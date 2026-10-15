class_name Cage
extends StaticBody3D
## Jaula de prisioneros con puerta articulada y cerradura (llave o ganzúa).
## Al abrirse activa una bandera de historia (p. ej. "jaula_cuervos_abierta")
## que libera al cautivo y hace avanzar las misiones que la esperan.
## La colisión solo cubre paredes y suelo (sin techo): así el cautivo aparece
## dentro, apoyado en el suelo de la jaula.

const SIZE := 2.0
const HEIGHT := 2.2

var entity_id := ""
var lock_level := 45
var key_id := ""
var open_flag := ""
var captive_npc := ""        # PNJ encerrado (para hablar a través de los barrotes)
var opened := false
var _door: Node3D
var _door_cs: CollisionShape3D
var _t := 0.0


func setup(id: String, level: int, key: String, flag: String, captive: String) -> void:
	entity_id = id
	lock_level = level
	key_id = key
	open_flag = flag
	captive_npc = captive


func _ready() -> void:
	collision_layer = 1 | 16
	collision_mask = 0
	var body := MeshInstance3D.new()
	body.mesh = ModelLibrary.prop_mesh("cage", {}, PackedStringArray(["body"]))
	add_child(body)
	var door_part := PropModels.cage().get_part("door")
	_door = Node3D.new()
	_door.position = door_part.origin
	add_child(_door)
	var dm := MeshInstance3D.new()
	dm.mesh = ModelLibrary.prop_mesh("cage", {}, PackedStringArray(["door"]), -door_part.origin)
	_door.add_child(dm)
	var h := SIZE * 0.5
	var t := 0.12
	# Fondo, costados, tramos del frente a los lados de la puerta y suelo
	_box(Vector3(SIZE, HEIGHT, t), Vector3(0, HEIGHT * 0.5, h - t * 0.5))
	_box(Vector3(t, HEIGHT, SIZE), Vector3(-h + t * 0.5, HEIGHT * 0.5, 0))
	_box(Vector3(t, HEIGHT, SIZE), Vector3(h - t * 0.5, HEIGHT * 0.5, 0))
	_box(Vector3(0.5, HEIGHT, t), Vector3(-0.75, HEIGHT * 0.5, -h + t * 0.5))
	_box(Vector3(0.5, HEIGHT, t), Vector3(0.75, HEIGHT * 0.5, -h + t * 0.5))
	_box(Vector3(SIZE - 0.1, 0.0625, SIZE - 0.1), Vector3(0, 0.03125, 0))
	_door_cs = _box(Vector3(1.0, 2.0, t), Vector3(0, 1.05, -h + t * 0.5))
	opened = LockPicking.is_unlocked(entity_id) or (open_flag != "" and GameState.has_flag(open_flag))
	_t = 1.0 if opened else 0.0
	_apply()


func _box(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	add_child(cs)
	return cs


func _captive() -> NPC:
	if captive_npc == "":
		return null
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := n as NPC
		if npc and npc.npc_id == captive_npc and npc.global_position.distance_to(global_position) < 3.0:
			return npc
	return null


func get_interaction_text() -> String:
	if opened:
		return ""
	var picks := GameState.item_count("lockpick")
	var has_key := key_id != "" and GameState.item_count(key_id) > 0
	if not has_key and picks == 0 and _captive() != null:
		return "[E] Hablar con %s a través de los barrotes · jaula: cerradura %s" % [_captive().data.get("name", ""), LockPicking.level_name(lock_level)]
	return LockPicking.hint("la jaula", lock_level, key_id, GameState.player)


func interact(player: Node) -> void:
	if opened:
		return
	var has_key := key_id != "" and GameState.item_count(key_id) > 0
	if not has_key and GameState.item_count("lockpick") == 0 and _captive() != null:
		_captive().interact(player)
		return
	var res := LockPicking.try_open(player, entity_id, lock_level, key_id, global_position + Vector3(0, 1.0, -SIZE * 0.5))
	if res == "key" or res == "picked":
		open_cage()


func open_cage() -> void:
	if opened:
		return
	opened = true
	GameState.set_opened(LockPicking.lock_key(entity_id), true)
	Audio.play_3d("door_open", global_position + Vector3(0, 1.0, -SIZE * 0.5), -1.0)
	if open_flag != "":
		GameState.set_flag(open_flag)


func _apply() -> void:
	var e := 1.0 - pow(1.0 - _t, 3.0)
	_door.rotation.y = e * deg_to_rad(105.0)
	_door_cs.disabled = _t > 0.3


func _process(delta: float) -> void:
	var target := 1.0 if opened else 0.0
	if not is_equal_approx(_t, target):
		_t = move_toward(_t, target, delta * 1.2)
		_apply()
