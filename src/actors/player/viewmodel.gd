class_name Viewmodel
extends Node3D
## Brazos y arma en primera persona: esqueleto con piel, IK de dos huesos,
## animaciones por arma con fundidos (AnimationPlayer) y capas procedurales
## (balanceo al caminar, inercia de la mirada, aterrizajes, retroceso junto a
## paredes). Debe ser hijo de la Camera3D del jugador.

signal action_finished(anim_name: String)

const SHOULDER_R := Vector3(0.21, -0.28, 0.12)
const SHOULDER_L := Vector3(-0.21, -0.28, 0.12)
const L_UPPER := 0.27
const L_FORE := 0.26
const VIEWMODEL_FOV := 72.0
const GRIP_OFFSET := Vector3(-0.012, -0.055, -0.01)

var kind: String = "sword"
var weapon_id: String = "sword"
var offhand_id: String = ""
var skeleton: Skeleton3D
var anim: AnimationPlayer
var anim_left: AnimationPlayer
var hand_r: Node3D
var hand_l: Node3D
var ik: ArmIK
var _arms_mesh: MeshInstance3D
var _attach_r: BoneAttachment3D
var _attach_l: BoneAttachment3D
var _weapon_r: MeshInstance3D
var _weapon_l: MeshInstance3D
var _bow_string: MeshInstance3D
var _sway := Vector2.ZERO
var _sway_target := Vector2.ZERO
var _bob_time := 0.0
var _bob_amount := 0.0
var _land_offset := 0.0
var _land_vel := 0.0
var _pullback := 0.0
var _crouch := 0.0
var _strafe_roll := 0.0
var _base_anim := ""
var _action := ""
var _left_action := ""
var _left_base := ""
var _blocking := false
var _dead := false
var _lowered := false


func _ready() -> void:
	_build()
	set_weapon("sword", "sword", "")


func _build() -> void:
	var rig := Rig.new()
	rig.add("root", "", Vector3.ZERO)
	for side: Array in [["R", SHOULDER_R], ["L", SHOULDER_L]]:
		var n: String = side[0]
		var sh: Vector3 = side[1]
		rig.add("upper_arm." + n, "root", sh)
		rig.add("forearm." + n, "upper_arm." + n, sh + Vector3(0, -L_UPPER, 0))
		rig.add("hand." + n, "forearm." + n, sh + Vector3(0, -L_UPPER - L_FORE, 0))
	skeleton = rig.create_skeleton()
	add_child(skeleton)
	var model := CharacterModels.player_arms()
	for p in model.parts:
		p.origin = rig.rest_position(p.bone)
	_arms_mesh = MeshInstance3D.new()
	_arms_mesh.name = "Arms"
	_arms_mesh.mesh = model.build_skinned_mesh(rig.bone_names(), ModelLibrary.viewmodel_material())
	_arms_mesh.skin = rig.create_skin()
	_arms_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arms_mesh.layers = 2
	skeleton.add_child(_arms_mesh)
	_arms_mesh.skeleton = NodePath("..")

	hand_r = Node3D.new()
	hand_r.name = "HandR"
	add_child(hand_r)
	hand_l = Node3D.new()
	hand_l.name = "HandL"
	add_child(hand_l)

	ik = ArmIK.new()
	ik.name = "ArmIK"
	ik.len_upper = L_UPPER
	ik.len_fore = L_FORE
	skeleton.add_child(ik)
	ik.setup(skeleton, hand_r, hand_l)

	_attach_r = BoneAttachment3D.new()
	_attach_r.bone_name = "hand.R"
	skeleton.add_child(_attach_r)
	_attach_l = BoneAttachment3D.new()
	_attach_l.bone_name = "hand.L"
	skeleton.add_child(_attach_l)
	_weapon_r = MeshInstance3D.new()
	_weapon_r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon_r.layers = 2
	_attach_r.add_child(_weapon_r)
	_weapon_l = MeshInstance3D.new()
	_weapon_l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_weapon_l.layers = 2
	_attach_l.add_child(_weapon_l)

	_bow_string = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.0018
	cyl.bottom_radius = 0.0018
	cyl.height = 1.0
	cyl.radial_segments = 4
	cyl.rings = 1
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.82, 0.72)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.no_depth_test = true
	smat.render_priority = 10
	cyl.material = smat
	_bow_string.mesh = cyl
	_bow_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bow_string.visible = false
	add_child(_bow_string)

	var libs := ViewmodelAnims.split(ViewmodelAnims.build_library())
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", libs[0])
	anim.animation_finished.connect(_on_animation_finished)
	anim_left = AnimationPlayer.new()
	anim_left.name = "AnimationPlayerLeft"
	add_child(anim_left)
	anim_left.root_node = NodePath("..")
	anim_left.add_animation_library("", libs[1])
	anim_left.animation_finished.connect(_on_left_finished)


func has_shield() -> bool:
	return offhand_id == "shield" and kind in ["sword", "axe", "mace", "dagger"]


## Animación que corresponde a la mano izquierda para una acción dada.
func _left_for(anim_name: String) -> String:
	if has_shield():
		if anim_name == "death":
			return "death"
		if anim_name.ends_with("_block_hit"):
			return "shield_block_hit"
		if anim_name.ends_with("_block"):
			return "shield_block"
		if anim_name.ends_with("_hurt"):
			return "shield_hurt"
		if anim_name.ends_with("_unequip"):
			return "shield_unequip"
		if anim_name.ends_with("_equip"):
			return "shield_equip"
		if anim_name.ends_with("_run"):
			return "shield_run"
		if anim_name.ends_with("_idle"):
			return "shield_idle"
		if anim_name == "interact":
			return "shield_interact"
		if "_attack" in anim_name:
			return "shield_attack"
		if anim_name == "spell_cast":
			return "spell_cast"
		return "shield_idle"
	return anim_name if anim_left.has_animation(anim_name) else ""


func _play_left(anim_name: String, blend: float, speed: float = 1.0, one_shot: bool = false) -> void:
	var left := _left_for(anim_name)
	if left == "":
		return
	if one_shot:
		_left_action = left
	else:
		_left_base = left
		if _left_action != "":
			return
	anim_left.play(left, blend, speed)


func _on_left_finished(anim_name: StringName) -> void:
	if String(anim_name) == _left_action:
		_left_action = ""
		if _left_base != "":
			anim_left.play(_left_base, 0.2)


## Pose fija para capturas y pruebas (ambas manos).
func debug_pose(anim_name: String, t: float) -> void:
	if anim.has_animation(anim_name):
		anim.play(anim_name, 0.0)
		anim.seek(t, true)
		anim.pause()
	var left := _left_for(anim_name)
	if left != "" and anim_left.has_animation(left):
		anim_left.play(left, 0.0)
		anim_left.seek(minf(t, anim_left.get_animation(left).length), true)
		anim_left.pause()


## Cambia el arma visible y el juego de animaciones.
func set_weapon(new_kind: String, new_weapon_id: String, new_offhand: String) -> void:
	kind = new_kind
	weapon_id = new_weapon_id
	offhand_id = new_offhand
	var weapon_basis := Basis(Vector3.RIGHT, -PI / 2.0)
	if new_weapon_id == "" or new_kind == "unarmed":
		_weapon_r.mesh = null
	elif new_kind == "bow":
		_weapon_r.mesh = null
	else:
		_weapon_r.mesh = ModelLibrary.weapon_mesh(new_weapon_id, true)
		_weapon_r.transform = Transform3D(weapon_basis, GRIP_OFFSET)
	if new_kind == "bow":
		_weapon_l.mesh = ModelLibrary.weapon_mesh(new_weapon_id, true)
		_weapon_l.transform = Transform3D(weapon_basis, GRIP_OFFSET)
	elif new_offhand != "":
		_weapon_l.mesh = ModelLibrary.weapon_mesh(new_offhand, true)
		# El escudo mira hacia -Z de la mano; el puño queda tras el umbo.
		_weapon_l.transform = Transform3D(Basis.IDENTITY, Vector3(-0.01, -0.05, -0.08))
	else:
		_weapon_l.mesh = null
	_bow_string.visible = new_kind == "bow"
	if has_node("BowString2"):
		(get_node("BowString2") as Node3D).visible = new_kind == "bow"
	_apply_idle_pose()
	_base_anim = ""
	_action = ""
	_left_action = ""
	_left_base = ""
	_update_base_anim(false, true)
	play_action(kind + "_equip", 1.0)


func _apply_idle_pose() -> void:
	var p: Array = ViewmodelAnims.idle_pose(kind)
	hand_r.position = p[0]
	hand_r.rotation = (p[1] as Vector3) * (PI / 180.0)
	if has_shield():
		hand_l.position = ViewmodelAnims.SHIELD_IDLE_POS
		hand_l.rotation = ViewmodelAnims.SHIELD_IDLE_ROT * (PI / 180.0)
	else:
		hand_l.position = p[2]
		hand_l.rotation = (p[3] as Vector3) * (PI / 180.0)


func has_animation(anim_name: String) -> bool:
	return anim.has_animation(anim_name)


## Reproduce una acción puntual (ataque, golpe recibido...) con fundido.
func play_action(anim_name: String, speed: float = 1.0, blend: float = 0.08) -> void:
	if _dead or not anim.has_animation(anim_name):
		return
	_action = anim_name
	anim.play(anim_name, blend, speed)
	_play_left(anim_name, blend, speed, true)


## Gesto de la mano izquierda (hechizos) sin interrumpir el arma.
func play_left_gesture(anim_name: String) -> void:
	if anim_left.has_animation(anim_name):
		_left_action = anim_name
		anim_left.play(anim_name, 0.06, 1.2)


func is_busy() -> bool:
	return _action != ""


func current_action() -> String:
	return _action


func action_position() -> float:
	if _action == "":
		return 0.0
	return anim.current_animation_position


func set_blocking(enabled: bool) -> void:
	if _blocking == enabled:
		return
	_blocking = enabled
	if enabled:
		_action = ""
		_left_action = ""
		if has_shield():
			# Con escudo: la mano del arma queda en guardia y el escudo se alza.
			anim.play(kind + "_idle", 0.15)
			_base_anim = kind + "_block"
		else:
			anim.play(kind + "_block", 0.1)
			_base_anim = kind + "_block"
		_play_left(kind + "_block", 0.1)
	else:
		_base_anim = ""
		_update_base_anim(false, true)


func block_impact() -> void:
	if has_shield():
		_play_left(kind + "_block_hit", 0.03, 1.0, true)
		return
	if anim.has_animation(kind + "_block_hit"):
		anim.play(kind + "_block_hit", 0.03)
		_base_anim = kind + "_block_hit"


func set_lowered(enabled: bool) -> void:
	_lowered = enabled


func die() -> void:
	_dead = true
	anim.play("death", 0.15)
	anim_left.play("death", 0.15)
	_left_action = "death"


func revive() -> void:
	_dead = false
	_action = ""
	_left_action = ""
	_base_anim = ""
	_update_base_anim(false, true)


func _on_animation_finished(anim_name: StringName) -> void:
	var n := String(anim_name)
	if n == _action:
		_action = ""
		action_finished.emit(n)
		_update_base_anim(false, true)
	elif n == kind + "_block_hit" and _blocking:
		anim.play(kind + "_block", 0.05)
		_base_anim = kind + "_block"
		_play_left(kind + "_block", 0.05)


func _update_base_anim(running: bool, force: bool = false) -> void:
	if _dead or _action != "":
		return
	if _blocking:
		return
	var want := kind + ("_run" if running else "_idle")
	if kind == "bow" and _base_anim == "bow_hold":
		return
	if want != _base_anim or force:
		_base_anim = want
		anim.play(want, 0.25)
		_play_left(want, 0.25)


## Arco: tensar/mantener/soltar
func bow_hold() -> void:
	_action = ""
	_base_anim = "bow_hold"
	anim.play("bow_hold", 0.1)


func bow_release() -> void:
	_base_anim = ""
	play_action("bow_release", 1.0, 0.03)


## Capas procedurales. Llamar cada fotograma desde el jugador.
func update_motion(delta: float, horizontal_speed: float, local_velocity: Vector3, grounded: bool,
		running: bool, look_delta: Vector2, crouching: bool, wall_distance: float) -> void:
	# Paso de tiempo acotado: las capas procedurales deben ser estables aunque
	# el juego vaya a pocos fotogramas por segundo.
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	_update_base_anim(running and grounded and horizontal_speed > 3.5)
	# Balanceo al caminar
	var target_bob := clampf(horizontal_speed / 4.5, 0.0, 1.6) if grounded else 0.0
	_bob_amount = lerpf(_bob_amount, target_bob, 1.0 - exp(-dt * 8.0))
	_bob_time += dt * (6.5 + horizontal_speed * 1.1)
	var bob_scale := 1.0 if Settings.head_bob else 0.4
	var bob := Vector3(sin(_bob_time) * 0.011, -absf(cos(_bob_time)) * 0.013, 0.0) * _bob_amount * bob_scale
	# Inercia de la mirada (acotada por fotograma)
	var look := look_delta * (dt / maxf(delta, 0.0001)) if delta > 0.0 else Vector2.ZERO
	_sway_target = Vector2(clampf(-look.x * 0.0009, -0.05, 0.05), clampf(look.y * 0.0009, -0.04, 0.04))
	_sway = _sway.lerp(_sway_target, 1.0 - exp(-dt * 10.0))
	# Muelle de aterrizaje integrado de forma semiimplícita y acotado
	var k := 140.0
	var damp := 18.0
	_land_vel += (-_land_offset * k - _land_vel * damp) * dt
	_land_vel = clampf(_land_vel, -3.0, 3.0)
	_land_offset = clampf(_land_offset + _land_vel * dt, -0.12, 0.08)
	# Inclinación lateral al desplazarse de lado
	_strafe_roll = lerpf(_strafe_roll, clampf(-local_velocity.x * 0.012, -0.05, 0.05), 1.0 - exp(-dt * 6.0))
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, 1.0 - exp(-dt * 8.0))
	# Retroceso junto a paredes para evitar que el arma "atraviese" la escena
	var want_pull := clampf((0.9 - wall_distance) / 0.6, 0.0, 1.0)
	if _lowered:
		want_pull = maxf(want_pull, 0.8)
	_pullback = lerpf(_pullback, want_pull, 1.0 - exp(-dt * 10.0))
	position = bob + Vector3(_sway.x, _sway.y + _land_offset - _crouch * 0.015, 0.0) + Vector3(0.02, -0.07, 0.14) * _pullback
	rotation = Vector3(_sway.y * 1.5 - _pullback * 0.35, _sway.x * 2.0, _strafe_roll + _sway.x * 1.2)
	_update_bow_string()


func land(impact: float) -> void:
	_land_vel -= clampf(impact, 0.0, 12.0) * 0.12


func update_fov(camera_fov: float) -> void:
	var s := tan(deg_to_rad(camera_fov) * 0.5) / tan(deg_to_rad(VIEWMODEL_FOV) * 0.5)
	ModelLibrary.viewmodel_material().set_shader_parameter("fov_scale", s)
	if _bow_string.mesh:
		((_bow_string.mesh as CylinderMesh).material as StandardMaterial3D).albedo_color = Color(0.85, 0.82, 0.72)


func _update_bow_string() -> void:
	if not _bow_string.visible:
		return
	# Cuerda entre las puntas del arco y, si se tensa, la mano derecha.
	var bow_xf := _weapon_l.global_transform
	var top := bow_xf * Vector3(-0.012, 26.0 / 40.0, 5.5 / 40.0)
	var bottom := bow_xf * Vector3(-0.012, -26.0 / 40.0, 5.5 / 40.0)
	var hand := _attach_r.global_transform * Vector3(-0.012, -0.05, -0.02)
	var mid := (top + bottom) * 0.5
	var drawn := _base_anim == "bow_hold" or _action == "bow_draw"
	var pull := hand if drawn else mid
	# Dos segmentos: se dibuja el más largo como aproximación (cuerda tensa en V)
	var a := top
	var b := pull
	var c := bottom
	_place_segment(_bow_string, a, b)
	if not has_node("BowString2"):
		var s2 := MeshInstance3D.new()
		s2.name = "BowString2"
		s2.mesh = _bow_string.mesh
		s2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s2)
	var seg2 := get_node("BowString2") as MeshInstance3D
	seg2.visible = true
	_place_segment(seg2, b, c)


func _place_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var dir := b - a
	var length := maxf(dir.length(), 0.001)
	var y := dir / length
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.global_transform = Transform3D(Basis(x, y * length, z), mid)
