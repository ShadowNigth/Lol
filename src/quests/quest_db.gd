class_name QuestDB
extends RefCounted
## Definición de misiones (datos). Cada misión tiene etapas con objetivos
## (matar, recoger, llegar, hablar) y recompensas (oro, objetos, reputación,
## experiencia). El estado vive en GameState.quests (se guarda en la partida).

const FACTIONS := {
	"hojarrubia": "Aldea de Hojarrubia",
	"guardia": "Guardia de la Marca",
	"robledal": "Parroquia de Robledal",
}

const QUESTS := {
	"huesos_inquietos": {
		"title": "Huesos inquietos",
		"giver": "rolf",
		"type": "matar",
		"description": "El guardia Rolf dice que los muertos del cementerio olvidado han vuelto a levantarse. Quiere que alguien acabe con ellos antes de que lleguen a la aldea.",
		"stages": [
			{"text": "Destruye a los esqueletos del cementerio y la capilla (0/3).", "objective": {"type": "kill", "target": "skeleton", "count": 3}},
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
	# --- Fase 6: misiones de la región (posada del camino, Robledal, túmulo y cubil) ---
	"lobos_del_camino": {
		"title": "Lobos en el camino",
		"giver": "ulrico",
		"type": "cazar",
		"description": "Ulrico, el posadero del Lobo Gris, dice que las manadas atacan a los viajeros del camino del oeste. Paga por cada lobo menos en los bosques.",
		"stages": [
			{"text": "Caza lobos en los bosques de la región (0/5).", "objective": {"type": "kill", "target": "wolf", "count": 5}},
			{"text": "Vuelve a la Posada del Lobo Gris y habla con Ulrico.", "objective": {"type": "talk", "target": "ulrico"}},
		],
		"rewards": {"gold": 90, "items": [{"id": "potion_health", "count": 2}], "reputation": {"robledal": 10}},
	},
	"piel_alfa": {
		"title": "Colmillo Negro",
		"giver": "edda",
		"type": "cazar",
		"description": "Edda, la cazadora, sigue el rastro de un lobo alfa enorme y negro que guía a las manadas desde una cueva del norte. Quiere su piel como prueba.",
		"stages": [
			{"text": "Encuentra el Cubil de Colmillo Negro (míralo en el mapa, tecla M) y entra.", "objective": {"type": "reach", "target": "cave_lobos"}},
			{"text": "Acaba con Colmillo Negro y consigue su piel.", "objective": {"type": "collect", "target": "alpha_pelt", "count": 1}},
			{"text": "Lleva la piel a Edda, en la Posada del Lobo Gris.", "objective": {"type": "talk", "target": "edda"}},
		],
		"rewards": {"gold": 160, "items": [{"id": "armor_leather", "count": 1}], "remove_items": [{"id": "alpha_pelt", "count": 1}], "reputation": {"robledal": 15}},
		"requires_reputation": {"robledal": 10},
	},
	"reyes_grises": {
		"title": "El túmulo de los Reyes Grises",
		"giver": "elena",
		"type": "investigar",
		"description": "Elena, la alcaldesa de Robledal, cuenta que alguien ha abierto el viejo túmulo de los Reyes Grises y que desde entonces los muertos rondan los campos de noche.",
		"stages": [
			{"text": "Entra en el Túmulo de los Reyes Grises, cerca de Robledal.", "objective": {"type": "reach", "target": "barrow_grises"}},
			{"text": "Destruye al Rey Gris en lo más hondo del túmulo.", "objective": {"type": "kill", "target": "barrow_king", "count": 1}},
			{"text": "Cuéntaselo a Elena, en Robledal.", "objective": {"type": "talk", "target": "elena"}},
		],
		"rewards": {"gold": 180, "items": [{"id": "shield_iron", "count": 1}], "reputation": {"robledal": 20}},
	},
}


static func get_quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})
