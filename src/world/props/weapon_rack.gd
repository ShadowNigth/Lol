class_name WeaponRack
extends StaticBody3D
## Armero de la herrería: permite tomar armas (hacha, maza, daga) una vez.

var entity_id: String = ""
const WEAPONS := ["res://data/weapons/axe.tres", "res://data/weapons/mace.tres", "res://data/weapons/dagger.tres"]


func setup(id: String) -> void:
	entity_id = id


func _ready() -> void:
	collision_layer = 1 | 16
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLibrary.prop_mesh("weapon_rack")
	add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 0.25)
	cs.shape = box
	cs.position = Vector3(0, 0.75, -0.1)
	add_child(cs)


func get_interaction_text() -> String:
	if GameState.is_looted(entity_id):
		return "Armero (vacío)"
	return "[E] Tomar armas del armero"


func interact(player: Node) -> void:
	if GameState.is_looted(entity_id):
		return
	GameState.mark_looted(entity_id)
	var given := 0
	for path: String in WEAPONS:
		var w := load(path) as WeaponData
		if w and player.has_method("add_weapon") and bool(player.call("add_weapon", w)):
			given += 1
	if given == 0:
		Events.notify.emit("Ya tienes todas estas armas.", "info")
