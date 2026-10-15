extends SceneTree
func _init() -> void:
	var img := Image.new()
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var err := img.load_svg_from_string(svg, 1.0)
	print("svg ", err, " ", img.get_size())
	img.resize(128, 128, Image.INTERPOLATE_NEAREST)
	img.save_png("res://packaging/vaelmoor.png")
	quit()
