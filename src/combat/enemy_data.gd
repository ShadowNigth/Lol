class_name EnemyData
extends Resource
## Parámetros configurables de un tipo de enemigo.

@export var id: String = "skeleton_warrior"
@export var display_name: String = "Guerrero esqueleto"
@export var model: String = "skeleton_warrior"
@export var weapon_model: String = "rusty_sword"
@export var has_shield: bool = true
## Modelo del escudo (shield = madera, shield_iron = hierro).
@export var shield_model: String = "shield"
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
## Ataca a distancia con arco (mantiene la distancia y dispara flechas).
@export var ranged: bool = false
@export var projectile_speed: float = 30.0

@export_group("Cuerpo y comportamiento")
## Tipo de cuerpo: "humanoid" (esqueletos y bandidos) o "quadruped" (lobos).
## El aspecto del humanoide lo decide `model`: "skeleton_warrior" o "bandit".
@export_enum("humanoid", "quadruped") var body: String = "humanoid"
## Altura de los ojos (línea de visión).
@export var eye_height: float = 1.6
@export var collision_radius: float = 0.33
@export var collision_height: float = 1.8
## Tiempos de los dos ataques (instante del impacto y duración total).
@export var attack1_hit: float = 0.55
@export var attack1_len: float = 1.15
@export var attack2_hit: float = 0.68
@export var attack2_len: float = 1.35
## Probabilidad de usar el ataque 1 (el resto, ataque 2).
@export_range(0.0, 1.0, 0.05) var attack1_chance: float = 0.6
## Impulso hacia delante durante el ataque 2 (salto de los lobos); 0 = sin salto.
@export var lunge_speed: float = 0.0
## Al detectar al jugador avisa a los de su especie cercanos (manada).
@export var pack_call: bool = false
## Fracción de salud por debajo de la cual huye un rato (0 = nunca).
@export_range(0.0, 1.0, 0.05) var flee_health: float = 0.0
@export var step_sound: String = "step_stone"
## Los animales salvajes reaparecen pasados unos días (0 = nunca).
@export var respawn_days: int = 0
