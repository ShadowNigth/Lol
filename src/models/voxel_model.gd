class_name VoxelModel
extends RefCounted
## Modelo de micro-vóxeles compuesto por piezas rígidas asociadas a huesos.
##
## Se "pinta" con primitivas (cajas, elipsoides, cilindros) y se convierte en
## una ArrayMesh con oclusión ambiental por vértice, variación de color por
## vóxel y propiedades de material (metal, rugosidad, emisión) en UV2/COLOR.a.
## Puede generar una malla con piel (skinning) para un Skeleton3D o una malla
## estática.

class Mat:
	var color: Color
	var metal: float
	var rough: float
	var emit: float
	var jitter: float

	func _init(c: Color, m: float, r: float, e: float, j: float) -> void:
		color = c
		metal = m
		rough = r
		emit = e
		jitter = j


class Part:
	var name: String
	var bone: String
	var origin: Vector3          # posición en el modelo del vóxel (0,0,0)
	var voxels: Dictionary = {}  # Vector3i -> índice de material

	func _init(part_name: String, bone_name: String, part_origin: Vector3) -> void:
		name = part_name
		bone = bone_name
		origin = part_origin

	func put(p: Vector3i, mat: int) -> void:
		voxels[p] = mat

	func erase(p: Vector3i) -> void:
		voxels.erase(p)

	func box(a: Vector3i, b: Vector3i, mat: int) -> void:
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					voxels[Vector3i(x, y, z)] = mat

	func erase_box(a: Vector3i, b: Vector3i) -> void:
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					voxels.erase(Vector3i(x, y, z))

	## Pinta solo los vóxeles ya existentes dentro de la caja.
	func recolor_box(a: Vector3i, b: Vector3i, mat: int) -> void:
		for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
					var p := Vector3i(x, y, z)
					if voxels.has(p):
						voxels[p] = mat

	func ellipsoid(center: Vector3, radii: Vector3, mat: int) -> void:
		var a := Vector3i(floor(center - radii))
		var b := Vector3i(ceil(center + radii))
		for z in range(a.z, b.z + 1):
			for y in range(a.y, b.y + 1):
				for x in range(a.x, b.x + 1):
					var d := (Vector3(x, y, z) - center) / radii
					if d.length_squared() <= 1.0:
						voxels[Vector3i(x, y, z)] = mat

	## Cilindro vertical (eje Y).
	func cylinder_y(cx: float, cz: float, r: float, y0: int, y1: int, mat: int) -> void:
		for y in range(y0, y1 + 1):
			for z in range(int(floor(cz - r)), int(ceil(cz + r)) + 1):
				for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
					if Vector2(x - cx, z - cz).length() <= r:
						voxels[Vector3i(x, y, z)] = mat

	## Cilindro a lo largo del eje Z.
	func cylinder_z(cx: float, cy: float, r: float, z0: int, z1: int, mat: int) -> void:
		for z in range(z0, z1 + 1):
			for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
				for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
					if Vector2(x - cx, y - cy).length() <= r:
						voxels[Vector3i(x, y, z)] = mat

	## Cilindro a lo largo del eje X.
	func cylinder_x(cy: float, cz: float, r: float, x0: int, x1: int, mat: int) -> void:
		for x in range(x0, x1 + 1):
			for z in range(int(floor(cz - r)), int(ceil(cz + r)) + 1):
				for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
					if Vector2(y - cy, z - cz).length() <= r:
						voxels[Vector3i(x, y, z)] = mat

	## Línea de vóxeles (Bresenham 3D aproximado) con grosor 1.
	func line(a: Vector3, b: Vector3, mat: int) -> void:
		var steps := int(ceil(a.distance_to(b) * 1.5)) + 1
		for i in steps + 1:
			var p := a.lerp(b, float(i) / float(steps))
			voxels[Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))] = mat

	func mirror_x(center_x: float) -> void:
		var copy := voxels.duplicate()
		for p: Vector3i in copy:
			var mx := int(round(2.0 * center_x - p.x))
			voxels[Vector3i(mx, p.y, p.z)] = copy[p]


var voxel_size: float = 1.0 / 16.0
var mats: Array[Mat] = []
var parts: Array[Part] = []
var seed_value: int = 1


func _init(size: float = 1.0 / 16.0, model_seed: int = 1) -> void:
	voxel_size = size
	seed_value = model_seed


## Registra un material y devuelve su índice.
func mat(c: Color, metal: float = 0.0, rough: float = 0.85, emit: float = 0.0, jitter: float = 0.06) -> int:
	mats.append(Mat.new(c, metal, rough, emit, jitter))
	return mats.size() - 1


func part(part_name: String, bone: String, origin: Vector3) -> Part:
	var p := Part.new(part_name, bone, origin)
	parts.append(p)
	return p


func get_part(part_name: String) -> Part:
	for p in parts:
		if p.name == part_name:
			return p
	return null


# ---------------------------------------------------------------------------
# Mallado
# ---------------------------------------------------------------------------

const _NORMALS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
# Esquinas en sentido horario vistas desde fuera (frontal en Godot).
const _CORNERS := [
	[Vector3i(1, 1, 1), Vector3i(1, 1, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 0, 1), Vector3i(0, 0, 0)],
	[Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)],
	[Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 0, 0)],
	[Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(1, 0, 1), Vector3i(0, 0, 1)],
	[Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0)],
]
const _AO := [0.5, 0.68, 0.84, 1.0]


static func _hash(p: Vector3i, s: int) -> float:
	var h := (p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791) ^ (s * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


func _emit_part(p: Part, bone_index: int, verts: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, uv2: PackedVector2Array, bones: PackedInt32Array, weights: PackedFloat32Array,
		indices: PackedInt32Array, skinned: bool, transform: Transform3D) -> Array:
	var vs := voxel_size
	for vp: Vector3i in p.voxels:
		var m: Mat = mats[int(p.voxels[vp])]
		var j := (_hash(vp, seed_value + p.name.hash()) - 0.5) * 2.0 * m.jitter
		var base_col := Color(clampf(m.color.r * (1.0 + j), 0.0, 1.0), clampf(m.color.g * (1.0 + j), 0.0, 1.0),
				clampf(m.color.b * (1.0 + j), 0.0, 1.0), m.emit)
		for f in 6:
			var n := _NORMALS[f]
			if p.voxels.has(vp + n):
				continue
			var corners: Array = _CORNERS[f]
			var aos: Array[int] = []
			for c in 4:
				var corner: Vector3i = corners[c]
				# Ejes tangentes: los que no son el de la normal
				var t1 := Vector3i.ZERO
				var t2 := Vector3i.ZERO
				if n.x != 0:
					t1 = Vector3i(0, 1 if corner.y == 1 else -1, 0)
					t2 = Vector3i(0, 0, 1 if corner.z == 1 else -1)
				elif n.y != 0:
					t1 = Vector3i(1 if corner.x == 1 else -1, 0, 0)
					t2 = Vector3i(0, 0, 1 if corner.z == 1 else -1)
				else:
					t1 = Vector3i(1 if corner.x == 1 else -1, 0, 0)
					t2 = Vector3i(0, 1 if corner.y == 1 else -1, 0)
				var front := vp + n
				var s1 := 1 if p.voxels.has(front + t1) else 0
				var s2 := 1 if p.voxels.has(front + t2) else 0
				var cc := 1 if p.voxels.has(front + t1 + t2) else 0
				aos.append(0 if (s1 == 1 and s2 == 1) else 3 - s1 - s2 - cc)
			var base := verts.size()
			var nn := transform.basis * Vector3(n)
			for c in 4:
				var corner2: Vector3i = corners[c]
				var local := p.origin + Vector3(vp + corner2) * vs
				verts.append(transform * local)
				normals.append(nn)
				var k: float = _AO[aos[c]]
				colors.append(Color(base_col.r * k, base_col.g * k, base_col.b * k, base_col.a))
				uv2.append(Vector2(m.metal, m.rough))
				if skinned:
					bones.append(bone_index)
					bones.append(0)
					bones.append(0)
					bones.append(0)
					weights.append(1.0)
					weights.append(0.0)
					weights.append(0.0)
					weights.append(0.0)
			if aos[0] + aos[2] < aos[1] + aos[3]:
				indices.append_array(PackedInt32Array([base + 1, base + 2, base + 3, base + 1, base + 3, base]))
			else:
				indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	return [verts, normals, colors, uv2, bones, weights, indices]


func _arrays_from(res: Array, skinned: bool) -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = res[0]
	arr[Mesh.ARRAY_NORMAL] = res[1]
	arr[Mesh.ARRAY_COLOR] = res[2]
	arr[Mesh.ARRAY_TEX_UV2] = res[3]
	if skinned:
		arr[Mesh.ARRAY_BONES] = res[4]
		arr[Mesh.ARRAY_WEIGHTS] = res[5]
	arr[Mesh.ARRAY_INDEX] = res[6]
	return arr


## Malla con piel: cada pieza queda pesada al 100 % en su hueso.
func build_skinned_mesh(bone_names: PackedStringArray, material: Material) -> ArrayMesh:
	var res: Array = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(),
			PackedInt32Array(), PackedFloat32Array(), PackedInt32Array()]
	for p in parts:
		var bi := bone_names.find(p.bone)
		if bi < 0:
			push_warning("VoxelModel: hueso '%s' no existe en el esqueleto" % p.bone)
			bi = 0
		res = _emit_part(p, bi, res[0], res[1], res[2], res[3], res[4], res[5], res[6], true, Transform3D.IDENTITY)
	var mesh := ArrayMesh.new()
	if (res[0] as PackedVector3Array).is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays_from(res, true))
	mesh.surface_set_material(0, material)
	return mesh


## Malla estática con todas las piezas (o solo las indicadas).
func build_static_mesh(material: Material, only_parts: PackedStringArray = PackedStringArray(),
		transform: Transform3D = Transform3D.IDENTITY) -> ArrayMesh:
	var res: Array = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedVector2Array(),
			PackedInt32Array(), PackedFloat32Array(), PackedInt32Array()]
	for p in parts:
		if not only_parts.is_empty() and not only_parts.has(p.name):
			continue
		res = _emit_part(p, 0, res[0], res[1], res[2], res[3], res[4], res[5], res[6], false, transform)
	var mesh := ArrayMesh.new()
	if (res[0] as PackedVector3Array).is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays_from(res, false))
	mesh.surface_set_material(0, material)
	return mesh


## Caja envolvente (en metros, espacio del modelo) de las piezas indicadas.
func bounds(only_parts: PackedStringArray = PackedStringArray()) -> AABB:
	var first := true
	var box := AABB()
	for p in parts:
		if not only_parts.is_empty() and not only_parts.has(p.name):
			continue
		for vp: Vector3i in p.voxels:
			var a := p.origin + Vector3(vp) * voxel_size
			var b := a + Vector3.ONE * voxel_size
			if first:
				box = AABB(a, b - a)
				first = false
			else:
				box = box.expand(a).expand(b)
	return box
