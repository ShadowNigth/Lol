class_name Bounties
extends RefCounted
## Encargos generados para los tablones de anuncios de cada asentamiento.
## Cada tablón ofrece un encargo distinto cada PERIOD_DAYS días, determinista
## según la semilla del mundo, el lugar y el periodo (caza, limpieza o entrega).
## La definición del encargo se guarda junto a su estado en GameState.quests
## (clave "def"), así que viaja con la partida y se valida al cargar.

const PERIOD_DAYS := 3
const SITES := {
	"hojarrubia": {"name": "Hojarrubia", "faction": "hojarrubia"},
	"robledal": {"name": "Robledal", "faction": "robledal"},
	"inn_lobo": {"name": "la Posada del Lobo Gris", "faction": "robledal"},
}
const DELIVERIES := [["wolf_pelt", 2, 3, 30], ["bone_dust", 3, 5, 12], ["wolf_fang", 3, 6, 10]]


static func giver_id(site: String) -> String:
	return "board_" + site


static func current_id(site: String) -> String:
	return "encargo_%s_%d" % [site, int((maxi(GameState.day, 1) - 1) / PERIOD_DAYS)]


## Encargo activo de este tablón (cualquier periodo), o "".
static func active_for(site: String) -> String:
	for qid: String in GameState.quests.keys():
		if qid.begins_with("encargo_%s_" % site) and QuestManager.is_active(qid):
			return qid
	return ""


## Genera la definición del encargo vigente del lugar.
static func generate(site: String) -> Dictionary:
	var info: Dictionary = SITES.get(site, {"name": site, "faction": "hojarrubia"})
	var place := str(info["name"])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%s" % [site, GameState.world_seed, current_id(site)])
	var giver := giver_id(site)
	var back := {"text": "Vuelve al tablón de anuncios de %s para cobrar." % place, "objective": {"type": "talk", "target": giver}}
	var def := {"giver": giver, "generated": true}
	var gold := 0
	match rng.randi() % 3:
		0:
			var n := rng.randi_range(3, 6)
			gold = 14 * n
			def["title"] = "Encargo: lobos cerca de %s" % place
			def["type"] = "cazar"
			def["description"] = "Una nota clavada en el tablón: «Se paga por cada lobo abatido en los alrededores de %s. Las manadas se están acercando demasiado a los corrales.»" % place
			def["stages"] = [{"text": "Caza lobos (0/%d)." % n, "objective": {"type": "kill", "target": "wolf", "count": n}}, back]
		1:
			var n2 := rng.randi_range(2, 4)
			gold = 22 * n2
			def["title"] = "Encargo: muertos inquietos"
			def["type"] = "matar"
			def["description"] = "Una nota con el sello de la guardia: «Recompensa por destruir esqueletos en ruinas, criptas o túmulos de la región. Que los muertos vuelvan a descansar.»"
			def["stages"] = [{"text": "Destruye esqueletos (0/%d)." % n2, "objective": {"type": "kill", "target": "skeleton", "count": n2}}, back]
		_:
			var d: Array = DELIVERIES[rng.randi() % DELIVERIES.size()]
			var n3 := rng.randi_range(int(d[1]), int(d[2]))
			var item := str(d[0])
			gold = int(d[3]) * n3
			def["title"] = "Encargo: se busca %s" % ItemDB.display_name(item).to_lower()
			def["type"] = "entregar"
			def["description"] = "Una nota escrita con prisa: «Compro %d × %s a buen precio. Dejadlo en el tablón de %s.»" % [n3, ItemDB.display_name(item), place]
			def["stages"] = [{"text": "Consigue %d × %s." % [n3, ItemDB.display_name(item)], "objective": {"type": "collect", "target": item, "count": n3}}, back]
			def["rewards_items_remove"] = [{"id": item, "count": n3}]
	def["rewards"] = {"gold": gold, "items": [], "reputation": {str(info["faction"]): 3},
			"remove_items": def.get("rewards_items_remove", [])}
	def.erase("rewards_items_remove")
	return def


## ¿Es válida una definición cargada de una partida? (evita datos corruptos)
static func valid_def(def: Variant) -> bool:
	if not (def is Dictionary):
		return false
	var d := def as Dictionary
	if not (d.get("title", null) is String) or not (d.get("stages", null) is Array) or (d["stages"] as Array).is_empty():
		return false
	for st: Variant in d["stages"]:
		if not (st is Dictionary) or not ((st as Dictionary).get("objective", null) is Dictionary) or not ((st as Dictionary).get("text", null) is String):
			return false
		var obj: Dictionary = (st as Dictionary)["objective"]
		if not str(obj.get("type", "")) in ["kill", "collect", "talk", "reach"]:
			return false
	return d.get("rewards", {}) is Dictionary


## Interacción con el tablón: cobrar, ver el progreso o aceptar el encargo vigente.
static func use_board(site: String) -> void:
	var active := active_for(site)
	if active != "":
		var st := QuestManager.current_stage(active)
		if str((st.get("objective", {}) as Dictionary).get("type", "")) == "talk":
			QuestManager.on_talk(giver_id(site))
		else:
			Events.notify.emit("Encargo en curso: %s" % QuestManager.stage_text(active), "quest")
		return
	var qid := current_id(site)
	if not GameState.quests.has(qid):
		var def := generate(site)
		GameState.quests[qid] = {"stage": 0, "progress": 0, "done": false, "def": def}
		Events.notify.emit("Nuevo encargo: %s" % def["title"], "quest")
		Events.notify.emit(str(def["description"]), "info")
		Audio.play_2d("quest", -3.0)
		QuestManager.check_collect_objectives()
		return
	Events.notify.emit("No hay encargos nuevos en el tablón. Vuelve dentro de unos días.", "info")
