class_name DungeonEntrance
extends StaticBody3D
## Puerta sellada de una mazmorra. Requiere la llave indicada; al abrirse
## lleva al interior de la mazmorra (Fase 3).

var entity_id: String = ""
var dungeon_id: String = ""
var key_item: String = "rusty_key"


func setup(id: String, dungeon: String) -> void:
	entity_id = id
	dungeon_id = dungeon


func _ready() -> void:
	collision_layer = 1 | 16
	for side: int in [-1, 1]:
		var mi := MeshInstance3D.new()
		mi.mesh = ModelLibrary.prop_mesh("dungeon_door")
		if side < 0:
			mi.position = Vector3(-0.5, 0, 0)
		else:
			mi.position = Vector3(0.5, 0, 0)
			mi.rotation.y = PI
		mi.scale = Vector3(0.5, 1.5, 1.0)
		add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 3.0, 0.2)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)


func get_interaction_text() -> String:
	if GameState.item_count(key_item) > 0 or GameState.is_opened(entity_id):
		return "[E] Entrar en la cripta de Velmar"
	return "Puerta de la cripta (cerrada con llave)"


func interact(player: Node) -> void:
	if GameState.item_count(key_item) <= 0 and not GameState.is_opened(entity_id):
		Audio.play_3d("lever", global_position + Vector3(0, 1.2, 0), -4.0)
		Events.notify.emit("La puerta está cerrada. Quizá la llave esté en algún lugar de la capilla.", "info")
		return
	GameState.set_opened(entity_id, true)
	var game := player.get_tree().current_scene
	if game and game.has_method("enter_dungeon"):
		game.call("enter_dungeon", dungeon_id, entity_id)
	else:
		Events.notify.emit("La cerradura cede, pero un derrumbe bloquea el paso.", "info")
