class_name EntitySpawner
extends Node3D
## Instancia las entidades de cada chunk (mobiliario, puertas, cofres, luces,
## humo, enemigos...) cuando el chunk se carga y las libera al descargarse.

var world: VoxelWorld
var player: Player
var _by_chunk: Dictionary = {}   # Vector2i -> Array[Node]
var _enemy_data_cache: Dictionary = {}

const STATIC_PROPS := ["barrel", "crate", "table", "chair", "bed", "anvil", "bucket", "goods", "hay_cart", "banner", "sign",
		"bedroll", "log_seat", "sack", "throne", "training_dummy", "minecart", "ore_pile", "pickaxe"]
## Props decorativos que no bloquean el paso.
const NO_COLLISION_PROPS := ["banner", "sign", "bones", "bedroll", "pickaxe"]


func setup(voxel_world: VoxelWorld, p: Player) -> void:
	world = voxel_world
	player = p
	world.chunk_loaded.connect(_on_chunk_loaded)
	world.chunk_unloaded.connect(_on_chunk_unloaded)


func _on_chunk_loaded(coord: Vector2i, data: ChunkData) -> void:
	var nodes: Array[Node] = []
	for e: Dictionary in data.entities:
		var n := _spawn(e)
		if n:
			nodes.append(n)
	# Objetos soltados por el jugador en este chunk
	for d: Variant in GameState.dropped_in_area():
		var dp: Array = (d as Dictionary)["pos"]
		var pos := Vector3(float(dp[0]), float(dp[1]), float(dp[2]))
		if data.contains_world_core(int(floor(pos.x)), int(floor(pos.z))):
			nodes.append(spawn_dropped(d as Dictionary))
	_by_chunk[coord] = nodes


func spawn_dropped(entry: Dictionary) -> Node:
	var dp: Array = entry["pos"]
	var pk := ItemPickup.new()
	pk.setup(str(entry["id"]))
	pk.set_meta("drop_entry", entry)
	pk.position = Vector3(float(dp[0]), float(dp[1]), float(dp[2]))
	add_child(pk)
	return pk


func _on_chunk_unloaded(coord: Vector2i) -> void:
	var nodes: Array = _by_chunk.get(coord, [])
	for n: Variant in nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_by_chunk.erase(coord)


func _spawn(e: Dictionary) -> Node:
	# Apariciones condicionadas por la historia (p. ej. la prisionera rescatada
	# deja la jaula y aparece en su aldea)
	var req := str(e.get("requires_flag", ""))
	if req != "" and not GameState.has_flag(req):
		return null
	var unless := str(e.get("unless_flag", ""))
	if unless != "" and GameState.has_flag(unless):
		return null
	var type := str(e.get("type", ""))
	var pos: Vector3 = e.get("pos", Vector3.ZERO)
	var yaw := deg_to_rad(float(e.get("yaw", 0.0)))
	var id := str(e.get("id", ""))
	match type:
		"enemy":
			if GameState.is_killed(id, int(e.get("respawn_days", 0))):
				return null
			return _spawn_enemy(e)
		"npc":
			var npc_def := NpcDB.get_npc(str(e.get("npc", "")))
			# Guardias caídos: no vuelven hasta pasados unos días
			if bool(npc_def.get("generic", false)) and GameState.is_killed(id, Law.GUARD_RESPAWN_DAYS):
				return null
			# Un personaje con nombre no puede estar en dos sitios (p. ej. acompañándote)
			if not bool(npc_def.get("generic", false)) and _named_npc_exists(str(e.get("npc", ""))):
				return null
			var npc := NPC.new()
			npc.setup(str(e.get("npc", "")), e, player)
			npc.name = "NPC_" + str(e.get("npc", ""))
			npc.add_to_group("npcs")
			npc.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(npc)
			_activate_when_safe.call_deferred(npc)
			return npc
		"door":
			var door := Door.new()
			door.setup(id, rad_to_deg(yaw))
			add_child(door)
			# El origen del modelo está en la bisagra: se desplaza medio bloque.
			door.global_position = pos + Basis(Vector3.UP, yaw) * Vector3(-0.5, 0, 0)
			return door
		"chest":
			var chest := Chest.new()
			chest.setup(id, str(e.get("loot", "home")), int(e.get("lock", 0)), str(e.get("key", "")))
			add_child(chest)
			chest.global_position = pos
			chest.rotation.y = yaw
			return chest
		"weapon_rack":
			var rack := WeaponRack.new()
			rack.setup(id)
			add_child(rack)
			rack.global_position = pos
			rack.rotation.y = yaw
			return rack
		"notice_board":
			var nb := NoticeBoard.new()
			nb.setup(id, str(e.get("site", "")))
			add_child(nb)
			nb.global_position = pos
			nb.rotation.y = yaw
			return nb
		"dungeon_entrance":
			var de := DungeonEntrance.new()
			de.setup(id, str(e.get("dungeon", "")), str(e.get("style", "door")))
			add_child(de)
			de.global_position = pos
			de.rotation.y = yaw
			return de
		"lantern", "wall_lantern":
			var root := Node3D.new()
			add_child(root)
			root.global_position = pos
			root.rotation.y = yaw
			var mi := MeshInstance3D.new()
			mi.mesh = ModelLibrary.prop_mesh(type)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			var light := TorchLight.new()
			light.position = Vector3(0, 0.2, 0)
			light.omni_range = 7.5 if type == "lantern" else 6.5
			light.base_energy = 1.7 if type == "lantern" else 1.3
			root.add_child(light)
			return root
		"forge_fire":
			var f := Node3D.new()
			add_child(f)
			f.global_position = pos
			var coals := MeshInstance3D.new()
			coals.mesh = ModelLibrary.prop_mesh("forge_fire")
			f.add_child(coals)
			for k in 3:
				var flame := MeshInstance3D.new()
				flame.mesh = world.flame_mesh
				flame.position = Vector3(-0.2 + k * 0.2, 0.25, 0.0)
				flame.scale = Vector3.ONE * 1.4
				f.add_child(flame)
			var fl := TorchLight.new()
			fl.position = Vector3(0, 0.6, 0)
			fl.omni_range = 8.0
			fl.base_energy = 2.0
			fl.light_color = Color(1.0, 0.55, 0.25)
			f.add_child(fl)
			Audio.make_loop_player_3d("fire_loop", f, -10.0, 12.0)
			return f
		"smoke":
			return _spawn_smoke(pos)
		"campfire":
			var cf := _spawn_static_prop("campfire", pos, yaw, e)
			for k in 4:
				var flame := MeshInstance3D.new()
				flame.mesh = world.flame_mesh
				var a := TAU * k / 4.0 + 0.3
				flame.position = Vector3(cos(a) * 0.12, 0.3 + (k % 2) * 0.12, sin(a) * 0.12)
				flame.scale = Vector3.ONE * (2.2 if k % 2 == 0 else 1.7)
				cf.add_child(flame)
			var cl := TorchLight.new()
			cl.position = Vector3(0, 0.9, 0)
			cl.omni_range = 11.0
			cl.base_energy = 2.2
			cl.light_color = Color(1.0, 0.58, 0.28)
			cf.add_child(cl)
			var smoke := _spawn_smoke(pos + Vector3(0, 1.0, 0))
			smoke.reparent(cf)
			Audio.make_loop_player_3d("fire_loop", cf, -8.0, 14.0)
			return cf
		"cage":
			var cage := Cage.new()
			cage.setup(id, int(e.get("lock", 45)), str(e.get("key", "")), str(e.get("flag", "")), str(e.get("captive", "")))
			add_child(cage)
			cage.global_position = pos
			cage.rotation.y = yaw
			return cage
		"dungeon_gate":
			var g := DungeonProps.Gate.new()
			g.setup(id, str(e.get("locked_key", "")), str(e.get("style", "portcullis")))
			g.position = pos
			g.rotation.y = yaw
			add_child(g)
			return g
		"lever":
			var lv := DungeonProps.Lever.new()
			lv.setup(id, str(e.get("target", "")))
			lv.position = pos
			lv.rotation.y = yaw
			add_child(lv)
			return lv
		"secret_wall":
			var sw := DungeonProps.SecretWall.new()
			sw.setup(id)
			sw.position = pos
			sw.rotation.y = yaw
			add_child(sw)
			return sw
		"spike_trap":
			var st := DungeonProps.SpikeTrap.new()
			st.setup(id)
			st.position = pos
			add_child(st)
			return st
		"key_pickup":
			if GameState.is_looted(id):
				return null
			var kp := DungeonProps.KeyPickup.new()
			kp.setup(id, str(e.get("item", "")))
			kp.position = pos
			add_child(kp)
			return kp
		"dungeon_exit":
			var ex := DungeonProps.Exit.new()
			ex.position = pos
			ex.rotation.y = yaw
			add_child(ex)
			return ex
		"brazier":
			var br := _spawn_static_prop("brazier", pos, 0.0, e)
			var flame := MeshInstance3D.new()
			flame.mesh = world.flame_mesh
			flame.position = Vector3(0, 1.15, 0)
			flame.scale = Vector3.ONE * 1.8
			br.add_child(flame)
			var bl := TorchLight.new()
			bl.position = Vector3(0, 1.5, 0)
			bl.omni_range = 7.0
			bl.base_energy = 1.4
			br.add_child(bl)
			return br
		"pillar", "sarcophagus", "bones":
			return _spawn_static_prop(type, pos, yaw, e)
		"mine_lamp":
			# Poste de mina con farol colgante (luz cálida y algo temblorosa)
			var ml := _spawn_static_prop("mine_lamp", pos, yaw, e)
			var mll := TorchLight.new()
			mll.position = Vector3(0.37, 1.4, -0.06)
			mll.omni_range = 6.5
			mll.base_energy = 1.2
			ml.add_child(mll)
			return ml
		"egg_sac":
			# Huevos de araña: un resplandor verdoso muy tenue en el nido
			var eg := _spawn_static_prop("egg_sac", pos, yaw, e)
			var egl := OmniLight3D.new()
			egl.light_color = Color(0.7, 1.0, 0.45)
			egl.omni_range = 3.2
			egl.light_energy = 0.55
			egl.position = Vector3(0, 0.45, 0)
			egl.shadow_enabled = false
			eg.add_child(egl)
			return eg
		"cocoon":
			var cc := DungeonProps.Cocoon.new()
			cc.setup(id, str(e.get("loot", "cocoon")))
			add_child(cc)
			cc.global_position = pos
			cc.rotation.y = yaw
			return cc
		"castle_portcullis":
			# Rastrillo alzado en la boca de la torre-puerta: decorativo, sin colisión
			var pc := MeshInstance3D.new()
			pc.mesh = ModelLibrary.prop_mesh("portcullis")
			add_child(pc)
			pc.global_position = pos + Vector3(0, 2.55, 0)
			pc.rotation.y = yaw
			pc.scale = Vector3(1.55, 1.0, 1.0)
			return pc
		"cell_door":
			var cd := CellDoor.new()
			cd.setup(id, int(e.get("lock", 0)), str(e.get("key", "")), rad_to_deg(yaw))
			add_child(cd)
			# Bisagra a la izquierda, como las puertas de madera
			cd.global_position = pos + Basis(Vector3.UP, yaw) * Vector3(-0.5, 0, 0)
			return cd
		_:
			if type in STATIC_PROPS:
				return _spawn_static_prop(type, pos, yaw, e)
	return null


func _spawn_static_prop(type: String, pos: Vector3, yaw: float, e: Dictionary) -> Node:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.global_position = pos
	body.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = ModelLibrary.prop_mesh(type, e)
	body.add_child(mi)
	var bounds := ModelLibrary.prop_bounds(type, e)
	if type in NO_COLLISION_PROPS:
		return body
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size.max(Vector3(0.05, 0.05, 0.05))
	cs.shape = box
	cs.position = bounds.get_center()
	body.add_child(cs)
	return body


func _spawn_smoke(pos: Vector3) -> Node:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.25, 0.15, 0.1)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.22
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.55, 0.57, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	p.mesh = mesh
	var grad := Gradient.new()
	grad.set_color(0, Color(0.6, 0.6, 0.62, 0.55))
	grad.set_color(1, Color(0.7, 0.7, 0.72, 0.0))
	p.color_ramp = grad
	add_child(p)
	p.global_position = pos
	p.emitting = true
	return p


func _spawn_enemy(e: Dictionary) -> Node:
	var kind := str(e.get("enemy", "skeleton_warrior"))
	var data: EnemyData = _enemy_data_cache.get(kind, null)
	if data == null:
		data = load("res://data/enemies/%s.tres" % kind) as EnemyData
		if data == null:
			push_warning("Datos de enemigo no encontrados: %s" % kind)
			return null
		_enemy_data_cache[kind] = data
	var enemy := Enemy.new()
	enemy.name = "Enemy_" + str(e.get("id", "x")).replace("/", "_")
	enemy.setup(data, e, world, player)
	enemy.add_to_group("enemies")
	enemy.killed.connect(func(en: Enemy) -> void: GameState.mark_killed(en.entity_id))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(enemy)
	_activate_when_safe.call_deferred(enemy)
	return enemy


## Enemigo invocado en plena pelea (las crías de la reina de las arañas): se
## libera con el chunk donde aparece y no se guarda en la partida.
func spawn_summon(kind: String, pos: Vector3, yaw_deg: float, id: String) -> Enemy:
	var e := _spawn_enemy({"enemy": kind, "pos": pos, "yaw": yaw_deg, "id": id}) as Enemy
	if e:
		track_node(e)
	return e


## Espera a que la colisión del chunk exista y coloca al actor en un hueco
## libre sobre el suelo antes de activarlo (evita que aparezca dentro de un
## bloque y la física lo expulse a través del terreno).
func _activate_when_safe(actor: CharacterBody3D) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(actor):
		return
	var radius := 0.34
	var height := 1.8
	if actor is Enemy:
		# Criaturas anchas (arañas, la reina) necesitan un hueco a su medida
		var d := (actor as Enemy).data
		radius = maxf(0.3, d.collision_radius * d.model_scale)
		height = maxf(radius * 2.0, d.collision_height * d.model_scale)
	var spot := find_free_spot(actor.global_position, radius, height)
	actor.global_position = spot
	if actor is Enemy:
		(actor as Enemy).home = spot
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	actor.reset_physics_interpolation()


## Busca una posición cercana donde una cápsula quepa sin solaparse y apoyada
## en el suelo. Devuelve la posición original si no encuentra nada mejor.
func find_free_spot(pos: Vector3, radius: float, height: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = 1
	var offsets: Array[Vector3] = [Vector3.ZERO]
	for r: float in [0.7, 1.4, 2.1]:
		for k in 8:
			var a := TAU * k / 8.0
			offsets.append(Vector3(cos(a) * r, 0, sin(a) * r))
	for off in offsets:
		var probe := pos + off
		# Suelo bajo el punto (desde un poco más arriba). Si hay un techo encima
		# (torre de vigía, tienda, interior bajo) se sondea desde debajo de él,
		# para no colocar al actor sobre el tejado.
		var top := probe + Vector3(0, 2.5, 0)
		var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe + Vector3(0, 0.3, 0), top, 1))
		if not up.is_empty():
			top = (up["position"] as Vector3) - Vector3(0, 0.05, 0)
		var q := PhysicsRayQueryParameters3D.create(top, probe + Vector3(0, -4.0, 0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var ground: Vector3 = hit["position"]
		if (hit["normal"] as Vector3).y < 0.6:
			continue
		params.transform = Transform3D(Basis.IDENTITY, ground + Vector3(0, height * 0.5 + 0.05, 0))
		if space.intersect_shape(params, 1).is_empty():
			return ground + Vector3(0, 0.02, 0)
	return pos


func _named_npc_exists(npc_id: String) -> bool:
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		var other := n as NPC
		if other and other.npc_id == npc_id and not other.is_queued_for_deletion():
			return true
	return false


## Vuelve a asociar un nodo al chunk donde está ahora (se liberará con él).
func track_node(n: Node3D) -> void:
	detach_node(n)
	var coord := Vector2i(floori(n.global_position.x / ChunkData.SIZE), floori(n.global_position.z / ChunkData.SIZE))
	if _by_chunk.has(coord):
		(_by_chunk[coord] as Array).append(n)


## Saca un nodo de las listas de los chunks (p. ej. un acompañante que te
## sigue: no debe desaparecer cuando se descarga el chunk donde apareció).
func detach_node(n: Node) -> void:
	for coord: Vector2i in _by_chunk:
		var arr: Array = _by_chunk[coord]
		var i := arr.find(n)
		if i >= 0:
			arr.remove_at(i)


## Acompañante de una escolta en curso: aparece junto al jugador.
func spawn_follower(npc_id: String) -> NPC:
	if _named_npc_exists(npc_id):
		return null
	var back := -player.look_direction()
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3(0, 0, 1)
	var pos := player.global_position + back.normalized() * 2.0
	var npc := NPC.new()
	npc.setup(npc_id, {"id": "npc/%s" % npc_id, "pos": pos, "yaw": player.get_yaw_degrees()}, player)
	npc.name = "NPC_" + npc_id
	npc.add_to_group("npcs")
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(npc)
	_activate_when_safe.call_deferred(npc)
	return npc


## Un guardia que pelea: un Enemy con el aspecto, equipo y nombre del PNJ
## ocupa su lugar (el PNJ queda oculto hasta que se calme; ver Law).
func spawn_guard_enemy(npc: NPC) -> Enemy:
	var data: EnemyData = _enemy_data_cache.get("town_guard", null)
	if data == null:
		data = load("res://data/enemies/town_guard.tres") as EnemyData
		if data == null:
			push_warning("Falta data/enemies/town_guard.tres")
			return null
		_enemy_data_cache["town_guard"] = data
	var e := Enemy.new()
	e.name = "HostileGuard_" + npc.entity_id.replace("/", "_")
	e.setup(data, {"id": npc.entity_id, "pos": npc.global_position, "yaw": rad_to_deg(npc.rotation.y),
			"look": npc.look_final, "gear": npc.data.get("gear", {}), "name": str(npc.data.get("name", ""))}, world, player)
	e.guard_npc = npc
	e.guard_essential = npc.is_essential()
	e.home = npc.work_pos
	e.add_to_group("enemies")
	e.killed.connect(func(en: Enemy) -> void: GameState.mark_killed(en.entity_id))
	add_child(e)
	e.global_position = npc.global_position
	e.stats.health = e.stats.max_health * clampf(npc.health_ratio(), 0.05, 1.0)
	e.make_aware()
	npc.hide_for_hostile(e)
	# Se libera con el chunk en el que está ahora (igual que el PNJ)
	for coord: Vector2i in _by_chunk:
		var arr: Array = _by_chunk[coord]
		if arr.has(npc):
			arr.append(e)
			break
	return e
