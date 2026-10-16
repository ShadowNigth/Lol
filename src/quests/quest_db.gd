class_name QuestDB
extends RefCounted
## Definición de misiones (datos). Cada misión tiene etapas con objetivos
## (matar, recoger, llegar, hablar, esperar una bandera de historia) y
## recompensas (oro, objetos, reputación). El estado vive en GameState.quests (se guarda en la partida).

const FACTIONS := {
	"hojarrubia": "Aldea de Hojarrubia",
	"guardia": "Guardia de la Marca",
	"robledal": "Parroquia de Robledal",
	"penalba": "Casa de Peñalba",
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
	"hija_bram": {
		"title": "La hija de Bram",
		"giver": "bram",
		"type": "buscar persona",
		"requires_not_flag": "lina_rescued",
		"description": "Bram, el granjero de Robledal, no sabe nada de su hija Lina desde que salió hace tres días a vender queso a la Posada del Lobo Gris. Te ruega que averigües qué le ha pasado.",
		"stages": [
			{"text": "Pregunta por Lina en la Posada del Lobo Gris (habla con Ulrico, el posadero).", "objective": {"type": "talk", "target": "ulrico"}, "skip_if_flag": "lina_rescued",
				"say": "¿Lina, la de los quesos? Pasó por aquí hace tres días y siguió por el bosque hacia Robledal. Esa misma noche Edda vio fuego entre los árboles, a unos {dir:bandit_camp} de aquí. Si son los Cuervos, esos salteadores que asaltan a los carreteros... la chica está en apuros. Te lo señalo en el mapa.",
				"effects": {"flags": ["known_bandit_camp"]}},
			{"text": "Encuentra el campamento de los Cuervos (está señalado en tu mapa, tecla M).", "objective": {"type": "reach", "target": "bandit_camp"}, "skip_if_flag": "lina_rescued"},
			{"text": "Libera a Lina: quítale la llave a Garra, el jefe de los Cuervos, o fuerza la cerradura de la jaula.", "objective": {"type": "flag", "target": "jaula_cuervos_abierta"}, "skip_if_flag": "lina_rescued"},
			{"text": "Habla con Lina.", "objective": {"type": "talk", "target": "lina", "requires_flag": "jaula_cuervos_abierta"}, "skip_if_flag": "lina_rescued",
				"say": "¡Estás aquí de verdad! Creí que me venderían en el sur... Gracias, gracias. Vuelvo a Robledal ahora mismo por el sendero. ¡Dile a mi padre que estoy bien!",
				"effects": {"flags": ["lina_rescued"]}},
			{"text": "Vuelve a Robledal y habla con Bram.", "objective": {"type": "talk", "target": "bram"},
				"say": "¡Lina ha vuelto a casa! Llegó llorando y riendo a la vez... No tengo mucho, pero esto es tuyo, y el mejor queso de la granja. En Robledal nadie olvidará lo que has hecho."},
		],
		"rewards": {"gold": 150, "items": [{"id": "cheese", "count": 3}, {"id": "potion_health", "count": 1}], "reputation": {"robledal": 25}},
	},
	# --- Castillo de Peñalba ---
	"escolta_anselmo": {
		"title": "Remedios para Robledal",
		"giver": "anselmo",
		"type": "escoltar",
		"description": "El hermano Anselmo, sanador del castillo de Peñalba, quiere llevar sus remedios a Robledal, donde unas fiebres tienen a media aldea en cama. Con los Cuervos y los lobos rondando los caminos no se atreve a ir solo: necesita que alguien le acompañe.",
		"on_accept": {"flags": ["anselmo_escolta"]},
		"stages": [
			{"text": "Acompaña al hermano Anselmo hasta la aldea de Robledal. Te sigue: no le dejes atrás.", "objective": {"type": "escort", "target": "anselmo", "to": "robledal"},
				"effects": {"flags": ["anselmo_llego"]}},
			{"text": "Habla con Elena, la alcaldesa de Robledal.", "objective": {"type": "talk", "target": "elena"},
				"say": "¿Es el hermano Anselmo? ¡Por fin! Las fiebres ya se han llevado a dos vecinos. Gracias por traerlo sano y salvo por esos caminos. Toma, es poco, pero Robledal no olvida."},
		],
		"rewards": {"gold": 120, "items": [{"id": "potion_health", "count": 2}], "reputation": {"penalba": 15, "robledal": 15}},
	},
	"hierro_penalba": {
		"title": "Hierro para Peñalba",
		"giver": "garin",
		"type": "limpiar",
		"description": "Garin, el armero del castillo, no recibe hierro de la mina de Hierronegro desde hace semanas, y sin hierro no hay cotas ni espadas para la guardia. Los carreteros dicen que los mineros huyeron una noche y no han vuelto. Quiere que alguien vaya a la mina, al norte, averigüe qué ha pasado y lo arregle.",
		"stages": [
			{"text": "Ve a la mina de Hierronegro, al norte del castillo (está en tu mapa), y habla con Tobías, el capataz.", "objective": {"type": "talk", "target": "tobias"},
				"say": "¿Te manda Garin? Pues dile que su hierro está ahí abajo, con ellas. Al picar la veta honda abrimos una cueva vieja llena de seda... y esa noche salieron las arañas. Grandes como perros, y una reina como un buey, con una marca roja en el lomo, anidada en lo más hondo. Mientras ella viva no se irán. Llévate antídotos, que su mordedura quema la sangre, y no te pares delante de las escupidoras: te enredan los pies."},
			{"text": "Entra en la mina de Hierronegro.", "objective": {"type": "reach", "target": "mina_hierronegro"}},
			{"text": "Mata a la Reina Tejedora en lo más hondo de la mina.", "objective": {"type": "kill", "target": "spider_queen", "count": 1},
				"effects": {"flags": ["mina_limpia"]}},
			{"text": "Vuelve con Garin, el armero del castillo de Peñalba.", "objective": {"type": "talk", "target": "garin"},
				"say": "¿La reina, muerta? ¡Por el yunque de mi padre! Tobías ya ha mandado recado: mañana vuelven los picos a la galería honda. Toma: la forjé con la última barra de hierro negro que me quedaba, esperando a quien se la ganara. Corta como ninguna espada de la guardia."},
		],
		"rewards": {"gold": 180, "items": [{"id": "weapon_sword_penalba", "count": 1}, {"id": "potion_cure", "count": 2}], "reputation": {"penalba": 20, "guardia": 5}},
	},
	"cuervos_camino": {
		"title": "Limpiar los caminos",
		"giver": "aldric",
		"type": "matar",
		"description": "El capitán Aldric no tiene hombres suficientes para vigilar los caminos de la Marca. Paga a quien acabe con los salteadores que asaltan a los carreteros.",
		"stages": [
			{"text": "Acaba con salteadores de los Cuervos en los caminos o en su campamento (0/4).", "objective": {"type": "kill", "target": "bandit", "count": 4}},
			{"text": "Vuelve a hablar con el capitán Aldric en el castillo de Peñalba.", "objective": {"type": "talk", "target": "aldric"},
				"say": "Cuatro menos. Mis hombres dicen que los carreteros ya silban otra vez por el camino del oeste. Aquí tienes tu paga, y un yelmo de la guardia: te lo has ganado."},
		],
		"rewards": {"gold": 140, "items": [{"id": "helm_iron", "count": 1}], "reputation": {"guardia": 20}},
	},
}


static func get_quest(id: String) -> Dictionary:
	if QUESTS.has(id):
		return QUESTS[id]
	# Encargos generados (tablones de anuncios): la definición viaja con su estado
	var st: Variant = GameState.quests.get(id, null)
	if st is Dictionary and Bounties.valid_def((st as Dictionary).get("def", null)):
		return (st as Dictionary)["def"]
	return {}
