class_name WorldGenerator
extends WorldSource
## Generador determinista del terreno a partir de una semilla: relieve,
## biomas, ríos, vegetación y estampado de estructuras planificadas.
## Es de solo lectura tras construirse, por lo que puede usarse desde hilos.

enum Biome { PLAINS, FOREST, BIRCH_FOREST, TAIGA, SNOW, SWAMP, DESERT, ROCKY, BEACH, OCEAN, RIVER }

const SEA_LEVEL := 30
const BIOME_NAMES := ["Llanura", "Bosque templado", "Bosque de abedules", "Taiga", "Montañas nevadas",
		"Pantano", "Desierto", "Tierras rocosas", "Costa", "Lago", "Río"]

var world_seed: int
var planner: StructurePlanner

var _continent := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _mountain_mask := FastNoiseLite.new()
var _temperature := FastNoiseLite.new()
var _moisture := FastNoiseLite.new()
var _river := FastNoiseLite.new()
var _flowers := FastNoiseLite.new()


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_setup(_continent, 11, 0.0016, 4)
	_setup(_hills, 23, 0.0075, 3)
	_setup(_detail, 37, 0.045, 2)
	_setup(_ridge, 41, 0.0055, 4)
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_setup(_mountain_mask, 53, 0.0019, 2)
	_setup(_temperature, 67, 0.0011, 2)
	_setup(_moisture, 71, 0.0014, 2)
	_setup(_river, 83, 0.0011, 3)
	_setup(_flowers, 97, 0.06, 1)
	planner = StructurePlanner.new(self)


func _setup(n: FastNoiseLite, offset: int, freq: float, octaves: int) -> void:
	n.seed = world_seed + offset * 1013
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves


## Factor 0..1 que suaviza el relieve cerca del punto de inicio.
static func spawn_calm(x: float, z: float) -> float:
	var dist := sqrt(x * x + z * z)
	return clampf((dist - 90.0) / 140.0, 0.0, 1.0)


## Altura natural (sin estructuras) en metros.
func raw_height(x: float, z: float) -> float:
	var calm := spawn_calm(x, z)
	var c := _continent.get_noise_2d(x, z)
	var base := SEA_LEVEL + 7.0 + c * 16.0 * lerpf(0.35, 1.0, calm)
	var hills := _hills.get_noise_2d(x, z) * lerpf(5.0, 9.0, calm)
	var detail := _detail.get_noise_2d(x, z) * 1.6
	var mask := smoothstep(0.12, 0.5, _mountain_mask.get_noise_2d(x, z)) * calm
	var ridge := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var mountains := mask * ridge * ridge * 62.0
	var h := base + hills + detail + mountains
	# Ríos: cauces estrechos donde el ruido cruza el cero.
	var r := absf(_river.get_noise_2d(x, z))
	var river_w := 0.03 * calm
	if r < river_w and h < SEA_LEVEL + 30.0:
		var t := 1.0 - r / river_w
		h = lerpf(h, SEA_LEVEL - 3.0, smoothstep(0.0, 1.0, t * 1.4))
	return h


func height_at(x: int, z: int) -> int:
	var h := raw_height(x, z)
	h = planner.apply_flatten(x, z, h)
	return int(round(h))


func climate(x: float, z: float) -> Vector2:
	var calm := spawn_calm(x, z)
	var t := _temperature.get_noise_2d(x, z) * 1.6
	var m := _moisture.get_noise_2d(x, z) * 1.6
	# Zona inicial: templada y algo húmeda (bosque/llanura).
	t = lerpf(0.05, t, calm)
	m = lerpf(0.15, m, calm)
	return Vector2(t, m)


func biome_at(x: int, z: int, h: int) -> int:
	if h < SEA_LEVEL - 1:
		return Biome.OCEAN
	var r := absf(_river.get_noise_2d(x, z))
	if r < 0.03 * spawn_calm(x, z) and h <= SEA_LEVEL:
		return Biome.RIVER
	if h <= SEA_LEVEL + 1:
		return Biome.BEACH
	if h > 82:
		return Biome.SNOW
	var cl := climate(x, z)
	var t := cl.x
	var m := cl.y
	if t < -0.38:
		return Biome.SNOW if h > 58 else Biome.TAIGA
	if t > 0.38 and m < -0.05:
		return Biome.DESERT
	if m > 0.4 and h < SEA_LEVEL + 7:
		return Biome.SWAMP
	if m < -0.38 and t > 0.05:
		return Biome.ROCKY
	if m > 0.12:
		return Biome.BIRCH_FOREST if t < -0.12 else Biome.FOREST
	return Biome.PLAINS


func biome_name(x: int, z: int) -> String:
	return BIOME_NAMES[biome_at(x, z, height_at(x, z))]


func location_at(x: float, z: float) -> String:
	return planner.location_at(x, z)


func spawn_point() -> Vector3:
	return planner.spawn_point


func spawn_yaw() -> float:
	return planner.spawn_yaw_deg


static func biome_tint(biome: int) -> Color:
	match biome:
		Biome.FOREST:
			return Color(0.9, 1.0, 0.85)
		Biome.BIRCH_FOREST:
			return Color(1.0, 1.04, 0.85)
		Biome.TAIGA:
			return Color(0.78, 0.92, 0.88)
		Biome.SNOW:
			return Color(0.8, 0.9, 0.9)
		Biome.SWAMP:
			return Color(0.72, 0.78, 0.5)
		Biome.DESERT, Biome.ROCKY:
			return Color(1.05, 0.95, 0.65)
		Biome.BEACH:
			return Color(1.0, 1.0, 0.8)
	return Color(1.0, 1.0, 0.92)


static func hash2(x: int, z: int, salt: int) -> int:
	var h := (x * 374761393 + z * 668265263 + salt * 2147483647) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	return (h ^ (h >> 16)) & 0x7fffffff


static func hashf(x: int, z: int, salt: int) -> float:
	return float(hash2(x, z, salt) % 100000) / 100000.0


# ---------------------------------------------------------------------------
# Generación de chunks
# ---------------------------------------------------------------------------

func generate_chunk(cx: int, cz: int) -> ChunkData:
	var data := ChunkData.new(cx, cz)
	var x0 := cx * ChunkData.SIZE - 1
	var z0 := cz * ChunkData.SIZE - 1
	var pad := ChunkData.PAD
	var layer := ChunkData.LAYER
	var blocks := data.blocks
	var heights := PackedInt32Array()
	heights.resize(pad * pad)
	var biomes := PackedByteArray()
	biomes.resize(pad * pad)
	var max_y := 1

	for pz in pad:
		for px in pad:
			var wx := x0 + px
			var wz := z0 + pz
			var h := clampi(height_at(wx, wz), 2, ChunkData.HEIGHT - 20)
			var biome := biome_at(wx, wz, h)
			var col := px + pz * pad
			heights[col] = h
			biomes[col] = biome
			data.tints[col] = biome_tint(biome)
			var surface := BlockTypes.GRASS
			var sub := BlockTypes.DIRT
			var sub_depth := 3
			match biome:
				Biome.DESERT:
					surface = BlockTypes.SAND
					sub = BlockTypes.SANDSTONE
					sub_depth = 4
				Biome.BEACH, Biome.OCEAN, Biome.RIVER:
					surface = BlockTypes.SAND if h >= SEA_LEVEL - 2 else BlockTypes.GRAVEL
					sub = BlockTypes.SAND
				Biome.SNOW:
					surface = BlockTypes.SNOW if h < 95 else BlockTypes.SNOW
					sub = BlockTypes.STONE if h > 88 else BlockTypes.DIRT
				Biome.ROCKY:
					surface = BlockTypes.GRAVEL if hash2(wx, wz, 5) % 3 == 0 else BlockTypes.STONE
					sub = BlockTypes.STONE
				Biome.SWAMP:
					surface = BlockTypes.MUD if hash2(wx, wz, 6) % 4 == 0 else BlockTypes.GRASS
				Biome.TAIGA:
					surface = BlockTypes.SNOW if h > 50 and hash2(wx, wz, 7) % 3 != 0 else BlockTypes.GRASS
			# Pendientes fuertes en montaña: roca desnuda.
			if h > 64 and biome != Biome.SNOW:
				surface = BlockTypes.STONE
			var road := planner.surface_override(wx, wz)
			if road > 0:
				surface = road
			var base := col
			blocks[base] = BlockTypes.BEDROCK
			var stone_top := h - sub_depth
			for y in range(1, h + 1):
				var id: int
				if y == h:
					id = surface
				elif y > stone_top:
					id = sub
				else:
					id = BlockTypes.STONE
				blocks[base + y * layer] = id
			if h < SEA_LEVEL:
				for y in range(h + 1, SEA_LEVEL + 1):
					blocks[base + y * layer] = BlockTypes.WATER
				max_y = maxi(max_y, SEA_LEVEL)
			max_y = maxi(max_y, h)
	# Los Packed*Array se copian al escribir: hay que devolver el array al chunk.
	data.blocks = blocks
	data.max_y = max_y

	for lz in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			data.biome_ids[lx + lz * ChunkData.SIZE] = biomes[(lx + 1) + (lz + 1) * pad]

	_decorate(data, heights, biomes)
	planner.stamp_structures(data)
	planner.add_spawns(data, heights)
	_add_wildlife(data, cx, cz, heights, biomes)
	return data


# ---------------------------------------------------------------------------
# Fauna salvaje (manadas de lobos) — determinista por semilla y chunk
# ---------------------------------------------------------------------------

func _add_wildlife(data: ChunkData, cx: int, cz: int, heights: PackedInt32Array, biomes: PackedByteArray) -> void:
	var pad := ChunkData.PAD
	var mid := (ChunkData.SIZE / 2 + 1) + (ChunkData.SIZE / 2 + 1) * pad
	var biome := int(biomes[mid])
	var chance := 0.0
	match biome:
		Biome.FOREST, Biome.BIRCH_FOREST:
			chance = 0.045
		Biome.TAIGA, Biome.SNOW:
			chance = 0.05
		Biome.PLAINS, Biome.ROCKY:
			chance = 0.015
	if chance <= 0.0 or hashf(cx, cz, world_seed % 100000 + 777) > chance:
		return
	var wx0 := cx * ChunkData.SIZE
	var wz0 := cz * ChunkData.SIZE
	if not planner.wildlife_allowed(wx0 + 8, wz0 + 8):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wolves|%d|%d|%d" % [world_seed, cx, cz])
	var count := rng.randi_range(2, 3)
	var cold := biome in [Biome.TAIGA, Biome.SNOW]
	for i in count:
		var lx := rng.randi_range(3, ChunkData.SIZE - 4)
		var lz := rng.randi_range(3, ChunkData.SIZE - 4)
		var h := heights[(lx + 1) + (lz + 1) * pad]
		if h <= SEA_LEVEL + 1 or not planner.wildlife_allowed(wx0 + lx, wz0 + lz):
			continue
		var pos := Vector3(wx0 + lx + 0.5, h + 1, wz0 + lz + 0.5)
		# Merodean entre unos pocos puntos cercanos
		var patrol: Array[Vector3] = [pos]
		for k in 2:
			var px := clampi(lx + rng.randi_range(-6, 6), 1, ChunkData.SIZE - 2)
			var pz := clampi(lz + rng.randi_range(-6, 6), 1, ChunkData.SIZE - 2)
			var ph := heights[(px + 1) + (pz + 1) * pad]
			if ph > SEA_LEVEL + 1 and absi(ph - h) <= 2:
				patrol.append(Vector3(wx0 + px + 0.5, ph + 1, wz0 + pz + 0.5))
		data.entities.append({"type": "enemy", "enemy": "wolf", "id": "wild/wolf_%d_%d_%d" % [cx, cz, i], "pos": pos,
				"yaw": rng.randf() * 360.0, "variant": 2 if cold else -1, "respawn_days": 3, "patrol": patrol})


# ---------------------------------------------------------------------------
# Vegetación
# ---------------------------------------------------------------------------

const CELL := 4

func _tree_density(biome: int) -> float:
	match biome:
		Biome.FOREST:
			return 0.62
		Biome.BIRCH_FOREST:
			return 0.55
		Biome.TAIGA:
			return 0.5
		Biome.SNOW:
			return 0.12
		Biome.SWAMP:
			return 0.22
		Biome.PLAINS:
			return 0.07
		Biome.ROCKY:
			return 0.04
		Biome.DESERT:
			return 0.03
	return 0.0


func _decorate(data: ChunkData, heights: PackedInt32Array, biomes: PackedByteArray) -> void:
	var x0 := data.origin_x()
	var z0 := data.origin_z()
	var wr := ChunkWriter.new(data)
	# Árboles y rocas por celdas (incluye celdas vecinas cuyas copas invaden el chunk).
	var c_min_x := int(floor(float(x0 - 6) / CELL))
	var c_max_x := int(floor(float(x0 + ChunkData.SIZE + 6) / CELL))
	var c_min_z := int(floor(float(z0 - 6) / CELL))
	var c_max_z := int(floor(float(z0 + ChunkData.SIZE + 6) / CELL))
	for gz in range(c_min_z, c_max_z + 1):
		for gx in range(c_min_x, c_max_x + 1):
			var hsh := hash2(gx, gz, 101)
			var tx := gx * CELL + hsh % CELL
			var tz := gz * CELL + (hsh / CELL) % CELL
			var h := height_at(tx, tz)
			if h <= SEA_LEVEL:
				continue
			if planner.is_reserved(tx, tz):
				continue
			var biome := biome_at(tx, tz, h)
			var roll := hashf(gx, gz, 202)
			var density := _tree_density(biome)
			if roll < density:
				_place_tree(wr, tx, h + 1, tz, biome, hash2(gx, gz, 303))
			elif roll > 0.985 and biome != Biome.DESERT:
				_place_boulder(wr, tx, h, tz, hash2(gx, gz, 404))

	# Plantas pequeñas sobre la superficie interior.
	var pad := ChunkData.PAD
	for lz in ChunkData.SIZE:
		for lx in ChunkData.SIZE:
			var col := (lx + 1) + (lz + 1) * pad
			var h := heights[col]
			var wx := x0 + lx
			var wz := z0 + lz
			if h <= SEA_LEVEL or h >= ChunkData.HEIGHT - 3:
				continue
			var top := data.blocks[col + h * ChunkData.LAYER]
			if data.blocks[col + (h + 1) * ChunkData.LAYER] != 0:
				continue
			if planner.is_reserved(wx, wz):
				continue
			var biome := int(biomes[col])
			var r := hashf(wx, wz, 505)
			var plant := 0
			if top == BlockTypes.GRASS:
				var flower_patch := _flowers.get_noise_2d(wx, wz)
				match biome:
					Biome.PLAINS:
						if r < 0.22:
							plant = BlockTypes.TALL_GRASS
						elif r < 0.26 and flower_patch > 0.2:
							plant = [BlockTypes.FLOWER_RED, BlockTypes.FLOWER_YELLOW, BlockTypes.FLOWER_BLUE][hash2(wx, wz, 9) % 3]
						elif r < 0.27:
							plant = BlockTypes.BUSH
					Biome.FOREST, Biome.BIRCH_FOREST:
						if r < 0.2:
							plant = BlockTypes.TALL_GRASS
						elif r < 0.24:
							plant = BlockTypes.BUSH
						elif r < 0.25:
							plant = BlockTypes.MUSHROOM
						elif r < 0.27 and flower_patch > 0.3:
							plant = BlockTypes.FLOWER_YELLOW
					Biome.TAIGA:
						if r < 0.1:
							plant = BlockTypes.TALL_GRASS
						elif r < 0.12:
							plant = BlockTypes.MUSHROOM
					Biome.SWAMP:
						if r < 0.25:
							plant = BlockTypes.TALL_GRASS
						elif r < 0.3:
							plant = BlockTypes.REEDS
			elif top == BlockTypes.SAND and biome == Biome.DESERT:
				if r < 0.02:
					plant = BlockTypes.DEAD_BUSH
			elif top == BlockTypes.SAND and h == SEA_LEVEL + 1 and r < 0.15:
				plant = BlockTypes.REEDS
			elif top == BlockTypes.GRAVEL and r < 0.03:
				plant = BlockTypes.DEAD_BUSH
			if plant != 0:
				data.blocks[col + (h + 1) * ChunkData.LAYER] = plant
				data.max_y = maxi(data.max_y, h + 1)


func _place_tree(wr: ChunkWriter, x: int, y: int, z: int, biome: int, hsh: int) -> void:
	match biome:
		Biome.TAIGA, Biome.SNOW:
			_spruce(wr, x, y, z, hsh)
		Biome.BIRCH_FOREST:
			if hsh % 4 == 0:
				_oak(wr, x, y, z, hsh)
			else:
				_birch(wr, x, y, z, hsh)
		Biome.FOREST:
			if hsh % 5 == 0:
				_birch(wr, x, y, z, hsh)
			elif hsh % 7 == 0:
				_big_oak(wr, x, y, z, hsh)
			else:
				_oak(wr, x, y, z, hsh)
		Biome.SWAMP, Biome.ROCKY, Biome.DESERT:
			if hsh % 3 == 0 and biome == Biome.SWAMP:
				_oak(wr, x, y, z, hsh)
			else:
				_dead_tree(wr, x, y, z, hsh)
		_:
			if hsh % 6 == 0:
				_big_oak(wr, x, y, z, hsh)
			else:
				_oak(wr, x, y, z, hsh)


func _leaf(wr: ChunkWriter, x: int, y: int, z: int, id: int) -> void:
	if wr.in_bounds_world(x, z) and wr.get_world(x, y, z) == 0:
		wr.put_world(x, y, z, id)


func _oak(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var trunk := 4 + hsh % 3
	for k in trunk:
		wr.put_world(x, y + k, z, BlockTypes.LOG)
	var top := y + trunk
	for dy in range(-2, 2):
		var r := 2 if dy < 0 else 1
		if dy == -2:
			r = 2
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) == r and absi(dz) == r and (hash2(x + dx, z + dz, y + dy) % 3 != 0 or dy >= 0):
					continue
				_leaf(wr, x + dx, top + dy, z + dz, BlockTypes.LEAVES)
	_leaf(wr, x, top + 1, z, BlockTypes.LEAVES)


func _big_oak(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var trunk := 6 + hsh % 3
	for k in trunk:
		wr.put_world(x, y + k, z, BlockTypes.LOG)
	# Raíces
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if hash2(x + d.x, z + d.y, 77) % 2 == 0:
			wr.put_world(x + d.x, y, z + d.y, BlockTypes.LOG)
	var top := y + trunk
	for dy in range(-3, 2):
		var r := 3 if dy <= -1 else 2
		if dy == 1:
			r = 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var dist := dx * dx + dz * dz
				if dist > r * r + 1:
					continue
				if dist >= r * r and hash2(x + dx, z + dz, y + dy * 3) % 3 == 0:
					continue
				_leaf(wr, x + dx, top + dy, z + dz, BlockTypes.LEAVES)
	# Ramas
	for k in 2:
		var dir := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][(hsh >> (k * 2)) % 4] as Vector2i
		wr.put_world(x + dir.x, top - 2 - k, z + dir.y, BlockTypes.LOG)
		wr.put_world(x + dir.x * 2, top - 1 - k, z + dir.y * 2, BlockTypes.LOG)


func _birch(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var trunk := 5 + hsh % 3
	for k in trunk:
		wr.put_world(x, y + k, z, BlockTypes.BIRCH_LOG)
	var top := y + trunk
	for dy in range(-2, 2):
		var r := 1 if dy >= 0 else 2
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) == r and absi(dz) == r:
					continue
				_leaf(wr, x + dx, top + dy, z + dz, BlockTypes.BIRCH_LEAVES)
	_leaf(wr, x, top + 1, z, BlockTypes.BIRCH_LEAVES)


func _spruce(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var trunk := 7 + hsh % 4
	for k in trunk:
		wr.put_world(x, y + k, z, BlockTypes.SPRUCE_LOG)
	var top := y + trunk
	var r := 0
	for k in range(trunk - 2, -1, -1):
		var ly := y + 2 + (trunk - 2 - k)
		r = 1 + (trunk - 2 - k) / 2
		if k % 2 == 0:
			r = maxi(r - 1, 1)
		r = mini(r, 3)
		var level := top - (ly - y)
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx == 0 and dz == 0:
					continue
				if absi(dx) + absi(dz) > r + 1:
					continue
				_leaf(wr, x + dx, level, z + dz, BlockTypes.SPRUCE_LEAVES)
	_leaf(wr, x, top, z, BlockTypes.SPRUCE_LEAVES)
	_leaf(wr, x, top + 1, z, BlockTypes.SPRUCE_LEAVES)


func _dead_tree(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var trunk := 3 + hsh % 3
	for k in trunk:
		wr.put_world(x, y + k, z, BlockTypes.SPRUCE_LOG)
	var d1 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][hsh % 4] as Vector2i
	wr.put_world(x + d1.x, y + trunk - 1, z + d1.y, BlockTypes.SPRUCE_LOG)
	wr.put_world(x + d1.x * 2, y + trunk, z + d1.y * 2, BlockTypes.SPRUCE_LOG)
	var d2 := Vector2i(-d1.y, d1.x)
	wr.put_world(x + d2.x, y + trunk - 2, z + d2.y, BlockTypes.SPRUCE_LOG)


func _place_boulder(wr: ChunkWriter, x: int, y: int, z: int, hsh: int) -> void:
	var size := 1 + hsh % 2
	for dz in range(0, size + 1):
		for dx in range(0, size + 1):
			var hh := 1 if (dx + dz) > size else 2
			for dy in hh:
				var id := BlockTypes.MOSS_STONE if hash2(x + dx, z + dz, dy) % 3 == 0 else BlockTypes.COBBLE
				wr.put_world(x + dx, y + dy, z + dz, id)
