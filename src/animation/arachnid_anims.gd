class_name ArachnidAnims
extends RefCounted
## Animaciones esqueléticas del rig de arácnido (arañas gigantes y su reina).
## Usan la misma máquina de estados que el resto de criaturas
## (HumanoidAnims.build_tree): locomoción idle/walk/run mezclada y estados de
## alerta, mordisco, salto, escupitajo de seda, golpe, aturdimiento y muerte.
##
## Las patas se mueven con un paso de trípode alterno (L1-R2-L3-R4 frente a
## R1-L2-R3-L4): en el apoyo la pata barre hacia atrás y en el vuelo se eleva
## (fémur arriba, tibia recogida) y avanza. Las rotaciones se calculan como
## cuaterniones en los ejes propios de cada pata (giro vertical en la cadera
## y bisagra perpendicular a la pata) y se convierten a ángulos de Euler para
## AnimBuilder.
##
## Convenciones: cuerpo X+ = levantar la parte delantera; abdomen X+ = bajar
## la punta; colmillos Z = abrir (R +, L -) y X+ = clavar hacia delante;
## pedipalpos X+ = levantar.

const SIDES := ["R", "L"]

static var _lib: AnimationLibrary


## Biblioteca compartida (se construye una sola vez para todas las arañas).
static func library() -> AnimationLibrary:
	if _lib == null:
		_lib = build_library()
	return _lib


static func _deg(e: Vector3) -> Vector3:
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


static func _hinge(i: int, side: String) -> Vector3:
	var d: Vector3 = Rig.spider_leg(i, side)["dir"]
	return d.cross(Vector3.UP).normalized()


## Fémur: `fwd` grados hacia delante (giro vertical en la cadera) y `lift`
## grados de elevación (+ = la rodilla sube).
static func _qa(i: int, side: String, fwd: float, lift: float) -> Vector3:
	var s := 1.0 if side == "R" else -1.0
	var q := Quaternion(Vector3.UP, deg_to_rad(fwd * s)) * Quaternion(_hinge(i, side), deg_to_rad(lift))
	return _deg(q.get_euler())


## Tibia o tarso: flexión en la bisagra (+ = se estira hacia fuera, - = se recoge).
static func _qh(i: int, side: String, bend: float) -> Vector3:
	return _deg(Quaternion(_hinge(i, side), deg_to_rad(bend)).get_euler())


static func _v(x: float, y: float = 0.0, z: float = 0.0) -> Vector3:
	return Vector3(x, y, z)


static func _leg_name(i: int, side: String, seg: String) -> String:
	return "leg%d.%s.%s" % [i, side, seg]


## Grupo del trípode alterno: L1, R2, L3, R4 (true) frente a R1, L2, R3, L4.
static func _group_a(i: int, side: String) -> bool:
	return (i % 2 == 1) == (side == "L")


## Desplaza un ciclo de claves [u, p1, p2...] (u en 0..1) una fase y lo cierra
## con valores interpolados en u = 0 y u = 1.
static func _cycle(keys: Array, phase: float) -> Array:
	var shifted: Array = []
	for k: Array in keys:
		var nk := k.duplicate()
		nk[0] = fmod(float(k[0]) + phase, 1.0)
		shifted.append(nk)
	shifted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var first: Array = shifted[0]
	var last: Array = shifted[shifted.size() - 1]
	var span := float(first[0]) + 1.0 - float(last[0])
	var w := (1.0 - float(last[0])) / maxf(span, 0.0001)
	var edge: Array = [0.0]
	for j in range(1, first.size()):
		edge.append(lerpf(float(last[j]), float(first[j]), w))
	var out: Array = [edge]
	for k2: Array in shifted:
		if float(k2[0]) > 0.0001 and float(k2[0]) < 0.9999:
			out.append(k2)
	var end := edge.duplicate()
	end[0] = 1.0
	out.append(end)
	return out


## Pistas de las 24 piezas de las patas para un ciclo de marcha.
static func _gait(length: float, amp: float, lift: float, bend: float, tracks: Dictionary) -> void:
	var amp_by_leg: Array[float] = [0.75, 1.0, 1.0, 0.9]
	for i in range(1, 5):
		for side: String in SIDES:
			var a := amp * amp_by_leg[i - 1]
			# [u, adelante, elevación, flexión tibia, flexión tarso]
			var keys := [
				[0.0, a, 0.0, 0.0, 0.0],
				[0.5, -a, 0.0, 0.0, 0.0],
				[0.62, -a * 0.45, lift * 0.85, bend * 0.8, bend * 0.4],
				[0.75, 0.0, lift, bend, bend * 0.5],
				[0.88, a * 0.75, lift * 0.45, bend * 0.4, bend * 0.15],
			]
			var cyc := _cycle(keys, 0.0 if _group_a(i, side) else 0.5)
			var ta: Array = []
			var tb: Array = []
			var tc: Array = []
			for k: Array in cyc:
				var t := float(k[0]) * length
				ta.append([t, _qa(i, side, float(k[1]), float(k[2]))])
				tb.append([t, _qh(i, side, float(k[3]))])
				tc.append([t, _qh(i, side, float(k[4]))])
			tracks[_leg_name(i, side, "a")] = ta
			tracks[_leg_name(i, side, "b")] = tb
			tracks[_leg_name(i, side, "c")] = tc


## Misma pose para todas las patas en un instante: añade claves a las pistas.
## `pose` = func(i, side) -> [adelante, elevación, flexión tibia, flexión tarso].
static func _pose_all(tracks: Dictionary, t: float, pose: Callable) -> void:
	for i in range(1, 5):
		for side: String in SIDES:
			var p: Array = pose.call(i, side)
			for seg: String in ["a", "b", "c"]:
				var key := _leg_name(i, side, seg)
				if not tracks.has(key):
					tracks[key] = []
			(tracks[_leg_name(i, side, "a")] as Array).append([t, _qa(i, side, float(p[0]), float(p[1]))])
			(tracks[_leg_name(i, side, "b")] as Array).append([t, _qh(i, side, float(p[2]))])
			(tracks[_leg_name(i, side, "c")] as Array).append([t, _qh(i, side, float(p[3]) if p.size() > 3 else 0.0)])


static func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var rest := func(_i: int, _s: String) -> Array: return [0.0, 0.0, 0.0, 0.0]

	# --- Reposo: respira con el abdomen, mueve palpos y quelíceros y tantea el suelo con una pata ---
	var idle := {
		"body": [[0.0, _v(0)], [1.5, _v(1.5, 2.5, 0)], [3.0, _v(0)]],
		"abdomen": [[0.0, _v(0)], [1.5, _v(3.5)], [3.0, _v(0)]],
		"palp.R": [[0.0, _v(0)], [0.4, _v(16)], [0.8, _v(0)], [3.0, _v(0)]],
		"palp.L": [[0.0, _v(0)], [1.6, _v(0)], [2.0, _v(16)], [2.4, _v(0)], [3.0, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.9, _v(0, 0, 9)], [1.2, _v(0)], [3.0, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.9, _v(0, 0, -9)], [1.2, _v(0)], [3.0, _v(0)]],
		"leg1.R.a": [[0.0, _qa(1, "R", 0, 0)], [1.1, _qa(1, "R", 0, 0)], [1.3, _qa(1, "R", 7, 24)], [1.45, _qa(1, "R", 5, 6)],
				[1.6, _qa(1, "R", 6, 16)], [1.8, _qa(1, "R", 0, 0)], [3.0, _qa(1, "R", 0, 0)]],
		"leg1.R.b": [[0.0, _qh(1, "R", 0)], [1.1, _qh(1, "R", 0)], [1.3, _qh(1, "R", -14)], [1.45, _qh(1, "R", -2)],
				[1.6, _qh(1, "R", -10)], [1.8, _qh(1, "R", 0)], [3.0, _qh(1, "R", 0)]],
		"leg1.L.a": [[0.0, _qa(1, "L", 0, 0)], [2.3, _qa(1, "L", 0, 0)], [2.5, _qa(1, "L", 4, 14)], [2.75, _qa(1, "L", 0, 0)], [3.0, _qa(1, "L", 0, 0)]],
		"leg1.L.b": [[0.0, _qh(1, "L", 0)], [2.3, _qh(1, "L", 0)], [2.5, _qh(1, "L", -8)], [2.75, _qh(1, "L", 0)], [3.0, _qh(1, "L", 0)]],
	}
	lib.add_animation("idle", AnimBuilder.make(3.0, true, idle, {
		"root": [[0.0, _v(0)], [1.5, _v(0, -0.008, 0)], [3.0, _v(0)]]}))

	# --- Paso: trípode alterno con un leve vaivén del cuerpo ---
	var wl := 0.8
	var walk := {
		"body": [[0.0, _v(0, 1.5, 0)], [wl * 0.5, _v(0, -1.5, 0)], [wl, _v(0, 1.5, 0)]],
		"abdomen": [[0.0, _v(1)], [wl * 0.25, _v(-1)], [wl * 0.5, _v(1)], [wl * 0.75, _v(-1)], [wl, _v(1)]],
		"palp.R": [[0.0, _v(8)], [wl * 0.5, _v(2)], [wl, _v(8)]],
		"palp.L": [[0.0, _v(2)], [wl * 0.5, _v(8)], [wl, _v(2)]],
	}
	_gait(wl, 14.0, 24.0, -18.0, walk)
	lib.add_animation("walk", AnimBuilder.make(wl, true, walk, {
		"root": [[0.0, _v(0, -0.006, 0)], [wl * 0.25, _v(0, 0.006, 0)], [wl * 0.5, _v(0, -0.006, 0)], [wl * 0.75, _v(0, 0.006, 0)], [wl, _v(0, -0.006, 0)]]}))

	# --- Carrera: el mismo trípode, más rápido y amplio, el cuerpo más bajo y el abdomen rebotando ---
	var rl := 0.42
	var run := {
		"body": [[0.0, _v(-3, 2, 0)], [rl * 0.5, _v(-3, -2, 0)], [rl, _v(-3, 2, 0)]],
		"abdomen": [[0.0, _v(4)], [rl * 0.25, _v(-3)], [rl * 0.5, _v(4)], [rl * 0.75, _v(-3)], [rl, _v(4)]],
		"palp.R": [[0.0, _v(14)], [rl, _v(14)]],
		"palp.L": [[0.0, _v(14)], [rl, _v(14)]],
	}
	_gait(rl, 21.0, 30.0, -26.0, run)
	lib.add_animation("run", AnimBuilder.make(rl, true, run, {
		"root": [[0.0, _v(0, -0.02, 0)], [rl * 0.25, _v(0, 0.0, 0)], [rl * 0.5, _v(0, -0.02, 0)], [rl * 0.75, _v(0, 0.0, 0)], [rl, _v(0, -0.02, 0)]]}))

	# --- Alerta: se encabrita, alza las patas delanteras y abre los quelíceros ---
	var alert := {
		"body": [[0.0, _v(0)], [0.35, _v(22)], [0.9, _v(18)]],
		"abdomen": [[0.0, _v(0)], [0.35, _v(-12)], [0.9, _v(-10)]],
		"fang.R": [[0.0, _v(0)], [0.3, _v(-8, 0, 28)], [0.9, _v(-6, 0, 20)]],
		"fang.L": [[0.0, _v(0)], [0.3, _v(-8, 0, -28)], [0.9, _v(-6, 0, -20)]],
		"palp.R": [[0.0, _v(0)], [0.3, _v(28)], [0.9, _v(22)]],
		"palp.L": [[0.0, _v(0)], [0.3, _v(28)], [0.9, _v(22)]],
	}
	_pose_all(alert, 0.0, rest)
	_pose_all(alert, 0.35, func(i: int, _s: String) -> Array:
		return [[10.0, 55.0, 25.0, 10.0], [4.0, 22.0, 8.0, 0.0], [-2.0, 6.0, 0.0, 0.0], [-6.0, -6.0, 4.0, 0.0]][i - 1])
	_pose_all(alert, 0.9, func(i: int, _s: String) -> Array:
		return [[8.0, 50.0, 22.0, 8.0], [4.0, 20.0, 6.0, 0.0], [-2.0, 5.0, 0.0, 0.0], [-6.0, -5.0, 4.0, 0.0]][i - 1])
	lib.add_animation("alert", AnimBuilder.make(0.9, false, alert, {
		"root": [[0.0, _v(0)], [0.35, _v(0, 0.03, 0.02)], [0.9, _v(0, 0.025, 0.02)]]}))

	# --- Mordisco (impacto hacia 0,38 s): se echa atrás y descarga los colmillos ---
	var bite := {
		"body": [[0.0, _v(0)], [0.22, _v(20)], [0.36, _v(-14)], [0.5, _v(-6)], [0.8, _v(0)]],
		"abdomen": [[0.0, _v(0)], [0.22, _v(-10)], [0.36, _v(8)], [0.8, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.22, _v(-15, 0, 35)], [0.34, _v(30, 0, 28)], [0.38, _v(38, 0, 0)], [0.5, _v(10, 0, 0)], [0.8, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.22, _v(-15, 0, -35)], [0.34, _v(30, 0, -28)], [0.38, _v(38, 0, 0)], [0.5, _v(10, 0, 0)], [0.8, _v(0)]],
		"palp.R": [[0.0, _v(0)], [0.22, _v(30)], [0.36, _v(-10)], [0.8, _v(0)]],
		"palp.L": [[0.0, _v(0)], [0.22, _v(30)], [0.36, _v(-10)], [0.8, _v(0)]],
	}
	_pose_all(bite, 0.0, rest)
	_pose_all(bite, 0.22, func(i: int, _s: String) -> Array:
		return [[12.0, 45.0, 20.0, 6.0], [0.0, 12.0, 4.0, 0.0], [0.0, 4.0, 0.0, 0.0], [0.0, 4.0, 0.0, 0.0]][i - 1])
	_pose_all(bite, 0.36, func(i: int, _s: String) -> Array:
		return [[18.0, 8.0, -10.0, 0.0], [10.0, -4.0, 2.0, 0.0], [-12.0, -6.0, 4.0, 0.0], [-12.0, -6.0, 4.0, 0.0]][i - 1])
	_pose_all(bite, 0.55, func(i: int, _s: String) -> Array:
		return [[6.0, 4.0, -2.0, 0.0], [2.0, 0.0, 0.0, 0.0], [-4.0, -2.0, 0.0, 0.0], [-4.0, -2.0, 0.0, 0.0]][i - 1])
	_pose_all(bite, 0.8, rest)
	lib.add_animation("attack_1", AnimBuilder.make(0.8, false, bite, {
		"root": [[0.0, _v(0)], [0.22, _v(0, 0.02, 0.05)], [0.36, _v(0, -0.03, -0.18)], [0.55, _v(0, 0, -0.06)], [0.8, _v(0)]]}))

	# --- Salto con mordisco (impacto hacia 0,55 s; el impulso real lo da la IA) ---
	var pounce := {
		"body": [[0.0, _v(0)], [0.28, _v(10)], [0.42, _v(6)], [0.55, _v(-12)], [0.75, _v(-4)], [1.0, _v(0)]],
		"abdomen": [[0.0, _v(0)], [0.28, _v(6)], [0.42, _v(-14)], [0.55, _v(6)], [1.0, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.42, _v(-12, 0, 32)], [0.52, _v(20, 0, 26)], [0.56, _v(38, 0, 0)], [1.0, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.42, _v(-12, 0, -32)], [0.52, _v(20, 0, -26)], [0.56, _v(38, 0, 0)], [1.0, _v(0)]],
	}
	_pose_all(pounce, 0.0, rest)
	_pose_all(pounce, 0.28, func(_i: int, _s: String) -> Array: return [0.0, 6.0, -5.0, 0.0])
	_pose_all(pounce, 0.42, func(i: int, _s: String) -> Array:
		return [[14.0, 40.0, 18.0, 4.0], [10.0, 28.0, 12.0, 0.0], [-18.0, -16.0, 12.0, 0.0], [-20.0, -20.0, 14.0, 0.0]][i - 1])
	_pose_all(pounce, 0.55, func(i: int, _s: String) -> Array:
		return [[10.0, 10.0, -6.0, 0.0], [2.0, 4.0, 0.0, 0.0], [-4.0, 2.0, 0.0, 0.0], [-6.0, 2.0, 0.0, 0.0]][i - 1])
	_pose_all(pounce, 1.0, rest)
	lib.add_animation("attack_2", AnimBuilder.make(1.0, false, pounce, {
		"root": [[0.0, _v(0)], [0.28, _v(0, -0.04, 0.05)], [0.42, _v(0, 0.3, -0.1)], [0.52, _v(0, 0.12, -0.16)], [0.6, _v(0, 0, -0.1)], [1.0, _v(0)]]}))

	# --- Escupitajo de seda (suelta el proyectil hacia 0,55 s) ---
	var spit := {
		"body": [[0.0, _v(0)], [0.4, _v(28)], [0.55, _v(6)], [0.75, _v(10)], [1.0, _v(0)]],
		"abdomen": [[0.0, _v(0)], [0.4, _v(-16)], [0.55, _v(6)], [1.0, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.45, _v(-10, 0, 30)], [0.55, _v(25, 0, 30)], [0.8, _v(0)], [1.0, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.45, _v(-10, 0, -30)], [0.55, _v(25, 0, -30)], [0.8, _v(0)], [1.0, _v(0)]],
		"palp.R": [[0.0, _v(0)], [0.4, _v(30)], [0.6, _v(10)], [1.0, _v(0)]],
		"palp.L": [[0.0, _v(0)], [0.4, _v(30)], [0.6, _v(10)], [1.0, _v(0)]],
	}
	_pose_all(spit, 0.0, rest)
	_pose_all(spit, 0.4, func(i: int, _s: String) -> Array:
		return [[8.0, 50.0, 20.0, 6.0], [2.0, 16.0, 4.0, 0.0], [-2.0, 2.0, 0.0, 0.0], [-6.0, -8.0, 4.0, 0.0]][i - 1])
	_pose_all(spit, 0.55, func(i: int, _s: String) -> Array:
		return [[14.0, 30.0, 10.0, 2.0], [4.0, 6.0, 0.0, 0.0], [-4.0, 0.0, 0.0, 0.0], [-8.0, -4.0, 2.0, 0.0]][i - 1])
	_pose_all(spit, 1.0, rest)
	lib.add_animation("shoot", AnimBuilder.make(1.0, false, spit, {
		"root": [[0.0, _v(0)], [0.4, _v(0, 0.04, 0.06)], [0.55, _v(0, 0, -0.06)], [1.0, _v(0)]]}))

	# --- Golpe recibido: retrocede, encoge las patas y sacude el abdomen ---
	var hit := {
		"body": [[0.0, _v(0)], [0.08, _v(14, 0, 6)], [0.25, _v(4, 0, 2)], [0.45, _v(0)]],
		"abdomen": [[0.0, _v(0)], [0.1, _v(-10)], [0.45, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.08, _v(0, 0, 25)], [0.45, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.08, _v(0, 0, -25)], [0.45, _v(0)]],
	}
	_pose_all(hit, 0.0, rest)
	_pose_all(hit, 0.08, func(_i: int, _s: String) -> Array: return [0.0, 16.0, -20.0, -6.0])
	_pose_all(hit, 0.45, rest)
	lib.add_animation("hit", AnimBuilder.make(0.45, false, hit, {
		"root": [[0.0, _v(0)], [0.08, _v(0, 0.02, 0.1)], [0.45, _v(0)]]}))

	# --- Aturdida: espasmos desordenados de las patas y tambaleo ---
	var stun := {
		"body": [[0.0, _v(0)], [0.2, _v(-4, 0, 8)], [0.5, _v(-2, 0, -8)], [0.8, _v(-4, 0, 7)], [1.05, _v(-2, 0, -4)], [1.25, _v(0)]],
		"fang.R": [[0.0, _v(0)], [0.3, _v(0, 0, 20)], [0.45, _v(0)], [0.7, _v(0, 0, 18)], [0.85, _v(0)], [1.25, _v(0)]],
		"fang.L": [[0.0, _v(0)], [0.35, _v(0, 0, -20)], [0.5, _v(0)], [0.75, _v(0, 0, -18)], [0.9, _v(0)], [1.25, _v(0)]],
	}
	var k := 0
	for i in range(1, 5):
		for side: String in SIDES:
			var t0 := 0.1 + fmod(k * 0.37, 0.85)
			var lift := 16.0 + float(k % 3) * 7.0
			stun[_leg_name(i, side, "a")] = [[0.0, _qa(i, side, 0, 0)], [t0, _qa(i, side, 4.0 - k % 2 * 8.0, lift)], [t0 + 0.14, _qa(i, side, 0, 2)], [1.25, _qa(i, side, 0, 0)]]
			stun[_leg_name(i, side, "b")] = [[0.0, _qh(i, side, 0)], [t0, _qh(i, side, -18)], [t0 + 0.14, _qh(i, side, -2)], [1.25, _qh(i, side, 0)]]
			k += 1
	lib.add_animation("stun", AnimBuilder.make(1.25, false, stun, {
		"root": [[0.0, _v(0)], [0.3, _v(0, -0.03, 0)], [1.0, _v(0, -0.02, 0)], [1.25, _v(0)]]}))

	# --- Muerte: se desploma y encoge las patas sobre el cuerpo, una tras otra ---
	var death := {
		"body": [[0.0, _v(0)], [0.25, _v(12)], [0.7, _v(-6, 0, 18)], [1.6, _v(-8, 0, 22)]],
		"abdomen": [[0.0, _v(0)], [0.7, _v(10)], [1.6, _v(12)]],
		"fang.R": [[0.0, _v(0)], [0.3, _v(0, 0, 30)], [1.6, _v(0, 0, 10)]],
		"fang.L": [[0.0, _v(0)], [0.3, _v(0, 0, -30)], [1.6, _v(0, 0, -10)]],
		"palp.R": [[0.0, _v(0)], [0.8, _v(-30)], [1.6, _v(-35)]],
		"palp.L": [[0.0, _v(0)], [0.8, _v(-30)], [1.6, _v(-35)]],
	}
	for i in range(1, 5):
		for side: String in SIDES:
			var delay := (i - 1) * 0.08 + (0.04 if side == "L" else 0.0)
			var fwd := -5.0 * (i - 2.5)
			death[_leg_name(i, side, "a")] = [[0.0, _qa(i, side, 0, 0)], [0.2 + delay, _qa(i, side, 0, 25)],
					[0.75 + delay, _qa(i, side, fwd, 68)], [1.6, _qa(i, side, fwd, 72)]]
			death[_leg_name(i, side, "b")] = [[0.0, _qh(i, side, 0)], [0.25 + delay, _qh(i, side, -20)],
					[0.75 + delay, _qh(i, side, -92)], [1.6, _qh(i, side, -98)]]
			death[_leg_name(i, side, "c")] = [[0.0, _qh(i, side, 0)], [0.8 + delay, _qh(i, side, -48)], [1.6, _qh(i, side, -55)]]
	lib.add_animation("death", AnimBuilder.make(1.6, false, death, {
		"root": [[0.0, _v(0)], [0.25, _v(0, 0.03, 0)], [0.7, _v(0, -0.26, 0)], [1.6, _v(0, -0.28, 0)]]}))
	return lib
