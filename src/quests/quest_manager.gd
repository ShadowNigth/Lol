class_name QuestManager
extends RefCounted
## Lógica de misiones: aceptar, avanzar etapas según eventos del juego,
## completar y entregar recompensas. Estado en GameState.quests:
##   id -> {"stage": int, "progress": int, "done": bool}
##
## Objetivos de etapa: kill, collect, reach (lugar o mazmorra), talk (con PNJ;
## admite "requires_flag"), flag (espera una bandera de historia, p. ej. que
## se abra una jaula) y escort (el PNJ "target" sigue al jugador hasta el
## lugar "to"; ver NPC._follow_update). La misión puede tener "on_accept"
## ({"flags": [...]}) que se aplica al aceptarla. Cada etapa puede tener "say" (lo que dice el PNJ al
## cumplirla), "effects" ({"flags": [...]}) que se aplican al completarla y
## "skip_if_flag" (se salta si la historia ya la dejó atrás).
## La misión puede exigir "requires_flag"/"requires_not_flag" para ofrecerse.


static func state(id: String) -> Dictionary:
	return GameState.quests.get(id, {})


static func is_active(id: String) -> bool:
	var s := state(id)
	return not s.is_empty() and not bool(s.get("done", false))


static func is_done(id: String) -> bool:
	return bool(state(id).get("done", false))


static func can_offer(id: String) -> bool:
	if not state(id).is_empty():
		return false
	var q := QuestDB.get_quest(id)
	var req: Dictionary = q.get("requires_reputation", {})
	for f: String in req:
		if GameState.reputation(f) < int(req[f]):
			return false
	if str(q.get("requires_flag", "")) != "" and not GameState.has_flag(str(q["requires_flag"])):
		return false
	if str(q.get("requires_not_flag", "")) != "" and GameState.has_flag(str(q["requires_not_flag"])):
		return false
	return true


static func accept(id: String) -> void:
	if not can_offer(id):
		return
	GameState.quests[id] = {"stage": 0, "progress": 0, "done": false}
	var q := QuestDB.get_quest(id)
	Events.notify.emit("Nueva misión: %s" % q["title"], "quest")
	Audio.play_2d("quest", -3.0)
	for f: String in (q.get("on_accept", {}) as Dictionary).get("flags", []):
		GameState.set_flag(f)
	# Los objetivos de recoger (o de bandera) pueden estar ya cumplidos
	check_collect_objectives()
	_check_flag_objectives()


static func current_stage(id: String) -> Dictionary:
	var q := QuestDB.get_quest(id)
	var s := state(id)
	var stages: Array = q.get("stages", [])
	var i := int(s.get("stage", 0))
	if i >= 0 and i < stages.size():
		return stages[i]
	return {}


static func stage_text(id: String) -> String:
	var st := current_stage(id)
	if st.is_empty():
		return ""
	var text := str(st["text"])
	var obj: Dictionary = st.get("objective", {})
	if str(obj.get("type", "")) == "kill":
		text = text.replace("(0/%d)" % int(obj["count"]), "(%d/%d)" % [int(state(id).get("progress", 0)), int(obj["count"])])
	return text


static func _advance(id: String) -> void:
	var q := QuestDB.get_quest(id)
	var s := state(id)
	var fx: Dictionary = current_stage(id).get("effects", {})
	s["stage"] = int(s["stage"]) + 1
	s["progress"] = 0
	var new_stage := int(s["stage"])
	var stages: Array = q["stages"]
	if new_stage >= stages.size():
		_complete(id)
	else:
		Events.notify.emit("%s: %s" % [q["title"], stage_text(id)], "quest")
	# Efectos de la etapa cumplida (banderas de historia). Pueden cumplir ya la
	# etapa siguiente: en ese caso el avance anidado hace sus comprobaciones.
	for f: String in fx.get("flags", []):
		GameState.set_flag(f)
	if new_stage < stages.size() and int(s["stage"]) == new_stage:
		check_collect_objectives()
		_check_flag_objectives()


static func _complete(id: String) -> void:
	var q := QuestDB.get_quest(id)
	var s := state(id)
	s["done"] = true
	var r: Dictionary = q.get("rewards", {})
	var p := GameState.player
	for it: Dictionary in r.get("remove_items", []):
		GameState.remove_item(str(it["id"]), int(it["count"]))
	if p and r.has("gold"):
		p.set("gold", int(p.get("gold")) + int(r["gold"]))
	for it2: Dictionary in r.get("items", []):
		GameState.give_item(p, it2)
	var rep: Dictionary = r.get("reputation", {})
	for f: String in rep:
		GameState.add_reputation(f, int(rep[f]))
	Events.notify.emit("Misión completada: %s (+%d oro)" % [q["title"], int(r.get("gold", 0))], "quest")
	Audio.play_2d("level_up", -2.0)


## Eventos del juego ----------------------------------------------------------

static func on_enemy_killed(enemy_type: String) -> void:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		var tgt := str(obj.get("target", ""))
		# Objetivo exacto o familia por prefijo ("skeleton" -> skeleton_archer, "wolf" -> wolf_alpha)
		if str(obj.get("type", "")) == "kill" and (tgt == enemy_type or tgt == "any" or enemy_type.begins_with(tgt + "_")):
			var s := state(id)
			s["progress"] = int(s["progress"]) + 1
			if int(s["progress"]) >= int(obj["count"]):
				_advance(id)
			else:
				Events.notify.emit(stage_text(id), "quest")


static func on_area_entered(area_id: String) -> void:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		if str(obj.get("type", "")) == "reach" and str(obj.get("target", "")) == area_id:
			_advance(id)


## Bandera de historia activada: avanza las etapas que la esperaban.
static func on_flag_set(_flag: String) -> void:
	_check_flag_objectives()


static func _check_flag_objectives() -> void:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var st := current_stage(id)
		var obj: Dictionary = st.get("objective", {})
		var skip := str(st.get("skip_if_flag", ""))
		# Etapas que dejan de tener sentido (p. ej. la persona ya fue rescatada)
		if skip != "" and GameState.has_flag(skip):
			_advance(id)
		elif str(obj.get("type", "")) == "flag" and GameState.has_flag(str(obj.get("target", ""))):
			_advance(id)


static func check_collect_objectives() -> void:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		if str(obj.get("type", "")) == "collect" and GameState.item_count(str(obj["target"])) >= int(obj["count"]):
			_advance(id)


## Hablar con un PNJ: avanza etapas "talk" dirigidas a él. Devuelve una
## entrada por misión que avanzó: {"quest", "say" (texto de la etapa cumplida,
## puede estar vacío) y "completed"} para que el diálogo lo refleje.
static func on_talk(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var st := current_stage(id)
		var obj: Dictionary = st.get("objective", {})
		if str(obj.get("type", "")) != "talk" or str(obj.get("target", "")) != npc_id:
			continue
		if str(obj.get("requires_flag", "")) != "" and not GameState.has_flag(str(obj["requires_flag"])):
			continue
		_advance(id)
		out.append({"quest": id, "say": str(st.get("say", "")), "completed": is_done(id)})
	return out


## Escoltas ---------------------------------------------------------------------

## Misión de escolta activa para este PNJ: {"quest", "to"} o vacío.
static func escort_for(npc_id: String) -> Dictionary:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		if str(obj.get("type", "")) == "escort" and str(obj.get("target", "")) == npc_id:
			return {"quest": id, "to": str(obj.get("to", ""))}
	return {}


## Todas las escoltas en curso: [{"quest", "npc", "to"}] (para recolocar al
## acompañante junto al jugador al cargar partida o al cambiar de zona).
static func active_escorts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		if str(obj.get("type", "")) == "escort":
			out.append({"quest": id, "npc": str(obj.get("target", "")), "to": str(obj.get("to", ""))})
	return out


## El acompañante ha llegado a un lugar: completa las etapas de escolta que
## lo tenían como destino.
static func on_escort_arrived(npc_id: String, loc_id: String) -> void:
	for id: String in GameState.quests.keys():
		if not is_active(id):
			continue
		var obj: Dictionary = current_stage(id).get("objective", {})
		if str(obj.get("type", "")) == "escort" and str(obj.get("target", "")) == npc_id and str(obj.get("to", "")) == loc_id:
			_advance(id)
