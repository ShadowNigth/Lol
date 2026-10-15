class_name SelfTest
extends Node
## Autoprueba integrada: nueva partida, carga del mundo, movimiento, combate
## contra un esqueleto, saqueo, guardado y carga. Termina con código 0 si todo
## va bien. Uso con el juego exportado:
##   ./vaelmoor.x86_64 --headless -- --self-test
## Desde el código fuente:
##   godot --headless --path . res://tools/dev/smoke_test.tscn
## Opcional: --shots=<dir> (con un renderizador real) guarda capturas.

var _stage := "start"
var _t := 0.0
var _total := 0.0
var _failures: Array[String] = []
var _log: Array[String] = []
var _shots_dir := ""
var _enemy: Node = null
var _enemy_hp_start := 0.0
var _player_hp_start := 0.0
var _attacks := 0
var _shot_index := 0
var _return_ref := Vector3.ZERO
var _hits_start := 0
var _wolf_min_hp := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_reparent_and_start")


func _reparent_and_start() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Audio.wait_until_ready()
	GameState.start_new_game({"name": "Prueba", "class": "warrior", "seed": 12345})
	_stage = "loading"


func _note(msg: String) -> void:
	_log.append(msg)
	print("[SMOKE] ", msg)


func _fail(msg: String) -> void:
	_failures.append(msg)
	print("[SMOKE][FALLO] ", msg)


func _game() -> Node:
	return get_tree().current_scene


func _player() -> Player:
	var g := _game()
	if g and "player" in g:
		return g.get("player") as Player
	return null


func _shot(label: String) -> void:
	if _shots_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	if img:
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		_shot_index += 1
		var path := _shots_dir.path_join("%02d_%s.png" % [_shot_index, label])
		img.save_png(path)
		_note("Captura: " + path)


func _process(delta: float) -> void:
	_t += delta
	_total += delta
	if _total > 330.0:
		_fail("Tiempo de prueba agotado en la etapa '%s'" % _stage)
		_finish()
		return
	var p := _player()
	match _stage:
		"loading":
			if p and _game().has_method("is_world_ready") and bool(_game().call("is_world_ready")):
				_note("Mundo listo en %.1f s. Chunks: %d. Pos: %s" % [_total, (_game().get("world") as VoxelWorld).loaded_chunk_count(), p.global_position])
				_player_hp_start = p.stats.health
				_next("settle")
			elif _t > 120.0:
				_fail("El mundo no terminó de cargar")
				_finish()
		"settle":
			if _t > 2.0:
				if not p.is_on_floor():
					_fail("El jugador no está sobre el suelo tras aparecer (y=%.2f)" % p.global_position.y)
				else:
					_note("Jugador en el suelo, y=%.2f" % p.global_position.y)
				_shot("spawn")
				_next("npcs")
		"npcs":
			if _t > 1.5:
				var npcs := get_tree().get_nodes_in_group("npcs")
				_note("PNJ en la aldea: %d" % npcs.size())
				if npcs.size() < 5:
					_fail("Faltan PNJ en la aldea (%d de 5)" % npcs.size())
				# Misión del guardia Rolf
				if QuestManager.can_offer("huesos_inquietos"):
					QuestManager.accept("huesos_inquietos")
				if not QuestManager.is_active("huesos_inquietos"):
					_fail("No se pudo aceptar la misión 'Huesos inquietos'")
				# Comercio con la posadera
				var gold0 := p.gold
				var shop := GameState.get_shop("posada")
				var bread0 := GameState.item_count("bread")
				var price := maxi(1, int(round(float(ItemDB.get_def("bread")["value"]) * 1.3)))
				if p.gold >= price:
					p.gold -= price
					shop["stock"]["bread"] = int(shop["stock"]["bread"]) - 1
					GameState.give_item(p, {"id": "bread", "count": 1})
				_note("Compra: oro %d -> %d, pan %d -> %d" % [gold0, p.gold, bread0, GameState.item_count("bread")])
				# Usar una poción y soltar/recoger un objeto
				p.stats.health = p.stats.max_health * 0.5
				var pots := GameState.item_count("potion_health")
				GameState.use_item(p, "potion_health")
				_note("Poción usada: %d -> %d, salud %.0f/%.0f" % [pots, GameState.item_count("potion_health"), p.stats.health, p.stats.max_health])
				if GameState.item_count("potion_health") != pots - 1:
					_fail("La poción no se consumió correctamente")
				var bread1 := GameState.item_count("bread")
				GameState.remove_item("bread", 1)
				_game().call("drop_item", "bread")
				for n in (_game().get("spawner") as Node).get_children():
					if n is ItemPickup:
						(n as ItemPickup).interact(p)
						break
				_note("Soltar y recoger pan: %d -> %d (soltados pendientes: %d)" % [bread1, GameState.item_count("bread"), GameState.dropped_in_area().size()])
				if GameState.item_count("bread") != bread1:
					_fail("Soltar/recoger duplicó o perdió el objeto")
				_test_equipment(p)
				Input.action_press("move_forward")
				_next("walk")
		"walk":
			if _t > 2.5:
				Input.action_release("move_forward")
				var moved := p.global_position.distance_to(GameState.player.global_position)
				_note("Tras caminar: pos %s, aguante %.0f" % [p.global_position, p.stats.stamina])
				_next("jump")
				Input.action_press("jump")
		"jump":
			if _t > 0.1:
				Input.action_release("jump")
			if _t > 1.2:
				_note("Salto completado, en suelo: %s" % p.is_on_floor())
				_shot("walk")
				# Ir junto a las ruinas
				p.teleport(Vector3(52.5, 0, 9.5), -90.0)
				var w := _game().get("world") as VoxelWorld
				var h := w.generator.height_at(52, 9) + 1.0
				p.teleport(Vector3(52.5, h + 0.2, 9.5), -90.0)
				_next("to_ruins")
		"to_ruins":
			var enemies := get_tree().get_nodes_in_group("enemies")
			if not enemies.is_empty() and _t > 3.0:
				# El esqueleto del cementerio (el de la capilla puede quedar tras la escalera de la cripta)
				_enemy = enemies[0]
				for e in enemies:
					if (e as Enemy).entity_id == "ruins/skeleton_1":
						_enemy = e
				_note("Enemigos cargados: %d. Más cercano a %.1f m" % [enemies.size(), (_enemy as Node3D).global_position.distance_to(p.global_position)])
				_enemy_hp_start = (_enemy as Enemy).stats.health
				_shot("ruins")
				# Colocarse dentro del cementerio, a unos metros del esqueleto
				var ep := (_enemy as Node3D).global_position
				p.teleport(ep + Vector3(-4.0, 0.3, 0.0), -90.0)
				_next("approach")
			elif _t > 30.0:
				_fail("No aparecieron enemigos en las ruinas")
				_finish()
		"approach":
			var e := _enemy as Enemy
			if not is_instance_valid(e):
				_fail("El enemigo desapareció")
				_finish()
				return
			var to := e.global_position - p.global_position
			to.y = 0.0
			p._yaw = atan2(-to.x, -to.z)
			p._pitch = deg_to_rad(-8.0)
			if to.length() > 1.9:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			if e.is_aware() and _stage == "approach":
				_note("El esqueleto ha detectado al jugador (estado %d) a %.1f m" % [e.state, to.length()])
				_next("fight")
			elif _t > 20.0:
				_fail("El esqueleto no detectó al jugador")
				_next("fight")
		"fight":
			var e2 := _enemy as Enemy
			if not is_instance_valid(e2):
				_fail("El enemigo desapareció durante el combate")
				_finish()
				return
			var to2 := e2.global_position - p.global_position
			to2.y = 0.0
			p._yaw = atan2(-to2.x, -to2.z)
			p._pitch = deg_to_rad(-10.0)
			if to2.length() > 2.0:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			if fmod(_t, 0.7) < delta and to2.length() < 2.6:
				Input.action_press("attack")
				_attacks += 1
			else:
				Input.action_release("attack")
			if _t > 1.0 and _t < 1.1:
				_shot("fight")
			if p.stats.health < p.stats.max_health * 0.4:
				p.stats.heal(40.0)
			if not e2.is_alive():
				Input.action_release("move_forward")
				Input.action_release("attack")
				_note("Golpes: %d, impactos: %d, contra pared: %d, bloqueos del esqueleto: %d" % [p.stat_swings, p.stat_hits, p.stat_world_hits, e2.stat_blocks])
				_note("Esqueleto derrotado tras %d ataques en %.1f s. Salud del jugador: %.0f/%.0f (empezó con %.0f)" % [_attacks, _t, p.stats.health, p.stats.max_health, _player_hp_start])
				if p.stats.health >= _player_hp_start and p.stats.max_health == _player_hp_start:
					_note("Aviso: el jugador no recibió daño (puede ser correcto si bloqueó o mató rápido)")
				_next("ranged")
			elif _t > 60.0:
				_fail("Combate demasiado largo: vida del esqueleto %.0f/%.0f" % [e2.stats.health, e2.stats.max_health])
				_note("Golpes: %d, impactos: %d, contra pared: %d, bloqueos del esqueleto: %d" % [p.stat_swings, p.stat_hits, p.stat_world_hits, e2.stat_blocks])
				_next("loot")
		"ranged":
			var archer: Enemy = null
			for e in get_tree().get_nodes_in_group("enemies"):
				if (e as Enemy).entity_id == "ruins/archer_0" and (e as Enemy).is_alive():
					archer = e
			if archer == null:
				if _t > 3.0:
					_fail("No se encontró al arquero esqueleto")
					_next("loot")
				return
			if not has_meta("ranged_init"):
				set_meta("ranged_init", true)
				p.teleport(archer.global_position + Vector3(-9.0, 0.3, 0.0), -90.0)
				set_meta("archer_hp", archer.stats.health)
				set_meta("player_hp", p.stats.health)
				p.stats.mana = p.stats.max_mana
				return
			var to := archer.global_position - p.global_position
			p._yaw = atan2(-to.x, -to.z)
			var aim_dy := (archer.global_position.y + 1.1) - p.camera.global_position.y
			p._pitch = atan2(aim_dy, Vector2(to.x, to.z).length() + 0.001)
			if _t > 0.8 and not has_meta("fired_spell"):
				set_meta("fired_spell", true)
				var mana0 := p.stats.mana
				p._cast_spell()
				var proj := 0
				for n in get_tree().current_scene.get_children():
					if n is Projectile:
						proj += 1
				_note("Bola de fuego: magia %.0f -> %.0f, proyectiles en escena: %d" % [mana0, p.stats.mana, proj])
				if p.stats.mana >= mana0 or proj == 0:
					_fail("El hechizo no consumió magia o no creó el proyectil")
			if _t > 2.5 and not has_meta("bow_ready"):
				set_meta("bow_ready", true)
				var bow := load("res://data/weapons/bow.tres") as WeaponData
				p.add_weapon(bow)
				GameState.give_item(p, {"id": "arrow", "count": 10})
				p._equip_index(p.weapons.size() - 1)
				set_meta("arrows0", GameState.item_count("arrow"))
				Input.action_press("attack")
			if _t > 3.6 and has_meta("bow_ready") and not has_meta("bow_released"):
				set_meta("bow_released", true)
				Input.action_release("attack")
			if _t > 4.2 and not has_meta("bow_checked"):
				set_meta("bow_checked", true)
				_note("Arco: flechas %d -> %d" % [int(get_meta("arrows0")), GameState.item_count("arrow")])
				if GameState.item_count("arrow") != int(get_meta("arrows0")) - 1:
					_fail("El arco no disparó una flecha")
			if _t > 9.0:
				var hp0 := float(get_meta("archer_hp"))
				_note("Arquero: salud %.0f -> %.0f (vivo: %s). Salud del jugador %.0f -> %.0f, efectos: %s" % [hp0, archer.stats.health if is_instance_valid(archer) else 0.0,
						archer.is_alive() if is_instance_valid(archer) else false, float(get_meta("player_hp")), p.stats.health, p.stats.active_effect_names()])
				if is_instance_valid(archer) and archer.stats.health >= hp0 and archer.is_alive():
					_fail("Ni el hechizo ni la flecha dañaron al arquero")
				p._equip_index(0)
				_next("loot")
		"loot":
			if _t > 2.0:
				_shot("corpse")
				var e3 := _enemy as Enemy
				if is_instance_valid(e3) and not e3.is_alive():
					var gold_before := p.gold
					e3.interact(p)
					_note("Saqueo: oro %d -> %d, inventario %s" % [gold_before, p.gold, GameState.inventory])
				_next("save")
		"save":
			for act: String in ["move_forward", "attack", "block", "jump"]:
				Input.action_release(act)
			var err := GameState.save_game("autoprueba")
			if err != OK:
				_fail("No se pudo guardar: %s" % error_string(err))
				_finish()
				return
			_note("Partida guardada correctamente")
			var saved_pos := p.global_position
			set_meta("saved_pos", saved_pos)
			var msg := GameState.load_game("autoprueba")
			if msg != "":
				_fail("No se pudo cargar: " + msg)
				_finish()
				return
			_next("reload")
		"enter_dungeon":
			if _t > 0.5:
				_return_ref = p.global_position
				_game().call("enter_dungeon", "crypt_velmar", "selftest")
				_next("in_dungeon")
		"in_dungeon":
			var g := _game()
			if bool(g.call("is_world_ready")) and _t > 1.5:
				var dg := g.get("generator") as DungeonGenerator
				if dg == null:
					_fail("No se generó la mazmorra")
					_finish()
					return
				_note("Mazmorra '%s' generada: %d salas, verificada: %s, entrada %d, jefe %d" % [dg.display_name, dg.rooms.size(), dg.verified, dg.entrance_index, dg.boss_index])
				if not dg.verified:
					_fail("La mazmorra no superó la verificación de conectividad")
				if not p.is_on_floor():
					_fail("El jugador no está sobre el suelo de la mazmorra (y=%.2f)" % p.global_position.y)
				var boss_rect: Rect2i = dg.rooms[dg.boss_index]["rect"]
				var path := dg.find_path(p.global_position, Vector3(boss_rect.get_center().x + 0.5, 20, boss_rect.get_center().y + 0.5))
				_note("Ruta A* de la entrada al jefe: %d casillas" % path.size())
				if path.is_empty():
					_fail("No hay ruta transitable de la entrada a la sala del jefe")
				var en := get_tree().get_nodes_in_group("enemies").size()
				_note("Enemigos cargados en la mazmorra: %d" % en)
				_shot("dungeon_entrance")
				# Visitar la sala del jefe
				p.teleport(Vector3(boss_rect.get_center().x + 0.5, 20.1, boss_rect.end.y - 1.5), 0.0)
				_next("boss_view")
			elif _t > 60.0:
				_fail("La mazmorra no terminó de cargar")
				_finish()
		"boss_view":
			if _t > 2.0:
				_shot("dungeon_boss")
				var bosses := 0
				for e in get_tree().get_nodes_in_group("enemies"):
					if (e as Enemy).data.is_boss:
						bosses += 1
				_note("Jefes presentes: %d" % bosses)
				if bosses == 0:
					_fail("No apareció el jefe en su sala")
				_game().call("exit_dungeon")
				_next("exit_dungeon")
		"exit_dungeon":
			var g2 := _game()
			if bool(g2.call("is_world_ready")) and _t > 1.5:
				var d := p.global_position.distance_to(_return_ref)
				_note("De vuelta al exterior a %.1f m de la entrada de la cripta" % d)
				if g2.get("generator") is DungeonGenerator:
					_fail("Sigue en la mazmorra tras salir")
				_next("region")
			elif _t > 60.0:
				_fail("No se pudo volver al exterior")
				_finish()
		"region":
			if _t > 0.5:
				_test_region()
				# Campo abierto al este de la muralla para el combate con un lobo
				var w2 := _game().get("world") as VoxelWorld
				var hh := w2.generator.height_at(44, 0) + 1.0
				p.teleport(Vector3(44.5, hh + 0.2, 0.5), 90.0)
				_next("wolf_spawn")
		"wolf_spawn":
			if _t > 2.0:
				var w3 := _game().get("world") as VoxelWorld
				var wpos := Vector3(37.5, w3.generator.height_at(37, 0) + 1.1, 0.5)
				if QuestManager.can_offer("lobos_del_camino"):
					QuestManager.accept("lobos_del_camino")
				_enemy = (_game().get("spawner") as Node).call("_spawn_enemy", {"type": "enemy", "enemy": "wolf",
						"id": "selftest/wolf", "pos": wpos, "yaw": -90.0})
				if _enemy == null:
					_fail("No se pudo crear el lobo de prueba")
					_finish()
					return
				_player_hp_start = p.stats.health
				_hits_start = p.stat_hits
				_attacks = 0
				_wolf_min_hp = 999.0
				_next("wolf_fight")
		"wolf_fight":
			var wf := _enemy as Enemy
			if not is_instance_valid(wf):
				_fail("El lobo desapareció")
				_finish()
				return
			_wolf_min_hp = minf(_wolf_min_hp, wf.stats.health)
			var tw := wf.global_position - p.global_position
			tw.y = 0.0
			p._yaw = atan2(-tw.x, -tw.z)
			p._pitch = deg_to_rad(-10.0)
			if tw.length() > 1.9:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			if fmod(_t, 0.7) < delta and tw.length() < 2.4:
				Input.action_press("attack")
				_attacks += 1
			else:
				Input.action_release("attack")
			if _t > 1.5 and _t < 1.6:
				_shot("wolf")
			if p.stats.health < p.stats.max_health * 0.4:
				p.stats.heal(40.0)
			if not wf.is_alive():
				Input.action_release("move_forward")
				Input.action_release("attack")
				_note("Lobo (%s) derrotado tras %d ataques en %.1f s; impactos del jugador: %d; salud del jugador %.0f -> %.0f; ¿huyó? %s" % [
						wf.data.display_name, _attacks, _t, p.stat_hits - _hits_start, _player_hp_start, p.stats.health, wf._fled])
				_note("Misión 'Lobos en el camino': %s" % QuestManager.stage_text("lobos_del_camino"))
				if int(GameState.quests.get("lobos_del_camino", {}).get("progress", 0)) < 1:
					_fail("La caza del lobo no contó para la misión")
				var inv0 := GameState.item_count("wolf_pelt") + GameState.item_count("wolf_fang")
				wf.interact(p)
				_note("Botín del lobo: pieles/colmillos %d -> %d" % [inv0, GameState.item_count("wolf_pelt") + GameState.item_count("wolf_fang")])
				_finish()
			elif _t > 60.0:
				_fail("Combate con el lobo demasiado largo: vida %.0f/%.0f, impactos %d" % [wf.stats.health, wf.stats.max_health, p.stat_hits - _hits_start])
				_finish()
		"reload":
			if p and _game().has_method("is_world_ready") and bool(_game().call("is_world_ready")) and _t > 1.0:
				var sp: Vector3 = get_meta("saved_pos")
				var dist := p.global_position.distance_to(sp)
				_note("Partida cargada. Distancia a la posición guardada: %.2f m" % dist)
				if dist > 1.5:
					_fail("La posición cargada no coincide con la guardada")
				if GameState.is_killed(str((_enemy as Enemy).entity_id) if is_instance_valid(_enemy) else "ruins/skeleton_0") or true:
					_note("Enemigos muertos registrados: %s" % str(GameState.world_changes["killed"].keys()))
				_note("Misión tras cargar: %s, progreso %s" % [QuestManager.stage_text("huesos_inquietos"), GameState.quests.get("huesos_inquietos", {})])
				if not QuestManager.is_active("huesos_inquietos") or int(GameState.quests["huesos_inquietos"]["progress"]) < 1:
					_fail("El progreso de la misión no se conservó al guardar/cargar")
				_note("Equipo tras cargar: %s, armadura %.1f" % [GameState.equipment, p.stats.armor_rating])
				if str(GameState.equipment.get("head", "")) != "helm_iron" or p.stats.armor_rating <= 0.0:
					_fail("El equipo no se conservó al guardar/cargar")
				_shot("reloaded")
				_next("enter_dungeon")
			elif _t > 90.0:
				_fail("La carga no terminó")
				_finish()


## Equipo: kit inicial, equipar/quitar sin duplicar, efectos en armadura,
## resistencias, magia y escudo.
func _test_equipment(p: Player) -> void:
	var eq := GameState.equipment
	_note("Equipo inicial (%s): %s · armadura %.1f · escudo %s" % [GameState.character_class, eq, p.stats.armor_rating, p.offhand_id])
	if p.stats.armor_rating <= 0.0:
		_fail("El equipo inicial no da armadura")
	var arm0 := p.stats.armor_rating
	GameState.give_item(p, {"id": "helm_iron", "count": 1})
	GameState.equip_item(p, "helm_iron")
	if str(GameState.equipment.get("head", "")) != "helm_iron" or GameState.item_count("helm_iron") != 0:
		_fail("Equipar el yelmo falló o lo duplicó")
	_note("Yelmo de hierro: armadura %.1f -> %.1f" % [arm0, p.stats.armor_rating])
	if p.stats.armor_rating <= arm0:
		_fail("El yelmo no aumentó la armadura")
	var slash := p.stats.mitigate(20.0, "slash")
	var fire := p.stats.mitigate(20.0, "fire")
	_note("Daño 20 cortante -> %.1f; 20 de fuego -> %.1f (la armadura no frena la magia)" % [slash, fire])
	if slash >= 20.0 or fire < 19.99:
		_fail("La mitigación por armadura no funciona como se espera")
	# Cambiar el torso por la túnica de aprendiz: la pieza anterior vuelve al inventario
	var chest0 := str(GameState.equipment.get("chest", ""))
	var mana0 := p.stats.max_mana
	GameState.give_item(p, {"id": "robe_apprentice", "count": 1})
	GameState.equip_item(p, "robe_apprentice")
	_note("Túnica: magia máx. %.0f -> %.0f, resistencia al fuego %.2f, '%s' devuelto al inventario: %d" % [mana0, p.stats.max_mana,
			float(p.stats.resistances["fire"]), chest0, GameState.item_count(chest0) if chest0 != "" else 0])
	if p.stats.max_mana < mana0 + 14.9 or float(p.stats.resistances["fire"]) < 0.09:
		_fail("La túnica no aplicó sus bonificaciones")
	if chest0 != "" and GameState.item_count(chest0) != 1:
		_fail("La pieza sustituida no volvió al inventario")
	if chest0 != "":
		GameState.equip_item(p, chest0)
	# Quitar y volver a poner el escudo
	var off := str(GameState.equipment.get("offhand", ""))
	if off != "":
		GameState.unequip_slot(p, "offhand")
		if p.offhand_id != "" or GameState.item_count(off) != 1:
			_fail("Quitar el escudo no funcionó")
		GameState.equip_item(p, off)
		_note("Escudo quitado y vuelto a equipar: modelo '%s', bloqueo %.2f, visible %s" % [p.offhand_id, p.shield_block, p.viewmodel.has_shield()])
		if not p.viewmodel.has_shield():
			_fail("El escudo no aparece en la mano izquierda")


## Región: lugares con nombre, PNJ, mazmorras temáticas verificadas y fauna.
func _test_region() -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	var pl := wg.planner
	var names: Array[String] = []
	for site: Dictionary in pl.sites:
		names.append("%s (%s)" % [site["name"], StructurePlanner.direction_text(Vector2.ZERO, site["pos"])])
	_note("Lugares de la región: " + "; ".join(names))
	if pl.sites.size() < 6:
		_fail("Faltan lugares en la región (%d)" % pl.sites.size())
	for site2: Dictionary in pl.sites:
		var sp: Vector2 = site2["pos"]
		var h := wg.height_at(int(sp.x), int(sp.y))
		if h < WorldGenerator.SEA_LEVEL + 1:
			_fail("El lugar '%s' quedó bajo el agua (h=%d)" % [site2["name"], h])
	for npc_id: String in ["ulrico", "edda", "elena", "bram"]:
		var found := false
		for sp2: Dictionary in pl.spawns:
			if str(sp2.get("npc", "")) == npc_id:
				found = true
		if not found or NpcDB.get_npc(npc_id).is_empty():
			_fail("PNJ de la región ausente: %s" % npc_id)
	for did: String in ["barrow_grises", "cave_lobos"]:
		var dg := DungeonGenerator.new(did, GameState.world_seed, 1)
		var boss := ""
		for e: Dictionary in dg.entities:
			if str(e.get("id", "")).ends_with("/boss"):
				boss = str(e.get("enemy", ""))
		var key := "key_" + did
		_note("Mazmorra '%s' (%s): %d salas, verificada %s, jefe '%s', llave '%s'" % [dg.display_name, DungeonDB.get_def(did)["theme"],
				dg.rooms.size(), dg.verified, boss, ItemDB.display_name(key)])
		if not dg.verified or boss != str(DungeonDB.get_def(did)["boss"]) or not ItemDB.exists(key):
			_fail("La mazmorra '%s' no es válida" % did)
	# Fauna: manadas generadas en los chunks alrededor del cubil
	var den: Vector2 = Vector2.ZERO
	for site3: Dictionary in pl.sites:
		if site3["id"] == "cave_lobos":
			den = site3["pos"]
	var wolves := 0
	var t0 := Time.get_ticks_msec()
	var dcx := int(floor(den.x / 16.0))
	var dcz := int(floor(den.y / 16.0))
	for cz in range(dcz - 4, dcz + 5):
		for cx in range(dcx - 4, dcx + 5):
			for e2: Dictionary in wg.generate_chunk(cx, cz).entities:
				if str(e2.get("enemy", "")).begins_with("wolf"):
					wolves += 1
	_note("Lobos en los 81 chunks alrededor del cubil: %d (generados en %d ms)" % [wolves, Time.get_ticks_msec() - t0])
	if wolves == 0:
		_fail("No se generó ningún lobo alrededor del cubil")


func _next(s: String) -> void:
	_stage = s
	_t = 0.0


func _finish() -> void:
	set_process(false)
	print("[SMOKE] ===== RESUMEN =====")
	for l in _log:
		print("[SMOKE]   ", l)
	if _failures.is_empty():
		print("[SMOKE] RESULTADO: OK")
	else:
		print("[SMOKE] RESULTADO: %d fallo(s)" % _failures.size())
		for f in _failures:
			print("[SMOKE]   - ", f)
	# No dejar la partida de prueba en la lista del jugador
	DirAccess.remove_absolute(GameState.SAVE_DIR.path_join("autoprueba.json"))
	DirAccess.remove_absolute(GameState.SAVE_DIR.path_join("autoprueba.json.bak"))
	get_tree().quit(0 if _failures.is_empty() else 1)
