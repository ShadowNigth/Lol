class_name StructurePlanner
extends RefCounted
## Planifica dónde van las estructuras, caminos y zonas niveladas del mundo.
## Fase 1: aldea inicial de Hojarrubia, torre, muralla y ruinas con cementerio.
## La planificación es determinista y de solo lectura tras el constructor.

const B = preload("res://src/world/voxel/block_types.gd")
const VILLAGE_FLOOR := WorldGenerator.SEA_LEVEL + 6   # altura del suelo de la aldea
const SEA_LEVEL_SAFE := WorldGenerator.SEA_LEVEL + 4

var gen: WorldGenerator
var structures: Array[Dictionary] = []
var flatten_zones: Array[Dictionary] = []
var roads: Array[Dictionary] = []       # {a: Vector2, b: Vector2, half: float, block: int}
var paved: Array[Dictionary] = []       # {rect: Rect2i, block: int}
var reserved: Array[Rect2i] = []
var spawns: Array[Dictionary] = []      # criaturas planificadas
var locations: Array[Dictionary] = []   # zonas con nombre (HUD)
var sites: Array[Dictionary] = []      # lugares de la región: {id, name, kind, pos: Vector2}
var no_wildlife: Array[Rect2i] = []     # zonas habitadas: sin fauna salvaje
var spawn_point := Vector3(3.5, VILLAGE_FLOOR + 1.0, 3.5)
var spawn_yaw_deg := -90.0              # mirando al este


func _init(generator: WorldGenerator) -> void:
	gen = generator
	_plan_start_village()
	_plan_east_ruins()
	_plan_region()


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

	spawns.append({"type": "notice_board", "id": "board/hojarrubia", "site": "hojarrubia", "pos": Vector3(6.5, fy, -2.5), "yaw": 90.0})

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
	spawns.append({"id": "ruins/archer_0", "enemy": "skeleton_archer", "pos": Vector3(70.5, fy, 3.0), "yaw": 135.0})
	spawns.append({"id": "ruins/skeleton_2", "enemy": "skeleton_warrior", "pos": Vector3(63.5, fy, -10.5), "yaw": 0.0,
			"patrol": [Vector3(61.5, fy, -10.5), Vector3(66.5, fy, -10.5)]})


# ---------------------------------------------------------------------------
# Fase 6: región alrededor de la aldea (sitios con semilla y caminos)
# ---------------------------------------------------------------------------

## Posada del camino al oeste, aldea de Robledal al sur, túmulo cerca de
## Robledal y cubil de lobos en los bosques del norte. Las posiciones
## exactas dependen de la semilla y del relieve (se elige el terreno más
## llano y seco entre varios candidatos); los identificadores son fijos para
## que misiones y partidas guardadas los encuentren siempre.
func _plan_region() -> void:
	sites.append({"id": "village", "name": "Aldea de Hojarrubia", "kind": "village", "pos": Vector2(0, 0)})
	sites.append({"id": "ruins", "name": "Capilla en ruinas de Velmar", "kind": "dungeon", "pos": Vector2(64, -10)})
	no_wildlife.append(Rect2i(-110, -100, 220, 200))
	no_wildlife.append(Rect2i(40, -40, 50, 75))
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(gen.world_seed * 7919 + 1301)
	var inn := _find_site(rng, Vector2(-215.0, rng.randf_range(-35.0, 35.0)), 45.0, Vector2i(32, 34))
	_plan_roadside_inn(inn)
	_add_winding_road(Vector2(-70, 0), Vector2(inn.x + 8, inn.z), 3.0, rng)
	var ham := _find_site(rng, Vector2(rng.randf_range(-50.0, 50.0), 300.0), 55.0, Vector2i(42, 38))
	_plan_hamlet(ham, rng)
	_add_winding_road(Vector2(0, 80), Vector2(ham.x, ham.z - 18), 3.0, rng)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var bar := _find_site(rng, Vector2(ham.x + side * 120.0, ham.z + 50.0), 40.0, Vector2i(19, 19))
	_plan_barrow(bar)
	_add_winding_road(Vector2(ham.x + side * 20.0, ham.z), Vector2(bar.x, bar.z - side * 0.0 - 11.0), 2.0, rng)
	var den := _find_site(rng, Vector2(rng.randf_range(-230.0, -120.0), -240.0), 70.0, Vector2i(15, 15), true)
	_plan_wolf_den(den)
	# Se planifica el último y con su propio generador: no altera el resto de la región
	_plan_bandit_camp(inn, ham)


## Busca el mejor emplazamiento cerca de `around`: seco, lo más llano posible
## y lejos de lo ya reservado. Devuelve (x, altura del suelo, z) del centro.
func _find_site(rng: RandomNumberGenerator, around: Vector2, radius: float, size: Vector2i, prefer_forest: bool = false) -> Vector3i:
	var best := Vector3i(int(around.x), SEA_LEVEL_SAFE, int(around.y))
	var best_score := INF
	for i in 24:
		var ang := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * radius
		var c := around + Vector2(cos(ang), sin(ang)) * dist
		var lo := INF
		var hi := -INF
		var sum := 0.0
		for gz in 5:
			for gx in 5:
				var h := gen.raw_height(c.x + (gx - 2) * size.x / 4.0, c.y + (gz - 2) * size.y / 4.0)
				lo = minf(lo, h)
				hi = maxf(hi, h)
				sum += h
		if lo < WorldGenerator.SEA_LEVEL + 2:
			continue
		var rect := Rect2i(int(c.x) - size.x / 2, int(c.y) - size.y / 2, size.x, size.y)
		var blocked := false
		for r: Rect2i in reserved:
			if r.intersects(rect):
				blocked = true
				break
		if blocked:
			continue
		var score := (hi - lo) + dist * 0.02 + maxf(sum / 25.0 - (WorldGenerator.SEA_LEVEL + 30.0), 0.0)
		if prefer_forest:
			var b := gen.biome_at(int(c.x), int(c.y), int(sum / 25.0))
			if b in [WorldGenerator.Biome.FOREST, WorldGenerator.Biome.BIRCH_FOREST, WorldGenerator.Biome.TAIGA]:
				score -= 4.0
		if score < best_score:
			best_score = score
			best = Vector3i(int(round(c.x)), int(round(sum / 25.0)), int(round(c.y)))
	best.y = clampi(best.y, WorldGenerator.SEA_LEVEL + 2, WorldGenerator.SEA_LEVEL + 40)
	return best


## Camino con un quiebro intermedio (no una recta perfecta entre lugares).
func _add_winding_road(a: Vector2, b: Vector2, width: float, rng: RandomNumberGenerator) -> void:
	var mid := (a + b) * 0.5
	var perp := (b - a).orthogonal().normalized()
	mid += perp * rng.randf_range(-0.12, 0.12) * a.distance_to(b)
	for seg: Array in [[a, mid], [mid, b]]:
		_add_road(seg[0], seg[1], width)
		var rect := Rect2(seg[0], Vector2.ZERO).expand(seg[1]).grow(width * 0.5 + 1.0)
		reserved.append(Rect2i(rect))


func _site_zone(c: Vector3i, half: Vector2i, name: String, margin: float = 16.0, id: String = "") -> void:
	var rect := Rect2i(c.x - half.x, c.z - half.y, half.x * 2, half.y * 2)
	flatten_zones.append({"rect": rect, "height": float(c.y), "margin": margin})
	locations.append({"name": name, "rect": rect, "id": id})
	no_wildlife.append(rect.grow(30))


func _plan_roadside_inn(c: Vector3i) -> void:
	var fy := c.y + 1
	_site_zone(c, Vector2i(16, 17), "Posada del Lobo Gris", 16.0, "inn_lobo")
	sites.append({"id": "inn_lobo", "name": "Posada del Lobo Gris", "kind": "inn", "pos": Vector2(c.x, c.z)})
	paved.append({"rect": Rect2i(c.x - 6, c.z - 5, 13, 11), "block": B.COBBLE})
	reserved.append(Rect2i(c.x - 7, c.z - 6, 15, 13))
	var inn_o := Vector3i(c.x - 17, fy, c.z - 5)
	_add_structure({"id": "inn_lobo/inn", "type": "house", "origin": inn_o, "w": 11, "d": 9, "rot": 1,
			"floors": 2, "style": "timber", "roof": B.ROOF_STAIRS, "interior": "inn", "name": "Posada del Lobo Gris"})
	_add_structure({"id": "inn_lobo/stable", "type": "house", "origin": Vector3i(c.x - 3, fy, c.z - 15), "w": 7, "d": 6, "rot": 2,
			"floors": 1, "style": "timber", "roof": B.THATCH_STAIRS})
	_add_structure({"id": "inn_lobo/well", "type": "well", "origin": Vector3i(c.x + 2, fy, c.z + 1), "w": 3, "d": 3, "rot": 0, "margin": 2})
	_add_structure({"id": "inn_lobo/stall", "type": "stall", "origin": Vector3i(c.x - 1, fy, c.z + 8), "w": 3, "d": 2, "rot": 0,
			"goods": "food", "margin": 1})
	for p: Vector2i in [Vector2i(c.x - 7, c.z - 6), Vector2i(c.x + 7, c.z + 6), Vector2i(c.x + 7, c.z - 6)]:
		_add_structure({"id": "inn_lobo/lamp_%d_%d" % [p.x, p.y], "type": "lamp", "origin": Vector3i(p.x, fy, p.y),
				"w": 1, "d": 1, "rot": 0, "margin": 1})
	# Ulrico tras la barra (misma posición local que Berta en La Jarra del Roble)
	var bar := ChunkWriter.local_to_world(inn_o, 11, 9, 1, Vector3(5.5, 0, 7.5))
	spawns.append({"type": "npc", "npc": "ulrico", "id": "npc/ulrico", "pos": bar, "yaw": -90.0})
	spawns.append({"type": "notice_board", "id": "board/inn_lobo", "site": "inn_lobo", "pos": Vector3(c.x - 4.5, fy, c.z + 4.5), "yaw": -90.0})
	spawns.append({"type": "npc", "npc": "edda", "id": "npc/edda", "pos": Vector3(c.x + 4.5, fy, c.z - 2.5), "yaw": -90.0,
			"home": ChunkWriter.local_to_world(inn_o, 11, 9, 1, Vector3(3.5, 0, 3.5))})


func _plan_hamlet(c: Vector3i, rng: RandomNumberGenerator) -> void:
	var fy := c.y + 1
	_site_zone(c, Vector2i(20, 19), "Aldea de Robledal", 16.0, "robledal")
	sites.append({"id": "robledal", "name": "Aldea de Robledal", "kind": "village", "pos": Vector2(c.x, c.z)})
	paved.append({"rect": Rect2i(c.x - 5, c.z - 5, 11, 11), "block": B.PATH})
	reserved.append(Rect2i(c.x - 6, c.z - 6, 13, 13))
	_add_structure({"id": "robledal/well", "type": "well", "origin": Vector3i(c.x - 1, fy, c.z - 1), "w": 3, "d": 3, "rot": 0, "margin": 2})
	# Casas alrededor de la plaza, con la fachada hacia el centro
	var styles := ["timber", "stone", "brick", "timber"]
	var roofs := [B.THATCH_STAIRS, B.ROOF_STAIRS]
	var homes: Array[Vector3] = []
	var slots := [[Vector3i(c.x - 4, fy, c.z - 15), 2], [Vector3i(c.x + 7, fy, c.z - 4), 3], [Vector3i(c.x - 4, fy, c.z + 8), 0], [Vector3i(c.x - 15, fy, c.z - 4), 1]]
	for i in slots.size():
		var o: Vector3i = slots[i][0]
		var rot: int = slots[i][1]
		var w := 9 if i % 2 == 0 else 7
		var d := 7
		if rot % 2 == 1:
			o = Vector3i(o.x, o.y, o.z - (w - 7) / 2)
		var st := str(styles[(i + rng.randi()) % styles.size()])
		_add_structure({"id": "robledal/house_%d" % i, "type": "house", "origin": o, "w": w, "d": d, "rot": rot,
				"floors": 1 + (rng.randi() % 2), "style": st, "roof": roofs[rng.randi() % roofs.size()]})
		homes.append(ChunkWriter.local_to_world(o, w, d, rot, Vector3(w * 0.5, 0, 2.5)))
	_add_structure({"id": "robledal/field", "type": "field", "origin": Vector3i(c.x + 6, fy, c.z + 7), "w": 9, "d": 9, "rot": 0})
	for p: Vector2i in [Vector2i(c.x - 6, c.z - 6), Vector2i(c.x + 6, c.z + 6)]:
		_add_structure({"id": "robledal/lamp_%d_%d" % [p.x, p.y], "type": "lamp", "origin": Vector3i(p.x, fy, p.y),
				"w": 1, "d": 1, "rot": 0, "margin": 1})
	spawns.append({"type": "npc", "npc": "elena", "id": "npc/elena", "pos": Vector3(c.x + 2.5, fy, c.z - 3.5), "yaw": 180.0, "home": homes[0]})
	spawns.append({"type": "npc", "npc": "bram", "id": "npc/bram", "pos": Vector3(c.x - 2.5, fy, c.z + 2.5), "yaw": 0.0, "home": homes[2]})
	# Lina, la hija de Bram, solo está en casa después de que la rescaten
	spawns.append({"type": "npc", "npc": "lina", "id": "npc/lina", "pos": Vector3(c.x - 4.0, fy, c.z + 3.5), "yaw": 60.0, "home": homes[2],
			"requires_flag": "lina_rescued"})
	spawns.append({"type": "notice_board", "id": "board/robledal", "site": "robledal", "pos": Vector3(c.x + 4.0, fy, c.z + 3.5), "yaw": 90.0})


func _plan_barrow(c: Vector3i) -> void:
	var fy := c.y + 1
	_site_zone(c, Vector2i(10, 10), "Túmulo de los Reyes Grises", 12.0)
	sites.append({"id": "barrow_grises", "name": "Túmulo de los Reyes Grises", "kind": "dungeon", "pos": Vector2(c.x, c.z)})
	_add_structure({"id": "barrow_grises/mound", "type": "barrow", "origin": Vector3i(c.x - 7, fy, c.z - 7), "w": 15, "d": 15, "rot": 0,
			"dungeon": "barrow_grises", "margin": 2})
	# Guardianes en el exterior (esqueletos que salen de noche y de día)
	spawns.append({"id": "barrow_grises/out_0", "enemy": "skeleton_warrior", "pos": Vector3(c.x - 4.5, fy, c.z - 10.5), "yaw": 180.0,
			"patrol": [Vector3(c.x - 4.5, fy, c.z - 10.5), Vector3(c.x + 4.5, fy, c.z - 10.5)]})
	spawns.append({"id": "barrow_grises/out_1", "enemy": "skeleton_archer", "pos": Vector3(c.x + 6.5, fy, c.z - 9.5), "yaw": 200.0})


func _plan_wolf_den(c: Vector3i) -> void:
	var fy := c.y + 1
	_site_zone(c, Vector2i(7, 7), "Cubil de Colmillo Negro", 10.0)
	sites.append({"id": "cave_lobos", "name": "Cubil de Colmillo Negro", "kind": "dungeon", "pos": Vector2(c.x, c.z)})
	_add_structure({"id": "cave_lobos/mouth", "type": "cave_mouth", "origin": Vector3i(c.x - 6, fy, c.z - 6), "w": 13, "d": 13, "rot": 0,
			"dungeon": "cave_lobos", "margin": 2})
	no_wildlife.pop_back()   # junto al cubil sí hay lobos: la manada de guardia
	for i in 3:
		var a := TAU * i / 3.0
		spawns.append({"id": "cave_lobos/pack_%d" % i, "enemy": "wolf", "pos": Vector3(c.x + 0.5 + cos(a) * 3.0, fy, c.z - 10.5 + sin(a) * 2.0),
				"yaw": 180.0, "respawn_days": 3})


## Campamento de los Cuervos: en el bosque, entre la posada y Robledal, algo
## apartado de los caminos y unido a ellos por un sendero. Oculto en el mapa
## hasta que alguien te hable de él (bandera known_bandit_camp) o lo encuentres.
func _plan_bandit_camp(inn: Vector3i, ham: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(gen.world_seed * 4513 + 977)
	var mid := Vector2(inn.x, inn.z).lerp(Vector2(ham.x, ham.z), 0.5)
	var away := mid.normalized() if mid.length() > 1.0 else Vector2(-0.55, 0.83)
	var size := StructureBuilder.CAMP_SIZE
	var c := _find_site(rng, mid + away * 45.0, 50.0, Vector2i(size + 6, size + 6), true)
	var fy := c.y + 1
	# Punto más cercano de los caminos existentes (destino del sendero)
	var center := Vector2(c.x, c.z)
	var best := center + Vector2(0, -40)
	var best_d := INF
	for road: Dictionary in roads:
		var a: Vector2 = road["a"]
		var b: Vector2 = road["b"]
		var ab := b - a
		var t := clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		if q.distance_to(center) < best_d:
			best_d = q.distance_to(center)
			best = q
	# La entrada (z = 0 local) mira hacia el sendero
	var dir := best - center
	var rot := 0
	if absf(dir.x) > absf(dir.y):
		rot = 1 if dir.x > 0.0 else 3
	else:
		rot = 2 if dir.y > 0.0 else 0
	var half := size / 2
	var o := Vector3i(c.x - half, fy, c.z - half)
	_site_zone(c, Vector2i(half + 4, half + 4), "Campamento de los Cuervos", 10.0, "bandit_camp")
	sites.append({"id": "bandit_camp", "name": "Campamento de los Cuervos", "kind": "camp", "pos": center, "hidden": true})
	_add_structure({"id": "bandit_camp/camp", "type": "bandit_camp", "origin": o, "w": size, "d": size, "rot": rot,
			"margin": 2, "site": "bandit_camp"})
	var lw := func(lp: Vector3) -> Vector3: return ChunkWriter.local_to_world(o, size, size, rot, lp)
	var gate: Vector3 = lw.call(Vector3(12.5, 0, -2.0))
	_add_winding_road(Vector2(gate.x, gate.z), best, 1.5, rng)
	var yaw_off := -rot * 90.0
	# Los Cuervos: guardia de la puerta, matón junto al fuego, ronda interior,
	# arquera en la torre y el jefe Garra ante su tienda (lleva la llave)
	spawns.append({"id": "bandit_camp/gate", "enemy": "bandit", "pos": lw.call(Vector3(13.5, 0, 3.0)), "yaw": 180.0 + yaw_off,
			"patrol": [lw.call(Vector3(10.0, 0, 3.0)), lw.call(Vector3(14.5, 0, 3.0))]})
	spawns.append({"id": "bandit_camp/brute", "enemy": "bandit_brute", "pos": lw.call(Vector3(10.0, 0, 10.0)), "yaw": -135.0 + yaw_off})
	spawns.append({"id": "bandit_camp/round", "enemy": "bandit", "pos": lw.call(Vector3(7.5, 0, 14.5)), "yaw": 90.0 + yaw_off,
			"patrol": [lw.call(Vector3(7.5, 0, 14.5)), lw.call(Vector3(17.0, 0, 15.5)), lw.call(Vector3(13.0, 0, 7.5))]})
	spawns.append({"id": "bandit_camp/archer", "enemy": "bandit_archer", "pos": lw.call(Vector3(16.5, 4.0, 5.5)), "yaw": 180.0 + yaw_off,
			"hold": true})
	spawns.append({"id": "bandit_camp/chief", "enemy": "bandit_chief", "pos": lw.call(Vector3(12.5, 0, 15.0)), "yaw": 0.0 + yaw_off})
	# Lina, encerrada en la jaula; al quedar libre sale por la puerta del campamento
	var cage: Vector3 = StructureBuilder.CAMP_CAGE
	spawns.append({"type": "npc", "npc": "lina", "id": "npc/lina_cautiva", "pos": lw.call(cage), "yaw": -90.0 + yaw_off,
			"unless_flag": "lina_rescued",
			"captive": {"flag": "jaula_cuervos_abierta", "rescued_flag": "lina_rescued",
				"path": [lw.call(cage + Vector3(2.2, 0, 0.6)), lw.call(Vector3(11.5, 0, 4.0)), lw.call(Vector3(12.5, 0, -2.0)),
					lw.call(Vector3(12.5, 0, -9.0))]}})


## ¿Están los lugares ocultos ya descubiertos? (para mapa y leyenda)
static func site_known(site: Dictionary) -> bool:
	if not bool(site.get("hidden", false)):
		return true
	return GameState.has_flag("known_" + str(site.get("id", "")))


## ¿Puede aparecer fauna salvaje en esta columna? (lejos de aldeas y caminos)
func wildlife_allowed(x: int, z: int) -> bool:
	var p := Vector2i(x, z)
	for r: Rect2i in no_wildlife:
		if r.has_point(p):
			return false
	return not is_reserved(x, z)


## Texto de dirección y distancia aproximada de un lugar (para mapa y diálogos).
static func direction_text(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if d.length() < 25.0:
		return "aquí"
	var ang := fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)
	var names := ["norte", "nordeste", "este", "sudeste", "sur", "sudoeste", "oeste", "noroeste"]
	return "%d m al %s" % [int(round(d.length() / 10.0) * 10.0), names[int(round(ang / 45.0)) % 8]]


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


## Identificador del lugar (para objetivos «llegar a» y descubrimientos).
func location_id_at(x: float, z: float) -> String:
	var p := Vector2i(int(floor(x)), int(floor(z)))
	for loc: Dictionary in locations:
		var r: Rect2i = loc["rect"]
		if r.has_point(p):
			return str(loc.get("id", ""))
	return ""
