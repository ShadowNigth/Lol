extends Node
## Estado de la partida en curso y guardado/carga.
##
## Guardado versionado en JSON con escritura atómica: se escribe en un fichero
## temporal, se verifica leyéndolo de nuevo y solo entonces sustituye al
## anterior (que se conserva como .bak). Nunca se sobrescribe la única
## partida válida con datos incompletos.

signal inventory_changed

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const GAME_SCENE := "res://scenes/game.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const MAX_CARRY_BASE := 60.0

var world_seed: int = 1
var character_name: String = "Aventurero"
var character_class: String = "warrior"
var time_of_day: float = 15.5       # horas (0-24)
var day: int = 1
var playtime: float = 0.0
var world_changes: Dictionary = {"looted": {}, "killed": {}, "opened": {}, "dropped": []}
var inventory: Array[Dictionary] = []   # {"id": String, "count": int}
var pending_load: Dictionary = {}       # datos a aplicar al entrar en la escena de juego
var current_area: Dictionary = {"type": "overworld"}   # exterior o mazmorra (con punto de regreso)
var quests: Dictionary = {}             # id -> {"stage", "progress", "done"}
var reputations: Dictionary = {}        # facción -> valor (-100..100)
var shops: Dictionary = {}              # id de tienda -> {"gold", "stock"}
var player: Node = null
var in_game: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Events.enemy_killed.connect(func(_e: Node, enemy_id: String) -> void: QuestManager.on_enemy_killed(enemy_id))
	inventory_changed.connect(func() -> void: QuestManager.check_collect_objectives())


func reputation(faction: String) -> int:
	return int(reputations.get(faction, 0))


func add_reputation(faction: String, amount: int) -> void:
	reputations[faction] = clampi(reputation(faction) + amount, -100, 100)
	var fname: String = QuestDB.FACTIONS.get(faction, faction)
	Events.notify.emit("Reputación con %s: %+d (%d)" % [fname, amount, reputation(faction)], "quest")


func get_shop(shop_id: String) -> Dictionary:
	if not shops.has(shop_id):
		var def: Dictionary = NpcDB.SHOPS.get(shop_id, {"gold": 100, "stock": []})
		var stock := {}
		for e: Array in def["stock"]:
			stock[str(e[0])] = int(e[1])
		shops[shop_id] = {"gold": int(def["gold"]), "stock": stock}
	return shops[shop_id]


func _process(delta: float) -> void:
	if in_game and not get_tree().paused:
		playtime += delta


# ---------------------------------------------------------------------------
# Nueva partida
# ---------------------------------------------------------------------------

func start_new_game(config: Dictionary) -> void:
	world_seed = int(config.get("seed", 0))
	if world_seed == 0:
		world_seed = randi_range(1, 2147483646)
	character_name = str(config.get("name", "Aventurero")).strip_edges()
	if character_name == "":
		character_name = "Aventurero"
	character_class = str(config.get("class", "warrior"))
	time_of_day = 15.5
	day = 1
	playtime = 0.0
	world_changes = {"looted": {}, "killed": {}, "opened": {}, "dropped": []}
	current_area = {"type": "overworld"}
	quests = {}
	reputations = {}
	shops = {}
	inventory.clear()
	inventory.append({"id": "potion_health", "count": 2})
	inventory.append({"id": "bread", "count": 1})
	pending_load = {}
	inventory_changed.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


## Atributos iniciales según la clase elegida.
static func class_template(cls: String) -> Dictionary:
	match cls:
		"rogue":
			return {"name": "Explorador", "attributes": {"strength": 38, "agility": 55, "endurance": 40, "intelligence": 40, "willpower": 35, "personality": 45, "luck": 50},
					"skills": {"blade": 18, "archery": 25, "sneak": 25, "acrobatics": 20, "lockpick": 20}, "weapons": ["dagger", "sword"]}
		"mage":
			return {"name": "Mago de batalla", "attributes": {"strength": 32, "agility": 40, "endurance": 36, "intelligence": 60, "willpower": 55, "personality": 42, "luck": 40},
					"skills": {"destruction": 28, "restoration": 22, "alteration": 18, "blade": 12, "blunt": 15}, "weapons": ["mace"]}
	return {"name": "Guerrero", "attributes": {"strength": 55, "agility": 40, "endurance": 55, "intelligence": 32, "willpower": 38, "personality": 38, "luck": 40},
			"skills": {"blade": 25, "block": 25, "heavy_armor": 20, "axe": 18, "blunt": 18, "athletics": 18}, "weapons": ["sword"]}


# ---------------------------------------------------------------------------
# Cambios persistentes del mundo
# ---------------------------------------------------------------------------

func mark_looted(id: String) -> void:
	if id != "":
		(world_changes["looted"] as Dictionary)[id] = true


func is_looted(id: String) -> bool:
	return (world_changes["looted"] as Dictionary).has(id)


func mark_killed(id: String) -> void:
	if id != "":
		(world_changes["killed"] as Dictionary)[id] = day


func is_killed(id: String) -> bool:
	return (world_changes["killed"] as Dictionary).has(id)


func set_opened(id: String, opened: bool) -> void:
	if id == "":
		return
	if opened:
		(world_changes["opened"] as Dictionary)[id] = true
	else:
		(world_changes["opened"] as Dictionary).erase(id)


func is_opened(id: String) -> bool:
	return (world_changes["opened"] as Dictionary).has(id)


# ---------------------------------------------------------------------------
# Inventario
# ---------------------------------------------------------------------------

func give_item(p: Node, item: Dictionary) -> void:
	var id := str(item.get("id", ""))
	var count := maxi(1, int(item.get("count", 1)))
	if not ItemDB.exists(id):
		push_warning("Objeto desconocido: %s" % id)
		return
	if id == "gold":
		if p and "gold" in p:
			p.set("gold", int(p.get("gold")) + count)
		return
	var def := ItemDB.get_def(id)
	if def.has("weapon") and p and p.has_method("add_weapon"):
		var w := load(str(def["weapon"])) as WeaponData
		if w and bool(p.call("add_weapon", w)):
			return
	for e in inventory:
		if e["id"] == id:
			e["count"] = int(e["count"]) + count
			inventory_changed.emit()
			return
	inventory.append({"id": id, "count": count})
	inventory_changed.emit()


## Registra un objeto soltado en el mundo (zona actual) y devuelve su entrada.
func add_dropped(id: String, pos: Vector3) -> Dictionary:
	var area := str(current_area.get("type", "overworld")) + ":" + str(current_area.get("id", ""))
	var e := {"id": id, "pos": [pos.x, pos.y, pos.z], "area": area}
	if not world_changes.has("dropped"):
		world_changes["dropped"] = []
	(world_changes["dropped"] as Array).append(e)
	return e


func dropped_in_area() -> Array:
	var area := str(current_area.get("type", "overworld")) + ":" + str(current_area.get("id", ""))
	var out := []
	for e: Variant in world_changes.get("dropped", []):
		if e is Dictionary and str((e as Dictionary).get("area", "")) == area:
			out.append(e)
	return out


func pick_dropped(pickup: Node) -> void:
	var list: Array = world_changes.get("dropped", [])
	var entry: Variant = pickup.get_meta("drop_entry") if pickup.has_meta("drop_entry") else null
	if entry != null:
		list.erase(entry)


func item_count(id: String) -> int:
	for e in inventory:
		if e["id"] == id:
			return int(e["count"])
	return 0


func remove_item(id: String, count: int = 1) -> bool:
	for i in inventory.size():
		var e := inventory[i]
		if e["id"] == id:
			if int(e["count"]) < count:
				return false
			e["count"] = int(e["count"]) - count
			if int(e["count"]) <= 0:
				inventory.remove_at(i)
			inventory_changed.emit()
			return true
	return false


func carry_weight() -> float:
	var total := 0.0
	for e in inventory:
		total += float(ItemDB.get_def(str(e["id"])).get("weight", 0.0)) * int(e["count"])
	return total


## Usa un consumible y aplica su efecto al jugador.
func use_item(p: Node, id: String) -> bool:
	var def := ItemDB.get_def(id)
	if def.is_empty() or not def.has("effect") or item_count(id) <= 0:
		return false
	var stats: Stats = p.get("stats")
	if stats == null:
		return false
	var fx: Dictionary = def["effect"]
	if fx.has("heal"):
		stats.heal(float(fx["heal"]))
	if fx.has("stamina"):
		stats.restore_stamina(float(fx["stamina"]))
	if fx.has("mana"):
		stats.restore_mana(float(fx["mana"]))
	remove_item(id, 1)
	Audio.play_2d("drink" if str(def.get("category", "")) == "potion" else "eat", -3.0)
	Events.notify.emit("Usas: %s" % def["name"], "item")
	return true


# ---------------------------------------------------------------------------
# Guardar / cargar
# ---------------------------------------------------------------------------

func _slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


func build_save_data() -> Dictionary:
	var pdata := {}
	if player and is_instance_valid(player):
		var pl := player as Player
		var weapon_ids: Array[String] = []
		for w in pl.weapons:
			weapon_ids.append(w.resource_path)
		pdata = {
			"position": [pl.global_position.x, pl.global_position.y, pl.global_position.z],
			"yaw": pl.get_yaw_degrees(),
			"stats": pl.stats.to_dict(),
			"gold": pl.gold,
			"weapons": weapon_ids,
			"weapon_index": pl.weapon_index,
		}
	return {
		"version": SAVE_VERSION,
		"game": "vaelmoor",
		"saved_at": Time.get_datetime_string_from_system(),
		"seed": world_seed,
		"character": {"name": character_name, "class": character_class},
		"time_of_day": time_of_day,
		"day": day,
		"playtime": playtime,
		"player": pdata,
		"inventory": inventory.duplicate(true),
		"world_changes": world_changes.duplicate(true),
		"area": current_area.duplicate(true),
		"quests": quests.duplicate(true),
		"reputations": reputations.duplicate(true),
		"shops": shops.duplicate(true),
		"location": str(player.call("current_location_name")) if player and player.has_method("current_location_name") else "",
	}


func save_game(slot: String) -> Error:
	if player == null or not is_instance_valid(player) or (player as Player).is_dead:
		Events.notify.emit("No se puede guardar ahora.", "warning")
		return ERR_UNAVAILABLE
	var data := build_save_data()
	var text := JSON.stringify(data, "\t")
	var final_path := _slot_path(slot)
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		var err := FileAccess.get_open_error()
		Events.notify.emit("Error al guardar: %s" % error_string(err), "error")
		return err
	f.store_string(text)
	f.close()
	# Verificación: el temporal debe poder leerse y validarse antes de reemplazar.
	var check := _read_save(tmp_path)
	if check.is_empty():
		DirAccess.remove_absolute(tmp_path)
		Events.notify.emit("Error al guardar: la verificación falló. La partida anterior se conserva.", "error")
		return ERR_FILE_CORRUPT
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return ERR_CANT_OPEN
	if FileAccess.file_exists(final_path):
		if FileAccess.file_exists(final_path + ".bak"):
			dir.remove(slot + ".json.bak")
		dir.rename(slot + ".json", slot + ".json.bak")
	var err2 := dir.rename(slot + ".json.tmp", slot + ".json")
	if err2 != OK:
		Events.notify.emit("Error al guardar: %s" % error_string(err2), "error")
		return err2
	Events.notify.emit("Partida guardada.", "info")
	Events.game_saved.emit(slot)
	return OK


## Lee y valida un fichero de guardado. Devuelve {} si no es válido.
func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("Guardado corrupto (%s): %s en la línea %d" % [path, json.get_error_message(), json.get_error_line()])
		return {}
	var data: Variant = json.data
	if not (data is Dictionary):
		return {}
	var d := data as Dictionary
	if not validate_save(d):
		return {}
	return d


func validate_save(d: Dictionary) -> bool:
	if str(d.get("game", "")) != "vaelmoor":
		return false
	var ver := int(d.get("version", -1))
	if ver < 1 or ver > SAVE_VERSION:
		return false
	for key: String in ["seed", "player", "inventory", "world_changes", "time_of_day"]:
		if not d.has(key):
			return false
	var p: Variant = d["player"]
	if not (p is Dictionary):
		return false
	var pd := p as Dictionary
	if not (pd.get("position", null) is Array) or (pd["position"] as Array).size() != 3:
		return false
	if not (pd.get("stats", null) is Dictionary):
		return false
	if not (d["inventory"] is Array) or not (d["world_changes"] is Dictionary):
		return false
	return true


## Devuelve un mensaje de error o "" si se inició la carga.
func load_game(slot: String) -> String:
	var path := _slot_path(slot)
	var d := _read_save(path)
	if d.is_empty():
		var bak := _read_save(path + ".bak")
		if bak.is_empty():
			return "La partida '%s' no existe o está dañada." % slot
		d = bak
		Events.notify.emit("La partida estaba dañada; se ha cargado la copia de seguridad.", "warning")
	world_seed = int(d["seed"])
	var ch: Dictionary = d.get("character", {})
	character_name = str(ch.get("name", "Aventurero"))
	character_class = str(ch.get("class", "warrior"))
	time_of_day = clampf(float(d.get("time_of_day", 12.0)), 0.0, 24.0)
	day = maxi(1, int(d.get("day", 1)))
	playtime = float(d.get("playtime", 0.0))
	inventory.clear()
	for e: Variant in d["inventory"]:
		if e is Dictionary and ItemDB.exists(str((e as Dictionary).get("id", ""))):
			inventory.append({"id": str(e["id"]), "count": maxi(1, int(e.get("count", 1)))})
	var wc: Dictionary = d["world_changes"]
	world_changes = {"looted": wc.get("looted", {}), "killed": wc.get("killed", {}), "opened": wc.get("opened", {}),
			"dropped": wc.get("dropped", []) if wc.get("dropped", []) is Array else []}
	var area: Variant = d.get("area", {"type": "overworld"})
	current_area = (area as Dictionary).duplicate(true) if area is Dictionary else {"type": "overworld"}
	if str(current_area.get("type", "overworld")) not in ["overworld", "dungeon"]:
		current_area = {"type": "overworld"}
	quests = (d.get("quests", {}) as Dictionary).duplicate(true) if d.get("quests", {}) is Dictionary else {}
	for qid: String in quests.keys():
		if QuestDB.get_quest(qid).is_empty() or not (quests[qid] is Dictionary):
			quests.erase(qid)
	reputations = (d.get("reputations", {}) as Dictionary).duplicate(true) if d.get("reputations", {}) is Dictionary else {}
	shops = (d.get("shops", {}) as Dictionary).duplicate(true) if d.get("shops", {}) is Dictionary else {}
	pending_load = d["player"]
	inventory_changed.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)
	Events.game_loaded.emit(slot)
	return ""


func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for fname in dir.get_files():
		if not fname.ends_with(".json"):
			continue
		var slot := fname.get_basename()
		var d := _read_save(SAVE_DIR.path_join(fname))
		if d.is_empty():
			out.append({"slot": slot, "valid": false, "label": "%s (dañada)" % slot})
			continue
		var stats: Dictionary = (d["player"] as Dictionary).get("stats", {})
		var ch: Dictionary = d.get("character", {})
		var label := "%s — %s, nivel %d — %s" % [slot, ch.get("name", "?"), int(stats.get("level", 1)), d.get("saved_at", "")]
		out.append({"slot": slot, "valid": true, "label": label, "saved_at": str(d.get("saved_at", ""))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("saved_at", "")) > str(b.get("saved_at", "")))
	return out


func has_any_save() -> bool:
	for s in list_saves():
		if bool(s.get("valid", false)):
			return true
	return false


func go_to_menu() -> void:
	in_game = false
	player = null
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
