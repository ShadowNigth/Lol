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
		"mine_entrance":
			mine_entrance(wr, s)
		"bandit_camp":
			bandit_camp(wr, s)
		"castle":
			CastleBuilder.build(wr, s)
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
		"barracks":
			# Cuartel de la guardia: literas en fila, armero, mesa de dados y arcón
			for bi in 4:
				wr.entity("bed", Vector3(1.5 + bi * 1.6, 0, d - 2.5), 0.0, {"uid": "bed_%d" % bi})
			wr.entity("weapon_rack", Vector3(w - 1.62, 0, d / 2.0), 90.0, {"uid": "rack"})
			wr.entity("table", Vector3(w / 2.0, 0, 2.2), 0.0, {"uid": "t1"})
			wr.entity("chair", Vector3(w / 2.0 - 1.0, 0, 2.2), 90.0, {"uid": "c1"})
			wr.entity("chair", Vector3(w / 2.0 + 1.0, 0, 2.2), -90.0, {"uid": "c2"})
			wr.entity("chest", Vector3(1.4, 0, 1.6), 90.0, {"uid": "chest", "loot": "barracks"})
			wr.entity("barrel", Vector3(w - 1.5, 0, 1.5), 0.0, {"uid": "b1"})
			wr.entity("lantern", Vector3(w / 2.0, wall_h - 1.05, d / 2.0), 0.0, {"uid": "l1"})
			wr.entity("banner", Vector3(w / 2.0, 2.4, d - 1.08), 0.0, {"uid": "banner", "kind": "penalba"})
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


# ---------------------------------------------------------------------------
# Boca de la mina de Hierronegro: ladera de roca con vetas de hierro, galería
# entibada con raíles que salen hasta una vagoneta, escombrera, cobertizo de
# los mineros, hoguera del capataz y faroles en la bocamina.
# Coordenadas locales (25 × 25, explanada y frente en z = 0).
# ---------------------------------------------------------------------------

const MINE_SIZE := 25
const MINE_CAMPFIRE := Vector3(7.5, 0.0, 3.5)
const MINE_SHED := Vector3(19.5, 0.0, 3.5)
const MINE_PORTAL := Vector3(12.5, 0.0, 7.0)


static func mine_entrance(wr: ChunkWriter, s: Dictionary) -> void:
	var w := MINE_SIZE
	var d := MINE_SIZE
	# Explanada de tierra pisada y grava delante de la ladera
	for lz in range(0, 11):
		for lx in w:
			wr.foundation(lx, -1, lz, B.DIRT, 6)
			var hsh := WorldGenerator.hash2(lx * 5 + 1, lz, 5101) % 10
			wr.put(lx, -1, lz, B.GRAVEL if hsh < 3 else (B.PATH if hsh < 6 else B.DIRT))
			wr.clear(lx, 0, lz, lx, 9, lz)
	# Ladera: montículo alargado de roca con un frente escarpado hacia z = 8
	var cx := 12.0
	var cz := 17.5
	for lz2 in range(8, d):
		for lx2 in w:
			var nx := (lx2 - cx) / 12.5
			var nz := (lz2 - cz) / 9.8
			var r := sqrt(nx * nx + nz * nz) + WorldGenerator.hashf(lx2, lz2, 5103) * 0.12
			if r > 1.0:
				continue
			var top := int(round(11.0 * sqrt(maxf(1.0 - r * r, 0.0)) + WorldGenerator.hashf(lx2, lz2, 5105) * 1.6))
			if lz2 < 11:
				top = mini(top, 3 + (lz2 - 8) * 3)
			for ly in range(0, top + 1):
				var hh := WorldGenerator.hash2(lx2 * 11 + ly, lz2, 5107) % 13
				var id := B.STONE
				if hh == 0:
					id = B.IRON_ORE
				elif hh == 1:
					id = B.GRAVEL
				elif hh == 2:
					id = B.MOSS_STONE
				elif hh == 3:
					id = B.COBBLE
				wr.put(lx2, ly, lz2, id)
			if top >= 5 and WorldGenerator.hash2(lx2, lz2, 5109) % 3 == 0:
				wr.put(lx2, top, lz2, B.GRASS)
				if WorldGenerator.hash2(lx2, lz2, 5111) % 5 == 0:
					wr.put(lx2, top + 1, lz2, B.TALL_GRASS)
			wr.foundation(lx2, -1, lz2, B.STONE, 8)
	# Galería: 3 de ancho y 4 de alto, con marcos de entibado
	var ax0 := 11
	var ax1 := 13
	var back := 15
	for lz3 in range(5, back + 1):
		wr.fill(ax0, 0, lz3, ax1, 3, lz3, B.AIR)
		for lx3 in range(ax0, ax1 + 1):
			wr.put(lx3, -1, lz3, B.GRAVEL if (lx3 + lz3) % 3 != 0 else B.DIRT)
	for fz: int in [8, 11, 14]:
		for ly2 in range(0, 4):
			wr.put(ax0 - 1, ly2, fz, B.LOG)
			wr.put(ax1 + 1, ly2, fz, B.LOG)
		for lx4 in range(ax0 - 1, ax1 + 2):
			wr.put(lx4, 4, fz, B.DARK_PLANKS)
	# Tejadillo de tablas sobre la bocamina
	for lx5 in range(ax0 - 2, ax1 + 3):
		wr.put(lx5, 5, 7, B.PLANK_SLAB)
		wr.put(lx5, 4, 7, B.AIR)
	wr.put(ax0 - 2, 4, 7, B.FENCE)
	wr.put(ax1 + 2, 4, 7, B.FENCE)
	for ly3 in range(0, 4):
		wr.put(ax0 - 2, ly3, 7, B.FENCE)
		wr.put(ax1 + 2, ly3, 7, B.FENCE)
	# Raíles desde el fondo de la galería hasta la explanada, con tope
	for lz4 in range(1, back + 1):
		wr.put(12, 0, lz4, B.RAIL)
	wr.put(12, 0, 0, B.PLANK_SLAB)
	# Escombrera de grava y roca
	for lz5 in range(2, 11):
		for lx6 in range(0, 8):
			var rr := Vector2(lx6 - 3.5, lz5 - 6.5).length() / 3.6 + WorldGenerator.hashf(lx6, lz5, 5113) * 0.15
			if rr > 1.0:
				continue
			var tp := int(round(3.2 * (1.0 - rr * rr)))
			for ly4 in range(0, tp):
				wr.put(lx6, ly4, lz5, B.GRAVEL if WorldGenerator.hash2(lx6, lz5 + ly4, 5115) % 4 != 0 else B.STONE)
	# Cobertizo de los mineros: postes, tablas de abeto, techo de losas
	var sx0 := 17
	var sx1 := 22
	var sz0 := 1
	var sz1 := 5
	for lz6 in range(sz0, sz1 + 1):
		for lx7 in range(sx0, sx1 + 1):
			wr.put(lx7, -1, lz6, B.PLANKS)
	for corner: Vector2i in [Vector2i(sx0, sz0), Vector2i(sx1, sz0), Vector2i(sx0, sz1), Vector2i(sx1, sz1)]:
		for ly5 in range(0, 3):
			wr.put(corner.x, ly5, corner.y, B.LOG)
	for lx8 in range(sx0 + 1, sx1):
		for ly6 in range(0, 3):
			wr.put(lx8, ly6, sz1, B.SPRUCE_PLANKS)
	for lz7 in range(sz0 + 1, sz1):
		for ly7 in range(0, 3):
			wr.put(sx1, ly7, lz7, B.SPRUCE_PLANKS)
			if not (ly7 == 1 and lz7 == 3):
				wr.put(sx0, ly7, lz7, B.SPRUCE_PLANKS)
	wr.put(sx0, 1, 3, B.GLASS)
	for lz8 in range(sz0 - 1, sz1 + 2):
		for lx9 in range(sx0 - 1, sx1 + 2):
			wr.put(lx9, 3, lz8, B.PLANK_SLAB)
	# Mobiliario y herramientas
	wr.entity("minecart", Vector3(12.5, 0, 3.5), 0.0, {"uid": "cart"})
	wr.entity("ore_pile", Vector3(15.6, 0, 3.2), 40.0, {"uid": "ore"})
	wr.entity("pickaxe", Vector3(10.2, 0, 5.4), 70.0, {"uid": "pick"})
	wr.entity("crate", Vector3(15.6, 0, 6.4), 10.0, {"uid": "crate_0"})
	wr.entity("crate", Vector3(15.6, 0.75, 6.4), 35.0, {"uid": "crate_1"})
	wr.entity("barrel", Vector3(9.3, 0, 6.6), 0.0, {"uid": "barrel_0"})
	wr.entity("table", Vector3(19.5, 0, 4.2), 0.0, {"uid": "shed_table"})
	wr.entity("barrel", Vector3(21.3, 0, 4.3), 0.0, {"uid": "shed_barrel"})
	wr.entity("crate", Vector3(18.0, 0, 4.4), 0.0, {"uid": "shed_crate"})
	wr.entity("bedroll", Vector3(20.2, 0, 2.2), 90.0, {"uid": "shed_bed"})
	wr.entity("campfire", MINE_CAMPFIRE, 0.0, {"uid": "fire"})
	wr.entity("smoke", MINE_CAMPFIRE + Vector3(0, 0.6, 0), 0.0, {"uid": "smoke"})
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		wr.entity("log_seat", MINE_CAMPFIRE + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6), rad_to_deg(-a) + 90.0, {"uid": "seat_%d" % k})
	wr.entity("sign", Vector3(15.2, 0, 1.2), 0.0, {"uid": "sign"})
	# Faroles en los postes de la bocamina
	wr.entity("wall_lantern", Vector3(ax0 - 0.5, 2.2, 7.7), 0.0, {"uid": "lamp_w"})
	wr.entity("wall_lantern", Vector3(ax1 + 1.5, 2.2, 7.7), 0.0, {"uid": "lamp_e"})
	wr.entity("dungeon_entrance", Vector3(12.5, 0, back + 0.85), 0.0, {"uid": "adit", "dungeon": str(s.get("dungeon", "mina_hierronegro")), "style": "open"})


# ---------------------------------------------------------------------------
# Campamento de bandidos (los Cuervos): empalizada, tiendas, torre de vigía,
# hoguera, jaula con prisionera y arcón del jefe
# ---------------------------------------------------------------------------

## Disposición en coordenadas locales (25 × 25, entrada en z = 0). El
## planificador usa las mismas posiciones para enemigos y PNJ.
const CAMP_SIZE := 25
const CAMP_CENTER := Vector2(12.5, 12.5)
const CAMP_CAGE := Vector3(6.0, 0.0, 6.0)
const CAMP_STASH := Vector3(12.5, 0.0, 20.4)


static func bandit_camp(wr: ChunkWriter, s: Dictionary) -> void:
	var r := _rng(s)
	var cx := 12
	var cz := 12
	# Suelo pisoteado y despejado dentro del cerco
	for lz in CAMP_SIZE:
		for lx in CAMP_SIZE:
			var dist := Vector2(lx - cx, lz - cz).length()
			if dist > 11.6:
				continue
			wr.foundation(lx, -1, lz, B.DIRT, 6)
			var hsh := WorldGenerator.hash2(lx * 7 + 3, lz, 4401) % 10
			var ground := B.GRASS
			if dist < 3.2:
				ground = B.GRAVEL if hsh < 6 else B.DIRT
			elif hsh < 4:
				ground = B.PATH
			elif hsh < 6:
				ground = B.DIRT
			wr.put(lx, -1, lz, ground)
			wr.clear(lx, 0, lz, lx, 6, lz)
	# Empalizada: anillo de un tronco de grosor siguiendo el círculo, con
	# huecos para la puerta y una brecha trasera para entrar a escondidas
	var ring := {}
	for step in 720:
		var ang := TAU * step / 720.0
		var cell := Vector2i(int(floor(CAMP_CENTER.x + cos(ang) * 11.2)), int(floor(CAMP_CENTER.y + sin(ang) * 11.2)))
		ring[cell] = ang
	for cell2: Vector2i in ring:
		var lx2 := cell2.x
		var lz2 := cell2.y
		if absi(lx2 - cx) <= 1 and lz2 < cz:
			continue                              # puerta principal
		if absf(float(ring[cell2]) - deg_to_rad(52.0)) < 0.13:
			continue                              # brecha trasera
		wr.foundation(lx2, -1, lz2, B.DIRT, 6)
		# Troncos alternos altos (con la punta afilada) y bajos: perfil dentado.
		# La punta solo va en los altos para que no se una a un vecino más
		# alto (las vallas se conectan con los bloques opacos de al lado).
		var tall := (lx2 + lz2) % 2 == 0
		var hgt := 4 if tall else 3
		for ly in hgt:
			wr.put(lx2, ly, lz2, B.SPRUCE_LOG if (lx2 * 7 + lz2) % 3 != 0 else B.LOG)
		if tall:
			wr.put(lx2, hgt, lz2, B.FENCE)
	# Postes de la puerta con antorchas
	for gx: int in [cx - 2, cx + 2]:
		for gy in 5:
			wr.put(gx, gy, 1, B.LOG)
		wr.put(gx, 5, 1, B.TORCH)
	# Tiendas: dos laterales abiertas hacia la hoguera y la del jefe al fondo
	_tent(wr, 3, 9, 6, 2, true, false)
	_tent(wr, 17, 10, 5, 2, true, true)
	_tent(wr, 9, 16, 6, 3, false, true)
	wr.put(12, 3, 21, B.CANVAS)                   # mástil con el gallardete rojo del jefe
	wr.put(12, 4, 21, B.FENCE)
	wr.put(12, 5, 21, B.WOOL_RED)
	wr.entity("bedroll", Vector3(5.5, 0, 11.5), 90.0, {"uid": "bedroll_a"})
	wr.entity("bedroll", Vector3(19.5, 0, 12.5), -90.0, {"uid": "bedroll_b"})
	wr.entity("bedroll", Vector3(10.4, 0, 19.5), 180.0, {"uid": "bedroll_chief"})
	wr.entity("chest", CAMP_STASH, 0.0, {"uid": "stash", "loot": "bandit_stash", "lock": 60, "key": "key_cuervos"})
	wr.entity("crate", Vector3(14.6, 0, 20.4), 15.0, {"uid": "crate_chief"})
	# Torre de vigía con escalera, plataforma, barandilla y tejadillo
	for px: int in [15, 17]:
		for pz: int in [4, 6]:
			for py in 6:
				wr.put(px, py, pz, B.LOG)
	for tz in range(4, 7):
		for tx in range(15, 18):
			if not ((tx == 15 or tx == 17) and (tz == 4 or tz == 6)):
				wr.put(tx, 3, tz, B.PLANKS)
				wr.put(tx, 6, tz, B.PLANK_SLAB)
	for rail: Vector2i in [Vector2i(16, 4), Vector2i(15, 5), Vector2i(17, 5)]:
		wr.put(rail.x, 4, rail.y, B.FENCE)
	wr.put(15, 6, 4, B.PLANK_SLAB)
	wr.put(17, 6, 4, B.PLANK_SLAB)
	wr.put(15, 6, 6, B.PLANK_SLAB)
	wr.put(17, 6, 6, B.PLANK_SLAB)
	for step in 4:
		var sz := 10 - step
		wr.put(16, step, sz, B.stairs(B.PLANK_STAIRS, 0))
		for fill in step:
			wr.put(16, fill, sz, B.FENCE)        # postes bajo los peldaños (escalera abierta)
	# Hoguera con troncos para sentarse (del lado de la entrada: detrás queda
	# libre el paso de la ronda ante la tienda del jefe)
	wr.entity("campfire", Vector3(cx + 0.5, 0, cz + 0.5), 0.0, {"uid": "fire"})
	for k in 3:
		var a := deg_to_rad(200.0 + k * 70.0)
		var sp := Vector3(cx + 0.5 + cos(a) * 2.4, 0, cz + 0.5 + sin(a) * 2.4)
		wr.entity("log_seat", sp, rad_to_deg(-a), {"uid": "seat_%d" % k})
	# Jaula de la prisionera (puerta hacia el interior del campamento)
	wr.entity("cage", CAMP_CAGE, -90.0, {"uid": "cage", "lock": 45, "key": "key_cuervos", "flag": "jaula_cuervos_abierta", "captive": "lina"})
	# Leña, paja, barriles y mercancía robada
	for wx in range(3, 6):
		wr.put(wx, 0, 15, B.LOG)
	wr.put(4, 1, 15, B.LOG)
	wr.put(20, 0, 7, B.HAY)
	wr.put(21, 0, 8, B.HAY)
	wr.put(20, 1, 7, B.HAY)
	wr.entity("barrel", Vector3(7.6, 0, 3.6), 0.0, {"uid": "barrel_1"})
	wr.entity("barrel", Vector3(8.5, 0, 3.2), 40.0, {"uid": "barrel_2"})
	wr.entity("goods", Vector3(20.6, 0, 15.8), 200.0, {"uid": "goods_1", "kind": "cloth"})
	wr.entity("sack", Vector3(19.6, 0, 16.7), 0.0, {"uid": "sack_1"})
	wr.entity("sack", Vector3(9.4, 0, 3.9), 70.0, {"uid": "sack_2"})
	wr.entity("crate", Vector3(4.4, 0, 16.6), 10.0, {"uid": "crate_1"})
	var _unused := r


## Tienda de lona a dos aguas. `along_x`: la cumbrera va a lo largo del eje X
## local; (x0, z0) es la esquina mínima, `length` el largo de la cumbrera y
## `half` el medio ancho (2 = tienda pequeña, 3 = tienda del jefe). La cabecera
## de coordenada menor queda abierta si `open_min` (si no, la mayor).
static func _tent(wr: ChunkWriter, x0: int, z0: int, length: int, half: int, along_x: bool, open_min: bool) -> void:
	var c0 := (z0 if along_x else x0) + half
	var a0 := x0 if along_x else z0
	var open_a := a0 if open_min else a0 + length - 1
	var closed_a := a0 + length - 1 if open_min else a0
	var lo_face := 2 if along_x else 1
	var hi_face := 0 if along_x else 3
	for a in range(a0, a0 + length):
		for o in range(-half, half + 1):
			var y := half - absi(o)
			var id := B.CANVAS_SLAB if o == 0 else B.stairs(B.CANVAS_STAIRS, lo_face if o < 0 else hi_face)
			_tent_put(wr, along_x, a, c0 + o, y, id)
			for yy in range(0, y):
				_tent_put(wr, along_x, a, c0 + o, yy, B.AIR)
			_tent_put(wr, along_x, a, c0 + o, -1, B.PATH if absi(o) < half else B.DIRT)
	for o2 in range(-half + 1, half):
		for yy2 in range(0, half - absi(o2)):
			_tent_put(wr, along_x, closed_a, c0 + o2, yy2, B.CANVAS)
	for side: int in [-1, 1]:
		_tent_put(wr, along_x, open_a, c0 + side * (half - 1), 0, B.CANVAS)


static func _tent_put(wr: ChunkWriter, along_x: bool, a: int, o: int, y: int, id: int) -> void:
	if along_x:
		wr.put(a, y, o, id)
	else:
		wr.put(o, y, a, id)
