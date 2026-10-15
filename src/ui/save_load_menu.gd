class_name SaveLoadMenu
extends PanelContainer
## Lista de partidas para guardar o cargar.

signal closed

var save_mode: bool = false
var _list: ItemList
var _name: LineEdit
var _status: Label
var _saves: Array[Dictionary] = []


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(640, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UITheme.title_label("Guardar partida" if save_mode else "Cargar partida", 32))
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(600, 300)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(func(_i: int) -> void: _on_confirm())
	v.add_child(_list)
	if save_mode:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "Nombre:"
		h.add_child(l)
		_name = LineEdit.new()
		_name.custom_minimum_size = Vector2(480, 36)
		_name.text = "partida_%d" % (Time.get_unix_time_from_system() as int % 100000)
		_name.max_length = 40
		h.add_child(_name)
		v.add_child(h)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(UITheme.button("Guardar" if save_mode else "Cargar", _on_confirm, 180))
	buttons.add_child(UITheme.button("Borrar", _on_delete, 140))
	buttons.add_child(UITheme.button("Volver", func() -> void: closed.emit(), 140))
	v.add_child(buttons)
	refresh()


func refresh() -> void:
	_list.clear()
	_saves = GameState.list_saves()
	for s in _saves:
		_list.add_item(str(s["label"]))
	if _saves.is_empty():
		_status.text = "No hay partidas guardadas." if not save_mode else "Escribe un nombre y pulsa Guardar."


func _on_selected(i: int) -> void:
	if save_mode and i < _saves.size():
		_name.text = str(_saves[i]["slot"])


func _on_confirm() -> void:
	if save_mode:
		var slot := _name.text.strip_edges().validate_filename().replace(" ", "_")
		if slot == "":
			_status.text = "Nombre no válido."
			return
		var err := GameState.save_game(slot)
		_status.text = "Partida guardada." if err == OK else "Error al guardar: %s" % error_string(err)
		refresh()
	else:
		var sel := _list.get_selected_items()
		if sel.is_empty():
			_status.text = "Selecciona una partida."
			return
		var s := _saves[sel[0]]
		if not bool(s.get("valid", false)):
			_status.text = "Esa partida está dañada y no se puede cargar."
			return
		var msg := GameState.load_game(str(s["slot"]))
		if msg != "":
			_status.text = msg


func _on_delete() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var slot := str(_saves[sel[0]]["slot"])
	DirAccess.remove_absolute(GameState.SAVE_DIR.path_join(slot + ".json"))
	_status.text = "Partida '%s' borrada." % slot
	refresh()
