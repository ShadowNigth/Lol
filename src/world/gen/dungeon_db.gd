class_name DungeonDB
extends RefCounted
## Definición de las mazmorras del mundo (datos): nombre, ambientación de la
## generación (cripta, túmulo, cueva), llave de la entrada, jefe, esbirros,
## botín del jefe y dificultad. El generador (DungeonGenerator) y las
## entradas (DungeonEntrance) leen esta tabla, de modo que añadir una
## mazmorra nueva es añadir una entrada aquí y un sitio en StructurePlanner.

const B = preload("res://src/world/voxel/block_types.gd")

const DUNGEONS := {
	"crypt_velmar": {
		"name": "Cripta de Velmar", "theme": "crypt", "door": "la cripta de Velmar",
		"entry_key": "rusty_key", "entry_hint": "La puerta está cerrada. Quizá la llave esté en algún lugar de la capilla.",
		"boss": "skeleton_lord", "guards": "skeleton_warrior", "boss_loot": "boss",
		"minions": ["skeleton_warrior", "skeleton_archer"], "ranged_chance": 0.25, "difficulty": 1,
	},
	"barrow_grises": {
		"name": "Túmulo de los Reyes Grises", "theme": "barrow", "door": "el túmulo de los Reyes Grises",
		"entry_key": "", "entry_hint": "",
		"boss": "barrow_king", "guards": "skeleton_warrior", "boss_loot": "boss_barrow",
		"minions": ["skeleton_warrior", "skeleton_archer"], "ranged_chance": 0.35, "difficulty": 2,
	},
	"cave_lobos": {
		"name": "Cubil de Colmillo Negro", "theme": "cave", "door": "la cueva",
		"entry_key": "", "entry_hint": "",
		"boss": "wolf_alpha", "guards": "wolf", "boss_loot": "boss_den",
		"minions": ["wolf"], "ranged_chance": 0.0, "difficulty": 1, "max_per_room": 1,
	},
	"mina_hierronegro": {
		"name": "Mina de Hierronegro", "theme": "mine", "door": "la mina de Hierronegro",
		"entry_key": "", "entry_hint": "",
		"boss": "spider_queen", "guards": "spider", "boss_loot": "boss_mine", "room_loot": "mine",
		"minions": ["spider", "spider_spitter"], "ranged_chance": 0.3, "difficulty": 2, "max_per_room": 2,
	},
}

## Bloques por ambientación: muros (base, alternativo), suelos (base,
## alternativo), telarañas, sarcófagos y, en la mina: techo de roca
## irregular, vetas de mineral, entibado de madera, raíles en las galerías,
## lámparas de poste en vez de braseros y el nido de seda de la sala del jefe.
const THEMES := {
	"crypt": {"wall": B.DUNGEON_BRICK, "wall_alt": B.STONE, "floor": B.DUNGEON_FLOOR, "floor_alt": B.MOSS_STONE,
			"cobwebs": true, "sarcophagi": true},
	"barrow": {"wall": B.MOSSY_BRICK, "wall_alt": B.DIRT, "floor": B.COBBLE, "floor_alt": B.GRAVEL,
			"cobwebs": true, "sarcophagi": true},
	"cave": {"wall": B.STONE, "wall_alt": B.GRAVEL, "floor": B.GRAVEL, "floor_alt": B.DIRT,
			"cobwebs": false, "sarcophagi": false, "rough_ceiling": true},
	"mine": {"wall": B.STONE, "wall_alt": B.GRAVEL, "floor": B.GRAVEL, "floor_alt": B.DIRT,
			"cobwebs": true, "sarcophagi": false, "rough_ceiling": true, "ore": true, "timber": true,
			"rails": true, "lights": "mine_lamp", "nest": true},
}


static func get_def(id: String) -> Dictionary:
	return DUNGEONS.get(id, DUNGEONS["crypt_velmar"])


static func theme(id: String) -> Dictionary:
	return THEMES.get(str(get_def(id).get("theme", "crypt")), THEMES["crypt"])


static func display_name(id: String) -> String:
	return str(get_def(id).get("name", id))
