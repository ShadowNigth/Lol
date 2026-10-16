class_name CellDoor
extends AnimatableBody3D
## Puerta enrejada de las celdas del calabozo de Peñalba. Cerrada con llave
## hasta que se abre con la llave del calabozo o forzando la cerradura (ver
## LockPicking); después se abre y se cierra como cualquier puerta. Forzarla
## delante de testigos es allanamiento. Al cumplir condena el carcelero la
## deja abierta (Law / game.gd).

var entity_id := ""
var lock_level := 0
var key_id := ""
var open := false
var _anim := 0.0
var _pivot_yaw := 0.0


func setup(id: String, level: int, key: String, yaw_deg: float) -> void:
	entity_id = id
	lock_level = level
	key_id = key
	_pivot_yaw = deg_to_rad(yaw_deg)


func is_locked() -> bool:
	return lock_level > 0 and not LockPicking.is_unlocked(entity_id)


func _ready() -> void:
	add_to_group("cell_doors")
	collision_layer = 1 | 16
	collision_mask = 0
	sync_to_physics = false
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLibrary.prop_mesh("cell_door")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 0.14)
	cs.shape = box
	cs.position = Vector3(0.5, 1.0, -0.03)
	add_child(cs)
	open = GameState.is_opened(entity_id)
	_anim = 1.0 if open else 0.0
	_apply()


func get_interaction_text() -> String:
	if is_locked():
		return LockPicking.hint("la reja", lock_level, key_id, GameState.player)
	return "[E] Cerrar la reja" if open else "[E] Abrir la reja"


func interact(player: Node) -> void:
	if is_locked():
		var res := LockPicking.try_open(player, entity_id, lock_level, key_id, global_position + Basis(Vector3.UP, _pivot_yaw) * Vector3(0.8, 1.0, 0))
		if res == "picked":
			Law.report("allanamiento")
		if res != "key" and res != "picked":
			return
	set_open(not open)


func set_open(value: bool) -> void:
	open = value
	GameState.set_opened(entity_id, open)
	Audio.play_3d("door_open" if open else "door_close", global_position + Vector3(0.5, 1.0, 0), -2.0, 0.05, 0.7)


## Abre la reja sin cerradura (fin de la condena).
func release() -> void:
	GameState.set_opened(LockPicking.lock_key(entity_id), true)
	set_open(true)


func _physics_process(delta: float) -> void:
	var target := 1.0 if open else 0.0
	if not is_equal_approx(_anim, target):
		_anim = move_toward(_anim, target, delta * 1.4)
		_apply()


func _apply() -> void:
	var t := _anim * _anim * (3.0 - 2.0 * _anim)
	rotation.y = _pivot_yaw + t * deg_to_rad(-100.0)
