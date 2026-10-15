class_name ChunkMesher
extends RefCounted
## Convierte un ChunkData en geometría (opaca, recortada y agua) y en caras de
## colisión. Incluye oclusión ambiental por vértice al estilo de los juegos
## voxel clásicos. Está pensado para ejecutarse en hilos de trabajo.

const PAD := ChunkData.PAD
const LAYER := ChunkData.LAYER
const HEIGHT := ChunkData.HEIGHT

# Orden de caras: 0 +X, 1 -X, 2 +Y, 3 -Y, 4 +Z, 5 -Z
const FACE_NORMALS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
		Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
const FACE_DELTA: Array[int] = [1, -1, LAYER, -LAYER, PAD, -PAD]
# Esquinas en sentido horario vistas desde fuera (Godot usa el sentido horario
# para las caras frontales), empezando por la esquina superior izquierda.
const FACE_CORNERS := [
	[Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)],
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 0)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0)],
]
const QUAD_UVS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
const FACE_SHADE: Array[float] = [0.88, 0.88, 1.0, 0.64, 0.8, 0.8]
const AO_CURVE: Array[float] = [0.46, 0.64, 0.82, 1.0]

static var fancy_leaves: bool = true
static var _ao_deltas := PackedInt32Array()   # 6 caras * 4 esquinas * 2 lados
static var _layer_variants := PackedByteArray()


static func _static_init() -> void:
	_ao_deltas.resize(6 * 4 * 2)
	var axis_delta: Array[int] = [1, LAYER, PAD]
	var normal_axis: Array[int] = [0, 0, 1, 1, 2, 2]
	for f in 6:
		var na := normal_axis[f]
		var tangents: Array[int] = []
		for a in 3:
			if a != na:
				tangents.append(a)
		for c in 4:
			var corner: Vector3 = FACE_CORNERS[f][c]
			for t in 2:
				var a := tangents[t]
				var sgn := 1 if corner[a] > 0.5 else -1
				_ao_deltas[(f * 4 + c) * 2 + t] = sgn * axis_delta[a]


static func _ensure_variant_table() -> void:
	if _layer_variants.size() == BlockTypes.texture_layer_count:
		return
	var tbl := PackedByteArray()
	tbl.resize(BlockTypes.texture_layer_count)
	for tex_name: String in BlockTypes.texture_base:
		tbl[int(BlockTypes.texture_base[tex_name])] = int(BlockTypes.texture_variants[tex_name])
	_layer_variants = tbl


class SurfaceBuilder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func add_vertex(p: Vector3, n: Vector3, uv: Vector2, tex_layer: float, c: Color) -> void:
		verts.append(p)
		normals.append(n)
		uvs.append(uv)
		uv2s.append(Vector2(tex_layer, 0.0))
		colors.append(c)

	func add_quad_indices(base: int, flip: bool) -> void:
		if flip:
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 3)
			indices.append(base + 1)
			indices.append(base + 3)
			indices.append(base)
		else:
			indices.append(base)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base)
			indices.append(base + 2)
			indices.append(base + 3)

	func is_empty() -> bool:
		return verts.is_empty()

	func to_arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
		arr[Mesh.ARRAY_COLOR] = colors
		arr[Mesh.ARRAY_INDEX] = indices
		return arr


class CollisionBuilder:
	var faces := PackedVector3Array()

	func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		faces.append(a)
		faces.append(b)
		faces.append(c)
		faces.append(a)
		faces.append(c)
		faces.append(d)


static func _hash3(x: int, y: int, z: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## Genera la geometría. Devuelve un diccionario con los arrays de cada capa,
## las caras de colisión y las posiciones de antorchas.
static func build(data: ChunkData) -> Dictionary:
	_ensure_variant_table()
	var blocks := data.blocks
	var opq := BlockTypes.opaque
	var shp_tbl := BlockTypes.shape
	var lyr_tbl := BlockTypes.layer
	var solid_tbl := BlockTypes.solid
	var tint_tbl := BlockTypes.tinted
	var t_top := BlockTypes.tex_top
	var t_side := BlockTypes.tex_side
	var t_bot := BlockTypes.tex_bottom
	var variants := _layer_variants
	var tints := data.tints
	var ox := data.origin_x()
	var oz := data.origin_z()

	var surf_opaque := SurfaceBuilder.new()
	var surf_cutout := SurfaceBuilder.new()
	var surf_water := SurfaceBuilder.new()
	var collision := CollisionBuilder.new()
	var lights := PackedVector3Array()

	var ymax := mini(data.max_y + 1, HEIGHT - 2)
	for y in range(1, ymax + 1):
		for lz in 16:
			var row := (lz + 1) * PAD + y * LAYER + 1
			for lx in 16:
				var i := row + lx
				var id := blocks[i]
				if id == 0:
					continue
				var shp := shp_tbl[id]
				if shp == BlockTypes.Shape.CUBE:
					var is_opaque := opq[id] == 1
					var surf := surf_opaque if lyr_tbl[id] == BlockTypes.Layer.OPAQUE else surf_cutout
					var is_leaf := tint_tbl[id] == 1 and id != BlockTypes.GRASS
					var tint := tints[(lx + 1) + (lz + 1) * PAD]
					var is_solid := solid_tbl[id] == 1
					for f in 6:
						var nid := blocks[i + FACE_DELTA[f]]
						if opq[nid] == 1:
							continue
						if not is_opaque and nid == id and not (is_leaf and fancy_leaves):
							continue
						var tex: int
						if f == 2:
							tex = t_top[id]
						elif f == 3:
							tex = t_bot[id]
						else:
							tex = t_side[id]
						var nv := variants[tex]
						if nv > 1:
							tex += _hash3(ox + lx, y, oz + lz) % nv
						var base_col := Color(1, 1, 1)
						if tint_tbl[id] == 1 and (f == 2 or is_leaf):
							base_col = tint
						var shade := FACE_SHADE[f]
						var front := i + FACE_DELTA[f]
						var ao0 := _ao(blocks, opq, front, f, 0)
						var ao1 := _ao(blocks, opq, front, f, 1)
						var ao2 := _ao(blocks, opq, front, f, 2)
						var ao3 := _ao(blocks, opq, front, f, 3)
						var base := surf.verts.size()
						var corners: Array = FACE_CORNERS[f]
						var n := FACE_NORMALS[f]
						var p := Vector3(lx, y, lz)
						var aos: Array[int] = [ao0, ao1, ao2, ao3]
						for c in 4:
							var k := shade * AO_CURVE[aos[c]]
							surf.add_vertex(p + (corners[c] as Vector3), n, QUAD_UVS[c], tex,
									Color(base_col.r * k, base_col.g * k, base_col.b * k))
						surf.add_quad_indices(base, ao0 + ao2 < ao1 + ao3)
						if is_solid:
							collision.add_quad(p + (corners[0] as Vector3), p + (corners[1] as Vector3),
									p + (corners[2] as Vector3), p + (corners[3] as Vector3))
				elif shp == BlockTypes.Shape.CROSS:
					var tex := t_side[id]
					var nv2 := variants[tex]
					var h := _hash3(ox + lx, y, oz + lz)
					if nv2 > 1:
						tex += h % nv2
					var col := tints[(lx + 1) + (lz + 1) * PAD] if tint_tbl[id] == 1 else Color(1, 1, 1)
					_emit_cross(surf_cutout, Vector3(lx, y, lz), tex, col, h)
				elif shp == BlockTypes.Shape.LIQUID:
					_emit_liquid(surf_water, blocks, opq, i, id, Vector3(lx, y, lz), t_top[id])
				else:
					var p2 := Vector3(lx, y, lz)
					var tex_t := t_top[id]
					var tex_s := t_side[id]
					var tex_b := t_bot[id]
					var is_solid2 := solid_tbl[id] == 1
					var surf2 := surf_opaque if lyr_tbl[id] == BlockTypes.Layer.OPAQUE else surf_cutout
					var col_ref: CollisionBuilder = collision if is_solid2 else null
					match shp:
						BlockTypes.Shape.SLAB:
							_emit_box(surf2, col_ref, blocks, opq, i, p2, Vector3(0, 0, 0), Vector3(1, 0.5, 1), tex_t, tex_s, tex_b)
						BlockTypes.Shape.SLAB_TOP:
							_emit_box(surf2, col_ref, blocks, opq, i, p2, Vector3(0, 0.5, 0), Vector3(1, 1, 1), tex_t, tex_s, tex_b)
						BlockTypes.Shape.STAIRS:
							_emit_box(surf2, col_ref, blocks, opq, i, p2, Vector3(0, 0, 0), Vector3(1, 0.5, 1), tex_t, tex_s, tex_b)
							var fdir := int(BlockTypes.facing[id])
							var a := Vector3(0, 0.5, 0)
							var b := Vector3(1, 1, 1)
							match fdir:
								0:
									b.z = 0.5
								1:
									a.x = 0.5
								2:
									a.z = 0.5
								_:
									b.x = 0.5
							_emit_box(surf2, col_ref, blocks, opq, i, p2, a, b, tex_t, tex_s, tex_b)
						BlockTypes.Shape.TORCH:
							_emit_box(surf_cutout, null, blocks, opq, i, p2,
									Vector3(7.0 / 16.0, 0, 7.0 / 16.0), Vector3(9.0 / 16.0, 10.0 / 16.0, 9.0 / 16.0), tex_t, tex_s, tex_b)
							lights.append(p2 + Vector3(0.5, 0.78, 0.5))
						BlockTypes.Shape.FENCE:
							_emit_fence(surf2, col_ref, blocks, opq, shp_tbl, i, p2, tex_s)
						_:
							pass

	var result := {
		"opaque": null if surf_opaque.is_empty() else surf_opaque.to_arrays(),
		"cutout": null if surf_cutout.is_empty() else surf_cutout.to_arrays(),
		"water": null if surf_water.is_empty() else surf_water.to_arrays(),
		"collision": collision.faces,
		"lights": lights,
	}
	return result


static func _ao(blocks: PackedByteArray, opq: PackedByteArray, front: int, f: int, c: int) -> int:
	var k := (f * 4 + c) * 2
	var d1 := _ao_deltas[k]
	var d2 := _ao_deltas[k + 1]
	var s1 := opq[blocks[front + d1]]
	var s2 := opq[blocks[front + d2]]
	if s1 == 1 and s2 == 1:
		return 0
	return 3 - s1 - s2 - opq[blocks[front + d1 + d2]]


static func _emit_cross(surf: SurfaceBuilder, p: Vector3, tex: int, col: Color, h: int) -> void:
	var jx := (float(h & 15) / 15.0 - 0.5) * 0.3
	var jz := (float((h >> 4) & 15) / 15.0 - 0.5) * 0.3
	var height := 0.85 + float((h >> 8) & 7) / 7.0 * 0.25
	var c := p + Vector3(0.5 + jx, 0, 0.5 + jz)
	var r := 0.45
	var up := Vector3(0, 1, 0)
	var dark := Color(col.r * 0.8, col.g * 0.8, col.b * 0.8)
	var quads := [
		[c + Vector3(-r, height, -r), c + Vector3(r, height, r), c + Vector3(r, 0, r), c + Vector3(-r, 0, -r)],
		[c + Vector3(-r, height, r), c + Vector3(r, height, -r), c + Vector3(r, 0, -r), c + Vector3(-r, 0, r)],
	]
	for q: Array in quads:
		var base := surf.verts.size()
		surf.add_vertex(q[0], up, Vector2(0, 0), tex, col)
		surf.add_vertex(q[1], up, Vector2(1, 0), tex, col)
		surf.add_vertex(q[2], up, Vector2(1, 1), tex, dark)
		surf.add_vertex(q[3], up, Vector2(0, 1), tex, dark)
		surf.add_quad_indices(base, false)


static func _emit_liquid(surf: SurfaceBuilder, blocks: PackedByteArray, opq: PackedByteArray, i: int, id: int,
		p: Vector3, tex: int) -> void:
	var above := blocks[i + LAYER]
	var top := 1.0 if above == id else 0.875
	for f in 6:
		var nid := blocks[i + FACE_DELTA[f]]
		if nid == id or opq[nid] == 1:
			continue
		if f == 3:
			continue
		var corners: Array = FACE_CORNERS[f]
		var base := surf.verts.size()
		for c in 4:
			var k: Vector3 = corners[c]
			var v := Vector3(k.x, k.y * top, k.z)
			surf.add_vertex(p + v, FACE_NORMALS[f], QUAD_UVS[c], tex, Color(1, 1, 1))
		surf.add_quad_indices(base, false)


static func _uv_for(f: int, v: Vector3) -> Vector2:
	match f:
		0:
			return Vector2(1.0 - v.z, 1.0 - v.y)
		1:
			return Vector2(v.z, 1.0 - v.y)
		2:
			return Vector2(v.x, v.z)
		3:
			return Vector2(v.x, 1.0 - v.z)
		4:
			return Vector2(v.x, 1.0 - v.y)
		_:
			return Vector2(1.0 - v.x, 1.0 - v.y)


## Emite una caja (subvolumen del bloque). Las caras que tocan el borde del
## bloque se omiten si el vecino es opaco. Devuelve el array de colisión.
static func _emit_box(surf: SurfaceBuilder, col: CollisionBuilder, blocks: PackedByteArray, opq: PackedByteArray,
		i: int, p: Vector3, a: Vector3, b: Vector3, tex_top: int, tex_side: int, tex_bottom: int) -> void:
	for f in 6:
		var on_edge := false
		match f:
			0:
				on_edge = b.x >= 0.999
			1:
				on_edge = a.x <= 0.001
			2:
				on_edge = b.y >= 0.999
			3:
				on_edge = a.y <= 0.001
			4:
				on_edge = b.z >= 0.999
			5:
				on_edge = a.z <= 0.001
		if on_edge and opq[blocks[i + FACE_DELTA[f]]] == 1:
			continue
		var tex := tex_side
		if f == 2:
			tex = tex_top
		elif f == 3:
			tex = tex_bottom
		var corners: Array = FACE_CORNERS[f]
		var base := surf.verts.size()
		var shade := FACE_SHADE[f]
		var pts: Array[Vector3] = []
		for c in 4:
			var k: Vector3 = corners[c]
			var v := Vector3(lerpf(a.x, b.x, k.x), lerpf(a.y, b.y, k.y), lerpf(a.z, b.z, k.z))
			pts.append(p + v)
			surf.add_vertex(p + v, FACE_NORMALS[f], _uv_for(f, v), tex, Color(shade, shade, shade))
		surf.add_quad_indices(base, false)
		if col != null:
			col.add_quad(pts[0], pts[1], pts[2], pts[3])


static func _emit_fence(surf: SurfaceBuilder, col: CollisionBuilder, blocks: PackedByteArray, opq: PackedByteArray,
		shp_tbl: PackedByteArray, i: int, p: Vector3, tex: int) -> void:
	var s := 1.0 / 16.0
	_emit_box(surf, col, blocks, opq, i, p, Vector3(6 * s, 0, 6 * s), Vector3(10 * s, 1.0, 10 * s), tex, tex, tex)
	var dirs := [[0, Vector3(10 * s, 0, 7 * s), Vector3(1.0, 0, 9 * s)],
			[1, Vector3(0, 0, 7 * s), Vector3(6 * s, 0, 9 * s)],
			[4, Vector3(7 * s, 0, 10 * s), Vector3(9 * s, 0, 1.0)],
			[5, Vector3(7 * s, 0, 0), Vector3(9 * s, 0, 6 * s)]]
	for d: Array in dirs:
		var f: int = d[0]
		var nid := blocks[i + FACE_DELTA[f]]
		if shp_tbl[nid] == BlockTypes.Shape.FENCE or opq[nid] == 1:
			var lo: Vector3 = d[1]
			var hi: Vector3 = d[2]
			for rail_y: Array in [[6 * s, 9 * s], [12 * s, 15 * s]]:
				var a := Vector3(lo.x, rail_y[0], lo.z)
				var b := Vector3(hi.x, rail_y[1], hi.z)
				_emit_box(surf, col, blocks, opq, i, p, a, b, tex, tex, tex)
