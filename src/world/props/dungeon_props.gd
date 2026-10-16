class_name DungeonProps
extends RefCounted
## Elementos interactivos de las mazmorras: rejas y puertas cerradas, palancas,
## paredes falsas, trampas de pinchos, llaves y la salida.


## Reja (portcullis) abierta por palanca, o puerta cerrada con llave.
class Gate extends AnimatableBody3D:
	var entity_id := ""
	var locked_key := ""
	var style := "portcullis"
	var opened := false
	var _t := 0.0
	var _mesh: Node3D
	var _cs: CollisionShape3D

	func setup(id: String, key: String, gate_style: String) -> void:
		entity_id = id
		locked_key = key
		style = gate_style

	func _ready() -> void:
		collision_layer = 1 | 16
		sync_to_physics = false
		add_to_group("dungeon_gates")
		_mesh = Node3D.new()
		add_child(_mesh)
		if style == "portcullis":
			var mi := MeshInstance3D.new()
			mi.mesh = ModelLibrary.prop_mesh("portcullis")
			_mesh.add_child(mi)
		else:
			for side: int in [-1, 1]:
				var d := MeshInstance3D.new()
				d.mesh = ModelLibrary.prop_mesh("dungeon_door")
				d.position = Vector3(-1.0 if side < 0 else 1.0, 0, 0)
				d.rotation.y = 0.0 if side < 0 else PI
				d.scale = Vector3(1.0, 1.45, 1.0)
				_mesh.add_child(d)
		_cs = CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 3.0, 0.25)
		_cs.shape = box
		_cs.position = Vector3(0, 1.5, 0)
		add_child(_cs)
		opened = GameState.is_opened(entity_id)
		_t = 1.0 if opened else 0.0
		_apply()

	func get_interaction_text() -> String:
		if opened:
			return ""
		if style == "portcullis":
			return "Reja de hierro (se abre con una palanca)"
		if GameState.item_count(locked_key) > 0:
			return "[E] Abrir con la llave de hierro"
		return "Puerta cerrada con llave"

	func interact(_player: Node) -> void:
		if opened:
			return
		if style != "portcullis" and GameState.item_count(locked_key) > 0:
			open_gate()
			Events.notify.emit("La llave gira con un chirrido. La puerta se abre.", "info")
		elif style == "portcullis":
			Events.notify.emit("No se mueve. Busca un mecanismo cercano.", "info")
		else:
			Audio.play_3d("lever", global_position + Vector3(0, 1.2, 0), -4.0)
			Events.notify.emit("Está cerrada. Necesitas una llave.", "info")

	func open_gate() -> void:
		if opened:
			return
		opened = true
		GameState.set_opened(entity_id, true)
		Audio.play_3d("stone_door" if style == "portcullis" else "door_open", global_position + Vector3(0, 1.5, 0), 0.0)

	func _physics_process(delta: float) -> void:
		var target := 1.0 if opened else 0.0
		if not is_equal_approx(_t, target):
			_t = move_toward(_t, target, delta * 0.6)
			_apply()

	func _apply() -> void:
		if style == "portcullis":
			_mesh.position.y = _t * 2.9
			_cs.position.y = 1.5 + _t * 2.9
		else:
			for i in _mesh.get_child_count():
				var d := _mesh.get_child(i) as Node3D
				var base := 0.0 if i == 0 else PI
				d.rotation.y = base + (-1.0 if i == 0 else 1.0) * _t * deg_to_rad(95.0)
			_cs.disabled = _t > 0.5


## Palanca de pared que abre la reja con el mismo identificador.
class Lever extends StaticBody3D:
	var entity_id := ""
	var target_id := ""
	var pulled := false
	var _handle: Node3D
	var _t := 0.0

	func setup(id: String, target: String) -> void:
		entity_id = id
		target_id = target

	func _ready() -> void:
		collision_layer = 16
		var base := MeshInstance3D.new()
		base.mesh = ModelLibrary.prop_mesh("lever", {}, PackedStringArray(["base"]))
		add_child(base)
		var model := PropModels.lever()
		var hp := model.get_part("handle")
		_handle = Node3D.new()
		_handle.position = hp.origin
		add_child(_handle)
		var hm := MeshInstance3D.new()
		hm.mesh = ModelLibrary.prop_mesh("lever", {}, PackedStringArray(["handle"]), -hp.origin)
		_handle.add_child(hm)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.45, 0.6, 0.3)
		cs.shape = box
		add_child(cs)
		pulled = GameState.is_opened(entity_id)
		_t = 1.0 if pulled else 0.0
		_handle.rotation.x = lerpf(0.6, -0.6, _t)

	func get_interaction_text() -> String:
		return "Palanca (accionada)" if pulled else "[E] Accionar la palanca"

	func interact(_player: Node) -> void:
		if pulled:
			return
		pulled = true
		GameState.set_opened(entity_id, true)
		Audio.play_3d("lever", global_position, 0.0)
		for g in get_tree().get_nodes_in_group("dungeon_gates"):
			if g is Gate and (g as Gate).entity_id == target_id:
				(g as Gate).open_gate()
		GameState.set_opened(target_id, true)
		Events.notify.emit("Se oye un mecanismo pesado a lo lejos...", "info")

	func _process(delta: float) -> void:
		var target := 1.0 if pulled else 0.0
		if not is_equal_approx(_t, target):
			_t = move_toward(_t, target, delta * 3.0)
			_handle.rotation.x = lerpf(0.6, -0.6, _t)


## Pared falsa: un bloque agrietado que se desliza al examinarlo.
class SecretWall extends AnimatableBody3D:
	var entity_id := ""
	var opened := false
	var _t := 0.0
	var _base_y := 0.0
	var _mesh: MeshInstance3D
	static var _mat: StandardMaterial3D

	func setup(id: String) -> void:
		entity_id = id

	func _ready() -> void:
		collision_layer = 1 | 16
		sync_to_physics = false
		_mesh = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.0, 3.0, 1.0)
		bm.material = _material()
		_mesh.mesh = bm
		_mesh.position = Vector3(0, 1.5, 0)
		add_child(_mesh)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 3.0, 1.0)
		cs.shape = box
		cs.position = Vector3(0, 1.5, 0)
		add_child(cs)
		opened = GameState.is_opened(entity_id)
		_base_y = position.y
		_t = 1.0 if opened else 0.0
		_apply()

	static func _material() -> StandardMaterial3D:
		if _mat:
			return _mat
		var tf := TextureFactory.new()
		var img: Image = tf.build_images()[int(BlockTypes.texture_base["cracked_brick"])]
		var tex := ImageTexture.create_from_image(img)
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = tex
		_mat.albedo_color = Color(0.62, 0.64, 0.7)
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_mat.uv1_scale = Vector3(6.0, 3.0, 1.0)
		_mat.roughness = 0.95
		return _mat

	func get_interaction_text() -> String:
		return "" if opened else "[E] Examinar la pared agrietada"

	func interact(_player: Node) -> void:
		if opened:
			return
		opened = true
		GameState.set_opened(entity_id, true)
		Audio.play_3d("stone_door", global_position + Vector3(0, 1.5, 0), 0.0)
		Events.notify.emit("¡Una pared falsa! Se abre un pasadizo secreto.", "info")

	func _physics_process(delta: float) -> void:
		var target := 1.0 if opened else 0.0
		if not is_equal_approx(_t, target):
			_t = move_toward(_t, target, delta * 0.5)
			_apply()

	func _apply() -> void:
		position.y = _base_y - _t * 3.05


## Trampa de pinchos: placa visible en el suelo (detectable) que dispara
## pinchos al pisarla; daña una vez por activación y se rearma.
class SpikeTrap extends Node3D:
	var entity_id := ""
	var _spikes: Node3D
	var _area: Area3D
	var _state := 0      # 0 armada, 1 subiendo, 2 arriba, 3 bajando
	var _t := 0.0
	var _hit_done := false

	func setup(id: String) -> void:
		entity_id = id

	func _ready() -> void:
		var plate := MeshInstance3D.new()
		plate.mesh = ModelLibrary.prop_mesh("pressure_plate")
		plate.position = Vector3(0, 0.005, 0)
		add_child(plate)
		_spikes = Node3D.new()
		add_child(_spikes)
		var sm := MeshInstance3D.new()
		sm.mesh = ModelLibrary.prop_mesh("spikes")
		_spikes.add_child(sm)
		_spikes.position.y = -0.7
		_area = Area3D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2 | 4
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 0.5, 0.9)
		cs.shape = box
		cs.position = Vector3(0, 0.25, 0)
		_area.add_child(cs)
		add_child(_area)
		_area.body_entered.connect(_on_body)

	func _on_body(_body: Node3D) -> void:
		if _state == 0:
			_state = 1
			_t = 0.0
			_hit_done = false
			Audio.play_3d("trap", global_position + Vector3(0, 0.3, 0), 0.0)

	func _process(delta: float) -> void:
		match _state:
			1:
				_t += delta
				_spikes.position.y = lerpf(-0.7, 0.0, clampf(_t / 0.12, 0.0, 1.0))
				if _t >= 0.12 and not _hit_done:
					_hit_done = true
					for b in _area.get_overlapping_bodies():
						if b is Player:
							(b as Player).take_damage_raw(18.0, "pierce", global_position)
						elif b.has_method("take_hit") and b.has_method("is_alive") and bool(b.call("is_alive")):
							b.call("take_hit", 14.0, {"position": global_position + Vector3(0, 0.5, 0), "damage_type": "pierce"})
				if _t > 0.12:
					_state = 2
					_t = 0.0
			2:
				_t += delta
				if _t > 1.4:
					_state = 3
					_t = 0.0
			3:
				_t += delta
				_spikes.position.y = lerpf(0.0, -0.7, clampf(_t / 0.6, 0.0, 1.0))
				if _t > 0.6:
					_state = 0


## Llave flotante que se recoge al interactuar.
class KeyPickup extends Area3D:
	var entity_id := ""
	var item_id := ""
	var _mesh: MeshInstance3D
	var _t := 0.0

	func setup(id: String, item: String) -> void:
		entity_id = id
		item_id = item

	func _ready() -> void:
		if GameState.is_looted(entity_id):
			queue_free()
			return
		collision_layer = 16
		collision_mask = 0
		monitoring = false
		_mesh = MeshInstance3D.new()
		var is_book := str(ItemDB.get_def(item_id).get("category", "")) == "book"
		_mesh.mesh = ModelLibrary.prop_mesh("book" if is_book else "key")
		add_child(_mesh)
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.35
		cs.shape = sph
		add_child(cs)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.4)
		light.omni_range = 2.5
		light.light_energy = 0.8
		add_child(light)

	func _process(delta: float) -> void:
		_t += delta
		_mesh.rotation.y = _t * 1.5
		_mesh.position.y = sin(_t * 2.0) * 0.06

	func get_interaction_text() -> String:
		return "[E] Coger %s" % ItemDB.display_name(item_id)

	func interact(player: Node) -> void:
		GameState.mark_looted(entity_id)
		GameState.give_item(player, {"id": item_id, "count": 1})
		Audio.play_2d("pickup", -2.0)
		Events.notify.emit("Has cogido: %s" % ItemDB.display_name(item_id), "item")
		queue_free()


## Escalera de salida de la mazmorra.
class Exit extends StaticBody3D:
	func _ready() -> void:
		collision_layer = 1 | 16
		var mi := MeshInstance3D.new()
		mi.mesh = ModelLibrary.prop_mesh("exit_stairs")
		add_child(mi)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 1.0, 0.6)
		cs.shape = box
		cs.position = Vector3(0, 0.5, -0.3)
		add_child(cs)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 2.5, -1.5)
		light.light_color = Color(0.9, 0.95, 1.0)
		light.omni_range = 6.0
		light.light_energy = 1.2
		add_child(light)

	func get_interaction_text() -> String:
		return "[E] Subir a la superficie"

	func interact(player: Node) -> void:
		var game := player.get_tree().current_scene
		if game and game.has_method("exit_dungeon"):
			game.call("exit_dungeon")


## Capullo de seda del nido de arañas: dentro queda lo que llevaba la víctima.
## Se raja con [E] una sola vez (queda abierto también al volver).
class Cocoon extends StaticBody3D:
	var entity_id := ""
	var loot := "cocoon"
	var _mesh: MeshInstance3D

	func setup(id: String, loot_table: String) -> void:
		entity_id = id
		loot = loot_table

	func _ready() -> void:
		collision_layer = 1 | 16
		collision_mask = 0
		_mesh = MeshInstance3D.new()
		_mesh.mesh = ModelLibrary.prop_mesh("cocoon_torn" if GameState.is_looted(entity_id) else "cocoon")
		add_child(_mesh)
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.32
		cap.height = 1.75
		cs.shape = cap
		cs.position = Vector3(0, 0.88, 0)
		add_child(cs)

	func get_interaction_text() -> String:
		if GameState.is_looted(entity_id):
			return "Capullo de seda (rajado)"
		return "[E] Rajar el capullo de seda"

	func interact(player: Node) -> void:
		if GameState.is_looted(entity_id):
			return
		GameState.mark_looted(entity_id)
		_mesh.mesh = ModelLibrary.prop_mesh("cocoon_torn")
		var at := global_position + Vector3(0, 1.0, 0)
		Audio.play_3d("web_hit", at, 0.0)
		HitFX.spawn(get_tree().current_scene, "web", at, -global_basis.z, 1.3)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(entity_id)
		var found: Array[String] = []
		var gold := LootTables.gold_for(loot, rng)
		if gold > 0 and player and "gold" in player:
			player.set("gold", int(player.get("gold")) + gold)
			found.append("%d monedas de oro" % gold)
			Audio.play_2d("gold", -4.0)
		for item: Dictionary in LootTables.roll(loot, rng):
			GameState.give_item(player, item)
			var c := int(item.get("count", 1))
			found.append(str(item["name"]) + (" x%d" % c if c > 1 else ""))
		Events.notify.emit("Dentro del capullo: " + (", ".join(found) if not found.is_empty() else "solo huesos"), "item")
