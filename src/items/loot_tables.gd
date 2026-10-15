class_name LootTables
extends RefCounted
## Tablas de botín: cada entrada [id, probabilidad, mín, máx].

const TABLES := {
	"skeleton": [["bone_dust", 0.6, 1, 2], ["old_coin", 0.25, 1, 2], ["potion_health", 0.15, 1, 1], ["weapon_rusty_sword", 0.08, 1, 1]],
	"home": [["bread", 0.7, 1, 2], ["apple", 0.5, 1, 3], ["potion_health", 0.3, 1, 1], ["lockpick", 0.3, 1, 2]],
	"inn": [["bread", 0.8, 1, 3], ["potion_stamina", 0.5, 1, 1], ["silver_ring", 0.1, 1, 1]],
	"dungeon": [["potion_health", 0.7, 1, 2], ["old_coin", 0.8, 2, 6], ["potion_stamina", 0.4, 1, 1], ["silver_ring", 0.15, 1, 1], ["weapon_axe", 0.08, 1, 1]],
	"secret": [["silver_ring", 0.8, 1, 2], ["potion_health", 1.0, 2, 3], ["potion_mana", 0.8, 1, 2], ["weapon_mace", 0.3, 1, 1], ["old_coin", 1.0, 5, 10]],
	"boss": [["velmar_crown", 1.0, 1, 1], ["potion_health", 1.0, 2, 3], ["silver_ring", 0.6, 1, 1], ["old_coin", 1.0, 8, 15]],
	"skeleton_lord": [["bone_dust", 1.0, 3, 5], ["old_coin", 1.0, 4, 8]],
	"ruins": [["potion_health", 0.9, 1, 2], ["old_coin", 0.8, 2, 5], ["book_velmar", 1.0, 1, 1], ["rusty_key", 1.0, 1, 1], ["potion_mana", 0.4, 1, 1]],
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
		"secret":
			return rng.randi_range(60, 120)
		"boss":
			return rng.randi_range(150, 250)
	return rng.randi_range(1, 10)
