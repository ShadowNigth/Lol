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
var _from := ""          # --from=mine: salta directamente a las pruebas de la mina (desarrollo)


func _ready() -> void:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--shots="):
			_shots_dir = a.substr(8)
		elif a.begins_with("--from="):
			_from = a.substr(7)
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
	if _total > 600.0:
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
				if _from == "mine":
					_test_spider_assets()
					_go_mine()
					_next("mine_arrive")
					return
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
				if not p.is_on_floor() or absf(p.global_position.y - DungeonGenerator.FLOOR_Y) > 0.6:
					_fail("El jugador no está sobre el suelo de la mazmorra (y=%.2f)" % p.global_position.y)
				var boss_rect: Rect2i = dg.rooms[dg.boss_index]["rect"]
				var path := dg.find_path(p.global_position, Vector3(boss_rect.get_center().x + 0.5, 20, boss_rect.get_center().y + 0.5))
				_note("Ruta A* de la entrada al jefe: %d casillas" % path.size())
				if path.is_empty():
					_fail("No hay ruta transitable de la entrada a la sala del jefe")
				var en := get_tree().get_nodes_in_group("enemies").size()
				_note("Enemigos cargados en la mazmorra: %d" % en)
				_shot("dungeon_entrance")
				# Visitar la sala del jefe (con la vida llena: el jefe y su guardia atacan enseguida)
				p.stats.heal(p.stats.max_health)
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
				# Tras la sala del jefe el jugador puede llegar casi sin vida: un mordisco
				# lo mataría antes de que la prueba pudiera atacar.
				if p.is_dead:
					_fail("El jugador ya estaba muerto antes del combate con el lobo")
					_finish()
					return
				p.stats.heal(p.stats.max_health)
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
			if p.is_dead:
				_fail("El jugador murió durante el combate con el lobo (vida del lobo %.0f/%.0f)" % [wf.stats.health, wf.stats.max_health])
				_finish()
				return
			if fmod(_t, 10.0) < delta:
				_note("  [lobo t=%.0f] lobo %s estado %d consciente %s activo %s · jugador %s · distancia %.1f" % [_t, wf.global_position,
						wf.state, wf.is_aware(), wf.process_mode != Node.PROCESS_MODE_DISABLED, p.global_position, wf.global_position.distance_to(p.global_position)])
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
				_goto_site("inn_lobo")
				_next("visit_inn")
			elif _t > 60.0:
				_fail("Combate con el lobo demasiado largo: vida %.0f/%.0f, impactos %d" % [wf.stats.health, wf.stats.max_health, p.stat_hits - _hits_start])
				_finish()
		"visit_inn", "visit_hamlet":
			var w4 := _game().get("world") as VoxelWorld
			if _t > 3.0 and w4.is_chunk_loaded_at(p.global_position) and w4.pending_task_count() == 0:
				var want: Array = ["ulrico", "edda"] if _stage == "visit_inn" else ["elena", "bram"]
				var seen: Array[String] = []
				for n: Node in get_tree().get_nodes_in_group("npcs"):
					var npc := n as NPC
					if npc and str(npc.npc_id) in want and npc.process_mode != Node.PROCESS_MODE_DISABLED:
						var ground := w4.surface_height(npc.global_position.x, npc.global_position.z)
						seen.append("%s (y=%.1f, suelo %.1f)" % [npc.npc_id, npc.global_position.y, ground])
				_note("%s: PNJ presentes %s; lugar: '%s'; jugador en el suelo: %s" % [_stage, seen, _game().call("current_location_name"), p.is_on_floor()])
				if seen.size() < want.size():
					_fail("Faltan PNJ en %s (%s)" % [_stage, seen])
				_shot(_stage)
				if _stage == "visit_inn":
					_goto_site("robledal")
					_next("visit_hamlet")
				else:
					_test_bounty(p)
					_return_ref = p.global_position
					_game().call("enter_dungeon", "cave_lobos", "selftest_cave")
					_next("in_cave")
			elif _t > 40.0:
				_fail("No terminó de cargar el lugar (%s)" % _stage)
				_finish()
		"in_cave":
			if bool(_game().call("is_world_ready")) and _t > 2.0:
				var dg2 := _game().get("generator") as DungeonGenerator
				var kinds := {}
				var boss := ""
				for e4: Node in get_tree().get_nodes_in_group("enemies"):
					var en4 := e4 as Enemy
					kinds[en4.data.id] = int(kinds.get(en4.data.id, 0)) + 1
					if en4.data.is_boss:
						boss = en4.data.display_name
				_note("Cueva '%s' cargada: enemigos %s, jefe '%s' (verificada %s), jugador en el suelo: %s" % [dg2.display_name if dg2 else "?",
						kinds, boss, dg2.verified if dg2 else false, p.is_on_floor()])
				if dg2 == null or not kinds.has("wolf"):
					_fail("La cueva de los lobos no se cargó con sus lobos")
				_shot("cave")
				var brect: Rect2i = dg2.rooms[dg2.boss_index]["rect"]
				p.stats.heal(p.stats.max_health)
				p.teleport(Vector3(brect.get_center().x + 0.5, 20.1, brect.end.y - 1.5), 0.0)
				_next("cave_boss")
			elif _t > 60.0:
				_fail("La cueva no terminó de cargar")
				_finish()
		"cave_boss":
			if _t > 2.0:
				var alpha := false
				for e5: Node in get_tree().get_nodes_in_group("enemies"):
					if (e5 as Enemy).data.id == "wolf_alpha":
						alpha = true
				_note("Colmillo Negro presente en su sala: %s" % alpha)
				if not alpha:
					_fail("El lobo alfa no apareció en la sala del jefe")
				_shot("cave_boss")
				_game().call("exit_dungeon")
				_next("exit_cave")
		"exit_cave":
			if bool(_game().call("is_world_ready")) and _t > 1.5:
				_note("Fuera de la cueva a %.1f m de la entrada" % p.global_position.distance_to(_return_ref))
				if _game().get("generator") is DungeonGenerator:
					_fail("Sigue en la cueva tras salir")
				var w5 := _game().get("world") as VoxelWorld
				p.teleport(Vector3(44.5, w5.generator.height_at(44, 0) + 1.2, 0.5), 90.0)
				_next("bandit_spawn")
			elif _t > 60.0:
				_fail("No se pudo salir de la cueva")
				_finish()
		"bandit_spawn":
			if _t > 2.0:
				var w6 := _game().get("world") as VoxelWorld
				_enemy = (_game().get("spawner") as Node).call("_spawn_enemy", {"type": "enemy", "enemy": "bandit",
						"id": "selftest/bandit", "pos": Vector3(37.5, w6.generator.height_at(37, 0) + 1.1, 0.5), "yaw": -90.0})
				if _enemy == null:
					_fail("No se pudo crear el bandido de prueba")
					_finish()
					return
				p.stats.heal(p.stats.max_health)
				_player_hp_start = p.stats.health
				_hits_start = p.stat_hits
				_attacks = 0
				_next("bandit_fight")
		"bandit_fight":
			var bf := _enemy as Enemy
			if not is_instance_valid(bf):
				_fail("El bandido desapareció")
				_finish()
				return
			if p.is_dead:
				_fail("El jugador murió contra el bandido (vida del bandido %.0f/%.0f)" % [bf.stats.health, bf.stats.max_health])
				_finish()
				return
			var tb := bf.global_position - p.global_position
			tb.y = 0.0
			p._yaw = atan2(-tb.x, -tb.z)
			p._pitch = deg_to_rad(-8.0)
			if tb.length() > 1.9:
				Input.action_press("move_forward")
			else:
				Input.action_release("move_forward")
			if fmod(_t, 0.7) < delta and tb.length() < 2.5:
				Input.action_press("attack")
				_attacks += 1
			else:
				Input.action_release("attack")
			if _t > 1.5 and _t < 1.6:
				_shot("bandit")
			if p.stats.health < p.stats.max_health * 0.4:
				p.stats.heal(40.0)
			if not bf.is_alive():
				Input.action_release("move_forward")
				Input.action_release("attack")
				var body := bf.get_node_or_null("Model/Skeleton3D/Body") as MeshInstance3D
				_note("Bandido (%s, modelo '%s', malla %s) derrotado tras %d ataques en %.1f s; impactos %d; bloqueos %d; ¿huyó? %s; salud del jugador %.0f -> %.0f" % [
						bf.data.display_name, bf.data.model, body != null and body.mesh != null, _attacks, _t, p.stat_hits - _hits_start,
						bf.stat_blocks, bf._fled, _player_hp_start, p.stats.health])
				if bf.data.model != "bandit" or body == null:
					_fail("El bandido no se construyó con su modelo humano")
				var picks0 := GameState.item_count("lockpick")
				var gold0 := p.gold
				bf.interact(p)
				_note("Botín del bandido: oro %d -> %d, ganzúas %d -> %d" % [gold0, p.gold, picks0, GameState.item_count("lockpick")])
				_next("bandit_quest")
			elif _t > 70.0:
				_fail("Combate con el bandido demasiado largo: vida %.0f/%.0f, impactos %d" % [bf.stats.health, bf.stats.max_health, p.stat_hits - _hits_start])
				_finish()
		"bandit_quest":
			if _t > 0.5:
				_test_bandit_quest_start(p)
		"camp_arrive":
			var w7 := _game().get("world") as VoxelWorld
			# Los bandidos ya pueden atacar mientras carga: que no muera esperando
			if p.stats.health < p.stats.max_health * 0.5:
				p.stats.heal(60.0)
			if _t > 3.0 and w7.is_chunk_loaded_at(p.global_position) and w7.pending_task_count() == 0:
				_test_camp(p)
			elif _t > 45.0:
				_fail("El campamento no terminó de cargar")
				_finish()
		"lina_leaving":
			if p.stats.health < p.stats.max_health * 0.5:
				p.stats.heal(60.0)
			if _t > 3.0:
				var lina := _find_npc("lina")
				var moved := 0.0
				if lina:
					moved = lina.global_position.distance_to(get_meta("lina_pos"))
				_note("Lina libre: ¿se marcha? %s, recorrido %.1f m (o ya se perdió de vista: %s)" % [lina != null and lina._leaving, moved, lina == null])
				if lina != null and not lina._leaving:
					_fail("Lina no se marcha tras ser liberada")
				_goto_site("robledal")
				_next("lina_home")
		"lina_home":
			var w8 := _game().get("world") as VoxelWorld
			if _t > 3.0 and w8.is_chunk_loaded_at(p.global_position) and w8.pending_task_count() == 0:
				var lina2 := _find_npc("lina")
				_note("Robledal: Lina en casa: %s%s" % [lina2 != null, (" (cautiva: %s)" % lina2.is_captive()) if lina2 else ""])
				if lina2 == null or lina2.is_captive():
					_fail("Lina no aparece en Robledal tras el rescate")
				var gold1 := p.gold
				var rep0 := GameState.reputation("robledal")
				var res := QuestManager.on_talk("bram")
				_note("Bram: %s · misión completada %s · oro %d -> %d · reputación Robledal %d -> %d" % [
						str(res[0].get("say", "")).substr(0, 40) + "..." if not res.is_empty() else "(nada)", QuestManager.is_done("hija_bram"),
						gold1, p.gold, rep0, GameState.reputation("robledal")])
				if not QuestManager.is_done("hija_bram") or p.gold < gold1 + 150:
					_fail("La misión de la hija de Bram no se completó con su recompensa")
				# Las banderas de historia viajan en la partida guardada
				GameState.save_game("autoprueba")
				var f := FileAccess.open(GameState.SAVE_DIR.path_join("autoprueba.json"), FileAccess.READ)
				var saved: Variant = JSON.parse_string(f.get_as_text()) if f else null
				var flags: Dictionary = {}
				if saved is Dictionary:
					flags = ((saved as Dictionary).get("world_changes", {}) as Dictionary).get("flags", {})
				_note("Banderas guardadas: %s" % [flags.keys()])
				if not flags.has("lina_rescued") or not flags.has("known_bandit_camp"):
					_fail("Las banderas de historia no se guardaron")
				_go_castle()
				_next("castle_arrive")
			elif _t > 40.0:
				_fail("Robledal no terminó de cargar")
				_finish()
		"castle_arrive":
			var w9 := _game().get("world") as VoxelWorld
			if p.stats.health < p.stats.max_health * 0.5:
				p.stats.heal(60.0)
			if _t > 3.0 and w9.is_chunk_loaded_at(p.global_position) and w9.pending_task_count() == 0:
				_test_castle(p)
			elif _t > 45.0:
				_fail("El castillo no terminó de cargar")
				_finish()
		"law_arrest":
			var dlg2 := _open_dialogue()
			if dlg2 and dlg2.arrest:
				_test_arrest_pay(p, dlg2)
			elif _t > 30.0:
				_fail("Ningún guardia dio el alto al jugador buscado (recompensa %d)" % Law.bounty())
				Law.clear()
				_test_assault(p)
		"jail_wait":
			if _t > 1.0 and not bool(_game().get("_switching")):
				_test_jailed(p)
			elif _t > 40.0:
				_fail("El traslado al calabozo no terminó")
				_finish()
		"law_calm":
			if p.stats.health < p.stats.max_health * 0.6:
				p.stats.heal(80.0)
			if _t > 2.0:
				_test_calm(p)
		"escort_start":
			if _t > 1.2:
				var ans := _find_npc("anselmo")
				_note("Escolta aceptada: Anselmo sigue al jugador: %s (bandera %s)" % [ans != null and ans.follow_quest == "escolta_anselmo",
						GameState.has_flag("anselmo_escolta")])
				if ans == null or ans.follow_quest != "escolta_anselmo":
					_fail("El hermano Anselmo no sigue al jugador al aceptar la escolta")
					_finish()
					return
				set_meta("escort_from", ans.global_position)
				_goto_site("robledal")
				_next("escort_arrive")
		"escort_arrive":
			var w10 := _game().get("world") as VoxelWorld
			if _t > 4.0 and w10.is_chunk_loaded_at(p.global_position) and w10.pending_task_count() == 0:
				_test_escort_arrival(p)
			elif _t > 45.0:
				_fail("Robledal no terminó de cargar (escolta)")
				_finish()
		"mine_arrive":
			var wm := _game().get("world") as VoxelWorld
			if p.stats.health < p.stats.max_health * 0.5:
				p.stats.heal(60.0)
			if _t > 3.0 and wm.is_chunk_loaded_at(p.global_position) and wm.pending_task_count() == 0:
				_test_mine_outside(p)
			elif _t > 45.0:
				_fail("La bocamina no terminó de cargar")
				_finish()
		"mine_poison":
			_mine_poison_step(p)
		"mine_fight":
			_mine_fight_step(p, delta)
		"in_mine":
			if bool(_game().call("is_world_ready")) and _t > 2.5:
				_test_mine_inside(p)
			elif _t > 60.0:
				_fail("La mina no terminó de cargar")
				_finish()
		"mine_web":
			_mine_web_step(p)
		"mine_boss":
			if _t > 2.5:
				_test_mine_boss(p)
		"mine_exit":
			if bool(_game().call("is_world_ready")) and _t > 1.5:
				_test_mine_reward(p)
			elif _t > 60.0:
				_fail("No se pudo salir de la mina")
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
	# Puentes: donde un camino cruza agua debe haber tablero de madera
	var crossings := 0
	var bridged := 0
	for road: Dictionary in pl.roads:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var steps := int(a.distance_to(b))
		var last_chunk := Vector2i(1 << 30, 0)
		var cd: ChunkData = null
		for k in steps:
			var q := a.lerp(b, float(k) / maxf(steps, 1))
			var qx := int(floor(q.x))
			var qz := int(floor(q.y))
			if wg.height_at(qx, qz) < WorldGenerator.SEA_LEVEL and pl.surface_override(qx, qz) > 0:
				crossings += 1
				var cc := Vector2i(int(floor(qx / 16.0)), int(floor(qz / 16.0)))
				if cc != last_chunk:
					last_chunk = cc
					cd = wg.generate_chunk(cc.x, cc.y)
				if cd.get_world(qx, WorldGenerator.SEA_LEVEL + 1, qz) == BlockTypes.PLANKS:
					bridged += 1
	_note("Cruces de caminos sobre agua: %d columnas, con tablero de puente: %d" % [crossings, bridged])
	if bridged < crossings:
		_fail("Hay tramos de camino sobre el agua sin puente")
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
	# Emboscadas: bandidos junto a los caminos, nunca dentro de poblados
	var seen_chunks := {}
	var ambush: Array[Vector3] = []
	var t1 := Time.get_ticks_msec()
	for road2: Dictionary in pl.roads:
		var ra: Vector2 = road2["a"]
		var rb: Vector2 = road2["b"]
		var n := int(ra.distance_to(rb) / 12.0) + 1
		for k2 in n + 1:
			var q2 := ra.lerp(rb, float(k2) / float(n))
			var cc2 := Vector2i(int(floor(q2.x / 16.0)), int(floor(q2.y / 16.0)))
			if seen_chunks.has(cc2):
				continue
			seen_chunks[cc2] = true
			for e3: Dictionary in wg.generate_chunk(cc2.x, cc2.y).entities:
				if str(e3.get("id", "")).begins_with("wild/bandit_"):
					ambush.append(e3["pos"])
	var bad := 0
	for ap: Vector3 in ambush:
		var near := pl.nearest_road_point(Vector2(ap.x, ap.z))
		if near.is_empty() or float(near["dist"]) > 12.0 or pl.near_settlement(int(ap.x), int(ap.z)):
			bad += 1
	_note("Emboscadas en los %d chunks de los caminos: %d bandidos (en %d ms), mal colocados: %d" % [seen_chunks.size(), ambush.size(),
			Time.get_ticks_msec() - t1, bad])
	if bad > 0:
		_fail("Hay bandidos emboscados lejos de los caminos o dentro de un poblado")


## Encargo generado del tablón de Robledal: aceptar, cumplir, sobrevivir a un
## guardado JSON y cobrar.
func _test_bounty(p: Player) -> void:
	var boards := 0
	for n: Node in (_game().get("spawner") as Node).get_children():
		if n is NoticeBoard:
			boards += 1
	Bounties.use_board("robledal")
	var qid := Bounties.current_id("robledal")
	var def := QuestDB.get_quest(qid)
	_note("Tablones cargados: %d. Encargo '%s': %s" % [boards, def.get("title", "?"), QuestManager.stage_text(qid)])
	if boards == 0 or def.is_empty() or not QuestManager.is_active(qid):
		_fail("El tablón de anuncios no ofreció un encargo")
		return
	# La definición debe sobrevivir al guardado (JSON convierte los enteros en reales)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(GameState.quests[qid]))
	GameState.quests[qid] = round_trip
	if not Bounties.valid_def((round_trip as Dictionary).get("def")):
		_fail("La definición del encargo no es válida tras guardarla")
	var obj: Dictionary = QuestManager.current_stage(qid).get("objective", {})
	var count := int(obj.get("count", 1))
	match str(obj.get("type", "")):
		"kill":
			for i in count:
				QuestManager.on_enemy_killed(str(obj["target"]) + "_warrior" if str(obj["target"]) == "skeleton" else str(obj["target"]))
		"collect":
			GameState.give_item(p, {"id": str(obj["target"]), "count": count})
	var gold0 := p.gold
	Bounties.use_board("robledal")
	_note("Encargo cobrado: %s, oro %d -> %d, reputación Robledal %d" % [QuestManager.is_done(qid), gold0, p.gold, GameState.reputation("robledal")])
	if not QuestManager.is_done(qid) or p.gold <= gold0:
		_fail("El encargo no se pudo completar y cobrar")
	# Encargo de salteadores (otro periodo): definición válida que cuenta cualquier bandido
	var day0 := GameState.day
	var found := ""
	for period in 24:
		GameState.day = 1 + period * Bounties.PERIOD_DAYS
		var d2 := Bounties.generate("hojarrubia")
		var o2: Dictionary = ((d2["stages"] as Array)[0] as Dictionary)["objective"]
		if str(o2.get("target", "")) == "bandit":
			found = "%s (periodo %d, %d bandidos, %d de oro)" % [d2["title"], period, int(o2["count"]), int(d2["rewards"]["gold"])]
			if not Bounties.valid_def(d2):
				_fail("La definición del encargo de salteadores no es válida")
			break
	GameState.day = day0
	_note("Encargo de salteadores en el tablón de Hojarrubia: %s" % (found if found != "" else "ninguno"))
	if found == "":
		_fail("Ningún tablón ofreció un encargo de salteadores en 24 periodos")


func _find_npc(npc_id: String) -> NPC:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := n as NPC
		if npc and npc.npc_id == npc_id and not npc.is_queued_for_deletion():
			return npc
	return null


func _camp_structure() -> Dictionary:
	var wg := _game().get("overworld_generator") as WorldGenerator
	for st: Dictionary in wg.planner.structures:
		if str(st.get("id", "")) == "bandit_camp/camp":
			return st
	return {}


## Misión «La hija de Bram»: aceptar, preguntar en la posada (descubre el
## campamento en el mapa) y viajar a la puerta del campamento.
func _test_bandit_quest_start(p: Player) -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	var camp: Dictionary = {}
	for site: Dictionary in wg.planner.sites:
		if site["id"] == "bandit_camp":
			camp = site
	if camp.is_empty():
		_fail("No se planificó el campamento de bandidos")
		_finish()
		return
	var cp: Vector2 = camp["pos"]
	_note("Campamento de los Cuervos en %s (%s de Hojarrubia), altura del suelo %d, ¿conocido? %s" % [cp, StructurePlanner.direction_text(Vector2.ZERO, cp),
			wg.height_at(int(cp.x), int(cp.y)), StructurePlanner.site_known(camp)])
	if StructurePlanner.site_known(camp):
		_fail("El campamento aparece en el mapa antes de descubrirlo")
	if not QuestManager.can_offer("hija_bram"):
		_fail("Bram no ofrece la misión de su hija")
	QuestManager.accept("hija_bram")
	var res := QuestManager.on_talk("ulrico")
	var said := DialogueUI.resolve_text(str(res[0].get("say", "")) if not res.is_empty() else "", Vector3(-200, 0, 0))
	_note("Ulrico: «%s...» · etapa: %s · ¿campamento en el mapa? %s" % [said.substr(maxi(said.find("Edda"), 0), 70), QuestManager.stage_text("hija_bram"),
			StructurePlanner.site_known(camp)])
	if res.is_empty() or not StructurePlanner.site_known(camp) or said.find("{dir:") >= 0 or said.find(" m al ") < 0:
		_fail("Preguntar a Ulrico no reveló el campamento o el texto no se resolvió")
	var st := _camp_structure()
	var gate := ChunkWriter.local_to_world(st["origin"], int(st["w"]), int(st["d"]), int(st["rot"]), Vector3(12.5, 0, -1.0))
	var out := ChunkWriter.local_to_world(st["origin"], int(st["w"]), int(st["d"]), int(st["rot"]), Vector3(12.5, 0, -6.0))
	p.stats.heal(p.stats.max_health)
	p.teleport(Vector3(gate.x, wg.height_at(int(floor(gate.x)), int(floor(gate.z))) + 1.2, gate.z), 0.0)
	var look := gate - out
	p._yaw = atan2(-look.x, -look.z)
	_next("camp_arrive")


## En el campamento: llegada (objetivo «llegar a»), bandidos, jaula con Lina,
## ganzúas, diálogo de rescate y arcón del jefe abierto con su llave.
func _test_camp(p: Player) -> void:
	var st := _camp_structure()
	var center := ChunkWriter.local_to_world(st["origin"], int(st["w"]), int(st["d"]), int(st["rot"]), Vector3(12.5, 0, 12.5))
	_note("Llegada al campamento: lugar '%s', etapa: %s" % [_game().call("current_location_name"), QuestManager.stage_text("hija_bram")])
	if int(GameState.quests.get("hija_bram", {}).get("stage", 0)) < 2:
		_fail("Llegar al campamento no hizo avanzar la misión")
	var kinds := {}
	var chief: Enemy = null
	var bandits: Array[Enemy] = []
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and e.data.model == "bandit" and e.is_alive() and Vector2(e.global_position.x - center.x, e.global_position.z - center.z).length() < 16.0:
			kinds[e.data.id] = int(kinds.get(e.data.id, 0)) + 1
			bandits.append(e)
			if e.data.is_boss:
				chief = e
	var archer_y := -1.0
	for e2: Enemy in bandits:
		if e2.data.id == "bandit_archer":
			archer_y = e2.global_position.y - center.y
	_note("Bandidos en el campamento: %s · arquera a %.1f m sobre el suelo (torre)" % [kinds, archer_y])
	if chief == null or not kinds.has("bandit") or not kinds.has("bandit_archer"):
		_fail("Faltan bandidos en el campamento")
	if archer_y < 3.5 or archer_y > 4.6:
		_fail("La arquera no está en la plataforma de la torre de vigía (%.1f m)" % archer_y)
	var cage: Cage = null
	var stash: Chest = null
	var fire := false
	for n2: Node in (_game().get("spawner") as Node).get_children():
		if n2 is Cage:
			cage = n2
		elif n2 is Chest and (n2 as Chest).entity_id == "bandit_camp/camp/stash":
			stash = n2
		elif n2.get_child_count() > 0 and n2 is StaticBody3D:
			for ch: Node in n2.get_children():
				if ch is TorchLight:
					fire = true
	var lina := _find_npc("lina")
	_note("Jaula: %s · Lina dentro: %s (encerrada %s) · arcón con cerradura: %s · hoguera encendida: %s" % [cage != null,
			lina != null and cage != null and lina.global_position.distance_to(cage.global_position) < 1.2, lina.is_caged() if lina else false,
			stash.is_locked() if stash else false, fire])
	if cage == null or lina == null or not lina.is_caged() or stash == null or not stash.is_locked():
		_fail("El campamento no tiene la jaula con Lina o el arcón cerrado")
		_finish()
		return
	_shot("camp")
	# Ganzúas: intentos contra la cerradura difícil del arcón (contabilidad de roturas)
	GameState.give_item(p, {"id": "lockpick", "count": 12})
	var picks0 := GameState.item_count("lockpick")
	var broke := 0
	var results: Array[String] = []
	for i in 8:
		if not stash.is_locked():
			break
		var r := LockPicking.try_open(p, stash.entity_id, stash.lock_level, "", stash.global_position)
		results.append(r)
		if r == "broke":
			broke += 1
	_note("Arcón (difícil, %d %% de éxito con Ganzúas %d): %s · ganzúas %d -> %d" % [int(LockPicking.chance(p.stats, 60) * 100.0), p.stats.skill("lockpick"),
			results, picks0, GameState.item_count("lockpick")])
	if GameState.item_count("lockpick") != picks0 - broke:
		_fail("Las ganzúas rotas no se descontaron bien")
	# Jaula: con mucha habilidad se fuerza enseguida
	var skill0 := p.stats.skill("lockpick")
	p.stats.skills["lockpick"] = 90
	var xp0 := float(p.stats.skill_xp["lockpick"])
	var tries := 0
	while not cage.opened and tries < 10 and GameState.item_count("lockpick") > 0:
		cage.interact(p)
		tries += 1
	var trained := float(p.stats.skill_xp["lockpick"]) > xp0 or p.stats.skill("lockpick") > 90
	p.stats.skills["lockpick"] = skill0
	_note("Jaula forzada en %d intento(s): abierta %s, bandera %s, entrenó Ganzúas %s · etapa: %s" % [tries, cage.opened,
			GameState.has_flag("jaula_cuervos_abierta"), trained, QuestManager.stage_text("hija_bram")])
	if not cage.opened or not GameState.has_flag("jaula_cuervos_abierta") or int(GameState.quests["hija_bram"]["stage"]) != 3:
		_fail("Forzar la jaula no la abrió o no avanzó la misión")
	# Los bandidos caen (daño real a través de take_hit) y el jefe lleva la llave
	for e3: Enemy in bandits:
		e3.take_hit(9999.0, {"damage_type": "blunt"})
	var key0 := GameState.item_count("key_cuervos")
	if chief:
		chief.interact(p)
	_note("Garra registrado: llave de los Cuervos %d -> %d, nota %d" % [key0, GameState.item_count("key_cuervos"), GameState.item_count("nota_cuervos")])
	if GameState.item_count("key_cuervos") < 1:
		_fail("El jefe de los bandidos no llevaba la llave")
	var gold0 := p.gold
	stash.interact(p)
	_note("Arcón abierto con la llave: %s, oro %d -> %d" % [not stash.is_locked(), gold0, p.gold])
	if stash.is_locked() or p.gold <= gold0:
		_fail("La llave no abrió el arcón del jefe")
	# Hablar con Lina: el diálogo real (DialogueUI) hace avanzar la misión
	_game().call("open_dialogue", lina)
	var dlg := _game().get("_dialogue") as DialogueUI
	var text := dlg._text.text if dlg else ""
	_note("Lina: «%s...» · etapa: %s · bandera de rescate: %s" % [text.substr(0, 60), QuestManager.stage_text("hija_bram"), GameState.has_flag("lina_rescued")])
	if not GameState.has_flag("lina_rescued") or int(GameState.quests["hija_bram"]["stage"]) != 4:
		_fail("Hablar con Lina no la rescató")
	if dlg:
		dlg.close()
	set_meta("lina_pos", lina.global_position)
	_next("lina_leaving")


# ---------------------------------------------------------------------------
# Castillo de Peñalba, ley y orden, escolta
# ---------------------------------------------------------------------------

## La conversación abierta en el juego (o null si no hay o ya se cerró).
func _open_dialogue() -> DialogueUI:
	var dv: Variant = _game().get("_dialogue")
	if dv == null or not is_instance_valid(dv) or (dv as Node).is_queued_for_deletion():
		return null
	return dv as DialogueUI


func _castle_local(lp: Vector3) -> Vector3:
	var wg := _game().get("overworld_generator") as WorldGenerator
	return wg.planner.castle_local(lp)


func _castle_block(lx: int, ly: int, lz: int) -> int:
	var w := _game().get("world") as VoxelWorld
	var wp := _castle_local(Vector3(lx + 0.5, ly + 0.5, lz + 0.5))
	return w.get_block(int(floor(wp.x)), int(floor(wp.y)), int(floor(wp.z)))


## Explanada ante la puerta del castillo, mirando hacia ella.
func _go_castle() -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	GameState.time_of_day = 11.0
	_player().teleport(_castle_local(Vector3(19.5, 0.2, -3.5)), 180.0 - wg.planner.castle_rot * 90.0)


func _castle_npc(entity_id: String) -> NPC:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := n as NPC
		if npc and npc.entity_id == entity_id and not npc.is_queued_for_deletion():
			return npc
	return null


func _attachments(npc_skel: Skeleton3D) -> int:
	var k := 0
	if npc_skel:
		for ch: Node in npc_skel.get_children():
			if ch is BoneAttachment3D:
				k += 1
	return k


## Estructura del castillo, su gente con el equipo visible y robos con y sin testigos.
func _test_castle(p: Player) -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	var checks := {
		"paso de la puerta": _castle_block(19, 1, 3) == BlockTypes.AIR and _castle_block(19, 0, 0) == BlockTypes.AIR,
		"muralla maciza": BlockTypes.solid[_castle_block(10, 3, 3)] == 1,
		"adarve": BlockTypes.solid[_castle_block(10, 5, 3)] == 1 and _castle_block(10, 6, 3) == BlockTypes.AIR,
		"almena": _castle_block(10, 7, 2) == BlockTypes.STONE_BRICK,
		"puerta de torre": _castle_block(5, 6, 3) == BlockTypes.AIR and _castle_block(6, 7, 3) == BlockTypes.AIR,
		"caracol": BlockTypes.shape[_castle_block(2, 6, 4)] == BlockTypes.Shape.STAIRS,
		"escalera al adarve": BlockTypes.shape[_castle_block(13, 5, 5)] == BlockTypes.Shape.STAIRS,
		"rejas": _castle_block(28, 1, 26) == BlockTypes.IRON_BARS,
		"salón": _castle_block(19, 3, 25) == BlockTypes.AIR and _castle_block(16, 3, 23) == BlockTypes.CHISELED,
		"azotea": BlockTypes.solid[_castle_block(17, 12, 27)] == 1,
	}
	var bad: Array[String] = []
	for k: String in checks:
		if not bool(checks[k]):
			bad.append(k)
	var cells := 0
	var thrones := 0
	var dummies := 0
	var banners := 0
	var board := false
	var thr_mesh := ModelLibrary.prop_mesh("throne")
	var dum_mesh := ModelLibrary.prop_mesh("training_dummy")
	var ban_mesh := ModelLibrary.prop_mesh("banner", {"kind": "penalba"})
	for n: Node in (_game().get("spawner") as Node).get_children():
		if n is CellDoor:
			cells += 1
		elif n is NoticeBoard and (n as NoticeBoard).site == "castle":
			board = true
		elif n is StaticBody3D:
			for ch: Node in n.get_children():
				if ch is MeshInstance3D:
					var m := (ch as MeshInstance3D).mesh
					thrones += 1 if m == thr_mesh else 0
					dummies += 1 if m == dum_mesh else 0
					banners += 1 if m == ban_mesh else 0
	_note("Castillo de Peñalba (giro %d) · lugar '%s' · estructura: %s · celdas %d, trono %d, muñecos %d, estandartes azules %d, tablón %s" % [
			wg.planner.castle_rot, _game().call("current_location_name"), "OK" if bad.is_empty() else "FALLA " + str(bad), cells, thrones, dummies, banners, board])
	if not bad.is_empty() or cells != 2 or thrones != 1 or dummies != 3 or banners < 6 or not board:
		_fail("El castillo no tiene todas sus partes")
	if str(_game().call("current_location_name")) != "Castillo de Peñalba":
		_fail("La explanada del castillo no está dentro de su zona con nombre")
	# Gente del castillo y equipo visible
	var names: Array[String] = []
	for id: String in ["isolda", "aldric", "garin", "anselmo"]:
		if _find_npc(id) == null:
			names.append(id)
	var guards: Array[NPC] = []
	for n2: Node in get_tree().get_nodes_in_group("npcs"):
		var g := n2 as NPC
		if g and g.npc_id == "guardia_castillo":
			guards.append(g)
	var aldric := _find_npc("aldric")
	var gl: Dictionary = guards[0].look_final if not guards.is_empty() else {}
	var al: Dictionary = aldric.look_final if aldric else {}
	_note("Gente: faltan %s · guardias %d · Aldric: yelmo %s, malla %s, guanteletes %s, grebas %s, escarpes %s, sobreveste %s, piezas en mano %d · guardia: yelmo %s, malla %s, sobreveste %s, piezas en mano %d" % [
			names, guards.size(), al.has("helm"), al.has("chain"), al.has("gauntlets"), al.has("greaves"), al.has("sabatons"), al.has("tabard"),
			_attachments(aldric.skeleton) if aldric else 0, gl.has("helm"), gl.has("chain"), gl.has("tabard"),
			_attachments(guards[0].skeleton) if not guards.is_empty() else 0])
	if not names.is_empty() or guards.size() < 4:
		_fail("Falta gente en el castillo")
	if not (al.has("helm") and al.has("chain") and al.has("gauntlets") and al.has("tabard")) or not (gl.has("helm") and gl.has("chain")):
		_fail("La armadura de los guardias no se ve en sus modelos")
	if aldric and _attachments(aldric.skeleton) < 2:
		_fail("El capitán no lleva espada y escudo")
	_shot("castle")
	# Robo sin testigos: arcón del cuartel, con la puerta cerrada
	var chest: Chest = null
	var rack: WeaponRack = null
	for n3: Node in (_game().get("spawner") as Node).get_children():
		if n3 is Chest and (n3 as Chest).entity_id == "castle/barracks/chest":
			chest = n3
		elif n3 is WeaponRack and (n3 as WeaponRack).entity_id == "castle/fort/yard_rack":
			rack = n3
	if chest == null or rack == null:
		_fail("No se encontraron el arcón del cuartel o el armero del patio")
		_finish()
		return
	var hint := chest.get_interaction_text()
	p.teleport(_castle_local(ChunkWriter.local_to_world(Vector3i(6, 0, 8), 9, 7, 1, Vector3(2.8, 0.05, 2.2))), 0.0)
	var b0 := Law.bounty()
	chest.interact(p)
	_note("Robo sin testigos (arcón del cuartel, «%s»): recompensa %d -> %d" % [hint, b0, Law.bounty()])
	if hint.find("Robar") < 0 or Law.bounty() != b0:
		_fail("Robar sin testigos no debería ser delito (o el cofre no tiene dueño)")
	# Robo con testigo: un guardia mira mientras se vacía el armero del patio
	var witness := _castle_npc("castle/guard_keep")
	var at := _castle_local(Vector3(13.6, 0.05, 21.2))
	p.teleport(at, 0.0)
	if witness:
		witness.global_position = at + Vector3(3.0, 0.0, 0.0)
		witness.rotation.y = atan2(3.0, 0.0)
		witness.reset_physics_interpolation()
	var rep0 := GameState.reputation("guardia")
	rack.interact(p)
	_note("Robo con testigo (armero, %s mirando): recompensa %d, reputación con la guardia %d -> %d" % [witness != null, Law.bounty(), rep0, GameState.reputation("guardia")])
	if Law.bounty() <= 25 or GameState.reputation("guardia") >= rep0:
		_fail("El robo delante de un guardia no se denunció")
	p.gold = maxi(p.gold, Law.bounty() + 50)
	_next("law_arrest")


func _test_arrest_pay(p: Player, dlg: DialogueUI) -> void:
	var guard := dlg.npc
	var b := Law.bounty()
	var gold0 := p.gold
	dlg._arrest_pay()
	_note("Alto de la guardia (%s, a %.1f m): multa %d pagada, oro %d -> %d, recompensa ahora %d" % [guard.display_name() if guard else "?",
			guard.global_position.distance_to(p.global_position) if guard else -1.0, b, gold0, p.gold, Law.bounty()])
	if Law.is_wanted() or p.gold != gold0 - b:
		_fail("Pagar la multa no saldó la deuda")
	if dlg and is_instance_valid(dlg):
		dlg._arrest_close()
	_test_assault(p)


## Agresión a un aldeano: denuncia, huida y, después, calabozo.
func _test_assault(p: Player) -> void:
	var ans := _find_npc("anselmo")
	if ans == null:
		_fail("No está el hermano Anselmo para la prueba de agresión")
		_finish()
		return
	p.teleport(ans.global_position + Vector3(1.2, 0.1, 0.0), 0.0)
	var rep0 := GameState.reputation("penalba")
	var hp0 := ans.health
	var res := ans.take_hit(6.0, {"attacker": p, "position": ans.global_position + Vector3(0, 1.3, 0), "damage_type": "blunt"})
	var alerted := 0
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var g := n as NPC
		if g and g.is_guard() and (g._alert_pos != Vector3.INF or g._pursue):
			alerted += 1
	_note("Agresión a Anselmo: %s, salud %.0f -> %.0f, huye %s, recompensa %d, reputación Peñalba %d -> %d, guardias alertados %d" % [res, hp0, ans.health,
			ans.is_fleeing(), Law.bounty(), rep0, GameState.reputation("penalba"), alerted])
	if Law.bounty() != Law.CRIMES["agresion"]["bounty"] or not ans.is_fleeing() or GameState.reputation("penalba") >= rep0:
		_fail("La agresión no se denunció o la víctima no huyó")
	# Al calabozo: el guardia más cercano le da el alto y el jugador se entrega
	var guard := _castle_npc("castle/guard_yard")
	if guard == null:
		guard = _castle_npc("castle/guard_gate_w")
	set_meta("day_before_jail", GameState.day)
	_game().call("open_arrest", guard)
	var dlg := _open_dialogue()
	if dlg == null or not dlg.arrest:
		_fail("No se abrió el diálogo de detención")
		_finish()
		return
	dlg._arrest_jail()
	_next("jail_wait")


func _test_jailed(p: Player) -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	var spot: Dictionary = wg.planner.jail_spot
	var door: CellDoor = null
	for n: Node in get_tree().get_nodes_in_group("cell_doors"):
		if (n as CellDoor).entity_id == str(spot["door"]):
			door = n
	var dist := p.global_position.distance_to(spot["pos"])
	var day0 := int(get_meta("day_before_jail"))
	_note("Calabozo: día %d -> %d, hora %.1f, recompensa %d, en la celda a %.1f m, reja abierta %s, días cumplidos %d" % [day0, GameState.day,
			GameState.time_of_day, Law.bounty(), dist, door.open if door else false, int(GameState.law.get("jail_days", 0))])
	if GameState.day != day0 + 1 or Law.is_wanted() or dist > 1.6 or door == null or not door.open or int(GameState.law["jail_days"]) != 1:
		_fail("La condena en el calabozo no funcionó")
	_shot("jail")
	_test_resist(p)


## Atacar a un guardia: se resiste, el guardia pelea (Enemy con su aspecto),
## muere (asesinato, vuelve en días) y el capitán, con nombre, solo cae inconsciente.
func _test_resist(p: Player) -> void:
	GameState.time_of_day = 11.0
	var guard := _castle_npc("castle/guard_keep")
	if guard == null:
		guard = _castle_npc("castle/guard_gate_e")
	if guard == null:
		_fail("No hay guardia para la prueba de resistencia")
		_finish()
		return
	p.teleport(guard.global_position + Vector3(1.5, 0.1, 0.0), 0.0)
	var gid := guard.entity_id
	guard.take_hit(8.0, {"attacker": p, "position": guard.global_position + Vector3(0, 1.3, 0), "damage_type": "slash"})
	var e := guard.hostile_enemy
	var body := e.get_node_or_null("Model/Skeleton3D/Body") as MeshInstance3D if e else null
	_note("Ataque a un guardia: se resiste %s, recompensa %d, guardia convertido en enemigo %s ('%s', %s, malla %s, piezas %d), PNJ oculto %s" % [Law.resisted(), Law.bounty(),
			e != null, e.display_name() if e else "", e.data.id if e else "", body != null, _attachments(e.skeleton) if e else 0, not guard.visible])
	if e == null or not Law.resisted() or e.data.id != "town_guard" or body == null or guard.visible or _attachments(e.skeleton) < 2:
		_fail("El guardia atacado no pasó a pelear")
		_finish()
		return
	var b0 := Law.bounty()
	e.take_hit(9999.0, {"attacker": p, "damage_type": "blunt"})
	var gold0 := p.gold
	e.interact(p)
	_note("Guardia abatido: muerto %s, no vuelve hasta dentro de %d días %s, PNJ liberado %s, recompensa %d -> %d, botín oro %d -> %d" % [not e.is_alive(),
			Law.GUARD_RESPAWN_DAYS, GameState.is_killed(gid, Law.GUARD_RESPAWN_DAYS), not is_instance_valid(guard) or guard.is_queued_for_deletion(), b0, Law.bounty(), gold0, p.gold])
	if e.is_alive() or not GameState.is_killed(gid, Law.GUARD_RESPAWN_DAYS):
		_fail("El guardia muerto no quedó registrado")
	# El capitán (con nombre) cae inconsciente en vez de morir
	var aldric := _find_npc("aldric")
	if aldric:
		p.teleport(aldric.global_position + Vector3(1.5, 0.1, 0.0), 0.0)
		aldric.take_hit(5.0, {"attacker": p, "damage_type": "slash"})
		var ae := aldric.hostile_enemy
		if ae:
			ae.take_hit(9999.0, {"attacker": p, "damage_type": "blunt"})
		_note("Capitán Aldric: peleó %s y cayó inconsciente %s (visible %s)" % [ae != null, aldric.is_knocked_out(), aldric.visible])
		if ae == null or not aldric.is_knocked_out() or not aldric.visible:
			_fail("El capitán no quedó inconsciente al vencerle")
	# Se salda todo: los guardias que se hubieran unido vuelven a su puesto
	Law.clear()
	p.stats.heal(p.stats.max_health)
	_next("law_calm")


func _test_calm(p: Player) -> void:
	var hostile := 0
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e and e.guard_npc != null and e.is_alive() and not e.is_queued_for_deletion():
			hostile += 1
	_note("Deuda saldada: guardias aún hostiles %d" % hostile)
	if hostile > 0:
		_fail("Los guardias no se calmaron al saldar la deuda")
	# La ley viaja en la partida guardada (y las partidas antiguas sin ella valen)
	GameState.law["bounty"] = 123
	GameState.law["resisted_day"] = GameState.day + 1
	var data := GameState.build_save_data()
	var rt: Variant = JSON.parse_string(JSON.stringify(data))
	var law2 := GameState.sanitize_law((rt as Dictionary).get("law", null))
	var old := GameState.sanitize_law(null)
	_note("Ley guardada: %s · partida antigua: %s" % [law2, old])
	if int(law2["bounty"]) != 123 or int(law2["resisted_day"]) != GameState.day + 1 or int(old["bounty"]) != 0:
		_fail("El estado de la ley no se guarda bien")
	Law.clear()
	# Escolta: el hermano Anselmo acompaña al jugador hasta Robledal
	var ans := _find_npc("anselmo")
	if ans:
		ans._flee_t = 0.0
		p.teleport(ans.global_position + Vector3(1.5, 0.1, 0.0), 0.0)
	QuestManager.accept("escolta_anselmo")
	_next("escort_start")


func _test_escort_arrival(p: Player) -> void:
	var ans := _find_npc("anselmo")
	var dist := ans.global_position.distance_to(p.global_position) if ans else -1.0
	var loc := (_game().get("overworld_generator") as WorldGenerator).planner.location_id_at(ans.global_position.x, ans.global_position.z) if ans else ""
	_note("Escolta en Robledal: Anselmo a %.1f m del jugador (lugar '%s'), llegó %s, etapa: %s" % [dist, loc, GameState.has_flag("anselmo_llego"),
			QuestManager.stage_text("escolta_anselmo")])
	if ans == null or not GameState.has_flag("anselmo_llego"):
		_fail("El acompañante no llegó a Robledal")
		_finish()
		return
	var gold0 := p.gold
	var res := QuestManager.on_talk("elena")
	var tracked := false
	var sp := _game().get("spawner") as EntitySpawner
	for coord: Vector2i in sp._by_chunk:
		if (sp._by_chunk[coord] as Array).has(ans):
			tracked = true
	_note("Elena: «%s» · misión completada %s · oro %d -> %d · Anselmo deja de seguir %s y queda en Robledal %s" % [
			str(res[0].get("say", "")).substr(0, 40) + "..." if not res.is_empty() else "(nada)", QuestManager.is_done("escolta_anselmo"), gold0, p.gold,
			ans.follow_quest == "", tracked])
	if not QuestManager.is_done("escolta_anselmo") or p.gold < gold0 + 120 or ans.follow_quest != "" or not tracked:
		_fail("La escolta no terminó bien")
	var data := GameState.build_save_data()
	var flags: Dictionary = (data["world_changes"] as Dictionary).get("flags", {})
	if not flags.has("anselmo_escolta") or not flags.has("anselmo_llego"):
		_fail("Las banderas de la escolta no se guardan")
	_test_spider_assets()
	_go_mine()
	_next("mine_arrive")


# ---------------------------------------------------------------------------
# Mina de Hierronegro: arañas, veneno, seda, la reina y la misión de Garin
# ---------------------------------------------------------------------------

## Modelo, esqueleto y animaciones de las arañas (sin escena).
func _test_spider_assets() -> void:
	var rig := Rig.arachnid()
	var names := rig.bone_names()
	var verts := 0
	for v in 4:
		var mesh := CharacterModels.spider(v).build_skinned_mesh(names, ModelLibrary.model_material())
		if mesh.get_surface_count() > 0:
			verts += (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var lib := ArachnidAnims.library()
	var missing: Array[String] = []
	for an: StringName in lib.get_animation_list():
		var a := lib.get_animation(an)
		for ti in a.get_track_count():
			var bone := str(a.track_get_path(ti)).get_slice(":", 1)
			if not names.has(bone) and not missing.has(bone):
				missing.append(bone)
	var want := ["idle", "walk", "run", "alert", "attack_1", "attack_2", "shoot", "hit", "stun", "death"]
	var have := 0
	for w: String in want:
		if lib.has_animation(w):
			have += 1
	_note("Arañas: esqueleto de %d huesos, 4 variantes con %d vértices, animaciones %d/%d, pistas sin hueso: %s" % [names.size(), verts, have, want.size(), missing])
	if names.size() != 31 or verts < 4000 or have != want.size() or not missing.is_empty():
		_fail("El modelo o las animaciones de las arañas están incompletos")


func _mine_planner() -> StructurePlanner:
	return (_game().get("overworld_generator") as WorldGenerator).planner


func _go_mine() -> void:
	var pl := _mine_planner()
	var at := pl.mine_local(Vector3(12.5, 0.2, 1.5))
	var look := pl.mine_local(Vector3(12.5, 0.0, 9.0)) - at
	_player().teleport(at, rad_to_deg(atan2(-look.x, -look.z)))


func _test_mine_outside(p: Player) -> void:
	var pl := _mine_planner()
	var site := {}
	for st: Dictionary in pl.sites:
		if st["id"] == "mina_hierronegro":
			site = st
	var w := _game().get("world") as VoxelWorld
	var rail := w.block_at(pl.mine_local(Vector3(12.5, 0.1, 4.5)))
	var ore := 0
	for k in 40:
		var b := w.block_at(pl.mine_local(Vector3(4.5 + k % 16, 1.5 + k / 16, 13.5)))
		if b == BlockTypes.IRON_ORE:
			ore += 1
	var entrance: DungeonEntrance = null
	var props := {}
	for n in (_game().get("spawner") as Node).get_children():
		if n is DungeonEntrance and (n as DungeonEntrance).dungeon_id == "mina_hierronegro":
			entrance = n
	var spiders: Array[Enemy] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).data.id == "spider":
			spiders.append(e)
	var tob := _find_npc("tobias")
	var pos := pl.mine_local(Vector3(12.5, 0, 12.5))
	_note("Mina de Hierronegro en %s (%.0f m del castillo), raíles en la bocamina: %s, entrada: %s, Tobías: %s, arañas fuera: %d" % [
			site.get("pos", Vector2.ZERO), (site.get("pos", Vector2.ZERO) as Vector2).distance_to(Vector2(pl.castle_origin.x, pl.castle_origin.z)),
			rail == BlockTypes.RAIL or rail == BlockTypes.RAIL + 1, entrance != null, tob != null, spiders.size()])
	if site.is_empty() or entrance == null or tob == null or not (rail == BlockTypes.RAIL or rail == BlockTypes.RAIL + 1):
		_fail("La bocamina de Hierronegro está incompleta")
	var _u := [ore, props, pos]
	_shot("mine_entrance")
	# Misión de Garin: aceptar y hablar con Tobías
	if QuestManager.can_offer("hierro_penalba"):
		QuestManager.accept("hierro_penalba")
	var res := QuestManager.on_talk("tobias")
	_note("Hierro para Peñalba: aceptada %s, Tobías: «%s» · etapa: %s" % [QuestManager.is_active("hierro_penalba"),
			str(res[0].get("say", "")).substr(0, 40) + "..." if not res.is_empty() else "(nada)", QuestManager.stage_text("hierro_penalba")])
	if not QuestManager.is_active("hierro_penalba") or int(GameState.quests["hierro_penalba"]["stage"]) != 1:
		_fail("La misión de la mina no avanzó al hablar con Tobías")
	# Una araña de la bocamina muerde al jugador (sin bloquear): veneno
	p.stats.heal(p.stats.max_health)
	_enemy = null
	if not spiders.is_empty():
		_enemy = spiders[0]
		for sp2 in spiders:
			sp2.make_aware()
	_next("mine_poison")


func _mine_poison_step(p: Player) -> void:
	var sp := _enemy as Enemy
	if p.stats.health < p.stats.max_health * 0.4:
		p.stats.heal(60.0)
	if sp == null or not is_instance_valid(sp):
		_fail("No hay arañas en la bocamina para probar el veneno")
		_enter_mine(p)
		return
	var to := sp.global_position - p.global_position
	to.y = 0.0
	p._yaw = atan2(-to.x, -to.z)
	if p.stats.effects.has("poison"):
		var hp := p.stats.health
		_note("Mordedura de araña tras %.1f s: estado «%s» (potencia %.1f/s), salud %.0f; la araña %s" % [_t,
				Stats.EFFECT_NAMES["poison"], float(p.stats.effects["poison"]["power"]), hp, sp.data.display_name])
		GameState.give_item(p, {"id": "potion_cure", "count": 1})
		GameState.use_item(p, "potion_cure")
		_note("Antídoto: veneno curado %s" % (not p.stats.effects.has("poison")))
		if p.stats.effects.has("poison"):
			_fail("El antídoto no cura el veneno")
		_shot("spider_bite")
		# Ahora a espadazos: impactos reales contra un cuerpo bajo y ancho
		_hits_start = p.stat_hits
		_attacks = 0
		_next("mine_fight")
	elif _t > 25.0:
		_fail("Ninguna araña envenenó al jugador en 25 s")
		_enter_mine(p)


func _mine_fight_step(p: Player, delta: float) -> void:
	var sp := _enemy as Enemy
	if p.stats.health < p.stats.max_health * 0.4:
		p.stats.heal(60.0)
	p.stats.clear_effect("poison")
	if sp == null or not is_instance_valid(sp):
		_fail("La araña desapareció durante el combate")
		_enter_mine(p)
		return
	var tb := sp.global_position - p.global_position
	tb.y = 0.0
	p._yaw = atan2(-tb.x, -tb.z)
	p._pitch = deg_to_rad(-14.0)
	if tb.length() > 1.6:
		Input.action_press("move_forward")
	else:
		Input.action_release("move_forward")
	if fmod(_t, 0.7) < delta and tb.length() < 2.4:
		Input.action_press("attack")
		_attacks += 1
	else:
		Input.action_release("attack")
	if not sp.is_alive():
		Input.action_release("move_forward")
		Input.action_release("attack")
		var silk0 := GameState.item_count("spider_silk") + GameState.item_count("spider_venom")
		sp.interact(p)
		_note("Araña abatida a espadazos: %d ataques, %d impactos en %.1f s; despojos %d -> %d" % [_attacks, p.stat_hits - _hits_start, _t,
				silk0, GameState.item_count("spider_silk") + GameState.item_count("spider_venom")])
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			if en.is_alive():
				en.take_hit(9999.0, {"attacker": p, "damage_type": "blunt"})
		_enter_mine(p)
	elif _t > 40.0:
		Input.action_release("move_forward")
		Input.action_release("attack")
		_fail("Combate con la araña demasiado largo: vida %.0f/%.0f, impactos %d" % [sp.stats.health, sp.stats.max_health, p.stat_hits - _hits_start])
		_enter_mine(p)


func _enter_mine(p: Player) -> void:
	p.stats.heal(p.stats.max_health)
	_return_ref = p.global_position
	_game().call("enter_dungeon", "mina_hierronegro", "selftest_mine")
	_next("in_mine")


func _test_mine_inside(p: Player) -> void:
	var dg := _game().get("generator") as DungeonGenerator
	var kinds := {}
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		kinds[en.data.id] = int(kinds.get(en.data.id, 0)) + 1
	var types := {}
	for e2: Dictionary in dg.entities:
		types[str(e2["type"])] = int(types.get(str(e2["type"]), 0)) + 1
	var w := _game().get("world") as VoxelWorld
	var rails := 0
	for t: Vector2i in dg.rail_tiles:
		var b := w.block_at(Vector3(t.x + 0.5, DungeonGenerator.FLOOR_Y + 0.1, t.y + 0.5))
		if b == BlockTypes.RAIL or b == BlockTypes.RAIL + 1:
			rails += 1
	var boss := false
	for e3: Dictionary in dg.entities:
		if str(e3.get("enemy", "")) == "spider_queen":
			boss = true
	_note("Mina '%s' (verificada %s): enemigos %s, jefa en el plano %s, raíles %d/%d, vigas %d, postes %d, entidades %s; misión: %s" % [
			dg.display_name, dg.verified, kinds, boss, rails, dg.rail_tiles.size(), dg.timber_beams.size(), dg.timber_posts.size(),
			types, QuestManager.stage_text("hierro_penalba")])
	if not dg.verified or not boss or dg.rail_tiles.is_empty() or dg.timber_beams.is_empty() or not types.has("mine_lamp"):
		_fail("La mina no se generó con sus galerías, raíles, entibado o la reina")
	if absf(p.global_position.y - DungeonGenerator.FLOOR_Y) > 0.6:
		_fail("El jugador no aparece sobre el suelo de la mina (y=%.2f)" % p.global_position.y)
	if int(GameState.quests["hierro_penalba"]["stage"]) != 2:
		_fail("Entrar en la mina no avanzó la misión")
	_shot("mine_inside")
	# Una escupidora a unos metros: la seda enreda (ralentiza)
	var sp := _game().get("spawner") as EntitySpawner
	var er: Rect2i = dg.rooms[dg.entrance_index]["rect"]
	_enemy = sp.spawn_summon("spider_spitter", Vector3(er.position.x + er.size.x * 0.5 + 1.0, DungeonGenerator.FLOOR_Y, er.position.y + 1.0), 180.0,
			"selftest/spitter")
	if _enemy:
		(_enemy as Enemy).hold_position = true
		(_enemy as Enemy).make_aware()
	_next("mine_web")


func _mine_web_step(p: Player) -> void:
	var sp := _enemy as Enemy
	if p.stats.health < p.stats.max_health * 0.4:
		p.stats.heal(60.0)
	if sp == null or not is_instance_valid(sp):
		_fail("No se pudo crear la araña escupidora")
		_go_mine_boss(p)
		return
	var to := sp.global_position - p.global_position
	to.y = 0.0
	p._yaw = atan2(-to.x, -to.z)
	if fmod(_t, 4.0) < get_process_delta_time():
		_note("  (escupidora: estado %d, alerta %s, visión %s, a %.1f m, pos %s, jugador %s)" % [sp.state, sp.is_aware(), sp._line_of_sight(),
				to.length(), sp.global_position, p.global_position])
	if p.stats.effects.has("web"):
		_note("Escupitajo de seda tras %.1f s: «%s», velocidad x%.2f" % [_t, Stats.EFFECT_NAMES["web"], p.stats.slow_factor()])
		if p.stats.slow_factor() >= 0.99:
			_fail("La seda no ralentiza al jugador")
		sp.take_hit(9999.0, {"attacker": p, "damage_type": "blunt"})
		_go_mine_boss(p)
	elif _t > 25.0:
		_fail("La araña escupidora no alcanzó al jugador con su seda en 25 s (estado %d)" % sp.state)
		_go_mine_boss(p)


func _go_mine_boss(p: Player) -> void:
	var dg := _game().get("generator") as DungeonGenerator
	var brect: Rect2i = dg.rooms[dg.boss_index]["rect"]
	p.stats.heal(p.stats.max_health)
	p.teleport(Vector3(brect.get_center().x + 0.5, DungeonGenerator.FLOOR_Y + 0.1, brect.end.y - 1.5), 0.0)
	_next("mine_boss")


func _test_mine_boss(p: Player) -> void:
	var queen: Enemy = null
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if (e as Enemy).data.id == "spider_queen":
			queen = e
	if queen == null:
		_fail("La Reina Tejedora no apareció en su nido")
		_game().call("exit_dungeon")
		_next("mine_exit")
		return
	_shot("mine_nest")
	var brood := func() -> int:
		var n := 0
		for e2: Node in get_tree().get_nodes_in_group("enemies"):
			if (e2 as Enemy).data.id == "spiderling" and (e2 as Enemy).is_alive():
				n += 1
		return n
	var b0: int = brood.call()
	queen.take_hit(queen.stats.max_health * 0.4, {"attacker": p, "damage_type": "blunt", "stagger": 0.0})
	var b1: int = brood.call()
	queen.take_hit(queen.stats.max_health * 0.35, {"attacker": p, "damage_type": "blunt", "stagger": 0.0})
	var b2: int = brood.call()
	var res := ""
	var guard := 0
	while queen.is_alive() and guard < 20:
		res = queen.take_hit(9999.0, {"attacker": p, "damage_type": "blunt"})
		guard += 1
	queen.interact(p)
	_note("Reina Tejedora (escala %.1f): crías %d -> %d -> %d al bajar del 66%% y del 33%%; muerta: %s; colmillo: %d; bandera mina_limpia: %s; misión: %s" % [
			queen.data.model_scale, b0, b1, b2, not queen.is_alive(), GameState.item_count("queen_fang"), GameState.has_flag("mina_limpia"),
			QuestManager.stage_text("hierro_penalba")])
	if b1 <= b0 or b2 <= b1:
		_fail("La reina no llamó a sus crías al ser herida")
	if queen.is_alive() or GameState.item_count("queen_fang") < 1 or not GameState.has_flag("mina_limpia"):
		_fail("La muerte de la reina no se registró (botín o bandera)")
	_game().call("exit_dungeon")
	_next("mine_exit")


func _test_mine_reward(p: Player) -> void:
	var gold0 := p.gold
	var rep0 := GameState.reputation("penalba")
	var res := QuestManager.on_talk("garin")
	var arms: Array[String] = []
	for w0: WeaponData in p.weapons:
		arms.append(w0.id)
	_note("Garin: «%s» · misión completada %s · oro %d -> %d · armas %s · reputación Peñalba %d -> %d" % [
			str(res[0].get("say", "")).substr(0, 40) + "..." if not res.is_empty() else "(nada)", QuestManager.is_done("hierro_penalba"),
			gold0, p.gold, arms, rep0, GameState.reputation("penalba")])
	var sword := false
	for w: WeaponData in p.weapons:
		if w.id == "sword_penalba":
			sword = true
	if not QuestManager.is_done("hierro_penalba") or not sword or p.gold < gold0 + 180:
		_fail("La misión de la mina no terminó con su recompensa")
	_finish()


## Lleva al jugador a la plaza de un lugar de la región.
func _goto_site(site_id: String) -> void:
	var wg := _game().get("overworld_generator") as WorldGenerator
	for site: Dictionary in wg.planner.sites:
		if site["id"] == site_id:
			var sp: Vector2 = site["pos"]
			var pos := Vector3(sp.x + 0.5, wg.height_at(int(sp.x), int(sp.y)) + 1.2, sp.y + 0.5)
			if site_id == "inn_lobo":
				pos.x -= 4.0   # junto al pozo, no encima
			_player().teleport(pos, 0.0)
			return
	_fail("Lugar desconocido: " + site_id)


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
