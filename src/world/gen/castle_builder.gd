class_name CastleBuilder
extends RefCounted
## Castillo de Peñalba: recinto amurallado de 39 x 39 bloques con cuatro torres
## de esquina (escalera de caracol hasta la azotea), adarve almenado continuo,
## torre-puerta con rastrillo, torre del homenaje (salón del trono, cámara de
## la señora y azotea) y calabozo con dos celdas enrejadas. El cuartel, la
## armería, el pozo y las farolas son edificios aparte (StructureBuilder) que
## el planificador coloca dentro del patio.
##
## Marco local (ChunkWriter.frame): y = 0 es el suelo del patio; la puerta está
## en z = 0 (mirando hacia -Z local).

const B = preload("res://src/world/voxel/block_types.gd")

const SIZE := 39
const WALL_H := 6          # muralla maciza en y = 0..5: el adarve está a la altura 6
const TOWER_H := 10        # torres: azotea a la altura 10
const GATE := Rect2i(15, 0, 9, 7)       # torre-puerta (x, z, ancho, fondo)
const PASSAGE_X := Vector2i(18, 20)     # paso de la puerta (x mínima, x máxima)
const KEEP := Rect2i(14, 19, 11, 13)    # torre del homenaje
const KEEP_FLOOR2 := 6                  # forjado de la primera planta (de pie a 7)
const KEEP_ROOF := 12                   # azotea (de pie a 13)
const JAIL := Rect2i(27, 21, 7, 10)     # calabozo
const JAIL_DOOR := Vector2i(29, 21)     # puerta del calabozo (en su fachada norte, hacia el patio)
## Celdas del calabozo: interior (x0, z0, x1, z1) y puerta enrejada (x, z).
const CELLS := [[Vector4i(28, 27, 29, 29), Vector2i(29, 26)], [Vector4i(31, 27, 32, 29), Vector2i(31, 26)]]
## Orden del anillo de la escalera de caracol en una torre de 7 x 7 (pilar en 3,3).
const RING := [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2), Vector2i(3, 2)]


static func build(wr: ChunkWriter, s: Dictionary) -> void:
	_ground(wr)
	# Lienzos de muralla entre torres (exterior: z = 2 / z = 36 / x = 2 / x = 36)
	_curtain(wr, Rect2i(7, 2, 25, 3), Vector2i(0, -1))
	_curtain(wr, Rect2i(7, 34, 25, 3), Vector2i(0, 1))
	_curtain(wr, Rect2i(2, 7, 3, 25), Vector2i(-1, 0))
	_curtain(wr, Rect2i(34, 7, 3, 25), Vector2i(1, 0))
	# Torres de esquina: puertas hacia los adarves y escalera que esquiva las puertas
	_tower(wr, Vector2i(0, 0), ["E", "S"], 4)
	_tower(wr, Vector2i(32, 0), ["W", "S"], 6)
	_tower(wr, Vector2i(0, 32), ["E", "N"], 2)
	_tower(wr, Vector2i(32, 32), ["W", "N"], 0)
	_wall_stairs(wr)
	_gatehouse(wr)
	_keep(wr)
	_jail(wr)
	_yard(wr, s)


# ---------------------------------------------------------------------------
# Patio
# ---------------------------------------------------------------------------

static func _ground(wr: ChunkWriter) -> void:
	# Despeja el patio (sin tocar el terreno de fuera) y lo pavimenta en parte
	wr.clear(5, 0, 5, SIZE - 6, 14, SIZE - 6)
	for lz in range(5, SIZE - 5):
		for lx in range(5, SIZE - 5):
			wr.foundation(lx, -2, lz, B.DIRT, 6)
			var cur := wr.get_local(lx, -1, lz)
			if cur == B.AIR or cur == B.WATER:
				wr.put(lx, -1, lz, B.GRASS)
	# Camino empedrado desde la puerta hasta el homenaje y, a lo largo de su
	# fachada, hasta la puerta del calabozo
	for lz in range(5, KEEP.position.y):
		for lx in range(PASSAGE_X.x, PASSAGE_X.y + 1):
			wr.put(lx, -1, lz, _vary(wr, lx, -1, lz, B.COBBLE, B.GRAVEL, 12))
	for lx in range(PASSAGE_X.y + 1, JAIL_DOOR.x + 2):
		wr.put(lx, -1, 18, _vary(wr, lx, -1, 18, B.COBBLE, B.GRAVEL, 15))
	for lz in range(18, JAIL.position.y):
		for lx in range(JAIL_DOOR.x - 1, JAIL_DOOR.x + 2):
			wr.put(lx, -1, lz, _vary(wr, lx, -1, lz, B.COBBLE, B.GRAVEL, 15))
	# Explanada de tierra delante de la puerta (fuera de la muralla)
	for lz in range(-6, 0):
		for lx in range(PASSAGE_X.x - 1, PASSAGE_X.y + 2):
			wr.foundation(lx, -2, lz, B.DIRT, 6)
			wr.put(lx, -1, lz, B.PATH)
			wr.clear(lx, 0, lz, lx, 4, lz)


## Variación determinista de material por posición (muros menos repetitivos).
static func _vary(wr: ChunkWriter, lx: int, ly: int, lz: int, base: int, alt: int, chance_pct: int) -> int:
	var p := wr.to_world_xz(lx, lz)
	if WorldGenerator.hash2(p.x * 31 + ly, p.y, 4217) % 100 < chance_pct:
		return alt
	return base


static func _masonry(wr: ChunkWriter, lx: int, ly: int, lz: int) -> int:
	if ly <= 0:
		return _vary(wr, lx, ly, lz, B.COBBLE, B.MOSS_STONE, 30)
	if ly == 1:
		return _vary(wr, lx, ly, lz, B.STONE_BRICK, B.MOSSY_BRICK, 35)
	return _vary(wr, lx, ly, lz, B.STONE_BRICK, B.CRACKED_BRICK, 8)


# ---------------------------------------------------------------------------
# Muralla con adarve, parapeto y almenas en el lado exterior
# ---------------------------------------------------------------------------

static func _curtain(wr: ChunkWriter, r: Rect2i, outward: Vector2i) -> void:
	for lz in range(r.position.y, r.end.y):
		for lx in range(r.position.x, r.end.x):
			wr.foundation(lx, -1, lz, B.COBBLE, 14)
			for ly in range(0, WALL_H):
				wr.put(lx, ly, lz, _masonry(wr, lx, ly, lz))
			wr.clear(lx, WALL_H, lz, lx, WALL_H + 3, lz)
			var outer := (outward.y < 0 and lz == r.position.y) or (outward.y > 0 and lz == r.end.y - 1) \
					or (outward.x < 0 and lx == r.position.x) or (outward.x > 0 and lx == r.end.x - 1)
			if outer:
				wr.put(lx, WALL_H, lz, B.STONE_BRICK)
				var along := lx if outward.y != 0 else lz
				if along % 2 == 0:
					wr.put(lx, WALL_H + 1, lz, B.STONE_BRICK)
					if along % 8 == 0:
						wr.put(lx, WALL_H + 2, lz, B.TORCH)
			# Cornisa (matacán corrido) bajo el parapeto exterior
			if outer:
				var ox := lx + outward.x
				var oz := lz + outward.y
				wr.put(ox, WALL_H - 1, oz, B.BRICK_SLAB_TOP)


## Escaleras de piedra adosadas a la cara interior de la muralla (patio -> adarve).
static func _wall_stairs(wr: ChunkWriter) -> void:
	# A los lados de la torre-puerta (suben hacia la puerta) y junto a la muralla trasera
	_flight(wr, Vector2i(8, 5), Vector2i(1, 0))
	_flight(wr, Vector2i(30, 5), Vector2i(-1, 0))
	_flight(wr, Vector2i(6, 33), Vector2i(1, 0))


static func _flight(wr: ChunkWriter, start: Vector2i, dir: Vector2i) -> void:
	var facing := 1 if dir.x > 0 else (3 if dir.x < 0 else (2 if dir.y > 0 else 0))
	for k in WALL_H:
		var c := start + dir * k
		wr.foundation(c.x, -1, c.y, B.COBBLE, 6)
		for ly in range(0, k):
			wr.put(c.x, ly, c.y, B.COBBLE)
		wr.put(c.x, k, c.y, B.stairs(B.BRICK_STAIRS, facing))
		wr.clear(c.x, k + 1, c.y, c.x, k + 3, c.y)


# ---------------------------------------------------------------------------
# Torre de esquina de 7 x 7: muro de dos bloques, base maciza, sala a la
# altura del adarve y caracol de cuatro peldaños hasta la azotea almenada
# ---------------------------------------------------------------------------

static func _tower(wr: ChunkWriter, o: Vector2i, doors: Array, spiral_start: int) -> void:
	var n := 7
	for lz in n:
		for lx in n:
			var x := o.x + lx
			var z := o.y + lz
			wr.foundation(x, -1, z, B.COBBLE, 14)
			var shell := lx <= 1 or lz <= 1 or lx >= n - 2 or lz >= n - 2
			var corner := (lx == 0 or lx == n - 1) and (lz == 0 or lz == n - 1)
			for ly in range(0, TOWER_H):
				var id := B.AIR
				if shell or (lx == 3 and lz == 3):
					id = _masonry(wr, x, ly, z)
					if corner and ly % 4 == 3:
						id = B.CHISELED
				elif ly < 5:
					id = B.COBBLE
				elif ly == 5:
					id = B.PLANKS
				elif ly == TOWER_H - 1:
					id = B.STONE_BRICK
				wr.put(x, ly, z, id)
			wr.clear(x, TOWER_H, z, x, TOWER_H + 3, z)
			# Parapeto y almenas de la azotea
			var edge := lx == 0 or lz == 0 or lx == n - 1 or lz == n - 1
			if edge:
				wr.put(x, TOWER_H, z, B.STONE_BRICK)
				if (lx + lz) % 2 == 0:
					wr.put(x, TOWER_H + 1, z, B.STONE_BRICK)
	wr.put(o.x, TOWER_H + 2, o.y, B.TORCH)
	wr.put(o.x + n - 1, TOWER_H + 2, o.y + n - 1, B.TORCH)
	# Puertas al adarve (dos de alto) con dintel tallado
	for f: String in doors:
		var cells: Array[Vector2i] = []
		match f:
			"E":
				cells = [Vector2i(5, 3), Vector2i(6, 3)]
			"W":
				cells = [Vector2i(0, 3), Vector2i(1, 3)]
			"S":
				cells = [Vector2i(3, 5), Vector2i(3, 6)]
			"N":
				cells = [Vector2i(3, 0), Vector2i(3, 1)]
		for c in cells:
			wr.put(o.x + c.x, WALL_H, o.y + c.y, B.AIR)
			wr.put(o.x + c.x, WALL_H + 1, o.y + c.y, B.AIR)
			wr.put(o.x + c.x, WALL_H + 2, o.y + c.y, B.CHISELED)
	# Saeteras en las caras exteriores (las que no tienen puerta)
	for f: String in ["E", "W", "S", "N"]:
		if f in doors:
			continue
		var slit: Array[Vector2i] = []
		match f:
			"E":
				slit = [Vector2i(5, 3), Vector2i(6, 3)]
			"W":
				slit = [Vector2i(0, 3), Vector2i(1, 3)]
			"S":
				slit = [Vector2i(3, 5), Vector2i(3, 6)]
			"N":
				slit = [Vector2i(3, 0), Vector2i(3, 1)]
		for c2 in slit:
			wr.put(o.x + c2.x, WALL_H + 1, o.y + c2.y, B.AIR)
	# Caracol: peldaños de la altura 6 a la 9 por el anillo, saltándose las puertas
	for k in 4:
		var cur: Vector2i = RING[(spiral_start + k) % 8]
		var nxt: Vector2i = RING[(spiral_start + k + 1) % 8]
		var dir := nxt - cur
		var facing := 0
		if dir.x > 0:
			facing = 1
		elif dir.x < 0:
			facing = 3
		elif dir.y > 0:
			facing = 2
		var ly := WALL_H + k
		wr.put(o.x + cur.x, ly, o.y + cur.y, B.stairs(B.BRICK_STAIRS, facing))
		# Hueco en la azotea sobre los peldaños altos (para no darse en la cabeza)
		if k >= 1 and k <= 2:
			wr.put(o.x + cur.x, TOWER_H - 1, o.y + cur.y, B.AIR)


# ---------------------------------------------------------------------------
# Torre-puerta: paso abovedado con rastrillo alzado, sala de guardia a la
# altura del adarve y almenas
# ---------------------------------------------------------------------------

static func _gatehouse(wr: ChunkWriter) -> void:
	var g := GATE
	var top := 9
	for lz in range(g.position.y, g.end.y):
		for lx in range(g.position.x, g.end.x):
			wr.foundation(lx, -1, lz, B.COBBLE, 14)
			for ly in range(0, top + 1):
				wr.put(lx, ly, lz, _masonry(wr, lx, ly, lz))
			wr.clear(lx, top + 1, lz, lx, top + 3, lz)
			var edge := lx == g.position.x or lx == g.end.x - 1 or lz == g.position.y or lz == g.end.y - 1
			if edge:
				wr.put(lx, top + 1, lz, B.STONE_BRICK)
				if (lx + lz) % 2 == 1:
					wr.put(lx, top + 2, lz, B.STONE_BRICK)
	# Paso de la puerta
	for lz in range(g.position.y, g.end.y):
		for lx in range(PASSAGE_X.x, PASSAGE_X.y + 1):
			wr.put(lx, -1, lz, _vary(wr, lx, -1, lz, B.COBBLE, B.GRAVEL, 10))
			wr.clear(lx, 0, lz, lx, 3, lz)
	# Arco: jambas y dovelas talladas en las dos bocas
	for lz2: int in [g.position.y, g.end.y - 1]:
		for ly in range(0, 4):
			wr.put(PASSAGE_X.x - 1, ly, lz2, B.CHISELED)
			wr.put(PASSAGE_X.y + 1, ly, lz2, B.CHISELED)
		for lx in range(PASSAGE_X.x - 1, PASSAGE_X.y + 2):
			wr.put(lx, 4, lz2, B.CHISELED)
	# Sala de guardia (suelo a la altura del adarve) y puertas a ambos lados
	wr.clear(g.position.x + 1, WALL_H, g.position.y + 1, g.end.x - 2, top - 1, g.end.y - 2)
	wr.fill(g.position.x + 1, WALL_H - 1, g.position.y + 1, g.end.x - 2, WALL_H - 1, g.end.y - 2, B.PLANKS)
	for side: int in [g.position.x, g.end.x - 1]:
		wr.put(side, WALL_H, 3, B.AIR)
		wr.put(side, WALL_H + 1, 3, B.AIR)
	# Saeteras hacia fuera y ventanas hacia el patio
	for lx: int in [17, 21]:
		wr.put(lx, WALL_H + 1, g.position.y, B.AIR)
		wr.put(lx, WALL_H + 1, g.end.y - 1, B.GLASS)
	wr.entity("castle_portcullis", Vector3(19.5, 0.0, 1.5), 0.0, {"uid": "portcullis"})
	wr.entity("banner", Vector3(16.5, 5.6, -0.08), 0.0, {"uid": "banner_w", "kind": "penalba"})
	wr.entity("banner", Vector3(22.5, 5.6, -0.08), 0.0, {"uid": "banner_e", "kind": "penalba"})
	wr.entity("wall_lantern", Vector3(16.5, 2.4, -0.12), 0.0, {"uid": "lamp_w"})
	wr.entity("wall_lantern", Vector3(22.5, 2.4, -0.12), 0.0, {"uid": "lamp_e"})
	wr.entity("lantern", Vector3(19.5, 2.95, 3.5), 0.0, {"uid": "lamp_passage"})
	wr.entity("lantern", Vector3(19.5, WALL_H + 1.9, 3.5), 0.0, {"uid": "lamp_room"})
	wr.entity("barrel", Vector3(16.6, WALL_H, 1.6), 0.0, {"uid": "room_barrel"})
	wr.entity("weapon_rack", Vector3(21.5, WALL_H, 5.62), 0.0, {"uid": "room_rack"})


# ---------------------------------------------------------------------------
# Torre del homenaje: salón del trono, cámara de la señora y azotea
# ---------------------------------------------------------------------------

static func _keep(wr: ChunkWriter) -> void:
	var k := KEEP
	var x0 := k.position.x
	var z0 := k.position.y
	var x1 := k.end.x - 1
	var z1 := k.end.y - 1
	var top := KEEP_ROOF
	wr.clear(x0, 0, z0, x1, top + 4, z1)
	for lz in range(z0, z1 + 1):
		for lx in range(x0, x1 + 1):
			wr.foundation(lx, -2, lz, B.COBBLE, 12)
			var edge := lx == x0 or lx == x1 or lz == z0 or lz == z1
			wr.put(lx, -1, lz, B.COBBLE if edge else B.DARK_PLANKS)
			if not edge:
				wr.put(lx, KEEP_FLOOR2, lz, B.PLANKS)
				wr.put(lx, top, lz, B.DARK_PLANKS)
				continue
			var corner := (lx == x0 or lx == x1) and (lz == z0 or lz == z1)
			for ly in range(0, top + 1):
				var id := _masonry(wr, lx, ly, lz)
				if corner or ly == KEEP_FLOOR2 or ly == top:
					id = B.CHISELED
				wr.put(lx, ly, lz, id)
			wr.put(lx, top + 1, lz, B.STONE_BRICK)
			if (lx + lz) % 2 == 0:
				wr.put(lx, top + 2, lz, B.STONE_BRICK)
				if corner:
					wr.put(lx, top + 3, lz, B.TORCH)
	# Ventanas altas y estrechas en las dos plantas
	for wz: int in [22, 25, 28]:
		for wy: Array in [[2, 3], [8, 9]]:
			for yy: int in wy:
				wr.put(x0, yy, wz, B.GLASS)
				wr.put(x1, yy, wz, B.GLASS)
	for wx: int in [16, 22]:
		for yy2: int in [2, 3, 8, 9]:
			wr.put(wx, yy2, z0, B.GLASS)
	wr.put(19, 8, z0, B.GLASS)
	wr.put(19, 9, z0, B.GLASS)
	# Puerta principal con jambas talladas
	wr.clear(19, 0, z0, 19, 1, z0)
	for ly in range(0, 3):
		wr.put(18, ly, z0, B.CHISELED)
		wr.put(20, ly, z0, B.CHISELED)
	wr.put(19, 2, z0, B.CHISELED)
	wr.entity("door", Vector3(19.5, 0.0, z0 + 0.5), 0.0, {"uid": "keep_door"})
	wr.entity("banner", Vector3(19.5, 4.2, z0 - 0.08), 0.0, {"uid": "keep_banner", "kind": "penalba"})
	wr.entity("banner", Vector3(16.5, 10.4, z0 - 0.08), 0.0, {"uid": "keep_banner_w", "kind": "penalba"})
	wr.entity("banner", Vector3(22.5, 10.4, z0 - 0.08), 0.0, {"uid": "keep_banner_e", "kind": "penalba"})
	wr.entity("wall_lantern", Vector3(17.5, 2.3, z0 - 0.12), 0.0, {"uid": "keep_lamp_w"})
	wr.entity("wall_lantern", Vector3(21.5, 2.3, z0 - 0.12), 0.0, {"uid": "keep_lamp_e"})

	# --- Salón del trono (planta baja) ---
	for lz in range(z0 + 1, 28):
		for lx in range(18, 21):
			wr.put(lx, -1, lz, B.WOOL_RED)
	for pc: Vector2i in [Vector2i(16, 23), Vector2i(22, 23), Vector2i(16, 27), Vector2i(22, 27)]:
		for ly in range(0, KEEP_FLOOR2):
			wr.put(pc.x, ly, pc.y, B.CHISELED)
	# Estrado con escalones y el trono de los Peñalba
	wr.fill(16, 0, 28, 22, 0, z1 - 1, B.DARK_PLANKS)
	for lx in range(18, 21):
		wr.put(lx, 0, 27, B.stairs(B.DARK_STAIRS, 2))
	wr.entity("throne", Vector3(19.5, 1.0, z1 - 0.62), 0.0, {"uid": "throne"})
	wr.entity("banner", Vector3(17.5, 3.0, z1 - 0.08), 0.0, {"uid": "hall_banner_w", "kind": "penalba"})
	wr.entity("banner", Vector3(21.5, 3.0, z1 - 0.08), 0.0, {"uid": "hall_banner_e", "kind": "penalba"})
	wr.entity("brazier", Vector3(15.5, 0.0, 28.6), 0.0, {"uid": "hall_brazier_w"})
	wr.entity("brazier", Vector3(23.5, 0.0, 28.6), 0.0, {"uid": "hall_brazier_e"})
	wr.entity("lantern", Vector3(19.5, KEEP_FLOOR2 - 1.05, 22.5), 0.0, {"uid": "hall_lamp_1"})
	wr.entity("lantern", Vector3(19.5, KEEP_FLOOR2 - 1.05, 26.0), 0.0, {"uid": "hall_lamp_2"})
	wr.entity("table", Vector3(22.6, 0.0, 25.0), 90.0, {"uid": "hall_table"})
	wr.entity("chair", Vector3(23.5, 0.0, 24.5), -90.0, {"uid": "hall_chair_1"})
	wr.entity("chair", Vector3(23.5, 0.0, 25.6), -90.0, {"uid": "hall_chair_2"})
	wr.entity("chest", Vector3(23.4, 0.0, 21.0), -90.0, {"uid": "hall_chest", "loot": "castle", "lock": 50})
	wr.put(x0 + 1, 0, z1 - 1, B.BOOKSHELF)
	wr.put(x0 + 1, 1, z1 - 1, B.BOOKSHELF)
	wr.put(x1 - 1, 0, z1 - 1, B.BOOKSHELF)
	wr.put(x1 - 1, 1, z1 - 1, B.BOOKSHELF)
	# Escalera a la primera planta junto al muro oeste (sube hacia el fondo)
	for s in range(0, KEEP_FLOOR2 + 1):
		wr.put(x0 + 1, s, z0 + 2 + s, B.stairs(B.BRICK_STAIRS, 2))
		for ly2 in range(0, s):
			wr.put(x0 + 1, ly2, z0 + 2 + s, B.STONE_BRICK)
	for lz3 in range(z0 + 3, z0 + 2 + KEEP_FLOOR2):
		wr.put(x0 + 1, KEEP_FLOOR2, lz3, B.AIR)
		wr.put(x0 + 2, KEEP_FLOOR2 + 1, lz3, B.FENCE)
	wr.put(x0 + 1, KEEP_FLOOR2 + 1, z0 + 2, B.FENCE)

	# --- Cámara de la señora (primera planta) ---
	var f2 := KEEP_FLOOR2 + 1
	wr.entity("bed", Vector3(21.5, f2, 29.5), 0.0, {"uid": "lady_bed"})
	wr.entity("chest", Vector3(18.5, f2, z1 - 0.7), 180.0, {"uid": "lady_chest", "loot": "noble", "lock": 65})
	wr.entity("table", Vector3(17.5, f2, 22.6), 0.0, {"uid": "study_table"})
	wr.entity("chair", Vector3(17.5, f2, 21.7), 180.0, {"uid": "study_chair"})
	wr.entity("lantern", Vector3(19.5, top - 1.05, 25.5), 0.0, {"uid": "lady_lamp"})
	wr.entity("banner", Vector3(19.5, f2 + 2.2, z1 - 0.08), 0.0, {"uid": "lady_banner", "kind": "penalba"})
	for lx5 in range(17, 21):
		wr.put(lx5, f2, z0 + 1, B.BOOKSHELF)
		wr.put(lx5, f2 + 1, z0 + 1, B.BOOKSHELF)
	# Escalera a la azotea junto al muro este (sube hacia la puerta)
	for s2 in range(0, top - KEEP_FLOOR2):
		var sz := 27 - s2
		wr.put(x1 - 1, f2 + s2, sz, B.stairs(B.BRICK_STAIRS, 0))
		for ly3 in range(f2, f2 + s2):
			wr.put(x1 - 1, ly3, sz, B.STONE_BRICK)
	for lz5 in range(23, 26):
		wr.put(x1 - 1, top, lz5, B.AIR)
	for lz6 in range(22, 26):
		wr.put(x1 - 2, top + 1, lz6, B.FENCE)
	wr.put(x1 - 1, top + 1, 26, B.FENCE)


# ---------------------------------------------------------------------------
# Calabozo: puesto del carcelero y dos celdas con reja y puerta enrejada
# ---------------------------------------------------------------------------

static func _jail(wr: ChunkWriter) -> void:
	var j := JAIL
	var x0 := j.position.x
	var z0 := j.position.y
	var x1 := j.end.x - 1
	var z1 := j.end.y - 1
	var h := 4
	wr.clear(x0, 0, z0, x1, h + 3, z1)
	for lz in range(z0, z1 + 1):
		for lx in range(x0, x1 + 1):
			wr.foundation(lx, -2, lz, B.COBBLE, 12)
			wr.put(lx, -1, lz, B.DUNGEON_FLOOR if lz >= 27 else B.COBBLE)
			var edge := lx == x0 or lx == x1 or lz == z0 or lz == z1
			wr.put(lx, h, lz, B.STONE_BRICK)
			if edge:
				for ly in range(0, h):
					wr.put(lx, ly, lz, _masonry(wr, lx, ly, lz))
				wr.put(lx, h + 1, lz, B.STONE_BRICK)
				if (lx + lz) % 2 == 0:
					wr.put(lx, h + 2, lz, B.STONE_BRICK)
	# Tabique entre las celdas y frente enrejado
	for ly in range(0, h):
		for lz2 in range(26, z1):
			wr.put(30, ly, lz2, B.STONE_BRICK)
		for lx2: int in [28, 29, 31, 32]:
			wr.put(lx2, ly, 26, B.IRON_BARS)
	for cell: Array in CELLS:
		var door: Vector2i = cell[1]
		wr.put(door.x, 0, door.y, B.AIR)
		wr.put(door.x, 1, door.y, B.AIR)
		var inner: Vector4i = cell[0]
		wr.entity("bedroll", Vector3(inner.x + 0.6, 0.0, inner.w - 0.3), 0.0, {"uid": "cell_bed_%d" % inner.x})
		wr.entity("bucket", Vector3(inner.z + 0.6, 0.0, inner.w + 0.5), 0.0, {"uid": "cell_bucket_%d" % inner.x})
	wr.entity("cell_door", Vector3(29.5, 0.0, 26.5), 0.0, {"uid": "cell_a", "lock": 55, "key": "key_calabozo"})
	wr.entity("cell_door", Vector3(31.5, 0.0, 26.5), 0.0, {"uid": "cell_b", "lock": 55, "key": "key_calabozo"})
	# Ventanucos enrejados y puerta al patio (fachada norte)
	for lx3: int in [28, 32]:
		wr.put(lx3, 2, z1, B.IRON_BARS)
	wr.put(x0, 2, 24, B.IRON_BARS)
	var jd := JAIL_DOOR
	wr.clear(jd.x, 0, jd.y, jd.x, 1, jd.y)
	wr.put(jd.x, 2, jd.y, B.CHISELED)
	wr.entity("door", Vector3(jd.x + 0.5, 0.0, jd.y + 0.5), 0.0, {"uid": "jail_door"})
	wr.entity("wall_lantern", Vector3(jd.x - 0.5, 2.4, jd.y - 0.12), 0.0, {"uid": "jail_lamp_out"})
	wr.entity("sign", Vector3(jd.x + 2.6, 2.7, jd.y - 0.55), 0.0, {"uid": "jail_sign", "text": "Calabozo"})
	# Puesto del carcelero
	wr.entity("table", Vector3(31.0, 0.0, 23.0), 0.0, {"uid": "jail_table"})
	wr.entity("chair", Vector3(31.0, 0.0, 24.0), 0.0, {"uid": "jail_chair"})
	wr.entity("chest", Vector3(32.4, 0.0, 22.6), -90.0, {"uid": "jail_chest", "loot": "castle", "lock": 40})
	wr.entity("lantern", Vector3(30.5, h - 1.05, 24.0), 0.0, {"uid": "jail_lamp"})


# ---------------------------------------------------------------------------
# Patio: pozo y farolas van aparte; aquí el campo de entrenamiento, el huerto
# del hermano Anselmo, leña, carros y abrevadero
# ---------------------------------------------------------------------------

static func _yard(wr: ChunkWriter, _s: Dictionary) -> void:
	# Campo de entrenamiento: tierra batida con muñecos de paja
	for lz in range(18, 22):
		for lx in range(6, 13):
			wr.put(lx, -1, lz, B.PATH)
	for i in 3:
		wr.entity("training_dummy", Vector3(7.5 + i * 2.0, 0.0, 19.5), 0.0, {"uid": "dummy_%d" % i})
	wr.entity("weapon_rack", Vector3(12.4, 0.0, 21.2), -90.0, {"uid": "yard_rack"})
	# Huerto con cerca
	for lz2 in range(28, 32):
		for lx2 in range(6, 12):
			wr.put(lx2, -1, lz2, B.DIRT if (lx2 + lz2) % 3 else B.MUD)
			if lz2 == 28 or lz2 == 31 or lx2 == 6 or lx2 == 11:
				wr.put(lx2, 0, lz2, B.FENCE if not (lz2 == 28 and lx2 == 9) else B.AIR)
			else:
				var plant := [B.CROP, B.FLOWER_BLUE, B.BUSH, B.FLOWER_YELLOW][(lx2 * 7 + lz2) % 4] as int
				wr.put(lx2, 0, lz2, plant)
	# Pertrechos junto al cuartel y la armería
	wr.entity("hay_cart", Vector3(32.0, 0.0, 17.2), 75.0, {"uid": "cart"})
	wr.entity("barrel", Vector3(13.6, 0.0, 6.2), 0.0, {"uid": "yard_barrel_1"})
	wr.entity("barrel", Vector3(13.6, 0.0, 7.3), 0.0, {"uid": "yard_barrel_2"})
	wr.entity("crate", Vector3(24.6, 0.0, 6.3), 15.0, {"uid": "yard_crate_1"})
	wr.entity("sack", Vector3(25.5, 0.0, 6.6), 0.0, {"uid": "yard_sack"})
	wr.entity("banner", Vector3(19.5, 5.6, GATE.end.y + 0.08), 180.0, {"uid": "gate_banner_in", "kind": "penalba"})
