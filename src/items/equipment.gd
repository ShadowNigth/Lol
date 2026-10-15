class_name Equipment
extends RefCounted
## Ranuras de equipo (ropa, armaduras y escudo) y sus efectos reales:
## valor de armadura (mejorado por las habilidades de armadura ligera/pesada),
## resistencias, bonificaciones, peso y aspecto de los brazos en primera persona.
## El estado se guarda en GameState.equipment (ranura -> id de objeto); un objeto
## equipado sale del inventario y vuelve a él al quitarlo (no puede duplicarse).

const SLOTS: Array[String] = ["head", "chest", "hands", "legs", "feet", "offhand"]
const SLOT_NAMES := {"head": "Cabeza", "chest": "Torso", "hands": "Manos", "legs": "Piernas",
		"feet": "Pies", "offhand": "Escudo"}
const TYPE_NAMES := {"cloth": "Ropa", "light": "Armadura ligera", "heavy": "Armadura pesada"}
const TYPE_SKILL := {"light": "light_armor", "heavy": "heavy_armor"}
const RESIST_NAMES := {"fire": "fuego", "frost": "escarcha", "poison": "veneno", "shock": "rayo"}
const BONUS_NAMES := {"max_mana": "magia máx.", "max_health": "salud máx.", "max_stamina": "aguante máx."}


static func is_equippable(id: String) -> bool:
	var def := ItemDB.get_def(id)
	return def.has("slot") and str(def["slot"]) in SLOTS


static func slot_of(id: String) -> String:
	return str(ItemDB.get_def(id).get("slot", ""))


## Comprueba un diccionario de equipo cargado: descarta ranuras u objetos inválidos.
static func sanitize(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for slot: Variant in (raw as Dictionary):
		var id := str((raw as Dictionary)[slot])
		if str(slot) in SLOTS and is_equippable(id) and slot_of(id) == str(slot):
			out[str(slot)] = id
		else:
			push_warning("Equipo descartado al cargar: %s -> %s" % [slot, id])
	return out


## Multiplicador por habilidad: 0.7 con habilidad 0, 1.2 con habilidad 100.
static func skill_multiplier(armor_type: String, stats: Stats) -> float:
	if not TYPE_SKILL.has(armor_type) or stats == null:
		return 1.0
	return 0.7 + stats.skill(str(TYPE_SKILL[armor_type])) / 200.0


## Calcula armadura, resistencias y bonificaciones del equipo puesto.
static func compute(equipment: Dictionary, stats: Stats) -> Dictionary:
	var armor := 0.0
	var resist := {"fire": 0.0, "frost": 0.0, "poison": 0.0, "shock": 0.0}
	var bonus := {}
	for slot: String in SLOTS:
		var def := ItemDB.get_def(str(equipment.get(slot, "")))
		if def.is_empty():
			continue
		armor += float(def.get("armor", 0.0)) * skill_multiplier(str(def.get("armor_type", "cloth")), stats)
		var r: Dictionary = def.get("resist", {})
		for k: String in r:
			resist[k] = float(resist.get(k, 0.0)) + float(r[k])
		var b: Dictionary = def.get("bonus", {})
		for k: String in b:
			bonus[k] = float(bonus.get(k, 0.0)) + float(b[k])
	for k: String in resist:
		resist[k] = clampf(float(resist[k]), -0.5, 0.75)
	return {"armor": armor, "resist": resist, "bonus": bonus}


static func weight(equipment: Dictionary) -> float:
	var total := 0.0
	for slot: String in equipment:
		total += float(ItemDB.get_def(str(equipment[slot])).get("weight", 0.0))
	return total


## Proporción de piezas ligeras y pesadas (para entrenar las habilidades al recibir golpes).
static func type_counts(equipment: Dictionary) -> Dictionary:
	var out := {"light": 0, "heavy": 0}
	for slot: String in equipment:
		var t := str(ItemDB.get_def(str(equipment[slot])).get("armor_type", "cloth"))
		if out.has(t):
			out[t] = int(out[t]) + 1
	return out


## Aspecto de los brazos en primera persona y modelo del escudo.
static func appearance(equipment: Dictionary) -> Dictionary:
	var chest := ItemDB.get_def(str(equipment.get("chest", "")))
	var hands := ItemDB.get_def(str(equipment.get("hands", "")))
	var off := ItemDB.get_def(str(equipment.get("offhand", "")))
	return {"chest": str(chest.get("look", "cloth")), "hands": str(hands.get("look", "bare")),
			"shield": str(off.get("model", "")), "block": float(off.get("block", 0.0))}


## Texto descriptivo de las propiedades de un objeto equipable.
static func describe(id: String, stats: Stats) -> String:
	var def := ItemDB.get_def(id)
	if not def.has("slot"):
		return ""
	var t := str(def.get("armor_type", "cloth"))
	var base := float(def.get("armor", 0.0))
	var txt := "Ranura: %s · %s\nArmadura: %d (efectiva %.1f con tu habilidad)" % [SLOT_NAMES.get(def["slot"], def["slot"]),
			TYPE_NAMES.get(t, t), int(base), base * skill_multiplier(t, stats)]
	if def.has("block"):
		txt += "\nBloqueo: detiene el %d%% del daño" % int(float(def["block"]) * 100.0)
	var r: Dictionary = def.get("resist", {})
	for k: String in r:
		txt += "\nResistencia a %s: +%d%%" % [RESIST_NAMES.get(k, k), int(float(r[k]) * 100.0)]
	var b: Dictionary = def.get("bonus", {})
	for k: String in b:
		txt += "\n+%d %s" % [int(float(b[k])), BONUS_NAMES.get(k, k)]
	return txt
