class_name Stats
extends RefCounted
## Atributos, habilidades y valores derivados (salud, aguante, magia).
## Las habilidades mejoran con el uso; al acumular mejoras se sube de nivel.

signal changed
signal died
signal skill_increased(skill: String, value: int)
signal level_up(new_level: int)

const ATTRIBUTES := ["strength", "agility", "endurance", "intelligence", "willpower", "personality", "luck"]
const ATTRIBUTE_NAMES := {"strength": "Fuerza", "agility": "Agilidad", "endurance": "Resistencia",
		"intelligence": "Inteligencia", "willpower": "Voluntad", "personality": "Personalidad", "luck": "Suerte"}
const SKILLS := ["blade", "axe", "blunt", "archery", "block", "light_armor", "heavy_armor", "athletics",
		"acrobatics", "destruction", "restoration", "alteration", "sneak", "mercantile", "speech", "lockpick"]
const SKILL_NAMES := {"blade": "Espadas", "axe": "Hachas", "blunt": "Armas contundentes", "archery": "Arquería",
		"block": "Bloqueo", "light_armor": "Armadura ligera", "heavy_armor": "Armadura pesada", "athletics": "Atletismo",
		"acrobatics": "Acrobacias", "destruction": "Destrucción", "restoration": "Restauración", "alteration": "Alteración",
		"sneak": "Sigilo", "mercantile": "Comercio", "speech": "Elocuencia", "lockpick": "Ganzúas"}
# Atributo que gobierna cada habilidad (para la subida de nivel)
const SKILL_ATTRIBUTE := {"blade": "strength", "axe": "strength", "blunt": "strength", "archery": "agility",
		"block": "endurance", "light_armor": "agility", "heavy_armor": "endurance", "athletics": "endurance",
		"acrobatics": "agility", "destruction": "intelligence", "restoration": "willpower", "alteration": "willpower",
		"sneak": "agility", "mercantile": "personality", "speech": "personality", "lockpick": "agility"}

var level: int = 1
var level_progress: int = 0          # subidas de habilidad desde el último nivel
var attributes: Dictionary = {}
var skills: Dictionary = {}
var skill_xp: Dictionary = {}
var health: float = 100.0
var stamina: float = 100.0
var mana: float = 50.0
var max_health: float = 100.0
var max_stamina: float = 100.0
var max_mana: float = 50.0
var armor_rating: float = 0.0
var resistances: Dictionary = {"fire": 0.0, "frost": 0.0, "poison": 0.0, "shock": 0.0}
var dead: bool = false
var effects: Dictionary = {}          # efecto -> {"time": s, "power": p}
const EFFECT_NAMES := {"burn": "Ardiendo", "frost": "Congelado", "poison": "Envenenado"}


func _init() -> void:
	for a: String in ATTRIBUTES:
		attributes[a] = 40
	for s: String in SKILLS:
		skills[s] = 10
		skill_xp[s] = 0.0
	recalc(true)


func recalc(fill: bool = false) -> void:
	var end_v := float(attributes["endurance"])
	var str_v := float(attributes["strength"])
	var agi_v := float(attributes["agility"])
	var int_v := float(attributes["intelligence"])
	var wil_v := float(attributes["willpower"])
	max_health = 40.0 + end_v * 1.2 + str_v * 0.3 + (level - 1) * (4.0 + end_v * 0.08)
	max_stamina = 50.0 + end_v * 0.6 + agi_v * 0.4 + wil_v * 0.3
	max_mana = 10.0 + int_v * 1.0 + wil_v * 0.2
	if fill:
		health = max_health
		stamina = max_stamina
		mana = max_mana
	health = minf(health, max_health)
	stamina = minf(stamina, max_stamina)
	mana = minf(mana, max_mana)
	changed.emit()


func attr(a: String) -> int:
	return int(attributes.get(a, 40))


func skill(s: String) -> int:
	return int(skills.get(s, 10))


## Multiplicador de daño cuerpo a cuerpo por fuerza y habilidad.
func melee_multiplier(weapon_skill: String) -> float:
	return (1.0 + (attr("strength") - 40) / 120.0) * (0.75 + skill(weapon_skill) / 120.0)


## Probabilidad de golpe crítico (suerte y agilidad).
func crit_chance() -> float:
	return clampf(0.03 + (attr("luck") - 40) / 600.0 + (attr("agility") - 40) / 900.0, 0.01, 0.25)


func stamina_regen() -> float:
	return 9.0 + attr("endurance") * 0.12


func health_regen() -> float:
	return 0.15 + attr("endurance") * 0.01


func mana_regen() -> float:
	return 0.4 + attr("willpower") * 0.03


func move_speed_multiplier() -> float:
	return 1.0 + (attr("agility") - 40) / 400.0 + (skill("athletics") - 10) / 600.0


func regen(delta: float, allow_stamina: bool) -> void:
	if dead:
		return
	var before := Vector3(health, stamina, mana)
	health = minf(max_health, health + health_regen() * delta)
	if allow_stamina:
		stamina = minf(max_stamina, stamina + stamina_regen() * delta)
	mana = minf(max_mana, mana + mana_regen() * delta)
	if before != Vector3(health, stamina, mana):
		changed.emit()


func use_stamina(amount: float) -> bool:
	if stamina < amount * 0.35:
		return false
	stamina = maxf(0.0, stamina - amount)
	changed.emit()
	return true


func use_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	changed.emit()
	return true


## Aplica daño ya mitigado. Devuelve el daño final.
func apply_damage(amount: float) -> float:
	if dead:
		return 0.0
	health = maxf(0.0, health - amount)
	changed.emit()
	if health <= 0.0:
		dead = true
		died.emit()
	return amount


## Reducción por armadura: daño * 100 / (100 + armadura)
func mitigate(amount: float, damage_type: String) -> float:
	var reduced := amount * 100.0 / (100.0 + armor_rating)
	if resistances.has(damage_type):
		reduced *= 1.0 - clampf(float(resistances[damage_type]), -1.0, 0.9)
	return reduced


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(max_health, health + amount)
	changed.emit()


func restore_stamina(amount: float) -> void:
	stamina = minf(max_stamina, stamina + amount)
	changed.emit()


func restore_mana(amount: float) -> void:
	mana = minf(max_mana, mana + amount)
	changed.emit()


## Entrena una habilidad por uso. Devuelve true si sube.
func train(s: String, amount: float = 1.0) -> bool:
	if not skills.has(s):
		return false
	var cur := int(skills[s])
	if cur >= 100:
		return false
	skill_xp[s] = float(skill_xp[s]) + amount
	var needed := 4.0 + cur * 0.55
	if float(skill_xp[s]) >= needed:
		skill_xp[s] = 0.0
		skills[s] = cur + 1
		skill_increased.emit(s, cur + 1)
		level_progress += 1
		if level_progress >= 10:
			level_progress = 0
			_level_up(s)
		changed.emit()
		return true
	return false


func _level_up(last_skill: String) -> void:
	level += 1
	var main_attr: String = SKILL_ATTRIBUTE.get(last_skill, "endurance")
	attributes[main_attr] = mini(100, attr(main_attr) + 3)
	attributes["endurance"] = mini(100, attr("endurance") + 1)
	recalc()
	health = max_health
	level_up.emit(level)


## Estados alterados: quemadura y veneno hacen daño por segundo; la escarcha ralentiza.
func add_effect(effect: String, duration: float, power: float) -> void:
	var res_key := {"burn": "fire", "frost": "frost", "poison": "poison"}.get(effect, "") as String
	var resist := clampf(float(resistances.get(res_key, 0.0)), -1.0, 0.9) if res_key != "" else 0.0
	var dur := duration * (1.0 - resist)
	if dur <= 0.05:
		return
	var cur: Dictionary = effects.get(effect, {"time": 0.0, "power": 0.0})
	effects[effect] = {"time": maxf(float(cur["time"]), dur), "power": maxf(float(cur["power"]), power)}
	changed.emit()


## Avanza los efectos y devuelve el daño de este paso.
func tick_effects(delta: float) -> float:
	if effects.is_empty() or dead:
		return 0.0
	var dmg := 0.0
	for k: String in effects.keys():
		var e: Dictionary = effects[k]
		if k in ["burn", "poison"]:
			dmg += float(e["power"]) * delta
		e["time"] = float(e["time"]) - delta
		if float(e["time"]) <= 0.0:
			effects.erase(k)
			changed.emit()
	return dmg


func slow_factor() -> float:
	if effects.has("frost"):
		return 1.0 - clampf(float((effects["frost"] as Dictionary)["power"]), 0.0, 0.8)
	return 1.0


func active_effect_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in effects:
		out.append(str(EFFECT_NAMES.get(k, k)))
	return out


func to_dict() -> Dictionary:
	return {"level": level, "level_progress": level_progress, "attributes": attributes.duplicate(),
			"skills": skills.duplicate(), "skill_xp": skill_xp.duplicate(), "health": health,
			"stamina": stamina, "mana": mana}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	level_progress = int(d.get("level_progress", 0))
	var attrs: Dictionary = d.get("attributes", {})
	for a: String in ATTRIBUTES:
		attributes[a] = clampi(int(attrs.get(a, 40)), 1, 100)
	var sk: Dictionary = d.get("skills", {})
	var sx: Dictionary = d.get("skill_xp", {})
	for s: String in SKILLS:
		skills[s] = clampi(int(sk.get(s, 10)), 1, 100)
		skill_xp[s] = float(sx.get(s, 0.0))
	recalc()
	health = clampf(float(d.get("health", max_health)), 1.0, max_health)
	stamina = clampf(float(d.get("stamina", max_stamina)), 0.0, max_stamina)
	mana = clampf(float(d.get("mana", max_mana)), 0.0, max_mana)
	dead = false
	changed.emit()
