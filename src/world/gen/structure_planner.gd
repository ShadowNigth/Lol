class_name StructurePlanner
extends RefCounted
## Planifica dónde van las estructuras, caminos y zonas niveladas del mundo.
## Fase 1: aldea inicial de Hojarrubia, torre, muralla y ruinas con cementerio.
## La planificación es determinista y de solo lectura tras el constructor.

const B = preload("res://src/world/voxel/block_types.gd")
const VILLAGE_FLOOR := WorldGenerator.SEA_LEVEL + 6   # altura del suelo de la aldea

var gen: WorldGenerator
var structures: Array[Dictionary] = []
var flatten_zones: Array[Dictionary] = []
var roads: Array[Dictionary] = []       # {a: Vector2, b: Vector2, half: float, block: int}
var paved: Array[Dictionary] = []       # {rect: Rect2i, block: int}
var reserved: Array[Rect2i] = []
var spawns: Array[Dictionary] = []      # criaturas planificadas
var locations: Array[Dictionary] = []   # zonas con nombre (HUD)
var spawn_point := Vector3(3.5, VILLAGE_FLOOR + 1.0, 3.5)
var spawn_yaw_deg := -90.0              # mirando al este


func _init(generator: WorldGenerator) -> void:
	gen = generator
	_plan_start_village()
	_plan_east_ruins()


# ---------------------------------------------------------------------------
# Planificación
# ---------------------------------------------------------------------------

func _add_structure(s: Dictionary) -> void:
	var fp := ChunkWriter.footprint(int(s["w"]), int(s["d"]), int(s.get("rot", 0)))
	var o: Vector3i = s["origin"]
	var margin := int(s.get("margin", 3))
	s["aabb"] = Rect2i(o.x - margin, o.z - margin, fp.x + margin * 2, fp.y + margin * 2)
	s["footprint"] = Rect2i(o.x, o.z, fp.x, fp.y)
	if not s.has("seed"):
		s["seed"] = gen.world_seed + structures.size() * 7717
	structures.append(s)
	reserved.append(Rect2i(o.x - 2, o.z - 2, fp.x + 4, fp.y + 4))


func _add_road(a: Vector2, b: Vector2, width: float, block: int = B.PATH) -> void:
	roads.append({"a": a, "b": b, "half": width * 0.5, "block": block})


func _plan_start_village() -> void:
	var fy := VILLAGE_FLOOR + 1
	flatten_zones.append({"rect": Rect2i(-34, -24, 71, 57), "height": float(VILLAGE_FLOOR), "margin": 22.0})
	locations.append({"name": "Aldea de Hojarrubia", "rect": Rect2i(-34, -24, 71, 57)})
	paved.append({"rect": Rect2i(-8, -9, 17, 18), "block": B.COBBLE})
	reserved.append(Rect2i(-9, -10, 19, 20))

	_add_structure({"id": "village/inn", "type": "house", "origin": Vector3i(-5, fy, -19), "w": 11, "d": 9, "rot": 2,
			"floors": 2, "style": "stone", "roof": B.ROOF_STAIRS, "interior": "inn", "name": "La Jarra del Roble"})
	_add_structure({"id": "village/house_a", "type": "house", "origin": Vector3i(-18, fy, -14), "w": 9, "d": 7, "rot": 1,
			"floors": 2, "style": "timber", "roof": B.ROOF_STAIRS})
	_add_structure({"id": "village/house_b", "type": "house", "origin": Vector3i(-17, fy, 5), "w": 7, "d": 7, "rot": 1,
			"floors": 1, "style": "stone", "roof": B.THATCH_STAIRS})
	_add_structure({"id": "village/smithy", "type": "smithy", "origin": Vector3i(11, fy, -13), "w": 7, "d": 6, "rot": 3})
	_add_structure({"id": "village/house_c", "type": "house", "origin": Vector3i(11, fy, 6), "w": 7, "d": 6, "rot": 3,
			"floors": 1, "style": "timber", "roof": B.THATCH_STAIRS})
	_add_structure({"id": "village/house_d", "type": "house", "origin": Vector3i(-15, fy, 17), "w": 9, "d": 7, "rot": 0,
			"floors": 2, "style": "brick", "roof": B.ROOF_STAIRS})
	_add_structure({"id": "village/well", "type": "well", "origin": Vector3i(-1, fy, -1), "w": 3, "d": 3, "rot": 0, "margin": 2})
	_add_structure({"id": "village/stall_1", "type": "stall", "origin": Vector3i(-6, fy, 4), "w": 3, "d": 2, "rot": 0,
			"goods": "food", "margin": 1})
	_add_structure({"id": "village/stall_2", "type": "stall", "origin": Vector3i(4, fy, -7), "w": 3, "d": 2, "rot": 2,
			"goods": "cloth", "margin": 1})
	for p: Vector2i in [Vector2i(-8, -9), Vector2i(8, -9), Vector2i(-8, 8), Vector2i(8, 8), Vector2i(2, 20), Vector2i(-2, 40),
			Vector2i(20, 2), Vector2i(-24, -2)]:
		_add_structure({"id": "village/lamp_%d_%d" % [p.x, p.y], "type": "lamp", "origin": Vector3i(p.x, fy, p.y),
				"w": 1, "d": 1, "rot": 0, "margin": 1})
	_add_structure({"id": "village/field", "type": "field", "origin": Vector3i(-31, fy, -13), "w": 9, "d": 9, "rot": 0})
	_add_structure({"id": "village/tower", "type": "tower", "origin": Vector3i(4, fy, 24), "w": 5, "d": 5, "rot": 3,
			"height": 13})
	_add_structure({"id": "village/east_wall", "type": "wall", "origin": Vector3i(32, fy, -12), "w": 25, "d": 2, "rot": 1,
			"height": 5, "gate_from": 10, "gate_to": 14})

	# Personajes con nombre (posición de trabajo, casa para la noche, patrulla)
	spawns.append({"type": "npc", "npc": "berta", "id": "npc/berta", "pos": Vector3(0.5, fy, -17.5), "yaw": 180.0})
	spawns.append({"type": "npc", "npc": "oswin", "id": "npc/oswin", "pos": Vector3(14.6, fy, -9.5), "yaw": 90.0,
			"home": Vector3(10.5, fy, 9.5)})
	spawns.append({"type": "npc", "npc": "mira", "id": "npc/mira", "pos": Vector3(-2.4, fy, 0.5), "yaw": -90.0,
			"home": Vector3(-9.5, fy, 8.5)})
	spawns.append({"type": "npc", "npc": "tomas", "id": "npc/tomas", "pos": Vector3(-3.5, fy, -8.0), "yaw": 180.0,
			"home": Vector3(-10.5, fy, 16.5)})
	spawns.append({"type": "npc", "npc": "rolf", "id": "npc/rolf", "pos": Vector3(6.5, fy, 6.5), "yaw": 0.0,
			"patrol": [Vector3(6.5, fy, 6.5), Vector3(-6.5, fy, 6.5), Vector3(-6.5, fy, -6.5), Vector3(6.5, fy, -6.5), Vector3(20.0, fy, 0.5)]})

	# Caminos
	_add_road(Vector2(-70, 0), Vector2(-8, 0), 3.0)
	_add_road(Vector2(8, 0), Vector2(110, 0), 3.0)
	_add_road(Vector2(0, 8), Vector2(0, 80), 3.0)
	_add_road(Vector2(-11, -10), Vector2(-8, -10), 1.0)
	_add_road(Vector2(-10, 8), Vector2(-8, 8), 1.0)
	_add_road(Vector2(10, 9), Vector2(8, 9), 1.0)
	_add_road(Vector2(9, -10), Vector2(8, -10), 1.0)
	_add_road(Vector2(3, 26), Vector2(1, 26), 1.0)
	_add_road(Vector2(-11, 16), Vector2(-11, 9), 1.0)
	_add_road(Vector2(-27, -4), Vector2(-27, -1), 1.0)
	for r: Dictionary in roads:
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		var h: float = r["half"] + 1.0
		var rect := Rect2(a, Vector2.ZERO).expand(b).grow(h)
		reserved.append(Rect2i(rect))


func _plan_east_ruins() -> void:
	var ry := int(round(gen.raw_height(64, 0)))
	ry = clampi(ry, WorldGenerator.SEA_LEVEL + 3, WorldGenerator.SEA_LEVEL + 22)
	flatten_zones.append({"rect": Rect2i(54, -16, 21, 36), "height": float(ry), "margin": 16.0})
	locations.append({"name": "Capilla en ruinas de Velmar", "rect": Rect2i(54, -16, 21, 13)})
	locations.append({"name": "Cementerio olvidado", "rect": Rect2i(54, 3, 21, 16)})
	var fy := ry + 1
	_add_structure({"id": "ruins/chapel", "type": "chapel_ruin", "origin": Vector3i(58, fy, -14), "w": 13, "d": 9, "rot": 2,
			"margin": 4, "dungeon": "crypt_velmar"})
	_add_structure({"id": "ruins/graveyard", "type": "graveyard", "origin": Vector3i(56, fy, 5), "w": 17, "d": 13, "rot": 0})
	spawns.append({"id": "ruins/skeleton_0", "enemy": "skeleton_warrior", "pos": Vector3(60.5, fy, 10.5), "yaw": 30.0,
			"patrol": [Vector3(60.5, fy, 10.5), Vector3(68.5, fy, 10.5), Vector3(68.5, fy, 14.5)]})
	spawns.append({"id": "ruins/skeleton_1", "enemy": "skeleton_warrior", "pos": Vector3(65.5, fy, 9.5), "yaw": 160.0})
	spawns.append({"id": "ruins/skeleton_2", "enemy": "skeleton_warrior", "pos": Vector3(63.5, fy, -10.5), "yaw": 0.0,
			"patrol": [Vector3(61.5, fy, -10.5), Vector3(66.5, fy, -10.5)]})


# ---------------------------------------------------------------------------
# Consultas (usadas por el generador, posiblemente desde hilos)
# ---------------------------------------------------------------------------

func apply_flatten(x: int, z: int, h: float) -> float:
	for zone: Dictionary in flatten_zones:
		var r: Rect2i = zone["rect"]
		var dx := maxi(maxi(r.position.x - x, 0), x - (r.position.x + r.size.x - 1))
		var dz := maxi(maxi(r.position.y - z, 0), z - (r.position.y + r.size.y - 1))
		var margin: float = zone["margin"]
		var dist := sqrt(float(dx * dx + dz * dz))
		if dist >= margin:
			continue
		var t := 1.0 - smoothstep(0.0, margin, dist)
		h = lerpf(h, float(zone["height"]), t)
	return h


func surface_override(x: int, z: int) -> int:
	for p: Dictionary in paved:
		var r: Rect2i = p["rect"]
		if r.has_point(Vector2i(x, z)):
			return int(p["block"])
	var pt := Vector2(x + 0.5, z + 0.5)
	for road: Dictionary in roads:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var half: float = road["half"]
		var ab := b - a
		var t := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var dist := pt.distance_to(a + ab * t)
		if dist <= half:
			# Bordes del camino irregulares
			if dist > half - 0.7 and WorldGenerator.hash2(x, z, 1234) % 3 == 0:
				continue
			return int(road["block"])
	return 0


func is_reserved(x: int, z: int) -> bool:
	var p := Vector2i(x, z)
	for r: Rect2i in reserved:
		if r.has_point(p):
			return true
	return false


func stamp_structures(data: ChunkData) -> void:
	var area := Rect2i(data.origin_x() - 1, data.origin_z() - 1, ChunkData.PAD, ChunkData.PAD)
	var wr := ChunkWriter.new(data)
	for s: Dictionary in structures:
		var aabb: Rect2i = s["aabb"]
		if aabb.intersects(area):
			StructureBuilder.build(wr, s)


func add_spawns(data: ChunkData, _heights: PackedInt32Array) -> void:
	for sp: Dictionary in spawns:
		var p: Vector3 = sp["pos"]
		if data.contains_world_core(int(floor(p.x)), int(floor(p.z))):
			var e := sp.duplicate(true)
			if not e.has("type"):
				e["type"] = "enemy"
			data.entities.append(e)


func location_at(x: float, z: float) -> String:
	var p := Vector2i(int(floor(x)), int(floor(z)))
	for loc: Dictionary in locations:
		var r: Rect2i = loc["rect"]
		if r.has_point(p):
			return str(loc["name"])
	return ""
