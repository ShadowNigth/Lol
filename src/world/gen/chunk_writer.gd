class_name ChunkWriter
extends RefCounted
## Escritor de bloques con recorte al área (con borde) de un chunk y con un
## marco local girable para construir estructuras orientadas.

var data: ChunkData
var _x0: int
var _x1: int
var _z0: int
var _z1: int
# Marco local
var ox: int = 0
var oy: int = 0
var oz: int = 0
var rot: int = 0
var w: int = 1
var d: int = 1
var structure_id: String = ""


func _init(chunk: ChunkData) -> void:
	data = chunk
	_x0 = chunk.origin_x() - 1
	_x1 = chunk.origin_x() + ChunkData.SIZE
	_z0 = chunk.origin_z() - 1
	_z1 = chunk.origin_z() + ChunkData.SIZE


## Define el marco local: origen (esquina mínima en el mundo de la huella ya
## girada), tamaño local (w a lo largo de x local, d a lo largo de z local) y
## giro en cuartos de vuelta en sentido horario visto desde arriba.
func frame(origin: Vector3i, size_w: int, size_d: int, rotation: int, id: String = "") -> void:
	ox = origin.x
	oy = origin.y
	oz = origin.z
	w = size_w
	d = size_d
	rot = posmod(rotation, 4)
	structure_id = id


## Tamaño de la huella en el mundo para un giro dado.
static func footprint(size_w: int, size_d: int, rotation: int) -> Vector2i:
	return Vector2i(size_w, size_d) if posmod(rotation, 2) == 0 else Vector2i(size_d, size_w)


func to_world_xz(lx: int, lz: int) -> Vector2i:
	match rot:
		0:
			return Vector2i(ox + lx, oz + lz)
		1:
			return Vector2i(ox + (d - 1 - lz), oz + lx)
		2:
			return Vector2i(ox + (w - 1 - lx), oz + (d - 1 - lz))
		_:
			return Vector2i(ox + lz, oz + (w - 1 - lx))


func to_world_pos(lpos: Vector3) -> Vector3:
	var x: float
	var z: float
	match rot:
		0:
			x = ox + lpos.x
			z = oz + lpos.z
		1:
			x = ox + d - lpos.z
			z = oz + lpos.x
		2:
			x = ox + w - lpos.x
			z = oz + d - lpos.z
		_:
			x = ox + lpos.z
			z = oz + w - lpos.x
	return Vector3(x, oy + lpos.y, z)


func in_bounds_world(wx: int, wz: int) -> bool:
	return wx >= _x0 and wx <= _x1 and wz >= _z0 and wz <= _z1


func put_world(wx: int, wy: int, wz: int, id: int) -> void:
	if wx < _x0 or wx > _x1 or wz < _z0 or wz > _z1:
		return
	data.set_world(wx, wy, wz, id)


func get_world(wx: int, wy: int, wz: int) -> int:
	return data.get_world(wx, wy, wz)


## Escribe en coordenadas locales (y relativa a oy).
func put(lx: int, ly: int, lz: int, id: int) -> void:
	var p := to_world_xz(lx, lz)
	if p.x < _x0 or p.x > _x1 or p.y < _z0 or p.y > _z1:
		return
	data.set_world(p.x, oy + ly, p.y, BlockTypes.rotate_block(id, rot))


func get_local(lx: int, ly: int, lz: int) -> int:
	var p := to_world_xz(lx, lz)
	return data.get_world(p.x, oy + ly, p.y)


## Caja rellena (inclusiva) en coordenadas locales.
func fill(lx0: int, ly0: int, lz0: int, lx1: int, ly1: int, lz1: int, id: int) -> void:
	for ly in range(mini(ly0, ly1), maxi(ly0, ly1) + 1):
		for lz in range(mini(lz0, lz1), maxi(lz0, lz1) + 1):
			for lx in range(mini(lx0, lx1), maxi(lx0, lx1) + 1):
				put(lx, ly, lz, id)


## Solo el perímetro de un rectángulo a una altura.
func ring(lx0: int, lz0: int, lx1: int, lz1: int, ly: int, id: int) -> void:
	for lx in range(lx0, lx1 + 1):
		put(lx, ly, lz0, id)
		put(lx, ly, lz1, id)
	for lz in range(lz0 + 1, lz1):
		put(lx0, ly, lz, id)
		put(lx1, ly, lz, id)


## Rellena hacia abajo desde ly hasta encontrar suelo sólido (cimientos).
func foundation(lx: int, ly: int, lz: int, id: int, max_depth: int = 12) -> void:
	var p := to_world_xz(lx, lz)
	if not in_bounds_world(p.x, p.y):
		return
	for k in max_depth:
		var wy := oy + ly - k
		if wy < 1:
			return
		var cur := data.get_world(p.x, wy, p.y)
		if cur > 0 and BlockTypes.solid[cur] == 1 and BlockTypes.opaque[cur] == 1 and k > 0:
			return
		data.set_world(p.x, wy, p.y, id)


## Vacía (aire) una caja local.
func clear(lx0: int, ly0: int, lz0: int, lx1: int, ly1: int, lz1: int) -> void:
	fill(lx0, ly0, lz0, lx1, ly1, lz1, BlockTypes.AIR)


## Registra una entidad (puerta, cofre, enemigo...) si cae en la zona interior
## del chunk. `yaw_deg` es local (0 = mirando a -Z local).
func entity(type: String, lpos: Vector3, yaw_deg: float = 0.0, extra: Dictionary = {}) -> void:
	var wp := to_world_pos(lpos)
	if not data.contains_world_core(int(floor(wp.x)), int(floor(wp.z))):
		return
	var e := extra.duplicate()
	e["type"] = type
	e["pos"] = wp
	e["yaw"] = yaw_deg - rot * 90.0
	e["id"] = "%s/%s@%d,%d,%d" % [structure_id, type, int(floor(wp.x)), int(floor(wp.y)), int(floor(wp.z))]
	if extra.has("uid"):
		e["id"] = "%s/%s" % [structure_id, str(extra["uid"])]
	data.entities.append(e)
