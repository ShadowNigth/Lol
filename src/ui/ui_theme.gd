class_name UITheme
extends RefCounted
## Tema visual de la interfaz (paneles oscuros con bordes dorados).

const GOLD := Color(0.84, 0.69, 0.38)
const GOLD_DIM := Color(0.55, 0.44, 0.24)
const PARCHMENT := Color(0.93, 0.88, 0.76)
const PANEL_BG := Color(0.07, 0.055, 0.045, 0.9)
const TEXT := Color(0.92, 0.88, 0.8)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 18
	var panel := _box(PANEL_BG, GOLD_DIM, 2, 4)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := _box(Color(0.16, 0.12, 0.09, 0.95), GOLD_DIM, 2, 3)
	btn.set_content_margin_all(8)
	btn.content_margin_left = 18
	btn.content_margin_right = 18
	var btn_hover := _box(Color(0.28, 0.2, 0.12, 0.98), GOLD, 2, 3)
	btn_hover.set_content_margin_all(8)
	btn_hover.content_margin_left = 18
	btn_hover.content_margin_right = 18
	var btn_pressed := _box(Color(0.38, 0.27, 0.14, 1.0), GOLD, 2, 3)
	btn_pressed.set_content_margin_all(8)
	var btn_disabled := _box(Color(0.1, 0.09, 0.08, 0.8), Color(0.3, 0.27, 0.22), 2, 3)
	btn_disabled.set_content_margin_all(8)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_pressed)
	t.set_stylebox("focus", "Button", btn_hover)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.93, 0.75))
	t.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.6))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 4)
	var line := _box(Color(0.12, 0.1, 0.08, 0.95), GOLD_DIM, 1, 2)
	line.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", line)
	t.set_stylebox("focus", "LineEdit", _box(Color(0.15, 0.12, 0.09, 0.95), GOLD, 1, 2))
	t.set_color("font_color", "LineEdit", TEXT)
	var slider := _box(Color(0.2, 0.16, 0.12), GOLD_DIM, 1, 2)
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD_DIM, GOLD_DIM, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, GOLD, 0, 2))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("hover", "OptionButton", btn_hover)
	t.set_stylebox("pressed", "OptionButton", btn_pressed)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 0.93, 0.75))
	t.set_stylebox("hover", "PopupMenu", btn_hover)
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("panel", "ItemList", _box(Color(0.05, 0.04, 0.035, 0.9), GOLD_DIM, 1, 2))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_stylebox("selected", "ItemList", btn_hover)
	t.set_stylebox("selected_focus", "ItemList", btn_hover)
	t.set_stylebox("cursor", "ItemList", btn_hover)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	_theme = t
	return t


static func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	return s


static func title_label(text: String, size: int = 48) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, callback: Callable, min_width: float = 280.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 44)
	b.pressed.connect(func() -> void: Audio.play_2d("ui_click", -6.0))
	b.mouse_entered.connect(func() -> void: Audio.play_2d("ui_hover", -14.0))
	b.pressed.connect(callback)
	return b
