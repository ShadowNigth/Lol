class_name StructureBuilder
extends RefCounted
## Construcciones voxel paramétricas (casas con entramado, torre, murallas,
## pozo, herrería, ruinas, cementerio...). Todas trabajan en un marco local
## (ChunkWriter.frame) donde y = 0 es el nivel del suelo interior y la
## fachada principal está en z = 0 (mirando hacia -Z local).

const B = preload("res://src/world/voxel/block_types.gd")


static func build(wr: ChunkWriter, s: Dictionary) -> void:
	var size := ChunkWriter.footprint(int(s["w"]), int(s["d"]), int(s.get("rot", 0)))
	wr.frame(s["origin"], int(s["w"]), int(s["d"]), int(s.get("rot", 0)), str(s.get("id", "")))
	match str(s["type"]):
		"house":
			house(wr, s)
		"tower":
			tower(wr, s)
		"wall":
			wall(wr, s)
		"well":
			well(wr, s)
		"stall":
			stall(wr, s)
		"smithy":
			smithy(wr, s)
		"chapel_ruin":
			chapel_ruin(wr, s)
		"graveyard":
			graveyard(wr, s)
		"field":
			field(wr, s)
		"lamp":
			lamp_post(wr, s)
		"barrow":
			barrow(wr, s)
		"cave_mouth":
			cave_mouth(wr, s)
		_:
			push_warning("Estructura desconocida: %s" % s["type"])
	var _unused := size


static func _rng(s: Dictionary) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(s.get("seed", 1))
	return r


## Variación de material determinista por posición (para muros menos repetitivos).
static func _vary(wr: ChunkWriter, lx: int, ly: int, lz: int, base: int, alt: int, chance_pct: int) -> int:
	var p := wr.to_world_xz(lx, lz)
	if WorldGenerator.hash2(p.x * 31 + ly, p.y, 911) % 100 < chance_pct:
		return alt
	return base


# ---------------------------------------------------------------------------
# Casa con entramado de madera (1-2 plantas, tejado a dos aguas, chimenea)
# ---------------------------------------------------------------------------

static func house(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	var floors := int(s.get("floors", 1))
	var style := str(s.get("style", "timber"))
	var roof := int(s.get("roof", B.ROOF_STAIRS))
	var roof_full := B.THATCH if roof == B.THATCH_STAIRS else B.ROOF_TILE
	var wall_h := 4
	var top := floors * wall_h
	var ground_wall := B.PLASTER
	var upper_wall := B.PLASTER
	var post := B.LOG
	var beam := B.TIMBER
	var floor_block := B.PLANKS
	match style:
		"stone":
			ground_wall = B.COBBLE
		"brick":
			ground_wall = B.STONE_BRICK
			upper_wall = B.STONE_BRICK
			post = B.STONE_BRICK
			beam = B.DARK_PLANKS
		"rustic":
			ground_wall = B.PLANKS
			upper_wall = B.PLANKS
			post = B.LOG
			beam = B.LOG
			floor_block = B.DARK_PLANKS

	# Despeja el volumen y crea cimientos y suelo.
	wr.clear(-1, 0, -1, w, top + d / 2 + 2, d)
	for lz in d:
		for lx in w:
			wr.foundation(lx, -2, lz, B.COBBLE, 10)
			var edge := lx == 0 or lz == 0 or lx == w - 1 or lz == d - 1
			wr.put(lx, -1, lz, B.COBBLE if edge else floor_block)

	# Muros
	for f in floors:
		var y0 := f * wall_h
		var mat := ground_wall if f == 0 else upper_wall
		for ly in range(y0, y0 + wall_h):
			var is_beam := ly == y0 + wall_h - 1
			for lx in w:
				for lz: int in [0, d - 1]:
					wr.put(lx, ly, lz, _wall_block(wr, lx, ly, lz, w, d, is_beam, mat, post, beam, style, f))
			for lz in range(1, d - 1):
				for lx: int in [0, w - 1]:
					wr.put(lx, ly, lz, _wall_block(wr, lx, ly, lz, w, d, is_beam, mat, post, beam, style, f))
		# Forjado del piso superior
		if f > 0:
			wr.fill(1, y0 - 1, 1, w - 2, y0 - 1, d - 2, floor_block)

	# Escalera interior a lo largo del muro trasero
	if floors > 1:
		for k in wall_h:
			wr.put(1 + k, k, d - 2, B.stairs(B.PLANK_STAIRS, 1))
			if k < wall_h - 1:
				wr.put(1 + k, wall_h - 1, d - 2, B.AIR)
				# hueco de la escalera más ancho para no golpearse la cabeza
				wr.put(1 + k, wall_h - 1, d - 3, B.AIR if k < 2 else floor_block)

	# Ventanas
	var door_x := w / 2
	for f in floors:
		var wy := f * wall_h + 1
		for lx in range(2, w - 2):
			if lx % 3 == 2 or (w <= 7 and lx == door_x + 2):
				if not (f == 0 and absi(lx - door_x) <= 0):
					wr.put(lx, wy, 0, B.GLASS)
					if f > 0:
						wr.put(lx, wy + 1, 0, B.GLASS)
				wr.put(lx, wy, d - 1, B.GLASS)
		if d >= 5:
			var zc := d / 2
			wr.put(0, wy, zc, B.GLASS)
			wr.put(w - 1, wy, zc, B.GLASS)

	# Puerta
	wr.clear(door_x, 0, 0, door_x, 1, 0)
	wr.put(door_x, 2, 0, beam)
	wr.put(door_x, -1, -1, B.COBBLE)
	wr.entity("door", Vector3(door_x + 0.5, 0.0, 0.5), 0.0, {"uid": "door"})
	wr.entity("wall_lantern", Vector3(door_x + 1.5, 2.2, -0.12), 0.0, {"uid": "lantern"})

	# Tejado a dos aguas (cumbrera a lo largo de x local)
	var gable_mat := upper_wall if style != "stone" else B.PLASTER
	if style == "brick":
		gable_mat = B.STONE_BRICK
	_gable_roof(wr, w, d, top, roof, roof_full, gable_mat, beam)

	# Chimenea integrada en el hastial derecho
	if bool(s.get("chimney", true)):
		var zc := d / 2 + 1 if d / 2 + 1 < d - 1 else d / 2
		var chim_top := top + d / 2 + 2
		for ly in range(-1, chim_top):
			wr.put(w, ly, zc, _vary(wr, w, ly, zc, B.COBBLE, B.STONE_BRICK, 25))
		wr.put(w, chim_top, zc, B.BRICK_SLAB)
		wr.entity("smoke", Vector3(w + 0.5, chim_top + 0.6, zc + 0.5), 0.0, {"uid": "smoke"})

	_furnish(wr, s, w, d, floors, wall_h)


static func _wall_block(wr: ChunkWriter, lx: int, ly: int, lz: int, w: int, d: int, is_beam: bool,
		mat: int, post: int, beam: int, style: String, storey: int) -> int:
	var corner := (lx == 0 or lx == w - 1) and (lz == 0 or lz == d - 1)
	if corner:
		return post
	if is_beam:
		return beam
	var along := lx if (lz == 0 or lz == d - 1) else lz
	if (style == "timber" or (style == "stone" and storey > 0)) and along % 3 == 0:
		return beam
	if mat == B.COBBLE:
		return _vary(wr, lx, ly, lz, B.COBBLE, B.MOSS_STONE if ly == 0 else B.STONE_BRICK, 12)
	if mat == B.PLASTER and ly % 4 == 0:
		return _vary(wr, lx, ly, lz, B.PLASTER, B.TIMBER, 8)
	return mat


static func _gable_roof(wr: ChunkWriter, w: int, d: int, top: int, stairs_base: int, full: int,
		gable_mat: int, beam: int) -> void:
	var k := 0
	while k < 32:
		var zf := k - 1
		var zb := d - k
		var y := top - 1 + k
		if zf > zb:
			break
		for lx in range(-1, w + 1):
			if zf == zb:
				wr.put(lx, y, zf, full)
			else:
				wr.put(lx, y, zf, B.stairs(stairs_base, 2))
				wr.put(lx, y, zb, B.stairs(stairs_base, 0))
		if k >= 1:
			for lz in range(zf + 1, zb):
				var m := gable_mat
				if lz == (d - 1) / 2 or (lz == d / 2 and d % 2 == 0):
					m = beam
				wr.put(0, y, lz, m)
				wr.put(w - 1, y, lz, m)
		if zf == zb or zf + 1 == zb:
			break
		k += 1


static func _furnish(wr: ChunkWriter, s: Dictionary, w: int, d: int, floors: int, wall_h: int) -> void:
	var interior := str(s.get("interior", "home"))
	match interior:
		"inn":
			# Barra del tabernero
			for lx in range(2, w - 3):
				wr.put(lx, 0, d - 3, B.DARK_PLANKS)
			wr.put(w - 3, 0, d - 3, B.PLANK_STAIRS + 2)
			wr.entity("barrel", Vector3(1.5, 0, d - 1.6), 0.0, {"uid": "b1"})
			wr.entity("barrel", Vector3(2.6, 0, d - 1.6), 0.0, {"uid": "b2"})
			wr.entity("table", Vector3(2.5, 0, 2.5), 0.0, {"uid": "t1"})
			wr.entity("chair", Vector3(1.6, 0, 2.5), 90.0, {"uid": "c1"})
			wr.entity("chair", Vector3(3.4, 0, 2.5), -90.0, {"uid": "c2"})
			wr.entity("table", Vector3(w - 3.0, 0, 2.5), 0.0, {"uid": "t2"})
			wr.entity("chair", Vector3(w - 3.0, 0, 1.6), 180.0, {"uid": "c3"})
			wr.entity("chair", Vector3(w - 3.0, 0, 3.4), 0.0, {"uid": "c4"})
			wr.entity("lantern", Vector3(w / 2.0, wall_h - 1.05, d / 2.0), 0.0, {"uid": "l1"})
			wr.entity("sign", Vector3(w / 2.0 + 0.5 + 1.6, 2.6, -0.55), 0.0, {"uid": "sign", "text": str(s.get("name", "Posada"))})
			if floors > 1:
				wr.entity("bed", Vector3(w - 2.5, wall_h, 1.5), 0.0, {"uid": "bed1"})
				wr.entity("bed", Vector3(w - 4.5, wall_h, 1.5), 0.0, {"uid": "bed2"})
				wr.entity("chest", Vector3(w - 2.5, wall_h, d - 2.5), 180.0, {"uid": "chest", "loot": "inn"})
				wr.entity("lantern", Vector3(w / 2.0, wall_h * 2 - 1.05, d / 2.0), 0.0, {"uid": "l2"})
		"smith":
			pass
		_:
			wr.entity("table", Vector3(w - 2.5, 0, 2.0), 0.0, {"uid": "t1"})
			wr.entity("chair", Vector3(w - 2.5, 0, 1.1), 180.0, {"uid": "c1"})
			wr.entity("barrel", Vector3(1.5, 0, 1.5), 0.0, {"uid": "b1"})
			wr.entity("crate", Vector3(1.5, 0, 2.5), 15.0, {"uid": "cr1"})
			wr.put(w - 2, 0, d - 2, B.BOOKSHELF)
			wr.put(w - 2, 1, d - 2, B.BOOKSHELF)
			wr.entity("lantern", Vector3(w / 2.0, wall_h - 1.05, d / 2.0), 0.0, {"uid": "l1"})
			if floors > 1:
				wr.entity("bed", Vector3(w - 2.5, wall_h, 1.5), 0.0, {"uid": "bed"})
				wr.entity("chest", Vector3(w - 2.5, wall_h, 3.2), 90.0, {"uid": "chest", "loot": "home"})
			else:
				wr.entity("bed", Vector3(1.5, 0, d - 2.5), 90.0, {"uid": "bed"})
				wr.entity("chest", Vector3(w - 2.5, 0, d - 3.4), 180.0, {"uid": "chest", "loot": "home"})
			# Alfombra
			for lz in range(2, d - 2):
				for lx in range(2, w - 2):
					if (lx + lz) % 7 != 0:
						wr.put(lx, -1, lz, B.WOOL_RED if (lx > 2 and lx < w - 3 and lz > 2 and lz < d - 3) else wr.get_local(lx, -1, lz))


# ---------------------------------------------------------------------------
# Torre de vigilancia con escalera de caracol y almenas
# ---------------------------------------------------------------------------

static func tower(wr: ChunkWriter, s: Dictionary) -> void:
	var h := int(s.get("height", 12))
	var size := 5
	wr.clear(0, 0, 0, size - 1, h + 3, size - 1)
	for lz in size:
		for lx in size:
			wr.foundation(lx, -1, lz, B.STONE_BRICK, 12)
			wr.put(lx, -1, lz, B.COBBLE)
	for ly in range(0, h):
		for lz in size:
			for lx in size:
				var edge := lx == 0 or lz == 0 or lx == size - 1 or lz == size - 1
				if not edge:
					continue
				var corner := (lx == 0 or lx == size - 1) and (lz == 0 or lz == size - 1)
				var id := B.STONE_BRICK
				if corner:
					id = B.CHISELED if ly % 4 == 3 else B.STONE_BRICK
				elif ly < 3:
					id = _vary(wr, lx, ly, lz, B.STONE_BRICK, B.MOSSY_BRICK, 35)
				else:
					id = _vary(wr, lx, ly, lz, B.STONE_BRICK, B.CRACKED_BRICK, 10)
				wr.put(lx, ly, lz, id)
		wr.put(2, ly, 2, B.STONE_BRICK)
	# Saeteras
	for ly: int in [4, 5, 8, 9]:
		wr.put(2, ly, size - 1, B.AIR)
		wr.put(0, ly, 2, B.AIR)
		wr.put(size - 1, ly, 2, B.AIR)
	# Escalera de caracol alrededor del pilar central
	var path := [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1)]
	var step := 0
	for ly in range(0, h):
		var cur: Vector2i = path[step % 8]
		var nxt: Vector2i = path[(step + 1) % 8]
		var dir := nxt - cur
		var facing := 0
		if dir.x > 0:
			facing = 1
		elif dir.x < 0:
			facing = 3
		elif dir.y > 0:
			facing = 2
		wr.put(cur.x, ly, cur.y, B.stairs(B.BRICK_STAIRS, facing))
		step += 1
	# Plataforma superior (con hueco sobre los últimos peldaños)
	var last := (h - 1) % 8
	for i in 8:
		var p: Vector2i = path[i]
		var dist_back := posmod(last - i, 8)
		if dist_back <= 2:
			continue
		wr.put(p.x, h - 1, p.y, B.PLANKS)
	wr.put(2, h - 1, 2, B.PLANKS)
	# Almenas
	for lz in size:
		for lx in size:
			var edge2 := lx == 0 or lz == 0 or lx == size - 1 or lz == size - 1
			if edge2:
				wr.put(lx, h, lz, B.STONE_BRICK)
				if (lx + lz) % 2 == 0:
					wr.put(lx, h + 1, lz, B.STONE_BRICK)
	wr.put(0, h + 2, 0, B.TORCH)
	wr.put(size - 1, h + 2, size - 1, B.TORCH)
	# Puerta
	wr.clear(2, 0, 0, 2, 1, 0)
	wr.entity("door", Vector3(2.5, 0.0, 0.5), 0.0, {"uid": "door"})
	wr.entity("banner", Vector3(2.5, 3.4, -0.08), 0.0, {"uid": "banner"})


# ---------------------------------------------------------------------------
# Muralla con almenas y puerta
# ---------------------------------------------------------------------------

static func wall(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var h := int(s.get("height", 5))
	var gate_from := int(s.get("gate_from", -100))
	var gate_to := int(s.get("gate_to", -100))
	for lx in w:
		var in_gate := lx >= gate_from and lx <= gate_to
		for lz in 2:
			wr.foundation(lx, -1, lz, B.COBBLE, 10)
			for ly in range(0, h):
				if in_gate and ly < h - 1:
					wr.put(lx, ly, lz, B.AIR)
					continue
				var id := _vary(wr, lx, ly, lz, B.STONE_BRICK, B.MOSSY_BRICK if ly < 2 else B.CRACKED_BRICK, 18)
				wr.put(lx, ly, lz, id)
		# Almenas solo en el lado exterior (z = 0)
		if lx % 2 == 0:
			wr.put(lx, h, 0, B.STONE_BRICK)
		if in_gate:
			wr.put(lx, h - 1, 0, B.BRICK_SLAB_TOP)
			wr.put(lx, h - 1, 1, B.BRICK_SLAB_TOP)
	if gate_from >= 0:
		for lz in 2:
			wr.put(gate_from - 1, h, lz, B.STONE_BRICK)
			wr.put(gate_to + 1, h, lz, B.STONE_BRICK)
		wr.put(gate_from - 1, h + 1, 1, B.TORCH)
		wr.put(gate_to + 1, h + 1, 1, B.TORCH)
	# Escalera de acceso al adarve en un extremo (cara interior)
	for k in h:
		wr.put(w - 1 - k, k, 2, B.stairs(B.COBBLE_STAIRS, 3))
		wr.foundation(w - 1 - k, k - 1, 2, B.COBBLE, 8)


# ---------------------------------------------------------------------------
# Pozo de la plaza
# ---------------------------------------------------------------------------

static func well(wr: ChunkWriter, s: Dictionary) -> void:
	wr.clear(-1, 0, -1, 3, 5, 3)
	for lz in 3:
		for lx in 3:
			wr.put(lx, -1, lz, B.COBBLE)
			wr.put(lx, -2, lz, B.COBBLE)
			wr.put(lx, -3, lz, B.COBBLE)
	wr.put(1, -1, 1, B.WATER)
	wr.put(1, -2, 1, B.WATER)
	wr.ring(0, 0, 2, 2, 0, B.COBBLE)
	wr.put(1, 0, 1, B.AIR)
	wr.put(0, 1, 1, B.FENCE)
	wr.put(2, 1, 1, B.FENCE)
	wr.put(0, 2, 1, B.FENCE)
	wr.put(2, 2, 1, B.FENCE)
	for lx in range(-1, 4):
		wr.put(lx, 3, 0, B.stairs(B.ROOF_STAIRS, 2))
		wr.put(lx, 3, 2, B.stairs(B.ROOF_STAIRS, 0))
		wr.put(lx, 3, 1, B.ROOF_TILE)
	wr.entity("bucket", Vector3(1.5, 1.2, 1.5), 0.0, {"uid": "bucket"})


# ---------------------------------------------------------------------------
# Puesto de mercado
# ---------------------------------------------------------------------------

static func stall(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	for ly in 3:
		wr.put(0, ly, 0, B.FENCE)
		wr.put(w - 1, ly, 0, B.FENCE)
		wr.put(0, ly, d - 1, B.FENCE)
		wr.put(w - 1, ly, d - 1, B.FENCE)
	for lx in w:
		for lz in d:
			wr.put(lx, 3, lz, B.WOOL_RED if (lx % 2 == 0) else B.PLANK_SLAB)
	for lx in range(0, w):
		wr.put(lx, 0, 0, B.PLANK_SLAB_TOP if lx > 0 and lx < w - 1 else B.FENCE)
	wr.entity("crate", Vector3(1.0, 0, d - 0.8), 10.0, {"uid": "c1"})
	wr.entity("barrel", Vector3(w - 1.4, 0, d - 0.9), 0.0, {"uid": "b1"})
	wr.entity("goods", Vector3(w / 2.0, 0.5, 0.5), 0.0, {"uid": "g1", "kind": str(s.get("goods", "food"))})


# ---------------------------------------------------------------------------
# Herrería (cobertizo abierto con fragua, yunque y chimenea)
# ---------------------------------------------------------------------------

static func smithy(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	wr.clear(-1, 0, -1, w, 9, d)
	for lz in d:
		for lx in w:
			wr.foundation(lx, -2, lz, B.COBBLE, 10)
			wr.put(lx, -1, lz, B.COBBLE if (lx + lz) % 5 else B.GRAVEL)
	# Tejado a un agua: bajo en la fachada abierta, alto junto al muro trasero.
	for lz in range(-1, d + 1):
		var k := lz + 1
		var y := 4 + k / 2
		for lx in range(-1, w + 1):
			wr.put(lx, y, lz, B.ROOF_SLAB if k % 2 == 0 else B.stairs(B.ROOF_STAIRS, 2))
	# Muros laterales y trasero de piedra hasta el tejado; postes en la fachada.
	for lz in range(0, d):
		var roof_y := 4 + (lz + 1) / 2
		for ly in range(0, roof_y):
			if lz == 0:
				if ly < 4:
					wr.put(0, ly, 0, B.LOG)
					wr.put(w - 1, ly, 0, B.LOG)
				continue
			var mat := _vary(wr, 0, ly, lz, B.COBBLE, B.STONE_BRICK, 20)
			wr.put(0, ly, lz, mat)
			wr.put(w - 1, ly, lz, _vary(wr, w - 1, ly, lz, B.COBBLE, B.MOSS_STONE if ly == 0 else B.STONE_BRICK, 20))
			if lz == d - 1:
				for lx in range(1, w - 1):
					wr.put(lx, ly, lz, _vary(wr, lx, ly, lz, B.COBBLE, B.STONE_BRICK, 20))
	# Ventana lateral
	wr.put(0, 2, d / 2, B.AIR)
	# Fragua con chimenea
	wr.fill(w - 3, 0, d - 3, w - 2, 0, d - 2, B.COBBLE)
	wr.fill(w - 3, 1, d - 2, w - 2, 1, d - 2, B.STONE_BRICK)
	for ly in range(1, 11):
		wr.put(w - 2, ly, d - 1, B.STONE_BRICK)
		wr.put(w - 3, ly, d - 1, B.STONE_BRICK if ly < 4 or ly > 7 else B.COBBLE)
	wr.entity("forge_fire", Vector3(w - 2.0, 1.05, d - 2.6), 0.0, {"uid": "fire"})
	wr.entity("smoke", Vector3(w - 2.0, 11.4, d - 0.5), 0.0, {"uid": "smoke"})
	wr.entity("anvil", Vector3(w / 2.0, 0, d / 2.0 - 0.3), 90.0, {"uid": "anvil"})
	wr.entity("barrel", Vector3(1.6, 0, d - 1.8), 0.0, {"uid": "water"})
	wr.entity("weapon_rack", Vector3(w / 2.0 - 1.0, 0, d - 1.35), 0.0, {"uid": "rack"})
	wr.entity("crate", Vector3(1.4, 0, 1.3), 30.0, {"uid": "crate"})
	wr.entity("lantern", Vector3(w / 2.0, 3.6, d / 2.0), 0.0, {"uid": "lantern"})


# ---------------------------------------------------------------------------
# Ruinas de capilla con entrada a la cripta
# ---------------------------------------------------------------------------

static func chapel_ruin(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	for lz in d:
		for lx in w:
			wr.foundation(lx, -2, lz, B.COBBLE, 8)
			var floor_id := B.COBBLE if WorldGenerator.hash2(lx, lz, int(s.get("seed", 3))) % 4 else B.MOSS_STONE
			if WorldGenerator.hash2(lx * 7, lz, 5) % 9 == 0:
				floor_id = B.GRASS
			wr.put(lx, -1, lz, floor_id)
	wr.clear(0, 0, 0, w - 1, 9, d - 1)
	# Muros derruidos: altura variable según ruido determinista
	for lx in w:
		for lz in d:
			var edge := lx == 0 or lz == 0 or lx == w - 1 or lz == d - 1
			if not edge:
				continue
			var p := wr.to_world_xz(lx, lz)
			var hh := 1 + WorldGenerator.hash2(p.x / 2, p.y / 2, 77) % 6
			if (lx == 0 or lx == w - 1) and (lz == 0 or lz == d - 1):
				hh = 6 + WorldGenerator.hash2(p.x, p.y, 13) % 3
			if lz == 0 and absi(lx - w / 2) <= 1:
				hh = 0 if absi(lx - w / 2) == 0 else 5
			for ly in hh:
				var id := _vary(wr, lx, ly, lz, B.MOSSY_BRICK, B.CRACKED_BRICK, 40)
				if ly == 0:
					id = _vary(wr, lx, ly, lz, B.MOSSY_BRICK, B.MOSS_STONE, 30)
				wr.put(lx, ly, lz, id)
			# Ventanales góticos (huecos)
			if (lz == 0 or lz == d - 1) and lx % 3 == 1 and hh >= 4:
				wr.put(lx, 2, lz, B.AIR)
				wr.put(lx, 3, lz, B.AIR)
	# Columnas interiores rotas
	for lx in range(2, w - 2, 3):
		for lz: int in [2, d - 3]:
			var p2 := wr.to_world_xz(lx, lz)
			var ch := 1 + WorldGenerator.hash2(p2.x, p2.y, 19) % 5
			for ly in ch:
				wr.put(lx, ly, lz, B.CHISELED if ly == 0 else B.STONE_BRICK)
	# Escombros
	var r := _rng(s)
	for i in 14:
		var lx2 := r.randi_range(1, w - 2)
		var lz2 := r.randi_range(1, d - 2)
		wr.put(lx2, 0, lz2, [B.COBBLE_SLAB, B.MOSSY_BRICK, B.BRICK_SLAB, B.COBBLE][r.randi() % 4])
	# Altar y entrada a la cripta al fondo
	var ax := w / 2
	wr.fill(ax - 1, 0, d - 3, ax + 1, 0, d - 3, B.CHISELED)
	wr.put(ax, 1, d - 3, B.BRICK_SLAB)
	wr.put(ax - 1, 1, d - 3, B.TORCH)
	wr.put(ax + 1, 1, d - 3, B.TORCH)
	# Escalera que baja hacia la cripta (bajo el suelo, delante del altar)
	for k in 4:
		var lz3 := d - 5 - k
		wr.put(ax, -1 - k, lz3, B.stairs(B.BRICK_STAIRS, 2))
		wr.put(ax - 1, -1 - k, lz3, B.STONE_BRICK)
		wr.put(ax + 1, -1 - k, lz3, B.STONE_BRICK)
		for ly in range(-k, 1):
			wr.put(ax, ly, lz3, B.AIR)
	# Rellano inferior con la puerta sellada de la cripta
	var bottom_y := -5
	wr.fill(ax - 1, bottom_y, d - 10, ax + 1, bottom_y, d - 9, B.DUNGEON_FLOOR)
	wr.clear(ax, bottom_y + 1, d - 10, ax, bottom_y + 3, d - 9)
	wr.fill(ax - 1, bottom_y + 1, d - 11, ax + 1, bottom_y + 4, d - 11, B.DUNGEON_BRICK)
	for ly in range(bottom_y + 1, bottom_y + 4):
		wr.put(ax - 1, ly, d - 10, B.DUNGEON_BRICK)
		wr.put(ax + 1, ly, d - 10, B.DUNGEON_BRICK)
		wr.put(ax - 1, ly, d - 9, B.DUNGEON_BRICK)
		wr.put(ax + 1, ly, d - 9, B.DUNGEON_BRICK)
	wr.fill(ax - 1, bottom_y + 4, d - 11, ax + 1, bottom_y + 4, d - 9, B.DUNGEON_BRICK)
	wr.entity("dungeon_entrance", Vector3(ax + 0.5, bottom_y + 1, d - 10.0 + 0.35), 0.0,
			{"uid": "crypt_door", "dungeon": str(s.get("dungeon", "crypt_east"))})
	wr.entity("chest", Vector3(ax - 2.5, 0, d - 2.5), 180.0, {"uid": "altar_chest", "loot": "ruins"})


# ---------------------------------------------------------------------------
# Cementerio
# ---------------------------------------------------------------------------

static func graveyard(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	for lx in w:
		for lz in d:
			var edge := lx == 0 or lz == 0 or lx == w - 1 or lz == d - 1
			wr.foundation(lx, -1, lz, B.DIRT, 6)
			wr.put(lx, -1, lz, B.GRASS if WorldGenerator.hash2(lx, lz, 4) % 5 else B.MUD)
			wr.clear(lx, 0, lz, lx, 4, lz)
			if edge:
				var gate := lz == 0 and absi(lx - w / 2) <= 1
				if not gate:
					wr.put(lx, 0, lz, B.FENCE)
	# Tumbas en filas
	for row in range(2, d - 2, 3):
		for lx in range(2, w - 2, 2):
			var p := wr.to_world_xz(lx, row)
			var hsh := WorldGenerator.hash2(p.x, p.y, 61)
			if hsh % 5 == 0:
				continue
			match hsh % 3:
				0:
					wr.put(lx, 0, row, B.CHISELED)
					wr.put(lx, 1, row, B.BRICK_SLAB)
				1:
					wr.put(lx, 0, row, B.MOSSY_BRICK)
				_:
					wr.put(lx, 0, row, B.CRACKED_BRICK)
					wr.put(lx, 1, row, B.COBBLE_SLAB)
			wr.put(lx, -1, row + 1, B.MUD)
	wr.put(w / 2 - 2, 0, 0, B.FENCE)
	wr.put(w / 2 - 2, 1, 0, B.TORCH)
	wr.put(w / 2 + 2, 0, 0, B.FENCE)
	wr.put(w / 2 + 2, 1, 0, B.TORCH)


# ---------------------------------------------------------------------------
# Huerto vallado con trigo
# ---------------------------------------------------------------------------

static func field(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	for lx in w:
		for lz in d:
			var edge := lx == 0 or lz == 0 or lx == w - 1 or lz == d - 1
			wr.foundation(lx, -1, lz, B.DIRT, 6)
			wr.clear(lx, 0, lz, lx, 3, lz)
			if edge:
				wr.put(lx, -1, lz, B.GRASS)
				if not (lz == 0 and lx == w / 2):
					wr.put(lx, 0, lz, B.FENCE)
			else:
				var water_row := lz == d / 2
				wr.put(lx, -1, lz, B.WATER if water_row else B.DIRT)
				if not water_row:
					wr.put(lx, 0, lz, B.CROP)
	wr.put(0, 1, 0, B.TORCH)
	wr.entity("hay_cart", Vector3(w + 1.5, 0, 1.5), 90.0, {"uid": "cart"})


static func lamp_post(wr: ChunkWriter, _s: Dictionary) -> void:
	wr.put(0, -1, 0, B.COBBLE)
	wr.put(0, 0, 0, B.COBBLE)
	wr.put(0, 1, 0, B.FENCE)
	wr.put(0, 2, 0, B.FENCE)
	wr.put(0, 3, 0, B.TORCH)


# ---------------------------------------------------------------------------
# Fase 6: túmulo funerario y boca de cueva (entradas a mazmorras)
# ---------------------------------------------------------------------------

## Túmulo: montículo de tierra y hierba con un corredor de piedra (dolmen) que
## lleva a la puerta de la mazmorra, y un círculo de piedras erguidas.
static func barrow(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	var cx := (w - 1) / 2.0
	var cz := (d - 1) / 2.0 + 1.0
	var rad := minf(w, d) * 0.5 - 1.0
	var height := 5.0
	for lz in d:
		for lx in w:
			var r := Vector2(lx - cx, lz - cz).length()
			if r > rad:
				continue
			var top := int(round(height * sqrt(maxf(1.0 - (r / rad) * (r / rad), 0.0))))
			for ly in range(0, top + 1):
				wr.put(lx, ly, lz, B.DIRT)
			wr.put(lx, top, lz, B.GRASS if WorldGenerator.hash2(lx, lz, 3) % 5 != 0 else B.MOSS_STONE)
			wr.foundation(lx, -1, lz, B.DIRT, 6)
	# Corredor de entrada (frente en z = 0): muros y dintel de piedra musgosa
	var ax := int(cx)
	var door_z := int(cz) - 1
	for lz2 in range(0, door_z + 1):
		for ly2 in range(0, 4):
			wr.put(ax - 2, ly2, lz2, _vary(wr, ax - 2, ly2, lz2, B.MOSSY_BRICK, B.COBBLE, 30))
			wr.put(ax + 2, ly2, lz2, _vary(wr, ax + 2, ly2, lz2, B.MOSSY_BRICK, B.COBBLE, 30))
		wr.fill(ax - 1, 0, lz2, ax + 1, 2, lz2, B.AIR)
		wr.put(ax - 1, -1, lz2, B.COBBLE)
		wr.put(ax, -1, lz2, B.GRAVEL)
		wr.put(ax + 1, -1, lz2, B.COBBLE)
		wr.fill(ax - 2, 3, lz2, ax + 2, 3, lz2, B.CHISELED if lz2 == 0 else B.MOSSY_BRICK)
	wr.fill(ax - 2, 0, door_z + 1, ax + 2, 3, door_z + 1, B.MOSSY_BRICK)
	wr.put(ax - 2, 4, 0, B.COBBLE_SLAB)
	wr.put(ax + 2, 4, 0, B.COBBLE_SLAB)
	wr.put(ax - 1, 2, 1, B.TORCH)
	wr.put(ax + 1, 2, 1, B.TORCH)
	wr.entity("dungeon_entrance", Vector3(ax + 0.5, 0, door_z + 0.9), 0.0, {"uid": "door", "dungeon": str(s.get("dungeon", "barrow_grises"))})
	# Piedras erguidas alrededor
	var r2 := _rng(s)
	for i in 7:
		var ang := PI * 0.15 + i * PI * 1.7 / 6.0
		var px := int(round(cx + sin(ang) * (rad + 0.5)))
		var pz := int(round(cz + cos(ang) * (rad + 0.5)))
		if px < 0 or pz < 0 or px >= w or pz >= d or pz <= 1:
			continue
		var hgt := r2.randi_range(2, 3)
		for ly3 in hgt:
			wr.put(px, ly3, pz, B.STONE if ly3 < hgt - 1 else B.MOSS_STONE)


## Boca de cueva: un risco de roca con un túnel que se adentra en la oscuridad.
static func cave_mouth(wr: ChunkWriter, s: Dictionary) -> void:
	var w := int(s["w"])
	var d := int(s["d"])
	var cx := (w - 1) / 2.0
	var cz := (d - 1) / 2.0 + 1.0
	var rad := minf(w, d) * 0.5 - 0.5
	for lz in d:
		for lx in w:
			var r := Vector2(lx - cx, lz - cz).length() + WorldGenerator.hashf(lx, lz, 41) * 1.2
			if r > rad:
				continue
			var top := int(round(7.0 * sqrt(maxf(1.0 - (r / rad) * (r / rad), 0.0)) + WorldGenerator.hashf(lx, lz, 43) * 1.5))
			for ly in range(0, top + 1):
				var hsh := WorldGenerator.hash2(lx * 13 + ly, lz, 47) % 9
				wr.put(lx, ly, lz, B.GRAVEL if hsh == 0 else (B.MOSS_STONE if hsh == 1 else B.STONE))
			if top >= 4 and WorldGenerator.hash2(lx, lz, 49) % 4 == 0:
				wr.put(lx, top, lz, B.GRASS)
			wr.foundation(lx, -1, lz, B.STONE, 6)
	# Túnel de entrada irregular (frente en z = 0)
	var ax := int(cx)
	var end_z := int(cz)
	for lz2 in range(0, end_z + 1):
		var half := 1 if lz2 > 1 else 2
		var hgt := 3 if lz2 > 1 else 4
		wr.fill(ax - half, 0, lz2, ax + half, hgt - 1, lz2, B.AIR)
		wr.put(ax, -1, lz2, B.GRAVEL)
		wr.put(ax - 1, -1, lz2, B.DIRT)
		wr.put(ax + 1, -1, lz2, B.GRAVEL)
	wr.put(ax - 2, 0, 0, B.MOSS_STONE)
	wr.put(ax + 2, 1, 0, B.STONE)
	wr.put(ax - 1, 0, 1, B.MUSHROOM)
	wr.entity("bones", Vector3(ax + 1.2, 0, 2.2), 30.0, {"uid": "bones_1"})
	wr.entity("bones", Vector3(ax - 2.4, 0, -1.4), 110.0, {"uid": "bones_2"})
	wr.entity("dungeon_entrance", Vector3(ax + 0.5, 0, end_z + 0.85), 0.0, {"uid": "mouth", "dungeon": str(s.get("dungeon", "cave_lobos")), "style": "open"})
