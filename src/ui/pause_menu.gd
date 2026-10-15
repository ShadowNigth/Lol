class_name PauseMenu
extends CanvasLayer
## Menú de pausa: continuar, guardar, cargar, opciones, menú principal, salir.

var _root: Control
var _main: VBoxContainer
var _sub: Control = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	center.add_child(_main)
	_main.add_child(UITheme.title_label("Pausa", 44))
	_main.add_child(UITheme.button("Continuar", close))
	_main.add_child(UITheme.button("Guardar partida", func() -> void: _open_sub(_make_saveload(true))))
	_main.add_child(UITheme.button("Cargar partida", func() -> void: _open_sub(_make_saveload(false))))
	_main.add_child(UITheme.button("Opciones", func() -> void: _open_sub(_make_options())))
	_main.add_child(UITheme.button("Menú principal", func() -> void: GameState.go_to_menu()))
	_main.add_child(UITheme.button("Salir del juego", func() -> void: get_tree().quit()))


func _make_saveload(save: bool) -> Control:
	var m := SaveLoadMenu.new()
	m.save_mode = save
	m.closed.connect(_close_sub)
	return m


func _make_options() -> Control:
	var o := OptionsMenu.new()
	o.closed.connect(_close_sub)
	return o


func _open_sub(c: Control) -> void:
	_main.visible = false
	_sub = c
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(c)
	_root.add_child(center)


func _close_sub() -> void:
	if _sub:
		_sub.get_parent().queue_free()
		_sub = null
	_main.visible = true


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play_2d("ui_open", -8.0)


func close() -> void:
	if _sub:
		_close_sub()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		if _sub:
			_close_sub()
		else:
			close()
		get_viewport().set_input_as_handled()
