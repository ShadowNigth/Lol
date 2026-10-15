class_name NoticeBoard
extends StaticBody3D
## Tablón de anuncios de un asentamiento: ofrece encargos generados (Bounties).

var entity_id: String = ""
var site: String = ""


func setup(id: String, site_id: String) -> void:
	entity_id = id
	site = site_id


func _ready() -> void:
	collision_layer = 1 | 16
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLibrary.prop_mesh("notice_board")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 2.2, 0.3)
	cs.shape = box
	cs.position = Vector3(0, 1.1, 0)
	add_child(cs)


func get_interaction_text() -> String:
	var active := Bounties.active_for(site)
	if active != "" and str((QuestManager.current_stage(active).get("objective", {}) as Dictionary).get("type", "")) == "talk":
		return "[E] Cobrar el encargo"
	return "[E] Leer el tablón de anuncios"


func interact(_player: Node) -> void:
	Bounties.use_board(site)
