extends Node
## Herramienta de capturas para revisión visual automática. Inicia una partida
## con semilla fija, recorre puntos de vista y fotografía poses concretas de
## las animaciones (primera persona y esqueleto).
## Uso (con un renderizador real, p. ej. el binario de pruebas offscreen):
##   godot --path . res://tools/dev/capture.tscn -- --out=/tmp/caps [--set=views,vm,enemy] [--only=nombre1,nombre2]

var _out := "/tmp/caps"
var _sets: PackedStringArray = ["views", "vm", "enemy"]
var _queue: Array[Dictionary] = []
var _wait := 0
var _cur: Dictionary = {}
var _started := false
var _preview: Node3D
var _preview_anim: AnimationPlayer
var _dungeon_wait := false
var _wolf: Node3D
var _wolf_anim: AnimationPlayer
var _wolf_variant := -1
var _bandits: Array[Node3D] = []
var _only: PackedStringArray = []      # --only=a,b: solo esas capturas


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--set="):
			_sets = a.substr(6).split(",")
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_begin")


func _begin() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Audio.wait_until_ready()
	# Distancia de dibujado reducida: el renderizado por CPU es lento.
	Settings.view_distance = 4
	GameState.start_new_game({"name": "Captura", "class": "warrior", "seed": 12345})


func _game() -> Node:
	return get_tree().current_scene


func _player() -> Player:
	var g := _game()
	return g.get("player") as Player if g and "player" in g else null


func _build_queue() -> void:
	if "views" in _sets:
		# [nombre, pos, yaw, pitch, hora]
		_queue.append({"name": "plaza", "pos": Vector3(3.5, 37.0, 6.5), "yaw": 20.0, "pitch": -4.0, "time": 15.5})
		_queue.append({"name": "inn_front", "pos": Vector3(1.5, 37.0, -2.5), "yaw": 0.0, "pitch": 6.0, "time": 16.5})
		_queue.append({"name": "houses_west", "pos": Vector3(-5.5, 37.0, -2.0), "yaw": 65.0, "pitch": 2.0, "time": 10.0})
		_queue.append({"name": "smithy", "pos": Vector3(6.5, 37.0, -9.5), "yaw": -90.0, "pitch": -2.0, "time": 12.0})
		_queue.append({"name": "tower", "pos": Vector3(-3.0, 37.0, 16.0), "yaw": -150.0, "pitch": 14.0, "time": 17.8})
		_queue.append({"name": "gate", "pos": Vector3(22.5, 37.0, 0.5), "yaw": -90.0, "pitch": 4.0, "time": 9.0})
		_queue.append({"name": "inn_inside", "pos": Vector3(0.5, 37.0, -12.4), "yaw": 10.0, "pitch": -4.0, "time": 21.0})
		_queue.append({"name": "night_plaza", "pos": Vector3(-4.5, 37.0, 5.5), "yaw": -40.0, "pitch": 0.0, "time": 23.0})
		_queue.append({"name": "ruins", "pos": Vector3(64.5, -1.0, 2.5), "yaw": 0.0, "pitch": 3.0, "time": 18.4})
	if "vm" in _sets:
		for a: Array in [["sword_idle", 0.0], ["sword_attack_1", 0.16], ["sword_attack_1", 0.27], ["sword_attack_1", 0.38],
				["sword_attack_3", 0.22], ["sword_block", 0.25], ["axe_idle", 0.0], ["axe_attack_2", 0.28], ["mace_idle", 0.0],
				["dagger_idle", 0.0], ["dagger_attack_1", 0.16], ["sword_run", 0.2], ["interact", 0.25]]:
			_queue.append({"name": "vm_%s_%03d" % [a[0], int(float(a[1]) * 100)], "vm": a[0], "t": a[1]})
		_queue.append({"name": "vm_sword_block_shield", "vm": "sword_block", "t": 0.25})
	if "ui" in _sets:
		_queue.append({"name": "npcs_plaza", "pos": Vector3(4.5, 37.0, 5.5), "yaw": 35.0, "pitch": -3.0, "time": 11.0})
		_queue.append({"name": "ui_dialogue", "ui": "dialogue"})
		_queue.append({"name": "ui_inventory", "ui": "menu", "tab": 0})
		_queue.append({"name": "ui_character", "ui": "menu", "tab": 1})
		_queue.append({"name": "ui_journal", "ui": "menu", "tab": 2})
		_queue.append({"name": "ui_map", "ui": "menu", "tab": 3})
	if "dungeon" in _sets:
		_queue.append({"name": "dungeon_enter", "dungeon": true})
		_queue.append({"name": "dungeon_entrance", "dview": "entrance"})
		_queue.append({"name": "dungeon_corridor", "dview": "corridor"})
		_queue.append({"name": "dungeon_boss", "dview": "boss"})
		_queue.append({"name": "dungeon_treasure", "dview": "treasure"})
	if "wolf" in _sets:
		for e2: Array in [["idle", 0.0], ["walk", 0.25], ["walk", 0.75], ["run", 0.12], ["run", 0.42], ["alert", 0.6],
				["attack_1", 0.16], ["attack_1", 0.32], ["attack_2", 0.42], ["hit", 0.08], ["stun", 0.45], ["death", 0.6], ["death", 1.5]]:
			_queue.append({"name": "wolf_%s_%03d" % [e2[0], int(float(e2[1]) * 100)], "wolf": e2[0], "t": e2[1], "variant": 0})
		for v: int in [1, 2, 3]:
			_queue.append({"name": "wolf_variant_%d" % v, "wolf": "idle", "t": 0.5, "variant": v})
	if "armor" in _sets:
		for o: Array in [["cloth", "bare", "shield"], ["leather", "leather_gloves", "shield"], ["chain", "gauntlets", "shield_iron"], ["robe", "bare", ""]]:
			_queue.append({"name": "armor_%s_%s" % [o[0], o[1]], "armor": o})
	if "sites" in _sets:
		var wg := (_game().get("overworld_generator") as WorldGenerator)
		var site_views := {"inn_lobo": [Vector2(16, 12), 15.0], "robledal": [Vector2(-14, -22), 11.0], "barrow_grises": [Vector2(-9, -20), 17.0],
				"cave_lobos": [Vector2(6, -17), 9.5]}
		for site: Dictionary in wg.planner.sites:
			if not site_views.has(site["id"]):
				continue
			var sp: Vector2 = site["pos"]
			var off: Vector2 = site_views[site["id"]][0]
			var cam := sp + off
			var to := sp - cam
			_queue.append({"name": "site_%s" % site["id"], "pos": Vector3(cam.x + 0.5, -1.0, cam.y + 0.5),
					"yaw": rad_to_deg(atan2(-to.x, -to.y)), "pitch": 2.0, "time": float(site_views[site["id"]][1])})
	if "readme" in _sets:
		_queue.append({"name": "readme_village", "pos": Vector3(3.5, 37.0, 6.5), "yaw": 20.0, "pitch": -4.0, "time": 15.5})
	if "cave" in _sets:
		_queue.append({"name": "cave_enter", "dungeon": "cave_lobos"})
		_queue.append({"name": "cave_entrance", "dview": "entrance"})
		_queue.append({"name": "cave_boss", "dview": "boss"})
	if "camp" in _sets:
		var wg2 := (_game().get("overworld_generator") as WorldGenerator)
		var st: Dictionary = {}
		for s0: Dictionary in wg2.planner.structures:
			if str(s0.get("id", "")) == "bandit_camp/camp":
				st = s0
		# Mapa antes y después de descubrir el campamento (lugar oculto)
		_queue.append({"name": "camp_map_hidden", "ui": "menu", "tab": 3})
		_queue.append({"name": "camp_map_known", "ui": "menu", "tab": 3, "flag": "known_bandit_camp"})
		if not st.is_empty():
			# [nombre, cámara (local), objetivo (local), hora]
			var views := [["camp_gate", Vector3(12.5, 0, -7.0), Vector3(12.5, 1.5, 12.5), 16.0],
					["camp_inside", Vector3(12.5, 0, 7.0), Vector3(12.5, 1.5, 19.0), 15.0],
					["camp_cage", Vector3(9.8, 0, 7.6), Vector3(6.0, 1.0, 6.0), 14.0],
					["camp_tower", Vector3(9.5, 0, 11.5), Vector3(16.5, 3.0, 5.5), 13.0],
					["camp_tents", Vector3(15.5, 0, 12.5), Vector3(5.5, 1.0, 11.0), 17.0],
					["camp_night", Vector3(12.5, 0, -6.0), Vector3(12.5, 1.0, 12.5), 22.5]]
			for v: Array in views:
				var cam := ChunkWriter.local_to_world(st["origin"], int(st["w"]), int(st["d"]), int(st["rot"]), v[1])
				var tgt := ChunkWriter.local_to_world(st["origin"], int(st["w"]), int(st["d"]), int(st["rot"]), v[2])
				var to := tgt - cam
				_queue.append({"name": v[0], "pos": Vector3(cam.x, -1.0, cam.z), "yaw": rad_to_deg(atan2(-to.x, -to.z)),
						"pitch": rad_to_deg(atan2(to.y - 1.6, Vector2(to.x, to.z).length())), "time": v[3], "camp": true})
		# Emboscada junto al camino (la primera que se encuentre en la red de caminos)
		var found := false
		for road: Dictionary in wg2.planner.roads:
			if found:
				break
			var ra: Vector2 = road["a"]
			var rb: Vector2 = road["b"]
			var n := int(ra.distance_to(rb) / 12.0) + 1
			for k in n + 1:
				var q := ra.lerp(rb, float(k) / float(n))
				for e: Dictionary in wg2.generate_chunk(int(floor(q.x / 16.0)), int(floor(q.y / 16.0))).entities:
					if not found and str(e.get("id", "")).begins_with("wild/bandit_"):
						var bp: Vector3 = e["pos"]
						var rp: Dictionary = wg2.planner.nearest_road_point(Vector2(bp.x, bp.z))
						var cam2: Vector2 = rp["point"] + (rp["point"] - Vector2(bp.x, bp.z)).normalized() * 2.0
						var to2 := Vector2(bp.x, bp.z) - cam2
						_queue.append({"name": "camp_ambush", "pos": Vector3(cam2.x, -1.0, cam2.y), "yaw": rad_to_deg(atan2(-to2.x, -to2.y)),
								"pitch": -4.0, "time": 15.0, "camp": true})
						found = true
	if "bandits" in _sets:
		_queue.append({"name": "bandits_idle", "bandits": "idle", "t": 0.6})
		_queue.append({"name": "bandits_attack", "bandits": "attack_1", "t": 0.42})
		_queue.append({"name": "bandits_back", "bandits": "idle", "t": 0.6, "back": true})
	if "enemy" in _sets:
		for e: Array in [["idle", 0.0], ["walk", 0.25], ["run", 0.16], ["alert", 0.4], ["attack_1", 0.42], ["attack_1", 0.56],
				["attack_2", 0.5], ["attack_2", 0.68], ["block", 0.35], ["hit", 0.08], ["stun", 0.5], ["death", 0.5], ["death", 1.5]]:
			_queue.append({"name": "enemy_%s_%03d" % [e[0], int(float(e[1]) * 100)], "enemy": e[0], "t": e[1]})


func _process(_delta: float) -> void:
	var g := _game()
	if not _started:
		if g and g.has_method("is_world_ready") and bool(g.call("is_world_ready")):
			_started = true
			_build_queue()
			if not _only.is_empty():
				var kept: Array[Dictionary] = []
				for q: Dictionary in _queue:
					if str(q["name"]) in _only:
						kept.append(q)
				_queue = kept
			var hud := g.get("hud") as HUD
			if hud:
				hud.set_visible_hud("--hud" in OS.get_cmdline_user_args())
		return
	# En las vistas del campamento los bandidos no ven a la cámara
	if "camp" in _sets:
		for en: Node in get_tree().get_nodes_in_group("enemies"):
			en.set("target", null)
	if _dungeon_wait:
		if g.has_method("is_world_ready") and bool(g.call("is_world_ready")):
			_dungeon_wait = false
		return
	if _wait > 0:
		# En las vistas, esperar a que no queden chunks pendientes cerca.
		var w := g.get("world") as VoxelWorld
		if (_cur.has("pos") or _cur.has("dview")) and _wait <= 3 and w and w.pending_task_count() > 0:
			return
		_wait -= 1
		if _wait == 0:
			_snap()
		return
	if _queue.is_empty():
		print("[CAPTURE] Terminado")
		get_tree().quit()
		return
	_cur = _queue.pop_front()
	_setup_shot(_cur)


func _setup_shot(shot: Dictionary) -> void:
	var p := _player()
	var w := _game().get("world") as VoxelWorld
	# Modelos de vista previa solo en sus propias capturas
	if _wolf:
		_wolf.visible = shot.has("wolf")
	if _preview:
		_preview.visible = shot.has("enemy")
	if not shot.has("ui"):
		# Cerrar menús y diálogos que hayan quedado abiertos de capturas anteriores
		var gm := _game().get("game_menu") as GameMenu
		if gm and gm.visible:
			gm.close()
		var dlg: Variant = _game().get("_dialogue")
		if dlg and is_instance_valid(dlg):
			(dlg as DialogueUI).close()
		var hud0 := _game().get("hud") as HUD
		if hud0:
			hud0.set_visible_hud("--hud" in OS.get_cmdline_user_args())
	if shot.has("flag"):
		GameState.set_flag(str(shot["flag"]))
	if shot.has("ui"):
		var g := _game()
		var hud := g.get("hud") as HUD
		if hud:
			hud.set_visible_hud(true)
		var menu := g.get("game_menu") as GameMenu
		if menu.visible:
			menu.close()
		if str(shot["ui"]) == "dialogue":
			var target: NPC = null
			for n in get_tree().get_nodes_in_group("npcs"):
				if (n as NPC).npc_id == "mira":
					target = n
			if target:
				p.teleport(target.global_position + Vector3(0, 0, 0) - target.global_basis.z * -1.6, 0.0)
				var to := target.global_position - p.global_position
				p._yaw = atan2(-to.x, -to.z)
				p._pitch = deg_to_rad(-6.0)
				g.call("open_dialogue", target)
		else:
			if g.get("_dialogue") and is_instance_valid(g.get("_dialogue")):
				(g.get("_dialogue") as DialogueUI).close()
			GameState.quests["huesos_inquietos"] = {"stage": 0, "progress": 1, "done": false}
			GameState.give_item(p, {"id": "book_velmar", "count": 1})
			menu.open(int(shot["tab"]))
		_wait = 8
		return
	if shot.has("dungeon"):
		_game().call("enter_dungeon", str(shot["dungeon"]) if shot["dungeon"] is String else "crypt_velmar", "capture")
		_wait = 0
		_dungeon_wait = true
		return
	if shot.has("dview"):
		var dg := _game().get("generator") as DungeonGenerator
		if dg == null:
			return
		var room_i := dg.entrance_index
		match str(shot["dview"]):
			"boss":
				room_i = dg.boss_index
			"treasure":
				for i in dg.rooms.size():
					if dg.rooms[i]["role"] == "treasure":
						room_i = i
		var rect: Rect2i = dg.rooms[room_i]["rect"]
		var pos := Vector3(rect.get_center().x + 0.5, 20.05, rect.end.y - 1.0)
		var yaw := 0.0
		if str(shot["dview"]) == "corridor" and not dg.corridor_tiles.is_empty():
			var t: Vector2i = dg.corridor_tiles[dg.corridor_tiles.size() / 2]
			pos = Vector3(t.x + 0.5, 20.05, t.y + 0.5)
			yaw = 90.0
		p.teleport(pos, yaw)
		p._pitch = deg_to_rad(4.0)
		_wait = 12
		return
	if shot.has("pos"):
		var pos: Vector3 = shot["pos"]
		if pos.y < 0.0:
			pos.y = w.generator.height_at(int(pos.x), int(pos.z)) + 1.0
		p.teleport(pos, float(shot["yaw"]))
		p._pitch = deg_to_rad(float(shot["pitch"]))
		GameState.time_of_day = float(shot["time"])
		p.viewmodel.visible = true
		_wait = 12
	elif shot.has("vm"):
		p.teleport(Vector3(2.5, 37.0, 3.5), -60.0)
		p._pitch = deg_to_rad(-12.0)
		GameState.time_of_day = 14.0
		var vm := p.viewmodel
		var anim_name: String = shot["vm"]
		var kind := anim_name.split("_")[0]
		if kind != "interact" and kind != vm.kind:
			var wid := kind if kind != "sword" else "sword"
			vm.set_weapon(kind, wid, "shield" if kind == "sword" else "")
		vm.debug_pose(anim_name, float(shot["t"]))
		_wait = 6
	elif shot.has("wolf"):
		p.teleport(Vector3(2.5, 37.0, 3.5), -90.0)
		p._pitch = deg_to_rad(-10.0)
		p.viewmodel.visible = false
		GameState.time_of_day = 13.0
		_ensure_wolf(int(shot["variant"]))
		_wolf.global_position = p.global_position + Vector3(2.4, 0, 0.2)
		_wolf.rotation.y = deg_to_rad(-25.0)
		_wolf_anim.play(str(shot["wolf"]), 0.0)
		_wolf_anim.seek(float(shot["t"]), true)
		_wolf_anim.pause()
		_wait = 6
	elif shot.has("armor"):
		p.teleport(Vector3(2.5, 37.0, 3.5), -60.0)
		p._pitch = deg_to_rad(-12.0)
		GameState.time_of_day = 14.0
		var o: Array = shot["armor"]
		p.viewmodel.visible = true
		p.viewmodel.set_appearance(str(o[0]), str(o[1]))
		p.viewmodel.set_weapon("sword", "sword", str(o[2]))
		# Preparación del tajo: brazo levantado (se ven manga, brazal y guante)
		p.viewmodel.debug_pose("sword_attack_1", 0.16)
		_wait = 6
	elif shot.has("bandits"):
		p.teleport(Vector3(2.5, 37.0, 3.5), -90.0)
		p._pitch = deg_to_rad(-4.0)
		p.viewmodel.visible = false
		GameState.time_of_day = 13.0
		_ensure_bandits()
		for i in _bandits.size():
			var b := _bandits[i]
			b.visible = true
			b.global_position = p.global_position + Vector3(3.0, 0, -2.4 + i * 1.2)
			b.rotation.y = deg_to_rad(90.0 + (180.0 if bool(shot.get("back", false)) else 0.0))
			var ap := b.get_node("AnimationPlayer") as AnimationPlayer
			ap.play("captive" if i == 4 else str(shot["bandits"]), 0.0)
			ap.seek(float(shot["t"]) if i != 4 else 1.0, true)
			ap.pause()
		_wait = 6
	elif shot.has("enemy"):
		p.teleport(Vector3(2.5, 37.0, 3.5), -90.0)
		p._pitch = deg_to_rad(-6.0)
		p.viewmodel.visible = false
		GameState.time_of_day = 13.0
		_ensure_preview()
		_preview.global_position = p.global_position + Vector3(1.9, 0, 0.35)
		_preview.rotation.y = deg_to_rad(90.0 + 35.0)
		_preview_anim.play(str(shot["enemy"]), 0.0)
		_preview_anim.seek(float(shot["t"]), true)
		_preview_anim.pause()
		_wait = 6


func _ensure_preview() -> void:
	if _preview:
		return
	_preview = Node3D.new()
	_game().add_child(_preview)
	var rig := Rig.humanoid()
	var sk := rig.create_skeleton()
	_preview.add_child(sk)
	var model := CharacterModels.skeleton_warrior(0)
	var mi := MeshInstance3D.new()
	mi.mesh = model.build_skinned_mesh(rig.bone_names(), ModelLibrary.model_material())
	mi.skin = rig.create_skin()
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	var wa := BoneAttachment3D.new()
	wa.bone_name = "hand.R"
	sk.add_child(wa)
	var wm := MeshInstance3D.new()
	wm.mesh = ModelLibrary.weapon_mesh("rusty_sword", false)
	wm.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02))
	wa.add_child(wm)
	var sa := BoneAttachment3D.new()
	sa.bone_name = "forearm.L"
	sk.add_child(sa)
	var sm := MeshInstance3D.new()
	sm.mesh = ModelLibrary.weapon_mesh("shield", false)
	sm.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.09, -0.14, 0.0))
	sa.add_child(sm)
	_preview_anim = AnimationPlayer.new()
	_preview.add_child(_preview_anim)
	_preview_anim.root_node = NodePath("..")
	_preview_anim.add_animation_library("", HumanoidAnims.build_library("warrior"))


## Los cuatro bandidos (salteador, matón, arquera y jefe) y Lina, en fila.
func _ensure_bandits() -> void:
	if not _bandits.is_empty():
		return
	var weapons := [["sword", "shield"], ["axe", ""], ["bow", ""], ["mace", "shield_iron"]]
	for v in 5:
		var root := Node3D.new()
		_game().add_child(root)
		var rig := Rig.humanoid()
		var sk := rig.create_skeleton()
		root.add_child(sk)
		var model: VoxelModel = CharacterModels.bandit(v, 100 + v * 7) if v < 4 else CharacterModels.human(NpcDB.get_npc("lina")["look"], hash("lina"))
		var mi := MeshInstance3D.new()
		mi.mesh = model.build_skinned_mesh(rig.bone_names(), ModelLibrary.model_material())
		mi.skin = rig.create_skin()
		sk.add_child(mi)
		mi.skeleton = NodePath("..")
		if v < 4:
			var ranged := v == 2
			var wa := BoneAttachment3D.new()
			wa.bone_name = "hand.L" if ranged else "hand.R"
			sk.add_child(wa)
			var wm := MeshInstance3D.new()
			wm.mesh = ModelLibrary.weapon_mesh(str(weapons[v][0]), false)
			if ranged:
				wm.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.07, -0.02))
			else:
				wm.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(-0.01, -0.07, -0.02))
			wa.add_child(wm)
			if str(weapons[v][1]) != "":
				var sa := BoneAttachment3D.new()
				sa.bone_name = "forearm.L"
				sk.add_child(sa)
				var sm := MeshInstance3D.new()
				sm.mesh = ModelLibrary.weapon_mesh(str(weapons[v][1]), false)
				sm.transform = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-0.09, -0.14, 0.0))
				sa.add_child(sm)
			if v == 1:
				root.scale = Vector3.ONE * 1.06
			elif v == 3:
				root.scale = Vector3.ONE * 1.08
		var ap := AnimationPlayer.new()
		ap.name = "AnimationPlayer"
		root.add_child(ap)
		ap.root_node = NodePath("..")
		ap.add_animation_library("", HumanoidAnims.build_library("warrior" if v < 4 else "civilian"))
		_bandits.append(root)


func _ensure_wolf(variant: int) -> void:
	if _wolf and _wolf_variant == variant:
		return
	if _wolf:
		_wolf.queue_free()
	_wolf_variant = variant
	_wolf = Node3D.new()
	_game().add_child(_wolf)
	var rig := Rig.quadruped()
	var sk := rig.create_skeleton()
	_wolf.add_child(sk)
	if variant == 3:
		sk.scale = Vector3.ONE * 1.35
	var mi := MeshInstance3D.new()
	mi.mesh = CharacterModels.wolf(variant).build_skinned_mesh(rig.bone_names(), ModelLibrary.model_material())
	mi.skin = rig.create_skin()
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	_wolf_anim = AnimationPlayer.new()
	_wolf.add_child(_wolf_anim)
	_wolf_anim.root_node = NodePath("..")
	_wolf_anim.add_animation_library("", QuadrupedAnims.build_library())


func _snap() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s.png" % _cur["name"])
	img.save_png(path)
	print("[CAPTURE] ", path)
