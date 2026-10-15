class_name NPC
extends CharacterBody3D
## Personaje no jugador con nombre: horario de día/noche (trabajar en su
## puesto, patrullar o volver a casa), animaciones contextuales (hablar,
## trabajar, saludar) y conversación con el jugador.

const GRAVITY := 15.0

var npc_id: String = ""
var data: Dictionary = {}
var work_pos := Vector3.ZERO
var work_yaw := 0.0
var home_pos := Vector3.INF
var patrol: Array[Vector3] = []
var player: Player
var talking := false

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


func setup(id: String, spawn: Dictionary, p: Player) -> void:
	npc_id = id
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
	_rng.seed = hash(id)


## Encerrado tras una puerta que aún no se ha abierto.
func is_caged() -> bool:
	return captive_flag != "" and not GameState.has_flag(captive_flag)


## Sigue cautivo (aunque la jaula esté abierta) hasta que se le rescata.
func is_captive() -> bool:
	return captive_flag != "" and not _leaving and (rescued_flag == "" or not GameState.has_flag(rescued_flag))


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
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
	var model := CharacterModels.human(data.get("look", {}), hash(npc_id))
	var mi := MeshInstance3D.new()
	mi.mesh = model.build_skinned_mesh(rig.bone_names(), ModelLibrary.model_material())
	mi.skin = rig.create_skin()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	if npc_id == "oswin":
		var wa := BoneAttachment3D.new()
		wa.bone_name = "hand.R"
		skeleton.add_child(wa)
		var hm := MeshInstance3D.new()
		hm.mesh = ModelLibrary.weapon_mesh("mace", false)
		hm.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02)).scaled_local(Vector3.ONE * 0.55)
		wa.add_child(hm)
	elif npc_id == "rolf":
		var wa2 := BoneAttachment3D.new()
		wa2.bone_name = "hand.R"
		skeleton.add_child(wa2)
		var sm := MeshInstance3D.new()
		sm.mesh = ModelLibrary.weapon_mesh("sword", false)
		sm.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02))
		wa2.add_child(sm)
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.75, 0.45)
		_lantern.omni_range = 6.0
		_lantern.light_energy = 1.0
		_lantern.position = Vector3(-0.3, 1.2, -0.2)
		add_child(_lantern)
	var lib := HumanoidAnims.build_library("civilian")
	anim_tree = AnimationTree.new()
	root.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	anim_tree.add_animation_library("", lib)
	anim_tree.tree_root = HumanoidAnims.build_tree(lib, PackedStringArray(["talk", "work", "wave", "captive", "cheer"]))
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	global_position = work_pos
	rotation.y = work_yaw
	_last_pos = global_position


func display_name() -> String:
	return "%s (%s)" % [data.get("name", npc_id), data.get("role", "")]


func get_interaction_text() -> String:
	if _leaving:
		return ""
	return "[E] Hablar con %s" % display_name()


func interact(p: Node) -> void:
	var game := get_tree().current_scene
	if game and game.has_method("open_dialogue"):
		game.call("open_dialogue", self)
	else:
		Events.notify.emit("%s: %s" % [data.get("name", npc_id), (data.get("greet", ["..."]) as Array)[0]], "info")
	var _unused := p


func start_talking() -> void:
	talking = true
	if not is_caged():
		playback.travel("talk")


func stop_talking() -> void:
	talking = false
	if not is_caged():
		playback.travel("loco")


func _is_night() -> bool:
	var t := GameState.time_of_day
	return t >= 21.0 or t < 6.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if captive_flag != "" and _captive_update(delta):
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
