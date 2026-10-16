class_name WeaponModels
extends RefCounted
## Armas en micro-vóxeles (1/40 m). Marco local: origen en el centro de la
## empuñadura, hoja/cabeza hacia +Y, filos hacia ±X, grosor en Z.

const V := 1.0 / 40.0


static func _mats(m: VoxelModel, rusty: bool) -> Dictionary:
	var steel_col := Color(0.62, 0.6, 0.55) if rusty else Color(0.78, 0.8, 0.84)
	return {
		"steel": m.mat(steel_col, 0.9 if not rusty else 0.6, 0.32 if not rusty else 0.6, 0.0, 0.05),
		"edge": m.mat(steel_col.lightened(0.25), 0.95, 0.25, 0.0, 0.03),
		"fuller": m.mat(steel_col.darkened(0.25), 0.9, 0.35, 0.0, 0.03),
		"rust": m.mat(Color(0.5, 0.3, 0.18), 0.5, 0.7, 0.0, 0.12),
		"brass": m.mat(Color(0.78, 0.6, 0.28), 0.9, 0.35, 0.0, 0.05),
		"grip": m.mat(Color(0.3, 0.18, 0.1), 0.0, 0.75, 0.0, 0.05),
		"grip_dk": m.mat(Color(0.18, 0.1, 0.05), 0.0, 0.8, 0.0, 0.05),
		"wood": m.mat(Color(0.48, 0.32, 0.18), 0.0, 0.8, 0.0, 0.08),
		"wood_dk": m.mat(Color(0.33, 0.21, 0.11), 0.0, 0.85, 0.0, 0.06),
		"iron": m.mat(Color(0.36, 0.37, 0.4), 0.85, 0.5, 0.0, 0.06),
	}


static func sword(rusty: bool = false) -> VoxelModel:
	var m := VoxelModel.new(V, 11 if rusty else 12)
	var c := _mats(m, rusty)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	# Empuñadura con tiras de cuero
	for y in range(-3, 4):
		p.box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["grip"] if y % 2 == 0 else c["grip_dk"])
	p.box(Vector3i(-1, -5, -1), Vector3i(0, -4, 0), c["brass"])          # pomo
	p.box(Vector3i(-2, -5, -1), Vector3i(1, -5, 0), c["brass"])
	# Guarda en cruz
	p.box(Vector3i(-6, 4, -1), Vector3i(5, 5, 0), c["steel"])
	p.put(Vector3i(-7, 5, -1), c["brass"])
	p.put(Vector3i(6, 5, 0), c["brass"])
	# Hoja con filos claros y acanaladura oscura
	for y in range(6, 36):
		var half := 2 if y < 32 else (1 if y < 34 else 0)
		p.box(Vector3i(-half, y, -1), Vector3i(half - 1 if half > 0 else 0, y, 0), c["steel"])
		if half >= 2:
			p.put(Vector3i(-half, y, -1), c["edge"])
			p.put(Vector3i(half - 1, y, 0), c["edge"])
			p.put(Vector3i(-half, y, 0), c["edge"])
			p.put(Vector3i(half - 1, y, -1), c["edge"])
			if y < 28:
				p.put(Vector3i(-1, y, -1), c["fuller"])
				p.put(Vector3i(0, y, 0), c["fuller"])
		if rusty and WorldGenerator.hash2(y, 3, 77) % 4 == 0:
			p.put(Vector3i(-1 + y % 2, y, -1), c["rust"])
	return m


## Espada de Hierronegro: acero pavonado casi negro con filos brillantes,
## guarda de plata con gavilanes curvos y empuñadura azul de Peñalba.
static func sword_penalba() -> VoxelModel:
	var m := VoxelModel.new(V, 13)
	var steel := m.mat(Color(0.28, 0.31, 0.37), 0.9, 0.3, 0.0, 0.05)
	var edge := m.mat(Color(0.84, 0.87, 0.92), 0.95, 0.2, 0.0, 0.03)
	var fuller := m.mat(Color(0.16, 0.18, 0.23), 0.9, 0.35, 0.0, 0.03)
	var silver := m.mat(Color(0.8, 0.82, 0.86), 0.95, 0.25, 0.0, 0.04)
	var blue := m.mat(Color(0.16, 0.26, 0.55), 0.0, 0.7, 0.0, 0.05)
	var blue_dk := m.mat(Color(0.1, 0.16, 0.36), 0.0, 0.75, 0.0, 0.05)
	var gem := m.mat(Color(0.3, 0.5, 1.0), 0.3, 0.2, 0.6, 0.0)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	for y in range(-3, 4):
		p.box(Vector3i(-1, y, -1), Vector3i(0, y, 0), blue if y % 2 == 0 else blue_dk)
	p.box(Vector3i(-2, -6, -1), Vector3i(1, -4, 0), silver)
	p.put(Vector3i(-1, -5, -2), gem)
	p.put(Vector3i(0, -5, 1), gem)
	# Guarda con gavilanes curvados hacia la hoja y una gema central
	p.box(Vector3i(-6, 4, -1), Vector3i(5, 5, 0), silver)
	p.box(Vector3i(-7, 6, -1), Vector3i(-7, 7, 0), silver)
	p.box(Vector3i(6, 6, -1), Vector3i(6, 7, 0), silver)
	p.put(Vector3i(-1, 5, -2), gem)
	p.put(Vector3i(0, 5, 1), gem)
	for y2 in range(6, 37):
		var half := 2 if y2 < 33 else (1 if y2 < 35 else 0)
		p.box(Vector3i(-half, y2, -1), Vector3i(half - 1 if half > 0 else 0, y2, 0), steel)
		if half >= 2:
			p.put(Vector3i(-half, y2, -1), edge)
			p.put(Vector3i(half - 1, y2, 0), edge)
			p.put(Vector3i(-half, y2, 0), edge)
			p.put(Vector3i(half - 1, y2, -1), edge)
			if y2 < 30:
				p.put(Vector3i(-1, y2, -1), fuller)
				p.put(Vector3i(0, y2, 0), fuller)
	return m


static func dagger() -> VoxelModel:
	var m := VoxelModel.new(V, 21)
	var c := _mats(m, false)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	for y in range(-2, 3):
		p.box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["grip"] if y % 2 == 0 else c["grip_dk"])
	p.box(Vector3i(-1, -3, -1), Vector3i(0, -3, 0), c["brass"])
	p.box(Vector3i(-3, 3, -1), Vector3i(2, 3, 0), c["brass"])
	for y in range(4, 17):
		var half := 2 if y < 13 else 1
		if y >= 16:
			half = 0
		p.box(Vector3i(-half, y, -1), Vector3i(maxi(half - 1, 0), y, -1 if half == 0 else 0), c["steel"])
		if half > 0:
			p.put(Vector3i(-half, y, 0), c["edge"])
	return m


static func axe() -> VoxelModel:
	var m := VoxelModel.new(V, 31)
	var c := _mats(m, false)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	for y in range(-6, 24):
		p.box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["wood"] if y % 5 != 0 else c["wood_dk"])
	for y in range(-4, 2):
		p.recolor_box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["grip"] if y % 2 == 0 else c["grip_dk"])
	# Cabeza: cuña de hierro con filo curvo hacia +X y punta trasera
	for y in range(16, 26):
		var reach := 3 + int(5.0 * sin(PI * float(y - 16) / 9.0))
		p.box(Vector3i(1, y, -1), Vector3i(reach, y, 0), c["iron"])
		p.put(Vector3i(reach + 1, y, -1), c["edge"])
		p.put(Vector3i(reach + 1, y, 0), c["edge"])
	p.box(Vector3i(-1, 18, -2), Vector3i(0, 23, 1), c["iron"])
	p.box(Vector3i(-4, 19, -1), Vector3i(-2, 21, 0), c["iron"])
	p.put(Vector3i(-5, 20, -1), c["steel"])
	return m


static func mace() -> VoxelModel:
	var m := VoxelModel.new(V, 41)
	var c := _mats(m, false)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	for y in range(-5, 18):
		p.box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["wood_dk"])
	for y in range(-4, 2):
		p.recolor_box(Vector3i(-1, y, -1), Vector3i(0, y, 0), c["grip"] if y % 2 == 0 else c["grip_dk"])
	p.box(Vector3i(-1, -6, -1), Vector3i(0, -6, 0), c["iron"])
	# Cabeza con aletas
	p.ellipsoid(Vector3(-0.5, 21.0, -0.5), Vector3(3.2, 4.0, 3.2), c["iron"])
	for k in 4:
		var dir := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][k] as Vector2i
		for y in range(18, 25):
			for r in range(3, 6):
				var x := int(round(-0.5 + dir.x * r))
				var z := int(round(-0.5 + dir.y * r))
				p.put(Vector3i(x, y, z), c["steel"])
	p.box(Vector3i(-1, 25, -1), Vector3i(0, 26, 0), c["steel"])
	return m


static func bow() -> VoxelModel:
	var m := VoxelModel.new(V, 51)
	var c := _mats(m, false)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	# Palas curvas (arco en el plano YZ, hacia -Z)
	for y in range(-26, 27):
		var t := float(y) / 26.0
		var z := int(round(-5.0 * (1.0 - t * t) + 5.0))
		var col: int = c["wood"] if absi(y) % 6 != 0 else c["wood_dk"]
		p.box(Vector3i(-1, y, z - 1), Vector3i(0, y, z), col)
	for y in range(-3, 4):
		p.recolor_box(Vector3i(-1, y, -2), Vector3i(0, y, 6), c["grip"] if y % 2 == 0 else c["grip_dk"])
	p.box(Vector3i(-1, 25, 4), Vector3i(0, 27, 6), c["brass"])
	p.box(Vector3i(-1, -27, 4), Vector3i(0, -25, 6), c["brass"])
	return m


static func arrow() -> VoxelModel:
	var m := VoxelModel.new(V, 61)
	var c := _mats(m, false)
	var feather := m.mat(Color(0.85, 0.82, 0.75), 0.0, 0.9, 0.0, 0.05)
	var feather2 := m.mat(Color(0.6, 0.15, 0.1), 0.0, 0.9, 0.0, 0.05)
	var p := m.part("arrow", "arrow", Vector3.ZERO)
	for z in range(-14, 16):
		p.put(Vector3i(0, 0, z), c["wood"])
	p.put(Vector3i(0, 0, -15), c["steel"])
	p.box(Vector3i(0, -1, -17), Vector3i(0, 1, -16), c["steel"])
	p.put(Vector3i(0, 0, -18), c["edge"])
	for z in range(10, 15):
		p.put(Vector3i(0, 1, z), feather if z % 2 == 0 else feather2)
		p.put(Vector3i(0, -1, z), feather)
		p.put(Vector3i(1, 0, z), feather2)
	return m


static func shield() -> VoxelModel:
	var m := VoxelModel.new(V, 71)
	var c := _mats(m, false)
	var paint := m.mat(Color(0.5, 0.12, 0.1), 0.0, 0.85, 0.0, 0.08)
	var paint2 := m.mat(Color(0.82, 0.68, 0.3), 0.0, 0.85, 0.0, 0.06)
	var p := m.part("shield", "shield", Vector3.ZERO)
	var r := 12.0
	for y in range(-12, 13):
		for x in range(-12, 13):
			var d := Vector2(x + 0.5, y + 0.5).length()
			if d > r:
				continue
			var col: int = c["wood"] if (x / 3) % 2 == 0 else c["wood_dk"]
			if d < 9.5 and (absi(x) <= 1 or absi(y) <= 1):
				col = paint2
			elif d < 9.5 and d > 4.0:
				col = paint
			p.put(Vector3i(x, y, 0), col)
			if d > r - 1.5:
				p.put(Vector3i(x, y, 0), c["iron"])
				p.put(Vector3i(x, y, -1), c["iron"])
	p.ellipsoid(Vector3(-0.5, -0.5, -1.2), Vector3(3.0, 3.0, 2.0), c["iron"])
	p.box(Vector3i(-1, -4, 1), Vector3i(0, 3, 2), c["grip"])
	return m


## Escudo de cometa de hierro: borde remachado, banda central y umbo.
static func shield_iron() -> VoxelModel:
	var m := VoxelModel.new(V, 73)
	var c := _mats(m, false)
	var plate := m.mat(Color(0.52, 0.54, 0.58), 0.85, 0.4, 0.0, 0.05)
	var plate_dk := m.mat(Color(0.34, 0.35, 0.39), 0.85, 0.45, 0.0, 0.05)
	var paint := m.mat(Color(0.14, 0.22, 0.42), 0.2, 0.7, 0.0, 0.06)
	var gold := m.mat(Color(0.8, 0.65, 0.3), 0.9, 0.35, 0.0, 0.05)
	var p := m.part("shield", "shield", Vector3.ZERO)
	for y in range(-16, 12):
		# Mitad superior recta; la inferior se estrecha hasta la punta
		var half := 10.0 if y >= -2 else 10.0 * (1.0 - float(-2 - y) / 15.0)
		if y >= 9:
			half = 10.0 - (y - 8) * 1.2
		for x in range(-11, 11):
			var fx := absf(x + 0.5)
			if fx > half:
				continue
			var col := paint
			if fx > half - 1.6 or y >= 10 or y <= -15:
				col = plate_dk if (x + y) % 3 == 0 else plate
			elif absi(x) <= 1:
				col = gold
			p.put(Vector3i(x, y, 0), col)
			if fx > half - 1.6:
				p.put(Vector3i(x, y, -1), plate_dk)
	p.ellipsoid(Vector3(-0.5, 1.0, -1.0), Vector3(2.6, 2.6, 1.8), plate)
	p.box(Vector3i(-1, -3, 1), Vector3i(0, 4, 2), c["grip"])
	return m


static func staff() -> VoxelModel:
	var m := VoxelModel.new(V, 81)
	var c := _mats(m, false)
	var crystal := m.mat(Color(0.45, 0.7, 1.0), 0.2, 0.2, 0.9, 0.08)
	var p := m.part("weapon", "weapon", Vector3.ZERO)
	for y in range(-20, 30):
		var off := int(round(sin(y * 0.3) * 0.6))
		p.box(Vector3i(-1 + off, y, -1), Vector3i(0 + off, y, 0), c["wood"] if y % 7 != 0 else c["wood_dk"])
	for k in 3:
		var a := TAU * k / 3.0
		p.line(Vector3(-0.5, 29, -0.5), Vector3(-0.5 + cos(a) * 3.0, 34, -0.5 + sin(a) * 3.0), c["wood_dk"])
	p.ellipsoid(Vector3(-0.5, 34.0, -0.5), Vector3(1.8, 3.0, 1.8), crystal)
	return m


static func by_id(weapon_id: String) -> VoxelModel:
	match weapon_id:
		"sword":
			return sword(false)
		"rusty_sword":
			return sword(true)
		"sword_penalba":
			return sword_penalba()
		"dagger":
			return dagger()
		"axe":
			return axe()
		"mace":
			return mace()
		"bow":
			return bow()
		"shield":
			return shield()
		"shield_iron":
			return shield_iron()
		"staff":
			return staff()
	return sword(false)
