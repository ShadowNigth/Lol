extends Node
## Herramienta de capturas para revisión visual automática. Inicia una partida
## con semilla fija, recorre puntos de vista y fotografía poses concretas de
## las animaciones (primera persona y esqueleto).
## Uso (con un renderizador real, p. ej. el binario de pruebas offscreen):
##   godot --path . res://tools/dev/capture.tscn -- --out=/tmp/caps [--set=views,vm,enemy]

var _out := "/tmp/caps"
var _sets: PackedStringArray = ["views", "vm", "enemy"]
var _queue: Array[Dictionary] = []
var _wait := 0
var _cur: Dictionary = {}
var _started := false
var _preview: Node3D
var _preview_anim: AnimationPlayer


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--set="):
			_sets = a.substr(6).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_begin")


func _begin() -> void:
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Audio.wait_until_ready()
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
			var hud := g.get("hud") as HUD
			if hud:
				hud.set_visible_hud("--hud" in OS.get_cmdline_user_args())
		return
	if _wait > 0:
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
	if shot.has("pos"):
		var pos: Vector3 = shot["pos"]
		if pos.y < 0.0:
			pos.y = w.generator.height_at(int(pos.x), int(pos.z)) + 1.0
		p.teleport(pos, float(shot["yaw"]))
		p._pitch = deg_to_rad(float(shot["pitch"]))
		GameState.time_of_day = float(shot["time"])
		p.viewmodel.visible = true
		_wait = 90
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


func _snap() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s.png" % _cur["name"])
	img.save_png(path)
	print("[CAPTURE] ", path)
