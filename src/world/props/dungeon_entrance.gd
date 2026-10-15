class_name DungeonEntrance
extends StaticBody3D
## Entrada a una mazmorra. Si la mazmorra lo exige (DungeonDB.entry_key) hace
## falta la llave; al cruzarla se carga el interior generado (DungeonGenerator).
## Estilos: "door" (puerta de piedra doble) u "open" (boca de cueva oscura).

var entity_id: String = ""
var dungeon_id: String = ""
var key_item: String = ""
var style: String = "door"


func setup(id: String, dungeon: String, entrance_style: String = "door") -> void:
	entity_id = id
	dungeon_id = dungeon
	style = entrance_style
	key_item = str(DungeonDB.get_def(dungeon).get("entry_key", ""))


func _ready() -> void:
	collision_layer = 1 | 16
	if style == "open":
		# Fondo oscuro del túnel (sugiere profundidad; la cueva está "dentro")
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.9, 2.4)
		mi.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.01, 0.01, 0.012)
		mi.material_override = mat
		mi.position = Vector3(0, 1.2, 0.05)
		mi.rotation.y = PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	else:
		for side: int in [-1, 1]:
			var dm := MeshInstance3D.new()
			dm.mesh = ModelLibrary.prop_mesh("dungeon_door")
			if side < 0:
				dm.position = Vector3(-0.5, 0, 0)
			else:
				dm.position = Vector3(0.5, 0, 0)
				dm.rotation.y = PI
			dm.scale = Vector3(0.5, 1.5, 1.0)
			add_child(dm)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0 if style != "open" else 1.8, 3.0, 0.2)
	cs.shape = box
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)


func _locked() -> bool:
	return key_item != "" and GameState.item_count(key_item) <= 0 and not GameState.is_opened(entity_id)


func get_interaction_text() -> String:
	var door := str(DungeonDB.get_def(dungeon_id).get("door", "la mazmorra"))
	if _locked():
		return "Entrada de %s (cerrada con llave)" % door
	return "[E] Entrar en %s" % door


func interact(player: Node) -> void:
	if _locked():
		Audio.play_3d("lever", global_position + Vector3(0, 1.2, 0), -4.0)
		var hint := str(DungeonDB.get_def(dungeon_id).get("entry_hint", ""))
		Events.notify.emit(hint if hint != "" else "Está cerrada con llave.", "info")
		return
	GameState.set_opened(entity_id, true)
	var game := player.get_tree().current_scene
	if game and game.has_method("enter_dungeon"):
		game.call("enter_dungeon", dungeon_id, entity_id)
	else:
		Events.notify.emit("La entrada está bloqueada por un derrumbe.", "info")
