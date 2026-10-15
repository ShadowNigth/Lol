class_name ItemDB
extends RefCounted
## Base de datos de objetos. Cada objeto tiene nombre, descripción, categoría,
## valor, peso y rareza. Los objetos concretos del inventario son diccionarios
## {"id", "count"} que remiten a esta tabla (evita duplicaciones y facilita el
## guardado).

const ITEMS := {
	"gold": {"name": "Monedas de oro", "category": "misc", "value": 1, "weight": 0.0, "rarity": "common",
			"description": "La moneda corriente de la Marca de Vaelmoor."},
	"potion_health": {"name": "Poción de salud", "category": "potion", "value": 25, "weight": 0.3, "rarity": "common",
			"description": "Restaura 40 puntos de salud.", "effect": {"heal": 40.0}},
	"potion_stamina": {"name": "Poción de vigor", "category": "potion", "value": 20, "weight": 0.3, "rarity": "common",
			"description": "Restaura 60 puntos de aguante.", "effect": {"stamina": 60.0}},
	"potion_mana": {"name": "Poción de magia", "category": "potion", "value": 30, "weight": 0.3, "rarity": "uncommon",
			"description": "Restaura 40 puntos de magia.", "effect": {"mana": 40.0}},
	"bread": {"name": "Hogaza de pan", "category": "food", "value": 3, "weight": 0.4, "rarity": "common",
			"description": "Pan de centeno. Restaura un poco de salud.", "effect": {"heal": 8.0}},
	"apple": {"name": "Manzana", "category": "food", "value": 2, "weight": 0.2, "rarity": "common",
			"description": "Crujiente y dulce.", "effect": {"heal": 5.0, "stamina": 10.0}},
	"bone_dust": {"name": "Polvo de hueso", "category": "ingredient", "value": 6, "weight": 0.1, "rarity": "common",
			"description": "Restos de un no muerto. Útil para alquimistas."},
	"rusty_key": {"name": "Llave oxidada", "category": "key", "value": 0, "weight": 0.1, "rarity": "uncommon",
			"description": "Una llave antigua con el emblema de Velmar."},
	"old_coin": {"name": "Moneda antigua", "category": "misc", "value": 15, "weight": 0.05, "rarity": "uncommon",
			"description": "Acuñada antes de la caída de Velmar."},
	"silver_ring": {"name": "Anillo de plata", "category": "misc", "value": 60, "weight": 0.05, "rarity": "rare",
			"description": "Un anillo sencillo de plata labrada."},
	"torch_item": {"name": "Antorcha", "category": "tool", "value": 2, "weight": 0.5, "rarity": "common",
			"description": "Ilumina los lugares oscuros."},
	"key_crypt_velmar": {"name": "Llave de hierro de la cripta", "category": "key", "value": 0, "weight": 0.1, "rarity": "rare",
			"description": "Abre la puerta sellada de la sala del Señor de Velmar."},
	"velmar_crown": {"name": "Corona de Velmar", "category": "quest", "value": 250, "weight": 1.0, "rarity": "epic",
			"description": "La corona herrumbrosa del antiguo señor de la cripta."},
	"potion_cure": {"name": "Antídoto", "category": "potion", "value": 18, "weight": 0.3, "rarity": "common",
			"description": "Restaura 15 de salud y limpia la sangre.", "effect": {"heal": 15.0}},
	"lockpick": {"name": "Ganzúa", "category": "tool", "value": 5, "weight": 0.05, "rarity": "common",
			"description": "Para abrir cerraduras sencillas."},
	"book_velmar": {"name": "Crónica de Velmar", "category": "book", "value": 20, "weight": 1.0, "rarity": "uncommon",
			"description": "Relata cómo la capilla de Velmar fue abandonada tras la plaga.",
			"text": "En el año del invierno largo, los monjes de Velmar sellaron la cripta. Dicen que los muertos no descansan bajo el altar..."},
	"weapon_sword": {"name": "Espada larga", "category": "weapon", "value": 45, "weight": 3.0, "rarity": "common", "weapon": "res://data/weapons/sword.tres"},
	"weapon_rusty_sword": {"name": "Espada oxidada", "category": "weapon", "value": 8, "weight": 3.2, "rarity": "common", "weapon": "res://data/weapons/rusty_sword.tres"},
	"weapon_axe": {"name": "Hacha de guerra", "category": "weapon", "value": 60, "weight": 5.0, "rarity": "common", "weapon": "res://data/weapons/axe.tres"},
	"weapon_mace": {"name": "Maza de armas", "category": "weapon", "value": 55, "weight": 5.5, "rarity": "common", "weapon": "res://data/weapons/mace.tres"},
	"weapon_dagger": {"name": "Daga", "category": "weapon", "value": 30, "weight": 1.0, "rarity": "common", "weapon": "res://data/weapons/dagger.tres"},
}


static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func display_name(id: String) -> String:
	return str(get_def(id).get("name", id))
