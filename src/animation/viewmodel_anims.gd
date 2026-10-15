class_name ViewmodelAnims
extends RefCounted
## Animaciones de primera persona definidas como trayectorias de las manos
## (posición + rotación en espacio de cámara). El IK de brazos convierte esas
## trayectorias en poses del esqueleto. Cada tipo de arma tiene su juego.
##
## Rotación de mano (grados, Euler YXZ): x inclina la hoja desde "al frente"
## hacia arriba, y la gira a la izquierda, z gira el filo sobre su eje.

const R := "@HandR"
const L := "@HandL"

# Poses de reposo por tipo de arma: [pos_der, rot_der, pos_izq, rot_izq]
const IDLE := {
	"sword": [Vector3(0.25, -0.31, -0.42), Vector3(38, 32, -20), Vector3(-0.23, -0.44, -0.32), Vector3(10, -10, 20)],
	"axe": [Vector3(0.26, -0.32, -0.4), Vector3(34, 28, -75), Vector3(-0.23, -0.44, -0.32), Vector3(10, -10, 20)],
	"mace": [Vector3(0.26, -0.32, -0.42), Vector3(36, 28, 0), Vector3(-0.23, -0.44, -0.32), Vector3(10, -10, 20)],
	"dagger": [Vector3(0.23, -0.3, -0.38), Vector3(12, 10, -90), Vector3(-0.23, -0.44, -0.32), Vector3(10, -10, 20)],
	"bow": [Vector3(-0.02, -0.17, -0.36), Vector3(10, 0, 0), Vector3(-0.13, -0.17, -0.46), Vector3(85, -5, -12)],
	"unarmed": [Vector3(0.2, -0.3, -0.36), Vector3(25, 0, 10), Vector3(-0.2, -0.3, -0.36), Vector3(25, 0, -10)],
}


static func idle_pose(kind: String) -> Array:
	return IDLE.get(kind, IDLE["sword"])


## keys: [[t, pos, rot], ...] para cada mano.
static func _anim(length: float, loop: bool, keys_r: Array, keys_l: Array) -> Animation:
	var rot := {}
	var pos := {}
	if not keys_r.is_empty():
		rot[R] = []
		pos[R] = []
		for k: Array in keys_r:
			(rot[R] as Array).append([k[0], k[2]])
			(pos[R] as Array).append([k[0], k[1]])
	if not keys_l.is_empty():
		rot[L] = []
		pos[L] = []
		for k: Array in keys_l:
			(rot[L] as Array).append([k[0], k[2]])
			(pos[L] as Array).append([k[0], k[1]])
	return AnimBuilder.make(length, loop, rot, pos)


static func _hold(pose_pos: Vector3, pose_rot: Vector3, t_end: float) -> Array:
	return [[0.0, pose_pos, pose_rot], [t_end, pose_pos, pose_rot]]


static func build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for kind: String in ["sword", "axe", "mace", "dagger", "unarmed"]:
		_melee_set(lib, kind)
	_bow_set(lib)
	_common_set(lib)
	_shield_set(lib)
	return lib


## Separa una biblioteca combinada en dos: pistas de la mano derecha (arma)
## y de la izquierda (escudo, hechizos). Cada mano tiene su propio reproductor
## para poder combinar, p. ej., un ataque con espada y el escudo en guardia.
static func split(lib: AnimationLibrary) -> Array[AnimationLibrary]:
	var right := AnimationLibrary.new()
	var left := AnimationLibrary.new()
	for n: StringName in lib.get_animation_list():
		var a := lib.get_animation(n)
		var ar := a.duplicate(true) as Animation
		var al := a.duplicate(true) as Animation
		for i in range(ar.get_track_count() - 1, -1, -1):
			if String(ar.track_get_path(i)).begins_with("HandL"):
				ar.remove_track(i)
		for i in range(al.get_track_count() - 1, -1, -1):
			if String(al.track_get_path(i)).begins_with("HandR"):
				al.remove_track(i)
		if ar.get_track_count() > 0:
			right.add_animation(n, ar)
		if al.get_track_count() > 0:
			left.add_animation(n, al)
	return [right, left]


const SHIELD_IDLE_POS := Vector3(-0.38, -0.46, -0.4)
const SHIELD_IDLE_ROT := Vector3(-8, -28, 10)
const SHIELD_BLOCK_POS := Vector3(-0.12, -0.24, -0.38)
const SHIELD_BLOCK_ROT := Vector3(2, 10, 0)


static func _shield_set(lib: AnimationLibrary) -> void:
	var ip := SHIELD_IDLE_POS
	var ir := SHIELD_IDLE_ROT
	var bp := SHIELD_BLOCK_POS
	var br := SHIELD_BLOCK_ROT
	lib.add_animation("shield_idle", _anim(3.2, true, [], [[0.0, ip, ir], [1.6, ip + Vector3(0, 0.007, 0.003), ir + Vector3(-1, 0, 0.5)], [3.2, ip, ir]]))
	lib.add_animation("shield_run", _anim(0.72, true, [], [[0.0, ip + Vector3(0, -0.03, 0.03), ir], [0.36, ip + Vector3(0, 0.0, 0.0), ir + Vector3(4, 0, 0)], [0.72, ip + Vector3(0, -0.03, 0.03), ir]]))
	lib.add_animation("shield_block", _anim(0.2, false, [], [[0.0, ip, ir], [0.2, bp, br]]))
	lib.add_animation("shield_block_hit", _anim(0.35, false, [], [[0.0, bp, br], [0.06, bp + Vector3(0.02, -0.03, 0.08), br + Vector3(-8, 4, 0)], [0.35, bp, br]]))
	lib.add_animation("shield_hurt", _anim(0.4, false, [], [[0.0, ip, ir], [0.06, ip + Vector3(-0.02, -0.06, 0.06), ir + Vector3(-10, 0, -5)], [0.4, ip, ir]]))
	lib.add_animation("shield_attack", _anim(0.6, false, [], [[0.0, ip, ir], [0.2, ip + Vector3(-0.03, -0.03, 0.04), ir + Vector3(-4, -6, 0)], [0.6, ip, ir]]))
	lib.add_animation("shield_interact", _anim(0.55, false, [], [[0.0, ip, ir], [0.25, ip + Vector3(0.06, -0.08, -0.06), ir + Vector3(-10, 0, 0)], [0.55, ip, ir]]))
	lib.add_animation("shield_equip", _anim(0.45, false, [], [[0.0, ip + Vector3(0, -0.3, 0.1), ir], [0.45, ip, ir]]))
	lib.add_animation("shield_unequip", _anim(0.35, false, [], [[0.0, ip, ir], [0.35, ip + Vector3(0, -0.3, 0.1), ir]]))


static func _breath(kind: String) -> Animation:
	var p: Array = idle_pose(kind)
	var pr: Vector3 = p[0]
	var rr: Vector3 = p[1]
	var pl: Vector3 = p[2]
	var rl: Vector3 = p[3]
	var up := Vector3(0, 0.008, 0.004)
	return _anim(3.2, true,
		[[0.0, pr, rr], [1.6, pr + up, rr + Vector3(-1.5, 0, 0.8)], [3.2, pr, rr]],
		[[0.0, pl, rl], [1.6, pl + up * 0.8, rl + Vector3(-1, 0, -0.5)], [3.2, pl, rl]])


static func _run(kind: String) -> Animation:
	var p: Array = idle_pose(kind)
	var pr: Vector3 = p[0] + Vector3(0.02, -0.06, 0.06)
	var rr: Vector3 = p[1] + Vector3(-22, -8, -12)
	var pl: Vector3 = p[2] + Vector3(0, 0.02, 0.0)
	var rl: Vector3 = p[3]
	var sway := Vector3(0.0, 0.03, -0.03)
	return _anim(0.72, true,
		[[0.0, pr, rr], [0.18, pr + sway, rr + Vector3(6, 0, 4)], [0.36, pr, rr], [0.54, pr - sway * 0.6, rr + Vector3(-5, 0, -3)], [0.72, pr, rr]],
		[[0.0, pl - sway, rl], [0.18, pl, rl], [0.36, pl + sway, rl + Vector3(8, 0, 0)], [0.54, pl, rl], [0.72, pl - sway, rl]])


static func _melee_set(lib: AnimationLibrary, kind: String) -> void:
	var p: Array = idle_pose(kind)
	var pr: Vector3 = p[0]
	var rr: Vector3 = p[1]
	var pl: Vector3 = p[2]
	var rl: Vector3 = p[3]
	lib.add_animation(kind + "_idle", _breath(kind))
	lib.add_animation(kind + "_run", _run(kind))
	var left_still := _hold(pl, rl, 1.0)
	var left_drop := [[0.0, pl, rl], [0.2, pl + Vector3(0, -0.04, 0.04), rl + Vector3(-10, 0, 0)], [0.9, pl, rl]]

	match kind:
		"sword":
			# 1: tajo de derecha a izquierda (la hoja cruza la pantalla en horizontal)
			lib.add_animation("sword_attack_1", _anim(0.78, false, [
				[0.0, pr, rr],
				[0.16, Vector3(0.36, -0.12, -0.26), Vector3(40, -110, -70)],
				[0.27, Vector3(0.14, -0.2, -0.5), Vector3(8, 75, -90)],
				[0.36, Vector3(-0.22, -0.32, -0.38), Vector3(-5, 135, -95)],
				[0.78, pr, rr]], left_drop))
			# 2: revés ascendente de izquierda a derecha
			lib.add_animation("sword_attack_2", _anim(0.8, false, [
				[0.0, pr, rr],
				[0.17, Vector3(-0.2, -0.36, -0.32), Vector3(-25, 120, 90)],
				[0.29, Vector3(0.06, -0.18, -0.52), Vector3(15, -80, 90)],
				[0.4, Vector3(0.33, -0.07, -0.34), Vector3(35, -140, 100)],
				[0.8, pr, rr]], left_drop))
			# 3: golpe vertical descendente
			lib.add_animation("sword_attack_3", _anim(0.9, false, [
				[0.0, pr, rr],
				[0.22, Vector3(0.17, 0.05, -0.2), Vector3(150, 15, 0)],
				[0.36, Vector3(0.06, -0.12, -0.52), Vector3(45, 5, 0)],
				[0.46, Vector3(0.04, -0.42, -0.42), Vector3(-35, 5, 0)],
				[0.9, pr, rr]], left_drop))
			# Estocada (al avanzar)
			lib.add_animation("sword_attack_thrust", _anim(0.7, false, [
				[0.0, pr, rr],
				[0.16, Vector3(0.2, -0.24, -0.2), Vector3(8, 14, -90)],
				[0.28, Vector3(0.1, -0.2, -0.64), Vector3(2, 6, -90)],
				[0.7, pr, rr]], left_drop))
			lib.add_animation("sword_block", _anim(0.25, false, [
				[0.0, pr, rr], [0.12, Vector3(0.1, -0.16, -0.4), Vector3(12, 78, 85)], [0.25, Vector3(0.08, -0.15, -0.4), Vector3(12, 78, 85)]], left_still))
			lib.add_animation("sword_block_hit", _anim(0.35, false, [
				[0.0, Vector3(0.08, -0.15, -0.4), Vector3(12, 78, 85)],
				[0.07, Vector3(0.11, -0.19, -0.3), Vector3(20, 70, 95)],
				[0.35, Vector3(0.08, -0.15, -0.4), Vector3(12, 78, 85)]], left_still))
		"axe":
			lib.add_animation("axe_attack_1", _anim(0.95, false, [
				[0.0, pr, rr],
				[0.26, Vector3(0.36, -0.04, -0.2), Vector3(70, -100, -60)],
				[0.4, Vector3(0.12, -0.17, -0.52), Vector3(15, 65, -85)],
				[0.52, Vector3(-0.22, -0.36, -0.38), Vector3(-15, 130, -90)],
				[0.95, pr, rr]], left_drop))
			lib.add_animation("axe_attack_2", _anim(1.0, false, [
				[0.0, pr, rr],
				[0.28, Vector3(0.16, 0.16, -0.12), Vector3(155, 10, -90)],
				[0.43, Vector3(0.06, -0.14, -0.55), Vector3(35, 5, -90)],
				[0.55, Vector3(0.05, -0.45, -0.4), Vector3(-40, 5, -90)],
				[1.0, pr, rr]], left_drop))
			lib.add_animation("axe_attack_3", lib.get_animation("axe_attack_1").duplicate())
			lib.add_animation("axe_attack_thrust", lib.get_animation("axe_attack_2").duplicate())
			lib.add_animation("axe_block", _anim(0.25, false, [
				[0.0, pr, rr], [0.12, Vector3(0.04, -0.14, -0.36), Vector3(10, 80, 0)], [0.25, Vector3(0.04, -0.14, -0.36), Vector3(10, 80, 0)]], left_still))
			lib.add_animation("axe_block_hit", _anim(0.35, false, [
				[0.0, Vector3(0.04, -0.14, -0.36), Vector3(10, 80, 0)], [0.07, Vector3(0.06, -0.18, -0.27), Vector3(18, 72, 8)],
				[0.35, Vector3(0.04, -0.14, -0.36), Vector3(10, 80, 0)]], left_still))
		"mace":
			lib.add_animation("mace_attack_1", _anim(0.92, false, [
				[0.0, pr, rr],
				[0.24, Vector3(0.18, 0.14, -0.12), Vector3(150, 20, 0)],
				[0.38, Vector3(0.06, -0.12, -0.55), Vector3(35, 5, 0)],
				[0.5, Vector3(0.02, -0.44, -0.42), Vector3(-40, 5, 0)],
				[0.92, pr, rr]], left_drop))
			lib.add_animation("mace_attack_2", _anim(0.88, false, [
				[0.0, pr, rr],
				[0.22, Vector3(0.36, -0.1, -0.24), Vector3(40, -105, 0)],
				[0.34, Vector3(0.12, -0.18, -0.52), Vector3(10, 70, 0)],
				[0.46, Vector3(-0.24, -0.32, -0.36), Vector3(-5, 130, 0)],
				[0.88, pr, rr]], left_drop))
			lib.add_animation("mace_attack_3", lib.get_animation("mace_attack_1").duplicate())
			lib.add_animation("mace_attack_thrust", lib.get_animation("mace_attack_2").duplicate())
			lib.add_animation("mace_block", _anim(0.25, false, [
				[0.0, pr, rr], [0.12, Vector3(0.05, -0.13, -0.37), Vector3(10, 78, 85)], [0.25, Vector3(0.05, -0.13, -0.37), Vector3(10, 78, 85)]], left_still))
			lib.add_animation("mace_block_hit", _anim(0.35, false, [
				[0.0, Vector3(0.05, -0.13, -0.37), Vector3(10, 78, 85)], [0.07, Vector3(0.07, -0.17, -0.28), Vector3(18, 70, 95)],
				[0.35, Vector3(0.05, -0.13, -0.37), Vector3(10, 78, 85)]], left_still))
		"dagger":
			lib.add_animation("dagger_attack_1", _anim(0.45, false, [
				[0.0, pr, rr],
				[0.08, Vector3(0.2, -0.22, -0.22), Vector3(10, 10, -90)],
				[0.16, Vector3(0.07, -0.17, -0.6), Vector3(2, 2, -90)],
				[0.45, pr, rr]], left_drop))
			lib.add_animation("dagger_attack_2", _anim(0.5, false, [
				[0.0, pr, rr],
				[0.1, Vector3(0.32, -0.12, -0.3), Vector3(30, -100, -90)],
				[0.2, Vector3(-0.12, -0.28, -0.42), Vector3(0, 80, -90)],
				[0.5, pr, rr]], left_drop))
			lib.add_animation("dagger_attack_3", lib.get_animation("dagger_attack_1").duplicate())
			lib.add_animation("dagger_attack_thrust", lib.get_animation("dagger_attack_1").duplicate())
			lib.add_animation("dagger_block", _anim(0.2, false, [
				[0.0, pr, rr], [0.1, Vector3(0.06, -0.15, -0.34), Vector3(20, 60, -10)], [0.2, Vector3(0.06, -0.15, -0.34), Vector3(20, 60, -10)]], left_still))
			lib.add_animation("dagger_block_hit", _anim(0.3, false, [
				[0.0, Vector3(0.06, -0.15, -0.34), Vector3(20, 60, -10)], [0.06, Vector3(0.08, -0.19, -0.26), Vector3(28, 55, 0)],
				[0.3, Vector3(0.06, -0.15, -0.34), Vector3(20, 60, -10)]], left_still))
		"unarmed":
			# Puñetazos alternos
			lib.add_animation("unarmed_attack_1", _anim(0.5, false, [
				[0.0, pr, rr], [0.1, pr + Vector3(0.02, -0.02, 0.08), rr], [0.2, Vector3(0.08, -0.16, -0.62), Vector3(10, 10, 80)], [0.5, pr, rr]],
				_hold(pl, rl, 0.5)))
			lib.add_animation("unarmed_attack_2", _anim(0.5, false, _hold(pr, rr, 0.5),
				[[0.0, pl, rl], [0.1, pl + Vector3(-0.02, -0.02, 0.08), rl], [0.2, Vector3(-0.08, -0.16, -0.62), Vector3(10, -10, -80)], [0.5, pl, rl]]))
			lib.add_animation("unarmed_attack_3", lib.get_animation("unarmed_attack_1").duplicate())
			lib.add_animation("unarmed_attack_thrust", lib.get_animation("unarmed_attack_1").duplicate())
			lib.add_animation("unarmed_block", _anim(0.2, false,
				[[0.0, pr, rr], [0.2, Vector3(0.1, -0.12, -0.3), Vector3(70, 0, 10)]],
				[[0.0, pl, rl], [0.2, Vector3(-0.1, -0.12, -0.3), Vector3(70, 0, -10)]]))
			lib.add_animation("unarmed_block_hit", lib.get_animation("unarmed_block").duplicate())
			# Lanzamiento de hechizo (mano izquierda al frente)
			lib.add_animation("spell_cast", _anim(0.75, false, _hold(pr, rr, 0.75), [
				[0.0, pl, rl],
				[0.25, Vector3(-0.18, -0.2, -0.22), Vector3(60, -20, -20)],
				[0.38, Vector3(-0.06, -0.14, -0.6), Vector3(80, -5, 0)],
				[0.75, pl, rl]]))
	# Golpe recibido y desenvainar comunes a cada arma
	lib.add_animation(kind + "_hurt", _anim(0.4, false, [
		[0.0, pr, rr], [0.06, pr + Vector3(0.03, -0.07, 0.07), rr + Vector3(-15, 5, 8)], [0.4, pr, rr]],
		[[0.0, pl, rl], [0.06, pl + Vector3(-0.02, -0.06, 0.06), rl + Vector3(-10, 0, -5)], [0.4, pl, rl]]))
	lib.add_animation(kind + "_equip", _anim(0.45, false, [
		[0.0, pr + Vector3(0.05, -0.35, 0.15), rr + Vector3(-50, 0, 0)], [0.45, pr, rr]],
		[[0.0, pl + Vector3(0, -0.3, 0.1), rl], [0.45, pl, rl]]))
	lib.add_animation(kind + "_unequip", _anim(0.35, false, [
		[0.0, pr, rr], [0.35, pr + Vector3(0.05, -0.35, 0.15), rr + Vector3(-50, 0, 0)]],
		[[0.0, pl, rl], [0.35, pl + Vector3(0, -0.3, 0.1), rl]]))


static func _bow_set(lib: AnimationLibrary) -> void:
	var p: Array = idle_pose("bow")
	var pr: Vector3 = p[0]
	var rr: Vector3 = p[1]
	var pl: Vector3 = p[2]
	var rl: Vector3 = p[3]
	lib.add_animation("bow_idle", _breath("bow"))
	lib.add_animation("bow_run", _run("bow"))
	var drawn_r := Vector3(0.03, -0.1, -0.1)
	var aim_l := Vector3(-0.06, -0.12, -0.5)
	lib.add_animation("bow_draw", _anim(0.85, false, [
		[0.0, pr, rr], [0.25, Vector3(-0.03, -0.14, -0.4), Vector3(10, 0, 0)], [0.85, drawn_r, Vector3(5, 0, 0)]],
		[[0.0, pl, rl], [0.85, aim_l, Vector3(88, -2, -4)]]))
	lib.add_animation("bow_hold", _anim(1.6, true, [
		[0.0, drawn_r, Vector3(5, 0, 0)], [0.8, drawn_r + Vector3(0.002, 0.003, 0), Vector3(5, 0, 1)], [1.6, drawn_r, Vector3(5, 0, 0)]],
		[[0.0, aim_l, Vector3(88, -2, -4)], [0.8, aim_l + Vector3(0.003, 0.004, 0), Vector3(88.5, -2, -3)], [1.6, aim_l, Vector3(88, -2, -4)]]))
	lib.add_animation("bow_release", _anim(0.55, false, [
		[0.0, drawn_r, Vector3(5, 0, 0)], [0.06, drawn_r + Vector3(0.07, 0.02, 0.04), Vector3(0, -20, 20)], [0.55, pr, rr]],
		[[0.0, aim_l, Vector3(88, -2, -4)], [0.08, aim_l + Vector3(0, 0.02, 0.03), Vector3(80, -2, -4)], [0.55, pl, rl]]))
	lib.add_animation("bow_hurt", _anim(0.4, false, [[0.0, pr, rr], [0.06, pr + Vector3(0.03, -0.07, 0.07), rr], [0.4, pr, rr]],
		[[0.0, pl, rl], [0.06, pl + Vector3(0, -0.06, 0.06), rl], [0.4, pl, rl]]))
	lib.add_animation("bow_equip", _anim(0.45, false, [[0.0, pr + Vector3(0, -0.3, 0.1), rr], [0.45, pr, rr]],
		[[0.0, pl + Vector3(0, -0.35, 0.15), rl + Vector3(-40, 0, 0)], [0.45, pl, rl]]))
	lib.add_animation("bow_unequip", _anim(0.35, false, [[0.0, pr, rr], [0.35, pr + Vector3(0, -0.3, 0.1), rr]],
		[[0.0, pl, rl], [0.35, pl + Vector3(0, -0.35, 0.15), rl + Vector3(-40, 0, 0)]]))
	lib.add_animation("bow_block", lib.get_animation("bow_idle").duplicate())
	lib.add_animation("bow_block_hit", lib.get_animation("bow_hurt").duplicate())


static func _common_set(lib: AnimationLibrary) -> void:
	var p: Array = idle_pose("sword")
	var pl: Vector3 = p[2]
	var rl: Vector3 = p[3]
	# Interactuar: la mano izquierda se adelanta (abrir, recoger, saquear)
	lib.add_animation("interact", _anim(0.55, false, [], [
		[0.0, pl, rl], [0.2, Vector3(-0.12, -0.2, -0.5), Vector3(60, -10, -30)], [0.32, Vector3(-0.1, -0.22, -0.52), Vector3(55, -10, -30)], [0.55, pl, rl]]))
	lib.add_animation("death", _anim(1.2, false, [
		[0.0, Vector3(0.2, -0.24, -0.4), Vector3(55, 25, -10)], [1.2, Vector3(0.25, -0.75, -0.2), Vector3(-30, 10, -40)]],
		[[0.0, pl, rl], [1.2, pl + Vector3(-0.05, -0.4, 0.1), rl + Vector3(-30, 0, 0)]]))
