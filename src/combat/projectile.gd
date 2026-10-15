class_name Projectile
extends Node3D
## Proyectil físico (flecha, bola de fuego, rayo de escarcha). Avanza con su
## velocidad (y gravedad en las flechas) y comprueba impactos con un rayo entre
## la posición anterior y la nueva; las flechas se clavan en el escenario.

var kind := "arrow"            # arrow, fireball, frost
var velocity := Vector3.ZERO
var damage := 10.0
var shooter: Node = null
var _life := 6.0
var _stuck := false
var _mesh: Node3D
var _light: OmniLight3D

const MASK := 1 | 2 | 4


static func spawn(parent: Node, k: String, from: Vector3, vel: Vector3, dmg: float, owner_node: Node) -> Projectile:
	var p := Projectile.new()
	p.kind = k
	p.velocity = vel
	p.damage = dmg
	p.shooter = owner_node
	parent.add_child(p)
	p.global_position = from
	p._orient()
	return p


func _ready() -> void:
	match kind:
		"arrow":
			var mi := MeshInstance3D.new()
			mi.mesh = ModelLibrary.arrow_mesh()
			_mesh = mi
			add_child(mi)
		_:
			var col := Color(1.0, 0.5, 0.15) if kind == "fireball" else Color(0.5, 0.8, 1.0)
			var sph := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.32
			sm.radial_segments = 8
			sm.rings = 4
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = col
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 4.0
			sm.material = mat
			sph.mesh = sm
			_mesh = sph
			add_child(sph)
			_light = OmniLight3D.new()
			_light.light_color = col
			_light.omni_range = 5.0
			_light.light_energy = 1.6
			add_child(_light)
			var trail := CPUParticles3D.new()
			trail.amount = 24
			trail.lifetime = 0.4
			trail.local_coords = false
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * 0.06
			var tm := StandardMaterial3D.new()
			tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			tm.albedo_color = col
			bm.material = tm
			trail.mesh = bm
			trail.gravity = Vector3(0, 0.5, 0)
			trail.initial_velocity_max = 0.4
			trail.spread = 180.0
			add_child(trail)


func _orient() -> void:
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	if kind == "arrow":
		velocity.y -= 9.8 * delta
	var from := global_position
	var to := from + velocity * delta
	var exclude: Array[RID] = []
	if shooter is CollisionObject3D:
		exclude.append((shooter as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		_orient()
		return
	_on_hit(hit)


func _on_hit(hit: Dictionary) -> void:
	var col := hit["collider"] as Node
	var pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var info := {"attacker": shooter, "position": pos, "normal": normal, "direction": velocity.normalized(),
			"damage_type": "pierce" if kind == "arrow" else ("fire" if kind == "fireball" else "frost"), "stagger": 0.8,
			"blockable": kind == "arrow", "ranged": true}
	if col is Player:
		(col as Player).take_hit(damage, info)
		_apply_status(col)
	elif col and col.has_method("take_hit"):
		col.call("take_hit", damage, info)
		_apply_status(col)
	if kind == "arrow":
		Audio.play_3d("arrow_hit", pos, -2.0)
		if col == null or not col.has_method("take_hit"):
			# Se clava en el escenario
			_stuck = true
			global_position = pos - velocity.normalized() * 0.15
			_life = 12.0
			HitFX.spawn(get_tree().current_scene, "dust", pos, normal, 0.4)
			return
		queue_free()
	else:
		Audio.play_3d("explosion" if kind == "fireball" else "frost", pos, 0.0)
		HitFX.spawn(get_tree().current_scene, "fire" if kind == "fireball" else "magic", pos, normal, 1.5)
		if kind == "fireball":
			# Daño de área reducido alrededor del impacto
			for n in get_tree().get_nodes_in_group("enemies"):
				var e := n as Node3D
				if e and e != col and e.global_position.distance_to(pos) < 2.5 and e.has_method("take_hit") and bool(e.call("is_alive")):
					e.call("take_hit", damage * 0.5, info)
		queue_free()


func _apply_status(target: Node) -> void:
	var stats: Stats = target.get("stats") if "stats" in target else null
	if stats == null:
		return
	match kind:
		"fireball":
			stats.add_effect("burn", 4.0, 4.0)
		"frost":
			stats.add_effect("frost", 4.0, 0.5)
