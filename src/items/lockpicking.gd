class_name LockPicking
extends RefCounted
## Cerraduras de cofres, jaulas y puertas: se abren con su llave o forzándolas
## con una ganzúa. La probabilidad depende de la habilidad «Ganzúas», la
## agilidad y la suerte frente a la dificultad de la cerradura; al fallar la
## ganzúa puede romperse. Cada intento entrena la habilidad. El estado
## («cerradura abierta») se guarda en GameState.world_changes["opened"].

## Límites superiores de cada nivel de dificultad (1-100).
const LEVELS := [[20, "muy sencilla"], [35, "sencilla"], [50, "media"], [70, "difícil"], [101, "muy difícil"]]
## Probabilidad de que la ganzúa se rompa en un intento fallido.
const BREAK_CHANCE := 0.5


static func level_name(level: int) -> String:
	for e: Array in LEVELS:
		if level < int(e[0]):
			return str(e[1])
	return "muy difícil"


## Probabilidad de éxito de un intento (0.03-0.95).
static func chance(stats: Stats, level: int) -> float:
	if stats == null:
		return 0.0
	var c := 0.45 + (stats.skill("lockpick") - level) * 0.015 \
			+ (stats.attr("agility") - 40) * 0.004 + (stats.attr("luck") - 40) * 0.002
	return clampf(c, 0.03, 0.95)


static func lock_key(entity_id: String) -> String:
	return entity_id + "#cerradura"


static func is_unlocked(entity_id: String) -> bool:
	return GameState.is_opened(lock_key(entity_id))


static func _stats_of(player: Node) -> Stats:
	if player and "stats" in player:
		return player.get("stats") as Stats
	return null


static func _lc_first(text: String) -> String:
	return text.substr(0, 1).to_lower() + text.substr(1)


## «de» + artículo con la contracción del castellano («del cofre», «de la jaula»).
static func _de(what: String) -> String:
	return "del " + what.substr(3) if what.begins_with("el ") else "de " + what


## Texto de la ayuda de interacción para algo cerrado con llave (`what` con
## artículo: «el cofre», «la jaula»).
static func hint(what: String, level: int, key_id: String, player: Node) -> String:
	if key_id != "" and GameState.item_count(key_id) > 0:
		return "[E] Abrir %s con la %s" % [what, _lc_first(ItemDB.display_name(key_id))]
	var picks := GameState.item_count("lockpick")
	if picks > 0:
		var pct := int(round(chance(_stats_of(player), level) * 100.0))
		return "[E] Forzar la cerradura %s (%s, %d %%) · ganzúas: %d" % [_de(what), level_name(level), pct, picks]
	return "%s%s: cerradura %s (necesitas la llave o una ganzúa)" % [what.substr(0, 1).to_upper(), what.substr(1), level_name(level)]


## Intenta abrir. Devuelve "key" o "picked" si se abre; "failed" o "broke"
## si falla (con o sin ganzúa rota) y "no_tools" si no hay llave ni ganzúas.
static func try_open(player: Node, entity_id: String, level: int, key_id: String, at: Vector3) -> String:
	if is_unlocked(entity_id):
		return "key"
	if key_id != "" and GameState.item_count(key_id) > 0:
		GameState.set_opened(lock_key(entity_id), true)
		Audio.play_3d("lock_open", at, -2.0)
		Events.notify.emit("Giras la %s en la cerradura. Se abre." % _lc_first(ItemDB.display_name(key_id)), "info")
		return "key"
	if GameState.item_count("lockpick") <= 0:
		Audio.play_3d("lever", at, -8.0)
		Events.notify.emit("Está cerrado (cerradura %s). Necesitas la llave o una ganzúa." % level_name(level), "info")
		return "no_tools"
	var stats := _stats_of(player)
	var p := chance(stats, level)
	Audio.play_3d("lock_pick", at, -4.0)
	if randf() < p:
		GameState.set_opened(lock_key(entity_id), true)
		if stats:
			stats.train("lockpick", 2.0 + level / 20.0)
		Audio.play_3d("lock_open", at, -2.0)
		Events.notify.emit("¡Clic! Fuerzas la cerradura (%s)." % level_name(level), "info")
		return "picked"
	if stats:
		stats.train("lockpick", 0.6)
	if randf() < BREAK_CHANCE:
		GameState.remove_item("lockpick", 1)
		Audio.play_3d("lock_break", at, -3.0)
		Events.notify.emit("La ganzúa se parte dentro de la cerradura. Te quedan %d." % GameState.item_count("lockpick"), "warning")
		return "broke"
	Events.notify.emit("La cerradura se resiste (%d %% de probabilidad)." % int(round(p * 100.0)), "info")
	return "failed"
