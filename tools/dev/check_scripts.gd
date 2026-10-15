extends Node
## Carga y compila todos los scripts, escenas y recursos del proyecto para
## detectar errores de sintaxis, tipos o rutas rotas (con autoloads activos).
## Uso: godot --headless --path . res://tools/dev/check_scripts.tscn

var _errors := 0
var _checked := 0


func _ready() -> void:
	for dir_path: String in ["res://src", "res://scenes", "res://data", "res://shaders"]:
		_scan(dir_path)
	print("Comprobados: %d recursos, errores: %d" % [_checked, _errors])
	get_tree().quit(1 if _errors > 0 else 0)


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(full)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres") or entry.ends_with(".gdshader"):
			_checked += 1
			var res := ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_REUSE)
			if res == null:
				_errors += 1
				printerr("FALLO al cargar: ", full)
			elif res is GDScript and not (res as GDScript).can_instantiate():
				_errors += 1
				printerr("FALLO al compilar: ", full)
		entry = dir.get_next()
