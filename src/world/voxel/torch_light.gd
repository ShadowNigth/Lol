class_name TorchLight
extends OmniLight3D
## Luz cálida con parpadeo suave para antorchas, faroles y fraguas.

var base_energy: float = 1.25
var _t: float = 0.0
var _seed: float = 0.0


func _init() -> void:
	light_color = Color(1.0, 0.68, 0.36)
	omni_range = 7.5
	omni_attenuation = 1.4
	light_energy = base_energy
	shadow_enabled = false
	light_specular = 0.3
	_seed = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t * 9.0 + _seed) * 0.05 + sin(_t * 23.0 + _seed * 2.0) * 0.04 + sin(_t * 3.1 + _seed) * 0.06
	light_energy = base_energy * (1.0 + f)
