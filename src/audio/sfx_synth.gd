class_name SfxSynth
extends RefCounted
## Sintetizador de efectos de sonido procedurales.
##
## Todos los sonidos del juego se generan al arrancar a partir de ruido,
## osciladores y filtros simples (no hay archivos de audio externos). Así el
## proyecto no depende de recursos con licencias de terceros.

const RATE := 22050

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1337) -> void:
	_rng.seed = seed_value


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

static func to_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


static func _normalize(b: PackedFloat32Array, peak: float = 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k
	return b


## Envolvente de ataque/decaimiento exponencial.
static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	return exp(-(t - attack) / maxf(decay, 0.0001))


## Suaviza principio y final para evitar chasquidos.
static func _fade_edges(b: PackedFloat32Array, fade_s: float = 0.004) -> void:
	var n := b.size()
	var f := mini(int(fade_s * RATE), n / 2)
	for i in f:
		var k := float(i) / float(f)
		b[i] *= k
		b[n - 1 - i] *= k


func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, gain: float) -> void:
	for i in src.size():
		var j := i + offset
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


## Ruido filtrado con un filtro de estado variable cuya frecuencia sigue una curva.
## mode: 0 = paso bajo, 1 = paso banda, 2 = paso alto.
func _filtered_noise(seconds: float, f_start: float, f_mid: float, f_end: float, q: float, mode: int,
		attack: float, decay: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var low := 0.0
	var band := 0.0
	var n := b.size()
	var damp := 1.0 / q
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / float(n)
		var fc: float
		if p < 0.5:
			fc = lerpf(f_start, f_mid, p * 2.0)
		else:
			fc = lerpf(f_mid, f_end, (p - 0.5) * 2.0)
		var f := 2.0 * sin(PI * minf(fc, RATE * 0.16) / RATE)
		var x := _rng.randf_range(-1.0, 1.0)
		low += f * band
		var high := x - low - damp * band
		band += f * high
		var y: float
		match mode:
			0:
				y = low
			1:
				y = band
			_:
				y = high
		b[i] = y * _env(t, attack, decay)
	return b


## Suma de parciales inarmónicos con decaimiento (sonidos metálicos).
func _partials(seconds: float, freqs: Array, decays: Array, gains: Array) -> PackedFloat32Array:
	var b := _buf(seconds)
	var n := b.size()
	for k in freqs.size():
		var fr: float = freqs[k] * _rng.randf_range(0.985, 1.015)
		var dc: float = decays[k]
		var g: float = gains[k]
		var ph := _rng.randf() * TAU
		for i in n:
			var t := float(i) / RATE
			b[i] += sin(ph + TAU * fr * t) * g * exp(-t / dc)
	return b


## Seno con barrido de frecuencia (golpes graves).
func _thump(seconds: float, f0: float, f1: float, decay: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ph := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, minf(t / seconds, 1.0))
		ph += TAU * f / RATE
		b[i] = sin(ph) * _env(t, 0.002, decay)
	return b


## Cuerda pulsada (Karplus-Strong).
func _pluck(seconds: float, freq: float, damping: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var period := maxi(int(RATE / freq), 2)
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = _rng.randf_range(-1.0, 1.0)
	var idx := 0
	for i in b.size():
		var nxt := (idx + 1) % period
		var v := (ring[idx] + ring[nxt]) * 0.5 * damping
		b[i] = ring[idx]
		ring[idx] = v
		idx = nxt
	return b


## Vocal sintética simple (tren de pulsos + formantes) para gruñidos.
func _vocal(seconds: float, f0_start: float, f0_end: float, formants: Array, breath: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var n := b.size()
	var ph := 0.0
	var lows: Array[float] = []
	var bands: Array[float] = []
	for _f in formants:
		lows.append(0.0)
		bands.append(0.0)
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / float(n)
		var f0 := lerpf(f0_start, f0_end, p)
		ph += f0 / RATE
		var src := (fmod(ph, 1.0) * 2.0 - 1.0) * 0.6 + _rng.randf_range(-1.0, 1.0) * breath
		var out := 0.0
		for k in formants.size():
			var fc: float = formants[k]
			var f := 2.0 * sin(PI * fc / RATE)
			lows[k] += f * bands[k]
			var high := src - lows[k] - 0.25 * bands[k]
			bands[k] += f * high
			out += bands[k] / float(k + 1)
		var env := sin(PI * minf(p * 1.15, 1.0))
		b[i] = out * env
	return b


# ---------------------------------------------------------------------------
# Biblioteca de sonidos
# ---------------------------------------------------------------------------

func build_library() -> Dictionary:
	var lib := {}
	lib["swing"] = to_stream(_normalize(_swing(0.30, 500.0, 1900.0, 700.0), 0.7))
	lib["swing_fast"] = to_stream(_normalize(_swing(0.20, 800.0, 2600.0, 1100.0), 0.6))
	lib["swing_heavy"] = to_stream(_normalize(_swing(0.45, 260.0, 1000.0, 380.0), 0.8))
	lib["hit_flesh"] = to_stream(_normalize(_hit_flesh(), 0.9))
	lib["hit_bone"] = to_stream(_normalize(_hit_bone(), 0.9))
	lib["hit_metal"] = to_stream(_normalize(_hit_metal(0.7, 1.0), 0.8))
	lib["block"] = to_stream(_normalize(_block(), 0.85))
	lib["hit_wall"] = to_stream(_normalize(_hit_wall(), 0.8))
	lib["hit_wood"] = to_stream(_normalize(_knock(0.25, [180.0, 420.0, 760.0]), 0.8))
	lib["step_grass"] = to_stream(_normalize(_step_soft(1800.0), 0.5))
	lib["step_dirt"] = to_stream(_normalize(_step_soft(1100.0), 0.5))
	lib["step_stone"] = to_stream(_normalize(_step_stone(), 0.5))
	lib["step_wood"] = to_stream(_normalize(_knock(0.16, [210.0, 520.0]), 0.5))
	lib["step_snow"] = to_stream(_normalize(_step_soft(2600.0), 0.45))
	lib["jump"] = to_stream(_normalize(_filtered_noise(0.18, 300.0, 900.0, 500.0, 1.2, 1, 0.03, 0.06), 0.3))
	lib["land"] = to_stream(_normalize(_land(), 0.8))
	lib["player_hurt"] = to_stream(_normalize(_vocal(0.32, 150.0, 105.0, [650.0, 1080.0, 2400.0], 0.25), 0.8))
	lib["player_death"] = to_stream(_normalize(_vocal(0.9, 140.0, 70.0, [600.0, 950.0, 2300.0], 0.35), 0.8))
	lib["player_effort"] = to_stream(_normalize(_vocal(0.22, 170.0, 140.0, [700.0, 1150.0, 2500.0], 0.45), 0.5))
	lib["skeleton_alert"] = to_stream(_normalize(_rattle(0.6, 14, 0.0), 0.8))
	lib["skeleton_hurt"] = to_stream(_normalize(_rattle(0.3, 7, 0.4), 0.8))
	lib["skeleton_death"] = to_stream(_normalize(_skeleton_death(), 0.85))
	lib["skeleton_idle"] = to_stream(_normalize(_rattle(0.35, 5, 0.0), 0.5))
	lib["growl"] = to_stream(_normalize(_vocal(0.7, 85.0, 70.0, [420.0, 800.0], 0.7), 0.8))
	lib["ui_click"] = to_stream(_normalize(_blip(0.05, 1300.0, 0.012), 0.5))
	lib["ui_hover"] = to_stream(_normalize(_blip(0.035, 900.0, 0.008), 0.25))
	lib["ui_open"] = to_stream(_normalize(_filtered_noise(0.22, 600.0, 2000.0, 1200.0, 2.0, 1, 0.01, 0.07), 0.35))
	lib["door_open"] = to_stream(_normalize(_creak(0.9, 160.0, 260.0), 0.6))
	lib["door_close"] = to_stream(_normalize(_door_close(), 0.8))
	lib["chest_open"] = to_stream(_normalize(_creak(0.45, 220.0, 320.0), 0.6))
	lib["pickup"] = to_stream(_normalize(_coins(), 0.6))
	lib["equip"] = to_stream(_normalize(_equip(), 0.6))
	lib["level_up"] = to_stream(_normalize(_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.12), 0.6))
	lib["quest"] = to_stream(_normalize(_arpeggio([392.0, 523.25, 659.25], 0.15), 0.55))
	lib["bow_draw"] = to_stream(_normalize(_filtered_noise(0.6, 300.0, 700.0, 1400.0, 3.0, 1, 0.4, 0.2), 0.35))
	lib["bow_release"] = to_stream(_normalize(_bow_release(), 0.8))
	lib["arrow_hit"] = to_stream(_normalize(_knock(0.18, [240.0, 610.0]), 0.8))
	lib["spell_cast"] = to_stream(_normalize(_spell(0.7, 440.0, 1320.0), 0.6))
	lib["fireball"] = to_stream(_normalize(_fire_whoosh(), 0.8))
	lib["frost"] = to_stream(_normalize(_partials(0.8, [1830.0, 2410.0, 3120.0, 3870.0], [0.25, 0.2, 0.15, 0.1], [0.5, 0.4, 0.3, 0.2]), 0.5))
	lib["heal"] = to_stream(_normalize(_arpeggio([392.0, 493.88, 587.33, 783.99], 0.09), 0.5))
	lib["explosion"] = to_stream(_normalize(_explosion(), 0.9))
	lib["drink"] = to_stream(_normalize(_drink(), 0.6))
	lib["eat"] = to_stream(_normalize(_filtered_noise(0.3, 800.0, 1500.0, 900.0, 1.5, 1, 0.01, 0.05), 0.5))
	lib["gold"] = to_stream(_normalize(_coins(), 0.6))
	lib["trap"] = to_stream(_normalize(_hit_metal(0.4, 0.6), 0.8))
	lib["lever"] = to_stream(_normalize(_knock(0.2, [330.0, 900.0]), 0.7))
	lib["stone_door"] = to_stream(_normalize(_filtered_noise(1.4, 120.0, 220.0, 90.0, 0.9, 0, 0.2, 0.9), 0.8))
	lib["wolf_alert"] = to_stream(_normalize(_growl(0.9), 0.85))
	lib["wolf_hurt"] = to_stream(_normalize(_vocal(0.24, 980.0, 560.0, [1300.0, 2700.0], 0.12), 0.8))
	lib["wolf_death"] = to_stream(_normalize(_vocal(1.0, 760.0, 260.0, [1100.0, 2300.0], 0.2), 0.8))
	lib["wolf_idle"] = to_stream(_normalize(_vocal(0.4, 120.0, 100.0, [480.0, 950.0], 0.85), 0.55))
	lib["wolf_howl"] = to_stream(_normalize(_howl(2.8), 0.7))
	lib["bite"] = to_stream(_normalize(_bite(), 0.85))
	# Bandidos (voces humanas sintéticas) y cerraduras
	lib["bandit_alert"] = to_stream(_normalize(_shout(), 0.85))
	lib["bandit_hurt"] = to_stream(_normalize(_vocal(0.26, 135.0, 98.0, [420.0, 880.0, 2350.0], 0.3), 0.8))
	lib["bandit_death"] = to_stream(_normalize(_vocal(1.1, 145.0, 62.0, [560.0, 930.0, 2300.0], 0.42), 0.8))
	lib["bandit_idle"] = to_stream(_normalize(_whistle(), 0.45))
	# Aldeanos heridos, gritos de socorro y el «¡alto!» de la guardia
	lib["npc_hurt"] = to_stream(_normalize(_vocal(0.3, 150.0, 110.0, [480.0, 950.0, 2400.0], 0.28), 0.75))
	lib["npc_hurt_f"] = to_stream(_normalize(_vocal(0.3, 270.0, 200.0, [620.0, 1150.0, 2850.0], 0.25), 0.75))
	lib["npc_scream"] = to_stream(_normalize(_vocal(0.9, 290.0, 235.0, [720.0, 1250.0, 2950.0], 0.3), 0.7))
	lib["guard_halt"] = to_stream(_normalize(_vocal(0.45, 125.0, 150.0, [540.0, 1050.0, 2450.0], 0.2), 0.85))
	lib["lock_pick"] = to_stream(_normalize(_lock_pick(), 0.6))
	lib["lock_open"] = to_stream(_normalize(_lock_open(), 0.75))
	lib["lock_break"] = to_stream(_normalize(_lock_break(), 0.75))
	# Arañas: siseo, castañeteo de quelíceros, chillidos y la seda
	lib["spider_alert"] = to_stream(_normalize(_hiss(0.85), 0.8))
	lib["spider_hurt"] = to_stream(_normalize(_spider_screech(0.32, 1500.0, 950.0), 0.8))
	lib["spider_death"] = to_stream(_normalize(_spider_death(), 0.85))
	lib["spider_idle"] = to_stream(_normalize(_chitter(0.45, 9, 0.6), 0.45))
	lib["step_spider"] = to_stream(_normalize(_chitter(0.07, 2, 0.4), 0.3))
	lib["web_spit"] = to_stream(_normalize(_web_spit(), 0.75))
	lib["web_hit"] = to_stream(_normalize(_filtered_noise(0.22, 1100.0, 600.0, 300.0, 0.9, 0, 0.005, 0.08), 0.7))
	lib["wind_loop"] = to_stream(_normalize(_wind_loop(6.0), 0.35), true)
	lib["fire_loop"] = to_stream(_normalize(_fire_loop(3.0), 0.5), true)
	lib["cave_loop"] = to_stream(_normalize(_cave_loop(6.0), 0.3), true)
	lib["night_loop"] = to_stream(_normalize(_night_loop(6.0), 0.3), true)
	return lib


## Grito de alarma de dos sílabas («¡a-llí!»): vocal abierta y luego cerrada,
## con la entonación subiendo y cayendo.
func _shout() -> PackedFloat32Array:
	var a := _vocal(0.16, 175.0, 215.0, [780.0, 1250.0, 2600.0], 0.18)
	var b2 := _vocal(0.34, 235.0, 165.0, [330.0, 2250.0, 3000.0], 0.15)
	var out := _buf(0.52)
	_mix_into(out, a, 0, 1.0)
	_mix_into(out, b2, int(0.15 * RATE), 0.9)
	_fade_edges(out)
	return out


## Silbido despreocupado: tres notas con portamento y vibrato.
func _whistle() -> PackedFloat32Array:
	var b := _buf(0.95)
	var n := b.size()
	var notes := [1180.0, 1490.0, 1320.0, 1320.0]
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / float(n)
		var seg := minf(p * 3.0, 2.999)
		var k := int(seg)
		var f := lerpf(notes[k], notes[k + 1], smoothstep(0.0, 0.25, seg - k)) * (1.0 + sin(TAU * 5.5 * t) * 0.012)
		ph += f / RATE
		var env := sin(PI * p) * (0.75 + 0.25 * sin(PI * fmod(seg, 1.0)))
		b[i] = (sin(TAU * ph) + _rng.randf_range(-1.0, 1.0) * 0.06) * env
	return b


## Ganzúa: chasquidos metálicos pequeños e irregulares.
func _lock_pick() -> PackedFloat32Array:
	var out := _buf(0.5)
	for k in 4:
		var click := _knock(0.06, [2600.0 + k * 230.0, 4300.0])
		_mix_into(out, click, int((0.04 + k * 0.1 + _rng.randf_range(0.0, 0.03)) * RATE), 0.7 - k * 0.08)
	return out


## Cerradura que cede: chasquido seco y golpe del pestillo.
func _lock_open() -> PackedFloat32Array:
	var out := _buf(0.45)
	_mix_into(out, _knock(0.08, [3100.0, 5200.0]), 0, 0.6)
	_mix_into(out, _knock(0.3, [420.0, 980.0, 1700.0]), int(0.07 * RATE), 1.0)
	return out


## Ganzúa rota: chasquido agudo y tintineo.
func _lock_break() -> PackedFloat32Array:
	var out := _buf(0.5)
	_mix_into(out, _hit_metal(0.3, 1.5), 0, 0.7)
	_mix_into(out, _knock(0.12, [5200.0, 7400.0]), int(0.02 * RATE), 0.8)
	_mix_into(out, _knock(0.1, [3900.0, 6100.0]), int(0.22 * RATE), 0.35)
	return out


## Gruñido: voz grave con aspereza (modulación de amplitud rápida).
func _growl(seconds: float) -> PackedFloat32Array:
	var b := _vocal(seconds, 92.0, 78.0, [380.0, 760.0, 1500.0], 0.8)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.55 + 0.45 * absf(sin(TAU * 27.0 * t + sin(t * 9.0)))
	return b


## Aullido lejano: tono que sube, se sostiene con vibrato y cae.
func _howl(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var n := b.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 430.0
		if t < 0.6:
			f = lerpf(430.0, 640.0, smoothstep(0.0, 0.6, t))
		elif t < seconds - 0.8:
			f = 625.0 + sin(TAU * 5.0 * t) * 9.0
		else:
			f = lerpf(625.0, 410.0, smoothstep(seconds - 0.8, seconds, t))
		ph += TAU * f / RATE
		var amp := minf(t / 0.3, 1.0) * clampf((seconds - t) / 0.6, 0.0, 1.0)
		b[i] = (sin(ph) + 0.3 * sin(ph * 2.0) + 0.12 * sin(ph * 3.0) + _rng.randf_range(-0.05, 0.05)) * amp
	return b


## Mordisco: chasquido seco de dientes con un golpe sordo.
func _bite() -> PackedFloat32Array:
	var b := _knock(0.14, [700.0, 1650.0, 2900.0])
	_mix_into(b, _thump(0.1, 180.0, 90.0, 0.03), 0, 0.6)
	_fade_edges(b, 0.002)
	return b


## Siseo de araña: ruido agudo con pulsos rápidos y castañeteo de quelíceros.
func _hiss(seconds: float) -> PackedFloat32Array:
	var b := _filtered_noise(seconds, 2600.0, 4400.0, 3200.0, 1.3, 1, 0.06, seconds * 0.45)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= 0.6 + 0.4 * absf(sin(TAU * 13.0 * t))
	_mix_into(b, _chitter(seconds * 0.6, 8, 0.8), 0, 0.5)
	_fade_edges(b)
	return b


## Castañeteo seco y rápido (patas y quelíceros).
func _chitter(seconds: float, clicks: int, brightness: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for k in clicks:
		var f0 := (1800.0 + _rng.randf() * 1400.0) * (0.6 + brightness * 0.5)
		var click := _partials(0.035, [f0, f0 * 1.7], [0.006, 0.004], [0.6, 0.35])
		var at := (float(k) + _rng.randf_range(0.0, 0.6)) / float(maxi(clicks, 1)) * (seconds - 0.035)
		_mix_into(b, click, int(at * RATE), _rng.randf_range(0.5, 1.0))
	_fade_edges(b)
	return b


## Chillido agudo y áspero (araña herida).
func _spider_screech(seconds: float, f0: float, f1: float) -> PackedFloat32Array:
	var b := _vocal(seconds, f0, f1, [2400.0, 4100.0], 0.55)
	_mix_into(b, _chitter(seconds, 5, 1.0), 0, 0.45)
	_fade_edges(b)
	return b


## Muerte: chillido que se apaga y un crujido de quitina.
func _spider_death() -> PackedFloat32Array:
	var b := _spider_screech(1.0, 1300.0, 380.0)
	for i in b.size():
		b[i] *= clampf(1.0 - float(i) / b.size(), 0.0, 1.0)
	var crunch := _buf(0.5)
	for k in 14:
		var click := _partials(0.05, [700.0 + _rng.randf() * 1600.0, 1900.0 + _rng.randf() * 1500.0], [0.012, 0.008], [0.6, 0.4])
		_mix_into(crunch, click, int(_rng.randf() * 0.4 * RATE), _rng.randf_range(0.4, 1.0))
	_mix_into(b, crunch, int(0.45 * RATE), 0.8)
	_mix_into(b, _thump(0.25, 120.0, 60.0, 0.08), int(0.5 * RATE), 0.7)
	_fade_edges(b)
	return b


## Escupitajo de seda: un chasquido húmedo con un soplido que se aleja.
func _web_spit() -> PackedFloat32Array:
	var b := _filtered_noise(0.3, 2200.0, 900.0, 500.0, 1.0, 0, 0.005, 0.12)
	_mix_into(b, _thump(0.08, 420.0, 180.0, 0.02), 0, 0.7)
	_fade_edges(b, 0.002)
	return b


func _swing(seconds: float, f0: float, f1: float, f2: float) -> PackedFloat32Array:
	var b := _filtered_noise(seconds, f0, f1, f2, 2.2, 1, seconds * 0.35, seconds * 0.25)
	_fade_edges(b)
	return b


func _hit_flesh() -> PackedFloat32Array:
	var b := _thump(0.22, 110.0, 45.0, 0.07)
	_mix_into(b, _filtered_noise(0.12, 900.0, 600.0, 300.0, 1.0, 0, 0.002, 0.03), 0, 0.9)
	_fade_edges(b)
	return b


func _hit_bone() -> PackedFloat32Array:
	var b := _thump(0.2, 180.0, 90.0, 0.04)
	for k in 3:
		var crack := _filtered_noise(0.05, 2500.0, 1800.0, 1200.0, 3.0, 1, 0.001, 0.008)
		_mix_into(b, crack, int((0.004 + k * 0.013) * RATE), 1.2)
	_mix_into(b, _partials(0.15, [1150.0, 2280.0], [0.03, 0.02], [0.4, 0.3]), 0, 1.0)
	_fade_edges(b)
	return b


func _hit_metal(length: float, brightness: float) -> PackedFloat32Array:
	var b := _partials(length, [520.0, 1187.0, 1763.0, 2690.0, 3550.0],
			[0.35 * length, 0.22 * length, 0.15 * length, 0.09 * length, 0.06 * length],
			[0.5, 0.45 * brightness, 0.35 * brightness, 0.25 * brightness, 0.18 * brightness])
	_mix_into(b, _filtered_noise(0.04, 3000.0, 2500.0, 2000.0, 1.0, 2, 0.001, 0.01), 0, 0.8)
	_fade_edges(b)
	return b


func _block() -> PackedFloat32Array:
	var b := _hit_metal(0.35, 0.6)
	_mix_into(b, _thump(0.15, 140.0, 70.0, 0.05), 0, 0.9)
	_mix_into(b, _filtered_noise(0.1, 1200.0, 900.0, 600.0, 1.0, 1, 0.001, 0.03), 0, 0.6)
	return b


func _hit_wall() -> PackedFloat32Array:
	var b := _filtered_noise(0.25, 1800.0, 1200.0, 700.0, 0.8, 1, 0.001, 0.05)
	_mix_into(b, _thump(0.15, 120.0, 60.0, 0.04), 0, 0.9)
	for k in 4:
		_mix_into(b, _filtered_noise(0.03, 3000.0, 2500.0, 2000.0, 2.0, 1, 0.001, 0.006),
				int((0.03 + k * 0.025 + _rng.randf() * 0.02) * RATE), 0.4)
	_fade_edges(b)
	return b


func _knock(seconds: float, modes: Array) -> PackedFloat32Array:
	var decays := []
	var gains := []
	for i in modes.size():
		decays.append(0.06 / (1.0 + i * 0.6))
		gains.append(1.0 / (1.0 + i))
	var b := _partials(seconds, modes, decays, gains)
	_mix_into(b, _filtered_noise(0.03, 1500.0, 1200.0, 900.0, 1.0, 1, 0.001, 0.006), 0, 0.6)
	_fade_edges(b)
	return b


func _step_soft(cutoff: float) -> PackedFloat32Array:
	var b := _filtered_noise(0.16, cutoff, cutoff * 0.8, cutoff * 0.5, 0.9, 0, 0.004, 0.035)
	_mix_into(b, _filtered_noise(0.08, cutoff * 1.4, cutoff, cutoff * 0.6, 1.2, 1, 0.002, 0.02), int(0.03 * RATE), 0.6)
	_fade_edges(b)
	return b


func _step_stone() -> PackedFloat32Array:
	var b := _filtered_noise(0.06, 2600.0, 2200.0, 1800.0, 1.8, 1, 0.001, 0.01)
	_mix_into(b, _thump(0.08, 160.0, 110.0, 0.02), 0, 0.6)
	_mix_into(b, _filtered_noise(0.1, 1200.0, 900.0, 700.0, 1.0, 0, 0.003, 0.025), int(0.012 * RATE), 0.5)
	_fade_edges(b)
	return b


func _land() -> PackedFloat32Array:
	var b := _thump(0.25, 90.0, 45.0, 0.08)
	_mix_into(b, _filtered_noise(0.2, 900.0, 600.0, 300.0, 0.8, 0, 0.003, 0.05), 0, 0.8)
	_fade_edges(b)
	return b


func _rattle(seconds: float, clicks: int, thump_gain: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for k in clicks:
		var click := _partials(0.05, [1400.0 + _rng.randf() * 1500.0, 2600.0 + _rng.randf() * 1500.0], [0.012, 0.008], [0.6, 0.4])
		_mix_into(b, click, int(_rng.randf() * (seconds - 0.05) * RATE), _rng.randf_range(0.4, 1.0))
	if thump_gain > 0.0:
		_mix_into(b, _thump(0.12, 160.0, 80.0, 0.03), 0, thump_gain)
	_fade_edges(b)
	return b


func _skeleton_death() -> PackedFloat32Array:
	var b := _buf(1.3)
	for k in 40:
		var t := pow(_rng.randf(), 1.6) * 1.15
		var click := _partials(0.06, [900.0 + _rng.randf() * 2200.0, 2100.0 + _rng.randf() * 2200.0], [0.015, 0.01], [0.6, 0.4])
		_mix_into(b, click, int(t * RATE), _rng.randf_range(0.3, 1.0) * (1.0 - t * 0.5))
	_mix_into(b, _thump(0.3, 110.0, 50.0, 0.1), int(0.35 * RATE), 0.8)
	_fade_edges(b)
	return b


func _blip(seconds: float, freq: float, decay: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)) * _env(t, 0.002, decay)
	_fade_edges(b, 0.002)
	return b


func _creak(seconds: float, f_lo: float, f_hi: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var ph := 0.0
	var n := b.size()
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / float(n)
		var wobble := sin(t * 23.0) * 0.5 + sin(t * 61.0) * 0.3 + _rng.randf_range(-0.2, 0.2)
		var f := lerpf(f_lo, f_hi, p) * (1.0 + wobble * 0.08)
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var x := saw * (0.6 + 0.4 * absf(sin(t * 37.0)))
		var fc := 2.0 * sin(PI * 900.0 / RATE)
		low += fc * band
		var high := x - low - 0.4 * band
		band += fc * high
		b[i] = band * sin(PI * p)
	_fade_edges(b)
	return b


func _door_close() -> PackedFloat32Array:
	var b := _thump(0.3, 95.0, 55.0, 0.09)
	_mix_into(b, _knock(0.2, [190.0, 470.0]), 0, 0.7)
	_mix_into(b, _hit_metal(0.15, 0.8), int(0.06 * RATE), 0.25)
	return b


func _coins() -> PackedFloat32Array:
	var b := _buf(0.5)
	for k in 6:
		var ping := _partials(0.25, [2200.0 + _rng.randf() * 1800.0, 5100.0 + _rng.randf() * 1500.0], [0.07, 0.04], [0.5, 0.25])
		_mix_into(b, ping, int(_rng.randf() * 0.22 * RATE), _rng.randf_range(0.5, 1.0))
	_fade_edges(b)
	return b


func _equip() -> PackedFloat32Array:
	var b := _filtered_noise(0.3, 2000.0, 4000.0, 3000.0, 3.0, 1, 0.12, 0.08)
	_mix_into(b, _partials(0.4, [1900.0, 3100.0], [0.12, 0.08], [0.3, 0.2]), int(0.12 * RATE), 0.6)
	_fade_edges(b)
	return b


func _arpeggio(freqs: Array, step: float) -> PackedFloat32Array:
	var total := step * freqs.size() + 0.6
	var b := _buf(total)
	for k in freqs.size():
		var f: float = freqs[k]
		var tone := _partials(0.6, [f, f * 2.0, f * 3.0], [0.25, 0.15, 0.08], [0.6, 0.25, 0.1])
		_mix_into(b, tone, int(k * step * RATE), 0.8)
	_fade_edges(b)
	return b


func _bow_release() -> PackedFloat32Array:
	var b := _pluck(0.35, 98.0, 0.985)
	_mix_into(b, _thump(0.1, 200.0, 90.0, 0.025), 0, 0.5)
	_mix_into(b, _swing(0.18, 900.0, 2400.0, 1200.0), int(0.02 * RATE), 0.4)
	_fade_edges(b)
	return b


func _spell(seconds: float, f0: float, f1: float) -> PackedFloat32Array:
	var b := _buf(seconds)
	var n := b.size()
	var ph := 0.0
	var mph := 0.0
	for i in n:
		var t := float(i) / RATE
		var p := float(i) / float(n)
		var f := lerpf(f0, f1, p * p)
		mph += f * 1.5 / RATE
		ph += (f + sin(mph * TAU) * f * 0.5) / RATE
		b[i] = sin(ph * TAU) * sin(PI * p) * 0.6
	_mix_into(b, _filtered_noise(seconds, 3000.0, 5000.0, 4000.0, 2.0, 2, seconds * 0.5, seconds * 0.3), 0, 0.3)
	_fade_edges(b)
	return b


func _fire_whoosh() -> PackedFloat32Array:
	var b := _filtered_noise(0.8, 300.0, 1200.0, 200.0, 0.9, 1, 0.15, 0.3)
	_mix_into(b, _filtered_noise(0.8, 120.0, 200.0, 90.0, 0.7, 0, 0.1, 0.4), 0, 0.8)
	_fade_edges(b)
	return b


func _explosion() -> PackedFloat32Array:
	var b := _filtered_noise(1.2, 900.0, 300.0, 100.0, 0.7, 0, 0.005, 0.35)
	_mix_into(b, _thump(0.6, 70.0, 30.0, 0.2), 0, 1.0)
	_fade_edges(b)
	return b


func _drink() -> PackedFloat32Array:
	var b := _buf(0.7)
	for k in 5:
		var glug := _thump(0.09, 300.0 + _rng.randf() * 150.0, 180.0, 0.03)
		_mix_into(b, glug, int((0.05 + k * 0.12) * RATE), 0.7)
	_mix_into(b, _filtered_noise(0.7, 700.0, 900.0, 600.0, 1.5, 1, 0.1, 0.3), 0, 0.15)
	_fade_edges(b)
	return b


func _loopify(b: PackedFloat32Array, cross_s: float) -> PackedFloat32Array:
	# Mezcla cruzada del final con el principio para que el bucle no tenga costura.
	var n := b.size()
	var c := int(cross_s * RATE)
	var out := PackedFloat32Array()
	out.resize(n - c)
	for i in n - c:
		out[i] = b[i]
	for i in c:
		var k := float(i) / float(c)
		out[i] = b[i] * k + b[n - c + i] * (1.0 - k)
	return out


func _wind_loop(seconds: float) -> PackedFloat32Array:
	var b := _buf(seconds + 1.0)
	var low := 0.0
	var band := 0.0
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var gust := 0.55 + 0.3 * sin(t * 0.9) + 0.15 * sin(t * 2.3 + 1.0)
		var fc := 2.0 * sin(PI * (250.0 + 350.0 * gust) / RATE)
		low += fc * band
		var high := _rng.randf_range(-1.0, 1.0) - low - 0.7 * band
		band += fc * high
		b[i] = band * gust
	return _loopify(b, 1.0)


func _fire_loop(seconds: float) -> PackedFloat32Array:
	var b := _filtered_noise(seconds + 0.5, 500.0, 600.0, 500.0, 0.8, 0, 0.01, 100.0)
	for i in b.size():
		b[i] *= 0.25
	for k in int(seconds * 18.0):
		var pop := _filtered_noise(0.02, 3000.0, 2000.0, 1500.0, 1.5, 1, 0.001, 0.004)
		_mix_into(b, pop, int(_rng.randf() * (seconds) * RATE), _rng.randf_range(0.3, 1.0))
	return _loopify(b, 0.5)


func _cave_loop(seconds: float) -> PackedFloat32Array:
	var b := _filtered_noise(seconds + 1.0, 120.0, 160.0, 120.0, 0.7, 0, 0.5, 100.0)
	for k in 5:
		var drip := _partials(0.3, [1400.0 + _rng.randf() * 900.0], [0.06], [0.5])
		_mix_into(b, drip, int(_rng.randf() * seconds * RATE), _rng.randf_range(0.2, 0.5))
	return _loopify(b, 1.0)


func _night_loop(seconds: float) -> PackedFloat32Array:
	var b := _wind_loop(seconds)
	for i in b.size():
		b[i] *= 0.4
	# Grillos: pulsos de alta frecuencia en ráfagas.
	var t := 0.0
	while t < seconds - 0.3:
		var chirp := _buf(0.12)
		var f := 4200.0 + _rng.randf() * 600.0
		for i in chirp.size():
			var tt := float(i) / RATE
			chirp[i] = sin(TAU * f * tt) * (0.5 + 0.5 * sin(TAU * 60.0 * tt)) * sin(PI * tt / 0.12)
		_mix_into(b, chirp, int(t * RATE), 0.25)
		t += _rng.randf_range(0.25, 0.9)
	return b
