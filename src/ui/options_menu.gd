class_name OptionsMenu
extends PanelContainer
## Menú de opciones (vídeo, audio y controles). Se guarda en user://settings.cfg.

signal closed

var _rows: VBoxContainer


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(620, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UITheme.title_label("Opciones", 34))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	_section("Vídeo")
	_check("Pantalla completa", Settings.fullscreen, func(b: bool) -> void: Settings.fullscreen = b)
	_check("Sincronización vertical (V-Sync)", Settings.vsync, func(b: bool) -> void: Settings.vsync = b)
	_slider("Campo de visión", 55, 100, 1, Settings.fov, func(x: float) -> void: Settings.fov = x)
	_slider("Distancia de dibujado (chunks)", 3, 12, 1, Settings.view_distance, func(x: float) -> void: Settings.view_distance = int(x))
	_option("Sombras", ["Desactivadas", "Bajas", "Medias", "Altas"], Settings.shadow_quality, func(i: int) -> void: Settings.shadow_quality = i)
	_option("Antialiasing (MSAA)", ["No", "2x", "4x"], Settings.msaa, func(i: int) -> void: Settings.msaa = i)
	_slider("Escala de resolución 3D", 0.5, 1.0, 0.05, Settings.render_scale, func(x: float) -> void: Settings.render_scale = x)
	_check("Balanceo de cámara", Settings.head_bob, func(b: bool) -> void: Settings.head_bob = b)
	_check("Mostrar FPS / depuración (F3)", Settings.show_fps, func(b: bool) -> void: Settings.show_fps = b)
	_section("Audio")
	_slider("Volumen general", 0, 1, 0.05, Settings.master_volume, func(x: float) -> void: Settings.master_volume = x)
	_slider("Efectos", 0, 1, 0.05, Settings.sfx_volume, func(x: float) -> void: Settings.sfx_volume = x)
	_slider("Ambiente y música", 0, 1, 0.05, Settings.music_volume, func(x: float) -> void: Settings.music_volume = x)
	_section("Controles")
	_slider("Sensibilidad del ratón", 0.02, 0.5, 0.01, Settings.mouse_sensitivity, func(x: float) -> void: Settings.mouse_sensitivity = x)
	_check("Invertir eje Y", Settings.invert_y, func(b: bool) -> void: Settings.invert_y = b)
	var keys := Label.new()
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.add_theme_font_size_override("font_size", 15)
	keys.text = "WASD: moverse · Espacio: saltar · Mayús: correr · Ctrl/C: agacharse · Alt/V: esquivar\nClic izquierdo: atacar (dirección según el movimiento) · Clic derecho: bloquear\nE: interactuar · H: poción de salud · 1-5 / rueda: cambiar arma\nF5: guardado rápido · F9: carga rápida · F3: depuración · F12: captura · Esc: pausa"
	_rows.add_child(keys)
	var back := UITheme.button("Volver", _on_close)
	v.add_child(back)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UITheme.GOLD)
	l.add_theme_font_size_override("font_size", 20)
	_rows.add_child(l)


func _row(label_text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	_rows.add_child(h)
	return h


func _check(label_text: String, value: bool, cb: Callable) -> void:
	var h := _row(label_text)
	var c := CheckBox.new()
	c.button_pressed = value
	c.toggled.connect(func(b: bool) -> void:
		cb.call(b)
		_apply())
	h.add_child(c)


func _slider(label_text: String, mn: float, mx: float, step: float, value: float, cb: Callable) -> void:
	var h := _row(label_text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(200, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size = Vector2(60, 0)
	val.text = str(snappedf(value, step))
	s.value_changed.connect(func(x: float) -> void:
		val.text = str(snappedf(x, step))
		cb.call(x)
		_apply())
	h.add_child(s)
	h.add_child(val)


func _option(label_text: String, items: Array, selected: int, cb: Callable) -> void:
	var h := _row(label_text)
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.selected = selected
	o.item_selected.connect(func(i: int) -> void:
		cb.call(i)
		_apply())
	h.add_child(o)


func _apply() -> void:
	Settings.apply_all()


func _on_close() -> void:
	Settings.save_settings()
	closed.emit()
