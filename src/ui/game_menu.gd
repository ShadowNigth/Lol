class_name GameMenu
extends CanvasLayer
## Menú de personaje con pestañas: Inventario (usar, equipar, soltar, peso),
## Personaje (atributos, habilidades, nivel), Diario (misiones y reputación)
## y Mapa (mapa generado del entorno con marcadores).

var player: Player
var game: Node
var _root: Control
var _tabs: TabContainer
var _inv_list: ItemList
var _inv_ids: Array[String] = []
var _inv_info: RichTextLabel
var _weap_list: ItemList
var _equip_list: ItemList
var _equip_slots: Array[String] = []
var _char_text: RichTextLabel
var _journal_text: RichTextLabel
var _map_rect: TextureRect
var _map_label: Label


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(980, 600)
	center.add_child(_tabs)
	_build_inventory()
	_build_character()
	_build_journal()
	_build_map()
	_tabs.tab_changed.connect(func(_t: int) -> void: refresh())


func _build_inventory() -> void:
	var h := HBoxContainer.new()
	h.name = "Inventario"
	h.add_theme_constant_override("separation", 12)
	_tabs.add_child(h)
	var left := VBoxContainer.new()
	h.add_child(left)
	var l := Label.new()
	l.text = "Objetos"
	l.add_theme_color_override("font_color", UITheme.GOLD)
	left.add_child(l)
	_inv_list = ItemList.new()
	_inv_list.custom_minimum_size = Vector2(420, 300)
	_inv_list.item_selected.connect(_on_item_selected)
	_inv_list.item_activated.connect(func(_i: int) -> void: _use_selected())
	left.add_child(_inv_list)
	var lw := Label.new()
	lw.text = "Armas (1-5 para equipar en juego)"
	lw.add_theme_color_override("font_color", UITheme.GOLD)
	left.add_child(lw)
	_weap_list = ItemList.new()
	_weap_list.custom_minimum_size = Vector2(420, 150)
	_weap_list.item_activated.connect(func(i: int) -> void:
		player._equip_index(i)
		refresh())
	left.add_child(_weap_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_inv_info = RichTextLabel.new()
	_inv_info.bbcode_enabled = true
	_inv_info.custom_minimum_size = Vector2(480, 150)
	_inv_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_inv_info)
	var le := Label.new()
	le.text = "Equipo puesto (doble clic para quitar)"
	le.add_theme_color_override("font_color", UITheme.GOLD)
	right.add_child(le)
	_equip_list = ItemList.new()
	_equip_list.custom_minimum_size = Vector2(480, 168)   # las 6 ranuras sin desplazamiento
	_equip_list.item_activated.connect(func(_i: int) -> void: _unequip_selected())
	_equip_list.item_selected.connect(_on_equip_selected)
	right.add_child(_equip_list)
	var buttons := HBoxContainer.new()
	buttons.add_child(UITheme.button("Usar / Equipar", _use_selected, 150))
	buttons.add_child(UITheme.button("Quitar", _unequip_selected, 100))
	buttons.add_child(UITheme.button("Equipar arma", _equip_selected_weapon, 150))
	buttons.add_child(UITheme.button("Soltar", _drop_selected, 100))
	right.add_child(buttons)


func _build_character() -> void:
	_char_text = RichTextLabel.new()
	_char_text.name = "Personaje"
	_char_text.bbcode_enabled = true
	_tabs.add_child(_char_text)


func _build_journal() -> void:
	_journal_text = RichTextLabel.new()
	_journal_text.name = "Diario"
	_journal_text.bbcode_enabled = true
	_tabs.add_child(_journal_text)


func _build_map() -> void:
	var v := VBoxContainer.new()
	v.name = "Mapa"
	_tabs.add_child(v)
	_map_label = Label.new()
	_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_label.custom_minimum_size = Vector2(900, 0)
	v.add_child(_map_label)
	_map_rect = TextureRect.new()
	_map_rect.custom_minimum_size = Vector2(512, 512)
	_map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_map_rect)


func open(tab: int) -> void:
	if player == null or player.is_dead:
		return
	visible = true
	_tabs.current_tab = tab
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.play_2d("ui_open", -8.0)
	refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory") or event.is_action_pressed("character") \
			or event.is_action_pressed("journal") or event.is_action_pressed("map"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if player == null:
		return
	match _tabs.current_tab:
		0:
			_refresh_inventory()
		1:
			_refresh_character()
		2:
			_refresh_journal()
		3:
			_refresh_map()


func carry_capacity() -> float:
	return 60.0 + player.stats.attr("strength") * 1.2


func _refresh_inventory() -> void:
	_inv_list.clear()
	_inv_ids.clear()
	var entries := GameState.inventory.duplicate()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(ItemDB.get_def(str(a["id"])).get("category", "")) < str(ItemDB.get_def(str(b["id"])).get("category", "")))
	for e: Dictionary in entries:
		var def := ItemDB.get_def(str(e["id"]))
		_inv_list.add_item("%s  x%d" % [def.get("name", e["id"]), int(e["count"])])
		_inv_ids.append(str(e["id"]))
	_weap_list.clear()
	for i in player.weapons.size():
		var w := player.weapons[i]
		_weap_list.add_item("%d. %s%s  (daño %d-%d, peso %.1f)" % [i + 1, w.display_name, "  [equipada]" if i == player.weapon_index else "", int(w.damage_min), int(w.damage_max), w.weight])
	_equip_list.clear()
	_equip_slots.clear()
	for slot: String in Equipment.SLOTS:
		var id := str(GameState.equipment.get(slot, ""))
		_equip_list.add_item("%s: %s" % [Equipment.SLOT_NAMES[slot], ItemDB.display_name(id) if id != "" else "—"])
		_equip_slots.append(slot)
	var weight := GameState.carry_weight()
	_inv_info.text = "[b]Oro:[/b] %d\n[b]Peso:[/b] %.1f / %.0f\n%s\n\nSelecciona un objeto para ver su descripción." % [player.gold,
			weight, carry_capacity(), _protection_text()]


func _protection_text() -> String:
	var s := player.stats
	var t := "[b]Armadura:[/b] %d (reduce el daño físico un %d%%)" % [int(s.armor_rating), int(100.0 - 10000.0 / (100.0 + s.armor_rating))]
	var parts: Array[String] = []
	for k: String in Equipment.RESIST_NAMES:
		var v := float(s.resistances.get(k, 0.0))
		if absf(v) > 0.001:
			parts.append("%s %+d%%" % [Equipment.RESIST_NAMES[k], int(v * 100.0)])
	if not parts.is_empty():
		t += "\n[b]Resistencias:[/b] " + ", ".join(parts)
	return t


func _on_equip_selected(i: int) -> void:
	var id := str(GameState.equipment.get(_equip_slots[i], ""))
	if id == "":
		_inv_info.text = "Ranura vacía: %s.\n\n%s" % [Equipment.SLOT_NAMES[_equip_slots[i]], _protection_text()]
		return
	var def := ItemDB.get_def(id)
	_inv_info.text = "[b]%s[/b] [i](puesto)[/i]\n\n%s\n\n%s\n\nValor: %d oro    Peso: %.2f" % [def.get("name", id),
			def.get("description", ""), Equipment.describe(id, player.stats), int(def.get("value", 0)), float(def.get("weight", 0.0))]


func _unequip_selected() -> void:
	var sel := _equip_list.get_selected_items()
	if sel.is_empty():
		return
	GameState.unequip_slot(player, _equip_slots[sel[0]])
	refresh()


func _on_item_selected(i: int) -> void:
	var id := _inv_ids[i]
	var def := ItemDB.get_def(id)
	var rarity := {"common": "Común", "uncommon": "Poco común", "rare": "Raro", "epic": "Épico"}
	var cats := {"potion": "Poción", "food": "Comida", "ingredient": "Ingrediente", "key": "Llave", "misc": "Varios",
			"tool": "Herramienta", "book": "Libro", "weapon": "Arma", "quest": "Objeto de misión",
			"armor": "Armadura", "clothing": "Ropa", "shield": "Escudo", "ammo": "Munición"}
	var text := "[b]%s[/b]\n[i]%s · %s[/i]\n\n%s\n\nValor: %d oro    Peso: %.2f" % [def.get("name", id),
			cats.get(def.get("category", ""), "Varios"), rarity.get(def.get("rarity", "common"), "Común"),
			def.get("description", ""), int(def.get("value", 0)), float(def.get("weight", 0.0))]
	if Equipment.is_equippable(id):
		text += "\n\n" + Equipment.describe(id, player.stats)
		var worn := str(GameState.equipment.get(Equipment.slot_of(id), ""))
		if worn != "":
			text += "\n[i]Sustituiría a: %s[/i]" % ItemDB.display_name(worn)
	if def.has("text"):
		text += "\n\n[i]«%s»[/i]" % def["text"]
	_inv_info.text = text


func _selected_item() -> String:
	var sel := _inv_list.get_selected_items()
	if sel.is_empty():
		return ""
	return _inv_ids[sel[0]]


func _use_selected() -> void:
	var id := _selected_item()
	if id == "":
		return
	var def := ItemDB.get_def(id)
	if Equipment.is_equippable(id):
		GameState.equip_item(player, id)
	elif def.has("effect"):
		GameState.use_item(player, id)
	elif def.has("text"):
		_on_item_selected(_inv_list.get_selected_items()[0])
		return
	else:
		Events.notify.emit("No puedes usar eso.", "info")
	refresh()


func _equip_selected_weapon() -> void:
	var sel := _weap_list.get_selected_items()
	if sel.is_empty():
		return
	player._equip_index(sel[0])
	refresh()


func _drop_selected() -> void:
	var id := _selected_item()
	if id == "":
		return
	var def := ItemDB.get_def(id)
	if str(def.get("category", "")) in ["quest", "key"]:
		Events.notify.emit("No conviene deshacerse de eso.", "warning")
		return
	if GameState.remove_item(id, 1) and game and game.has_method("drop_item"):
		game.call("drop_item", id)
	refresh()


func _refresh_character() -> void:
	var s := player.stats
	var t := "[b]%s[/b] — %s, nivel %d (progreso %d/10)\n\n" % [GameState.character_name,
			GameState.class_template(GameState.character_class)["name"], s.level, s.level_progress]
	t += "Salud %d/%d    Aguante %d/%d    Magia %d/%d    Armadura %d\n\n" % [ceili(s.health), ceili(s.max_health),
			ceili(s.stamina), ceili(s.max_stamina), ceili(s.mana), ceili(s.max_mana), int(s.armor_rating)]
	t += "[color=#d6b061][b]Atributos[/b][/color]\n"
	for a: String in Stats.ATTRIBUTES:
		t += "  %s: %d\n" % [Stats.ATTRIBUTE_NAMES[a], s.attr(a)]
	t += "\n[color=#d6b061][b]Habilidades[/b][/color] (mejoran al usarlas)\n"
	var cols: Array[String] = []
	for sk: String in Stats.SKILLS:
		var need := 4.0 + s.skill(sk) * 0.55
		cols.append("  %s: %d (%d%%)" % [Stats.SKILL_NAMES[sk], s.skill(sk), int(float(s.skill_xp[sk]) / need * 100.0)])
	for i in range(0, cols.size(), 2):
		t += cols[i] + ("        " + cols[i + 1] if i + 1 < cols.size() else "") + "\n"
	t += "\nDaño cuerpo a cuerpo ×%.2f · Crítico %d%% · Velocidad ×%.2f" % [s.melee_multiplier(player.weapon.skill if player.weapon else "blade"),
			int(s.crit_chance() * 100.0), s.move_speed_multiplier()]
	_char_text.text = t


func _refresh_journal() -> void:
	var t := "[color=#d6b061][b]Misiones activas[/b][/color]\n"
	var any := false
	for qid: String in GameState.quests:
		if QuestManager.is_active(qid):
			any = true
			var q := QuestDB.get_quest(qid)
			t += "\n[b]%s[/b]\n%s\n→ [i]%s[/i]\n" % [q["title"], q["description"], QuestManager.stage_text(qid)]
	if not any:
		t += "\nNinguna. Habla con la gente de Hojarrubia para encontrar trabajo.\n"
	t += "\n[color=#d6b061][b]Completadas[/b][/color]\n"
	for qid2: String in GameState.quests:
		if QuestManager.is_done(qid2):
			t += "  ✓ %s\n" % QuestDB.get_quest(qid2)["title"]
	t += "\n[color=#d6b061][b]Reputación[/b][/color]\n"
	for f: String in QuestDB.FACTIONS:
		var r := GameState.reputation(f)
		var tier := "Hostil" if r <= -20 else ("Neutral" if r < 20 else ("Amistoso" if r < 50 else "Venerado"))
		t += "  %s: %d (%s)\n" % [QuestDB.FACTIONS[f], r, tier]
	t += "\nDía %d, %s" % [GameState.day, "%02d:%02d" % [int(GameState.time_of_day), int(fmod(GameState.time_of_day, 1.0) * 60.0)]]
	_journal_text.text = t


func _refresh_map() -> void:
	var gen := (game.get("generator") as WorldSource) if game else null
	if gen == null:
		return
	var size := 128
	var scale := 4 if not gen.is_interior() else 1
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var center := player.global_position
	var ox := int(center.x) - size * scale / 2
	var oz := int(center.z) - size * scale / 2
	if gen is DungeonGenerator:
		var dg := gen as DungeonGenerator
		img.fill(Color(0.05, 0.05, 0.06))
		for t: Vector2i in dg.floor_tiles:
			var px := t.x - ox
			var pz := t.y - oz
			if px >= 0 and pz >= 0 and px < size and pz < size:
				img.set_pixel(px, pz, Color(0.55, 0.52, 0.48))
		_map_label.text = "Mapa local: %s" % dg.display_name
	else:
		var wg := gen as WorldGenerator
		for z in size:
			for x in size:
				var wx := ox + x * scale
				var wz := oz + z * scale
				var h := wg.height_at(wx, wz)
				var col := _map_color(wg, wx, wz, h)
				img.set_pixel(x, z, col)
		# Lugares ocultos (campamentos) que aún no se han descubierto
		var hidden := {}
		for site0: Dictionary in wg.planner.sites:
			if not StructurePlanner.site_known(site0):
				hidden[str(site0["id"])] = true
		for s: Dictionary in wg.planner.structures:
			if hidden.has(str(s.get("site", ""))):
				continue
			var r: Rect2i = s["footprint"]
			for zz in range(r.position.y, r.end.y, scale):
				for xx in range(r.position.x, r.end.x, scale):
					var px2 := (xx - ox) / scale
					var pz2 := (zz - oz) / scale
					if px2 >= 0 and pz2 >= 0 and px2 < size and pz2 < size:
						img.set_pixel(px2, pz2, Color(0.55, 0.25, 0.2))
		# Lugares de la región: marcadores y leyenda con dirección y distancia
		var me := Vector2(center.x, center.z)
		var legend: Array[String] = []
		for site: Dictionary in wg.planner.sites:
			if hidden.has(str(site["id"])):
				continue
			var sp: Vector2 = site["pos"]
			var mcol := Color(0.95, 0.85, 0.4)
			match str(site["kind"]):
				"inn":
					mcol = Color(1.0, 0.55, 0.15)
				"dungeon":
					mcol = Color(0.9, 0.15, 0.15)
				"camp":
					mcol = Color(0.7, 0.3, 0.9)
			var mx := int((sp.x - ox) / scale)
			var mz := int((sp.y - oz) / scale)
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					if absi(dx) + absi(dz) <= 3 and mx + dx >= 0 and mz + dz >= 0 and mx + dx < size and mz + dz < size:
						img.set_pixel(mx + dx, mz + dz, mcol if absi(dx) + absi(dz) < 3 else Color(0.1, 0.08, 0.06))
			legend.append("%s: %s" % [site["name"], StructurePlanner.direction_text(me, sp)])
		_map_label.text = "Mapa de la región (cada píxel = %d m; tú en el centro, norte arriba). Amarillo: aldeas · Naranja: posadas · Rojo: mazmorras · Morado: campamentos\n%s" % [scale, "  ·  ".join(legend)]
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			img.set_pixel(size / 2 + dx, size / 2 + dy, Color(1, 1, 1))
	var fwd := player.look_direction()
	for k in range(2, 6):
		var px3 := size / 2 + int(round(fwd.x * k))
		var pz3 := size / 2 + int(round(fwd.z * k))
		if px3 >= 0 and pz3 >= 0 and px3 < size and pz3 < size:
			img.set_pixel(px3, pz3, Color(1, 0.9, 0.3))
	img.resize(512, 512, Image.INTERPOLATE_NEAREST)
	_map_rect.texture = ImageTexture.create_from_image(img)


func _map_color(wg: WorldGenerator, x: int, z: int, h: int) -> Color:
	if h < WorldGenerator.SEA_LEVEL:
		return Color(0.15, 0.3, 0.55).lerp(Color(0.25, 0.45, 0.7), clampf(float(h - 15) / 15.0, 0.0, 1.0))
	if wg.planner.surface_override(x, z) > 0:
		return Color(0.6, 0.48, 0.3)
	var shade := clampf(0.75 + (h - 36) * 0.012, 0.5, 1.2)
	match wg.biome_at(x, z, h):
		WorldGenerator.Biome.DESERT, WorldGenerator.Biome.BEACH:
			return Color(0.85, 0.78, 0.5) * shade
		WorldGenerator.Biome.SNOW:
			return Color(0.9, 0.92, 0.95) * shade
		WorldGenerator.Biome.SWAMP:
			return Color(0.3, 0.38, 0.2) * shade
		WorldGenerator.Biome.ROCKY:
			return Color(0.5, 0.48, 0.45) * shade
		WorldGenerator.Biome.FOREST, WorldGenerator.Biome.BIRCH_FOREST, WorldGenerator.Biome.TAIGA:
			return Color(0.18, 0.4, 0.15) * shade
	return Color(0.35, 0.55, 0.25) * shade
