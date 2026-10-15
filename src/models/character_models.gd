class_name CharacterModels
extends RefCounted
## Modelos de personajes y criaturas en micro-vóxeles (1/24 m) para el rig
## humanoide. Cada pieza va unida rígidamente a un hueso.

const V := 1.0 / 24.0


static func _bone_shaft(p: VoxelModel.Part, y0: int, y1: int, m: int, knob: int) -> void:
	p.box(Vector3i(-1, y0, -1), Vector3i(0, y1, 0), m)
	# Cabezas articulares más anchas
	p.box(Vector3i(-1, y1 - 1, -1), Vector3i(0, y1, 0), knob)
	p.put(Vector3i(1, y1, -1), knob)
	p.put(Vector3i(-2, y1, 0), knob)
	p.put(Vector3i(1, y0, 0), knob)
	p.put(Vector3i(-2, y0, -1), knob)


## Guerrero esqueleto con espada oxidada y escudo (las armas se acoplan aparte).
static func skeleton_warrior(variant: int = 0) -> VoxelModel:
	var m := VoxelModel.new(V, 4242 + variant)
	var bone := m.mat(Color(0.86, 0.83, 0.73), 0.0, 0.75, 0.0, 0.07)
	var bone_dk := m.mat(Color(0.66, 0.62, 0.52), 0.0, 0.8, 0.0, 0.06)
	var crack := m.mat(Color(0.42, 0.38, 0.31), 0.0, 0.9, 0.0, 0.04)
	var socket := m.mat(Color(0.05, 0.045, 0.04), 0.0, 1.0, 0.0, 0.0)
	var lord := variant == 3
	var eye := m.mat(Color(1.0, 0.25, 0.15) if lord else Color(0.45, 0.95, 1.0), 0.0, 0.5, 1.0, 0.0)
	var gold := m.mat(Color(0.85, 0.66, 0.25), 0.95, 0.3, 0.0, 0.06)
	var gem := m.mat(Color(0.7, 0.1, 0.12), 0.3, 0.2, 0.6, 0.0)
	var rust := m.mat(Color(0.47, 0.32, 0.22), 0.55, 0.6, 0.0, 0.12)
	var iron := m.mat(Color(0.52, 0.53, 0.57), 0.85, 0.45, 0.0, 0.06)
	var cloth := m.mat(Color(0.26, 0.1, 0.32) if variant == 3 else Color(0.40, 0.11, 0.09), 0.0, 0.95, 0.0, 0.1)
	var leather := m.mat(Color(0.34, 0.21, 0.12), 0.0, 0.8, 0.0, 0.08)

	# --- Cráneo ---
	var head := m.part("skull", "head", Vector3(0, 1.56, 0))
	head.ellipsoid(Vector3(-0.5, 4.6, -0.3), Vector3(3.9, 3.6, 4.2), bone)
	head.box(Vector3i(-3, 0, -4), Vector3i(2, 2, 1), bone)        # mandíbula
	head.box(Vector3i(-4, 2, -3), Vector3i(3, 3, 0), bone)        # pómulos
	# Cuencas de los ojos y ojos brillantes al fondo
	for ex: int in [-3, 1]:
		head.erase_box(Vector3i(ex, 4, -5), Vector3i(ex + 1, 5, -3))
		head.put(Vector3i(ex, 4, -2), eye)
		head.put(Vector3i(ex + 1, 4, -2), eye)
		head.put(Vector3i(ex, 5, -2), socket)
		head.put(Vector3i(ex + 1, 5, -2), socket)
	head.put(Vector3i(-1, 3, -5), socket)
	head.put(Vector3i(0, 3, -5), socket)
	head.erase(Vector3i(-1, 3, -6))
	# Dientes
	for tx in range(-3, 3):
		head.put(Vector3i(tx, 2, -4), bone if tx % 2 == 0 else bone_dk)
		head.put(Vector3i(tx, 1, -4), socket if tx % 2 == 0 else bone)
	head.put(Vector3i(-2, 7, -2), crack)
	head.put(Vector3i(-1, 8, -1), crack)
	head.put(Vector3i(0, 8, 0), crack)
	head.put(Vector3i(1, 7, 1), crack)
	if lord:
		# Corona dorada con gemas
		for a in 28:
			var ang := TAU * a / 28.0
			var cx := int(round(-0.5 + cos(ang) * 4.2))
			var cz := int(round(-0.3 + sin(ang) * 4.4))
			head.put(Vector3i(cx, 7, cz), gold)
			if a % 4 == 0:
				head.put(Vector3i(cx, 8, cz), gold)
				head.put(Vector3i(cx, 9, cz), gem if a % 8 == 0 else gold)
	elif variant % 2 == 0:
		# Casco de hierro oxidado con nasal
		for p: Vector3i in head.voxels.keys():
			if p.y >= 6:
				head.voxels[p] = rust if (p.x + p.z) % 3 != 0 else iron
		head.ellipsoid(Vector3(-0.5, 6.2, -0.3), Vector3(4.6, 2.6, 4.8), rust)
		head.recolor_box(Vector3i(-6, 6, -6), Vector3i(5, 6, 5), iron)
		head.box(Vector3i(-1, 3, -6), Vector3i(0, 6, -6), iron)

	# --- Cuello ---
	var neck := m.part("neck", "neck", Vector3(0, 1.50, 0))
	neck.box(Vector3i(-1, 0, 0), Vector3i(0, 1, 1), bone_dk)
	neck.box(Vector3i(-2, 0, 0), Vector3i(1, 0, 1), bone)

	# --- Caja torácica ---
	var chest := m.part("ribcage", "chest", Vector3(0, 1.26, 0))
	for ry: int in [-3, -1, 1, 3]:
		var rx := 4.6 - (0.6 if ry < 0 else 0.0)
		var rz := 3.0 - (0.4 if ry < 0 else 0.0)
		for a in 40:
			var ang := TAU * a / 40.0
			var x := -0.5 + cos(ang) * rx
			var z := 0.4 + sin(ang) * rz
			if z < -1.8 and absf(x + 0.5) < 1.0:
				continue
			chest.put(Vector3i(roundi(x), ry, roundi(z)), bone)
	chest.box(Vector3i(-1, -3, -3), Vector3i(0, 4, -3), bone_dk)   # esternón
	chest.box(Vector3i(-1, -4, 2), Vector3i(0, 5, 3), bone_dk)     # columna
	chest.line(Vector3(-5, 5, -1), Vector3(4, 5, -1), bone)        # clavículas
	chest.box(Vector3i(-4, 1, 3), Vector3i(-2, 4, 3), bone)        # omóplatos
	chest.box(Vector3i(1, 1, 3), Vector3i(3, 4, 3), bone)
	# Hombrera oxidada (derecha) y correa de cuero
	chest.ellipsoid(Vector3(5.0, 5.0, 0.0), Vector3(2.6, 1.8, 2.8), rust)
	chest.recolor_box(Vector3i(3, 4, -3), Vector3i(8, 4, 3), iron)
	chest.line(Vector3(4, 4, -3), Vector3(-4, -4, -3), leather)
	chest.line(Vector3(4, 4, 4), Vector3(-4, -4, 4), leather)
	if lord:
		# Peto de hierro, segunda hombrera y capa raída
		chest.ellipsoid(Vector3(-6.0, 5.0, 0.0), Vector3(2.6, 1.8, 2.8), rust)
		for y in range(-3, 4):
			for x in range(-4, 4):
				chest.put(Vector3i(x, y, -4), iron if (x + y) % 3 != 0 else rust)
		chest.put(Vector3i(-1, 2, -5), gold)
		chest.put(Vector3i(0, 2, -5), gold)
		for y in range(-14, 5):
			for x in range(-5, 5):
				var torn := y < -10 and WorldGenerator.hash2(x, y, 99) % 3 == 0
				if not torn:
					chest.put(Vector3i(x, y, 5), cloth)

	# --- Lumbares ---
	var spine := m.part("spine", "spine", Vector3(0, 1.08, 0))
	for y in range(0, 5):
		var w := 1 if y % 2 == 0 else 0
		spine.box(Vector3i(-1 - w, y, 1), Vector3i(0 + w, y, 2), bone if y % 2 == 0 else bone_dk)

	# --- Pelvis, cinturón y taparrabos ---
	var hips := m.part("pelvis", "hips", Vector3(0, 0.95, 0))
	hips.box(Vector3i(-5, -1, -1), Vector3i(4, 1, 2), bone)
	hips.erase_box(Vector3i(-2, -1, -1), Vector3i(1, 0, 1))
	hips.box(Vector3i(-5, 2, -3), Vector3i(4, 2, 3), leather)
	hips.put(Vector3i(-1, 2, -4), iron)
	hips.put(Vector3i(0, 2, -4), iron)
	for side_z: int in [-3, 3]:
		for y in range(-8, 2):
			for x in range(-3, 3):
				var tattered := y < -5 and WorldGenerator.hash2(x + 7, y * 3 + side_z, 31 + variant) % 3 == 0
				if not tattered:
					hips.put(Vector3i(x, y, side_z), cloth)

	# --- Brazos ---
	for side: Array in [["R", 1.0], ["L", -1.0]]:
		var n: String = side[0]
		var sx: float = side[1]
		var ua := m.part("humerus." + n, "upper_arm." + n, Vector3(0.23 * sx, 1.44, 0))
		_bone_shaft(ua, -7, 0, bone, bone_dk)
		var fa := m.part("forearm." + n, "forearm." + n, Vector3(0.25 * sx, 1.15, 0))
		fa.box(Vector3i(-1, -6, 0), Vector3i(-1, 0, 0), bone)
		fa.box(Vector3i(0, -6, -1), Vector3i(0, 0, -1), bone)
		fa.box(Vector3i(-1, -1, -1), Vector3i(0, 0, 0), bone_dk)
		if n == "R":
			fa.box(Vector3i(-2, -5, -2), Vector3i(1, -2, 1), rust)
			fa.erase_box(Vector3i(-1, -5, -1), Vector3i(0, -2, 0))
			fa.box(Vector3i(-1, -5, -1), Vector3i(-1, -2, -1), bone)
		var hd := m.part("hand." + n, "hand." + n, Vector3(0.26 * sx, 0.90, 0))
		hd.box(Vector3i(-1, -2, -1), Vector3i(0, 0, 0), bone_dk)
		for fx: int in [-1, 0]:
			hd.box(Vector3i(fx, -4, -2), Vector3i(fx, -3, -2), bone)
			hd.put(Vector3i(fx, -3, -1), bone)
		hd.put(Vector3i(int(1 * sx) if sx > 0 else -2, -2, -1), bone)

	# --- Piernas ---
	for side2: Array in [["R", 1.0], ["L", -1.0]]:
		var n2: String = side2[0]
		var sx2: float = side2[1]
		var th := m.part("femur." + n2, "thigh." + n2, Vector3(0.11 * sx2, 0.92, 0))
		_bone_shaft(th, -10, 0, bone, bone_dk)
		var sh := m.part("tibia." + n2, "shin." + n2, Vector3(0.11 * sx2, 0.50, 0))
		sh.box(Vector3i(-1, -10, -1), Vector3i(0, 0, 0), bone)
		sh.box(Vector3i(-1, -1, -2), Vector3i(0, 0, -2), bone_dk)   # rótula
		sh.box(Vector3i(-1, -6, 0), Vector3i(-1, -3, 0), crack)
		if variant % 3 == 1:
			sh.box(Vector3i(-2, -8, -2), Vector3i(1, -3, 1), rust)
			sh.erase_box(Vector3i(-1, -8, -1), Vector3i(0, -3, 0))
		var ft := m.part("foot." + n2, "foot." + n2, Vector3(0.11 * sx2, 0.09, 0))
		ft.box(Vector3i(-1, -2, -2), Vector3i(0, 0, 1), bone)
		ft.box(Vector3i(-2, -2, -5), Vector3i(1, -2, -3), bone)
		ft.erase(Vector3i(-1, -2, -5))
		ft.erase(Vector3i(0, -2, -5))
	return m


## Persona (aldeanos, guardias...) para el rig humanoide. `look` define colores
## y detalles: skin, hair, tunic, pants, apron, female, beard, armor, cape.
static func human(look: Dictionary, model_seed: int = 7) -> VoxelModel:
	var m := VoxelModel.new(V, model_seed)
	var skin_c: Color = look.get("skin", Color(0.75, 0.55, 0.42))
	var hair_c: Color = look.get("hair", Color(0.3, 0.2, 0.1))
	var tunic_c: Color = look.get("tunic", Color(0.4, 0.3, 0.2))
	var pants_c: Color = look.get("pants", Color(0.3, 0.25, 0.2))
	var female := bool(look.get("female", false))
	var skin := m.mat(skin_c, 0.0, 0.7, 0.0, 0.03)
	var skin_dk := m.mat(skin_c.darkened(0.2), 0.0, 0.75, 0.0, 0.03)
	var hair := m.mat(hair_c, 0.0, 0.9, 0.0, 0.08)
	var tunic := m.mat(tunic_c, 0.0, 0.9, 0.0, 0.07)
	var tunic_dk := m.mat(tunic_c.darkened(0.3), 0.0, 0.9, 0.0, 0.05)
	var pants := m.mat(pants_c, 0.0, 0.9, 0.0, 0.06)
	var boots := m.mat(Color(0.2, 0.13, 0.08), 0.0, 0.8, 0.0, 0.06)
	var belt := m.mat(Color(0.25, 0.15, 0.08), 0.0, 0.8, 0.0, 0.05)
	var buckle := m.mat(Color(0.78, 0.62, 0.3), 0.9, 0.35, 0.0, 0.03)
	var eye_w := m.mat(Color(0.92, 0.92, 0.9), 0.0, 0.5, 0.0, 0.0)
	var eye_d := m.mat(Color(0.12, 0.15, 0.22), 0.0, 0.4, 0.0, 0.0)
	var mouth := m.mat(Color(0.5, 0.25, 0.22), 0.0, 0.7, 0.0, 0.0)
	var iron := m.mat(Color(0.55, 0.57, 0.62), 0.85, 0.4, 0.0, 0.05)

	# Cabeza
	var head := m.part("head", "head", Vector3(0, 1.56, 0))
	head.box(Vector3i(-4, 0, -3), Vector3i(3, 7, 3), skin)
	head.box(Vector3i(-4, 5, -4), Vector3i(3, 8, 4), hair)          # pelo superior
	head.box(Vector3i(-5, 2, -2), Vector3i(4, 7, 4), hair)          # laterales y nuca
	head.erase_box(Vector3i(-4, 0, -4), Vector3i(3, 4, -4))
	head.box(Vector3i(-4, 0, -3), Vector3i(3, 4, -3), skin)          # cara
	for ex: int in [-3, 1]:
		head.put(Vector3i(ex, 3, -4), eye_w)
		head.put(Vector3i(ex + 1, 3, -4), eye_d)
		head.put(Vector3i(ex, 4, -4), hair)
		head.put(Vector3i(ex + 1, 4, -4), hair)
	head.put(Vector3i(-1, 2, -4), skin_dk)
	head.put(Vector3i(0, 2, -4), skin_dk)
	head.box(Vector3i(-2, 1, -4), Vector3i(1, 1, -4), mouth)
	if female:
		head.box(Vector3i(-5, -6, 1), Vector3i(4, 6, 4), hair)       # melena
	if bool(look.get("beard", false)):
		head.box(Vector3i(-3, -1, -4), Vector3i(2, 1, -4), hair)
		head.box(Vector3i(-4, -2, -3), Vector3i(3, 0, -2), hair)
		head.put(Vector3i(-2, 1, -4), hair)
		head.put(Vector3i(1, 1, -4), hair)
	var neck := m.part("neck", "neck", Vector3(0, 1.5, 0))
	neck.box(Vector3i(-2, -1, -2), Vector3i(1, 1, 1), skin)

	# Torso
	var chest := m.part("torso", "chest", Vector3(0, 1.26, 0))
	chest.box(Vector3i(-5, -4, -3), Vector3i(4, 5, 2), tunic)
	chest.box(Vector3i(-2, 4, -4), Vector3i(1, 5, -4), skin)         # escote
	chest.recolor_box(Vector3i(-5, -4, -3), Vector3i(4, -4, 2), tunic_dk)
	if bool(look.get("armor", false)):
		chest.box(Vector3i(-5, -3, -4), Vector3i(4, 4, -4), iron)
		chest.ellipsoid(Vector3(5.0, 4.5, -0.5), Vector3(2.4, 1.6, 2.6), iron)
		chest.ellipsoid(Vector3(-6.0, 4.5, -0.5), Vector3(2.4, 1.6, 2.6), iron)
	if look.has("apron"):
		var apron := m.mat(look["apron"], 0.0, 0.9, 0.0, 0.05)
		chest.box(Vector3i(-3, -4, -4), Vector3i(2, 3, -4), apron)
	if bool(look.get("cape", false)):
		var cape := m.mat(tunic_c.darkened(0.35), 0.0, 0.9, 0.0, 0.06)
		for y in range(-20, 5):
			chest.box(Vector3i(-5, y, 3), Vector3i(4, y, 3), cape)
		chest.box(Vector3i(-5, 5, -3), Vector3i(4, 5, 3), cape)
	var spine := m.part("waist", "spine", Vector3(0, 1.08, 0))
	spine.box(Vector3i(-4, -1, -3), Vector3i(3, 4, 2), tunic)
	var hips := m.part("hips", "hips", Vector3(0, 0.95, 0))
	hips.box(Vector3i(-5, -2, -3), Vector3i(4, 1, 2), pants)
	hips.box(Vector3i(-5, 2, -3), Vector3i(4, 2, 2), belt)
	hips.put(Vector3i(-1, 2, -4), buckle)
	hips.put(Vector3i(0, 2, -4), buckle)
	if female or look.has("apron"):
		var skirt_c: int = tunic if female else (m.mat(look["apron"], 0.0, 0.9, 0.0, 0.05))
		for y in range(-9, 2):
			var w := 5 + int(-y / 4)
			hips.box(Vector3i(-w, y, -3 - (1 if y < -4 else 0)), Vector3i(w - 1, y, 2 + (1 if y < -4 else 0)), skirt_c)
	# Brazos
	for side: Array in [["R", 1.0], ["L", -1.0]]:
		var n: String = side[0]
		var sx: float = side[1]
		var ua := m.part("arm." + n, "upper_arm." + n, Vector3(0.23 * sx, 1.44, 0))
		ua.box(Vector3i(-2, -7, -2), Vector3i(1, 1, 1), tunic)
		var fa := m.part("fore." + n, "forearm." + n, Vector3(0.25 * sx, 1.15, 0))
		fa.box(Vector3i(-2, -5, -2), Vector3i(1, 0, 1), tunic if not bool(look.get("armor", false)) else iron)
		fa.box(Vector3i(-1, -6, -1), Vector3i(0, -5, 0), skin)
		var hd := m.part("hand." + n, "hand." + n, Vector3(0.26 * sx, 0.9, 0))
		hd.box(Vector3i(-1, -3, -2), Vector3i(0, 0, 1), skin)
		hd.put(Vector3i(int(sx) if sx > 0 else -2, -1, -2), skin_dk)
	# Piernas
	for side2: Array in [["R", 1.0], ["L", -1.0]]:
		var n2: String = side2[0]
		var sx2: float = side2[1]
		var th := m.part("thigh." + n2, "thigh." + n2, Vector3(0.11 * sx2, 0.92, 0))
		th.box(Vector3i(-2, -10, -2), Vector3i(1, 0, 1), pants)
		var sh := m.part("shin." + n2, "shin." + n2, Vector3(0.11 * sx2, 0.5, 0))
		sh.box(Vector3i(-2, -9, -2), Vector3i(1, 0, 1), pants)
		sh.box(Vector3i(-2, -9, -2), Vector3i(1, -5, 1), boots)
		var ft := m.part("foot." + n2, "foot." + n2, Vector3(0.11 * sx2, 0.09, 0))
		ft.box(Vector3i(-2, -2, -5), Vector3i(1, 0, 1), boots)
	return m


## Brazos del jugador en primera persona (1/40 m, más detalle cerca de cámara).
static func player_arms(sleeve: Color = Color(0.3, 0.22, 0.15), skin: Color = Color(0.6, 0.42, 0.31)) -> VoxelModel:
	var m := VoxelModel.new(1.0 / 40.0, 777)
	var skin_m := m.mat(skin, 0.0, 0.7, 0.0, 0.04)
	var skin_dk := m.mat(skin.darkened(0.18), 0.0, 0.75, 0.0, 0.04)
	var sleeve_m := m.mat(sleeve, 0.0, 0.92, 0.0, 0.08)
	var sleeve_dk := m.mat(sleeve.darkened(0.3), 0.0, 0.92, 0.0, 0.06)
	var leather := m.mat(Color(0.28, 0.17, 0.09), 0.0, 0.7, 0.0, 0.08)
	var strap := m.mat(Color(0.18, 0.11, 0.06), 0.0, 0.7, 0.0, 0.05)
	var buckle := m.mat(Color(0.75, 0.62, 0.3), 0.9, 0.35, 0.0, 0.05)
	for side: Array in [["R", 1.0], ["L", -1.0]]:
		var n: String = side[0]
		# Brazo superior (manga)
		var ua := m.part("upper." + n, "upper_arm." + n, Vector3.ZERO)
		ua.cylinder_y(-0.5, -0.5, 2.6, -12, 0, sleeve_m)
		for y in range(-12, 1, 3):
			ua.recolor_box(Vector3i(-4, y, -4), Vector3i(3, y, 3), sleeve_dk)
		# Antebrazo con brazal de cuero
		var fa := m.part("fore." + n, "forearm." + n, Vector3.ZERO)
		fa.cylinder_y(-0.5, -0.5, 2.2, -11, 0, sleeve_m)
		fa.cylinder_y(-0.5, -0.5, 2.4, -10, -4, leather)
		for y: int in [-9, -6]:
			fa.recolor_box(Vector3i(-4, y, -4), Vector3i(3, y, 3), strap)
		fa.put(Vector3i(-1, -9, -3), buckle)
		fa.put(Vector3i(-1, -6, -3), buckle)
		fa.cylinder_y(-0.5, -0.5, 1.8, -12, -11, skin_m)
		# Mano cerrada (puño) sujetando una empuñadura a lo largo de -Z local
		var hd := m.part("hand." + n, "hand." + n, Vector3.ZERO)
		hd.box(Vector3i(-2, -4, -2), Vector3i(1, 0, 1), skin_m)        # palma
		for fy in range(-4, 0):
			hd.box(Vector3i(-3, fy, -3), Vector3i(1, fy, -3), skin_m if fy % 2 == 0 else skin_dk)  # dedos
		hd.box(Vector3i(-3, -4, -2), Vector3i(-3, -1, 1), skin_dk)
		hd.box(Vector3i(2, -3, -3), Vector3i(2, -1, -1), skin_m)        # pulgar
		hd.box(Vector3i(-2, -1, 2), Vector3i(1, 0, 2), leather)         # guante (dorso)
	return m
