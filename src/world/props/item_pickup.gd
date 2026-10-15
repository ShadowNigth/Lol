class_name ItemPickup
extends Area3D
## Objeto suelto en el mundo (soltado por el jugador). Persistente: se guarda
## en GameState.world_changes["dropped"] hasta que se recoge.

var item_id := ""
var drop_index := -1
var _mesh: MeshInstance3D
var _t := 0.0


func setup(id: String) -> void:
	item_id = id


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false
	_mesh = MeshInstance3D.new()
	_mesh.mesh = ModelLibrary.prop_mesh("sack")
	add_child(_mesh)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.35
	cs.shape = sph
	cs.position = Vector3(0, 0.25, 0)
	add_child(cs)


func get_interaction_text() -> String:
	return "[E] Recoger %s" % ItemDB.display_name(item_id)


func interact(player: Node) -> void:
	GameState.pick_dropped(self)
	GameState.give_item(player, {"id": item_id, "count": 1})
	Audio.play_2d("pickup", -6.0)
	queue_free()
