class_name HumanoidAnims
extends RefCounted
## Animaciones esqueléticas para el rig humanoide (enemigos y PNJ) y su
## máquina de estados (AnimationTree) con fundidos entre estados.
##
## Convenciones (rotaciones de reposo nulas, modelo mirando a -Z):
##  brazo X+ = adelante; brazo derecho Z+ / izquierdo Z- = separar del cuerpo;
##  antebrazo X+ = flexionar codo; muslo X+ = pierna adelante; espinilla X- =
##  flexionar rodilla; columna X- = inclinarse adelante; Y+ = girar a la izquierda.

const HIPS_Y := 0.95


static func _p(y: float) -> Vector3:
	return Vector3(0, y, 0)


static func build_library(style: String = "warrior") -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var guard_r := Vector3(25, 0, 12)      # brazo de la espada en guardia
	var guard_rf := Vector3(55, 0, 0)
	var shield_l := Vector3(35, 0, -15)
	var shield_lf := Vector3(70, 0, 0)
	if style == "civilian":
		guard_r = Vector3(4, 0, 6)
		guard_rf = Vector3(10, 0, 0)
		shield_l = Vector3(4, 0, -6)
		shield_lf = Vector3(10, 0, 0)

	# --- Reposo con respiración ---
	lib.add_animation("idle", AnimBuilder.make(2.4, true, {
		"chest": [[0.0, Vector3(0, 0, 0)], [1.2, Vector3(-3, 0, 0)], [2.4, Vector3(0, 0, 0)]],
		"spine": [[0.0, Vector3(-2, 0, 0)], [1.2, Vector3(-1, 0, 0)], [2.4, Vector3(-2, 0, 0)]],
		"head": [[0.0, Vector3(-4, 0, 2)], [0.9, Vector3(-2, 6, -1)], [1.8, Vector3(-4, -3, 2)], [2.4, Vector3(-4, 0, 2)]],
		"upper_arm.R": [[0.0, guard_r], [1.2, guard_r + Vector3(-3, 0, 2)], [2.4, guard_r]],
		"forearm.R": [[0.0, guard_rf], [1.2, guard_rf + Vector3(4, 0, 0)], [2.4, guard_rf]],
		"upper_arm.L": [[0.0, shield_l], [1.2, shield_l + Vector3(-3, 0, -2)], [2.4, shield_l]],
		"forearm.L": [[0.0, shield_lf], [1.2, shield_lf + Vector3(3, 0, 0)], [2.4, shield_lf]],
		"thigh.R": [[0.0, Vector3(4, 0, 2)], [2.4, Vector3(4, 0, 2)]],
		"thigh.L": [[0.0, Vector3(-3, 0, -2)], [2.4, Vector3(-3, 0, -2)]],
		"shin.R": [[0.0, Vector3(-6, 0, 0)], [2.4, Vector3(-6, 0, 0)]],
		"shin.L": [[0.0, Vector3(-4, 0, 0)], [2.4, Vector3(-4, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.01)], [1.2, _p(HIPS_Y - 0.025)], [2.4, _p(HIPS_Y - 0.01)]]}))

	# --- Caminar ---
	lib.add_animation("walk", AnimBuilder.make(1.0, true, {
		"thigh.R": [[0.0, Vector3(28, 0, 0)], [0.25, Vector3(0, 0, 0)], [0.5, Vector3(-24, 0, 0)], [0.75, Vector3(4, 0, 0)], [1.0, Vector3(28, 0, 0)]],
		"thigh.L": [[0.0, Vector3(-24, 0, 0)], [0.25, Vector3(4, 0, 0)], [0.5, Vector3(28, 0, 0)], [0.75, Vector3(0, 0, 0)], [1.0, Vector3(-24, 0, 0)]],
		"shin.R": [[0.0, Vector3(-6, 0, 0)], [0.25, Vector3(-10, 0, 0)], [0.5, Vector3(-18, 0, 0)], [0.75, Vector3(-55, 0, 0)], [1.0, Vector3(-6, 0, 0)]],
		"shin.L": [[0.0, Vector3(-18, 0, 0)], [0.25, Vector3(-55, 0, 0)], [0.5, Vector3(-6, 0, 0)], [0.75, Vector3(-10, 0, 0)], [1.0, Vector3(-18, 0, 0)]],
		"foot.R": [[0.0, Vector3(-12, 0, 0)], [0.5, Vector3(14, 0, 0)], [1.0, Vector3(-12, 0, 0)]],
		"foot.L": [[0.0, Vector3(14, 0, 0)], [0.5, Vector3(-12, 0, 0)], [1.0, Vector3(14, 0, 0)]],
		"upper_arm.R": [[0.0, guard_r + Vector3(-8, 0, 0)], [0.5, guard_r + Vector3(10, 0, 0)], [1.0, guard_r + Vector3(-8, 0, 0)]],
		"forearm.R": [[0.0, guard_rf], [0.5, guard_rf + Vector3(8, 0, 0)], [1.0, guard_rf]],
		"upper_arm.L": [[0.0, shield_l + Vector3(12, 0, 0)], [0.5, shield_l + Vector3(-10, 0, 0)], [1.0, shield_l + Vector3(12, 0, 0)]],
		"forearm.L": [[0.0, shield_lf], [1.0, shield_lf]],
		"spine": [[0.0, Vector3(-3, 5, 0)], [0.5, Vector3(-3, -5, 0)], [1.0, Vector3(-3, 5, 0)]],
		"chest": [[0.0, Vector3(0, -4, 0)], [0.5, Vector3(0, 4, 0)], [1.0, Vector3(0, -4, 0)]],
		"head": [[0.0, Vector3(-3, 2, 0)], [0.5, Vector3(-3, -2, 0)], [1.0, Vector3(-3, 2, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.03)], [0.25, _p(HIPS_Y + 0.005)], [0.5, _p(HIPS_Y - 0.03)], [0.75, _p(HIPS_Y + 0.005)], [1.0, _p(HIPS_Y - 0.03)]]}))

	# --- Correr ---
	lib.add_animation("run", AnimBuilder.make(0.66, true, {
		"thigh.R": [[0.0, Vector3(48, 0, 0)], [0.165, Vector3(5, 0, 0)], [0.33, Vector3(-38, 0, 0)], [0.495, Vector3(10, 0, 0)], [0.66, Vector3(48, 0, 0)]],
		"thigh.L": [[0.0, Vector3(-38, 0, 0)], [0.165, Vector3(10, 0, 0)], [0.33, Vector3(48, 0, 0)], [0.495, Vector3(5, 0, 0)], [0.66, Vector3(-38, 0, 0)]],
		"shin.R": [[0.0, Vector3(-20, 0, 0)], [0.165, Vector3(-30, 0, 0)], [0.33, Vector3(-40, 0, 0)], [0.495, Vector3(-100, 0, 0)], [0.66, Vector3(-20, 0, 0)]],
		"shin.L": [[0.0, Vector3(-40, 0, 0)], [0.165, Vector3(-100, 0, 0)], [0.33, Vector3(-20, 0, 0)], [0.495, Vector3(-30, 0, 0)], [0.66, Vector3(-40, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(-25, 0, 12)], [0.33, Vector3(45, 0, 12)], [0.66, Vector3(-25, 0, 12)]],
		"forearm.R": [[0.0, Vector3(50, 0, 0)], [0.33, Vector3(75, 0, 0)], [0.66, Vector3(50, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.33, Vector3(-25, 0, -12)], [0.66, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, Vector3(75, 0, 0)], [0.33, Vector3(50, 0, 0)], [0.66, Vector3(75, 0, 0)]],
		"spine": [[0.0, Vector3(-10, 6, 0)], [0.33, Vector3(-10, -6, 0)], [0.66, Vector3(-10, 6, 0)]],
		"chest": [[0.0, Vector3(-6, -6, 0)], [0.33, Vector3(-6, 6, 0)], [0.66, Vector3(-6, -6, 0)]],
		"head": [[0.0, Vector3(10, 0, 0)], [0.66, Vector3(10, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.07)], [0.165, _p(HIPS_Y - 0.01)], [0.33, _p(HIPS_Y - 0.07)], [0.495, _p(HIPS_Y - 0.01)], [0.66, _p(HIPS_Y - 0.07)]]}))

	# --- Detectar / alerta ---
	lib.add_animation("alert", AnimBuilder.make(0.9, false, {
		"head": [[0.0, Vector3(-4, 0, 0)], [0.15, Vector3(8, 0, 6)], [0.5, Vector3(-6, 0, 0)], [0.9, Vector3(-4, 0, 0)]],
		"chest": [[0.0, Vector3(0, 0, 0)], [0.2, Vector3(6, 0, 0)], [0.6, Vector3(-6, 0, 0)], [0.9, Vector3(-3, 0, 0)]],
		"upper_arm.R": [[0.0, guard_r], [0.35, Vector3(70, 0, 25)], [0.9, Vector3(40, 0, 15)]],
		"forearm.R": [[0.0, guard_rf], [0.35, Vector3(90, 0, 0)], [0.9, Vector3(65, 0, 0)]],
		"upper_arm.L": [[0.0, shield_l], [0.35, Vector3(55, 0, -10)], [0.9, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, shield_lf], [0.9, Vector3(80, 0, 0)]],
		"thigh.R": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(18, 0, 6)], [0.9, Vector3(12, 0, 4)]],
		"thigh.L": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-12, 0, -6)], [0.9, Vector3(-8, 0, -4)]],
		"shin.R": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-25, 0, 0)], [0.9, Vector3(-18, 0, 0)]],
		"shin.L": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(-20, 0, 0)], [0.9, Vector3(-14, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y)], [0.3, _p(HIPS_Y - 0.08)], [0.9, _p(HIPS_Y - 0.05)]]}))

	# --- Ataque 1: tajo lateral (impacto ~0.55 s) ---
	lib.add_animation("attack_1", AnimBuilder.make(1.15, false, {
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.42, Vector3(120, 0, 75)], [0.55, Vector3(70, 0, -5)], [0.66, Vector3(35, 0, -30)], [1.15, Vector3(40, 0, 15)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.42, Vector3(95, 0, 0)], [0.55, Vector3(20, 0, 0)], [0.66, Vector3(15, 0, 0)], [1.15, Vector3(65, 0, 0)]],
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.42, Vector3(4, -30, 0)], [0.56, Vector3(-10, 25, 0)], [0.7, Vector3(-8, 30, 0)], [1.15, Vector3(-3, 0, 0)]],
		"spine": [[0.0, Vector3(-2, 0, 0)], [0.42, Vector3(0, -12, 0)], [0.56, Vector3(-6, 14, 0)], [1.15, Vector3(-2, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.42, Vector3(25, 0, -30)], [0.6, Vector3(55, 0, -10)], [1.15, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [1.15, Vector3(80, 0, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.42, Vector3(-10, 0, 4)], [0.56, Vector3(30, 0, 4)], [1.15, Vector3(12, 0, 4)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.56, Vector3(-18, 0, -4)], [1.15, Vector3(-8, 0, -4)]],
		"shin.R": [[0.0, Vector3(-18, 0, 0)], [0.56, Vector3(-30, 0, 0)], [1.15, Vector3(-18, 0, 0)]],
		"shin.L": [[0.0, Vector3(-14, 0, 0)], [0.56, Vector3(-10, 0, 0)], [1.15, Vector3(-14, 0, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.42, Vector3(-4, 18, 0)], [0.56, Vector3(-8, -15, 0)], [1.15, Vector3(-4, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.56, _p(HIPS_Y - 0.1)], [1.15, _p(HIPS_Y - 0.05)]]}))

	# --- Ataque 2: golpe descendente (impacto ~0.68 s) ---
	lib.add_animation("attack_2", AnimBuilder.make(1.35, false, {
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.5, Vector3(175, 0, 20)], [0.68, Vector3(60, 0, 8)], [0.8, Vector3(25, 0, 10)], [1.35, Vector3(40, 0, 15)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.5, Vector3(60, 0, 0)], [0.68, Vector3(10, 0, 0)], [1.35, Vector3(65, 0, 0)]],
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.5, Vector3(14, -8, 0)], [0.68, Vector3(-22, 4, 0)], [0.85, Vector3(-18, 0, 0)], [1.35, Vector3(-3, 0, 0)]],
		"spine": [[0.0, Vector3(-2, 0, 0)], [0.5, Vector3(8, 0, 0)], [0.68, Vector3(-14, 0, 0)], [1.35, Vector3(-2, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.5, Vector3(20, 0, -35)], [0.7, Vector3(40, 0, -15)], [1.35, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [1.35, Vector3(80, 0, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.5, Vector3(0, 0, 4)], [0.68, Vector3(35, 0, 4)], [1.35, Vector3(12, 0, 4)]],
		"shin.R": [[0.0, Vector3(-18, 0, 0)], [0.68, Vector3(-40, 0, 0)], [1.35, Vector3(-18, 0, 0)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.68, Vector3(-20, 0, -4)], [1.35, Vector3(-8, 0, -4)]],
		"shin.L": [[0.0, Vector3(-14, 0, 0)], [0.68, Vector3(-6, 0, 0)], [1.35, Vector3(-14, 0, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.5, Vector3(10, 0, 0)], [0.68, Vector3(-15, 0, 0)], [1.35, Vector3(-4, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.5, _p(HIPS_Y - 0.02)], [0.68, _p(HIPS_Y - 0.14)], [1.35, _p(HIPS_Y - 0.05)]]}))

	# --- Bloqueo con escudo (se mantiene) ---
	lib.add_animation("block", AnimBuilder.make(0.35, false, {
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.2, Vector3(75, 25, 5)], [0.35, Vector3(75, 25, 5)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [0.2, Vector3(95, 0, 0)], [0.35, Vector3(95, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.35, Vector3(20, 0, 25)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.35, Vector3(75, 0, 0)]],
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.35, Vector3(-8, 10, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.35, Vector3(-10, -8, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.35, Vector3(-12, 0, 6)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.35, Vector3(22, 0, -6)]],
		"shin.R": [[0.0, Vector3(-18, 0, 0)], [0.35, Vector3(-20, 0, 0)]],
		"shin.L": [[0.0, Vector3(-14, 0, 0)], [0.35, Vector3(-35, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.35, _p(HIPS_Y - 0.1)]]}))

	# --- Reacción a golpe ---
	lib.add_animation("hit", AnimBuilder.make(0.5, false, {
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.08, Vector3(18, 8, 4)], [0.5, Vector3(-3, 0, 0)]],
		"spine": [[0.0, Vector3(-2, 0, 0)], [0.08, Vector3(10, 0, 0)], [0.5, Vector3(-2, 0, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.08, Vector3(25, -10, 8)], [0.5, Vector3(-4, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.1, Vector3(10, 0, 45)], [0.5, Vector3(40, 0, 15)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.1, Vector3(30, 0, 0)], [0.5, Vector3(65, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.1, Vector3(15, 0, -45)], [0.5, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [0.1, Vector3(40, 0, 0)], [0.5, Vector3(80, 0, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.1, Vector3(-8, 0, 4)], [0.5, Vector3(12, 0, 4)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.1, Vector3(-20, 0, -4)], [0.5, Vector3(-8, 0, -4)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.1, _p(HIPS_Y - 0.08)], [0.5, _p(HIPS_Y - 0.05)]]}))

	# --- Aturdido (tras una parada o un golpe fuerte) ---
	lib.add_animation("stun", AnimBuilder.make(1.3, false, {
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.15, Vector3(20, 0, 6)], [0.5, Vector3(-28, 10, -6)], [1.0, Vector3(-22, -6, 4)], [1.3, Vector3(-3, 0, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.15, Vector3(25, 0, 0)], [0.5, Vector3(-30, 15, 10)], [1.0, Vector3(-25, -15, -8)], [1.3, Vector3(-4, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.4, Vector3(-5, 0, 10)], [1.0, Vector3(0, 0, 12)], [1.3, Vector3(40, 0, 15)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.4, Vector3(10, 0, 0)], [1.3, Vector3(65, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.4, Vector3(-5, 0, -10)], [1.3, Vector3(45, 0, -12)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [0.4, Vector3(10, 0, 0)], [1.3, Vector3(80, 0, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.5, Vector3(30, 0, 8)], [1.0, Vector3(25, 0, 6)], [1.3, Vector3(12, 0, 4)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.5, Vector3(20, 0, -8)], [1.0, Vector3(25, 0, -6)], [1.3, Vector3(-8, 0, -4)]],
		"shin.R": [[0.0, Vector3(-18, 0, 0)], [0.5, Vector3(-60, 0, 0)], [1.3, Vector3(-18, 0, 0)]],
		"shin.L": [[0.0, Vector3(-14, 0, 0)], [0.5, Vector3(-55, 0, 0)], [1.3, Vector3(-14, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.5, _p(HIPS_Y - 0.2)], [1.0, _p(HIPS_Y - 0.18)], [1.3, _p(HIPS_Y - 0.05)]]}))

	# --- Disparo con arco (suelta la flecha a 0.85 s) ---
	lib.add_animation("shoot", AnimBuilder.make(1.3, false, {
		"upper_arm.L": [[0.0, Vector3(20, 0, -10)], [0.35, Vector3(88, -10, -4)], [0.85, Vector3(88, -10, -4)], [1.3, Vector3(20, 0, -10)]],
		"forearm.L": [[0.0, Vector3(30, 0, 0)], [0.35, Vector3(6, 0, 0)], [0.85, Vector3(6, 0, 0)], [1.3, Vector3(30, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(20, 0, 10)], [0.35, Vector3(80, 0, 20)], [0.8, Vector3(85, 0, 35)], [0.88, Vector3(70, 0, 50)], [1.3, Vector3(20, 0, 10)]],
		"forearm.R": [[0.0, Vector3(30, 0, 0)], [0.35, Vector3(70, 0, 0)], [0.8, Vector3(140, 0, 0)], [0.88, Vector3(60, 0, 0)], [1.3, Vector3(30, 0, 0)]],
		"chest": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(0, 35, 0)], [0.85, Vector3(0, 38, 0)], [1.3, Vector3(0, 0, 0)]],
		"head": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(0, -32, 0)], [0.85, Vector3(0, -35, 0)], [1.3, Vector3(0, 0, 0)]],
		"thigh.R": [[0.0, Vector3(4, 0, 2)], [0.35, Vector3(-10, 0, 10)], [1.3, Vector3(4, 0, 2)]],
		"thigh.L": [[0.0, Vector3(-3, 0, -2)], [0.35, Vector3(15, 0, -10)], [1.3, Vector3(-3, 0, -2)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.02)], [0.35, _p(HIPS_Y - 0.06)], [1.3, _p(HIPS_Y - 0.02)]]}))

	# --- Gestos de conversación ---
	lib.add_animation("talk", AnimBuilder.make(3.0, true, {
		"upper_arm.R": [[0.0, Vector3(15, 0, 10)], [0.6, Vector3(45, 0, 20)], [1.2, Vector3(25, 0, 12)], [2.0, Vector3(50, -20, 15)], [3.0, Vector3(15, 0, 10)]],
		"forearm.R": [[0.0, Vector3(30, 0, 0)], [0.6, Vector3(70, 0, 0)], [1.2, Vector3(45, 0, 0)], [2.0, Vector3(80, 0, 0)], [3.0, Vector3(30, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(5, 0, -8)], [1.5, Vector3(30, 0, -15)], [3.0, Vector3(5, 0, -8)]],
		"forearm.L": [[0.0, Vector3(15, 0, 0)], [1.5, Vector3(55, 0, 0)], [3.0, Vector3(15, 0, 0)]],
		"head": [[0.0, Vector3(0, 0, 0)], [0.8, Vector3(-6, 8, 2)], [1.6, Vector3(4, -6, -2)], [2.4, Vector3(-3, 4, 0)], [3.0, Vector3(0, 0, 0)]],
		"chest": [[0.0, Vector3(0, 0, 0)], [1.5, Vector3(-3, 6, 0)], [3.0, Vector3(0, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y)], [3.0, _p(HIPS_Y)]]}))
	# --- Trabajo: martillear (herrero) ---
	lib.add_animation("work", AnimBuilder.make(1.1, true, {
		"upper_arm.R": [[0.0, Vector3(30, 0, 15)], [0.45, Vector3(130, 0, 20)], [0.6, Vector3(45, 0, 12)], [1.1, Vector3(30, 0, 15)]],
		"forearm.R": [[0.0, Vector3(70, 0, 0)], [0.45, Vector3(60, 0, 0)], [0.6, Vector3(20, 0, 0)], [1.1, Vector3(70, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(35, 0, -10)], [1.1, Vector3(35, 0, -10)]],
		"forearm.L": [[0.0, Vector3(60, 0, 0)], [1.1, Vector3(60, 0, 0)]],
		"chest": [[0.0, Vector3(-12, 0, 0)], [0.45, Vector3(-4, -6, 0)], [0.6, Vector3(-18, 4, 0)], [1.1, Vector3(-12, 0, 0)]],
		"head": [[0.0, Vector3(-18, 0, 0)], [1.1, Vector3(-18, 0, 0)]],
		"thigh.R": [[0.0, Vector3(10, 0, 4)], [1.1, Vector3(10, 0, 4)]],
		"thigh.L": [[0.0, Vector3(-6, 0, -4)], [1.1, Vector3(-6, 0, -4)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.03)], [0.6, _p(HIPS_Y - 0.05)], [1.1, _p(HIPS_Y - 0.03)]]}))
	# --- Saludo con la mano ---
	lib.add_animation("wave", AnimBuilder.make(1.4, false, {
		"upper_arm.R": [[0.0, Vector3(5, 0, 8)], [0.3, Vector3(10, 0, 150)], [0.55, Vector3(10, 0, 135)], [0.8, Vector3(10, 0, 155)], [1.05, Vector3(10, 0, 135)], [1.4, Vector3(5, 0, 8)]],
		"forearm.R": [[0.0, Vector3(10, 0, 0)], [0.3, Vector3(20, 0, 25)], [0.8, Vector3(20, 0, -10)], [1.4, Vector3(10, 0, 0)]],
		"head": [[0.0, Vector3(0, 0, 0)], [0.5, Vector3(4, 0, 5)], [1.4, Vector3(0, 0, 0)]],
	}))

	# --- Prisionera: cabizbaja, hombros caídos y muñecas atadas por delante;
	# cambia el peso de pierna, tiembla y levanta la vista de vez en cuando ---
	lib.add_animation("captive", AnimBuilder.make(4.0, true, {
		"spine": [[0.0, Vector3(-8, 0, 0)], [2.0, Vector3(-10, 0, 2)], [4.0, Vector3(-8, 0, 0)]],
		"chest": [[0.0, Vector3(-6, 0, 0)], [1.0, Vector3(-8, 3, 0)], [2.0, Vector3(-6, 0, 0)], [3.0, Vector3(-8, -3, 0)], [4.0, Vector3(-6, 0, 0)]],
		"head": [[0.0, Vector3(-8, 0, 0)], [1.2, Vector3(-9, 6, 3)], [2.0, Vector3(-2, -18, 0)], [2.6, Vector3(-2, 14, 0)], [3.2, Vector3(-7, 0, -2)], [4.0, Vector3(-8, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(22, 0, -14)], [2.0, Vector3(24, 0, -15)], [4.0, Vector3(22, 0, -14)]],
		"forearm.R": [[0.0, Vector3(58, 0, -12)], [2.0, Vector3(62, 0, -12)], [4.0, Vector3(58, 0, -12)]],
		"upper_arm.L": [[0.0, Vector3(22, 0, 14)], [2.0, Vector3(24, 0, 15)], [4.0, Vector3(22, 0, 14)]],
		"forearm.L": [[0.0, Vector3(58, 0, 12)], [2.0, Vector3(62, 0, 12)], [4.0, Vector3(58, 0, 12)]],
		"thigh.R": [[0.0, Vector3(3, 0, 2)], [2.0, Vector3(-2, 0, 3)], [4.0, Vector3(3, 0, 2)]],
		"thigh.L": [[0.0, Vector3(-2, 0, -3)], [2.0, Vector3(4, 0, -2)], [4.0, Vector3(-2, 0, -3)]],
		"shin.R": [[0.0, Vector3(-4, 0, 0)], [2.0, Vector3(-10, 0, 0)], [4.0, Vector3(-4, 0, 0)]],
		"shin.L": [[0.0, Vector3(-10, 0, 0)], [2.0, Vector3(-4, 0, 0)], [4.0, Vector3(-10, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y - 0.02)], [1.0, _p(HIPS_Y - 0.035)], [2.0, _p(HIPS_Y - 0.02)], [3.0, _p(HIPS_Y - 0.035)], [4.0, _p(HIPS_Y - 0.02)]]}))
	# --- Alegría: alza los dos brazos y da un saltito al verse libre ---
	lib.add_animation("cheer", AnimBuilder.make(1.6, false, {
		"upper_arm.R": [[0.0, Vector3(5, 0, 8)], [0.3, Vector3(10, 0, 150)], [0.6, Vector3(10, 0, 140)], [0.9, Vector3(10, 0, 155)], [1.6, Vector3(5, 0, 8)]],
		"forearm.R": [[0.0, Vector3(10, 0, 0)], [0.3, Vector3(25, 0, 0)], [0.9, Vector3(15, 0, 0)], [1.6, Vector3(10, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(5, 0, -8)], [0.3, Vector3(10, 0, -150)], [0.6, Vector3(10, 0, -140)], [0.9, Vector3(10, 0, -155)], [1.6, Vector3(5, 0, -8)]],
		"forearm.L": [[0.0, Vector3(10, 0, 0)], [0.3, Vector3(25, 0, 0)], [0.9, Vector3(15, 0, 0)], [1.6, Vector3(10, 0, 0)]],
		"head": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(14, 0, 0)], [1.0, Vector3(8, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"chest": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(6, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"thigh.R": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(12, 0, 0)], [0.45, Vector3(0, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"thigh.L": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(12, 0, 0)], [0.45, Vector3(0, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"shin.R": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(-25, 0, 0)], [0.45, Vector3(0, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"shin.L": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(-25, 0, 0)], [0.45, Vector3(0, 0, 0)], [1.6, Vector3(0, 0, 0)]],
	}, {"hips": [[0.0, _p(HIPS_Y)], [0.2, _p(HIPS_Y - 0.08)], [0.42, _p(HIPS_Y + 0.08)], [0.6, _p(HIPS_Y)], [1.6, _p(HIPS_Y)]]}))

	# --- Inconsciente: se le doblan las rodillas, cae de costado y queda tendido ---
	lib.add_animation("knockout", AnimBuilder.make(1.4, false, {
		"root": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(6, 0, 4)], [0.7, Vector3(40, 0, 18)], [1.05, Vector3(86, 0, 12)], [1.4, Vector3(88, 0, 10)]],
		"spine": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(12, 0, 0)], [0.8, Vector3(-6, 0, 4)], [1.4, Vector3(-4, 0, 6)]],
		"chest": [[0.0, Vector3(0, 0, 0)], [0.3, Vector3(14, 0, 0)], [0.9, Vector3(-10, 8, 0)], [1.4, Vector3(-6, 10, 0)]],
		"head": [[0.0, Vector3(0, 0, 0)], [0.25, Vector3(25, 0, 0)], [0.9, Vector3(-10, 20, 0)], [1.4, Vector3(-6, 38, 12)]],
		"upper_arm.R": [[0.0, Vector3(5, 0, 8)], [0.4, Vector3(-20, 0, 30)], [1.0, Vector3(-30, 0, 70)], [1.4, Vector3(-25, 0, 78)]],
		"forearm.R": [[0.0, Vector3(10, 0, 0)], [0.6, Vector3(35, 0, 0)], [1.4, Vector3(20, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(5, 0, -8)], [0.4, Vector3(-15, 0, -25)], [1.0, Vector3(-10, 0, -60)], [1.4, Vector3(-8, 0, -66)]],
		"forearm.L": [[0.0, Vector3(10, 0, 0)], [0.6, Vector3(50, 0, 0)], [1.4, Vector3(40, 0, 0)]],
		"thigh.R": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(50, 0, 4)], [0.9, Vector3(30, 0, 8)], [1.4, Vector3(18, 0, 10)]],
		"thigh.L": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(45, 0, -4)], [0.9, Vector3(40, 0, -8)], [1.4, Vector3(34, 0, -10)]],
		"shin.R": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(-95, 0, 0)], [0.9, Vector3(-40, 0, 0)], [1.4, Vector3(-22, 0, 0)]],
		"shin.L": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(-90, 0, 0)], [0.9, Vector3(-60, 0, 0)], [1.4, Vector3(-52, 0, 0)]],
	}, {
		"hips": [[0.0, _p(HIPS_Y)], [0.35, _p(HIPS_Y - 0.38)], [0.9, _p(HIPS_Y - 0.16)], [1.4, _p(HIPS_Y - 0.12)]],
		"root": [[0.0, Vector3(0, 0, 0)], [0.7, Vector3(0, 0.05, 0.15)], [1.05, Vector3(0, 0.15, 0.32)], [1.4, Vector3(0, 0.15, 0.33)]],
	}))
	# --- Levantarse: se incorpora, apoya una rodilla y se pone en pie ---
	lib.add_animation("getup", AnimBuilder.make(1.6, false, {
		"root": [[0.0, Vector3(88, 0, 10)], [0.45, Vector3(55, 0, 6)], [0.9, Vector3(14, 0, 0)], [1.3, Vector3(4, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"spine": [[0.0, Vector3(-4, 0, 6)], [0.45, Vector3(22, 0, 2)], [0.9, Vector3(20, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"chest": [[0.0, Vector3(-6, 10, 0)], [0.45, Vector3(16, 0, 0)], [1.0, Vector3(8, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"head": [[0.0, Vector3(-6, 38, 12)], [0.45, Vector3(10, 10, 0)], [1.0, Vector3(-8, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"upper_arm.R": [[0.0, Vector3(-25, 0, 78)], [0.45, Vector3(30, 0, 20)], [0.9, Vector3(40, 0, 15)], [1.6, Vector3(5, 0, 8)]],
		"forearm.R": [[0.0, Vector3(20, 0, 0)], [0.45, Vector3(10, 0, 0)], [1.6, Vector3(10, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(-8, 0, -66)], [0.45, Vector3(35, 0, -20)], [0.9, Vector3(45, 0, -12)], [1.6, Vector3(5, 0, -8)]],
		"forearm.L": [[0.0, Vector3(40, 0, 0)], [0.6, Vector3(20, 0, 0)], [1.6, Vector3(10, 0, 0)]],
		"thigh.R": [[0.0, Vector3(18, 0, 10)], [0.45, Vector3(85, 0, 4)], [0.9, Vector3(80, 0, 0)], [1.3, Vector3(20, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"thigh.L": [[0.0, Vector3(34, 0, -10)], [0.45, Vector3(60, 0, -4)], [0.9, Vector3(-10, 0, 0)], [1.3, Vector3(5, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"shin.R": [[0.0, Vector3(-22, 0, 0)], [0.45, Vector3(-120, 0, 0)], [0.9, Vector3(-95, 0, 0)], [1.3, Vector3(-25, 0, 0)], [1.6, Vector3(0, 0, 0)]],
		"shin.L": [[0.0, Vector3(-52, 0, 0)], [0.45, Vector3(-100, 0, 0)], [0.9, Vector3(-90, 0, 0)], [1.3, Vector3(-10, 0, 0)], [1.6, Vector3(0, 0, 0)]],
	}, {
		"hips": [[0.0, _p(HIPS_Y - 0.12)], [0.45, _p(HIPS_Y - 0.5)], [0.9, _p(HIPS_Y - 0.42)], [1.3, _p(HIPS_Y - 0.08)], [1.6, _p(HIPS_Y)]],
		"root": [[0.0, Vector3(0, 0.15, 0.33)], [0.45, Vector3(0, 0.05, 0.2)], [0.9, Vector3(0, 0.0, 0.05)], [1.6, Vector3(0, 0, 0)]],
	}))

	# --- Muerte: se desploma hacia atrás y queda en el suelo ---
	lib.add_animation("death", AnimBuilder.make(1.5, false, {
		"root": [[0.0, Vector3(0, 0, 0)], [0.35, Vector3(-8, 0, 0)], [0.75, Vector3(30, 0, 4)], [1.1, Vector3(84, 0, 6)], [1.25, Vector3(90, 0, 6)], [1.5, Vector3(88, 0, 6)]],
		"chest": [[0.0, Vector3(-3, 0, 0)], [0.3, Vector3(20, 10, 0)], [0.8, Vector3(-20, -6, 0)], [1.5, Vector3(-6, -12, 0)]],
		"head": [[0.0, Vector3(-4, 0, 0)], [0.3, Vector3(30, 0, 0)], [1.1, Vector3(-20, 30, 0)], [1.5, Vector3(-10, 45, 10)]],
		"upper_arm.R": [[0.0, Vector3(40, 0, 15)], [0.4, Vector3(-10, 0, 40)], [1.1, Vector3(-30, 0, 80)], [1.5, Vector3(-20, 0, 85)]],
		"forearm.R": [[0.0, Vector3(65, 0, 0)], [0.6, Vector3(20, 0, 0)], [1.5, Vector3(10, 0, 0)]],
		"upper_arm.L": [[0.0, Vector3(45, 0, -12)], [0.4, Vector3(-10, 0, -40)], [1.1, Vector3(-20, 0, -70)], [1.5, Vector3(-15, 0, -80)]],
		"forearm.L": [[0.0, Vector3(80, 0, 0)], [0.6, Vector3(30, 0, 0)], [1.5, Vector3(20, 0, 0)]],
		"thigh.R": [[0.0, Vector3(12, 0, 4)], [0.5, Vector3(55, 0, 6)], [1.1, Vector3(20, 0, 10)], [1.5, Vector3(10, 0, 14)]],
		"thigh.L": [[0.0, Vector3(-8, 0, -4)], [0.5, Vector3(45, 0, -6)], [1.1, Vector3(35, 0, -10)], [1.5, Vector3(25, 0, -12)]],
		"shin.R": [[0.0, Vector3(-18, 0, 0)], [0.5, Vector3(-100, 0, 0)], [1.1, Vector3(-30, 0, 0)], [1.5, Vector3(-15, 0, 0)]],
		"shin.L": [[0.0, Vector3(-14, 0, 0)], [0.5, Vector3(-90, 0, 0)], [1.1, Vector3(-50, 0, 0)], [1.5, Vector3(-40, 0, 0)]],
	}, {
		"hips": [[0.0, _p(HIPS_Y - 0.05)], [0.5, _p(HIPS_Y - 0.35)], [1.1, _p(HIPS_Y - 0.15)], [1.5, _p(HIPS_Y - 0.12)]],
		"root": [[0.0, Vector3(0, 0, 0)], [0.75, Vector3(0, 0.05, 0.2)], [1.1, Vector3(0, 0.16, 0.35)], [1.5, Vector3(0, 0.15, 0.35)]],
	}))
	return lib


## Construye el AnimationTree con estados y transiciones con fundido.
static func build_tree(lib: AnimationLibrary, actions: PackedStringArray) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	sm.allow_transition_to_self = true
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 2.0
	loco.sync = true
	for pt: Array in [["idle", 0.0], ["walk", 1.0], ["run", 2.0]]:
		var a := AnimationNodeAnimation.new()
		a.animation = pt[0]
		loco.add_blend_point(a, float(pt[1]), -1, StringName(str(pt[0])))
	sm.add_node("loco", loco, Vector2(0, 0))
	var start := AnimationNodeStateMachineTransition.new()
	start.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	sm.add_transition("Start", "loco", start)
	var i := 0
	for act in actions:
		if not lib.has_animation(act):
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = act
		sm.add_node(act, node, Vector2(200, i * 60))
		i += 1
	for act in actions:
		if not sm.has_node(act):
			continue
		sm.add_transition("loco", act, _xfade(0.15, false))
		# La muerte y el desmayo no vuelven solos a la locomoción
		if act != "death" and act != "knockout":
			var back := _xfade(0.22, true)
			if act == "block":
				back = _xfade(0.2, false)
			sm.add_transition(act, "loco", back)
		for other in actions:
			if other == act or not sm.has_node(other) or act == "death":
				continue
			sm.add_transition(act, other, _xfade(0.1, false))
	return sm


static func _xfade(t: float, at_end: bool) -> AnimationNodeStateMachineTransition:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = t
	if at_end:
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	else:
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	return tr
