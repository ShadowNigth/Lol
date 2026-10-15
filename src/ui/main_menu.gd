class_name MainMenu
extends Node3D
## Menú principal con un diorama 3D de la aldea al atardecer de fondo,
## creación de personaje, carga de partidas, opciones y créditos.

var _ui: Control
var _main_box: VBoxContainer
var _center: CenterContainer
var _sub: Control = null
var _cam: Camera3D
var _world: VoxelWorld
var _t := 0.0
var _continue_btn: Button


func _ready() -> void:
	get_tree().paused = false
	if "--self-test" in OS.get_cmdline_user_args():
		var test := SelfTest.new()
		add_child(test)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_ui()


func _build_backdrop() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 62.0
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var dn := DayNight.new()
	dn.time_scale = 0.0
	add_child(dn)
	var saved_time := GameState.time_of_day
	GameState.time_of_day = 17.6
	dn.setup(sun, env, sky_mat)
	GameState.time_of_day = saved_time
	_world = VoxelWorld.new()
	add_child(_world)
	_world.setup(WorldGenerator.new(20251015), TextureFactory.new().build_texture_array(), 3)
	_world.update_focus(Vector3(0, 40, 0))
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 300.0
	add_child(_cam)
	_cam.make_current()
	_update_camera(0.0)


func _process(delta: float) -> void:
	_t += delta
	_update_camera(delta)


func _update_camera(_delta: float) -> void:
	var a := _t * 0.035 + 0.6
	var r := 30.0
	_cam.position = Vector3(cos(a) * r, 52.0, sin(a) * r)
	_cam.look_at(Vector3(0, 39.0, 0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UITheme.get_theme()
	layer.add_child(_ui)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.015, 0.01, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_center)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	_center.add_child(_main_box)
	_main_box.add_child(UITheme.title_label("VAELMOOR", 84))
	var sub := Label.new()
	sub.text = "Crónicas de la Marca"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", UITheme.PARCHMENT)
	_main_box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	_main_box.add_child(spacer)
	_main_box.add_child(UITheme.button("Nueva partida", func() -> void: _open_sub(_make_new_game())))
	_continue_btn = UITheme.button("Continuar", _continue)
	_continue_btn.disabled = not GameState.has_any_save()
	_main_box.add_child(_continue_btn)
	_main_box.add_child(UITheme.button("Cargar partida", func() -> void: _open_sub(_make_load())))
	_main_box.add_child(UITheme.button("Opciones", func() -> void: _open_sub(_make_options())))
	_main_box.add_child(UITheme.button("Créditos", func() -> void: _open_sub(_make_credits())))
	_main_box.add_child(UITheme.button("Salir", func() -> void: get_tree().quit()))
	for c in _main_box.get_children():
		if c is Button:
			(c as Button).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ver := Label.new()
	ver.text = "v%s · Godot %s · Linux" % [ProjectSettings.get_setting("application/config/version", "0.1"), Engine.get_version_info()["string"]]
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top = -34
	ver.offset_left = 16
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 0.8))
	_ui.add_child(ver)


func _open_sub(c: Control) -> void:
	_main_box.visible = false
	_sub = CenterContainer.new()
	_sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(c)
	_ui.add_child(_sub)


func _close_sub() -> void:
	if _sub:
		_sub.queue_free()
		_sub = null
	_main_box.visible = true
	_continue_btn.disabled = not GameState.has_any_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _sub:
		_close_sub()


func _continue() -> void:
	for s in GameState.list_saves():
		if bool(s.get("valid", false)):
			var msg := GameState.load_game(str(s["slot"]))
			if msg == "":
				return


func _make_load() -> Control:
	var m := SaveLoadMenu.new()
	m.save_mode = false
	m.closed.connect(_close_sub)
	return m


func _make_options() -> Control:
	var o := OptionsMenu.new()
	o.closed.connect(_close_sub)
	return o


func _make_new_game() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Nuevo personaje", 34))
	var name_row := HBoxContainer.new()
	var nl := Label.new()
	nl.text = "Nombre:"
	nl.custom_minimum_size = Vector2(140, 0)
	name_row.add_child(nl)
	var name_edit := LineEdit.new()
	name_edit.text = "Aldric"
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(420, 36)
	name_row.add_child(name_edit)
	v.add_child(name_row)
	var class_row := HBoxContainer.new()
	var cl := Label.new()
	cl.text = "Clase:"
	cl.custom_minimum_size = Vector2(140, 0)
	class_row.add_child(cl)
	var class_opt := OptionButton.new()
	class_opt.add_item("Guerrero")
	class_opt.add_item("Explorador")
	class_opt.add_item("Mago de batalla")
	class_opt.custom_minimum_size = Vector2(420, 36)
	class_row.add_child(class_opt)
	v.add_child(class_row)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(580, 96)
	desc.add_theme_font_size_override("font_size", 15)
	v.add_child(desc)
	var classes := ["warrior", "rogue", "mage"]
	var descs := [
		"Guerrero: gran fuerza y resistencia. Empieza con espada larga y escudo. Domina las espadas, el bloqueo y las armas pesadas.",
		"Explorador: ágil y afortunado. Empieza con daga, espada, arco y cinco ganzúas. Destaca en sigilo, acrobacias y cerraduras.",
		"Mago de batalla: inteligencia y voluntad elevadas, más magia. Empieza con una maza. (La magia ofensiva llega en una fase posterior).",
	]
	var update_desc := func(i: int) -> void:
		var tpl := GameState.class_template(classes[i])
		var attrs: Dictionary = tpl["attributes"]
		var parts: Array[String] = []
		for a: String in Stats.ATTRIBUTES:
			parts.append("%s %d" % [Stats.ATTRIBUTE_NAMES[a].substr(0, 3), int(attrs[a])])
		desc.text = descs[i] + "\n" + "  ".join(parts)
	class_opt.item_selected.connect(update_desc)
	update_desc.call(0)
	var seed_row := HBoxContainer.new()
	var sl := Label.new()
	sl.text = "Semilla:"
	sl.custom_minimum_size = Vector2(140, 0)
	seed_row.add_child(sl)
	var seed_edit := LineEdit.new()
	seed_edit.placeholder_text = "Vacío = aleatoria (el mundo es reproducible con la misma semilla)"
	seed_edit.custom_minimum_size = Vector2(420, 36)
	seed_row.add_child(seed_edit)
	v.add_child(seed_row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var start_cb := func() -> void:
		var seed_text := seed_edit.text.strip_edges()
		var seed_value := 0
		if seed_text != "":
			seed_value = int(seed_text) if seed_text.is_valid_int() else absi(seed_text.hash())
		GameState.start_new_game({"name": name_edit.text, "class": classes[class_opt.selected], "seed": seed_value})
	buttons.add_child(UITheme.button("Comenzar aventura", start_cb, 300))
	buttons.add_child(UITheme.button("Volver", _close_sub, 160))
	v.add_child(buttons)
	return panel


func _make_credits() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UITheme.title_label("Créditos", 34))
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(600, 320)
	text.bbcode_enabled = true
	var f := FileAccess.open("res://ATTRIBUTIONS.md", FileAccess.READ)
	var body := f.get_as_text() if f else "Vaelmoor — proyecto original."
	text.text = "[b]Vaelmoor[/b] — RPG voxel de fantasía medieval.\nMotor: Godot Engine (licencia MIT).\nTodos los modelos, texturas, animaciones y sonidos se generan de forma procedural con código original del proyecto.\n\n" + body
	v.add_child(text)
	v.add_child(UITheme.button("Volver", _close_sub))
	return panel
