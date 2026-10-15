class_name Door
extends AnimatableBody3D
## Puerta de madera con bisagra que se abre y cierra con una animación suave.
## Su estado se guarda en GameState (cambios del mundo).

var entity_id: String = ""
var open: bool = false
var _pivot_yaw: float = 0.0
var _anim: float = 0.0
var _locked_key: String = ""


func setup(id: String, yaw_deg: float, locked_key: String = "") -> void:
	entity_id = id
	_pivot_yaw = deg_to_rad(yaw_deg)
	_locked_key = locked_key


func _ready() -> void:
	collision_layer = 1 | 16
	collision_mask = 0
	sync_to_physics = false
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLibrary.prop_mesh("door")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 0.14)
	cs.shape = box
	cs.position = Vector3(0.5, 1.0, 0.0)
	add_child(cs)
	open = GameState.is_opened(entity_id)
	_anim = 1.0 if open else 0.0
	_apply()


func get_interaction_text() -> String:
	return "[E] Cerrar puerta" if open else "[E] Abrir puerta"


func interact(_player: Node) -> void:
	open = not open
	GameState.set_opened(entity_id, open)
	Audio.play_3d("door_open" if open else "door_close", global_position + Vector3(0.5, 1.0, 0), -2.0)


func _physics_process(delta: float) -> void:
	var target := 1.0 if open else 0.0
	if not is_equal_approx(_anim, target):
		_anim = move_toward(_anim, target, delta * 1.6)
		_apply()


func _apply() -> void:
	var t := _anim * _anim * (3.0 - 2.0 * _anim)
	rotation.y = _pivot_yaw + t * deg_to_rad(-100.0)
