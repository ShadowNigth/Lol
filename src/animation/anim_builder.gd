class_name AnimBuilder
extends RefCounted
## Construye recursos Animation a partir de fotogramas clave descritos en
## datos: {"hueso": [[tiempo, Vector3(grados)], ...]}. Las rotaciones usan
## interpolación cúbica para transiciones suaves.

static func rot(deg: Vector3) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)))


## rot_tracks: ruta -> [[t, Vector3 grados], ...]
## pos_tracks: ruta -> [[t, Vector3 posición], ...]
## Las rutas sin ":" se tratan como huesos de `skeleton_path`.
static func make(length: float, loop: bool, rot_tracks: Dictionary, pos_tracks: Dictionary = {},
		skeleton_path: String = "Skeleton3D", cubic: bool = true) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for key: String in rot_tracks:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath(_path(key, skeleton_path)))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC if cubic else Animation.INTERPOLATION_LINEAR)
		for k: Array in rot_tracks[key]:
			a.rotation_track_insert_key(t, float(k[0]), rot(k[1]))
	for key: String in pos_tracks:
		var t2 := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(t2, NodePath(_path(key, skeleton_path)))
		a.track_set_interpolation_type(t2, Animation.INTERPOLATION_CUBIC if cubic else Animation.INTERPOLATION_LINEAR)
		for k: Array in pos_tracks[key]:
			a.position_track_insert_key(t2, float(k[0]), k[1])
	return a


static func _path(key: String, skeleton_path: String) -> String:
	if key.begins_with("@"):
		return key.substr(1)
	return "%s:%s" % [skeleton_path, key]
