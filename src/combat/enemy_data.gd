class_name EnemyData
extends Resource
## Parámetros configurables de un tipo de enemigo.

@export var id: String = "skeleton_warrior"
@export var display_name: String = "Guerrero esqueleto"
@export var model: String = "skeleton_warrior"
@export var weapon_model: String = "rusty_sword"
@export var has_shield: bool = true
@export var max_health: float = 55.0
@export var armor: float = 10.0
@export var damage_min: float = 7.0
@export var damage_max: float = 12.0
@export_enum("slash", "blunt", "pierce") var damage_type: String = "slash"
@export var attack_range: float = 1.9
@export var attack_cooldown: float = 1.1
@export var walk_speed: float = 1.6
@export var run_speed: float = 4.2
@export var detection_range: float = 16.0
@export var fov_degrees: float = 130.0
@export var hearing_range: float = 6.0
@export_range(0.0, 1.0, 0.05) var block_chance: float = 0.3
## Daño mínimo en un golpe para interrumpir un ataque en preparación.
@export var stagger_threshold: float = 8.0
@export var xp_reward: int = 25
@export var gold_min: int = 2
@export var gold_max: int = 12
@export var loot_table: String = "skeleton"
## Efecto de impacto: bone, blood, sparks
@export var hit_effect: String = "bone"
@export var sound_alert: String = "skeleton_alert"
@export var sound_hurt: String = "skeleton_hurt"
@export var sound_death: String = "skeleton_death"
@export var sound_idle: String = "skeleton_idle"
## Resistencias (fracción): slash, blunt, pierce, fire, frost...
@export var resist_slash: float = 0.15
@export var resist_blunt: float = -0.35
@export var resist_pierce: float = 0.4
@export var level: int = 1
## Escala del modelo (jefes más grandes).
@export var model_scale: float = 1.0
## Variante visual del modelo (0-3; 3 = corona de señor).
@export var model_variant: int = -1
@export var is_boss: bool = false
