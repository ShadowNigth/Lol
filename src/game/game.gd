class_name Game
extends Node3D
## Escena principal de juego: crea entorno, mundo por chunks, jugador, HUD,
## menús y gestiona la carga inicial, la pausa y la muerte.

var generator: WorldSource
var overworld_generator: WorldGenerator
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
var _switching := false
var _pending_spawn := Vector3.INF
var _pending_yaw := 0.0
var _player_light: OmniLight3D


func _ready() -> void:
	GameState.in_game = true
	loading = LoadingScreen.new()
	add_child(loading)
	_build_environment()
	_block_textures = TextureFactory.new().build_texture_array()
	overworld_generator = WorldGenerator.new(GameState.world_seed)

	player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.controls_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	GameState.player = player
	_player_light = OmniLight3D.new()
	_player_light.light_color = Color(1.0, 0.78, 0.5)
	_player_light.omni_range = 8.0
	_player_light.light_energy = 0.7
	_player_light.visible = false
	player.camera.add_child(_player_light)
	_player_light.position = Vector3(0.25, -0.35, 0.1)

	# Zona inicial: exterior o una mazmorra (si se carga una partida guardada dentro)
	var area: Dictionary = GameState.current_area
	if area.get("type", "overworld") == "dungeon":
		generator = DungeonGenerator.new(str(area.get("id", "crypt_velmar")), GameState.world_seed, int(area.get("difficulty", 1)))
	else:
		generator = overworld_generator
	_build_world()
	var spawn := generator.spawn_point()
	var yaw := generator.spawn_yaw()
	if not GameState.pending_load.is_empty():
		var p: Array = GameState.pending_load.get("position", [spawn.x, spawn.y, spawn.z])
		spawn = Vector3(float(p[0]), float(p[1]), float(p[2]))
		yaw = float(GameState.pending_load.get("yaw", yaw))
	player.teleport(spawn, yaw)
	world.update_focus(spawn)

	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(sun, env, sky_material)
	day_night.interior = generator.is_interior()

	hud = HUD.new()
	hud.setup(player, day_night, world)
	hud.name = "HUD"
	add_child(hud)
	hud.set_visible_hud(false)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	death_screen = DeathScreen.new()
	add_child(death_screen)
	game_menu = GameMenu.new()
	game_menu.player = player
	game_menu.game = self
	add_child(game_menu)
	player.died.connect(_on_player_died)
	world.initial_area_ready.connect(_on_world_ready)
	Settings.settings_changed.connect(_on_settings_changed)
	_ambient_day = Audio.make_loop_player_2d("wind_loop", self, -14.0)
	_ambient_night = Audio.make_loop_player_2d("night_loop", self, -60.0)
	_set_interior(generator.is_interior())


func _build_world() -> void:
	world = VoxelWorld.new()
	world.name = "VoxelWorld"
	add_child(world)
	world.setup(generator, _block_textures, Settings.view_distance if not generator.is_interior() else 4)
	player.world = world
	spawner = EntitySpawner.new()
	spawner.name = "Entities"
	add_child(spawner)
	spawner.setup(world, player)
	if hud:
		hud.world = world
	_apply_view_distance()


func _teardown_world() -> void:
	if spawner:
		spawner.queue_free()
		spawner = null
	if world:
		world.queue_free()
		world = null


func _set_interior(enabled: bool) -> void:
	if day_night:
		day_night.interior = enabled
	if enabled:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.0, 0.0, 0.0)
		env.fog_depth_begin = 3.0
		env.fog_depth_end = 30.0
		env.ambient_light_color = Color(0.1, 0.09, 0.11)
		env.fog_light_color = Color(0.015, 0.012, 0.02)
	else:
		env.background_mode = Environment.BG_SKY
		_apply_view_distance()
	if _player_light:
		_player_light.visible = enabled
	if _ambient_day:
		_ambient_day.stream_paused = enabled
	if enabled and not has_node("CaveAmbience"):
		var cave := Audio.make_loop_player_2d("cave_loop", self, -10.0)
		cave.name = "CaveAmbience"
	elif not enabled and has_node("CaveAmbience"):
		get_node("CaveAmbience").queue_free()


## Entra en una mazmorra (desde su puerta en el exterior).
func enter_dungeon(dungeon_id: String, entrance_entity: String) -> void:
	if _switching:
		return
	var back := player.global_position - player.look_direction() * 1.2
	back.y = player.global_position.y
	GameState.current_area = {"type": "dungeon", "id": dungeon_id, "difficulty": 1,
			"return": [back.x, back.y + 0.1, back.z], "return_yaw": player.get_yaw_degrees() + 180.0, "entrance": entrance_entity}
	var dg := DungeonGenerator.new(dungeon_id, GameState.world_seed, 1)
	_switch_area(dg, dg.spawn_point(), dg.spawn_yaw())
	QuestManager.on_area_entered(dungeon_id)
	Events.notify.emit("Desciendes a la oscuridad de %s..." % dg.display_name, "info")


## Vuelve al exterior junto a la entrada de la mazmorra.
func exit_dungeon() -> void:
	if _switching:
		return
	var ret: Array = GameState.current_area.get("return", [])
	var yaw := float(GameState.current_area.get("return_yaw", 0.0))
	var pos := overworld_generator.spawn_point()
	if ret.size() == 3:
		pos = Vector3(float(ret[0]), float(ret[1]), float(ret[2]))
	GameState.current_area = {"type": "overworld"}
	_switch_area(overworld_generator, pos, yaw)


func _switch_area(source: WorldSource, spawn: Vector3, yaw: float) -> void:
	_switching = true
	player.controls_enabled = false
	Events.target_changed.emit(null)
	var tw := hud.fade_to(1.0, 0.6)
	await tw.finished
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_teardown_world()
	await get_tree().process_frame
	generator = source
	_build_world()
	_set_interior(source.is_interior())
	_pending_spawn = spawn
	_pending_yaw = yaw
	player.teleport(spawn, yaw)
	world.update_focus(spawn)
	world.initial_area_ready.connect(_on_area_ready, CONNECT_ONE_SHOT)


func _on_area_ready() -> void:
	var p := _pending_spawn
	var ground := world.surface_height(p.x, p.z)
	if p.y < ground - 0.5 or p.y > ground + 3.0:
		p.y = ground
	player.teleport(p + Vector3(0, 0.05, 0), _pending_yaw)
	await get_tree().physics_frame
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.controls_enabled = true
	_switching = false
	_current_location = ""
	hud.fade_to(0.0, 0.8)


var _dialogue: DialogueUI
var game_menu: GameMenu


## Suelta un objeto delante del jugador (persistente hasta recogerlo).
func drop_item(id: String) -> void:
	var fwd := player.look_direction()
	fwd.y = 0.0
	var pos := player.global_position + fwd.normalized() * 0.9
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.0, 0), pos + Vector3(0, -3.0, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = hit["position"]
	var entry := GameState.add_dropped(id, pos)
	if spawner:
		spawner.spawn_dropped(entry)
	Events.notify.emit("Sueltas: %s" % ItemDB.display_name(id), "item")


## Abre la conversación con un PNJ.
func open_dialogue(npc: NPC) -> void:
	if _dialogue and is_instance_valid(_dialogue):
		return
	_dialogue = DialogueUI.new()
	add_child(_dialogue)
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_visible_hud(false)
	_dialogue.closed.connect(func() -> void:
		player.controls_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		hud.set_visible_hud(true))
	_dialogue.open(npc)


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
	if world == null or env == null:
		return
	if generator and generator.is_interior():
		world.view_radius = 4
		return
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
	if player == null or world == null:
		return
	world.update_focus(player.global_position)
	if _switching:
		return
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
	return _ready_done and not _switching


func current_location_name() -> String:
	if player == null or generator == null:
		return ""
	return generator.location_at(player.global_position.x, player.global_position.z)


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_done or _switching:
		return
	if event.is_action_pressed("pause"):
		if not player.is_dead and not pause_menu.visible:
			pause_menu.open()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not game_menu.visible and player.controls_enabled:
		game_menu.open(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character") and not game_menu.visible and player.controls_enabled:
		game_menu.open(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and not game_menu.visible and player.controls_enabled:
		game_menu.open(2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and not game_menu.visible and player.controls_enabled:
		game_menu.open(3)
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
	player.revive(generator.spawn_point(), generator.spawn_yaw())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var where := "a la entrada de la cripta" if generator.is_interior() else "en la plaza de Hojarrubia"
	Events.notify.emit("Despiertas %s. Has perdido %d monedas." % [where, gold_lost], "warning")
