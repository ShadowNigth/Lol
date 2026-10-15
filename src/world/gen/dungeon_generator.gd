class_name DungeonGenerator
extends WorldSource
## Mazmorra procedural (cripta) en una cuadrícula de celdas unidas por un árbol
## de expansión con algunos bucles extra (atajos). Incluye sala de entrada con
## la salida, sala del jefe (la más profunda), salas de tesoro (callejones sin
## salida), una sala secreta tras una pared falsa, una puerta cerrada cuya llave
## está garantizadamente antes de la puerta, una reja accionada por palanca,
## trampas de pinchos detectables y verificación de conectividad.

const GRID := 5
const CELL := 11
const FLOOR_Y := 20
const ORIGIN := Vector2i(4, 4)
const B = preload("res://src/world/voxel/block_types.gd")

var dungeon_id: String
var seed_value: int
var difficulty: int = 1
var display_name: String = "Cripta de Velmar"
var rooms: Array[Dictionary] = []      # índice = celda.x + celda.y * GRID
var edges: Array[Dictionary] = []      # {a, b, kind}
var entities: Array[Dictionary] = []
var floor_tiles: Dictionary = {}       # Vector2i -> true (suelo transitable)
var corridor_tiles: Array[Vector2i] = []
var entrance_index: int = 0
var boss_index: int = 0
var bounds: Rect2i
var verified: bool = false
var _astar: AStarGrid2D
var _rng := RandomNumberGenerator.new()
var _theme: Dictionary = {}


func _init(id: String, world_seed: int, diff: int = 1) -> void:
	dungeon_id = id
	var def := DungeonDB.get_def(id)
	display_name = str(def.get("name", display_name))
	difficulty = maxi(diff, int(def.get("difficulty", 1)))
	_theme = DungeonDB.theme(id)
	for attempt in 6:
		seed_value = absi(hash("%s|%d|%d" % [id, world_seed, attempt]))
		_rng.seed = seed_value
		_generate()
		if _verify():
			verified = true
			break
		push_warning("Mazmorra %s: verificación fallida en el intento %d, se regenera." % [id, attempt])
	_build_astar()


func is_interior() -> bool:
	return true


func location_at(_x: float, _z: float) -> String:
	return display_name


func location_id_at(_x: float, _z: float) -> String:
	return ""


func biome_name(_x: int, _z: int) -> String:
	return "Mazmorra"


func height_at(_x: int, _z: int) -> int:
	return FLOOR_Y - 1


func spawn_point() -> Vector3:
	var r := rooms[entrance_index]
	var rect: Rect2i = r["rect"]
	return Vector3(rect.position.x + rect.size.x * 0.5, FLOOR_Y + 0.05, rect.position.y + rect.size.y - 1.5)


func spawn_yaw() -> float:
	return 0.0


# ---------------------------------------------------------------------------
# Planificación
# ---------------------------------------------------------------------------

func _cell_index(c: Vector2i) -> int:
	return c.x + c.y * GRID


func _cell_origin(c: Vector2i) -> Vector2i:
	return ORIGIN + c * CELL


func _generate() -> void:
	rooms.clear()
	edges.clear()
	entities.clear()
	floor_tiles.clear()
	corridor_tiles.clear()
	# 1) Árbol de expansión por DFS aleatorio
	var visited := {}
	var stack: Array[Vector2i] = []
	var start := Vector2i(GRID / 2, GRID - 1)
	entrance_index = _cell_index(start)
	stack.append(start)
	visited[start] = true
	var adjacency := {}
	for i in GRID * GRID:
		adjacency[i] = []
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cur + d
			if n.x >= 0 and n.y >= 0 and n.x < GRID and n.y < GRID and not visited.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[_rng.randi() % options.size()]
		visited[nxt] = true
		edges.append({"a": _cell_index(cur), "b": _cell_index(nxt), "kind": "open"})
		(adjacency[_cell_index(cur)] as Array).append(_cell_index(nxt))
		(adjacency[_cell_index(nxt)] as Array).append(_cell_index(cur))
		stack.append(nxt)
	# 2) Salas: tamaño variable dentro de cada celda
	for y in GRID:
		for x in GRID:
			var c := Vector2i(x, y)
			var o := _cell_origin(c)
			var junction := _rng.randf() < 0.25
			var w := 3 if junction else _rng.randi_range(5, 8)
			var d := 3 if junction else _rng.randi_range(5, 8)
			var rx := o.x + (CELL - w) / 2
			var rz := o.y + (CELL - d) / 2
			rooms.append({"cell": c, "rect": Rect2i(rx, rz, w, d), "role": "junction" if junction else "room",
					"height": 3 if junction else _rng.randi_range(4, 5), "depth": -1})
	# 3) Profundidad por BFS desde la entrada
	var queue: Array[int] = [entrance_index]
	rooms[entrance_index]["depth"] = 0
	while not queue.is_empty():
		var i: int = queue.pop_front()
		for j: int in adjacency[i]:
			if int(rooms[j]["depth"]) < 0:
				rooms[j]["depth"] = int(rooms[i]["depth"]) + 1
				queue.append(j)
	# 4) Funciones de las salas
	var leaves: Array[int] = []
	for i in rooms.size():
		if i != entrance_index and (adjacency[i] as Array).size() == 1:
			leaves.append(i)
	boss_index = leaves[0] if not leaves.is_empty() else (GRID * GRID - 1)
	for i in leaves:
		if int(rooms[i]["depth"]) > int(rooms[boss_index]["depth"]):
			boss_index = i
	_set_room(entrance_index, "entrance", 6, 6, 4)
	_set_room(boss_index, "boss", 9, 9, 6)
	var treasure: Array[int] = []
	for i in leaves:
		if i != boss_index:
			treasure.append(i)
			_set_room(i, "treasure", _rng.randi_range(5, 6), _rng.randi_range(5, 6), 4)
	var secret_index := -1
	if not treasure.is_empty():
		secret_index = treasure[_rng.randi() % treasure.size()]
		rooms[secret_index]["role"] = "secret"
		for e in edges:
			if int(e["a"]) == secret_index or int(e["b"]) == secret_index:
				e["kind"] = "secret"
	# 5) Bucles extra (atajos) entre celdas vecinas no unidas
	var tries := 0
	var added := 0
	while added < 3 and tries < 40:
		tries += 1
		var a := Vector2i(_rng.randi() % GRID, _rng.randi() % GRID)
		var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
		var b := a + dirs[_rng.randi() % 2]
		if b.x >= GRID or b.y >= GRID:
			continue
		var ia := _cell_index(a)
		var ib := _cell_index(b)
		if ia in [boss_index, secret_index] or ib in [boss_index, secret_index]:
			continue
		if (adjacency[ia] as Array).has(ib):
			continue
		edges.append({"a": ia, "b": ib, "kind": "open"})
		(adjacency[ia] as Array).append(ib)
		(adjacency[ib] as Array).append(ia)
		added += 1
	# 6) Puerta cerrada en la entrada a la sala del jefe; la llave, en la sala
	#    alcanzable más profunda sin cruzar esa puerta.
	for e in edges:
		if int(e["a"]) == boss_index or int(e["b"]) == boss_index:
			e["kind"] = "locked"
	var reachable := _reachable_from(entrance_index, ["locked", "gate"], adjacency)
	var key_room := entrance_index
	for i: int in reachable:
		if i != entrance_index and i != secret_index and int(rooms[i]["depth"]) >= int(rooms[key_room]["depth"]):
			key_room = i
	rooms[key_room]["has_key"] = true
	# 7) Reja con palanca en el camino hacia la llave (si hay una sala lateral)
	var gate_edge := -1
	for ei in edges.size():
		var e2: Dictionary = edges[ei]
		if str(e2["kind"]) != "open":
			continue
		var a2 := int(e2["a"])
		var b2 := int(e2["b"])
		if int(rooms[a2]["depth"]) >= 2 and int(rooms[b2]["depth"]) >= 2 and _rng.randf() < 0.5:
			gate_edge = ei
			break
	if gate_edge >= 0:
		edges[gate_edge]["kind"] = "gate"
		var before := _reachable_from(entrance_index, ["locked", "gate", "secret"], adjacency)
		var lever_room := entrance_index
		for i: int in before:
			if i != entrance_index and rooms[i]["role"] in ["room", "treasure", "junction"]:
				lever_room = i
		rooms[lever_room]["has_lever"] = true
		edges[gate_edge]["lever_room"] = lever_room
	_carve_and_populate()


func _set_room(i: int, role: String, w: int, d: int, h: int) -> void:
	var c: Vector2i = rooms[i]["cell"]
	var o := _cell_origin(c)
	rooms[i]["role"] = role
	rooms[i]["rect"] = Rect2i(o.x + (CELL - w) / 2, o.y + (CELL - d) / 2, w, d)
	rooms[i]["height"] = h


func _reachable_from(start: int, blocked_kinds: Array, adjacency: Dictionary) -> Array[int]:
	var seen := {start: true}
	var q: Array[int] = [start]
	var out: Array[int] = [start]
	while not q.is_empty():
		var i: int = q.pop_front()
		for j: int in adjacency[i]:
			if seen.has(j):
				continue
			var kind := _edge_kind(i, j)
			if kind in blocked_kinds:
				continue
			seen[j] = true
			q.append(j)
			out.append(j)
	return out


func _edge_kind(a: int, b: int) -> String:
	for e in edges:
		if (int(e["a"]) == a and int(e["b"]) == b) or (int(e["a"]) == b and int(e["b"]) == a):
			return str(e["kind"])
	return ""


# ---------------------------------------------------------------------------
# Excavación y contenido
# ---------------------------------------------------------------------------

func _carve_and_populate() -> void:
	var min_c := ORIGIN - Vector2i(2, 2)
	var max_c := ORIGIN + Vector2i(GRID * CELL + 2, GRID * CELL + 2)
	bounds = Rect2i(min_c, max_c - min_c)
	for r in rooms:
		var rect: Rect2i = r["rect"]
		for z in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				floor_tiles[Vector2i(x, z)] = true
	for e in edges:
		_carve_corridor(int(e["a"]), int(e["b"]), e)
	# Contenido de cada sala
	for i in rooms.size():
		_populate_room(i)
	# Trampas de pinchos en pasillos
	var traps := 0
	var candidates := corridor_tiles.duplicate()
	candidates.shuffle()
	for t: Vector2i in candidates:
		if traps >= 3 + difficulty:
			break
		if _rng.randf() < 0.5:
			continue
		entities.append({"type": "spike_trap", "pos": Vector3(t.x + 0.5, FLOOR_Y, t.y + 0.5), "yaw": 0.0,
				"id": "%s/trap_%d_%d" % [dungeon_id, t.x, t.y]})
		traps += 1


## Pasillo recto en "L" entre los centros de dos salas vecinas, de 2 de ancho.
func _carve_corridor(a: int, b: int, e: Dictionary) -> void:
	var ra: Rect2i = rooms[a]["rect"]
	var rb: Rect2i = rooms[b]["rect"]
	var ca := ra.get_center()
	var cb := rb.get_center()
	var kind := str(e["kind"])
	var tiles: Array[Vector2i] = []
	if ca.y == cb.y or absi(ca.x - cb.x) > absi(ca.y - cb.y):
		# Horizontal
		var z := (ca.y + cb.y) / 2
		for x in range(mini(ca.x, cb.x), maxi(ca.x, cb.x) + 1):
			tiles.append(Vector2i(x, z))
			tiles.append(Vector2i(x, z + 1))
	else:
		var x2 := (ca.x + cb.x) / 2
		for z2 in range(mini(ca.y, cb.y), maxi(ca.y, cb.y) + 1):
			tiles.append(Vector2i(x2, z2))
			tiles.append(Vector2i(x2 + 1, z2))
	# El punto medio del pasillo fuera de las salas es la "puerta"
	var outside: Array[Vector2i] = []
	for t in tiles:
		if not floor_tiles.has(t):
			outside.append(t)
		floor_tiles[t] = true
	for t in outside:
		corridor_tiles.append(t)
	if outside.is_empty():
		return
	# Elegir el umbral junto a la sala b (o la a) para la puerta/reja/pared falsa
	var door_tiles: Array[Vector2i] = []
	var near_b := rb.grow(1)
	for t in outside:
		if near_b.has_point(t):
			door_tiles.append(t)
	if door_tiles.is_empty():
		door_tiles = [outside[0]]
		if outside.size() > 1:
			door_tiles.append(outside[1])
	var center := Vector2.ZERO
	for t in door_tiles:
		center += Vector2(t) + Vector2(0.5, 0.5)
	center /= door_tiles.size()
	var horizontal := door_tiles.size() > 1 and door_tiles[0].x == door_tiles[1].x
	var yaw := 0.0 if horizontal else 90.0
	var pos := Vector3(center.x, FLOOR_Y, center.y)
	var id := "%s/edge_%d_%d" % [dungeon_id, mini(a, b), maxi(a, b)]
	match kind:
		"locked":
			entities.append({"type": "dungeon_gate", "pos": pos, "yaw": yaw, "id": id, "locked_key": "key_" + dungeon_id,
					"style": "door"})
		"gate":
			entities.append({"type": "dungeon_gate", "pos": pos, "yaw": yaw, "id": id, "lever": id, "style": "portcullis"})
			e["gate_id"] = id
		"secret":
			entities.append({"type": "secret_wall", "pos": pos, "yaw": yaw, "id": id})


func _populate_room(i: int) -> void:
	var r := rooms[i]
	var rect: Rect2i = r["rect"]
	var role := str(r["role"])
	var center := Vector3(rect.position.x + rect.size.x * 0.5, FLOOR_Y, rect.position.y + rect.size.y * 0.5)
	var rid := "%s/room_%d" % [dungeon_id, i]
	var def := DungeonDB.get_def(dungeon_id)
	var guards := str(def.get("guards", "skeleton_warrior"))
	var minions: Array = def.get("minions", ["skeleton_warrior"])
	# Braseros en esquinas (salas medianas o grandes)
	if role != "junction" and rect.size.x >= 5:
		for corner: Vector2i in [rect.position, Vector2i(rect.end.x - 1, rect.end.y - 1)]:
			entities.append({"type": "brazier", "pos": Vector3(corner.x + 0.5, FLOOR_Y, corner.y + 0.5), "id": rid + "/brazier_%d" % corner.x})
	match role:
		"entrance":
			entities.append({"type": "dungeon_exit", "pos": Vector3(center.x, FLOOR_Y, rect.end.y - 0.6), "yaw": 180.0, "id": rid + "/exit"})
		"boss":
			entities.append({"type": "enemy", "enemy": str(def.get("boss", "skeleton_lord")), "pos": center + Vector3(0, 0, -1.5), "yaw": 180.0, "id": rid + "/boss"})
			entities.append({"type": "enemy", "enemy": guards, "pos": center + Vector3(-2.5, 0, 1.0), "yaw": 180.0, "id": rid + "/guard_0"})
			entities.append({"type": "enemy", "enemy": guards, "pos": center + Vector3(2.5, 0, 1.0), "yaw": 180.0, "id": rid + "/guard_1"})
			entities.append({"type": "chest", "pos": Vector3(center.x, FLOOR_Y, rect.position.y + 1.0), "yaw": 180.0, "id": rid + "/chest",
					"loot": str(def.get("boss_loot", "boss"))})
			for px: int in [rect.position.x + 1, rect.end.x - 2]:
				for pz: int in [rect.position.y + 2, rect.end.y - 3]:
					entities.append({"type": "pillar", "pos": Vector3(px + 0.5, FLOOR_Y, pz + 0.5), "id": rid + "/pillar_%d_%d" % [px, pz]})
		"treasure":
			# La mitad de los cofres tienen cerradura (decidido por hash: no altera la secuencia aleatoria)
			var lock := (20 + difficulty * 10) if absi(hash(rid)) % 2 == 0 else 0
			entities.append({"type": "chest", "pos": center, "yaw": float(_rng.randi() % 4) * 90.0, "id": rid + "/chest", "loot": "dungeon", "lock": lock})
			entities.append({"type": "enemy", "enemy": guards, "pos": center + Vector3(1.2, 0, 1.2), "yaw": 0.0, "id": rid + "/e0"})
		"secret":
			entities.append({"type": "chest", "pos": center, "yaw": 0.0, "id": rid + "/chest", "loot": "secret", "lock": 45 + difficulty * 5})
		"room":
			var n := _rng.randi_range(0, int(def.get("max_per_room", 1 + difficulty)))
			for k in n:
				var off := Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
				var kind := str(minions[minions.size() - 1]) if _rng.randf() < float(def.get("ranged_chance", 0.25)) else str(minions[0])
				entities.append({"type": "enemy", "enemy": kind, "pos": center + off, "yaw": _rng.randf() * 360.0, "id": rid + "/e%d" % k})
			if _rng.randf() < 0.5 and bool(_theme.get("sarcophagi", true)):
				entities.append({"type": "sarcophagus", "pos": center + Vector3(0, 0, -1.0), "yaw": 90.0 * (_rng.randi() % 2), "id": rid + "/sarc"})
			if _rng.randf() < 0.6:
				entities.append({"type": "bones", "pos": center + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), "yaw": _rng.randf() * 360.0, "id": rid + "/bones"})
	if bool(r.get("has_key", false)):
		entities.append({"type": "key_pickup", "pos": center + Vector3(0, 0.9, 0.6), "id": rid + "/key", "item": "key_" + dungeon_id})
	if bool(r.get("has_lever", false)):
		var lever_id := ""
		for e in edges:
			if str(e["kind"]) == "gate":
				lever_id = str(e.get("gate_id", ""))
		var wall_pos := Vector3(rect.position.x + 0.15, FLOOR_Y + 1.1, rect.position.y + rect.size.y * 0.5)
		entities.append({"type": "lever", "pos": wall_pos, "yaw": -90.0, "id": rid + "/lever", "target": lever_id})


# ---------------------------------------------------------------------------
# Verificación de conectividad (a nivel de casillas transitables)
# ---------------------------------------------------------------------------

func _verify() -> bool:
	# Todas las salas deben ser alcanzables por el suelo desde la entrada.
	var start: Vector2i = (rooms[entrance_index]["rect"] as Rect2i).get_center()
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var t: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := t + d
			if floor_tiles.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	for r in rooms:
		var c: Vector2i = (r["rect"] as Rect2i).get_center()
		if not seen.has(c):
			return false
	# La llave no puede quedar detrás de su propia puerta (comprobado al planificar).
	return true


func _build_astar() -> void:
	_astar = AStarGrid2D.new()
	_astar.region = bounds
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for z in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			_astar.set_point_solid(Vector2i(x, z), not floor_tiles.has(Vector2i(x, z)))


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if _astar == null:
		return out
	var a := Vector2i(int(floor(from.x)), int(floor(from.z)))
	var b := Vector2i(int(floor(to.x)), int(floor(to.z)))
	if not bounds.has_point(a) or not bounds.has_point(b) or _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return out
	var pts := _astar.get_id_path(a, b)
	for p in pts:
		out.append(Vector3(p.x + 0.5, FLOOR_Y, p.y + 0.5))
	return out


# ---------------------------------------------------------------------------
# Generación de chunks (vóxeles)
# ---------------------------------------------------------------------------

func generate_chunk(cx: int, cz: int) -> ChunkData:
	var data := ChunkData.new(cx, cz)
	var x0 := cx * ChunkData.SIZE - 1
	var z0 := cz * ChunkData.SIZE - 1
	var chunk_rect := Rect2i(x0, z0, ChunkData.PAD, ChunkData.PAD)
	if not chunk_rect.intersects(bounds):
		return data
	var blocks := data.blocks
	var layer := ChunkData.LAYER
	var pad := ChunkData.PAD
	var y_min := FLOOR_Y - 3
	var y_max := FLOOR_Y + 8
	var wall_a := int(_theme.get("wall", B.DUNGEON_BRICK))
	var wall_b := int(_theme.get("wall_alt", B.STONE))
	var floor_a := int(_theme.get("floor", B.DUNGEON_FLOOR))
	var floor_b := int(_theme.get("floor_alt", B.MOSS_STONE))
	var webs := bool(_theme.get("cobwebs", true))
	for pz in pad:
		for px in pad:
			var wx := x0 + px
			var wz := z0 + pz
			if not bounds.has_point(Vector2i(wx, wz)):
				continue
			var col := px + pz * pad
			for y in range(y_min, y_max + 1):
				var h := WorldGenerator.hash2(wx * 7 + y, wz, 4242)
				blocks[col + y * layer] = wall_a if h % 9 != 0 else wall_b
			var t := Vector2i(wx, wz)
			if floor_tiles.has(t):
				var ceil_h := _ceiling_height(t)
				if str(DungeonDB.get_def(dungeon_id).get("theme", "")) == "cave":
					ceil_h = maxi(3, ceil_h + WorldGenerator.hash2(wx, wz, 99) % 3 - 1)   # techo irregular de roca
				var floor_id := floor_a if WorldGenerator.hash2(wx, wz, 77) % 11 != 0 else floor_b
				blocks[col + (FLOOR_Y - 1) * layer] = floor_id
				for y2 in range(FLOOR_Y, FLOOR_Y + ceil_h):
					blocks[col + y2 * layer] = B.AIR
				# Telarañas en las esquinas altas
				if webs and ceil_h >= 4 and _is_corner(t) and WorldGenerator.hash2(wx, wz, 13) % 3 == 0:
					blocks[col + (FLOOR_Y + ceil_h - 1) * layer] = B.COBWEB
	data.blocks = blocks
	data.max_y = y_max
	# Entidades del chunk (solo las de su zona interior)
	for e in entities:
		var p: Vector3 = e["pos"]
		if data.contains_world_core(int(floor(p.x)), int(floor(p.z))):
			data.entities.append(e)
	return data


func _ceiling_height(t: Vector2i) -> int:
	for r in rooms:
		if (r["rect"] as Rect2i).has_point(t):
			return int(r["height"])
	return 3


func _is_corner(t: Vector2i) -> bool:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not floor_tiles.has(t + d):
			n += 1
	return n >= 2
