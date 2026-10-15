class_name DayNight
extends Node
## Ciclo de día y noche: mueve el sol/la luna, ajusta colores del cielo, luz
## ambiental, niebla y estrellas. La hora vive en GameState.time_of_day.

signal hour_changed(hour: int)

## Minutos de juego por segundo real.
@export var time_scale: float = 1.0

var sun: DirectionalLight3D
var env: Environment
var sky_material: ShaderMaterial
var fog_end: float = 90.0
var interior: bool = false
var _last_hour: int = -1
var _cloud_offset := Vector2.ZERO

# Colores por elevación solar: [elevación, cénit, horizonte, luz, energía, ambiente]
const KEYS := [
	[-0.35, Color(0.01, 0.015, 0.04), Color(0.04, 0.05, 0.1), Color(0.45, 0.55, 0.85), 0.16, Color(0.11, 0.13, 0.21)],
	[-0.08, Color(0.06, 0.08, 0.2), Color(0.35, 0.22, 0.22), Color(0.6, 0.45, 0.5), 0.14, Color(0.16, 0.16, 0.24)],
	[0.0, Color(0.18, 0.26, 0.5), Color(0.95, 0.55, 0.3), Color(1.0, 0.55, 0.3), 0.35, Color(0.3, 0.27, 0.3)],
	[0.12, Color(0.25, 0.42, 0.75), Color(0.95, 0.78, 0.6), Color(1.0, 0.82, 0.62), 0.85, Color(0.42, 0.44, 0.5)],
	[0.35, Color(0.24, 0.46, 0.85), Color(0.68, 0.8, 0.93), Color(1.0, 0.95, 0.86), 1.25, Color(0.5, 0.56, 0.66)],
	[1.0, Color(0.2, 0.42, 0.85), Color(0.62, 0.77, 0.94), Color(1.0, 0.97, 0.9), 1.35, Color(0.52, 0.58, 0.7)],
]


func setup(sun_light: DirectionalLight3D, environment: Environment, sky_mat: ShaderMaterial) -> void:
	sun = sun_light
	env = environment
	sky_material = sky_mat
	_apply()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	GameState.time_of_day += delta * time_scale / 60.0
	if GameState.time_of_day >= 24.0:
		GameState.time_of_day -= 24.0
		GameState.day += 1
	_cloud_offset += Vector2(1.6, 0.6) * delta
	_apply()
	var hour := int(GameState.time_of_day)
	if hour != _last_hour:
		_last_hour = hour
		hour_changed.emit(hour)


static func sun_vector(t: float) -> Vector3:
	var a := (t - 6.0) / 24.0 * TAU
	var tilt := deg_to_rad(28.0)
	return Vector3(cos(a), sin(a) * cos(tilt), sin(a) * sin(tilt)).normalized()


func _sample(elev: float) -> Array:
	for i in range(KEYS.size() - 1):
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if elev <= float(b[0]):
			var t := clampf((elev - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0)
			return [(a[1] as Color).lerp(b[1], t), (a[2] as Color).lerp(b[2], t), (a[3] as Color).lerp(b[3], t),
					lerpf(float(a[4]), float(b[4]), t), (a[5] as Color).lerp(b[5], t)]
	var last: Array = KEYS[KEYS.size() - 1]
	return [last[1], last[2], last[3], last[4], last[5]]


func _apply() -> void:
	if sun == null or env == null:
		return
	var sv := sun_vector(GameState.time_of_day)
	var elev := sv.y
	var s := _sample(elev)
	var zenith: Color = s[0]
	var horizon: Color = s[1]
	var light_col: Color = s[2]
	var energy: float = s[3]
	var ambient: Color = s[4]
	var is_night := elev < -0.05
	var light_dir := sv if not is_night else -sv
	# La luz direccional apunta en su -Z
	var up := Vector3.UP if absf(light_dir.y) < 0.98 else Vector3.FORWARD
	sun.global_basis = Basis.looking_at(-light_dir, up)
	sun.light_color = light_col
	sun.light_energy = energy if not interior else 0.0
	sun.visible = not interior
	env.ambient_light_color = ambient if not interior else Color(0.09, 0.08, 0.1)
	env.ambient_light_energy = 1.0
	env.fog_light_color = horizon if not interior else Color(0.02, 0.02, 0.03)
	if sky_material:
		sky_material.set_shader_parameter("sky_top", zenith)
		sky_material.set_shader_parameter("sky_horizon", horizon)
		sky_material.set_shader_parameter("ground_color", horizon.darkened(0.55))
		sky_material.set_shader_parameter("sun_dir", sv)
		sky_material.set_shader_parameter("moon_dir", -sv)
		sky_material.set_shader_parameter("sun_color", light_col)
		sky_material.set_shader_parameter("star_amount", clampf(-elev * 4.0, 0.0, 1.0))
		sky_material.set_shader_parameter("cloud_color", Color(1, 1, 1).lerp(light_col, 0.25) * clampf(energy + 0.25, 0.15, 1.1))
		sky_material.set_shader_parameter("cloud_shadow", horizon.lerp(zenith, 0.5).lightened(0.15))
		sky_material.set_shader_parameter("cloud_offset", _cloud_offset)


func hour_string() -> String:
	var t := GameState.time_of_day
	return "%02d:%02d" % [int(t), int(fmod(t, 1.0) * 60.0)]
