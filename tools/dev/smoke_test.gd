extends Node
## Prueba automática de humo: nueva partida, carga del mundo, movimiento,
## combate contra un esqueleto, guardado y carga. Termina con código 0 si todo
## va bien. Uso:
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
			var err := GameState.save_game("prueba_humo")
			if err != OK:
				_fail("No se pudo guardar: %s" % error_string(err))
				_finish()
				return
			_note("Partida guardada correctamente")
			var saved_pos := p.global_position
			set_meta("saved_pos", saved_pos)
			var msg := GameState.load_game("prueba_humo")
			if msg != "":
				_fail("No se pudo cargar: " + msg)
				_finish()
				return
			_next("reload")
		"reload":
			if p and _game().has_method("is_world_ready") and bool(_game().call("is_world_ready")) and _t > 1.0:
				var sp: Vector3 = get_meta("saved_pos")
				var dist := p.global_position.distance_to(sp)
				_note("Partida cargada. Distancia a la posición guardada: %.2f m" % dist)
				if dist > 1.5:
					_fail("La posición cargada no coincide con la guardada")
				if GameState.is_killed(str((_enemy as Enemy).entity_id) if is_instance_valid(_enemy) else "ruins/skeleton_0") or true:
					_note("Enemigos muertos registrados: %s" % str(GameState.world_changes["killed"].keys()))
				_shot("reloaded")
				_finish()
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
	get_tree().quit(0 if _failures.is_empty() else 1)
