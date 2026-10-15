class_name ArmIK
extends SkeletonModifier3D
## IK de dos huesos para los brazos en primera persona. Cada fotograma coloca
## brazo y antebrazo para que la muñeca alcance el objetivo animado (manos) y
## orienta la mano igual que el objetivo. Se ejecuta después de la animación.

var target_r: Node3D
var target_l: Node3D
var pole_r := Vector3(0.9, -0.6, 0.5)
var pole_l := Vector3(-0.9, -0.6, 0.5)
var len_upper := 0.27
var len_fore := 0.26

var _bones := {}


func setup(skeleton: Skeleton3D, r: Node3D, l: Node3D) -> void:
	target_r = r
	target_l = l
	for side: String in ["R", "L"]:
		_bones[side] = [skeleton.find_bone("upper_arm." + side), skeleton.find_bone("forearm." + side),
				skeleton.find_bone("hand." + side)]


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or target_r == null or target_l == null or _bones.is_empty():
		return
	var inv := sk.global_transform.affine_inverse()
	_solve(sk, "R", inv * target_r.global_transform, pole_r)
	_solve(sk, "L", inv * target_l.global_transform, pole_l)


func _solve(sk: Skeleton3D, side: String, target: Transform3D, pole: Vector3) -> void:
	var ids: Array = _bones[side]
	var ua: int = ids[0]
	var fa: int = ids[1]
	var hd: int = ids[2]
	if ua < 0 or fa < 0 or hd < 0:
		return
	var shoulder := sk.get_bone_global_rest(ua).origin
	var to := target.origin - shoulder
	var reach := len_upper + len_fore - 0.002
	var dist := clampf(to.length(), 0.06, reach)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	var cos_a := clampf((len_upper * len_upper + dist * dist - len_fore * len_fore) / (2.0 * len_upper * dist), -1.0, 1.0)
	var a := acos(cos_a)
	var pole_dir := pole - dir * pole.dot(dir)
	if pole_dir.length() < 0.0001:
		pole_dir = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	pole_dir = pole_dir.normalized()
	var elbow := shoulder + (dir * cos(a) + pole_dir * sin(a)) * len_upper
	var wrist := shoulder + dir * dist
	var plane_n := (elbow - shoulder).cross(wrist - elbow)
	if plane_n.length() < 0.00001:
		plane_n = dir.cross(pole_dir)
	plane_n = plane_n.normalized()
	sk.set_bone_global_pose(ua, Transform3D(_basis_down(elbow - shoulder, plane_n), shoulder))
	sk.set_bone_global_pose(fa, Transform3D(_basis_down(wrist - elbow, plane_n), elbow))
	sk.set_bone_global_pose(hd, Transform3D(target.basis.orthonormalized(), wrist))


## Base cuyo eje -Y apunta en la dirección `v` (los huesos cuelgan en reposo).
static func _basis_down(v: Vector3, side_axis: Vector3) -> Basis:
	var y := -v.normalized()
	var x := side_axis - y * side_axis.dot(y)
	if x.length() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
