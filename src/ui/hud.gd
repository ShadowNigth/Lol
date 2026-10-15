class_name HUD
extends CanvasLayer
## Interfaz en partida: barras de salud/aguante/magia, brújula, punto de mira,
## avisos de interacción, barra del enemigo apuntado, notificaciones, nombre
## de zona, viñeta de daño y panel de depuración (F3).

var player: Player
var day_night: DayNight
var world: VoxelWorld

var _root: Control
var _bars: Control
var _compass: Control
var _crosshair: Control
var _hint: Label
var _target_panel: Control
var _target_name: Label
var _target_bar: ProgressBar
var _notify_box: VBoxContainer
var _location: Label
var _location_t := 0.0
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _damage_flash := 0.0
var _info: Label
var _debug: Label
var _target: Node = null
var _underwater: ColorRect
var _fade: ColorRect


func setup(p: Player, dn: DayNight, w: VoxelWorld) -> void:
	player = p
	day_night = dn
	world = w


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_underwater = ColorRect.new()
	_underwater.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater.color = Color(0.1, 0.3, 0.55, 0.35)
	_underwater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater.visible = false
	_root.add_child(_underwater)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = load("res://shaders/vignette.gdshader")
	_vignette.material = _vignette_mat
	_root.add_child(_vignette)

	_bars = HudBars.new()
	_bars.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bars.position = Vector2(24, -112)
	_bars.custom_minimum_size = Vector2(300, 90)
	_bars.size = Vector2(300, 90)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bars)
	_bars.anchor_top = 1.0
	_bars.anchor_bottom = 1.0
	_bars.offset_top = -110
	_bars.offset_bottom = -20
	_bars.offset_left = 24
	_bars.offset_right = 324

	_compass = HudCompass.new()
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.anchor_left = 0.5
	_compass.anchor_right = 0.5
	_compass.offset_left = -230
	_compass.offset_right = 230
	_compass.offset_top = 14
	_compass.offset_bottom = 46
	_root.add_child(_compass)

	_crosshair = HudCrosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -12
	_crosshair.offset_right = 12
	_crosshair.offset_top = -12
	_crosshair.offset_bottom = 12
	_root.add_child(_crosshair)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 0.5
	_hint.anchor_bottom = 0.5
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.offset_top = 28
	_hint.offset_bottom = 60
	_hint.add_theme_font_size_override("font_size", 19)
	_root.add_child(_hint)

	_target_panel = VBoxContainer.new()
	_target_panel.anchor_left = 0.5
	_target_panel.anchor_right = 0.5
	_target_panel.offset_left = -150
	_target_panel.offset_right = 150
	_target_panel.offset_top = 52
	_target_panel.offset_bottom = 96
	_target_panel.visible = false
	_target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_target_panel)
	_target_name = Label.new()
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_name.add_theme_font_size_override("font_size", 16)
	_target_panel.add_child(_target_name)
	_target_bar = ProgressBar.new()
	_target_bar.custom_minimum_size = Vector2(300, 9)
	_target_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.03, 0.03, 0.8)
	bg.border_color = Color(0.4, 0.3, 0.2)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.72, 0.12, 0.1)
	_target_bar.add_theme_stylebox_override("background", bg)
	_target_bar.add_theme_stylebox_override("fill", fill)
	_target_panel.add_child(_target_bar)

	_notify_box = VBoxContainer.new()
	_notify_box.position = Vector2(20, 62)
	_notify_box.custom_minimum_size = Vector2(440, 0)
	_notify_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notify_box)

	_location = UITheme.title_label("", 34)
	_location.anchor_left = 0.5
	_location.anchor_right = 0.5
	_location.offset_left = -400
	_location.offset_right = 400
	_location.anchor_top = 0.2
	_location.anchor_bottom = 0.2
	_location.modulate.a = 0.0
	_root.add_child(_location)

	_info = Label.new()
	_info.anchor_left = 1.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = -360
	_info.offset_right = -24
	_info.offset_top = -110
	_info.offset_bottom = -20
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_info.add_theme_font_size_override("font_size", 16)
	_root.add_child(_info)

	_debug = Label.new()
	_debug.anchor_left = 1.0
	_debug.anchor_right = 1.0
	_debug.offset_left = -420
	_debug.offset_right = -16
	_debug.offset_top = 60
	_debug.offset_bottom = 260
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.add_theme_font_size_override("font_size", 14)
	_debug.visible = Settings.show_fps
	_root.add_child(_debug)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)

	Events.notify.connect(_on_notify)
	Events.interaction_hint.connect(_on_hint)
	Events.target_changed.connect(_on_target)
	Events.player_damaged.connect(_on_damaged)
	Events.location_entered.connect(_on_location)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		_debug.visible = not _debug.visible


func _process(delta: float) -> void:
	if player == null:
		return
	var s := player.stats
	(_bars as HudBars).set_values(s.health / s.max_health, s.stamina / s.max_stamina, s.mana / s.max_mana,
			"%d/%d" % [ceili(s.health), ceili(s.max_health)])
	(_compass as HudCompass).yaw = player.get_yaw_degrees()
	(_compass as HudCompass).time_text = day_night.hour_string() if day_night else ""
	_damage_flash = maxf(_damage_flash - delta * 1.8, 0.0)
	var low := clampf(1.0 - (s.health / s.max_health) / 0.3, 0.0, 1.0)
	var pulse := low * (0.55 + 0.45 * sin(Time.get_ticks_msec() / 220.0))
	_vignette_mat.set_shader_parameter("intensity", clampf(_damage_flash + pulse * 0.6, 0.0, 1.0))
	_underwater.visible = player.is_underwater()
	if _target and is_instance_valid(_target) and _target.has_method("health_ratio"):
		_target_bar.value = float(_target.call("health_ratio")) * 100.0
		if not bool(_target.call("is_alive")):
			_target_panel.visible = false
	elif _target_panel.visible:
		_target_panel.visible = false
	if _location_t > 0.0:
		_location_t -= delta
		_location.modulate.a = clampf(minf(_location_t, 4.0 - _location_t) * 1.5, 0.0, 1.0) if _location_t < 4.0 else 1.0
	var weapon_name := player.weapon.display_name if player.weapon else "Sin arma"
	if player.weapon and player.weapon.kind == "bow":
		weapon_name += "  (flechas: %d)" % GameState.item_count("arrow")
	var fx := player.stats.active_effect_names()
	var fx_text := ("  [%s]" % ", ".join(fx)) if not fx.is_empty() else ""
	_info.text = "%s\nHechizo [Q/Z]: %s\nOro: %d    Pociones [H]: %d%s" % [weapon_name, player.current_spell_name(), player.gold, GameState.item_count("potion_health"), fx_text]
	if _debug.visible and Engine.get_process_frames() % 10 == 0:
		var p := player.global_position
		var biome := world.generator.biome_name(int(p.x), int(p.z)) if world and world.generator else ""
		_debug.text = "FPS: %d\nPos: %.1f, %.1f, %.1f\nChunk: %d, %d\nBioma: %s\nChunks: %d (pend. %d)\nDibujado: %d llamadas\nSemilla: %d  Día %d" % [
			Engine.get_frames_per_second(), p.x, p.y, p.z, int(floor(p.x / 16.0)), int(floor(p.z / 16.0)), biome,
			world.loaded_chunk_count() if world else 0, world.pending_task_count() if world else 0,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			GameState.world_seed, GameState.day]


func _on_notify(text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
	l.add_theme_font_size_override("font_size", 15)
	match kind:
		"warning", "error":
			l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
		"item":
			l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		"skill", "level":
			l.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		"combat":
			l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		"quest":
			l.add_theme_color_override("font_color", Color(0.7, 1.0, 0.6))
	_notify_box.add_child(l)
	while _notify_box.get_child_count() > 6:
		var old := _notify_box.get_child(0)
		_notify_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _on_hint(text: String) -> void:
	_hint.text = text
	(_crosshair as HudCrosshair).active = text != ""


func _on_target(t: Node) -> void:
	_target = t
	if t and is_instance_valid(t) and t.has_method("display_name"):
		_target_name.text = str(t.call("display_name"))
		_target_panel.visible = true
	else:
		_target_panel.visible = false


func _on_damaged(amount: float, _src: Vector3) -> void:
	_damage_flash = clampf(_damage_flash + amount / 30.0 + 0.25, 0.0, 1.0)


func _on_location(loc_name: String) -> void:
	_location.text = loc_name
	_location_t = 5.0


func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	return tw


func set_visible_hud(v: bool) -> void:
	_root.visible = v


# ---------------------------------------------------------------------------
# Controles dibujados a mano
# ---------------------------------------------------------------------------

class HudBars extends Control:
	var hp := 1.0
	var st := 1.0
	var mp := 1.0
	var hp_text := ""
	var _shown := Vector3.ONE

	func set_values(h: float, s: float, m: float, text: String) -> void:
		hp = clampf(h, 0.0, 1.0)
		st = clampf(s, 0.0, 1.0)
		mp = clampf(m, 0.0, 1.0)
		hp_text = text
		queue_redraw()

	func _process(delta: float) -> void:
		var target := Vector3(hp, st, mp)
		_shown = _shown.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var rows := [[hp, _shown.x, Color(0.75, 0.12, 0.1), Color(0.95, 0.4, 0.3)],
				[st, _shown.y, Color(0.2, 0.6, 0.18), Color(0.5, 0.85, 0.35)],
				[mp, _shown.z, Color(0.15, 0.3, 0.75), Color(0.45, 0.6, 1.0)]]
		var y := 0.0
		var widths := [280.0, 230.0, 200.0]
		var heights := [20.0, 14.0, 14.0]
		for i in 3:
			var r: Array = rows[i]
			var w: float = widths[i]
			var h: float = heights[i]
			var rect := Rect2(0, y, w, h)
			draw_rect(rect.grow(3), Color(0.05, 0.035, 0.025, 0.85))
			draw_rect(rect.grow(3), UITheme.GOLD_DIM, false, 2.0)
			draw_rect(Rect2(0, y, w * float(r[1]), h), Color(1, 1, 1, 0.25))
			draw_rect(Rect2(0, y, w * float(r[0]), h), r[2])
			draw_rect(Rect2(0, y, w * float(r[0]), h * 0.35), (r[3] as Color) * Color(1, 1, 1, 0.55))
			for k in range(1, 10):
				var x := w * k / 10.0
				draw_line(Vector2(x, y), Vector2(x, y + h), Color(0, 0, 0, 0.25), 1.0)
			y += h + 12.0
		var font := get_theme_default_font()
		if font:
			draw_string(font, Vector2(286, 16), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.TEXT)


class HudCompass extends Control:
	var yaw := 0.0
	var time_text := ""
	const LABELS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SO", 270: "O", 315: "NO"}

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.035, 0.025, 0.7))
		draw_rect(Rect2(0, 0, w, h), UITheme.GOLD_DIM, false, 2.0)
		var font := get_theme_default_font()
		# Rumbo: 0 = norte (-Z). yaw de Godot crece hacia la izquierda.
		var heading := fposmod(-yaw, 360.0)
		var px_per_deg := w / 180.0
		for deg in range(0, 360, 15):
			var diff := wrapf(float(deg) - heading, -180.0, 180.0)
			if absf(diff) > 90.0:
				continue
			var x := w * 0.5 + diff * px_per_deg
			if LABELS.has(deg):
				var txt: String = LABELS[deg]
				var col := UITheme.GOLD if txt.length() == 1 else UITheme.TEXT
				if font:
					draw_string(font, Vector2(x - 12, h * 0.68), txt, HORIZONTAL_ALIGNMENT_CENTER, 24, 16 if txt.length() == 1 else 13, col)
			else:
				draw_line(Vector2(x, h * 0.25), Vector2(x, h * 0.55), Color(0.8, 0.75, 0.6, 0.6), 1.0)
		draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, 6), UITheme.GOLD, 2.0)
		draw_line(Vector2(w * 0.5, h - 6), Vector2(w * 0.5, h), UITheme.GOLD, 2.0)
		if font and time_text != "":
			draw_string(font, Vector2(w + 10, h * 0.68), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UITheme.TEXT)


class HudCrosshair extends Control:
	var active := false

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 2.0 if not active else 4.0
		draw_circle(c, r + 1.2, Color(0, 0, 0, 0.6))
		draw_circle(c, r, Color(1, 0.96, 0.85, 0.9) if not active else UITheme.GOLD)
