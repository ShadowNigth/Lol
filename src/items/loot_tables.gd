class_name LootTables
extends RefCounted
## Tablas de botín: cada entrada [id, probabilidad, mín, máx].

const TABLES := {
	"skeleton": [["bone_dust", 0.6, 1, 2], ["old_coin", 0.25, 1, 2], ["potion_health", 0.15, 1, 1], ["weapon_rusty_sword", 0.08, 1, 1], ["boots_leather", 0.04, 1, 1]],
	"home": [["bread", 0.7, 1, 2], ["apple", 0.5, 1, 3], ["potion_health", 0.3, 1, 1], ["lockpick", 0.3, 1, 2]],
	"inn": [["bread", 0.8, 1, 3], ["potion_stamina", 0.5, 1, 1], ["silver_ring", 0.1, 1, 1]],
	"dungeon": [["potion_health", 0.7, 1, 2], ["old_coin", 0.8, 2, 6], ["potion_stamina", 0.4, 1, 1], ["silver_ring", 0.15, 1, 1], ["weapon_axe", 0.08, 1, 1], ["hood_leather", 0.1, 1, 1], ["gloves_leather", 0.1, 1, 1], ["boots_iron", 0.06, 1, 1]],
	"secret": [["silver_ring", 0.8, 1, 2], ["potion_health", 1.0, 2, 3], ["potion_mana", 0.8, 1, 2], ["weapon_mace", 0.3, 1, 1], ["old_coin", 1.0, 5, 10], ["shield_iron", 0.35, 1, 1], ["helm_iron", 0.3, 1, 1]],
	"boss": [["velmar_crown", 1.0, 1, 1], ["velmar_helm", 1.0, 1, 1], ["potion_health", 1.0, 2, 3], ["silver_ring", 0.6, 1, 1], ["old_coin", 1.0, 8, 15]],
	"skeleton_lord": [["bone_dust", 1.0, 3, 5], ["old_coin", 1.0, 4, 8]],
	"wolf": [["wolf_pelt", 0.85, 1, 1], ["wolf_fang", 0.5, 1, 2]],
	"wolf_alpha": [["alpha_pelt", 1.0, 1, 1], ["wolf_fang", 1.0, 2, 4], ["wolf_pelt", 1.0, 1, 1]],
	"boss_barrow": [["helm_iron", 1.0, 1, 1], ["greaves_iron", 0.6, 1, 1], ["potion_health", 1.0, 2, 3], ["silver_ring", 0.7, 1, 2], ["old_coin", 1.0, 10, 18]],
	"boss_den": [["potion_health", 1.0, 1, 2], ["wolf_pelt", 1.0, 2, 3], ["gauntlets_iron", 0.5, 1, 1], ["old_coin", 1.0, 4, 9], ["weapon_bow", 0.3, 1, 1]],
	"ruins": [["potion_health", 0.9, 1, 2], ["old_coin", 0.8, 2, 5], ["book_velmar", 1.0, 1, 1], ["rusty_key", 1.0, 1, 1], ["potion_mana", 0.4, 1, 1]],
	# Bandidos: lo que lleva encima un salteador (y su jefe, con la llave del campamento)
	"bandit": [["lockpick", 0.45, 1, 2], ["bread", 0.35, 1, 1], ["cheese", 0.25, 1, 1], ["potion_health", 0.2, 1, 1], ["weapon_dagger", 0.08, 1, 1],
			["hood_leather", 0.06, 1, 1], ["gloves_leather", 0.06, 1, 1], ["silver_ring", 0.04, 1, 1]],
	"bandit_archer": [["arrow", 0.9, 4, 10], ["lockpick", 0.3, 1, 1], ["bread", 0.3, 1, 1], ["potion_health", 0.15, 1, 1], ["weapon_bow", 0.05, 1, 1]],
	"bandit_chief": [["key_cuervos", 1.0, 1, 1], ["nota_cuervos", 1.0, 1, 1], ["potion_health", 1.0, 1, 2], ["lockpick", 1.0, 2, 3], ["silver_ring", 0.5, 1, 1],
			["helm_iron", 0.35, 1, 1]],
	# Castillo de Peñalba: cuartel, arcones del salón y del calabozo, cámara de la señora
	"barracks": [["bread", 0.6, 1, 2], ["arrow", 0.6, 5, 12], ["potion_health", 0.35, 1, 1], ["lockpick", 0.25, 1, 1], ["gloves_leather", 0.15, 1, 1]],
	"castle": [["potion_health", 0.6, 1, 2], ["ley_marca", 0.5, 1, 1], ["silver_ring", 0.25, 1, 1], ["key_calabozo", 0.5, 1, 1], ["arrow", 0.4, 8, 16]],
	"noble": [["silver_goblet", 0.9, 1, 1], ["silver_ring", 0.7, 1, 2], ["cronica_penalba", 1.0, 1, 1], ["potion_mana", 0.4, 1, 1]],
	# Guardia de Peñalba abatido (equipo de la guardia y algo de paga)
	"guard": [["potion_health", 0.4, 1, 1], ["key_calabozo", 0.15, 1, 1], ["bread", 0.3, 1, 1], ["helm_iron", 0.12, 1, 1], ["weapon_sword", 0.1, 1, 1]],
	# Mina de Hierronegro: arañas, capullos con lo que llevaban sus víctimas y arcones de los mineros
	"spider": [["spider_silk", 0.7, 1, 2], ["spider_venom", 0.45, 1, 1]],
	"spider_spitter": [["spider_silk", 0.9, 1, 3], ["spider_venom", 0.3, 1, 1]],
	"spiderling": [["spider_silk", 0.25, 1, 1]],
	"spider_queen": [["queen_fang", 1.0, 1, 1], ["spider_venom", 1.0, 2, 3], ["spider_silk", 1.0, 3, 5]],
	"mine": [["iron_ore", 0.8, 1, 3], ["potion_health", 0.5, 1, 1], ["potion_cure", 0.5, 1, 1], ["old_coin", 0.6, 2, 5], ["lockpick", 0.3, 1, 2],
			["bread", 0.3, 1, 1], ["helm_iron", 0.06, 1, 1], ["weapon_axe", 0.06, 1, 1]],
	"cocoon": [["spider_silk", 0.8, 1, 2], ["old_coin", 0.5, 1, 4], ["bone_dust", 0.5, 1, 1], ["potion_health", 0.25, 1, 1], ["silver_ring", 0.12, 1, 1],
			["boots_leather", 0.08, 1, 1], ["lockpick", 0.2, 1, 1]],
	"boss_mine": [["potion_health", 1.0, 2, 3], ["potion_cure", 1.0, 1, 2], ["silver_ring", 0.8, 1, 2], ["old_coin", 1.0, 8, 15], ["armor_chain", 0.4, 1, 1],
			["iron_ore", 1.0, 2, 4], ["gauntlets_iron", 0.4, 1, 1]],
	# Arcón del jefe: el fruto de meses de asaltos en el camino
	"bandit_stash": [["silver_ring", 0.9, 1, 2], ["potion_health", 1.0, 1, 2], ["potion_stamina", 0.7, 1, 1], ["cheese", 1.0, 2, 4], ["arrow", 0.8, 10, 20],
			["armor_leather", 0.35, 1, 1], ["weapon_axe", 0.25, 1, 1], ["tunic_wool", 0.5, 1, 1]],
}


static func roll(table: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entries: Array = TABLES.get(table, [])
	for e: Array in entries:
		if rng.randf() < float(e[1]):
			var id: String = e[0]
			out.append({"id": id, "count": rng.randi_range(int(e[2]), int(e[3])), "name": ItemDB.display_name(id)})
	return out


static func gold_for(table: String, rng: RandomNumberGenerator) -> int:
	match table:
		"home":
			return rng.randi_range(3, 15)
		"inn":
			return rng.randi_range(10, 30)
		"ruins":
			return rng.randi_range(25, 60)
		"dungeon":
			return rng.randi_range(20, 50)
		"mine":
			return rng.randi_range(10, 30)
		"cocoon":
			return rng.randi_range(0, 12)
		"boss_mine":
			return rng.randi_range(120, 200)
		"secret":
			return rng.randi_range(60, 120)
		"boss":
			return rng.randi_range(150, 250)
		"bandit_stash":
			return rng.randi_range(120, 200)
		"barracks":
			return rng.randi_range(8, 25)
		"castle":
			return rng.randi_range(40, 90)
		"noble":
			return rng.randi_range(120, 220)
		"guard":
			return rng.randi_range(10, 30)
	return rng.randi_range(1, 10)
