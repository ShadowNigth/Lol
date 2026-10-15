class_name LoadingScreen
extends CanvasLayer
## Pantalla de carga mientras se generan los primeros chunks.

var _bar: ProgressBar
var _label: Label
var _root: Control
var _tips := [
	"Consejo: bloquea justo antes del golpe enemigo para hacer una parada perfecta.",
	"Consejo: agáchate (Ctrl) para acercarte sin ser visto y asestar un ataque furtivo.",
	"Consejo: muévete a los lados mientras atacas para cambiar la dirección del tajo.",
	"Consejo: F5 guarda rápido y F9 carga la partida rápida.",
	"Consejo: el aguante se recupera cuando no corres, bloqueas ni atacas.",
]


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -320
	box.offset_right = 320
	box.offset_top = -80
	box.offset_bottom = 80
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)
	box.add_child(UITheme.title_label("VAELMOOR", 56))
	_label = Label.new()
	_label.text = "Generando el mundo..."
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(640, 14)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.GOLD
	_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_bar)
	var tip := Label.new()
	tip.text = _tips[randi() % _tips.size()]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 15)
	tip.add_theme_color_override("font_color", Color(0.7, 0.66, 0.58))
	box.add_child(tip)


func set_progress(done: int, total: int) -> void:
	_bar.value = clampf(float(done) / float(maxi(total, 1)) * 100.0, 0.0, 100.0)
	_label.text = "Generando el mundo... (%d/%d)" % [mini(done, total), total]


func finish() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
