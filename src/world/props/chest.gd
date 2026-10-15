class_name Chest
extends StaticBody3D
## Cofre con tapa animada y botín generado por tablas. Solo se puede saquear
## una vez (persistente). Puede tener cerradura (`lock_level` > 0): se abre con
## su llave o forzándola con ganzúas (ver LockPicking).

var entity_id: String = ""
var loot_table: String = "home"
var lock_level: int = 0
var key_id: String = ""
var _lid: Node3D
var _lid_t: float = 0.0
var _opened: bool = false
var _padlock: MeshInstance3D


func setup(id: String, table: String, lock: int = 0, key: String = "") -> void:
	entity_id = id
	loot_table = table
	lock_level = lock
	key_id = key


func is_locked() -> bool:
	return lock_level > 0 and not _opened and not LockPicking.is_unlocked(entity_id)


func _ready() -> void:
	collision_layer = 1 | 16
	var base := MeshInstance3D.new()
	base.mesh = ModelLibrary.prop_mesh("chest", {}, PackedStringArray(["base"]))
	add_child(base)
	var model := PropModels.chest()
	var lid_part := model.get_part("lid")
	_lid = Node3D.new()
	_lid.position = lid_part.origin
	add_child(_lid)
	var lid_mesh := MeshInstance3D.new()
	lid_mesh.mesh = ModelLibrary.prop_mesh("chest", {}, PackedStringArray(["lid"]), -lid_part.origin)
	_lid.add_child(lid_mesh)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.75, 0.62)
	cs.shape = box
	cs.position = Vector3(-0.03, 0.37, -0.03)
	add_child(cs)
	_opened = GameState.is_looted(entity_id)
	_lid_t = 1.0 if _opened else 0.0
	_lid.rotation.x = -_lid_t * deg_to_rad(105.0)
	# Candado de hierro en el frente mientras esté cerrado con llave
	if is_locked():
		_padlock = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.14, 0.05)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.3, 0.33)
		mat.metallic = 0.8
		mat.roughness = 0.45
		bm.material = mat
		_padlock.mesh = bm
		_padlock.position = Vector3(-0.03, 0.42, -0.36)
		add_child(_padlock)


func get_interaction_text() -> String:
	if _opened:
		return "Cofre (vacío)"
	if is_locked():
		return LockPicking.hint("el cofre", lock_level, key_id, GameState.player)
	return "[E] Abrir cofre"


func interact(player: Node) -> void:
	if _opened:
		return
	if is_locked():
		var res := LockPicking.try_open(player, entity_id, lock_level, key_id, global_position + Vector3(0, 0.5, 0))
		if res != "key" and res != "picked":
			return
		if _padlock:
			_padlock.queue_free()
			_padlock = null
	_opened = true
	GameState.mark_looted(entity_id)
	Audio.play_3d("chest_open", global_position + Vector3(0, 0.6, 0), -2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(entity_id)
	var found: Array[String] = []
	var gold := LootTables.gold_for(loot_table, rng)
	if gold > 0 and player and "gold" in player:
		player.set("gold", int(player.get("gold")) + gold)
		found.append("%d monedas de oro" % gold)
		Audio.play_2d("gold", -4.0)
	for item: Dictionary in LootTables.roll(loot_table, rng):
		GameState.give_item(player, item)
		var c := int(item.get("count", 1))
		found.append(str(item["name"]) + (" x%d" % c if c > 1 else ""))
	Events.notify.emit("El cofre contiene: " + (", ".join(found) if not found.is_empty() else "nada"), "item")


func _process(delta: float) -> void:
	var target := 1.0 if _opened else 0.0
	if not is_equal_approx(_lid_t, target):
		_lid_t = move_toward(_lid_t, target, delta * 2.0)
		var e := 1.0 - pow(1.0 - _lid_t, 3.0)
		_lid.rotation.x = -e * deg_to_rad(105.0)
