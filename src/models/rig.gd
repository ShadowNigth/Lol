class_name Rig
extends RefCounted
## Definición de esqueleto: huesos con padre y posición de reposo global
## (rotaciones de reposo nulas, por lo que las rotaciones animadas se expresan
## directamente en los ejes del modelo: +X derecha, +Y arriba, -Z delante).

var bones: Array[Dictionary] = []


func add(bone_name: String, parent: String, global_pos: Vector3) -> void:
	bones.append({"name": bone_name, "parent": parent, "pos": global_pos})


func bone_names() -> PackedStringArray:
	var out := PackedStringArray()
	for b in bones:
		out.append(str(b["name"]))
	return out


func rest_position(bone_name: String) -> Vector3:
	for b in bones:
		if b["name"] == bone_name:
			return b["pos"]
	return Vector3.ZERO


## Posición de reposo local (relativa al padre), útil para pistas de posición.
func local_rest(bone_name: String) -> Vector3:
	for b in bones:
		if b["name"] == bone_name:
			var parent := str(b["parent"])
			return (b["pos"] as Vector3) - (rest_position(parent) if parent != "" else Vector3.ZERO)
	return Vector3.ZERO


func create_skeleton() -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	for b in bones:
		sk.add_bone(str(b["name"]))
	for b in bones:
		var i := sk.find_bone(str(b["name"]))
		var parent := str(b["parent"])
		var pos: Vector3 = b["pos"]
		var local := pos
		if parent != "":
			sk.set_bone_parent(i, sk.find_bone(parent))
			local = pos - rest_position(parent)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
	sk.reset_bone_poses()
	return sk


func create_skin() -> Skin:
	var skin := Skin.new()
	for b in bones:
		skin.add_named_bind(str(b["name"]), Transform3D(Basis.IDENTITY, b["pos"]).affine_inverse())
	return skin


## Esqueleto humanoide estándar (1,8 m). `scale` permite variantes.
static func humanoid(scale: float = 1.0) -> Rig:
	var r := Rig.new()
	var s := scale
	r.add("root", "", Vector3.ZERO)
	r.add("hips", "root", Vector3(0, 0.95, 0) * s)
	r.add("spine", "hips", Vector3(0, 1.08, 0) * s)
	r.add("chest", "spine", Vector3(0, 1.26, 0) * s)
	r.add("neck", "chest", Vector3(0, 1.50, 0) * s)
	r.add("head", "neck", Vector3(0, 1.56, 0) * s)
	for side: Array in [["R", 1.0], ["L", -1.0]]:
		var n: String = side[0]
		var sx: float = side[1]
		r.add("upper_arm." + n, "chest", Vector3(0.23 * sx, 1.44, 0) * s)
		r.add("forearm." + n, "upper_arm." + n, Vector3(0.25 * sx, 1.15, 0) * s)
		r.add("hand." + n, "forearm." + n, Vector3(0.26 * sx, 0.90, 0) * s)
		r.add("thigh." + n, "hips", Vector3(0.11 * sx, 0.92, 0) * s)
		r.add("shin." + n, "thigh." + n, Vector3(0.11 * sx, 0.50, 0) * s)
		r.add("foot." + n, "shin." + n, Vector3(0.11 * sx, 0.09, 0) * s)
	return r


## Esqueleto cuadrúpedo (lobo, ~1,3 m de largo y 0,75 m a la cruz), mirando a -Z.
## Patas: *_up (hombro/muslo), *_low (antebrazo/caña) y *_paw; f = delanteras, b = traseras.
static func quadruped(scale: float = 1.0) -> Rig:
	var r := Rig.new()
	var s := scale
	r.add("root", "", Vector3.ZERO)
	r.add("hips", "root", Vector3(0, 0.70, 0.36) * s)
	r.add("spine", "hips", Vector3(0, 0.72, 0.04) * s)
	r.add("chest", "spine", Vector3(0, 0.74, -0.28) * s)
	r.add("neck", "chest", Vector3(0, 0.84, -0.46) * s)
	r.add("head", "neck", Vector3(0, 0.92, -0.6) * s)
	r.add("jaw", "head", Vector3(0, 0.86, -0.66) * s)
	r.add("tail.1", "hips", Vector3(0, 0.74, 0.52) * s)
	r.add("tail.2", "tail.1", Vector3(0, 0.62, 0.78) * s)
	for side: Array in [["R", 1.0], ["L", -1.0]]:
		var n: String = side[0]
		var sx: float = side[1]
		r.add("f_up." + n, "chest", Vector3(0.13 * sx, 0.66, -0.34) * s)
		r.add("f_low." + n, "f_up." + n, Vector3(0.13 * sx, 0.38, -0.36) * s)
		r.add("f_paw." + n, "f_low." + n, Vector3(0.13 * sx, 0.07, -0.36) * s)
		r.add("b_up." + n, "hips", Vector3(0.13 * sx, 0.66, 0.38) * s)
		r.add("b_low." + n, "b_up." + n, Vector3(0.13 * sx, 0.36, 0.44) * s)
		r.add("b_paw." + n, "b_low." + n, Vector3(0.13 * sx, 0.07, 0.4) * s)
	return r
