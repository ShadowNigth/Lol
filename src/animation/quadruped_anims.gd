class_name QuadrupedAnims
extends RefCounted
## Animaciones esqueléticas del rig cuadrúpedo (lobos). Usan la misma máquina
## de estados que los humanoides (HumanoidAnims.build_tree): locomoción
## mezclada idle/walk/run y estados de alerta, ataques, golpe, aturdimiento y
## muerte con fundidos.
##
## Convenciones (rotaciones de reposo nulas, modelo mirando a -Z):
##  patas (apuntan hacia abajo): X+ = llevar la pata adelante.
##  cuello/cabeza/mandíbula (apuntan adelante): X+ = subir; mandíbula X- = abrir.
##  cola (apunta atrás): X+ = bajar, X- = levantar. Cadera Z = rodar de costado.

const HIPS := Vector3(0, 0.70, 0.36)


static func _hp(dy: float, dz: float = 0.0) -> Vector3:
	return HIPS + Vector3(0, dy, dz)


static func _v(x: float, y: float = 0.0, z: float = 0.0) -> Vector3:
	return Vector3(x, y, z)


## Pista de pata con claves [t, ángulo X] desplazadas una fase dentro del ciclo.
static func _leg(keys: Array, phase: float, length: float) -> Array:
	var out: Array = []
	var shifted: Array = []
	for k: Array in keys:
		var t := fmod(float(k[0]) + phase, length)
		shifted.append([t, float(k[1])])
	shifted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# Cerrar el ciclo con el valor interpolado en t = 0 y t = length
	var first: Array = shifted[0]
	var last: Array = shifted[shifted.size() - 1]
	var span := float(first[0]) + length - float(last[0])
	var w := (length - float(last[0])) / maxf(span, 0.0001)
	var edge := lerpf(float(last[1]), float(first[1]), w)
	out.append([0.0, _v(edge)])
	for k2: Array in shifted:
		if float(k2[0]) > 0.0001 and float(k2[0]) < length - 0.0001:
			out.append([float(k2[0]), _v(float(k2[1]))])
	out.append([length, _v(edge)])
	return out


static func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()

	# --- Reposo: respiración, jadeo, mirar alrededor y mover la cola ---
	lib.add_animation("idle", AnimBuilder.make(2.0, true, {
		"chest": [[0.0, _v(0)], [1.0, _v(-2)], [2.0, _v(0)]],
		"neck": [[0.0, _v(10)], [1.0, _v(13)], [2.0, _v(10)]],
		"head": [[0.0, _v(-8)], [0.7, _v(-8, 14, 0)], [1.4, _v(-6, -10, 0)], [2.0, _v(-8)]],
		"jaw": [[0.0, _v(-4)], [0.25, _v(-10)], [0.5, _v(-4)], [0.75, _v(-10)], [1.0, _v(-4)], [1.25, _v(-10)], [1.5, _v(-4)], [1.75, _v(-10)], [2.0, _v(-4)]],
		"tail.1": [[0.0, _v(10, 10, 0)], [1.0, _v(10, -10, 0)], [2.0, _v(10, 10, 0)]],
		"tail.2": [[0.0, _v(8, -6, 0)], [1.0, _v(8, 6, 0)], [2.0, _v(8, -6, 0)]],
		"f_up.R": [[0.0, _v(2)], [2.0, _v(2)]],
		"f_up.L": [[0.0, _v(-2)], [2.0, _v(-2)]],
	}, {"hips": [[0.0, _hp(-0.004)], [1.0, _hp(-0.014)], [2.0, _hp(-0.004)]]}))

	# --- Paso: marcha en diagonal (mano izquierda con pie derecho) ---
	var wl := 1.0
	var up_keys := [[0.0, 22.0], [0.5, -18.0]]
	var f_low_keys := [[0.0, 0.0], [0.5, -4.0], [0.72, -40.0], [0.9, -10.0]]   # carpo: la mano se recoge atrás
	var b_low_keys := [[0.0, 0.0], [0.5, 4.0], [0.72, 38.0], [0.9, 10.0]]      # corvejón: el pie avanza recogido
	lib.add_animation("walk", AnimBuilder.make(wl, true, {
		"f_up.L": _leg(up_keys, 0.0, wl), "f_low.L": _leg(f_low_keys, 0.0, wl),
		"b_up.R": _leg(up_keys, 0.0, wl), "b_low.R": _leg(b_low_keys, 0.0, wl),
		"f_up.R": _leg(up_keys, 0.5, wl), "f_low.R": _leg(f_low_keys, 0.5, wl),
		"b_up.L": _leg(up_keys, 0.5, wl), "b_low.L": _leg(b_low_keys, 0.5, wl),
		"spine": [[0.0, _v(0, 3, 0)], [0.5, _v(0, -3, 0)], [1.0, _v(0, 3, 0)]],
		"neck": [[0.0, _v(6)], [0.25, _v(3)], [0.5, _v(6)], [0.75, _v(3)], [1.0, _v(6)]],
		"head": [[0.0, _v(-6)], [1.0, _v(-6)]],
		"tail.1": [[0.0, _v(12, 8, 0)], [0.5, _v(12, -8, 0)], [1.0, _v(12, 8, 0)]],
		"tail.2": [[0.0, _v(6)], [1.0, _v(6)]],
	}, {"hips": [[0.0, _hp(-0.012)], [0.25, _hp(0.004)], [0.5, _hp(-0.012)], [0.75, _hp(0.004)], [1.0, _hp(-0.012)]]}))

	# --- Galope: patas delanteras y traseras alternadas, columna que se flexiona ---
	var rl := 0.6
	var fr_up := [[0.0, 48.0], [0.3, -40.0]]
	var fr_low := [[0.0, 0.0], [0.3, -8.0], [0.45, -70.0], [0.55, -20.0]]
	var bk_up := [[0.0, -40.0], [0.3, 46.0]]
	var bk_low := [[0.0, 10.0], [0.15, 60.0], [0.3, 0.0]]
	lib.add_animation("run", AnimBuilder.make(rl, true, {
		"f_up.L": _leg(fr_up, 0.0, rl), "f_low.L": _leg(fr_low, 0.0, rl),
		"f_up.R": _leg(fr_up, 0.06, rl), "f_low.R": _leg(fr_low, 0.06, rl),
		"b_up.L": _leg(bk_up, 0.0, rl), "b_low.L": _leg(bk_low, 0.0, rl),
		"b_up.R": _leg(bk_up, 0.06, rl), "b_low.R": _leg(bk_low, 0.06, rl),
		"spine": [[0.0, _v(6)], [0.3, _v(-8)], [0.6, _v(6)]],
		"chest": [[0.0, _v(-4)], [0.3, _v(4)], [0.6, _v(-4)]],
		"neck": [[0.0, _v(-2)], [0.3, _v(-8)], [0.6, _v(-2)]],
		"head": [[0.0, _v(-2)], [0.3, _v(2)], [0.6, _v(-2)]],
		"jaw": [[0.0, _v(-12)], [0.3, _v(-6)], [0.6, _v(-12)]],
		"tail.1": [[0.0, _v(-18, 4, 0)], [0.3, _v(-24, -4, 0)], [0.6, _v(-18, 4, 0)]],
		"tail.2": [[0.0, _v(-6)], [0.3, _v(4)], [0.6, _v(-6)]],
	}, {"hips": [[0.0, _hp(0.035)], [0.15, _hp(-0.02)], [0.3, _hp(0.03)], [0.45, _hp(-0.02)], [0.6, _hp(0.035)]]}))

	# --- Alerta: agacha la cabeza, enseña los dientes y gruñe ---
	lib.add_animation("alert", AnimBuilder.make(0.8, false, {
		"neck": [[0.0, _v(10)], [0.3, _v(-14)], [0.8, _v(-12)]],
		"head": [[0.0, _v(-8)], [0.3, _v(8)], [0.8, _v(6)]],
		"jaw": [[0.0, _v(0)], [0.2, _v(-22)], [0.5, _v(-12)], [0.8, _v(-18)]],
		"f_up.R": [[0.0, _v(0)], [0.3, _v(-20, 0, 6)], [0.8, _v(-20, 0, 6)]],
		"f_up.L": [[0.0, _v(0)], [0.3, _v(-20, 0, -6)], [0.8, _v(-20, 0, -6)]],
		"f_low.R": [[0.0, _v(0)], [0.3, _v(36)], [0.8, _v(36)]],
		"f_low.L": [[0.0, _v(0)], [0.3, _v(36)], [0.8, _v(36)]],
		"f_paw.R": [[0.0, _v(0)], [0.3, _v(-16)], [0.8, _v(-16)]],
		"f_paw.L": [[0.0, _v(0)], [0.3, _v(-16)], [0.8, _v(-16)]],
		"b_up.R": [[0.0, _v(0)], [0.3, _v(22)], [0.8, _v(22)]],
		"b_up.L": [[0.0, _v(0)], [0.3, _v(22)], [0.8, _v(22)]],
		"b_low.R": [[0.0, _v(0)], [0.3, _v(-40)], [0.8, _v(-40)]],
		"b_low.L": [[0.0, _v(0)], [0.3, _v(-40)], [0.8, _v(-40)]],
		"b_paw.R": [[0.0, _v(0)], [0.3, _v(18)], [0.8, _v(18)]],
		"b_paw.L": [[0.0, _v(0)], [0.3, _v(18)], [0.8, _v(18)]],
		"tail.1": [[0.0, _v(10)], [0.3, _v(-10)], [0.8, _v(-8)]],
	}, {"hips": [[0.0, _hp(0.0)], [0.3, _hp(-0.06, 0.02)], [0.8, _hp(-0.06, 0.02)]]}))

	# --- Mordisco rápido (impacto hacia 0,32 s) ---
	lib.add_animation("attack_1", AnimBuilder.make(0.75, false, {
		"neck": [[0.0, _v(8)], [0.15, _v(-10)], [0.32, _v(6)], [0.5, _v(0)], [0.75, _v(8)]],
		"head": [[0.0, _v(-6)], [0.15, _v(6)], [0.32, _v(-6)], [0.75, _v(-6)]],
		"jaw": [[0.0, _v(-4)], [0.18, _v(-42)], [0.29, _v(-42)], [0.34, _v(0)], [0.75, _v(-4)]],
		"chest": [[0.0, _v(0)], [0.15, _v(8)], [0.32, _v(-6)], [0.75, _v(0)]],
		"f_up.R": [[0.0, _v(0)], [0.15, _v(-16)], [0.32, _v(26)], [0.5, _v(6)], [0.75, _v(0)]],
		"f_up.L": [[0.0, _v(0)], [0.15, _v(-16)], [0.32, _v(22)], [0.5, _v(4)], [0.75, _v(0)]],
		"f_low.R": [[0.0, _v(0)], [0.15, _v(28)], [0.32, _v(-6)], [0.75, _v(0)]],
		"f_low.L": [[0.0, _v(0)], [0.15, _v(28)], [0.32, _v(-6)], [0.75, _v(0)]],
		"b_up.R": [[0.0, _v(0)], [0.15, _v(22)], [0.32, _v(-22)], [0.75, _v(0)]],
		"b_up.L": [[0.0, _v(0)], [0.15, _v(22)], [0.32, _v(-18)], [0.75, _v(0)]],
		"b_low.R": [[0.0, _v(0)], [0.15, _v(-36)], [0.32, _v(6)], [0.75, _v(0)]],
		"b_low.L": [[0.0, _v(0)], [0.15, _v(-36)], [0.32, _v(6)], [0.75, _v(0)]],
		"tail.1": [[0.0, _v(10)], [0.32, _v(-26)], [0.75, _v(10)]],
	}, {"hips": [[0.0, _hp(0.0)], [0.15, _hp(-0.05, 0.07)], [0.32, _hp(0.02, -0.14)], [0.5, _hp(0.0, -0.05)], [0.75, _hp(0.0)]]}))

	# --- Salto con mordisco (impacto hacia 0,5 s; el impulso real lo da la IA) ---
	lib.add_animation("attack_2", AnimBuilder.make(1.05, false, {
		"spine": [[0.0, _v(0)], [0.25, _v(10)], [0.42, _v(-10)], [0.7, _v(5)], [1.05, _v(0)]],
		"neck": [[0.0, _v(8)], [0.25, _v(-12)], [0.45, _v(4)], [0.7, _v(0)], [1.05, _v(8)]],
		"head": [[0.0, _v(-6)], [0.25, _v(8)], [0.45, _v(-4)], [1.05, _v(-6)]],
		"jaw": [[0.0, _v(-4)], [0.3, _v(-45)], [0.47, _v(-45)], [0.53, _v(0)], [1.05, _v(-4)]],
		"f_up.R": [[0.0, _v(0)], [0.25, _v(-22)], [0.42, _v(62)], [0.55, _v(45)], [0.7, _v(-10)], [1.05, _v(0)]],
		"f_up.L": [[0.0, _v(0)], [0.25, _v(-22)], [0.42, _v(58)], [0.55, _v(42)], [0.7, _v(-8)], [1.05, _v(0)]],
		"f_low.R": [[0.0, _v(0)], [0.25, _v(34)], [0.42, _v(-16)], [0.7, _v(22)], [1.05, _v(0)]],
		"f_low.L": [[0.0, _v(0)], [0.25, _v(34)], [0.42, _v(-16)], [0.7, _v(22)], [1.05, _v(0)]],
		"b_up.R": [[0.0, _v(0)], [0.25, _v(30)], [0.42, _v(-56)], [0.55, _v(-40)], [0.7, _v(10)], [1.05, _v(0)]],
		"b_up.L": [[0.0, _v(0)], [0.25, _v(30)], [0.42, _v(-52)], [0.55, _v(-38)], [0.7, _v(10)], [1.05, _v(0)]],
		"b_low.R": [[0.0, _v(0)], [0.25, _v(-50)], [0.42, _v(12)], [0.7, _v(-20)], [1.05, _v(0)]],
		"b_low.L": [[0.0, _v(0)], [0.25, _v(-50)], [0.42, _v(12)], [0.7, _v(-20)], [1.05, _v(0)]],
		"tail.1": [[0.0, _v(10)], [0.42, _v(-30)], [0.7, _v(-10)], [1.05, _v(10)]],
		"tail.2": [[0.0, _v(6)], [0.42, _v(-12)], [1.05, _v(6)]],
	}, {"root": [[0.0, _v(0)], [0.25, Vector3(0, -0.05, 0.05)], [0.42, Vector3(0, 0.3, -0.08)], [0.55, Vector3(0, 0.18, -0.08)],
			[0.7, Vector3(0, 0, 0)], [1.05, Vector3(0, 0, 0)]]}))

	# --- Golpe recibido: sacudida de cabeza, retroceso y cola entre las patas ---
	lib.add_animation("hit", AnimBuilder.make(0.42, false, {
		"neck": [[0.0, _v(8)], [0.08, _v(22, 12, 0)], [0.25, _v(10, 4, 0)], [0.42, _v(8)]],
		"head": [[0.0, _v(-6)], [0.08, _v(6, 26, 16)], [0.25, _v(-4, 8, 4)], [0.42, _v(-6)]],
		"jaw": [[0.0, _v(-4)], [0.06, _v(-30)], [0.25, _v(-8)], [0.42, _v(-4)]],
		"spine": [[0.0, _v(0)], [0.08, _v(0, 0, 8)], [0.42, _v(0)]],
		"tail.1": [[0.0, _v(10)], [0.1, _v(45)], [0.42, _v(20)]],
	}, {"hips": [[0.0, _hp(0.0)], [0.1, _hp(-0.04, 0.1)], [0.42, _hp(0.0)]]}))

	# --- Aturdido: tambaleo y sacudidas de cabeza ---
	var stun_head: Array = [[0.0, _v(-6)]]
	for i in range(1, 8):
		stun_head.append([i * 0.15, _v(-12, 22.0 * (1 if i % 2 == 0 else -1), 10.0 * (1 if i % 2 == 0 else -1))])
	stun_head.append([1.25, _v(-6)])
	lib.add_animation("stun", AnimBuilder.make(1.25, false, {
		"head": stun_head,
		"neck": [[0.0, _v(8)], [0.2, _v(-16)], [1.0, _v(-12)], [1.25, _v(8)]],
		"spine": [[0.0, _v(0)], [0.3, _v(0, 0, 8)], [0.6, _v(0, 0, -8)], [0.9, _v(0, 0, 6)], [1.25, _v(0)]],
		"f_up.R": [[0.0, _v(0)], [0.3, _v(0, 0, 14)], [1.0, _v(0, 0, 10)], [1.25, _v(0)]],
		"f_up.L": [[0.0, _v(0)], [0.3, _v(0, 0, -14)], [1.0, _v(0, 0, -10)], [1.25, _v(0)]],
		"tail.1": [[0.0, _v(10)], [0.2, _v(40)], [1.25, _v(20)]],
	}, {"hips": [[0.0, _hp(0.0)], [0.3, _hp(-0.05)], [0.9, _hp(-0.04)], [1.25, _hp(0.0)]]}))

	# --- Muerte: se desploma y cae de costado ---
	lib.add_animation("death", AnimBuilder.make(1.5, false, {
		"hips": [[0.0, _v(0)], [0.35, _v(0, 0, 25)], [0.75, _v(0, 0, 86)], [1.5, _v(0, 0, 90)]],
		"neck": [[0.0, _v(8)], [0.35, _v(20)], [0.9, _v(-8, 0, -10)], [1.5, _v(-12, 0, -12)]],
		"head": [[0.0, _v(-6)], [0.35, _v(10)], [1.0, _v(-10)], [1.5, _v(-12)]],
		"jaw": [[0.0, _v(-4)], [0.3, _v(-30)], [1.0, _v(-14)], [1.5, _v(-14)]],
		"f_up.R": [[0.0, _v(0)], [0.75, _v(18)], [1.5, _v(14)]],
		"f_up.L": [[0.0, _v(0)], [0.75, _v(-12)], [1.5, _v(-8)]],
		"f_low.R": [[0.0, _v(0)], [0.75, _v(30)], [1.5, _v(26)]],
		"b_up.R": [[0.0, _v(0)], [0.75, _v(-16)], [1.5, _v(-12)]],
		"b_up.L": [[0.0, _v(0)], [0.75, _v(14)], [1.5, _v(10)]],
		"b_low.L": [[0.0, _v(0)], [0.75, _v(-26)], [1.5, _v(-22)]],
		"tail.1": [[0.0, _v(10)], [0.75, _v(30)], [1.5, _v(32)]],
		"tail.2": [[0.0, _v(6)], [1.5, _v(20)]],
	}, {"hips": [[0.0, _hp(0.0)], [0.35, _hp(-0.12)], [0.75, _hp(-0.48)], [1.5, _hp(-0.5)]]}))
	return lib
