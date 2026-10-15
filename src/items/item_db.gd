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
	"cheese": {"name": "Cuña de queso", "category": "food", "value": 5, "weight": 0.3, "rarity": "common",
			"description": "Queso curado de oveja. Restaura salud y aguante.", "effect": {"heal": 12.0, "stamina": 15.0}},
	"wolf_pelt": {"name": "Piel de lobo", "category": "ingredient", "value": 18, "weight": 1.5, "rarity": "common",
			"description": "Piel gruesa de lobo. Los peleteros y cazadores la pagan bien."},
	"wolf_fang": {"name": "Colmillo de lobo", "category": "ingredient", "value": 6, "weight": 0.05, "rarity": "common",
			"description": "Colmillo afilado. Algunos lo llevan como amuleto."},
	"alpha_pelt": {"name": "Piel de Colmillo Negro", "category": "quest", "value": 120, "weight": 2.5, "rarity": "rare",
			"description": "La piel negra y enorme del lobo alfa que guiaba a las manadas del norte."},
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
			"description": "Para forzar cerraduras de cofres, jaulas y puertas. Puede romperse al fallar; la habilidad Ganzúas, la agilidad y la suerte mejoran las probabilidades."},
	"key_cuervos": {"name": "Llave de los Cuervos", "category": "key", "value": 0, "weight": 0.1, "rarity": "rare",
			"description": "Llave de hierro negro con un cuervo grabado. Abre la jaula y el arcón del campamento de los Cuervos."},
	"nota_cuervos": {"name": "Nota manchada de grasa", "category": "book", "value": 2, "weight": 0.05, "rarity": "uncommon",
			"description": "Un papel doblado que llevaba encima Garra, el jefe de los Cuervos.",
			"text": "Garra: la muchacha de los quesos vale buen dinero en Puerto Sal. Que nadie le ponga la mano encima. El carro sale con la luna nueva por el vado del sur; no faltes. —S."},
	"book_velmar": {"name": "Crónica de Velmar", "category": "book", "value": 20, "weight": 1.0, "rarity": "uncommon",
			"description": "Relata cómo la capilla de Velmar fue abandonada tras la plaga.",
			"text": "En el año del invierno largo, los monjes de Velmar sellaron la cripta. Dicen que los muertos no descansan bajo el altar..."},
	"arrow": {"name": "Flecha", "category": "ammo", "value": 1, "weight": 0.05, "rarity": "common",
			"description": "Flecha de fresno con punta de hierro."},
	"weapon_bow": {"name": "Arco de caza", "category": "weapon", "value": 50, "weight": 2.0, "rarity": "common", "weapon": "res://data/weapons/bow.tres"},
	"weapon_sword": {"name": "Espada larga", "category": "weapon", "value": 45, "weight": 3.0, "rarity": "common", "weapon": "res://data/weapons/sword.tres"},
	"weapon_rusty_sword": {"name": "Espada oxidada", "category": "weapon", "value": 8, "weight": 3.2, "rarity": "common", "weapon": "res://data/weapons/rusty_sword.tres"},
	"weapon_axe": {"name": "Hacha de guerra", "category": "weapon", "value": 60, "weight": 5.0, "rarity": "common", "weapon": "res://data/weapons/axe.tres"},
	"weapon_mace": {"name": "Maza de armas", "category": "weapon", "value": 55, "weight": 5.5, "rarity": "common", "weapon": "res://data/weapons/mace.tres"},
	"weapon_dagger": {"name": "Daga", "category": "weapon", "value": 30, "weight": 1.0, "rarity": "common", "weapon": "res://data/weapons/dagger.tres"},

	# --- Ropa, armaduras y escudos (equipables por ranuras; ver Equipment) ---
	# armor: valor base · armor_type: cloth/light/heavy (habilidad que lo mejora)
	# look: aspecto en los brazos de primera persona · resist/bonus: efectos extra
	"tunic_wool": {"name": "Camisa de lana", "category": "clothing", "value": 6, "weight": 1.0, "rarity": "common",
			"slot": "chest", "armor": 1, "armor_type": "cloth", "look": "cloth",
			"description": "Ropa sencilla de viaje, abrigada y remendada."},
	"robe_apprentice": {"name": "Túnica de aprendiz", "category": "clothing", "value": 55, "weight": 1.5, "rarity": "uncommon",
			"slot": "chest", "armor": 2, "armor_type": "cloth", "look": "robe",
			"resist": {"fire": 0.1, "frost": 0.1}, "bonus": {"max_mana": 15.0},
			"description": "Túnica azul bordada con runas de protección. Aumenta la magia y protege del fuego y la escarcha."},
	"hood_leather": {"name": "Capucha de cuero", "category": "armor", "value": 18, "weight": 1.0, "rarity": "common",
			"slot": "head", "armor": 4, "armor_type": "light",
			"description": "Capucha de cuero curtido con cogulla."},
	"armor_leather": {"name": "Jubón de cuero", "category": "armor", "value": 60, "weight": 5.0, "rarity": "common",
			"slot": "chest", "armor": 10, "armor_type": "light", "look": "leather",
			"description": "Jubón de cuero endurecido con remaches. Protege sin estorbar."},
	"gloves_leather": {"name": "Guantes de cuero", "category": "armor", "value": 12, "weight": 0.5, "rarity": "common",
			"slot": "hands", "armor": 3, "armor_type": "light", "look": "leather_gloves",
			"description": "Guantes de cuero con refuerzo en los nudillos."},
	"pants_leather": {"name": "Calzas de cuero", "category": "armor", "value": 25, "weight": 2.5, "rarity": "common",
			"slot": "legs", "armor": 6, "armor_type": "light",
			"description": "Calzas de cuero acolchado."},
	"boots_leather": {"name": "Botas de cuero", "category": "armor", "value": 15, "weight": 1.5, "rarity": "common",
			"slot": "feet", "armor": 3, "armor_type": "light",
			"description": "Botas altas de caña, buenas para el camino."},
	"helm_iron": {"name": "Yelmo de hierro", "category": "armor", "value": 70, "weight": 3.0, "rarity": "uncommon",
			"slot": "head", "armor": 8, "armor_type": "heavy",
			"description": "Yelmo de hierro con nasal."},
	"armor_chain": {"name": "Cota de malla", "category": "armor", "value": 160, "weight": 12.0, "rarity": "uncommon",
			"slot": "chest", "armor": 18, "armor_type": "heavy", "look": "chain",
			"description": "Miles de anillas de hierro remachadas sobre un gambesón. Pesada pero fiable."},
	"gauntlets_iron": {"name": "Guanteletes de hierro", "category": "armor", "value": 55, "weight": 2.0, "rarity": "uncommon",
			"slot": "hands", "armor": 5, "armor_type": "heavy", "look": "gauntlets",
			"description": "Guanteletes de láminas articuladas."},
	"greaves_iron": {"name": "Grebas de hierro", "category": "armor", "value": 80, "weight": 6.0, "rarity": "uncommon",
			"slot": "legs", "armor": 10, "armor_type": "heavy",
			"description": "Grebas y quijotes de hierro."},
	"boots_iron": {"name": "Escarpes de hierro", "category": "armor", "value": 50, "weight": 3.0, "rarity": "uncommon",
			"slot": "feet", "armor": 5, "armor_type": "heavy",
			"description": "Calzado de láminas de hierro."},
	"shield_wood": {"name": "Escudo redondo de madera", "category": "shield", "value": 25, "weight": 4.0, "rarity": "common",
			"slot": "offhand", "armor": 3, "armor_type": "light", "block": 0.8, "model": "shield",
			"description": "Escudo de tablas con umbo de hierro, pintado con los colores de la Marca. Detiene el 80% del daño al bloquear."},
	"shield_iron": {"name": "Escudo de hierro", "category": "shield", "value": 90, "weight": 7.0, "rarity": "uncommon",
			"slot": "offhand", "armor": 6, "armor_type": "heavy", "block": 0.9, "model": "shield_iron",
			"description": "Escudo de cometa forjado en hierro. Detiene el 90% del daño al bloquear."},
	"velmar_helm": {"name": "Yelmo del Señor de Velmar", "category": "armor", "value": 300, "weight": 3.5, "rarity": "epic",
			"slot": "head", "armor": 12, "armor_type": "heavy", "resist": {"frost": 0.25, "poison": 0.25},
			"description": "Yelmo antiguo de un caballero de Velmar. Su metal frío resiste la escarcha y el veneno."},
}


static func get_def(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	# Llaves de mazmorras generadas: "key_<id de mazmorra>" (ver DungeonDB)
	if id.begins_with("key_") and DungeonDB.DUNGEONS.has(id.substr(4)):
		return {"name": "Llave de hierro (%s)" % DungeonDB.display_name(id.substr(4)), "category": "key", "value": 0,
				"weight": 0.1, "rarity": "rare", "description": "Abre la puerta cerrada de %s." % DungeonDB.display_name(id.substr(4))}
	return {}


static func exists(id: String) -> bool:
	return not get_def(id).is_empty()


static func display_name(id: String) -> String:
	return str(get_def(id).get("name", id))
