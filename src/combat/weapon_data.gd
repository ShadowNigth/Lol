class_name WeaponData
extends Resource
## Parámetros configurables de un arma (editables desde el inspector o .tres).

@export var id: String = "sword"
@export var display_name: String = "Espada"
@export_multiline var description: String = ""
## sword, axe, mace, dagger, bow, staff, unarmed
@export_enum("sword", "axe", "mace", "dagger", "bow", "staff", "unarmed") var kind: String = "sword"
## Identificador del modelo voxel (WeaponModels.by_id)
@export var model_id: String = "sword"
@export var damage_min: float = 9.0
@export var damage_max: float = 15.0
@export var reach: float = 2.3
@export var stamina_cost: float = 12.0
## Multiplicador de velocidad de animación y de la ventana de golpe.
@export_range(0.5, 2.0, 0.05) var speed: float = 1.0
## Fracción de daño que se evita al bloquear.
@export_range(0.0, 1.0, 0.05) var block_reduction: float = 0.65
@export var block_stamina_cost: float = 10.0
## Habilidad que se entrena al usarla (ver Stats).
@export var skill: String = "blade"
@export var weight: float = 3.0
@export var value: int = 40
## Tipo de daño: slash, blunt, pierce
@export_enum("slash", "blunt", "pierce") var damage_type: String = "slash"
@export var two_handed: bool = false


func roll_damage(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(damage_min, damage_max)
