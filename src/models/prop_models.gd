class_name PropModels
extends RefCounted
## Mobiliario y objetos decorativos en micro-vóxeles (1/16 m). El origen de
## cada modelo está en el centro de su base.

const V := 1.0 / 16.0


static func _wood(m: VoxelModel) -> Dictionary:
	return {
		"wood": m.mat(Color(0.55, 0.38, 0.22), 0.0, 0.85, 0.0, 0.07),
		"wood_lt": m.mat(Color(0.64, 0.46, 0.27), 0.0, 0.85, 0.0, 0.07),
		"wood_dk": m.mat(Color(0.36, 0.24, 0.13), 0.0, 0.85, 0.0, 0.06),
		"iron": m.mat(Color(0.3, 0.31, 0.33), 0.8, 0.5, 0.0, 0.06),
		"brass": m.mat(Color(0.76, 0.6, 0.28), 0.9, 0.35, 0.0, 0.05),
	}


static func barrel() -> VoxelModel:
	var m := VoxelModel.new(V, 101)
	var c := _wood(m)
	var p := m.part("body", "", Vector3.ZERO)
	for y in range(0, 15):
		var bulge := 5.2 + sin(PI * y / 14.0) * 0.9
		for a in 48:
			var ang := TAU * a / 48.0
			var x := int(round(-0.5 + cos(ang) * bulge))
			var z := int(round(-0.5 + sin(ang) * bulge))
			var stave := (a / 4) % 2
			p.put(Vector3i(x, y, z), c["wood"] if stave == 0 else c["wood_lt"])
	p.cylinder_y(-0.5, -0.5, 5.0, 14, 14, c["wood_dk"])
	p.cylinder_y(-0.5, -0.5, 5.0, 0, 0, c["wood_dk"])
	for y: int in [2, 12]:
		for a in 48:
			var ang2 := TAU * a / 48.0
			var r := 5.2 + sin(PI * y / 14.0) * 0.9 + 0.4
			p.put(Vector3i(int(round(-0.5 + cos(ang2) * r)), y, int(round(-0.5 + sin(ang2) * r))), c["iron"])
	return m


static func crate() -> VoxelModel:
	var m := VoxelModel.new(V, 102)
	var c := _wood(m)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-6, 0, -6), Vector3i(5, 11, 5), c["wood"])
	for y in range(0, 12, 3):
		p.recolor_box(Vector3i(-6, y, -6), Vector3i(5, y, 5), c["wood_lt"])
	# Marco oscuro en aristas
	for e in range(-6, 6):
		for corner: Vector2i in [Vector2i(-6, -6), Vector2i(5, -6), Vector2i(-6, 5), Vector2i(5, 5)]:
			p.put(Vector3i(corner.x, e + 6, corner.y), c["wood_dk"])
		p.put(Vector3i(e, 0, -6), c["wood_dk"])
		p.put(Vector3i(e, 11, -6), c["wood_dk"])
		p.put(Vector3i(e, 0, 5), c["wood_dk"])
		p.put(Vector3i(e, 11, 5), c["wood_dk"])
		p.put(Vector3i(-6, 11, e), c["wood_dk"])
		p.put(Vector3i(5, 11, e), c["wood_dk"])
	p.line(Vector3(-5, 1, -7), Vector3(4, 10, -7), c["wood_dk"])
	p.line(Vector3(-5, 1, 6), Vector3(4, 10, 6), c["wood_dk"])
	return m


static func table() -> VoxelModel:
	var m := VoxelModel.new(V, 103)
	var c := _wood(m)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-9, 11, -6), Vector3i(8, 12, 5), c["wood_lt"])
	for x in range(-9, 9, 3):
		p.recolor_box(Vector3i(x, 12, -6), Vector3i(x, 12, 5), c["wood"])
	for leg: Vector2i in [Vector2i(-8, -5), Vector2i(6, -5), Vector2i(-8, 3), Vector2i(6, 3)]:
		p.box(Vector3i(leg.x, 0, leg.y), Vector3i(leg.x + 1, 10, leg.y + 1), c["wood_dk"])
	p.box(Vector3i(-7, 3, -5), Vector3i(6, 3, -5), c["wood_dk"])
	p.box(Vector3i(-7, 3, 4), Vector3i(6, 3, 4), c["wood_dk"])
	# Jarra y plato
	var mug := m.mat(Color(0.5, 0.45, 0.4), 0.2, 0.6, 0.0, 0.05)
	p.box(Vector3i(3, 13, -2), Vector3i(4, 15, -1), mug)
	p.put(Vector3i(5, 14, -2), mug)
	var plate := m.mat(Color(0.8, 0.78, 0.7), 0.0, 0.5, 0.0, 0.03)
	var bread := m.mat(Color(0.72, 0.5, 0.25), 0.0, 0.9, 0.0, 0.06)
	p.box(Vector3i(-5, 13, -2), Vector3i(-2, 13, 1), plate)
	p.box(Vector3i(-4, 14, -1), Vector3i(-3, 14, 0), bread)
	return m


static func chair() -> VoxelModel:
	var m := VoxelModel.new(V, 104)
	var c := _wood(m)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-4, 7, -4), Vector3i(3, 7, 3), c["wood_lt"])
	for leg: Vector2i in [Vector2i(-4, -4), Vector2i(3, -4), Vector2i(-4, 3), Vector2i(3, 3)]:
		p.box(Vector3i(leg.x, 0, leg.y), Vector3i(leg.x, 6, leg.y), c["wood_dk"])
	p.box(Vector3i(-4, 8, 3), Vector3i(-4, 15, 3), c["wood_dk"])
	p.box(Vector3i(3, 8, 3), Vector3i(3, 15, 3), c["wood_dk"])
	p.box(Vector3i(-3, 12, 3), Vector3i(2, 14, 3), c["wood"])
	return m


static func bed() -> VoxelModel:
	var m := VoxelModel.new(V, 105)
	var c := _wood(m)
	var sheet := m.mat(Color(0.86, 0.83, 0.74), 0.0, 0.95, 0.0, 0.04)
	var blanket := m.mat(Color(0.55, 0.14, 0.12), 0.0, 0.95, 0.0, 0.06)
	var blanket2 := m.mat(Color(0.7, 0.55, 0.25), 0.0, 0.95, 0.0, 0.06)
	var p := m.part("body", "", Vector3.ZERO)
	# Cama de 1 x 2 m a lo largo de Z
	p.box(Vector3i(-8, 2, -16), Vector3i(7, 4, 15), c["wood"])
	p.box(Vector3i(-7, 5, -15), Vector3i(6, 6, 14), sheet)
	p.box(Vector3i(-8, 6, -6), Vector3i(7, 7, 15), blanket)
	for z in range(-6, 16, 4):
		p.recolor_box(Vector3i(-8, 7, z), Vector3i(7, 7, z), blanket2)
	p.box(Vector3i(-5, 7, -14), Vector3i(4, 8, -10), sheet)
	for leg: Vector2i in [Vector2i(-8, -16), Vector2i(7, -16), Vector2i(-8, 15), Vector2i(7, 15)]:
		p.box(Vector3i(leg.x, 0, leg.y), Vector3i(leg.x, 1, leg.y), c["wood_dk"])
	p.box(Vector3i(-8, 2, -17), Vector3i(7, 12, -17), c["wood_dk"])
	p.box(Vector3i(-8, 2, 16), Vector3i(7, 8, 16), c["wood_dk"])
	return m


## Cofre con tapa separada (pieza "lid" con bisagra trasera en el origen).
static func chest() -> VoxelModel:
	var m := VoxelModel.new(V, 106)
	var c := _wood(m)
	var gold := m.mat(Color(0.95, 0.78, 0.25), 1.0, 0.25, 0.15, 0.05)
	var base := m.part("base", "", Vector3.ZERO)
	base.box(Vector3i(-7, 0, -5), Vector3i(6, 7, 4), c["wood"])
	base.erase_box(Vector3i(-6, 2, -4), Vector3i(5, 7, 3))
	base.box(Vector3i(-6, 1, -4), Vector3i(5, 3, 3), gold)
	for x: int in [-6, 5]:
		base.recolor_box(Vector3i(x, 0, -5), Vector3i(x, 7, 4), c["iron"])
	base.recolor_box(Vector3i(-7, 0, -5), Vector3i(6, 0, 4), c["wood_dk"])
	# Tapa: el origen de la pieza está en la bisagra (borde trasero superior)
	var lid := m.part("lid", "", Vector3(0, 8 * V, 4.5 * V))
	lid.box(Vector3i(-7, 0, -10), Vector3i(6, 3, -1), c["wood"])
	lid.box(Vector3i(-6, 4, -9), Vector3i(5, 4, -2), c["wood_lt"])
	for x2: int in [-6, 5]:
		lid.recolor_box(Vector3i(x2, 0, -10), Vector3i(x2, 4, -1), c["iron"])
	lid.box(Vector3i(-1, -2, -11), Vector3i(0, 1, -11), c["brass"])
	return m


static func anvil() -> VoxelModel:
	var m := VoxelModel.new(V, 107)
	var c := _wood(m)
	var steel := m.mat(Color(0.25, 0.26, 0.29), 0.9, 0.4, 0.0, 0.05)
	var p := m.part("body", "", Vector3.ZERO)
	p.cylinder_y(-0.5, -0.5, 4.5, 0, 6, c["wood_dk"])
	p.box(Vector3i(-3, 7, -2), Vector3i(2, 8, 1), steel)
	p.box(Vector3i(-2, 9, -1), Vector3i(1, 10, 0), steel)
	p.box(Vector3i(-6, 11, -2), Vector3i(5, 12, 1), steel)
	p.box(Vector3i(6, 11, -1), Vector3i(8, 12, 0), steel)
	p.put(Vector3i(9, 12, 0), steel)
	# Martillo encima
	p.box(Vector3i(-3, 13, -3), Vector3i(3, 13, -3), c["wood"])
	p.box(Vector3i(-5, 13, -4), Vector3i(-4, 14, -2), steel)
	return m


static func lantern(wall_mounted: bool = false) -> VoxelModel:
	var m := VoxelModel.new(V, 108)
	var c := _wood(m)
	var glow := m.mat(Color(1.0, 0.75, 0.35), 0.0, 0.5, 1.0, 0.05)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-2, 0, -2), Vector3i(1, 0, 1), c["iron"])
	p.box(Vector3i(-2, 5, -2), Vector3i(1, 5, 1), c["iron"])
	p.box(Vector3i(-1, 6, -1), Vector3i(0, 6, 0), c["iron"])
	for corner: Vector2i in [Vector2i(-2, -2), Vector2i(1, -2), Vector2i(-2, 1), Vector2i(1, 1)]:
		p.box(Vector3i(corner.x, 1, corner.y), Vector3i(corner.x, 4, corner.y), c["iron"])
	p.box(Vector3i(-1, 1, -1), Vector3i(0, 4, 0), glow)
	if wall_mounted:
		p.box(Vector3i(-1, 7, -1), Vector3i(0, 7, 4), c["iron"])
		p.box(Vector3i(-1, 3, 4), Vector3i(0, 8, 4), c["iron"])
	else:
		p.box(Vector3i(-1, 7, -1), Vector3i(-1, 12, -1), c["iron"])
	return m


static func bucket() -> VoxelModel:
	var m := VoxelModel.new(V, 109)
	var c := _wood(m)
	var water := m.mat(Color(0.25, 0.45, 0.7), 0.0, 0.2, 0.0, 0.05)
	var p := m.part("body", "", Vector3.ZERO)
	p.cylinder_y(-0.5, -0.5, 3.0, 0, 5, c["wood"])
	p.cylinder_y(-0.5, -0.5, 2.0, 5, 5, water)
	p.cylinder_y(-0.5, -0.5, 3.2, 1, 1, c["iron"])
	p.cylinder_y(-0.5, -0.5, 3.2, 4, 4, c["iron"])
	p.line(Vector3(-3, 5, -0.5), Vector3(-0.5, 9, -0.5), c["iron"])
	p.line(Vector3(2, 5, -0.5), Vector3(-0.5, 9, -0.5), c["iron"])
	return m


static func sign_board() -> VoxelModel:
	var m := VoxelModel.new(V, 110)
	var c := _wood(m)
	var paint := m.mat(Color(0.85, 0.7, 0.3), 0.3, 0.6, 0.0, 0.05)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-8, -10, -1), Vector3i(7, -1, 0), c["wood"])
	p.box(Vector3i(-8, -10, -1), Vector3i(7, -10, 0), c["wood_dk"])
	p.box(Vector3i(-8, -1, -1), Vector3i(7, -1, 0), c["wood_dk"])
	# Jarra pintada
	p.box(Vector3i(-2, -8, -2), Vector3i(1, -3, -2), paint)
	p.box(Vector3i(2, -7, -2), Vector3i(3, -5, -2), paint)
	p.line(Vector3(-6, 0, -0.5), Vector3(-6, 3, -0.5), c["iron"])
	p.line(Vector3(5, 0, -0.5), Vector3(5, 3, -0.5), c["iron"])
	p.box(Vector3i(-8, 4, -1), Vector3i(7, 4, 6), c["wood_dk"])
	return m


static func weapon_rack() -> VoxelModel:
	var m := VoxelModel.new(V, 111)
	var c := _wood(m)
	var steel := m.mat(Color(0.75, 0.77, 0.8), 0.9, 0.3, 0.0, 0.04)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-12, 0, -2), Vector3i(-11, 22, -1), c["wood_dk"])
	p.box(Vector3i(10, 0, -2), Vector3i(11, 22, -1), c["wood_dk"])
	p.box(Vector3i(-12, 6, -2), Vector3i(11, 6, -1), c["wood"])
	p.box(Vector3i(-12, 18, -2), Vector3i(11, 18, -1), c["wood"])
	for k in 3:
		var x := -7 + k * 7
		p.box(Vector3i(x, 4, -3), Vector3i(x, 25, -3), steel)
		p.box(Vector3i(x - 2, 8, -3), Vector3i(x + 2, 8, -3), c["brass"])
		p.box(Vector3i(x, 3, -3), Vector3i(x, 7, -3), c["wood_dk"])
	return m


static func banner() -> VoxelModel:
	var m := VoxelModel.new(V, 112)
	var cloth := m.mat(Color(0.48, 0.1, 0.1), 0.0, 0.95, 0.0, 0.07)
	var emblem := m.mat(Color(0.88, 0.72, 0.28), 0.2, 0.7, 0.0, 0.05)
	var c := _wood(m)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-7, 0, 0), Vector3i(6, 0, 1), c["wood_dk"])
	for y in range(-24, 0):
		for x in range(-6, 6):
			if y < -20 and absi(x + 0.5) > (y + 26) * 1.2:
				continue
			p.put(Vector3i(x, y, 0), cloth)
	# Emblema: árbol (hoja roja de Hojarrubia)
	p.box(Vector3i(-1, -18, -1), Vector3i(0, -8, -1), emblem)
	p.ellipsoid(Vector3(-0.5, -8.0, -1.0), Vector3(4.0, 3.5, 0.4), emblem)
	p.box(Vector3i(-3, -18, -1), Vector3i(2, -18, -1), emblem)
	return m


static func goods(kind: String) -> VoxelModel:
	var m := VoxelModel.new(V, 113)
	var p := m.part("body", "", Vector3.ZERO)
	if kind == "cloth":
		var cols := [Color(0.3, 0.4, 0.7), Color(0.6, 0.2, 0.2), Color(0.3, 0.55, 0.3)]
		for k in 3:
			var mi := m.mat(cols[k], 0.0, 0.95, 0.0, 0.05)
			p.cylinder_x(2.0, -6.0 + k * 5.0, 2.0, -6, 5, mi)
	else:
		var apple := m.mat(Color(0.75, 0.15, 0.1), 0.0, 0.5, 0.0, 0.08)
		var bread := m.mat(Color(0.75, 0.52, 0.26), 0.0, 0.9, 0.0, 0.06)
		var basket := m.mat(Color(0.6, 0.45, 0.25), 0.0, 0.9, 0.0, 0.08)
		p.box(Vector3i(-8, 0, -3), Vector3i(-2, 2, 3), basket)
		p.ellipsoid(Vector3(-5, 3, 0), Vector3(2.5, 1.2, 2.5), apple)
		p.box(Vector3i(1, 0, -2), Vector3i(7, 2, 1), bread)
		p.box(Vector3i(2, 3, -1), Vector3i(6, 3, 0), bread)
	return m


static func hay_cart() -> VoxelModel:
	var m := VoxelModel.new(V, 114)
	var c := _wood(m)
	var hay := m.mat(Color(0.82, 0.68, 0.3), 0.0, 0.95, 0.0, 0.1)
	var p := m.part("body", "", Vector3.ZERO)
	p.box(Vector3i(-10, 8, -16), Vector3i(9, 9, 15), c["wood"])
	p.box(Vector3i(-10, 10, -16), Vector3i(-10, 14, 15), c["wood_dk"])
	p.box(Vector3i(9, 10, -16), Vector3i(9, 14, 15), c["wood_dk"])
	p.ellipsoid(Vector3(-0.5, 13.0, 0.0), Vector3(9.0, 6.0, 15.0), hay)
	for side: int in [-12, 11]:
		for wz: int in [-9, 9]:
			for a in 40:
				var ang := TAU * a / 40.0
				p.put(Vector3i(side, int(round(6 + sin(ang) * 6.0)), int(round(wz + cos(ang) * 6.0))), c["wood_dk"])
			p.cylinder_x(6.0, wz, 1.0, side, side, c["iron"])
	p.box(Vector3i(-1, 6, -28), Vector3i(0, 7, -16), c["wood_dk"])
	return m


## Puerta de 1 x 2 bloques. Origen en la bisagra (borde -X, abajo, centro Z).
static func door(dark: bool = false) -> VoxelModel:
	var m := VoxelModel.new(V, 115)
	var c := _wood(m)
	var plank: int = c["wood_dk"] if dark else c["wood"]
	var plank2: int = c["wood"] if dark else c["wood_lt"]
	var p := m.part("body", "", Vector3.ZERO)
	for x in range(0, 16):
		p.box(Vector3i(x, 0, -1), Vector3i(x, 31, 0), plank if (x / 4) % 2 == 0 else plank2)
	for y: int in [4, 27]:
		p.box(Vector3i(0, y, -2), Vector3i(13, y + 1, -2), c["iron"])
		p.box(Vector3i(0, y, 1), Vector3i(13, y + 1, 1), c["iron"])
	p.line(Vector3(2, 6, -2), Vector3(13, 25, -2), plank2)
	p.box(Vector3i(13, 14, -3), Vector3i(13, 16, -3), c["brass"])
	p.box(Vector3i(13, 14, 2), Vector3i(13, 16, 2), c["brass"])
	return m


static func forge_coals() -> VoxelModel:
	var m := VoxelModel.new(V, 116)
	var coal := m.mat(Color(0.12, 0.1, 0.09), 0.0, 0.9, 0.0, 0.1)
	var ember := m.mat(Color(1.0, 0.4, 0.1), 0.0, 0.6, 1.0, 0.15)
	var ember2 := m.mat(Color(1.0, 0.7, 0.2), 0.0, 0.6, 1.0, 0.1)
	var p := m.part("body", "", Vector3.ZERO)
	for x in range(-6, 6):
		for z in range(-6, 6):
			var h := WorldGenerator.hash2(x, z, 3) % 3
			for y in h + 1:
				var r := WorldGenerator.hash2(x, z + y * 7, 5) % 5
				p.put(Vector3i(x, y, z), ember if r == 0 else (ember2 if r == 1 else coal))
	return m


## Devuelve el modelo por nombre de entidad.
static func by_name(prop: String, extra: Dictionary = {}) -> VoxelModel:
	match prop:
		"barrel":
			return barrel()
		"crate":
			return crate()
		"table":
			return table()
		"chair":
			return chair()
		"bed":
			return bed()
		"chest":
			return chest()
		"anvil":
			return anvil()
		"lantern":
			return lantern(false)
		"wall_lantern":
			return lantern(true)
		"bucket":
			return bucket()
		"sign":
			return sign_board()
		"weapon_rack":
			return weapon_rack()
		"banner":
			return banner()
		"goods":
			return goods(str(extra.get("kind", "food")))
		"hay_cart":
			return hay_cart()
		"door":
			return door(false)
		"dungeon_door":
			return door(true)
		"forge_fire":
			return forge_coals()
	return null
