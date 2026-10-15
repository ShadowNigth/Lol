extends Node
## Configuración persistente del juego (gráficos, audio, controles).
##
## Se guarda en user://settings.cfg. También registra el mapa de entrada por
## defecto (teclado/ratón y mando) para no depender del editor.

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

# --- Valores por defecto -----------------------------------------------------
var mouse_sensitivity: float = 0.12        # grados por píxel
var invert_y: bool = false
var fov: float = 75.0
var view_distance: int = 6                 # radio en chunks (16 m)
var shadow_quality: int = 2                # 0 = sin sombras, 1 = bajas, 2 = medias, 3 = altas
var msaa: int = 1                          # 0 = no, 1 = 2x, 2 = 4x
var fullscreen: bool = false
var vsync: bool = true
var render_scale: float = 1.0              # 0.5 - 1.0
var master_volume: float = 0.9
var sfx_volume: float = 1.0
var music_volume: float = 0.6
var show_fps: bool = false
var head_bob: bool = true

# Acciones -> eventos por defecto. Cada entrada: [tipo, código]
# tipo: "key" (keycode físico), "mouse" (botón), "joy_button", "joy_axis" ([eje, signo])
const DEFAULT_BINDINGS := {
	"move_forward": [["key", KEY_W], ["joy_axis", [JOY_AXIS_LEFT_Y, -1.0]]],
	"move_back": [["key", KEY_S], ["joy_axis", [JOY_AXIS_LEFT_Y, 1.0]]],
	"move_left": [["key", KEY_A], ["joy_axis", [JOY_AXIS_LEFT_X, -1.0]]],
	"move_right": [["key", KEY_D], ["joy_axis", [JOY_AXIS_LEFT_X, 1.0]]],
	"look_up": [["joy_axis", [JOY_AXIS_RIGHT_Y, -1.0]]],
	"look_down": [["joy_axis", [JOY_AXIS_RIGHT_Y, 1.0]]],
	"look_left": [["joy_axis", [JOY_AXIS_RIGHT_X, -1.0]]],
	"look_right": [["joy_axis", [JOY_AXIS_RIGHT_X, 1.0]]],
	"jump": [["key", KEY_SPACE], ["joy_button", JOY_BUTTON_A]],
	"sprint": [["key", KEY_SHIFT], ["joy_button", JOY_BUTTON_LEFT_STICK]],
	"crouch": [["key", KEY_CTRL], ["key", KEY_C], ["joy_button", JOY_BUTTON_B]],
	"dodge": [["key", KEY_ALT], ["key", KEY_V], ["joy_button", JOY_BUTTON_RIGHT_STICK]],
	"attack": [["mouse", MOUSE_BUTTON_LEFT], ["joy_axis", [JOY_AXIS_TRIGGER_RIGHT, 1.0]]],
	"block": [["mouse", MOUSE_BUTTON_RIGHT], ["joy_axis", [JOY_AXIS_TRIGGER_LEFT, 1.0]]],
	"cast_spell": [["key", KEY_Q], ["joy_button", JOY_BUTTON_LEFT_SHOULDER]],
	"spell_next": [["key", KEY_Z], ["joy_button", JOY_BUTTON_DPAD_RIGHT]],
	"interact": [["key", KEY_E], ["joy_button", JOY_BUTTON_X]],
	"weapon_next": [["mouse", MOUSE_BUTTON_WHEEL_DOWN], ["joy_button", JOY_BUTTON_RIGHT_SHOULDER]],
	"weapon_prev": [["mouse", MOUSE_BUTTON_WHEEL_UP]],
	"weapon_1": [["key", KEY_1]],
	"weapon_2": [["key", KEY_2]],
	"weapon_3": [["key", KEY_3]],
	"weapon_4": [["key", KEY_4]],
	"weapon_5": [["key", KEY_5]],
	"sheathe": [["key", KEY_R], ["joy_button", JOY_BUTTON_Y]],
	"use_potion": [["key", KEY_H], ["joy_button", JOY_BUTTON_DPAD_UP]],
	"inventory": [["key", KEY_I], ["key", KEY_TAB], ["joy_button", JOY_BUTTON_BACK]],
	"journal": [["key", KEY_J]],
	"map": [["key", KEY_M]],
	"character": [["key", KEY_K]],
	"pause": [["key", KEY_ESCAPE], ["joy_button", JOY_BUTTON_START]],
	"quick_save": [["key", KEY_F5]],
	"quick_load": [["key", KEY_F9]],
	"toggle_debug": [["key", KEY_F3]],
	"screenshot": [["key", KEY_F12]],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input_actions()
	load_settings()
	apply_all()


func _register_input_actions() -> void:
	for action: String in DEFAULT_BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for binding: Array in DEFAULT_BINDINGS[action]:
			var ev := _make_event(binding)
			if ev:
				InputMap.action_add_event(action, ev)


func _make_event(binding: Array) -> InputEvent:
	var kind: String = binding[0]
	match kind:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = binding[1] as Key
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = binding[1] as MouseButton
			return m
		"joy_button":
			var j := InputEventJoypadButton.new()
			j.button_index = binding[1] as JoyButton
			return j
		"joy_axis":
			var a := InputEventJoypadMotion.new()
			var data: Array = binding[1]
			a.axis = data[0] as JoyAxis
			a.axis_value = data[1]
			return a
	return null


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	mouse_sensitivity = clampf(float(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)), 0.01, 1.0)
	invert_y = bool(cfg.get_value("controls", "invert_y", invert_y))
	fov = clampf(float(cfg.get_value("video", "fov", fov)), 55.0, 100.0)
	view_distance = clampi(int(cfg.get_value("video", "view_distance", view_distance)), 3, 12)
	shadow_quality = clampi(int(cfg.get_value("video", "shadow_quality", shadow_quality)), 0, 3)
	msaa = clampi(int(cfg.get_value("video", "msaa", msaa)), 0, 2)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("video", "vsync", vsync))
	render_scale = clampf(float(cfg.get_value("video", "render_scale", render_scale)), 0.5, 1.0)
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	head_bob = bool(cfg.get_value("video", "head_bob", head_bob))
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("video", "view_distance", view_distance)
	cfg.set_value("video", "shadow_quality", shadow_quality)
	cfg.set_value("video", "msaa", msaa)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "head_bob", head_bob)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("No se pudo guardar la configuración (%s)." % error_string(err))


## Aplica todas las opciones que dependen del motor.
func apply_all() -> void:
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	if vp:
		match msaa:
			0:
				vp.msaa_3d = Viewport.MSAA_DISABLED
			1:
				vp.msaa_3d = Viewport.MSAA_2X
			_:
				vp.msaa_3d = Viewport.MSAA_4X
		vp.scaling_3d_scale = render_scale
	_apply_audio()
	settings_changed.emit()


func _apply_audio() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(master_idx, master_volume <= 0.001)
	for bus_name: String in ["SFX", "Music"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var v := sfx_volume if bus_name == "SFX" else music_volume
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)


## Tamaño del mapa de sombras y distancia según la calidad elegida.
func shadow_settings() -> Dictionary:
	match shadow_quality:
		0:
			return {"enabled": false, "distance": 0.0, "splits": 1}
		1:
			return {"enabled": true, "distance": 45.0, "splits": 1}
		2:
			return {"enabled": true, "distance": 70.0, "splits": 2}
		_:
			return {"enabled": true, "distance": 110.0, "splits": 4}
