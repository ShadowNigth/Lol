class_name QuestDB
extends RefCounted
## Definición de misiones (datos). Cada misión tiene etapas con objetivos
## (matar, recoger, llegar, hablar) y recompensas (oro, objetos, reputación,
## experiencia). El estado vive en GameState.quests (se guarda en la partida).

const FACTIONS := {
	"hojarrubia": "Aldea de Hojarrubia",
	"guardia": "Guardia de la Marca",
}

const QUESTS := {
	"huesos_inquietos": {
		"title": "Huesos inquietos",
		"giver": "rolf",
		"type": "matar",
		"description": "El guardia Rolf dice que los muertos del cementerio olvidado han vuelto a levantarse. Quiere que alguien acabe con ellos antes de que lleguen a la aldea.",
		"stages": [
			{"text": "Destruye a los esqueletos del cementerio y la capilla (0/3).", "objective": {"type": "kill", "target": "skeleton_warrior", "count": 3}},
			{"text": "Vuelve a hablar con el guardia Rolf.", "objective": {"type": "talk", "target": "rolf"}},
		],
		"rewards": {"gold": 60, "items": [{"id": "potion_health", "count": 2}], "reputation": {"guardia": 10, "hojarrubia": 5}},
	},
	"cripta_velmar": {
		"title": "La cripta de Velmar",
		"giver": "berta",
		"type": "explorar",
		"description": "Berta, la posadera, cuenta que bajo la capilla de Velmar duerme un antiguo señor coronado. Si alguien recuperase su corona, el pueblo podría dormir tranquilo... y Berta pagaría bien.",
		"stages": [
			{"text": "Encuentra la llave de la cripta en la capilla en ruinas.", "objective": {"type": "collect", "target": "rusty_key", "count": 1}},
			{"text": "Entra en la cripta de Velmar.", "objective": {"type": "reach", "target": "crypt_velmar"}},
			{"text": "Derrota al Señor de Velmar y recupera su corona.", "objective": {"type": "collect", "target": "velmar_crown", "count": 1}},
			{"text": "Lleva la corona a Berta, en la posada La Jarra del Roble.", "objective": {"type": "talk", "target": "berta"}},
		],
		"rewards": {"gold": 200, "items": [], "remove_items": [{"id": "velmar_crown", "count": 1}], "reputation": {"hojarrubia": 20}},
	},
	"anillo_perdido": {
		"title": "El anillo de Mira",
		"giver": "mira",
		"type": "recuperar",
		"description": "Mira perdió el anillo de plata de su abuela cuando huyó de los esqueletos cerca de las ruinas. Cree que algún saqueador lo escondió en la cripta.",
		"stages": [
			{"text": "Encuentra un anillo de plata.", "objective": {"type": "collect", "target": "silver_ring", "count": 1}},
			{"text": "Devuélvele el anillo a Mira, junto al pozo.", "objective": {"type": "talk", "target": "mira"}},
		],
		"rewards": {"gold": 40, "items": [{"id": "potion_mana", "count": 1}], "remove_items": [{"id": "silver_ring", "count": 1}], "reputation": {"hojarrubia": 10}},
		"requires_reputation": {"hojarrubia": 0},
	},
	"hierro_forja": {
		"title": "Material para la forja",
		"giver": "oswin",
		"type": "entregar",
		"description": "Oswin, el herrero, necesita polvo de hueso para templar el acero según una vieja receta de su maestro.",
		"stages": [
			{"text": "Consigue 3 puñados de polvo de hueso.", "objective": {"type": "collect", "target": "bone_dust", "count": 3}},
			{"text": "Entrega el polvo de hueso a Oswin en la herrería.", "objective": {"type": "talk", "target": "oswin"}},
		],
		"rewards": {"gold": 30, "items": [{"id": "weapon_dagger", "count": 1}], "remove_items": [{"id": "bone_dust", "count": 3}], "reputation": {"hojarrubia": 5}},
	},
}


static func get_quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})
