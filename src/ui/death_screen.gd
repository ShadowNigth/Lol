class_name DeathScreen
extends CanvasLayer
## Pantalla de muerte: cargar la última partida, reaparecer o volver al menú.

var _root: Control


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.0, 0.0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	var title := UITheme.title_label("Has muerto", 60)
	title.add_theme_color_override("font_color", Color(0.85, 0.2, 0.15))
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Tu viaje por la Marca de Vaelmoor se detiene aquí... por ahora."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UITheme.button("Cargar última partida", _load_last))
	v.add_child(UITheme.button("Reaparecer en la aldea", _respawn))
	v.add_child(UITheme.button("Menú principal", func() -> void: GameState.go_to_menu()))


func open() -> void:
	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.8)


func close() -> void:
	visible = false


func _load_last() -> void:
	var saves := GameState.list_saves()
	for s in saves:
		if bool(s.get("valid", false)):
			var msg := GameState.load_game(str(s["slot"]))
			if msg == "":
				return
	Events.notify.emit("No hay partidas guardadas válidas.", "warning")


func _respawn() -> void:
	var game := get_tree().current_scene
	if game and game.has_method("respawn_player"):
		game.call("respawn_player")
