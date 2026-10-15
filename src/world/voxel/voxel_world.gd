class_name VoxelWorld
extends Node3D
## Gestor del mundo por chunks: genera y malla en hilos de trabajo, integra
## los resultados en el hilo principal con un presupuesto por fotograma y
## descarga los chunks lejanos. Mantiene solo la zona cercana en memoria.

signal initial_area_ready
signal chunk_loaded(coord: Vector2i, data: ChunkData)
signal chunk_unloaded(coord: Vector2i)

const SIZE := ChunkData.SIZE
const MAX_TORCH_LIGHTS := 14
const LIGHT_RANGE := 7.5

var view_radius: int = 6
var generator: WorldGenerator
var block_textures: Texture2DArray
var mat_opaque: ShaderMaterial
var mat_cutout: ShaderMaterial
var mat_water: ShaderMaterial
var flame_mesh: QuadMesh

var _chunks: Dictionary = {}      # Vector2i -> Node3D
var _data: Dictionary = {}        # Vector2i -> ChunkData
var _tasks: Dictionary = {}       # Vector2i -> id de tarea
var _results: Array = []
var _mutex := Mutex.new()
var _center := Vector2i(1 << 20, 1 << 20)
var _focus := Vector3.ZERO
var _initial_ready := false
var _initial_radius := 2
var _max_tasks := 2
var _torches: Array[Dictionary] = []   # {pos: Vector3, light: OmniLight3D, coord}
var _light_timer := 0.0
var _shutting_down := false


func setup(gen: WorldGenerator, textures: Texture2DArray, radius: int) -> void:
	generator = gen
	block_textures = textures
	view_radius = radius
	_max_tasks = clampi(OS.get_processor_count() - 1, 1, 6)
	mat_opaque = ShaderMaterial.new()
	mat_opaque.shader = load("res://shaders/voxel_terrain.gdshader")
	mat_opaque.set_shader_parameter("block_textures", textures)
	mat_cutout = ShaderMaterial.new()
	mat_cutout.shader = load("res://shaders/voxel_cutout.gdshader")
	mat_cutout.set_shader_parameter("block_textures", textures)
	mat_water = ShaderMaterial.new()
	mat_water.shader = load("res://shaders/voxel_water.gdshader")
	mat_water.set_shader_parameter("block_textures", textures)
	mat_water.render_priority = 1
	flame_mesh = QuadMesh.new()
	flame_mesh.size = Vector2(0.32, 0.5)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/flame.gdshader")
	flame_mesh.material = fm


func _exit_tree() -> void:
	_shutting_down = true
	for coord: Vector2i in _tasks:
		var task_id := int(_tasks[coord])
		if task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(task_id)
	_tasks.clear()


## Llamar cada fotograma con la posición del jugador.
func update_focus(world_pos: Vector3) -> void:
	_focus = world_pos
	var c := Vector2i(int(floor(world_pos.x / SIZE)), int(floor(world_pos.z / SIZE)))
	if c != _center:
		_center = c
		_unload_far()


func is_initial_area_ready() -> bool:
	return _initial_ready


func _process(delta: float) -> void:
	if generator == null:
		return
	_collect_results(delta)
	_schedule()
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.4
		_update_lights()


func _schedule() -> void:
	if _tasks.size() >= _max_tasks:
		return
	var best := Vector2i.ZERO
	var best_d := 1 << 30
	var r := view_radius
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d2 := dx * dx + dz * dz
			if d2 > r * r + 1:
				continue
			var c := _center + Vector2i(dx, dz)
			if _chunks.has(c) or _tasks.has(c):
				continue
			if d2 < best_d:
				best_d = d2
				best = c
	if best_d == 1 << 30:
		return
	var id := WorkerThreadPool.add_task(_task_build.bind(best), false, "Chunk %s" % best)
	_tasks[best] = id
	if _tasks.size() < _max_tasks:
		_schedule()


func _task_build(coord: Vector2i) -> void:
	if _shutting_down:
		return
	var data := generator.generate_chunk(coord.x, coord.y)
	var mesh := ChunkMesher.build(data)
	_mutex.lock()
	_results.append([coord, data, mesh])
	_mutex.unlock()


func _collect_results(_delta: float) -> void:
	_mutex.lock()
	var ready := _results.duplicate()
	_results.clear()
	_mutex.unlock()
	var budget := 3 if _initial_ready else 12
	var deferred: Array = []
	for item: Array in ready:
		var coord: Vector2i = item[0]
		if _tasks.has(coord):
			var task_id := int(_tasks[coord])
			if task_id >= 0:
				WorkerThreadPool.wait_for_task_completion(task_id)
			_tasks.erase(coord)
		if budget <= 0:
			deferred.append(item)
			continue
		var dist := (coord - _center).length()
		if dist > view_radius + 1.5:
			continue
		_integrate(coord, item[1], item[2])
		budget -= 1
	if not deferred.is_empty():
		_mutex.lock()
		_results = deferred + _results
		_mutex.unlock()
		# Mantener la entrada en _tasks para no reprogramarlos mientras esperan.
		for item: Array in deferred:
			_tasks[item[0]] = -1
	if not _initial_ready:
		var all_ready := true
		for dz in range(-_initial_radius, _initial_radius + 1):
			for dx in range(-_initial_radius, _initial_radius + 1):
				if not _chunks.has(_center + Vector2i(dx, dz)):
					all_ready = false
		if all_ready:
			_initial_ready = true
			initial_area_ready.emit()


func _integrate(coord: Vector2i, data: ChunkData, mesh: Dictionary) -> void:
	if _tasks.get(coord, 0) == -1:
		_tasks.erase(coord)
	if _chunks.has(coord):
		return
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [coord.x, coord.y]
	node.position = Vector3(coord.x * SIZE, 0, coord.y * SIZE)
	var layers := [["opaque", mat_opaque, true], ["cutout", mat_cutout, true], ["water", mat_water, false]]
	for l: Array in layers:
		var arrays: Variant = mesh[l[0]]
		if arrays == null:
			continue
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays as Array)
		am.surface_set_material(0, l[1])
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if l[2] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	var faces: PackedVector3Array = mesh["collision"]
	if not faces.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		node.add_child(body)
	var lights: PackedVector3Array = mesh["lights"]
	for lp in lights:
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh
		flame.position = lp + Vector3(0, 0.08, 0)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(flame)
		_torches.append({"pos": node.position + lp, "coord": coord, "light": null})
	add_child(node)
	_chunks[coord] = node
	_data[coord] = data
	chunk_loaded.emit(coord, data)


func _unload_far() -> void:
	var limit := view_radius + 2
	var to_remove: Array[Vector2i] = []
	for coord: Vector2i in _chunks:
		var d := coord - _center
		if absi(d.x) > limit or absi(d.y) > limit:
			to_remove.append(coord)
	for coord in to_remove:
		var node: Node3D = _chunks[coord]
		node.queue_free()
		_chunks.erase(coord)
		_data.erase(coord)
		chunk_unloaded.emit(coord)
	if not to_remove.is_empty():
		var kept: Array[Dictionary] = []
		for t in _torches:
			if _chunks.has(t["coord"]):
				kept.append(t)
			elif t["light"] != null and is_instance_valid(t["light"]):
				(t["light"] as Node).queue_free()
		_torches = kept


## Activa luces reales solo en las antorchas más cercanas (límite del renderizador).
func _update_lights() -> void:
	if _torches.is_empty():
		return
	var sorted := _torches.duplicate()
	sorted.sort_custom(_closer_to_focus)
	for i in sorted.size():
		var t: Dictionary = sorted[i]
		var want := i < MAX_TORCH_LIGHTS and (t["pos"] as Vector3).distance_to(_focus) < 60.0
		var light: OmniLight3D = t["light"]
		if want and (light == null or not is_instance_valid(light)):
			light = TorchLight.new()
			light.position = t["pos"] + Vector3(0, 0.2, 0)
			add_child(light)
			t["light"] = light
		elif not want and light != null and is_instance_valid(light):
			light.queue_free()
			t["light"] = null


func _closer_to_focus(a: Dictionary, b: Dictionary) -> bool:
	return (a["pos"] as Vector3).distance_squared_to(_focus) < (b["pos"] as Vector3).distance_squared_to(_focus)


# ---------------------------------------------------------------------------
# Consultas
# ---------------------------------------------------------------------------

func get_block(wx: int, wy: int, wz: int) -> int:
	var c := Vector2i(int(floor(float(wx) / SIZE)), int(floor(float(wz) / SIZE)))
	var data: ChunkData = _data.get(c, null)
	if data == null:
		return -1
	return data.get_world(wx, wy, wz)


func block_at(p: Vector3) -> int:
	return get_block(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))


func is_chunk_loaded_at(p: Vector3) -> bool:
	return _chunks.has(Vector2i(int(floor(p.x / SIZE)), int(floor(p.z / SIZE))))


## Altura de la superficie caminable (bloque sólido más alto + 1).
func surface_height(x: float, z: float) -> float:
	var wx := int(floor(x))
	var wz := int(floor(z))
	var c := Vector2i(int(floor(float(wx) / SIZE)), int(floor(float(wz) / SIZE)))
	var data: ChunkData = _data.get(c, null)
	if data != null:
		var sy := data.surface_y(wx - c.x * SIZE, wz - c.y * SIZE)
		if sy >= 0:
			return sy + 1.0
	return generator.height_at(wx, wz) + 1.0


func loaded_chunk_count() -> int:
	return _chunks.size()


func pending_task_count() -> int:
	return _tasks.size()
