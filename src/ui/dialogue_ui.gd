class_name DialogueUI
extends CanvasLayer
## Ventana de conversación con PNJ: saludo según reputación, rumores,
## ofertas y seguimiento de misiones, entrega de misiones y comercio.

signal closed

var npc: NPC
var _root: Control
var _name: Label
var _text: RichTextLabel
var _options: VBoxContainer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 12
	_rng.randomize()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -330
	panel.offset_bottom = -24
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_name = Label.new()
	_name.add_theme_color_override("font_color", UITheme.GOLD)
	_name.add_theme_font_size_override("font_size", 22)
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.custom_minimum_size = Vector2(800, 120)
	_text.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(_text)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 4)
	v.add_child(_options)


func open(target: NPC) -> void:
	npc = target
	npc.start_talking()
	_name.text = npc.display_name()
	# Prisionero tras los barrotes: suplica y explica cómo sacarle
	if npc.is_caged():
		var cl: Array = npc.data.get("captive_lines", ["¡Sácame de aquí, por favor!"])
		_say(str(cl[_rng.randi() % cl.size()]))
		_clear_options()
		_option("Aguanta. Te sacaré de ahí.", close)
		return
	var results := QuestManager.on_talk(npc.npc_id)
	if not results.is_empty():
		var parts: Array[String] = []
		for r: Dictionary in results:
			var said := str(r.get("say", ""))
			if said != "":
				parts.append(resolve_text(said, npc.global_position))
			elif bool(r.get("completed", false)):
				parts.append("¡Gracias! Has cumplido lo que te pedí. Toma esto como recompensa.")
			else:
				parts.append("Bien hecho. Sigue así.")
		_say("\n\n".join(parts))
	elif npc.is_captive():
		# Rescatado sin la misión de su familia: se marcha a casa igualmente
		GameState.set_flag(npc.rescued_flag)
		GameState.add_reputation(str(npc.data.get("faction", "robledal")), 10)
		_say("¡Gracias, forastero! No sé quién eres, pero me has salvado la vida. Vuelvo a casa, a Robledal, antes de que vuelvan.")
	else:
		_say(_greeting())
	_main_options()


func _greeting() -> String:
	var data := npc.data
	# Saludos que dependen de la historia (banderas), por orden de prioridad
	var by_flag: Dictionary = data.get("greet_flags", {})
	for f: String in by_flag:
		if GameState.has_flag(f):
			var fl: Array = by_flag[f]
			return str(fl[_rng.randi() % fl.size()])
	var rep := GameState.reputation(str(data.get("faction", "hojarrubia")))
	var lines: Array = data.get("greet_friend", []) if rep >= 20 else data.get("greet", ["..."])
	if lines.is_empty():
		lines = data.get("greet", ["..."])
	return str(lines[_rng.randi() % lines.size()])


## Sustituye marcadores del texto: {dir:<lugar>} -> «230 m al sur» (desde
## `from` hasta ese lugar de la región).
static func resolve_text(text: String, from: Vector3) -> String:
	var out := text
	var guard := 0
	while out.find("{dir:") >= 0 and guard < 8:
		guard += 1
		var a := out.find("{dir:")
		var b := out.find("}", a)
		if b < 0:
			break
		var site_id := out.substr(a + 5, b - a - 5)
		var dir := "lejos de aquí"
		var tree := Engine.get_main_loop() as SceneTree
		var game := tree.current_scene if tree else null
		var wg: WorldGenerator = game.get("overworld_generator") as WorldGenerator if game and "overworld_generator" in game else null
		if wg:
			for site: Dictionary in wg.planner.sites:
				if str(site["id"]) == site_id:
					dir = StructurePlanner.direction_text(Vector2(from.x, from.z), site["pos"])
		out = out.substr(0, a) + dir + out.substr(b + 1)
	return out


func _say(text: String) -> void:
	_text.text = text


func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()


func _option(text: String, cb: Callable) -> void:
	var b := UITheme.button(text, cb, 780)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_options.add_child(b)


func _main_options() -> void:
	_clear_options()
	var data := npc.data
	if npc.is_captive():
		_option("Sal de aquí. Rápido.", close)
		return
	_option("¿Qué se cuenta por aquí? (rumores)", _rumor)
	for qid: String in data.get("quests", []):
		var q := QuestDB.get_quest(qid)
		if QuestManager.can_offer(qid):
			_option("¿Tienes algún trabajo para mí?", _offer.bind(qid))
		elif QuestManager.is_active(qid):
			_option("Sobre «%s»..." % q["title"], _status.bind(qid))
	if str(data.get("trade", "")) != "":
		_option("Quiero comerciar.", _trade)
	_option("Adiós.", close)


func _rumor() -> void:
	var r: Array = npc.data.get("rumors", ["No sé nada nuevo."])
	_say(str(r[_rng.randi() % r.size()]))
	_main_options()


func _offer(qid: String) -> void:
	var q := QuestDB.get_quest(qid)
	_say("[b]%s[/b]\n%s" % [q["title"], q["description"]])
	_clear_options()
	_option("Acepto. Me encargaré de ello.", func() -> void:
		QuestManager.accept(qid)
		_say("Bien. Que los antiguos te protejan.")
		_main_options())
	_option("Ahora no.", func() -> void:
		_say("Si cambias de idea, ya sabes dónde encontrarme.")
		_main_options())


func _status(qid: String) -> void:
	_say("Recuerda: %s" % QuestManager.stage_text(qid))
	_main_options()


func _trade() -> void:
	var shop := str(npc.data.get("trade", ""))
	var ui := TradeUI.new()
	ui.shop_id = shop
	ui.merchant_name = str(npc.data.get("name", ""))
	ui.faction = str(npc.data.get("faction", "hojarrubia"))
	add_child(ui)
	_root.visible = false
	ui.closed.connect(func() -> void:
		_root.visible = true
		_main_options())


func close() -> void:
	if npc and is_instance_valid(npc):
		npc.stop_talking()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _root.visible:
		close()
		get_viewport().set_input_as_handled()
