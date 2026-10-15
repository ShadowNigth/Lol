class_name Player
extends CharacterBody3D
## Jugador en primera persona: movimiento con aceleración, carrera con
## aguante, salto, agacharse, esquiva, subida de escalones, nado básico,
## daño por caída, interacción y combate cuerpo a cuerpo con detección real
## de impactos mediante rayos que barren el arco de cada ataque.

signal died
signal attacked(hit_something: bool)

const WALK_SPEED := 4.3
const RUN_SPEED := 7.0
const CROUCH_SPEED := 2.1
const SWIM_SPEED := 2.6
const JUMP_VELOCITY := 5.4
const GRAVITY := 15.0
const EYE_HEIGHT := 1.62
const CROUCH_EYE := 1.02
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.15
const STEP_HEIGHT := 0.6
const INTERACT_DISTANCE := 2.7
const MASK_WORLD := 1
const MASK_ACTORS := 4
const MASK_INTERACT := 16

var stats := Stats.new()
var world: VoxelWorld
var camera: Camera3D
var viewmodel: Viewmodel
var head_anchor: Node3D
var weapon: WeaponData
var weapons: Array[WeaponData] = []
var weapon_index: int = 0
var offhand_id: String = "shield"
var gold: int = 0
var controls_enabled: bool = true
var is_dead: bool = false

var _yaw: float = 0.0
var _pitch: float = 0.0
var _look_delta := Vector2.ZERO
var _crouching := false
var _eye := EYE_HEIGHT
var _step_smooth := 0.0
var _step_accum := 0.0
var _was_on_floor := true
var _prev_vel_y := 0.0
var _dodge_time := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _invulnerable := 0.0
var _trauma := 0.0
var _shake_t := 0.0
var _kick := Vector2.ZERO
var _fov_kick := 0.0
var _stamina_delay := 0.0
var _sprinting := false
var _swimming := false
var _head_underwater := false
var _rng := RandomNumberGenerator.new()
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _interact_target: Object = null
var _target_timer := 0.0
var _current_target: Node = null
var _death_t := 0.0

# Estado de combate
var _attack: Dictionary = {}
var _attack_t := 0.0
var _attack_len := 0.0
var _attack_prev_t := 0.0
var _hit_targets: Array = []
var _hit_world := false
var _combo := 0
var _combo_timer := 0.0
var _queued_attack := false
var _queue_time := 0.0
var _block_time := 0.0
var _blocking := false
var _bow_draw := 0.0
var _drawing := false
# Magia
const SPELLS := {
	"fireball": {"name": "Bola de fuego", "cost": 18.0, "skill": "destruction", "cooldown": 0.9},
	"frost": {"name": "Rayo de escarcha", "cost": 14.0, "skill": "destruction", "cooldown": 0.8},
	"heal": {"name": "Curar heridas", "cost": 22.0, "skill": "restoration", "cooldown": 1.2},
}
var spells: Array[String] = ["fireball", "frost", "heal"]
var spell_index := 0
var _spell_cd := 0.0
# Estadísticas de depuración/pruebas
var stat_swings := 0
var stat_hits := 0
var stat_world_hits := 0


func _ready() -> void:
	_rng.randomize()
	collision_layer = 2
	collision_mask = MASK_WORLD | MASK_ACTORS
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	safe_margin = 0.02
	_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "CollisionShape3D"
		add_child(_collision)
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.34
	_capsule.height = STAND_HEIGHT
	_collision.shape = _capsule
	_collision.position = Vector3(0, STAND_HEIGHT * 0.5, 0)

	head_anchor = Node3D.new()
	head_anchor.name = "HeadAnchor"
	head_anchor.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(head_anchor)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.near = 0.05
	camera.far = 600.0
	camera.fov = Settings.fov
	add_child(camera)
	camera.make_current()

	viewmodel = Viewmodel.new()
	viewmodel.name = "Viewmodel"
	camera.add_child(viewmodel)

	_load_default_weapons()
	stats.died.connect(_on_died)
	stats.changed.connect(func() -> void: Events.player_stats_changed.emit())
	stats.skill_increased.connect(_on_skill_increased)
	stats.level_up.connect(_on_level_up)
	Settings.settings_changed.connect(_on_settings_changed)
	_on_settings_changed()
	head_anchor.get_global_transform_interpolated()


func _load_default_weapons() -> void:
	weapons.clear()
	var sword := load("res://data/weapons/sword.tres") as WeaponData
	if sword:
		weapons.append(sword)
	_equip_index(0)


func add_weapon(w: WeaponData) -> bool:
	for existing in weapons:
		if existing.id == w.id:
			return false
	weapons.append(w)
	Events.notify.emit("Nueva arma: %s (tecla %d)" % [w.display_name, weapons.size()], "item")
	Audio.play_2d("equip", -4.0)
	return true


func _equip_index(i: int) -> void:
	if weapons.is_empty():
		weapon = null
		viewmodel.set_weapon("unarmed", "", "")
		return
	weapon_index = clampi(i, 0, weapons.size() - 1)
	weapon = weapons[weapon_index]
	var off := offhand_id if (weapon.kind in ["sword", "axe", "mace", "dagger"] and not weapon.two_handed) else ""
	viewmodel.set_weapon(weapon.kind, weapon.model_id, off)
	_attack = {}
	_blocking = false
	Audio.play_2d("equip", -8.0, 1.0, 0.1)


## Coloca al jugador (al iniciar o cargar partida).
func teleport(pos: Vector3, yaw_deg: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_yaw = deg_to_rad(yaw_deg)
	_pitch = 0.0
	reset_physics_interpolation()
	head_anchor.reset_physics_interpolation()


func get_yaw_degrees() -> float:
	return rad_to_deg(_yaw)


func look_direction() -> Vector3:
	return -camera.global_basis.z


func _on_settings_changed() -> void:
	if camera:
		camera.fov = Settings.fov
		viewmodel.update_fov(Settings.fov)


# ---------------------------------------------------------------------------
# Entrada
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		_yaw -= mm.relative.x * sens
		_pitch -= mm.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch, deg_to_rad(-88.0), deg_to_rad(88.0))
		_look_delta += mm.relative
	elif event.is_action_pressed("weapon_next"):
		if not weapons.is_empty():
			_equip_index((weapon_index + 1) % weapons.size())
	elif event.is_action_pressed("weapon_prev"):
		if not weapons.is_empty():
			_equip_index((weapon_index - 1 + weapons.size()) % weapons.size())
	else:
		for k in 5:
			if event.is_action_pressed("weapon_%d" % (k + 1)) and k < weapons.size() and k != weapon_index:
				_equip_index(k)
		if event.is_action_pressed("interact"):
			_try_interact()


# ---------------------------------------------------------------------------
# Bucle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_dead:
		_process_death(delta)
		_update_camera(delta)
		return
	# Mirada con mando
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.05 and controls_enabled:
		_yaw -= look.x * 2.6 * delta
		_pitch = clampf(_pitch - look.y * 2.0 * delta, deg_to_rad(-88.0), deg_to_rad(88.0))
		_look_delta += look * 12.0
	_update_camera(delta)
	var local_vel := Basis(Vector3.UP, _yaw).inverse() * velocity
	var hspeed := Vector2(velocity.x, velocity.z).length()
	viewmodel.update_motion(delta, hspeed, local_vel, is_on_floor(), _sprinting, _look_delta, _crouching, _wall_distance())
	_look_delta = Vector2.ZERO
	_update_interaction(delta)
	_update_target(delta)


func _update_camera(delta: float) -> void:
	var anchor := head_anchor.get_global_transform_interpolated().origin
	_step_smooth = move_toward(_step_smooth, 0.0, delta * 3.5)
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	_shake_t += delta * 30.0
	var shake := _trauma * _trauma
	var sx := (sin(_shake_t * 1.3) + sin(_shake_t * 2.9 + 1.0) * 0.5) * shake * 0.035
	var sy := (sin(_shake_t * 1.7 + 2.0) + sin(_shake_t * 3.3) * 0.5) * shake * 0.035
	_kick = _kick.lerp(Vector2.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	var roll := 0.0
	if _dodge_time > 0.0:
		roll = -_dodge_dir.dot(Basis(Vector3.UP, _yaw).x) * 0.08 * (_dodge_time / 0.28)
	var pos := anchor + Vector3(0, -_step_smooth, 0)
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch + sy + _kick.y, _yaw + sx + _kick.x, roll)), pos)
	var target_fov := Settings.fov + (6.0 if _sprinting and Vector2(velocity.x, velocity.z).length() > 5.0 else 0.0)
	_fov_kick = lerpf(_fov_kick, target_fov - Settings.fov, clampf(delta * 5.0, 0.0, 1.0))
	camera.fov = Settings.fov + _fov_kick


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y -= GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		move_and_slide()
		return
	_update_water()
	_track_safe_position(delta)
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var wish := yaw_basis * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	# Agacharse
	var want_crouch := controls_enabled and Input.is_action_pressed("crouch") and not _swimming
	if want_crouch != _crouching:
		if want_crouch or _can_stand():
			_set_crouch(want_crouch)
	_eye = move_toward(_eye, CROUCH_EYE if _crouching else EYE_HEIGHT, delta * 4.0)
	head_anchor.position.y = _eye

	# Carrera
	var moving_forward := input.y < -0.3
	_sprinting = controls_enabled and Input.is_action_pressed("sprint") and moving_forward and not _crouching \
			and stats.stamina > 1.0 and not _blocking and not _drawing
	var speed := WALK_SPEED
	if _sprinting:
		speed = RUN_SPEED
		stats.stamina = maxf(0.0, stats.stamina - 11.0 * delta)
		_stamina_delay = 0.6
		stats.changed.emit()
		if Engine.get_physics_frames() % 30 == 0:
			stats.train("athletics", 0.25)
	elif _crouching:
		speed = CROUCH_SPEED
	if input.y > 0.3:
		speed *= 0.82
	if _blocking or _drawing:
		speed *= 0.55
	if _swimming:
		speed = SWIM_SPEED
	speed *= stats.move_speed_multiplier() * stats.slow_factor()
	var over := GameState.carry_weight() - (60.0 + stats.attr("strength") * 1.2)
	if over > 0.0:
		speed *= clampf(1.0 - over / 40.0, 0.4, 1.0)

	var target := wish * speed
	var on_floor := is_on_floor()
	var accel := 11.0 if on_floor else 2.2
	if _swimming:
		accel = 4.0
	if _dodge_time > 0.0:
		_dodge_time -= delta
		target = _dodge_dir * 9.0 * (_dodge_time / 0.28 + 0.4)
		accel = 30.0
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))

	# Gravedad, salto, nado
	if _swimming:
		velocity.y -= GRAVITY * 0.12 * delta
		velocity.y = lerpf(velocity.y, 0.0, clampf(delta * 2.0, 0.0, 1.0))
		if controls_enabled and Input.is_action_pressed("jump"):
			velocity.y = minf(velocity.y + 9.0 * delta, 2.6)
	else:
		if not on_floor:
			velocity.y -= GRAVITY * delta
		elif controls_enabled and Input.is_action_just_pressed("jump") and not _crouching:
			if stats.use_stamina(7.0):
				velocity.y = JUMP_VELOCITY * (1.0 + (stats.skill("acrobatics") - 10) / 400.0)
				_stamina_delay = 0.5
				Audio.play_2d("jump", -10.0, 1.0, 0.1)
				stats.train("acrobatics", 0.5)

	# Esquiva
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if controls_enabled and Input.is_action_just_pressed("dodge") and on_floor and _dodge_cd <= 0.0 and _dodge_time <= 0.0:
		if stats.use_stamina(18.0):
			_dodge_dir = wish.normalized() if wish.length() > 0.2 else yaw_basis * Vector3(0, 0, 1)
			_dodge_time = 0.28
			_dodge_cd = 0.75
			_invulnerable = 0.22
			_stamina_delay = 0.8
			Audio.play_2d("jump", -6.0, 0.8)
			stats.train("acrobatics", 1.0)

	_try_step_up(delta)
	_prev_vel_y = velocity.y
	move_and_slide()

	# Aterrizaje y daño por caída
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		var impact := -_prev_vel_y
		if impact > 3.0:
			viewmodel.land(impact)
			Audio.play_2d("land", linear_to_db(clampf(impact / 10.0, 0.2, 1.0)) - 4.0)
			_trauma = minf(_trauma + impact * 0.025, 0.5)
		if impact > 11.5 and not _swimming:
			var dmg := pow(impact - 11.5, 1.6) * 3.0 * (1.0 - stats.skill("acrobatics") / 250.0)
			take_damage_raw(dmg, "fall")
	_was_on_floor = now_floor

	# Pasos
	if now_floor and not _swimming:
		_step_accum += Vector2(velocity.x, velocity.z).length() * delta
		var stride := 2.9 if _sprinting else (1.7 if _crouching else 2.3)
		if _step_accum > stride:
			_step_accum = 0.0
			_play_footstep()
	_combat(delta)
	_regen(delta)
	var dot := stats.tick_effects(delta)
	if dot > 0.0 and not is_dead:
		stats.apply_damage(dot)


var _safe_pos := Vector3.INF
var _safe_timer := 0.0


## Guarda periódicamente una posición segura; si el jugador cae fuera del
## mundo (por un fallo de colisión), vuelve a ella.
func _track_safe_position(delta: float) -> void:
	_safe_timer -= delta
	if is_on_floor() and _safe_timer <= 0.0:
		_safe_timer = 1.0
		_safe_pos = global_position
	if global_position.y < -20.0 and _safe_pos != Vector3.INF:
		teleport(_safe_pos + Vector3(0, 0.5, 0), rad_to_deg(_yaw))
		Events.notify.emit("Has vuelto a una posición segura.", "warning")


func _regen(delta: float) -> void:
	_stamina_delay = maxf(_stamina_delay - delta, 0.0)
	stats.regen(delta, _stamina_delay <= 0.0 and not _sprinting and not _blocking)


func _set_crouch(enable: bool) -> void:
	_crouching = enable
	_capsule.height = CROUCH_HEIGHT if enable else STAND_HEIGHT
	_collision.position.y = _capsule.height * 0.5


func _can_stand() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = _capsule.radius - 0.02
	shape.height = STAND_HEIGHT
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.02, 0))
	params.collision_mask = MASK_WORLD
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## Sube escalones de hasta STEP_HEIGHT sin saltar (losas, escaleras, bordes).
func _try_step_up(delta: float) -> void:
	if not is_on_floor() or _swimming:
		return
	var horiz := Vector3(velocity.x, 0, velocity.z) * delta
	if horiz.length() < 0.001:
		return
	var motion := horiz.normalized() * maxf(horiz.length(), 0.05)
	var xf := global_transform
	if not test_move(xf, motion):
		return
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(xf, up):
		return
	var raised := xf.translated(up)
	if test_move(raised, motion):
		return
	# Buscar el suelo tras el escalón
	var col := KinematicCollision3D.new()
	var moved := raised.translated(motion)
	if test_move(moved, -up, col):
		var drop := col.get_travel().length()
		var rise := STEP_HEIGHT - drop
		if rise > 0.05 and rise <= STEP_HEIGHT + 0.01:
			var n := col.get_normal()
			if n.y > 0.7:
				global_position.y += rise + 0.01
				_step_smooth += rise
				reset_physics_interpolation()


func _update_water() -> void:
	if world == null:
		_swimming = false
		return
	var chest := world.block_at(global_position + Vector3(0, 1.0, 0))
	var head := world.block_at(camera.global_position) if camera else -1
	_swimming = chest == BlockTypes.WATER
	_head_underwater = head == BlockTypes.WATER


func is_underwater() -> bool:
	return _head_underwater


func _play_footstep() -> void:
	var id := -1
	if world:
		id = world.block_at(global_position + Vector3(0, -0.2, 0))
		if id <= 0:
			id = world.block_at(global_position + Vector3(0, -0.7, 0))
	var snd := BlockTypes.sound_name(id) if id > 0 else "step_grass"
	var vol := -12.0 if _crouching else (-6.0 if _sprinting else -9.0)
	Audio.play_2d(snd, vol, 1.0, 0.12)


func _wall_distance() -> float:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 1.0, MASK_WORLD, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 10.0
	return from.distance_to(hit["position"])


# ---------------------------------------------------------------------------
# Interacción y objetivo
# ---------------------------------------------------------------------------

func _interaction_ray() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_basis.z * INTERACT_DISTANCE
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ACTORS | MASK_INTERACT, [get_rid()])
	q.collide_with_areas = true
	return space.intersect_ray(q)


static func _find_interactable(node: Object) -> Object:
	var n := node as Node
	var depth := 0
	while n != null and depth < 4:
		if n.has_method("interact") and n.has_method("get_interaction_text"):
			return n
		n = n.get_parent()
		depth += 1
	return null


func _update_interaction(_delta: float) -> void:
	if not controls_enabled:
		return
	var hit := _interaction_ray()
	var target: Object = null
	if not hit.is_empty():
		target = _find_interactable(hit["collider"])
	if target != _interact_target:
		_interact_target = target
		var text := ""
		if target != null:
			text = str(target.call("get_interaction_text"))
		Events.interaction_hint.emit(text)
	elif target != null and Engine.get_process_frames() % 15 == 0:
		Events.interaction_hint.emit(str(target.call("get_interaction_text")))


func _try_interact() -> void:
	if _interact_target != null and is_instance_valid(_interact_target):
		viewmodel.play_action("interact", 1.2)
		_interact_target.call("interact", self)
		_interact_target = null
		Events.interaction_hint.emit("")


func _update_target(delta: float) -> void:
	_target_timer -= delta
	if _target_timer > 0.0:
		return
	_target_timer = 0.15
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 14.0, MASK_WORLD | MASK_ACTORS, [get_rid()])
	var hit := space.intersect_ray(q)
	var t: Node = null
	if not hit.is_empty():
		var c := hit["collider"] as Node
		if c != null and c.has_method("take_hit") and c.has_method("is_alive") and bool(c.call("is_alive")):
			t = c
	if t != _current_target:
		_current_target = t
		Events.target_changed.emit(t)


# ---------------------------------------------------------------------------
# Combate
# ---------------------------------------------------------------------------

func _combat(delta: float) -> void:
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo = 0
	if not controls_enabled:
		return
	var kind := weapon.kind if weapon else "unarmed"
	_spell_cd = maxf(_spell_cd - delta, 0.0)
	if Input.is_action_just_pressed("spell_next"):
		spell_index = (spell_index + 1) % spells.size()
		Events.notify.emit("Hechizo preparado: %s" % SPELLS[spells[spell_index]]["name"], "info")
	if Input.is_action_just_pressed("cast_spell") and _attack.is_empty() and not _drawing:
		_cast_spell()
	if kind == "bow":
		_bow_combat(delta)
		return

	# Bloqueo
	var want_block := Input.is_action_pressed("block") and kind != "bow" and stats.stamina > 2.0 and _attack.is_empty()
	if want_block != _blocking:
		_blocking = want_block
		viewmodel.set_blocking(want_block)
		_block_time = 0.0
	if _blocking:
		_block_time += delta
		_stamina_delay = 0.4

	if Input.is_action_just_pressed("attack"):
		_queued_attack = true
		_queue_time = 0.4
	_queue_time -= delta
	if _queue_time <= 0.0:
		_queued_attack = false

	if not _attack.is_empty():
		_attack_prev_t = _attack_t
		var spd := weapon.speed if weapon else 1.0
		_attack_t += delta * spd
		var window: Array = _attack["hit"]
		if _attack_t >= float(window[0]) and _attack_prev_t <= float(window[1]) and not _hit_world:
			_sweep(maxf(_attack_prev_t, float(window[0])), minf(_attack_t, float(window[1])))
		if _attack_t >= _attack_len:
			_attack = {}
		elif _queued_attack and _attack_t > float(window[1]) + 0.06:
			_attack = {}
	if _attack.is_empty() and _queued_attack and not _blocking:
		_queued_attack = false
		_start_attack(kind)


func _bow_combat(delta: float) -> void:
	if _blocking:
		_blocking = false
		viewmodel.set_blocking(false)
	if Input.is_action_just_pressed("attack") and not _drawing:
		if GameState.item_count("arrow") <= 0:
			Events.notify.emit("No te quedan flechas.", "warning")
			return
		_drawing = true
		_bow_draw = 0.0
		viewmodel.play_action("bow_draw", 1.0, 0.05)
		Audio.play_2d("bow_draw", -6.0)
	if _drawing:
		_bow_draw += delta
		if _bow_draw > 0.85 and viewmodel.current_action() != "bow_hold":
			viewmodel.bow_hold()
		_fov_kick = lerpf(_fov_kick, -8.0, clampf(delta * 4.0, 0.0, 1.0))
		if not Input.is_action_pressed("attack"):
			_drawing = false
			if _bow_draw < 0.3:
				viewmodel.bow_release()
				return
			_fire_arrow(clampf(_bow_draw / 0.85, 0.3, 1.0))


func _fire_arrow(power: float) -> void:
	if not GameState.remove_item("arrow", 1):
		return
	viewmodel.bow_release()
	var dir := -camera.global_basis.z
	var from := camera.global_position + dir * 0.4 + camera.global_basis.y * -0.05
	var dmg := (weapon.roll_damage(_rng) if weapon else 8.0) * (0.75 + stats.skill("archery") / 120.0) * (0.45 + 0.55 * power)
	var p := Projectile.spawn(get_tree().current_scene, "arrow", from, dir * lerpf(20.0, 48.0, power), dmg, self)
	p.set_meta("player_arrow", true)
	Audio.play_2d("bow_release", -3.0, 1.0, 0.05)
	stats.train("archery", 0.8)
	stats.use_stamina(weapon.stamina_cost if weapon else 4.0)


func _cast_spell() -> void:
	if _spell_cd > 0.0:
		return
	var sid := spells[spell_index]
	var sp: Dictionary = SPELLS[sid]
	if not stats.use_mana(float(sp["cost"])):
		Events.notify.emit("No tienes suficiente magia.", "warning")
		return
	_spell_cd = float(sp["cooldown"])
	if weapon == null or weapon.kind == "unarmed":
		viewmodel.play_action("spell_cast", 1.2, 0.05)
	else:
		viewmodel.play_left_gesture("spell_cast")
	Audio.play_2d("spell_cast", -3.0, 1.0, 0.08)
	var skill_v := stats.skill(str(sp["skill"]))
	var power := (1.0 + (stats.attr("intelligence") - 40) / 100.0) * (0.7 + skill_v / 100.0)
	var dir := -camera.global_basis.z
	var from := camera.global_position + dir * 0.6 + camera.global_basis.x * -0.15
	match sid:
		"fireball":
			Projectile.spawn(get_tree().current_scene, "fireball", from, dir * 22.0, 22.0 * power, self)
			Audio.play_2d("fireball", -6.0)
		"frost":
			Projectile.spawn(get_tree().current_scene, "frost", from, dir * 30.0, 14.0 * power, self)
		"heal":
			stats.heal(30.0 * power)
			stats.effects.erase("poison")
			stats.effects.erase("burn")
			Audio.play_2d("heal", -3.0)
			HitFX.spawn(get_tree().current_scene, "heal", global_position + Vector3(0, 1.0, 0), Vector3.UP)
	stats.train(str(sp["skill"]), 1.0)


func current_spell_name() -> String:
	return str(SPELLS[spells[spell_index]]["name"])


func _start_attack(kind: String) -> void:
	var cost := weapon.stamina_cost if weapon else 6.0
	if not stats.use_stamina(cost):
		Events.notify.emit("Estás demasiado cansado para atacar.", "warning")
		Audio.play_2d("player_effort", -10.0)
		return
	_stamina_delay = 0.9
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_attack = AttackPatterns.pick(kind, _combo, input)
	stat_swings += 1
	_attack_t = 0.0
	_attack_prev_t = 0.0
	_hit_targets.clear()
	_hit_world = false
	var anim_name: String = _attack["anim"]
	var anim := viewmodel.anim.get_animation(anim_name) if viewmodel.has_animation(anim_name) else null
	_attack_len = anim.length if anim else 0.7
	viewmodel.play_action(anim_name, weapon.speed if weapon else 1.0, 0.06)
	_combo += 1
	_combo_timer = 1.1
	var swing_sound: String = _attack.get("sound", "swing")
	get_tree().create_timer(float((_attack["hit"] as Array)[0]) * 0.8 / (weapon.speed if weapon else 1.0)).timeout.connect(
			func() -> void: Audio.play_2d(swing_sound, -4.0, 1.0, 0.1))


## Barre con rayos el tramo del arco correspondiente al intervalo [t0, t1].
func _sweep(t0: float, t1: float) -> void:
	var window: Array = _attack["hit"]
	var h0 := float(window[0])
	var h1 := float(window[1])
	var a0 := clampf((t0 - h0) / maxf(h1 - h0, 0.001), 0.0, 1.0)
	var a1 := clampf((t1 - h0) / maxf(h1 - h0, 0.001), 0.0, 1.0)
	var from_ang: Vector2 = _attack["from"]
	var to_ang: Vector2 = _attack["to"]
	var reach := (weapon.reach if weapon else 1.4) + float(_attack.get("reach_bonus", 0.0))
	var space := get_world_3d().direct_space_state
	var origin := camera.global_position
	var samples := 4
	for i in samples + 1:
		var a := lerpf(a0, a1, float(i) / samples)
		var ang := from_ang.lerp(to_ang, a)
		var local_dir := Basis.from_euler(Vector3(deg_to_rad(ang.y), deg_to_rad(-ang.x), 0.0)) * Vector3.FORWARD
		var dir := camera.global_basis * local_dir
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, MASK_WORLD | MASK_ACTORS, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var col := hit["collider"] as Node
		if col != null and col.has_method("take_hit"):
			if col in _hit_targets:
				continue
			_hit_targets.append(col)
			stat_hits += 1
			_deliver_hit(col, hit["position"], hit["normal"], dir)
		else:
			# Solo rebota contra el escenario si el golpe va dirigido de lleno a él
			# (centro del arco o justo delante de la mira); los extremos del arco
			# rozando una pared no detienen el tajo.
			var central := absf(a - 0.5) < 0.2 or local_dir.angle_to(Vector3.FORWARD) < deg_to_rad(18.0)
			var dist := origin.distance_to(hit["position"])
			if central and dist < reach * 0.8 and _hit_targets.is_empty():
				_hit_world = true
				stat_world_hits += 1
				HitFX.spawn(get_tree().current_scene, "sparks", hit["position"], hit["normal"])
				Audio.play_3d("hit_wall", hit["position"], -2.0)
				_trauma = minf(_trauma + 0.15, 0.6)
				attacked.emit(false)
				return


func _deliver_hit(target: Node, pos: Vector3, normal: Vector3, dir: Vector3) -> void:
	var w := weapon
	var base := w.roll_damage(_rng) if w else _rng.randf_range(2.0, 4.0)
	var skill_name := w.skill if w else "blade"
	var dmg := base * stats.melee_multiplier(skill_name) * float(_attack.get("dmg", 1.0))
	var crit := _rng.randf() < stats.crit_chance()
	if _crouching and target.has_method("is_aware") and not bool(target.call("is_aware")):
		dmg *= 2.5
		crit = true
		Events.notify.emit("¡Ataque furtivo!", "combat")
	if crit:
		dmg *= 1.5
	var info := {
		"attacker": self, "position": pos, "normal": normal, "direction": dir,
		"damage_type": w.damage_type if w else "blunt", "critical": crit,
		"stagger": float(_attack.get("dmg", 1.0)),
	}
	var result: String = str(target.call("take_hit", dmg, info))
	stats.train(skill_name, 1.0 if result != "blocked" else 0.4)
	_trauma = minf(_trauma + (0.22 if crit else 0.14), 0.6)
	_kick += Vector2(_rng.randf_range(-0.004, 0.004), 0.006)
	attacked.emit(true)
	# Pequeña pausa de impacto para dar peso al golpe
	viewmodel.anim.speed_scale = 0.15
	get_tree().create_timer(0.06, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(viewmodel):
			viewmodel.anim.speed_scale = 1.0)


## Daño recibido de un ataque (con posibilidad de bloqueo o esquiva).
## Devuelve "dodged", "blocked", "parried" o "hit".
func take_hit(amount: float, info: Dictionary) -> String:
	if is_dead:
		return "dead"
	if _invulnerable > 0.0:
		return "dodged"
	var attacker_pos: Vector3 = info.get("position", global_position)
	var attacker := info.get("attacker", null) as Node3D
	if attacker:
		attacker_pos = attacker.global_position
	var to_attacker := attacker_pos - global_position
	to_attacker.y = 0.0
	var facing := -camera.global_basis.z
	facing.y = 0.0
	var front := facing.normalized().dot(to_attacker.normalized()) > 0.35
	if _blocking and front and bool(info.get("blockable", true)):
		var w := weapon
		var reduction := w.block_reduction if w else 0.4
		if offhand_id != "" and viewmodel.offhand_id != "":
			reduction = maxf(reduction, 0.82)
		var cost := (w.block_stamina_cost if w else 12.0) + amount * 0.6
		stats.use_stamina(cost)
		_stamina_delay = 1.0
		stats.train("block", 1.0)
		viewmodel.block_impact()
		_trauma = minf(_trauma + 0.12, 0.6)
		var hit_pos := global_position + Vector3(0, 1.3, 0) + to_attacker.normalized() * 0.6
		HitFX.spawn(get_tree().current_scene, "sparks", hit_pos, to_attacker.normalized())
		Audio.play_3d("block", hit_pos, 0.0)
		var parry := _block_time < 0.28
		if parry:
			Events.notify.emit("¡Parada perfecta!", "combat")
			return "parried"
		take_damage_raw(amount * (1.0 - reduction) * 0.5, str(info.get("damage_type", "slash")), attacker_pos)
		return "blocked"
	var dmg := stats.mitigate(amount, str(info.get("damage_type", "slash")))
	take_damage_raw(dmg, str(info.get("damage_type", "slash")), attacker_pos)
	return "hit"


## Daño directo (caídas, trampas, efectos).
func take_damage_raw(amount: float, _kind: String = "", source_pos: Vector3 = Vector3.INF) -> void:
	if is_dead or amount <= 0.0:
		return
	stats.apply_damage(amount)
	_trauma = minf(_trauma + 0.35, 0.8)
	_kick += Vector2(_rng.randf_range(-0.02, 0.02), 0.025)
	if not is_dead:
		viewmodel.play_action((weapon.kind if weapon else "unarmed") + "_hurt", 1.0, 0.04)
		Audio.play_2d("player_hurt", -3.0, 1.0, 0.08)
	Events.player_damaged.emit(amount, source_pos if source_pos != Vector3.INF else global_position)


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	controls_enabled = false
	_death_t = 0.0
	viewmodel.die()
	Audio.play_2d("player_death", -2.0)
	Events.player_died.emit()
	died.emit()


func _process_death(delta: float) -> void:
	_death_t += delta
	var t := clampf(_death_t / 1.2, 0.0, 1.0)
	_eye = lerpf(EYE_HEIGHT, 0.25, t * t)
	head_anchor.position.y = _eye
	_pitch = lerpf(_pitch, deg_to_rad(10.0), delta * 2.0)
	_kick.x = lerpf(_kick.x, 0.0, delta)


func revive(pos: Vector3, yaw_deg: float) -> void:
	is_dead = false
	stats.dead = false
	stats.health = stats.max_health * 0.6
	stats.stamina = stats.max_stamina
	stats.changed.emit()
	_eye = EYE_HEIGHT
	head_anchor.position.y = _eye
	controls_enabled = true
	viewmodel.revive()
	teleport(pos, yaw_deg)


func _on_skill_increased(skill: String, value: int) -> void:
	Events.notify.emit("%s ha mejorado a %d" % [Stats.SKILL_NAMES.get(skill, skill), value], "skill")


func _on_level_up(new_level: int) -> void:
	Events.notify.emit("¡Has alcanzado el nivel %d!" % new_level, "level")
	Audio.play_2d("level_up", -2.0)


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func is_blocking() -> bool:
	return _blocking


func is_crouching() -> bool:
	return _crouching


func is_sprinting() -> bool:
	return _sprinting
