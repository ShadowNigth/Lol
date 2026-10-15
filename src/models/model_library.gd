class_name ModelLibrary
extends RefCounted
## Caché de mallas y materiales de modelos voxel (se generan una vez y se
## comparten entre instancias).

static var _mesh_cache: Dictionary = {}
static var _bounds_cache: Dictionary = {}
static var _model_material: ShaderMaterial
static var _viewmodel_material: ShaderMaterial


static func model_material() -> ShaderMaterial:
	if _model_material == null:
		_model_material = ShaderMaterial.new()
		_model_material.shader = load("res://shaders/voxel_model.gdshader")
	return _model_material


## Material propio (para destellos de impacto por instancia).
static func unique_model_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/voxel_model.gdshader")
	return m


static func viewmodel_material() -> ShaderMaterial:
	if _viewmodel_material == null:
		_viewmodel_material = ShaderMaterial.new()
		_viewmodel_material.shader = load("res://shaders/viewmodel.gdshader")
	return _viewmodel_material


static func prop_mesh(prop: String, extra: Dictionary = {}, part_names: PackedStringArray = PackedStringArray(),
		origin_shift: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var key := "%s|%s|%s|%s" % [prop, str(extra.get("kind", "")), ",".join(part_names), str(origin_shift)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var model := PropModels.by_name(prop, extra)
	if model == null:
		return null
	var mesh := model.build_static_mesh(model_material(), part_names, Transform3D(Basis.IDENTITY, origin_shift))
	_mesh_cache[key] = mesh
	_bounds_cache[key] = model.bounds(part_names)
	return mesh


static func prop_bounds(prop: String, extra: Dictionary = {}, part_names: PackedStringArray = PackedStringArray(),
		origin_shift: Vector3 = Vector3.ZERO) -> AABB:
	var key := "%s|%s|%s|%s" % [prop, str(extra.get("kind", "")), ",".join(part_names), str(origin_shift)]
	if not _bounds_cache.has(key):
		prop_mesh(prop, extra, part_names, origin_shift)
	return _bounds_cache.get(key, AABB())


static func weapon_mesh(weapon_id: String, viewmodel: bool) -> ArrayMesh:
	var key := "weapon|%s|%s" % [weapon_id, viewmodel]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var model := WeaponModels.by_id(weapon_id)
	var mesh := model.build_static_mesh(viewmodel_material() if viewmodel else model_material())
	_mesh_cache[key] = mesh
	return mesh


static func arrow_mesh() -> ArrayMesh:
	var key := "arrow"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh := WeaponModels.arrow().build_static_mesh(model_material())
	_mesh_cache[key] = mesh
	return mesh
