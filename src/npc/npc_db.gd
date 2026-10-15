class_name NpcDB
extends RefCounted
## Personajes con nombre de Hojarrubia: apariencia, función, horario,
## comercio, misiones y diálogos (rumores y saludos según reputación).

const NPCS := {
	"berta": {
		"name": "Berta", "role": "Posadera", "faction": "hojarrubia",
		"look": {"skin": Color(0.78, 0.58, 0.45), "hair": Color(0.55, 0.3, 0.15), "tunic": Color(0.5, 0.22, 0.18), "pants": Color(0.3, 0.22, 0.16), "apron": Color(0.85, 0.82, 0.72), "female": true},
		"quests": ["cripta_velmar"], "trade": "posada",
		"greet": ["¡Bienvenido a La Jarra del Roble! ¿Una jarra o un plato caliente?", "Hay cama y sopa para quien pague. ¿Qué te trae por aquí?"],
		"greet_friend": ["¡Mira quién vuelve! El héroe de Hojarrubia siempre tiene sitio junto al fuego."],
		"rumors": ["Dicen que bajo la capilla de Velmar duerme un señor coronado que nunca aceptó la muerte.",
				"El herrero Oswin anda buscando polvo de hueso. Cosas raras de su oficio.",
				"Los mercaderes del sur ya no pasan por el camino del este desde que los muertos rondan las ruinas."],
		"work": "inn_bar", "work_anim": "talk",
	},
	"oswin": {
		"name": "Oswin", "role": "Herrero", "faction": "hojarrubia",
		"look": {"skin": Color(0.7, 0.5, 0.38), "hair": Color(0.15, 0.12, 0.1), "tunic": Color(0.35, 0.3, 0.28), "pants": Color(0.25, 0.2, 0.15), "apron": Color(0.35, 0.22, 0.12), "beard": true},
		"quests": ["hierro_forja"], "trade": "herreria",
		"greet": ["El acero no se forja solo. ¿Necesitas algo?", "Cuidado con la fragua, está al rojo."],
		"greet_friend": ["Para ti, el mejor acero de la Marca."],
		"rumors": ["Una espada bien templada vale más que tres mal forjadas.",
				"Los esqueletos de las ruinas llevan hierro viejo. Herrumbre, nada más.",
				"Si pegas con una maza a un esqueleto, se le parten los huesos mejor que con una espada."],
		"work": "smithy_anvil", "work_anim": "work",
	},
	"rolf": {
		"name": "Rolf", "role": "Guardia", "faction": "guardia",
		"look": {"skin": Color(0.74, 0.55, 0.42), "hair": Color(0.6, 0.5, 0.3), "tunic": Color(0.25, 0.32, 0.5), "pants": Color(0.2, 0.2, 0.22), "armor": true, "beard": true},
		"quests": ["huesos_inquietos"], "trade": "",
		"greet": ["Mantén la espada envainada dentro de la aldea, forastero.", "Todo tranquilo... de momento."],
		"greet_friend": ["Gracias a ti dormimos mejor. La guardia no lo olvida."],
		"rumors": ["Por la noche se ven luces azules en el cementerio olvidado.",
				"La torre del sur vigila el camino. Desde arriba se ve hasta las ruinas.",
				"Si bloqueas en el momento justo, el enemigo queda vendido. Lo aprendí a las malas."],
		"patrol": true, "work_anim": "idle",
	},
	"mira": {
		"name": "Mira", "role": "Aldeana", "faction": "hojarrubia",
		"look": {"skin": Color(0.82, 0.64, 0.52), "hair": Color(0.85, 0.7, 0.35), "tunic": Color(0.3, 0.45, 0.35), "pants": Color(0.35, 0.28, 0.2), "female": true},
		"quests": ["anillo_perdido"], "trade": "",
		"greet": ["Hola... perdona, estoy un poco distraída.", "El agua del pozo es la más fresca de la Marca."],
		"greet_friend": ["¡Gracias otra vez por el anillo! Mi abuela estaría feliz."],
		"rumors": ["Los niños dicen que en la cripta hay paredes que se mueven.",
				"La posadera Berta conoce todas las historias de Velmar.",
				"Por la noche no salgo de casa. Ni loca."],
		"work": "well", "work_anim": "idle",
	},
	"tomas": {
		"name": "Tomás", "role": "Alcalde", "faction": "hojarrubia",
		"look": {"skin": Color(0.76, 0.56, 0.44), "hair": Color(0.7, 0.7, 0.7), "tunic": Color(0.45, 0.12, 0.3), "pants": Color(0.18, 0.15, 0.2), "beard": true, "cape": true},
		"quests": [], "trade": "",
		"greet": ["Soy Tomás, alcalde de Hojarrubia. Los forasteros con espada son bienvenidos... si ayudan.", "La aldea necesita gente valiente."],
		"greet_friend": ["Hojarrubia está en deuda contigo. Considérate un vecino más."],
		"rumors": ["Hojarrubia se fundó junto al gran roble rojo. De ahí el nombre.",
				"Cuando la capilla de Velmar cayó, sus monjes sellaron la cripta. Nadie sabe por qué.",
				"Ayuda a la gente de la aldea y te abrirán sus puertas."],
		"work": "plaza", "work_anim": "talk",
	},
}

const SHOPS := {
	"posada": {"gold": 300, "stock": [["bread", 6], ["apple", 8], ["potion_health", 3], ["potion_stamina", 3], ["torch_item", 4]]},
	"herreria": {"gold": 500, "stock": [["weapon_sword", 1], ["weapon_axe", 1], ["weapon_mace", 1], ["weapon_dagger", 2], ["weapon_bow", 1], ["arrow", 60], ["lockpick", 5], ["potion_health", 1]]},
}


static func get_npc(id: String) -> Dictionary:
	return NPCS.get(id, {})
