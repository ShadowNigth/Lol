class_name NPC
extends CharacterBody3D
## Personaje no jugador con nombre: horario de día/noche (trabajar en su
## puesto, patrullar o volver a casa), animaciones contextuales (hablar,
## trabajar, saludar) y conversación con el jugador.
##
## Ley y orden (ver Law): los PNJ ven los delitos del jugador y lo denuncian;
## si les pegan huyen, y al quedarse sin salud caen inconscientes (los que
## tienen nombre nunca mueren) y se levantan al rato. Los guardias persiguen a
## quien tenga deudas con la Marca y le dan el alto; si hay pelea, el guardia
## se convierte en un Enemy con su mismo aspecto y equipo.
##
## Escolta: un PNJ cuya misión de escolta está activa sigue al jugador hasta
## el destino (ver QuestManager.escort_for).

const GRAVITY := 15.0
const KNOCKOUT_TIME := 30.0
const FLEE_TIME := 9.0
const PURSUE_SPEED := 3.9

var npc_id: String = ""
var entity_id: String = ""
var data: Dictionary = {}
var work_pos := Vector3.ZERO
var work_yaw := 0.0
var home_pos := Vector3.INF
var patrol: Array[Vector3] = []
var player: Player
var talking := false
var look_final: Dictionary = {}     # aspecto con el equipo ya aplicado (lo copia el guardia hostil)

var skeleton: Skeleton3D
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var _rng := RandomNumberGenerator.new()
var _target := Vector3.INF
var _patrol_i := 0
var _wait_t := 0.0
var _indoors := false
var _greeted := false
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _lantern: OmniLight3D
# Cautiverio (p. ej. Lina en la jaula de los Cuervos)
var captive_flag := ""       # bandera que abre su jaula
var rescued_flag := ""       # bandera de «rescatado»: se marcha a casa
var exit_path: Array[Vector3] = []   # ruta al quedar libre (puerta, campamento, fuera) antes de desaparecer
var _leaving := false
var _cheered := false
var _path_i := 0
# Ley y orden
var max_health := 60.0
var health := 60.0
var hostile_enemy: Enemy = null      # guardia peleando: el PNJ queda oculto mientras tanto
var _flee_t := 0.0
var _flee_from := Vector3.ZERO
var _knocked_t := 0.0
var _getting_up_t := 0.0
var _last_assault_ms := -100000
var _pursue := false
var _alert_pos := Vector3.INF
var _guard_think := 0.0
var _arrest_cd := 0.0
var _shout_cd := 0.0
# Escolta
var follow_quest := ""
var _escort_check := 0.0
var _follow_stuck := 0.0


func setup(id: String, spawn: Dictionary, p: Player) -> void:
	npc_id = id
	entity_id = str(spawn.get("id", "npc/" + id))
	data = NpcDB.get_npc(id)
	work_pos = spawn.get("pos", Vector3.ZERO)
	work_yaw = deg_to_rad(float(spawn.get("yaw", 0.0)))
	if spawn.has("home"):
		home_pos = spawn["home"]
	for q: Vector3 in spawn.get("patrol", []):
		patrol.append(q)
	var cap: Dictionary = spawn.get("captive", {})
	if not cap.is_empty():
		captive_flag = str(cap.get("flag", ""))
		rescued_flag = str(cap.get("rescued_flag", ""))
		for wp: Vector3 in cap.get("path", []):
			exit_path.append(wp)
	player = p
	_rng.seed = hash(entity_id)
	max_health = float(data.get("health", 90.0 if is_guard() else 55.0))
	health = max_health


## Encerrado tras una puerta que aún no se ha abierto.
func is_caged() -> bool:
	return captive_flag != "" and not GameState.has_flag(captive_flag)


## Sigue cautivo (aunque la jaula esté abierta) hasta que se le rescata.
func is_captive() -> bool:
	return captive_flag != "" and not _leaving and (rescued_flag == "" or not GameState.has_flag(rescued_flag))


func is_guard() -> bool:
	return bool(data.get("guard", false))


## Los PNJ con nombre son imprescindibles (quedan inconscientes, no mueren);
## los guardias genéricos pueden morir.
func is_essential() -> bool:
	return not bool(data.get("generic", false))


func is_knocked_out() -> bool:
	return _knocked_t > 0.0


func is_fleeing() -> bool:
	return _flee_t > 0.0


func is_alive() -> bool:
	return not is_knocked_out()


## Los PNJ nunca son «objetivo» del HUD: solo pelean convertidos en Enemy.
func is_hostile() -> bool:
	return false


func health_ratio() -> float:
	return health / maxf(max_health, 1.0)


## ¿Puede ver (y denunciar) lo que pasa a su alrededor?
func can_witness() -> bool:
	return visible and not _indoors and not is_knocked_out() and not is_caged() and not _leaving \
			and hostile_enemy == null and process_mode != Node.PROCESS_MODE_DISABLED and is_inside_tree()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	var root := Node3D.new()
	root.name = "Model"
	add_child(root)
	var rig := Rig.humanoid()
	skeleton = rig.create_skeleton()
	root.add_child(skeleton)
	var look: Dictionary = data.get("look", {})
	if bool(data.get("generic", false)):
		look = NpcDB.vary_look(look, entity_id)
	var gear: Dictionary = data.get("gear", {})
	look_final = CharacterModels.look_with_gear(look, gear)
	var model := CharacterModels.human(look_final, hash(entity_id))
	var mi := MeshInstance3D.new()
	mi.mesh = model.build_skinned_mesh(rig.bone_names(), ModelLibrary.model_material())
	mi.skin = rig.create_skin()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	_attach_gear(gear)
	var lib := HumanoidAnims.build_library("civilian")
	anim_tree = AnimationTree.new()
	root.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	anim_tree.add_animation_library("", lib)
	anim_tree.tree_root = HumanoidAnims.build_tree(lib, PackedStringArray(["talk", "work", "wave", "captive", "cheer", "hit", "knockout", "getup"]))
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	global_position = work_pos
	rotation.y = work_yaw
	_last_pos = global_position


## Arma en la mano, escudo al brazo, herramienta de trabajo o farol nocturno,
## según los datos del personaje (el equipo de cuerpo ya va en el modelo).
func _attach_gear(gear: Dictionary) -> void:
	var held := str(gear.get("weapon", data.get("held", "")))
	if held != "":
		var wa := BoneAttachment3D.new()
		wa.bone_name = "hand.R"
		skeleton.add_child(wa)
		var hm := MeshInstance3D.new()
		hm.mesh = ModelLibrary.weapon_mesh(held, false)
		var t := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02))
		hm.transform = t.scaled_local(Vector3.ONE * float(data.get("held_scale", 1.0)))
		wa.add_child(hm)
	var off := str(gear.get("offhand", ""))
	if off != "":
		var sa := BoneAttachment3D.new()
		sa.bone_name = "forearm.L"
		skeleton.add_child(sa)
		var sm := MeshInstance3D.new()
		sm.mesh = ModelLibrary.weapon_mesh(NpcDB.shield_model(off), false)
		sm.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.09, -0.14, 0.0))
		sa.add_child(sm)
	if bool(data.get("lantern", false)):
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.75, 0.45)
		_lantern.omni_range = 6.0
		_lantern.light_energy = 1.0
		_lantern.position = Vector3(-0.3, 1.2, -0.2)
		add_child(_lantern)


func display_name() -> String:
	return "%s (%s)" % [data.get("name", npc_id), data.get("role", "")]


func get_interaction_text() -> String:
	if _leaving or is_knocked_out() or is_fleeing() or _getting_up_t > 0.0:
		return ""
	return "[E] Hablar con %s" % display_name()


func interact(p: Node) -> void:
	if is_knocked_out() or is_fleeing():
		return
	var game := get_tree().current_scene
	if game and game.has_method("open_dialogue"):
		game.call("open_dialogue", self)
	else:
		Events.notify.emit("%s: %s" % [data.get("name", npc_id), (data.get("greet", ["..."]) as Array)[0]], "info")
	var _unused := p


func start_talking() -> void:
	talking = true
	_pursue = false
	if not is_caged():
		playback.travel("talk")


func stop_talking() -> void:
	talking = false
	if not is_caged():
		playback.travel("loco")


func _is_night() -> bool:
	var t := GameState.time_of_day
	return t >= 21.0 or t < 6.0


func _world() -> VoxelWorld:
	var sp := get_parent() as EntitySpawner
	return sp.world if sp else null


func _physics_process(delta: float) -> void:
	var w := _world()
	if w and not w.is_chunk_loaded_at(global_position):
		# Sin suelo cargado bajo sus pies: quieto (un acompañante se reúne con el jugador)
		if follow_quest != "" and player and w.is_chunk_loaded_at(player.global_position):
			_catch_up()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	_arrest_cd = maxf(_arrest_cd - delta, 0.0)
	_shout_cd = maxf(_shout_cd - delta, 0.0)
	if _knocked_update(delta):
		return
	if captive_flag != "" and _captive_update(delta):
		return
	if not talking and _flee_t > 0.0:
		_flee_update(delta)
		return
	if not talking and is_guard() and player and _guard_update(delta):
		return
	if not talking and _follow_update(delta):
		return
	var move := Vector3.ZERO
	var speed := 1.5
	if talking and player:
		_face(player.global_position - global_position, delta, 6.0)
	else:
		var goal := _current_goal()
		if goal != Vector3.INF:
			var d := goal - global_position
			d.y = 0.0
			if d.length() > 0.5:
				move = d.normalized()
				_face(d, delta, 5.0)
			else:
				_arrived(delta)
	if move.length() > 0.1 and playback.get_current_node() != &"loco":
		playback.travel("loco")
	velocity.x = lerpf(velocity.x, move.x * speed, clampf(delta * 6.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, move.z * speed, clampf(delta * 6.0, 0.0, 1.0))
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	anim_tree.set("parameters/loco/blend_position", clampf(hs / speed, 0.0, 1.0))
	# Atascos: si no avanza, se recoloca en su destino (evita quedarse trabado)
	if move.length() > 0.1 and global_position.distance_to(_last_pos) < 0.2 * delta:
		_stuck_t += delta
		if _stuck_t > 6.0:
			_stuck_t = 0.0
			var g := _current_goal()
			if g != Vector3.INF:
				global_position = g
				reset_physics_interpolation()
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	# Saludo al acercarse el jugador
	if player and not talking and not _greeted and global_position.distance_to(player.global_position) < 4.0:
		_greeted = true
		if _rng.randf() < 0.5:
			playback.travel("wave")
	elif player and global_position.distance_to(player.global_position) > 10.0:
		_greeted = false
	if _lantern:
		_lantern.visible = _is_night()
	if health < max_health:
		health = minf(max_health, health + delta * 0.5)


## Comportamiento de cautivo. Devuelve true si se ha encargado del fotograma.
func _captive_update(delta: float) -> bool:
	if is_caged():
		# Quieto en la jaula, cabizbajo; mira al jugador si se acerca
		if playback.get_current_node() != &"captive":
			playback.travel("captive")
		if player and global_position.distance_to(player.global_position) < 5.0:
			_face(player.global_position - global_position, delta, 2.0)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return true
	if rescued_flag != "" and GameState.has_flag(rescued_flag) and not _leaving and not talking:
		_leaving = true
		_cheered = false
	if not _leaving:
		return false
	# Libre: celebra, sale del campamento y se pierde de vista camino de casa
	if not _cheered:
		_cheered = true
		playback.travel("cheer")
		_wait_t = 0.0
	_wait_t += delta
	if _wait_t < 1.7:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return true
	if _path_i >= exit_path.size() or _wait_t > 60.0:
		queue_free()
		return true
	var goal := exit_path[_path_i]
	var d := goal - global_position
	d.y = 0.0
	if d.length() < 0.8:
		_path_i += 1
		_stuck_t = 0.0
		return true
	if playback.get_current_node() != &"loco":
		playback.travel("loco")
	_face(d, delta, 5.0)
	var dir := d.normalized()
	velocity.x = dir.x * 2.6
	velocity.z = dir.z * 2.6
	move_and_slide()
	anim_tree.set("parameters/loco/blend_position", 1.4)
	# Si algo la bloquea, salta al siguiente punto de la ruta
	if global_position.distance_to(_last_pos) < 0.4 * delta:
		_stuck_t += delta
		if _stuck_t > 3.0:
			_stuck_t = 0.0
			global_position = goal
			reset_physics_interpolation()
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return true


func _current_goal() -> Vector3:
	if _is_night() and home_pos != Vector3.INF:
		return home_pos
	if not patrol.is_empty():
		return patrol[_patrol_i]
	return work_pos


func _arrived(delta: float) -> void:
	if _is_night() and home_pos != Vector3.INF:
		# Entra en casa hasta el amanecer
		if not _indoors:
			_indoors = true
			visible = false
			$CollisionShape3D.disabled = true
		return
	if _indoors:
		_indoors = false
		visible = true
		$CollisionShape3D.disabled = false
	if not patrol.is_empty():
		_wait_t += delta
		if _wait_t > 4.0:
			_wait_t = 0.0
			_patrol_i = (_patrol_i + 1) % patrol.size()
		return
	_face_yaw(work_yaw, delta, 3.0)
	var anim := str(data.get("work_anim", "idle"))
	if anim != "idle" and playback.get_current_node() == &"loco":
		_wait_t += delta
		if _wait_t > 1.0:
			_wait_t = 0.0
			playback.travel(anim)


func _face(d: Vector3, delta: float, speed: float) -> void:
	if Vector2(d.x, d.z).length() > 0.01:
		_face_yaw(atan2(-d.x, -d.z), delta, speed)


func _face_yaw(yaw: float, delta: float, speed: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * speed, 0.0, 1.0))


## Movimiento sencillo con desvío si hay un obstáculo delante.
func _move_towards(dir: Vector3, speed: float, delta: float) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.01:
		velocity.x = lerpf(velocity.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	else:
		d = d.normalized()
		if _blocked(d):
			for ang: float in [40.0, -40.0, 80.0, -80.0, 120.0, -120.0]:
				var alt := d.rotated(Vector3.UP, deg_to_rad(ang))
				if not _blocked(alt):
					d = alt
					break
		_face(d, delta, 7.0)
		velocity.x = lerpf(velocity.x, d.x * speed, clampf(delta * 8.0, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, d.z * speed, clampf(delta * 8.0, 0.0, 1.0))
	if playback.get_current_node() != &"loco":
		playback.travel("loco")
	move_and_slide()
	anim_tree.set("parameters/loco/blend_position", clampf(Vector2(velocity.x, velocity.z).length() / 2.0, 0.0, 2.0))


func _blocked(dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 0.9, 1, [get_rid()])
	return not space.intersect_ray(q).is_empty()


# ---------------------------------------------------------------------------
# Golpes, huida e inconsciencia
# ---------------------------------------------------------------------------

func take_hit(amount: float, info: Dictionary) -> String:
	if is_knocked_out() or _leaving or not visible:
		return "dead"
	var attacker := info.get("attacker", null) as Node3D
	var by_player := attacker != null and attacker == player
	var pos: Vector3 = info.get("position", global_position + Vector3(0, 1.2, 0))
	var normal: Vector3 = info.get("normal", Vector3.UP)
	HitFX.spawn(get_tree().current_scene, "blood", pos, normal)
	Audio.play_3d("hit_flesh", pos, 0.0)
	health -= amount * (0.6 if is_guard() else 1.0)
	talking = false
	if is_guard():
		if not by_player:
			# Una flecha perdida de un salteador no le enfrenta con el jugador
			if health <= 0.0:
				health = 0.0
				_knock_out()
				return "killed"
			playback.travel("hit")
			return "hit"
		Law.mark_resisted()
		Law.report("agresion_guardia", self)
		if health <= 0.0 and is_essential():
			_knock_out()
			return "killed"
		Law.make_hostile(self)
		return "hit"
	Audio.play_3d("npc_hurt_f" if bool(data.get("look", {}).get("female", false)) else "npc_hurt", global_position + Vector3(0, 1.6, 0), -2.0)
	if by_player:
		var now := Time.get_ticks_msec()
		if now - _last_assault_ms > 10000:
			Law.report("agresion", self)
		_last_assault_ms = now
	if health <= 0.0:
		health = 0.0
		_knock_out()
		if by_player:
			Law.report("agresion_grave", self)
		return "killed"
	playback.travel("hit")
	_start_flee(attacker.global_position if attacker else pos)
	return "hit"


func _knock_out() -> void:
	_knocked_t = KNOCKOUT_TIME
	_flee_t = 0.0
	_pursue = false
	talking = false
	collision_layer = 0
	playback.travel("knockout")
	Audio.play_3d("bandit_death" if is_guard() else "npc_scream", global_position + Vector3(0, 1.2, 0), -3.0)
	Events.notify.emit("%s cae inconsciente." % str(data.get("name", npc_id)), "combat")


## Inconsciente en el suelo y, al despertar, se levanta. True si se encarga.
func _knocked_update(delta: float) -> bool:
	if _knocked_t > 0.0:
		_knocked_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _knocked_t <= 0.0:
			_knocked_t = 0.0
			_getting_up_t = 1.7
			health = max_health * 0.5
			collision_layer = 4
			playback.travel("getup")
		return true
	if _getting_up_t > 0.0:
		_getting_up_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _getting_up_t <= 0.0 and player and global_position.distance_to(player.global_position) < 12.0 and not is_guard():
			_start_flee(player.global_position)
		return true
	return false


func _start_flee(from: Vector3) -> void:
	if is_guard():
		return
	_flee_t = FLEE_TIME
	_flee_from = from
	if _shout_cd <= 0.0:
		_shout_cd = 12.0
		Audio.play_3d("npc_scream", global_position + Vector3(0, 1.6, 0), -1.0)
		Events.notify.emit("%s: «¡Socorro! ¡Guardias!»" % str(data.get("name", npc_id)), "warning")


func _flee_update(delta: float) -> void:
	_flee_t -= delta
	var from := player.global_position if player else _flee_from
	var away := global_position - from
	away.y = 0.0
	if away.length() > 22.0:
		_flee_t = minf(_flee_t, 0.5)
	_move_towards(away, 4.2, delta)


## Ha visto un delito del jugador: los civiles huyen de la violencia.
func witness_crime(_kind: String, where: Vector3, violent: bool) -> void:
	if is_guard():
		alert_guard(where)
		return
	if violent:
		_start_flee(where)
	elif _shout_cd <= 0.0:
		_shout_cd = 12.0
		Audio.play_3d("npc_scream", global_position + Vector3(0, 1.6, 0), -4.0)
		Events.notify.emit("%s: «¡Al ladrón!»" % str(data.get("name", npc_id)), "warning")


# ---------------------------------------------------------------------------
# Guardias: persecución, alto y pelea
# ---------------------------------------------------------------------------

## Un testigo ha dado la voz de alarma cerca: va a ver qué pasa.
func alert_guard(where: Vector3) -> void:
	if not is_guard() or is_knocked_out() or hostile_enemy != null:
		return
	_alert_pos = where
	_guard_think = 0.0


## Devuelve true si el guardia está ocupado con la ley este fotograma.
func _guard_update(delta: float) -> bool:
	_guard_think -= delta
	if _guard_think <= 0.0:
		_guard_think = 0.25
		var wanted := Law.is_wanted()
		var same_level := absf(player.global_position.y - global_position.y) < 3.0
		var sees := (wanted or Law.resisted()) and same_level and Law.npc_sees(self, player, 22.0)
		if sees and Law.resisted():
			Law.make_hostile(self)
			return true
		if sees and wanted:
			if not _pursue and _shout_cd <= 0.0:
				_shout_cd = 15.0
				Audio.play_3d("guard_halt", global_position + Vector3(0, 1.6, 0), 0.0)
				Events.notify.emit("%s: «¡Alto en nombre de la Marca!»" % str(data.get("name", npc_id)), "warning")
			_pursue = true
			_alert_pos = Vector3.INF
		elif _pursue and (not wanted or global_position.distance_to(player.global_position) > 45.0 or player.is_dead):
			_pursue = false
		if not wanted and not Law.resisted():
			_pursue = false
			_alert_pos = Vector3.INF
	if not _pursue and _alert_pos == Vector3.INF:
		return false
	var goal := player.global_position if _pursue else _alert_pos
	var d := goal - global_position
	d.y = 0.0
	if _pursue and d.length() < 2.2:
		_face(d, delta, 8.0)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _arrest_cd <= 0.0 and player.controls_enabled and not player.is_dead:
			_arrest_cd = 8.0
			var game := get_tree().current_scene
			if game and game.has_method("open_arrest"):
				game.call("open_arrest", self)
		return true
	if not _pursue and d.length() < 1.5:
		_alert_pos = Vector3.INF
		return false
	_move_towards(d, PURSUE_SPEED, delta)
	if global_position.distance_to(_last_pos) < 0.3 * delta:
		_stuck_t += delta
		if _stuck_t > 5.0:
			_stuck_t = 0.0
			_alert_pos = Vector3.INF
			_pursue = false
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return true


## Tras la detención (pagada o cumplida) vuelve a su puesto.
func end_arrest() -> void:
	_pursue = false
	_alert_pos = Vector3.INF
	_arrest_cd = 4.0


## Lo sustituye un Enemy (ver Law.make_hostile): se oculta y deja de actuar.
func hide_for_hostile(e: Enemy) -> void:
	hostile_enemy = e
	_pursue = false
	_alert_pos = Vector3.INF
	talking = false
	visible = false
	collision_layer = 0
	$CollisionShape3D.disabled = true
	process_mode = Node.PROCESS_MODE_DISABLED


## Vuelve el PNJ (donde estaba el Enemy) con la salud que le quede.
func restore_from_hostile(pos: Vector3, yaw: float, ratio: float, knocked_out: bool) -> void:
	hostile_enemy = null
	global_position = pos
	rotation.y = yaw
	reset_physics_interpolation()
	visible = true
	$CollisionShape3D.disabled = false
	collision_layer = 4
	health = max_health * clampf(ratio, 0.0, 1.0)
	process_mode = Node.PROCESS_MODE_INHERIT
	_last_pos = global_position
	if knocked_out:
		health = 0.0
		_knock_out()
	else:
		playback.travel("loco")


# ---------------------------------------------------------------------------
# Escolta: sigue al jugador hasta el destino de la misión
# ---------------------------------------------------------------------------

func _follow_update(delta: float) -> bool:
	_escort_check -= delta
	if _escort_check <= 0.0:
		_escort_check = 0.5
		var q := QuestManager.escort_for(npc_id)
		if q.is_empty():
			follow_quest = ""
		else:
			if follow_quest == "":
				# Ya no pertenece al chunk donde apareció: viaja con el jugador
				var sp0 := get_parent() as EntitySpawner
				if sp0:
					sp0.detach_node(self)
				_indoors = false
				visible = true
				$CollisionShape3D.disabled = false
			follow_quest = str(q["quest"])
			# ¿Hemos llegado?
			var gen := _overworld_generator()
			if gen and not gen.is_interior():
				var here := gen.planner.location_id_at(global_position.x, global_position.z)
				if here == str(q["to"]):
					QuestManager.on_escort_arrived(npc_id, here)
					follow_quest = ""
					work_pos = global_position
					work_yaw = rotation.y
					home_pos = Vector3.INF
					patrol.clear()
					var sp := get_parent() as EntitySpawner
					if sp:
						sp.track_node(self)
					return false
	if follow_quest == "" or player == null:
		return false
	var to := player.global_position - global_position
	var dist := Vector2(to.x, to.z).length()
	# Muy lejos o atascado: se reúne con el jugador (le sigue «por otro camino»)
	if dist > 30.0 or _follow_stuck > 5.0 or absf(to.y) > 6.0 and dist > 6.0:
		_follow_stuck = 0.0
		_catch_up()
		return true
	if dist > 2.6:
		_move_towards(to, 1.6 if dist < 6.0 else 4.2, delta)
		if global_position.distance_to(_last_pos) < 0.25 * delta:
			_follow_stuck += delta
		else:
			_follow_stuck = 0.0
	else:
		_follow_stuck = 0.0
		_face(to, delta, 4.0)
		velocity.x = lerpf(velocity.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		move_and_slide()
		anim_tree.set("parameters/loco/blend_position", 0.0)
	_last_pos = global_position
	return true


func _catch_up() -> void:
	var sp := get_parent() as EntitySpawner
	var back := -player.look_direction()
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3(0, 0, 1)
	var pos := player.global_position + back.normalized() * 2.2
	if sp:
		pos = sp.find_free_spot(pos, 0.3, 1.8)
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_last_pos = global_position


func _overworld_generator() -> WorldGenerator:
	var game := get_tree().current_scene
	if game and "generator" in game:
		return game.get("generator") as WorldGenerator
	return null
