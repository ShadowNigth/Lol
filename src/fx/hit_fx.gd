class_name HitFX
extends RefCounted
## Efectos de impacto con partículas voxel (chispas, astillas de hueso,
## sangre, polvo, magia). Se autodestruyen al terminar.

static var _meshes: Dictionary = {}


static func _cube_mesh(color: Color, emissive: bool, size: float) -> BoxMesh:
	var key := "%s|%s|%s" % [color.to_html(), emissive, size]
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	if emissive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	else:
		mat.roughness = 0.9
	m.material = mat
	_meshes[key] = m
	return m


static func spawn(parent: Node, kind: String, pos: Vector3, normal: Vector3 = Vector3.UP, scale: float = 1.0) -> void:
	if parent == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	p.direction = normal if normal.length() > 0.01 else Vector3.UP
	p.gravity = Vector3(0, -9.8, 0)
	var life := 0.5
	match kind:
		"sparks":
			p.mesh = _cube_mesh(Color(1.0, 0.75, 0.3), true, 0.025)
			p.amount = 14
			p.spread = 55.0
			p.initial_velocity_min = 2.5
			p.initial_velocity_max = 6.0
			life = 0.35
			p.color = Color(1, 0.8, 0.4)
		"bone":
			p.mesh = _cube_mesh(Color(0.85, 0.82, 0.72), false, 0.04)
			p.amount = 12
			p.spread = 70.0
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 4.0
			life = 0.8
			p.color = Color(0.9, 0.88, 0.8)
		"blood":
			p.mesh = _cube_mesh(Color(0.55, 0.05, 0.04), false, 0.035)
			p.amount = 16
			p.spread = 60.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.5
			life = 0.7
			p.color = Color(0.6, 0.05, 0.04)
		"dust":
			p.mesh = _cube_mesh(Color(0.6, 0.58, 0.55), false, 0.05)
			p.amount = 10
			p.spread = 80.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, -1.5, 0)
			life = 0.9
			p.color = Color(0.7, 0.68, 0.64)
		"magic":
			p.mesh = _cube_mesh(Color(0.4, 0.7, 1.0), true, 0.03)
			p.amount = 20
			p.spread = 180.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, 0.5, 0)
			life = 0.8
			p.color = Color(0.5, 0.8, 1.0)
		"fire":
			p.mesh = _cube_mesh(Color(1.0, 0.45, 0.1), true, 0.05)
			p.amount = 24
			p.spread = 180.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, 2.0, 0)
			life = 0.6
			p.color = Color(1, 0.5, 0.15)
		"ichor":
			# Icor de araña: verde amarillento y espeso
			p.mesh = _cube_mesh(Color(0.55, 0.62, 0.12), false, 0.035)
			p.amount = 16
			p.spread = 60.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.2
			life = 0.75
			p.color = Color(0.6, 0.68, 0.15)
		"web":
			# Hebras de seda que se esparcen y caen despacio
			p.mesh = _cube_mesh(Color(0.9, 0.9, 0.88), false, 0.04)
			p.amount = 18
			p.spread = 90.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0, -2.0, 0)
			life = 0.9
			p.color = Color(0.92, 0.92, 0.9)
		"heal":
			p.mesh = _cube_mesh(Color(0.5, 1.0, 0.5), true, 0.03)
			p.amount = 18
			p.spread = 30.0
			p.direction = Vector3.UP
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, 0.6, 0)
			life = 1.0
			p.color = Color(0.6, 1, 0.6)
		_:
			p.mesh = _cube_mesh(Color(0.8, 0.8, 0.8), false, 0.04)
			p.amount = 8
	p.lifetime = life
	p.amount = maxi(1, int(p.amount * scale))
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
