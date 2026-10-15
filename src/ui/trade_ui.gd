class_name TradeUI
extends Control
## Comercio: comprar al mercader y venderle objetos. Los precios dependen de
## la habilidad de Comercio, la Personalidad y la reputación con su facción.

signal closed

var shop_id := ""
var merchant_name := ""
var faction := "hojarrubia"
var _shop: Dictionary
var _stock_list: ItemList
var _inv_list: ItemList
var _info: Label
var _stock_ids: Array[String] = []
var _inv_ids: Array[String] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	_shop = GameState.get_shop(shop_id)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UITheme.title_label("Comercio con %s" % merchant_name, 28))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var left := VBoxContainer.new()
	var l1 := Label.new()
	l1.text = "Mercancía (comprar)"
	left.add_child(l1)
	_stock_list = ItemList.new()
	_stock_list.custom_minimum_size = Vector2(380, 320)
	_stock_list.item_activated.connect(func(_i: int) -> void: _buy())
	left.add_child(_stock_list)
	left.add_child(UITheme.button("Comprar", _buy, 380))
	h.add_child(left)
	var right := VBoxContainer.new()
	var l2 := Label.new()
	l2.text = "Tu inventario (vender)"
	right.add_child(l2)
	_inv_list = ItemList.new()
	_inv_list.custom_minimum_size = Vector2(380, 320)
	_inv_list.item_activated.connect(func(_i: int) -> void: _sell())
	right.add_child(_inv_list)
	right.add_child(UITheme.button("Vender", _sell, 380))
	h.add_child(right)
	_info = Label.new()
	v.add_child(_info)
	v.add_child(UITheme.button("Terminar", func() -> void:
		closed.emit()
		queue_free(), 200))
	_refresh()


func _price_factor_buy() -> float:
	var st := (GameState.player as Player).stats
	var f := 1.35 - st.skill("mercantile") / 250.0 - (st.attr("personality") - 40) / 300.0 - GameState.reputation(faction) / 200.0
	return clampf(f, 0.9, 1.6)


func _price_factor_sell() -> float:
	var st := (GameState.player as Player).stats
	var f := 0.4 + st.skill("mercantile") / 300.0 + (st.attr("personality") - 40) / 400.0 + GameState.reputation(faction) / 300.0
	return clampf(f, 0.25, 0.85)


func _refresh() -> void:
	_stock_list.clear()
	_inv_list.clear()
	_stock_ids.clear()
	_inv_ids.clear()
	var stock: Dictionary = _shop["stock"]
	for id: String in stock:
		if int(stock[id]) <= 0:
			continue
		var def := ItemDB.get_def(id)
		var price := maxi(1, int(round(float(def.get("value", 1)) * _price_factor_buy())))
		_stock_list.add_item("%s  x%d  —  %d oro" % [def.get("name", id), int(stock[id]), price])
		_stock_list.set_item_tooltip(_stock_list.item_count - 1, _tooltip(id))
		_stock_ids.append(id)
	for e in GameState.inventory:
		var id2 := str(e["id"])
		var def2 := ItemDB.get_def(id2)
		if str(def2.get("category", "")) in ["quest", "key"]:
			continue
		var price2 := maxi(1, int(round(float(def2.get("value", 1)) * _price_factor_sell())))
		_inv_list.add_item("%s  x%d  —  %d oro" % [def2.get("name", id2), int(e["count"]), price2])
		_inv_list.set_item_tooltip(_inv_list.item_count - 1, _tooltip(id2))
		_inv_ids.append(id2)
	var p := GameState.player as Player
	_info.text = "Tu oro: %d    Oro del mercader: %d" % [p.gold, int(_shop["gold"])]


## Descripción y, si es equipable, ranura, armadura y resistencias.
func _tooltip(id: String) -> String:
	var def := ItemDB.get_def(id)
	var t := "%s\n%s\nPeso: %.2f" % [def.get("name", id), def.get("description", ""), float(def.get("weight", 0.0))]
	if Equipment.is_equippable(id):
		t += "\n" + Equipment.describe(id, (GameState.player as Player).stats)
	return t


func _buy() -> void:
	var sel := _stock_list.get_selected_items()
	if sel.is_empty():
		return
	var id := _stock_ids[sel[0]]
	var def := ItemDB.get_def(id)
	var price := maxi(1, int(round(float(def.get("value", 1)) * _price_factor_buy())))
	var p := GameState.player as Player
	if p.gold < price:
		_info.text = "No tienes suficiente oro."
		return
	p.gold -= price
	_shop["gold"] = int(_shop["gold"]) + price
	_shop["stock"][id] = int(_shop["stock"][id]) - 1
	GameState.give_item(p, {"id": id, "count": 1})
	p.stats.train("mercantile", 0.5)
	Audio.play_2d("gold", -6.0)
	_refresh()


func _sell() -> void:
	var sel := _inv_list.get_selected_items()
	if sel.is_empty():
		return
	var id := _inv_ids[sel[0]]
	var def := ItemDB.get_def(id)
	var price := maxi(1, int(round(float(def.get("value", 1)) * _price_factor_sell())))
	if int(_shop["gold"]) < price:
		_info.text = "El mercader no tiene suficiente oro."
		return
	if not GameState.remove_item(id, 1):
		return
	var p := GameState.player as Player
	p.gold += price
	_shop["gold"] = int(_shop["gold"]) - price
	var stock: Dictionary = _shop["stock"]
	stock[id] = int(stock.get(id, 0)) + 1
	p.stats.train("mercantile", 0.5)
	Audio.play_2d("gold", -6.0)
	_refresh()
