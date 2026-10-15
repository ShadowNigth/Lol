extends Node
## Gestor de audio: genera la biblioteca de efectos procedurales en segundo
## plano y reproduce sonidos 2D/3D con un grupo reutilizable de reproductores.

signal library_ready

const POOL_3D := 24
const POOL_2D := 8

var _library: Dictionary = {}
var _ready_flag: bool = false
var _task_id: int = -1
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
var _rng := RandomNumberGenerator.new()
var _pending_library: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.9
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "SFX"
		add_child(p2)
		_pool_2d.append(p2)
	_task_id = WorkerThreadPool.add_task(_build_library_threaded, false, "Síntesis de efectos de sonido")


func _build_library_threaded() -> void:
	var synth := SfxSynth.new(20240917)
	_pending_library = synth.build_library()


func _process(_delta: float) -> void:
	if not _ready_flag and _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id):
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_library = _pending_library
		_pending_library = {}
		_ready_flag = true
		library_ready.emit()


func is_ready() -> bool:
	return _ready_flag


## Espera (bloqueando) a que termine la síntesis. Útil en pruebas automáticas.
func wait_until_ready() -> void:
	if _ready_flag:
		return
	if _task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		_library = _pending_library
		_pending_library = {}
		_ready_flag = true
		library_ready.emit()


func get_stream(sound: String) -> AudioStream:
	return _library.get(sound, null)


func _ensure_buses() -> void:
	for bus_name: String in ["SFX", "Music", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## Sonido no posicional (interfaz, sonidos del propio jugador).
func play_2d(sound: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_var: float = 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _pool_2d.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


## Sonido posicional en el mundo.
func play_3d(sound: String, position: Vector3, volume_db: float = 0.0, pitch_var: float = 0.08, pitch: float = 1.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.stop()
	p.stream = stream
	p.global_position = position
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


## Crea un reproductor en bucle (ambiente, antorchas...) hijo de `parent`.
func make_loop_player_3d(sound: String, parent: Node3D, volume_db: float = -6.0, max_distance: float = 20.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "Ambience"
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 3.0
	parent.add_child(p)
	_start_loop_when_ready(p, sound)
	return p


func make_loop_player_2d(sound: String, parent: Node, volume_db: float = -8.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Ambience"
	p.volume_db = volume_db
	parent.add_child(p)
	_start_loop_when_ready(p, sound)
	return p


## Asigna el bucle al reproductor ahora o cuando la biblioteca esté lista.
func _start_loop_when_ready(player: Node, sound: String) -> void:
	if _ready_flag:
		_assign_and_play(player, sound)
		return
	var cb := func() -> void:
		_assign_and_play(player, sound)
	library_ready.connect(cb, CONNECT_ONE_SHOT)


func _assign_and_play(player: Node, sound: String) -> void:
	if not is_instance_valid(player):
		return
	var stream := get_stream(sound)
	if stream == null:
		return
	if player is AudioStreamPlayer3D:
		var p3 := player as AudioStreamPlayer3D
		p3.stream = stream
		if p3.is_inside_tree():
			p3.play()
	elif player is AudioStreamPlayer:
		var p2 := player as AudioStreamPlayer
		p2.stream = stream
		if p2.is_inside_tree():
			p2.play()
