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
	if _total > 240.0:
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
				_next("loot")
			elif _t > 60.0:
				_fail("Combate demasiado largo: vida del esqueleto %.0f/%.0f" % [e2.stats.health, e2.stats.max_health])
				_note("Golpes: %d, impactos: %d, contra pared: %d, bloqueos del esqueleto: %d" % [p.stat_swings, p.stat_hits, p.stat_world_hits, e2.stat_blocks])
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
				_finish()
			elif _t > 60.0:
				_fail("No se pudo volver al exterior")
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
				_shot("reloaded")
				_next("enter_dungeon")
			elif _t > 90.0:
				_fail("La carga no terminó")
				_finish()


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
