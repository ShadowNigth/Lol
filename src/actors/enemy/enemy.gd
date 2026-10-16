class_name Enemy
extends CharacterBody3D
## Enemigo cuerpo a cuerpo con IA por estados: reposo/patrulla, detección
## (vista con campo de visión y línea de visión, oído), persecución con
## esquiva de obstáculos y saltos, ataques con preparación y comprobación
## real del alcance en el instante del impacto, bloqueo con escudo, reacción
## a golpes, aturdimiento tras una parada y muerte (cadáver saqueable).

signal killed(enemy: Enemy)

enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, BLOCK, HIT, STUN, RETURN, FLEE, DEAD }

const GRAVITY := 15.0
const MASK_WORLD := 1
const MASK_PLAYER := 2

var data: EnemyData
var stats := Stats.new()
var entity_id: String = ""
var world: VoxelWorld
var target: Player
var state: State = State.IDLE
var home := Vector3.ZERO
var home_yaw := 0.0
var patrol: Array[Vector3] = []
var loot_gold: int = 0
var looted: bool = false

var skeleton: Skeleton3D
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var _material: ShaderMaterial
var _model_root: Node3D
var _rng := RandomNumberGenerator.new()
var _state_t := 0.0
var _think_t := 0.0
var _aware := false
var _last_seen := Vector3.ZERO
var _lost_t := 0.0
var _attack_cd := 0.0
var _attack_name := ""
var _attack_hit_time := 0.0
var _attack_len := 0.0
var _attack_done := false
var _block_until := 0.0
var _patrol_i := 0
var _flash := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _avoid_dir := 0.0
var _avoid_t := 0.0
var _idle_sound_t := 4.0
var _step_accum := 0.0
var _desired_speed := 0.0
var stat_blocks := 0
var poise := 20.0
var max_poise := 20.0
var _poise_regen_delay := 0.0
var _fled := false
var _variant := -1
## Mantiene su puesto (p. ej. la arquera de la torre de vigía): no retrocede ni avanza.
var hold_position := false
## Guardia de la Marca peleando: sustituye a su PNJ hasta que se calma (ver Law).
var guard_npc: NPC = null
var guard_essential := false
var look: Dictionary = {}          # aspecto humano (modelo "guard")
var gear: Dictionary = {}          # equipo visible: arma y escudo
var custom_name := ""
var _guard_check := 0.0


func setup(enemy_data: EnemyData, spawn: Dictionary, voxel_world: VoxelWorld, player: Player) -> void:
	data = enemy_data
	world = voxel_world
	target = player
	entity_id = str(spawn.get("id", ""))
	home = spawn.get("pos", Vector3.ZERO)
	home_yaw = deg_to_rad(float(spawn.get("yaw", 0.0)))
	var pts: Array = spawn.get("patrol", [])
	for p: Vector3 in pts:
		patrol.append(p)
	_rng.seed = hash(entity_id)
	_variant = int(spawn.get("variant", -1))
	hold_position = bool(spawn.get("hold", false))
	look = spawn.get("look", {})
	gear = spawn.get("gear", {})
	custom_name = str(spawn.get("name", ""))


func _ready() -> void:
	collision_layer = 4
	collision_mask = MASK_WORLD | MASK_PLAYER | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var sc := data.model_scale
	cap.radius = data.collision_radius * sc
	cap.height = data.collision_height * sc
	cs.shape = cap
	cs.position = Vector3(0, data.collision_height * 0.5 * sc, 0)
	add_child(cs)
	if data.is_boss:
		max_poise = 60.0
		poise = max_poise
	stats.attributes["endurance"] = 40
	stats.recalc(true)
	stats.max_health = data.max_health
	stats.health = data.max_health
	stats.armor_rating = data.armor
	stats.resistances["slash"] = data.resist_slash
	stats.resistances["blunt"] = data.resist_blunt
	stats.resistances["pierce"] = data.resist_pierce
	_build_model()
	global_position = home
	rotation.y = home_yaw
	_last_pos = global_position
	state = State.PATROL if patrol.size() > 1 else State.IDLE
	loot_gold = _rng.randi_range(data.gold_min, data.gold_max)


func _build_model() -> void:
	_model_root = Node3D.new()
	_model_root.name = "Model"
	add_child(_model_root)
	if data.body == "quadruped":
		_build_quadruped()
		return
	var rig := Rig.humanoid()
	skeleton = rig.create_skeleton()
	_model_root.add_child(skeleton)
	_model_root.scale = Vector3.ONE * data.model_scale
	var variant := data.model_variant if data.model_variant >= 0 else _rng.randi() % 3
	var model: VoxelModel
	match data.model:
		"bandit":
			# Cada bandido tiene su propia cara y colores (semilla por identificador)
			model = CharacterModels.bandit(variant, absi(hash(entity_id)) % 100000 + 11)
		"guard":
			# Guardia: el mismo aspecto y armadura que su PNJ
			model = CharacterModels.human(look, hash(entity_id))
		_:
			model = CharacterModels.skeleton_warrior(variant)
	_material = ModelLibrary.unique_model_material()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = model.build_skinned_mesh(rig.bone_names(), _material)
	mi.skin = rig.create_skin()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	# Arma en la mano derecha y escudo en el antebrazo izquierdo
	var wa := BoneAttachment3D.new()
	wa.bone_name = "hand.L" if data.ranged else "hand.R"
	skeleton.add_child(wa)
	var wmesh := MeshInstance3D.new()
	wmesh.mesh = ModelLibrary.weapon_mesh(str(gear.get("weapon", data.weapon_model)), false)
	if data.ranged:
		wmesh.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.07, -0.02))
	else:
		wmesh.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02))
	wa.add_child(wmesh)
	if data.has_shield:
		var sa := BoneAttachment3D.new()
		sa.bone_name = "forearm.L"
		skeleton.add_child(sa)
		var smesh := MeshInstance3D.new()
		var shield_id := NpcDB.shield_model(str(gear["offhand"])) if gear.has("offhand") else data.shield_model
		smesh.mesh = ModelLibrary.weapon_mesh(shield_id, false)
		smesh.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.09, -0.14, 0.0))
		sa.add_child(smesh)
	var lib := HumanoidAnims.build_library("warrior")
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	_model_root.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	anim_tree.add_animation_library("", lib)
	anim_tree.tree_root = HumanoidAnims.build_tree(lib, PackedStringArray(["alert", "attack_1", "attack_2", "shoot", "block", "hit", "stun", "death"]))
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


## Cuerpo cuadrúpedo (lobos): sin armas; muerde con la mandíbula animada.
func _build_quadruped() -> void:
	var rig := Rig.quadruped()
	skeleton = rig.create_skeleton()
	_model_root.add_child(skeleton)
	_model_root.scale = Vector3.ONE * data.model_scale
	var variant := data.model_variant
	if variant < 0:
		variant = _variant if _variant >= 0 else _rng.randi() % 2
	var model := CharacterModels.wolf(variant)
	_material = ModelLibrary.unique_model_material()
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = model.build_skinned_mesh(rig.bone_names(), _material)
	mi.skin = rig.create_skin()
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	var lib := QuadrupedAnims.build_library()
	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	_model_root.add_child(anim_tree)
	anim_tree.root_node = NodePath("..")
	anim_tree.add_animation_library("", lib)
	anim_tree.tree_root = HumanoidAnims.build_tree(lib, PackedStringArray(["alert", "attack_1", "attack_2", "hit", "stun", "death"]))
	anim_tree.active = true
	playback = anim_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback


func _voice_pos() -> Vector3:
	return global_position + Vector3(0, data.eye_height * data.model_scale, 0)


func is_alive() -> bool:
	return state != State.DEAD


func is_aware() -> bool:
	return _aware


func display_name() -> String:
	return custom_name if custom_name != "" else data.display_name


## Ya sabe dónde está el jugador (guardia que entra en combate, etc.).
func make_aware() -> void:
	if state == State.DEAD or target == null:
		return
	_aware = true
	_last_seen = target.global_position
	_lost_t = 0.0
	_set_state(State.ALERT)
	playback.travel("alert")
	Audio.play_3d(data.sound_alert, _voice_pos(), 0.0)


func health_ratio() -> float:
	return stats.health / maxf(stats.max_health, 1.0)


# ---------------------------------------------------------------------------
# Bucle principal
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_t += delta
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_poise_regen_delay = maxf(_poise_regen_delay - delta, 0.0)
	if _poise_regen_delay <= 0.0:
		poise = minf(max_poise, poise + 12.0 * delta)
	_update_flash(delta)
	if state != State.DEAD:
		var dot := stats.tick_effects(delta)
		if dot > 0.0:
			stats.apply_damage(dot)
			if stats.dead:
				_die({})
	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	# No simular si su chunk no está cargado (evita caer al vacío)
	if world and not world.is_chunk_loaded_at(global_position):
		return
	# Recuperación si atraviesa el terreno por cualquier motivo
	if global_position.y < home.y - 25.0:
		global_position = home + Vector3(0, 0.3, 0)
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		_set_state(State.IDLE)
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = 0.2
		_perceive()
	if guard_npc != null:
		_guard_check -= delta
		if _guard_check <= 0.0:
			_guard_check = 0.5
			if _guard_should_calm():
				Law.calm_guard(self)
				return
	var move_dir := Vector3.ZERO
	_desired_speed = 0.0
	match state:
		State.IDLE:
			_face_yaw(home_yaw, delta, 2.0)
			_idle_sounds(delta)
		State.PATROL:
			move_dir = _patrol_step(delta)
			_idle_sounds(delta)
		State.ALERT:
			_face_target(delta, 8.0)
			if _state_t > 0.8:
				_set_state(State.CHASE)
		State.CHASE:
			move_dir = _chase_step(delta)
		State.ATTACK:
			move_dir = _attack_step(delta)
		State.FLEE:
			move_dir = _flee_step()
		State.BLOCK:
			_face_target(delta, 6.0)
			if _state_t > _block_until:
				playback.travel("loco")
				_set_state(State.CHASE)
		State.HIT:
			if _state_t > 0.42:
				_set_state(State.CHASE if _aware else State.IDLE)
		State.STUN:
			if _state_t > 1.25:
				_set_state(State.CHASE if _aware else State.IDLE)
		State.RETURN:
			move_dir = _return_step(delta)
	_apply_movement(move_dir, delta)


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0


func _apply_movement(dir: Vector3, delta: float) -> void:
	var target_vel := dir * _desired_speed * stats.slow_factor()
	var accel := 8.0 if is_on_floor() else 1.5
	velocity.x = lerpf(velocity.x, target_vel.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_vel.z, clampf(accel * delta, 0.0, 1.0))
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# Salto sobre obstáculos de un bloque (pero no se encaraman a las tiendas de lona)
	if dir.length() > 0.1 and is_on_floor() and _blocked_ahead(dir, 0.35) and not _blocked_ahead(dir, 1.35) and not _canvas_ahead(dir):
		velocity.y = 5.6
	move_and_slide()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var blend := 0.0
	if hspeed > 0.05:
		blend = clampf(hspeed / data.walk_speed, 0.0, 1.0) if hspeed <= data.walk_speed else 1.0 + clampf((hspeed - data.walk_speed) / (data.run_speed - data.walk_speed), 0.0, 1.0)
	anim_tree.set("parameters/loco/blend_position", blend)
	# Pasos (crujido de huesos)
	if is_on_floor() and hspeed > 0.5:
		_step_accum += hspeed * delta
		if _step_accum > (1.4 if hspeed < 3.0 else 2.0):
			_step_accum = 0.0
			Audio.play_3d(data.step_sound, global_position, -14.0, 0.2)
			if _rng.randf() < 0.3:
				Audio.play_3d(data.sound_idle, _voice_pos(), -16.0)
	# Atascos: cambiar de dirección de esquiva
	if dir.length() > 0.1:
		if global_position.distance_to(_last_pos) < 0.4 * delta * maxf(_desired_speed, 1.0):
			_stuck_t += delta
		else:
			_stuck_t = maxf(_stuck_t - delta, 0.0)
		if _stuck_t > 0.7:
			_stuck_t = 0.0
			_avoid_dir = 1.0 if _rng.randf() < 0.5 else -1.0
			_avoid_t = 1.2
	_last_pos = global_position


## ¿Lo que tiene delante (a la altura de las rodillas) es lona de una tienda?
func _canvas_ahead(dir: Vector3) -> bool:
	if world == null:
		return false
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.35, 0)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 0.75, MASK_WORLD, [get_rid()]))
	if hit.is_empty():
		return false
	var id := world.block_at((hit["position"] as Vector3) - (hit["normal"] as Vector3) * 0.05)
	return id == BlockTypes.CANVAS or id == BlockTypes.CANVAS_SLAB or (id >= BlockTypes.CANVAS_STAIRS and id < BlockTypes.CANVAS_STAIRS + 4)


func _blocked_ahead(dir: Vector3, height: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, height, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 0.75, MASK_WORLD, [get_rid()])
	return not space.intersect_ray(q).is_empty()


func _steer(desired: Vector3) -> Vector3:
	var dir := desired
	dir.y = 0.0
	if dir.length() < 0.001:
		return Vector3.ZERO
	dir = dir.normalized()
	_avoid_t = maxf(_avoid_t - get_physics_process_delta_time(), 0.0)
	if _avoid_t > 0.0:
		dir = dir.rotated(Vector3.UP, _avoid_dir * deg_to_rad(70.0))
	elif _blocked_ahead(dir, 1.35):
		# Pared alta delante: probar direcciones alternativas
		for ang: float in [35.0, -35.0, 70.0, -70.0, 110.0, -110.0]:
			var alt := dir.rotated(Vector3.UP, deg_to_rad(ang))
			if not _blocked_ahead(alt, 1.35):
				dir = alt
				break
	# Separación de otros enemigos cercanos
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not (other is Node3D):
			continue
		var d := global_position - (other as Node3D).global_position
		d.y = 0.0
		var dist := d.length()
		if dist < 1.1 and dist > 0.001:
			dir += d.normalized() * (1.1 - dist) * 1.5
	return dir.normalized()


func _face_yaw(yaw: float, delta: float, speed: float) -> void:
	rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * speed, 0.0, 1.0))


func _face_dir(dir: Vector3, delta: float, speed: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.001:
		return
	_face_yaw(atan2(-dir.x, -dir.z), delta, speed)


func _face_target(delta: float, speed: float) -> void:
	if target:
		_face_dir(target.global_position - global_position, delta, speed)


func _to_target() -> Vector3:
	if target == null:
		return Vector3(1000, 0, 0)
	var d := target.global_position - global_position
	return d


# ---------------------------------------------------------------------------
# Percepción
# ---------------------------------------------------------------------------

func _perceive() -> void:
	if target == null or target.is_dead:
		if _aware:
			_aware = false
			_set_state(State.RETURN)
		return
	var d := _to_target()
	var dist := d.length()
	var sees := false
	if dist < data.detection_range:
		var fwd := -global_basis.z
		var flat := Vector3(d.x, 0, d.z).normalized()
		var angle := rad_to_deg(acos(clampf(fwd.dot(flat), -1.0, 1.0)))
		var stealth := 0.55 if target.is_crouching() else 1.0
		var in_fov := angle < data.fov_degrees * 0.5 and dist < data.detection_range * stealth
		var heard := dist < data.hearing_range * (0.35 if target.is_crouching() else (1.6 if target.is_sprinting() else 1.0))
		if (in_fov or heard or _aware) and _line_of_sight():
			sees = true
	if sees:
		_last_seen = target.global_position
		_lost_t = 0.0
		if not _aware:
			_aware = true
			if state in [State.IDLE, State.PATROL, State.RETURN]:
				_set_state(State.ALERT)
				playback.travel("alert")
				Audio.play_3d(data.sound_alert, _voice_pos(), 0.0)
			if data.pack_call:
				_call_pack()
	elif _aware:
		_lost_t += 0.2
		if _lost_t > 7.0 or global_position.distance_to(home) > 40.0:
			_aware = false
			if state in [State.CHASE, State.ALERT]:
				_set_state(State.RETURN)


func _line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, data.eye_height * data.model_scale, 0)
	var to := target.global_position + Vector3(0, 1.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD, [get_rid()])
	return space.intersect_ray(q).is_empty()


## La manada (o la banda): avisa a los de su especie cercanos de dónde está la
## presa. Un lobo no despierta a un bandido ni al revés.
func _call_pack() -> void:
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var other := n as Enemy
		if other and other != self and other.data and other.data.pack_call and other.data.model == data.model \
				and other.global_position.distance_to(global_position) < 22.0:
			other.hear_noise(global_position, 100.0)


## Notificación de ruido (combate cercano, etc.)
func hear_noise(pos: Vector3, radius: float) -> void:
	if state == State.DEAD or _aware:
		return
	if global_position.distance_to(pos) < radius:
		_aware = true
		_last_seen = pos
		_set_state(State.ALERT)
		playback.travel("alert")
		Audio.play_3d(data.sound_alert, _voice_pos(), -2.0)


# ---------------------------------------------------------------------------
# Comportamientos
# ---------------------------------------------------------------------------

func _idle_sounds(delta: float) -> void:
	_idle_sound_t -= delta
	if _idle_sound_t <= 0.0:
		_idle_sound_t = _rng.randf_range(5.0, 11.0)
		Audio.play_3d(data.sound_idle, _voice_pos(), -10.0)


func _patrol_step(delta: float) -> Vector3:
	if patrol.size() < 2:
		_set_state(State.IDLE)
		return Vector3.ZERO
	var goal := patrol[_patrol_i]
	var d := goal - global_position
	d.y = 0.0
	if d.length() < 0.6:
		if _state_t > 2.5:
			_patrol_i = (_patrol_i + 1) % patrol.size()
			_state_t = 0.0
		return Vector3.ZERO
	var dir := _steer(d)
	_desired_speed = data.walk_speed
	_face_dir(dir, delta, 4.0)
	return dir


func _return_step(delta: float) -> Vector3:
	var d := home - global_position
	d.y = 0.0
	if d.length() < 0.8:
		_set_state(State.PATROL if patrol.size() > 1 else State.IDLE)
		stats.heal(stats.max_health)
		return Vector3.ZERO
	var dir := _steer(d)
	_desired_speed = data.walk_speed
	_face_dir(dir, delta, 4.0)
	return dir


func _chase_step(delta: float) -> Vector3:
	if not _aware:
		_set_state(State.RETURN)
		return Vector3.ZERO
	var d := _to_target()
	var flat := Vector3(d.x, 0, d.z)
	var dist := flat.length()
	_face_target(delta, 7.0)
	if data.ranged:
		return _ranged_step(dist, flat)
	# ¿Atacar?
	var fwd := -global_basis.z
	var facing := fwd.dot(flat.normalized()) > 0.85
	if dist < data.attack_range and facing and _attack_cd <= 0.0 and absf(d.y) < 1.6:
		_begin_attack()
		return Vector3.ZERO
	# ¿Bloquear si el jugador ataca de cerca?
	if dist < 2.8 and data.has_shield and target.viewmodel.is_busy() and _attack_cd > 0.2 and _rng.randf() < data.block_chance * 0.25:
		_begin_block(_rng.randf_range(0.6, 1.1))
		return Vector3.ZERO
	if dist < data.attack_range * 0.8:
		return Vector3.ZERO
	var goal := target.global_position if _lost_t <= 0.0 else _last_seen
	var to_goal := goal - global_position
	if world and world.generator.is_interior() and (not _line_of_sight() or _blocked_ahead(to_goal, 1.0)):
		var path := world.generator.find_path(global_position, goal)
		if path.size() > 2:
			to_goal = path[2] - global_position
	var dir := _steer(to_goal)
	_desired_speed = data.run_speed if dist > 3.5 else data.walk_speed * 1.4
	return dir


## Arquero: mantiene la distancia y dispara cuando tiene línea de visión.
func _ranged_step(dist: float, flat: Vector3) -> Vector3:
	if dist < 5.0 and not hold_position:
		_desired_speed = data.walk_speed * 1.6
		return _steer(-flat)
	if dist < data.attack_range and _attack_cd <= 0.0 and _line_of_sight():
		_set_state(State.ATTACK)
		_attack_done = false
		_attack_name = "shoot"
		_attack_hit_time = 0.85
		_attack_len = 1.3
		playback.travel("shoot")
		Audio.play_3d("bow_draw", global_position + Vector3(0, 1.4, 0), -4.0)
		return Vector3.ZERO
	if (dist > data.attack_range * 0.8 or not _line_of_sight()) and not hold_position:
		_desired_speed = data.run_speed
		var path := world.generator.find_path(global_position, target.global_position) if world else PackedVector3Array()
		if path.size() > 2:
			return _steer(path[2] - global_position)
		return _steer(flat)
	return Vector3.ZERO


func _shoot_arrow() -> void:
	if target == null:
		return
	var from := global_position + Vector3(0, 1.45, 0) + (-global_basis.z) * 0.6
	var aim := target.global_position + Vector3(0, 1.2, 0)
	var t := from.distance_to(aim) / data.projectile_speed
	aim += target.velocity * t * 0.8
	aim.y += 0.5 * 9.8 * t * t
	var dir := (aim - from).normalized()
	var dmg := _rng.randf_range(data.damage_min, data.damage_max)
	Projectile.spawn(get_tree().current_scene, "arrow", from, dir * data.projectile_speed, dmg, self)
	Audio.play_3d("bow_release", from, -2.0)


func _begin_attack() -> void:
	_set_state(State.ATTACK)
	_attack_done = false
	if _rng.randf() < data.attack1_chance:
		_attack_name = "attack_1"
		_attack_hit_time = data.attack1_hit
		_attack_len = data.attack1_len
	else:
		_attack_name = "attack_2"
		_attack_hit_time = data.attack2_hit
		_attack_len = data.attack2_len
	playback.travel(_attack_name)
	var quad := data.body == "quadruped"
	get_tree().create_timer(_attack_hit_time * 0.7).timeout.connect(func() -> void:
		if state == State.ATTACK and is_instance_valid(self):
			if quad:
				Audio.play_3d(data.sound_idle, _voice_pos(), -2.0)
			else:
				Audio.play_3d("swing_heavy" if _attack_name == "attack_2" else "swing", global_position + Vector3(0, 1.4, 0), -3.0))


func _attack_step(delta: float) -> Vector3:
	var lunge := Vector3.ZERO
	# Durante la preparación sigue al jugador; después se compromete con el golpe.
	if _state_t < _attack_hit_time - 0.15:
		_face_target(delta, 5.0)
	# Salto real hacia delante (lobos): el cuerpo físico avanza durante el impulso.
	if _attack_name == "attack_2" and data.lunge_speed > 0.0 and _state_t > _attack_hit_time - 0.28 and _state_t < _attack_hit_time + 0.05:
		lunge = -global_basis.z
		lunge.y = 0.0
		lunge = lunge.normalized()
		_desired_speed = data.lunge_speed
	if not _attack_done and _state_t >= _attack_hit_time:
		_attack_done = true
		if data.ranged:
			_shoot_arrow()
		else:
			_resolve_attack_hit()
	if _state_t >= _attack_len:
		_attack_cd = data.attack_cooldown * _rng.randf_range(0.8, 1.4)
		_set_state(State.CHASE)
	return lunge


## Huida: se aleja del jugador un rato y luego vuelve a la carga.
func _flee_step() -> Vector3:
	if target == null or _state_t > 3.5:
		_set_state(State.CHASE if _aware else State.RETURN)
		return Vector3.ZERO
	var away := global_position - target.global_position
	away.y = 0.0
	_face_dir(away.normalized(), get_physics_process_delta_time(), 6.0)
	_desired_speed = data.run_speed
	return _steer(away)


func _resolve_attack_hit() -> void:
	if target == null or target.is_dead:
		return
	var d := target.global_position - global_position
	var flat := Vector3(d.x, 0, d.z)
	var dist := flat.length()
	var fwd := -global_basis.z
	var angle := rad_to_deg(acos(clampf(fwd.dot(flat.normalized()), -1.0, 1.0)))
	if dist > data.attack_range + 0.45 or angle > 55.0 or absf(d.y) > 1.7 or not _line_of_sight():
		return
	var dmg := _rng.randf_range(data.damage_min, data.damage_max) * (1.0 + (data.level - 1) * 0.15)
	if data.body == "quadruped":
		Audio.play_3d("bite", _voice_pos(), 0.0)
	var info := {"attacker": self, "damage_type": data.damage_type, "position": global_position + Vector3(0, 1.3, 0)}
	var result := target.take_hit(dmg, info)
	match result:
		"parried":
			_get_stunned()
		"blocked":
			_set_state(State.HIT)
			playback.travel("hit")
		"hit":
			Audio.play_3d("hit_flesh", target.global_position + Vector3(0, 1.3, 0), 0.0)
			HitFX.spawn(get_tree().current_scene, "blood", target.global_position + Vector3(0, 1.3, 0) - flat.normalized() * 0.3, -flat.normalized(), 0.7)


func _begin_block(duration: float) -> void:
	_set_state(State.BLOCK)
	_block_until = duration
	playback.travel("block")


func _get_stunned() -> void:
	_set_state(State.STUN)
	playback.travel("stun")
	_attack_cd = 1.5


# ---------------------------------------------------------------------------
# Daño
# ---------------------------------------------------------------------------

## Recibe un golpe del jugador. Devuelve "blocked", "hit" o "killed".
func take_hit(amount: float, info: Dictionary) -> String:
	if state == State.DEAD:
		return "dead"
	var pos: Vector3 = info.get("position", global_position + Vector3(0, 1.2, 0))
	var normal: Vector3 = info.get("normal", Vector3.UP)
	var attacker := info.get("attacker", null) as Node3D
	if not _aware:
		_aware = true
		if attacker:
			_last_seen = attacker.global_position
	# Bloqueo frontal con escudo
	if state == State.BLOCK and attacker:
		var to_att := attacker.global_position - global_position
		to_att.y = 0.0
		if (-global_basis.z).dot(to_att.normalized()) > 0.3:
			Audio.play_3d("block", pos, 0.0)
			HitFX.spawn(get_tree().current_scene, "sparks", pos, normal)
			playback.travel("block")
			_block_until = _state_t + 0.4
			stat_blocks += 1
			return "blocked"
	# Bloqueo reactivo si está en guardia y no ataca
	if state in [State.CHASE, State.ALERT] and data.has_shield and _rng.randf() < data.block_chance * 0.5 and attacker:
		var to_att2 := attacker.global_position - global_position
		to_att2.y = 0.0
		if (-global_basis.z).dot(to_att2.normalized()) > 0.5:
			_begin_block(_rng.randf_range(0.5, 0.9))
			Audio.play_3d("block", pos, 0.0)
			HitFX.spawn(get_tree().current_scene, "sparks", pos, normal)
			stat_blocks += 1
			return "blocked"
	var dtype := str(info.get("damage_type", "slash"))
	var dmg := stats.mitigate(amount, dtype)
	stats.apply_damage(dmg)
	_flash = 1.0
	HitFX.spawn(get_tree().current_scene, data.hit_effect, pos, normal)
	HitFX.spawn(get_tree().current_scene, "dust", pos, normal, 0.5)
	Audio.play_3d("hit_bone" if data.hit_effect == "bone" else "hit_flesh", pos, 0.0)
	# Retroceso
	var push: Vector3 = info.get("direction", Vector3.ZERO)
	push.y = 0.0
	velocity += push.normalized() * 2.2 * float(info.get("stagger", 1.0))
	if stats.dead:
		_die(info)
		return "killed"
	Audio.play_3d(data.sound_hurt, _voice_pos(), -4.0)
	if data.flee_health > 0.0 and not _fled and health_ratio() < data.flee_health and state != State.ATTACK:
		_fled = true
		_set_state(State.FLEE)
		return "hit"
	# Aguante postural: solo se interrumpe al enemigo cuando se rompe su
	# guardia, y es inmune a interrupciones al final de la preparación.
	poise -= dmg * float(info.get("stagger", 1.0))
	_poise_regen_delay = 1.2
	var committed := state == State.ATTACK and _state_t > _attack_hit_time * 0.6
	if bool(info.get("critical", false)) and not committed:
		poise = max_poise
		_get_stunned()
	elif poise <= 0.0 and not committed:
		poise = max_poise
		_set_state(State.HIT)
		playback.travel("hit")
		# Tras recuperarse suele contraatacar enseguida
		if _rng.randf() < 0.6:
			_attack_cd = 0.0
	return "hit"


## El guardia vuelve a ser PNJ: ya no hay deudas ni resistencia, o ha
## perdido de vista al jugador y ha vuelto a su puesto.
func _guard_should_calm() -> bool:
	if not is_instance_valid(guard_npc):
		guard_npc = null
		return false
	if not Law.is_wanted() and not Law.resisted():
		return state in [State.IDLE, State.PATROL, State.RETURN, State.CHASE, State.ALERT]
	# Sin ver al jugador: de vuelta en su puesto (o tras un buen rato intentando volver)
	return not _aware and (state in [State.IDLE, State.PATROL] or (state == State.RETURN and _state_t > 12.0))


func _die(_info: Dictionary) -> void:
	if guard_npc != null and is_instance_valid(guard_npc):
		if guard_essential:
			# Los guardias con nombre no mueren: caen inconscientes
			Law.calm_guard(self, true)
			return
		Law.guard_killed(self)
	_set_state(State.DEAD)
	playback.travel("death")
	Audio.play_3d(data.sound_death, _voice_pos(), 0.0)
	# El cadáver deja de bloquear al jugador pero sigue siendo saqueable
	collision_layer = 16
	collision_mask = MASK_WORLD
	Events.enemy_killed.emit(self, data.id)
	killed.emit(self)


func _update_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 5.0, 0.0)
		_material.set_shader_parameter("flash_color", Color(1.0, 0.85, 0.8, _flash * 0.65))


# ---------------------------------------------------------------------------
# Saqueo del cadáver
# ---------------------------------------------------------------------------

func get_interaction_text() -> String:
	if state != State.DEAD:
		return ""
	if looted:
		return "%s (vacío)" % data.display_name
	return "[E] Registrar %s" % data.display_name


func interact(player: Player) -> void:
	if state != State.DEAD or looted:
		return
	looted = true
	GameState.mark_looted(entity_id)
	var found: Array[String] = []
	if loot_gold > 0:
		player.gold += loot_gold
		found.append("%d monedas de oro" % loot_gold)
		Audio.play_2d("gold", -4.0)
	var extra := LootTables.roll(data.loot_table, _rng)
	for item: Dictionary in extra:
		GameState.give_item(player, item)
		found.append(str(item.get("name", "objeto")))
	if found.is_empty():
		Events.notify.emit("No encuentras nada de valor.", "info")
	else:
		Events.notify.emit("Encuentras: " + ", ".join(found), "item")
