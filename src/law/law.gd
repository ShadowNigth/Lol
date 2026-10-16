class_name Law
extends RefCounted
## Ley y orden en la Marca de Vaelmoor.
##
## Un delito solo cuenta si alguien lo ve: testigos despiertos, a la vista y
## cerca (o la propia víctima). Cada delito visto suma una multa a la
## recompensa por tu cabeza y baja la reputación con la facción de la víctima.
## Los guardias que te ven con deudas te dan el alto: pagar la multa, cumplir
## calabozo (un día por cada 100 monedas) o resistirse. Resistirse (o atacar a
## un guardia) hace que la guardia te ataque a la vista hasta el día siguiente;
## un guardia que pelea se convierte en un Enemy con su mismo aspecto y equipo
## y vuelve a su puesto cuando se calma.
##
## Estado guardado en GameState.law = {"bounty", "resisted_day", "jail_days"}.

const CRIMES := {
	"agresion": {"name": "Agresión", "bounty": 40, "rep": -10},
	"agresion_guardia": {"name": "Agresión a la guardia", "bounty": 80, "rep": -15},
	"agresion_grave": {"name": "Agresión grave", "bounty": 150, "rep": -25},
	"asesinato": {"name": "Asesinato", "bounty": 500, "rep": -40},
	"robo": {"name": "Robo", "bounty": 25, "rep": -10},
	"allanamiento": {"name": "Allanamiento", "bounty": 15, "rep": -5},
	"resistencia": {"name": "Resistencia a la autoridad", "bounty": 50, "rep": -10},
}
const WITNESS_RANGE := 18.0
const THEFT_RANGE := 10.0
const ALERT_RANGE := 30.0
const GOLD_PER_JAIL_DAY := 100
const MAX_JAIL_DAYS := 14
const GUARD_RESPAWN_DAYS := 3
const MAX_BOUNTY := 99999


static func bounty() -> int:
	return int(GameState.law.get("bounty", 0))


static func is_wanted() -> bool:
	return bounty() > 0


## ¿Te has resistido a la guardia? Dura hasta el final del día siguiente.
static func resisted() -> bool:
	var d := int(GameState.law.get("resisted_day", 0))
	return d > 0 and GameState.day <= d


static func mark_resisted() -> void:
	GameState.law["resisted_day"] = GameState.day + 1


static func jail_days() -> int:
	return clampi(ceili(bounty() / float(GOLD_PER_JAIL_DAY)), 1, MAX_JAIL_DAYS)


static func clear() -> void:
	GameState.law["bounty"] = 0
	GameState.law["resisted_day"] = 0
	Events.law_changed.emit(0)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


# ---------------------------------------------------------------------------
# Testigos y denuncias
# ---------------------------------------------------------------------------

## ¿Ve este PNJ al jugador? Despierto, cerca y sin muros en medio. Para los
## robos, además, tiene que estar mirando hacia él (o muy cerca); agachado
## se te ve a menos distancia.
static func npc_sees(npc: NPC, target: Node3D, max_dist: float, need_facing: bool = false) -> bool:
	if npc == null or not is_instance_valid(npc) or target == null or not npc.can_witness():
		return false
	var eye := npc.global_position + Vector3(0, 1.6, 0)
	var to := target.global_position + Vector3(0, 1.4, 0)
	var dist := eye.distance_to(to)
	var reach := max_dist
	if target is Player and (target as Player).is_crouching():
		reach *= 0.6
	if dist > reach:
		return false
	if need_facing and dist > 3.0:
		var fwd := -npc.global_basis.z
		var flat := Vector3(to.x - eye.x, 0, to.z - eye.z).normalized()
		if fwd.dot(flat) < 0.2:
			return false
	var space := npc.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, to, 1, [npc.get_rid()])
	return space.intersect_ray(q).is_empty()


static func witnesses(target: Node3D, max_dist: float, victim: Node = null, need_facing: bool = false) -> Array[NPC]:
	var out: Array[NPC] = []
	var tree := _tree()
	if tree == null:
		return out
	for n: Node in tree.get_nodes_in_group("npcs"):
		var npc := n as NPC
		if npc == null or npc.is_queued_for_deletion():
			continue
		if npc == victim:
			if npc.can_witness() or npc.is_knocked_out():
				out.append(npc)
			continue
		if npc_sees(npc, target, max_dist, need_facing):
			out.append(npc)
	return out


## Denuncia un delito del jugador. Sin testigos no hay delito. Devuelve los
## puntos de multa añadidos (0 si nadie lo ha visto).
static func report(kind: String, victim: Node = null, value: int = 0) -> int:
	var p := GameState.player as Player
	var def: Dictionary = CRIMES.get(kind, {})
	if p == null or def.is_empty():
		return 0
	var theft := kind == "robo" or kind == "allanamiento"
	var ws := witnesses(p, THEFT_RANGE if theft else WITNESS_RANGE, victim, theft)
	if ws.is_empty():
		return 0
	var amount := int(def["bounty"]) + (2 * maxi(value, 0) if kind == "robo" else 0)
	GameState.law["bounty"] = mini(bounty() + amount, MAX_BOUNTY)
	# Reputación con la facción de la víctima (o del primer testigo)
	var faction := ""
	if victim is NPC:
		faction = str((victim as NPC).data.get("faction", ""))
	if faction == "":
		faction = str(ws[0].data.get("faction", ""))
	if faction != "" and QuestDB.FACTIONS.has(faction):
		GameState.add_reputation(faction, int(def["rep"]))
	Events.notify.emit("Delito: %s (+%d). Recompensa por tu cabeza: %d monedas." % [def["name"], amount, bounty()], "warning")
	Events.law_changed.emit(bounty())
	for w: NPC in ws:
		w.witness_crime(kind, p.global_position, not theft)
	# Los gritos atraen a los guardias cercanos aunque no lo hayan visto
	for n: Node in _tree().get_nodes_in_group("npcs"):
		var g := n as NPC
		if g and g.is_guard() and g.global_position.distance_to(p.global_position) < ALERT_RANGE:
			g.alert_guard(p.global_position)
	return amount


# ---------------------------------------------------------------------------
# Detención: multa, calabozo o resistencia
# ---------------------------------------------------------------------------

static func pay_fine(p: Node) -> bool:
	var b := bounty()
	if b <= 0:
		return true
	if p == null or int(p.get("gold")) < b:
		return false
	p.set("gold", int(p.get("gold")) - b)
	clear()
	Audio.play_2d("gold", -4.0)
	Events.notify.emit("Pagas %d monedas de multa. Tu deuda con la Marca queda saldada." % b, "info")
	return true


## Cumple la condena: borra la deuda, pasa el tiempo y las habilidades sin
## practicar se oxidan (se pierde lo avanzado hacia el siguiente punto en dos
## de ellas). Devuelve los días cumplidos.
static func serve_sentence(p: Player) -> int:
	var days := jail_days()
	clear()
	GameState.law["jail_days"] = int(GameState.law.get("jail_days", 0)) + days
	GameState.day += days
	GameState.time_of_day = 8.0
	if p:
		p.stats.heal(p.stats.max_health)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("calabozo%d" % GameState.day)
		var keys: Array = Stats.SKILLS.duplicate()
		for i in mini(2, keys.size()):
			var sk := str(keys.pop_at(rng.randi() % keys.size()))
			p.stats.skill_xp[sk] = 0.0
		Events.player_stats_changed.emit()
	return days


## El jugador se resiste: la guardia le ataca hasta el día siguiente.
static func resist(guard: NPC) -> void:
	mark_resisted()
	report("resistencia", guard)
	if guard and is_instance_valid(guard):
		make_hostile(guard)
	# Los guardias que lo ven se unen a la pelea
	var p := GameState.player as Player
	for n: Node in _tree().get_nodes_in_group("npcs"):
		var g := n as NPC
		if g and g != guard and g.is_guard() and npc_sees(g, p, 20.0):
			make_hostile(g)


# ---------------------------------------------------------------------------
# Guardias que pelean (cambio PNJ <-> Enemy)
# ---------------------------------------------------------------------------

static func make_hostile(npc: NPC) -> Enemy:
	if npc == null or not is_instance_valid(npc) or npc.is_knocked_out():
		return null
	if npc.hostile_enemy and is_instance_valid(npc.hostile_enemy):
		return npc.hostile_enemy
	var spawner := npc.get_parent() as EntitySpawner
	if spawner == null:
		return null
	return spawner.spawn_guard_enemy(npc)


## El guardia vuelve a su puesto: reaparece el PNJ donde estaba el Enemy.
static func calm_guard(e: Enemy, knocked_out: bool = false) -> void:
	var npc := e.guard_npc
	if npc and is_instance_valid(npc):
		npc.restore_from_hostile(e.global_position, e.global_rotation.y, e.health_ratio(), knocked_out)
	e.guard_npc = null
	e.queue_free()


## Un guardia (sin nombre) ha muerto: no vuelve hasta dentro de unos días y,
## si alguien lo ha visto, es un asesinato.
static func guard_killed(e: Enemy) -> void:
	var npc := e.guard_npc
	e.guard_npc = null
	if npc and is_instance_valid(npc):
		GameState.mark_killed(npc.entity_id)
		npc.queue_free()
	report("asesinato")
