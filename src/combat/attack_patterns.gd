class_name AttackPatterns
extends RefCounted
## Patrones de ataque por tipo de arma: animación, ventana activa de golpe y
## arco barrido (en grados yaw/pitch relativos a la cámara) para la detección
## real de impactos con rayos. Los tiempos se escalan con WeaponData.speed.

const PATTERNS := {
	"sword": [
		{"anim": "sword_attack_1", "hit": [0.17, 0.36], "from": Vector2(55, 12), "to": Vector2(-55, -14), "dmg": 1.0, "sound": "swing"},
		{"anim": "sword_attack_2", "hit": [0.18, 0.38], "from": Vector2(-55, -14), "to": Vector2(55, 14), "dmg": 1.0, "sound": "swing"},
		{"anim": "sword_attack_3", "hit": [0.24, 0.44], "from": Vector2(4, 45), "to": Vector2(2, -30), "dmg": 1.35, "sound": "swing_heavy"},
	],
	"sword_thrust": {"anim": "sword_attack_thrust", "hit": [0.17, 0.3], "from": Vector2(0, -2), "to": Vector2(0, -4), "dmg": 1.15, "sound": "swing_fast", "reach_bonus": 0.4},
	"axe": [
		{"anim": "axe_attack_1", "hit": [0.27, 0.5], "from": Vector2(55, 25), "to": Vector2(-45, -20), "dmg": 1.0, "sound": "swing_heavy"},
		{"anim": "axe_attack_2", "hit": [0.3, 0.52], "from": Vector2(3, 50), "to": Vector2(2, -30), "dmg": 1.3, "sound": "swing_heavy"},
	],
	"axe_thrust": {"anim": "axe_attack_2", "hit": [0.3, 0.52], "from": Vector2(3, 50), "to": Vector2(2, -30), "dmg": 1.3, "sound": "swing_heavy"},
	"mace": [
		{"anim": "mace_attack_1", "hit": [0.26, 0.48], "from": Vector2(5, 50), "to": Vector2(2, -30), "dmg": 1.2, "sound": "swing_heavy"},
		{"anim": "mace_attack_2", "hit": [0.23, 0.44], "from": Vector2(60, 8), "to": Vector2(-55, -6), "dmg": 1.0, "sound": "swing_heavy"},
	],
	"mace_thrust": {"anim": "mace_attack_1", "hit": [0.26, 0.48], "from": Vector2(5, 50), "to": Vector2(2, -30), "dmg": 1.2, "sound": "swing_heavy"},
	"dagger": [
		{"anim": "dagger_attack_1", "hit": [0.09, 0.2], "from": Vector2(0, -2), "to": Vector2(0, -3), "dmg": 1.0, "sound": "swing_fast"},
		{"anim": "dagger_attack_2", "hit": [0.1, 0.22], "from": Vector2(45, 8), "to": Vector2(-35, -10), "dmg": 0.9, "sound": "swing_fast"},
	],
	"dagger_thrust": {"anim": "dagger_attack_1", "hit": [0.09, 0.2], "from": Vector2(0, -2), "to": Vector2(0, -3), "dmg": 1.1, "sound": "swing_fast"},
	"unarmed": [
		{"anim": "unarmed_attack_1", "hit": [0.12, 0.24], "from": Vector2(8, -2), "to": Vector2(0, -4), "dmg": 1.0, "sound": "swing_fast"},
		{"anim": "unarmed_attack_2", "hit": [0.12, 0.24], "from": Vector2(-8, -2), "to": Vector2(0, -4), "dmg": 1.0, "sound": "swing_fast"},
	],
	"unarmed_thrust": {"anim": "unarmed_attack_1", "hit": [0.12, 0.24], "from": Vector2(8, -2), "to": Vector2(0, -4), "dmg": 1.0, "sound": "swing_fast"},
}


## Devuelve el patrón según el tipo de arma, el índice de combo y la dirección
## de movimiento (avanzar = estocada; lateral = tajo en esa dirección).
static func pick(kind: String, combo_index: int, move_input: Vector2) -> Dictionary:
	var list: Array = PATTERNS.get(kind, PATTERNS["unarmed"])
	if move_input.y < -0.5 and absf(move_input.x) < 0.3 and PATTERNS.has(kind + "_thrust"):
		return PATTERNS[kind + "_thrust"]
	if move_input.x < -0.5 and kind == "sword":
		return list[1]
	if move_input.x > 0.5 and kind == "sword":
		return list[0]
	return list[combo_index % list.size()]
