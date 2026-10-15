class_name Game
extends Node3D
## Escena principal de juego: crea entorno, mundo por chunks, jugador, HUD,
## menús y gestiona la carga inicial, la pausa y la muerte.

var generator: WorldGenerator
var world: VoxelWorld
var player: Player
var spawner: EntitySpawner
var hud: HUD
var day_night: DayNight
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_material: ShaderMaterial
var pause_menu: PauseMenu
var death_screen: DeathScreen
var loading: LoadingScreen
var _ready_done := false
var _location_timer := 0.0
var _current_location := ""
var _ambient_day: AudioStreamPlayer
var _ambient_night: AudioStreamPlayer
var _block_textures: Texture2DArray


func _ready() -> void:
	GameState.in_game = true
	loading = LoadingScreen.new()
	add_child(loading)
	_build_environment()
	_block_textures = TextureFactory.new().build_texture_array()
	generator = WorldGenerator.new(GameState.world_seed)
	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.setup(generator, _block_textures, Settings.view_distance)
	_apply_view_distance()

	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.world = world
	player.controls_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.player = player
	var spawn := generator.planner.spawn_point
	var yaw := generator.planner.spawn_yaw_deg
	if not GameState.pending_load.is_empty():
		var p: Array = GameState.pending_load.get("position", [spawn.x, spawn.y, spawn.z])
		spawn = Vector3(float(p[0]), float(p[1]), float(p[2]))
		yaw = float(GameState.pending_load.get("yaw", yaw))
	player.teleport(spawn, yaw)
	world.update_focus(spawn)

	spawner = EntitySpawner.new()
	spawner.name = "Entities"
	add_child(spawner)
	spawner.setup(world, player)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, env, sky_material)

	hud = HUD.new()
	hud.setup(player, day_night, world)
	add_child(hud)
	hud.set_visible_hud(false)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	death_screen = DeathScreen.new()
	add_child(death_screen)
	player.died.connect(_on_player_died)
	world.initial_area_ready.connect(_on_world_ready)
	Settings.settings_changed.connect(_on_settings_changed)
	_ambient_day = Audio.make_loop_player_2d("wind_loop", self, -14.0)
	_ambient_night = Audio.make_loop_player_2d("night_loop", self, -60.0)


func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.0
	sun.light_angular_distance = 0.5
	add_child(sun)
	_apply_shadow_settings()


func _apply_shadow_settings() -> void:
	var s := Settings.shadow_settings()
	sun.shadow_enabled = bool(s["enabled"])
	sun.directional_shadow_max_distance = float(s["distance"])
	match int(s["splits"]):
		1:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		2:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		_:
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS


func _apply_view_distance() -> void:
	var far := Settings.view_distance * 16.0
	env.fog_depth_begin = far * 0.45
	env.fog_depth_end = far - 6.0
	world.view_radius = Settings.view_distance


func _on_settings_changed() -> void:
	_apply_shadow_settings()
	_apply_view_distance()


func _on_world_ready() -> void:
	if _ready_done:
		return
	_ready_done = true
	# Asegurar que el jugador no aparece dentro de un bloque
	var p := player.global_position
	var ground := world.surface_height(p.x, p.z)
	if GameState.pending_load.is_empty() or p.y < ground - 0.5:
		p.y = maxf(p.y, ground) + 0.05
	player.teleport(p, player.get_yaw_degrees())
	_apply_new_or_loaded_player()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.controls_enabled = true
	loading.finish()
	hud.set_visible_hud(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.world_ready.emit()
	if GameState.pending_load.is_empty():
		Events.notify.emit("Bienvenido a la Marca de Vaelmoor, %s." % GameState.character_name, "info")
		Events.notify.emit("WASD mover · Ratón mirar · Clic izq. atacar · Clic der. bloquear · E interactuar", "info")
	GameState.pending_load = {}


func _apply_new_or_loaded_player() -> void:
	var data := GameState.pending_load
	if data.is_empty():
		var tpl := GameState.class_template(GameState.character_class)
		var attrs: Dictionary = tpl["attributes"]
		for a: String in attrs:
			player.stats.attributes[a] = attrs[a]
		var sk: Dictionary = tpl["skills"]
		for s: String in sk:
			if player.stats.skills.has(s):
				player.stats.skills[s] = sk[s]
		player.stats.recalc(true)
		player.weapons.clear()
		for wid: String in tpl["weapons"]:
			var w := load("res://data/weapons/%s.tres" % wid) as WeaponData
			if w:
				player.weapons.append(w)
		player._equip_index(0)
		player.gold = 25
		return
	player.stats.from_dict(data.get("stats", {}))
	player.gold = int(data.get("gold", 0))
	player.weapons.clear()
	for path: Variant in data.get("weapons", []):
		var w2 := load(str(path)) as WeaponData if ResourceLoader.exists(str(path)) else null
		if w2:
			player.weapons.append(w2)
	if player.weapons.is_empty():
		player.weapons.append(load("res://data/weapons/sword.tres") as WeaponData)
	player._equip_index(int(data.get("weapon_index", 0)))


func _process(delta: float) -> void:
	if player == null:
		return
	world.update_focus(player.global_position)
	if not _ready_done:
		loading.set_progress(world.loaded_chunk_count(), 25)
		return
	_location_timer -= delta
	if _location_timer <= 0.0:
		_location_timer = 0.5
		var loc := current_location_name()
		if loc != _current_location:
			_current_location = loc
			if loc != "":
				Events.location_entered.emit(loc)
	# Ambiente: viento de día, grillos de noche
	var night := clampf(-DayNight.sun_vector(GameState.time_of_day).y * 5.0, 0.0, 1.0)
	if _ambient_day:
		_ambient_day.volume_db = lerpf(-14.0, -22.0, night)
	if _ambient_night:
		_ambient_night.volume_db = lerpf(-50.0, -12.0, night)


func is_world_ready() -> bool:
	return _ready_done


func current_location_name() -> String:
	if player == null:
		return ""
	return generator.planner.location_at(player.global_position.x, player.global_position.z)


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done:
		return
	if event.is_action_pressed("pause"):
		if not player.is_dead and not pause_menu.visible:
			pause_menu.open()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save"):
		GameState.save_game("rapida")
	elif event.is_action_pressed("quick_load"):
		var err := GameState.load_game("rapida")
		if err != "":
			Events.notify.emit(err, "warning")
	elif event.is_action_pressed("use_potion"):
		if not GameState.use_item(player, "potion_health"):
			Events.notify.emit("No te quedan pociones de salud.", "warning")
	elif event.is_action_pressed("screenshot"):
		var img := get_viewport().get_texture().get_image()
		var path := "user://captura_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
		img.save_png(path)
		Events.notify.emit("Captura guardada en %s" % ProjectSettings.globalize_path(path), "info")


func _on_player_died() -> void:
	hud.set_visible_hud(true)
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		death_screen.open())


## Reaparece en la plaza de la aldea (desde la pantalla de muerte).
func respawn_player() -> void:
	death_screen.close()
	var gold_lost := player.gold / 3
	player.gold -= gold_lost
	player.revive(generator.planner.spawn_point, generator.planner.spawn_yaw_deg)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.notify.emit("Despiertas en la plaza de Hojarrubia. Has perdido %d monedas." % gold_lost, "warning")
