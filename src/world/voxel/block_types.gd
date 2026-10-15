class_name BlockTypes
extends RefCounted
## Registro de tipos de bloque del mundo voxel (1 bloque = 1 m).
##
## Las propiedades se guardan en tablas empaquetadas indexadas por id para que
## el generador de mallas (que corre en hilos) pueda consultarlas rápido.

enum Shape { NONE, CUBE, CROSS, SLAB, STAIRS, TORCH, FENCE, LIQUID, SLAB_TOP }
enum Layer { OPAQUE, CUTOUT, WATER }
enum Sound { NONE, GRASS, DIRT, STONE, WOOD, SAND, SNOW, LEAVES }

# --- Identificadores -----------------------------------------------------------
const AIR := 0
const BEDROCK := 1
const STONE := 2
const DIRT := 3
const GRASS := 4
const SAND := 5
const GRAVEL := 6
const SNOW := 7
const COBBLE := 8
const STONE_BRICK := 9
const MOSSY_BRICK := 10
const CRACKED_BRICK := 11
const PLANKS := 12
const DARK_PLANKS := 13
const LOG := 14
const SPRUCE_LOG := 15
const BIRCH_LOG := 16
const LEAVES := 17
const SPRUCE_LEAVES := 18
const BIRCH_LEAVES := 19
const WATER := 20
const PATH := 21
const ROOF_TILE := 22
const PLASTER := 23
const TIMBER := 24
const GLASS := 25
const TORCH := 26
const TALL_GRASS := 27
const FLOWER_RED := 28
const FLOWER_YELLOW := 29
const FLOWER_BLUE := 30
const BUSH := 31
const HAY := 32
const THATCH := 33
const CLAY := 34
const SANDSTONE := 35
const ICE := 36
const MUD := 37
const DEAD_BUSH := 38
const MUSHROOM := 39
const BOOKSHELF := 40
const WOOL_RED := 41
const DUNGEON_BRICK := 42
const DUNGEON_FLOOR := 43
const CROP := 44
const REEDS := 45
const FENCE := 46
const MOSS_STONE := 47
const CHISELED := 48
const SPRUCE_PLANKS := 49
const IRON_BLOCK := 50
const COBWEB := 51
const CANVAS := 52
const CANVAS_SLAB := 53
const COBBLE_SLAB := 60
const PLANK_SLAB := 61
const ROOF_SLAB := 62
const BRICK_SLAB := 63
const THATCH_SLAB := 64
const PLANK_SLAB_TOP := 65
const BRICK_SLAB_TOP := 66
# Escaleras: id base + orientación (0 = N, 1 = E, 2 = S, 3 = O). "N" = el lado
# alto mira al norte (-Z), es decir, se sube caminando hacia el norte.
const ROOF_STAIRS := 70
const PLANK_STAIRS := 74
const COBBLE_STAIRS := 78
const BRICK_STAIRS := 82
const THATCH_STAIRS := 86
const DARK_STAIRS := 90
const CANVAS_STAIRS := 96
const MAX_ID := 100

# --- Texturas (nombre, variantes) en el orden de capas del Texture2DArray -----
const TEXTURES := [
	["bedrock", 1], ["stone", 3], ["dirt", 2], ["grass_top", 3], ["grass_side", 2],
	["sand", 2], ["gravel", 2], ["snow", 2], ["snow_side", 1], ["cobble", 3],
	["stone_brick", 2], ["mossy_brick", 2], ["cracked_brick", 1], ["planks", 2],
	["dark_planks", 2], ["spruce_planks", 1], ["log_side", 1], ["log_top", 1],
	["spruce_log_side", 1], ["spruce_log_top", 1], ["birch_log_side", 1], ["birch_log_top", 1],
	["leaves", 2], ["spruce_leaves", 1], ["birch_leaves", 1], ["water", 1],
	["path_top", 2], ["path_side", 1], ["roof_tile", 2], ["plaster", 2], ["timber", 1],
	["glass", 1], ["torch", 1], ["tall_grass", 2], ["flower_red", 1], ["flower_yellow", 1],
	["flower_blue", 1], ["bush", 1], ["hay_side", 1], ["hay_top", 1], ["thatch", 2],
	["clay", 1], ["sandstone_side", 1], ["sandstone_top", 1], ["ice", 1], ["mud", 2],
	["dead_bush", 1], ["mushroom", 1], ["bookshelf", 1], ["wool_red", 1],
	["dungeon_brick", 3], ["dungeon_floor", 2], ["crop", 1], ["reeds", 1],
	["moss_stone", 2], ["chiseled", 1], ["iron_block", 1], ["cobweb", 1], ["canvas", 4],
]

# --- Tablas (rellenadas en _static_init) ------------------------------------
static var shape := PackedByteArray()
static var layer := PackedByteArray()
static var opaque := PackedByteArray()       # cubo opaco completo: oculta caras vecinas
static var solid := PackedByteArray()        # genera colisión
static var tinted := PackedByteArray()       # se multiplica por el tinte del bioma
static var sound := PackedByteArray()
static var facing := PackedByteArray()       # orientación de escaleras
static var emits_light := PackedByteArray()
static var tex_top := PackedInt32Array()
static var tex_side := PackedInt32Array()
static var tex_bottom := PackedInt32Array()
static var tex_variants := PackedByteArray() # variantes del lado/superior (mismo número)
static var names: Array[String] = []
static var texture_base: Dictionary = {}     # nombre -> primera capa
static var texture_variants: Dictionary = {} # nombre -> nº de variantes
static var texture_layer_count: int = 0


static func _static_init() -> void:
	var layer_index := 0
	for entry: Array in TEXTURES:
		texture_base[entry[0]] = layer_index
		texture_variants[entry[0]] = entry[1]
		layer_index += int(entry[1])
	texture_layer_count = layer_index

	shape.resize(MAX_ID)
	layer.resize(MAX_ID)
	opaque.resize(MAX_ID)
	solid.resize(MAX_ID)
	tinted.resize(MAX_ID)
	sound.resize(MAX_ID)
	facing.resize(MAX_ID)
	emits_light.resize(MAX_ID)
	tex_top.resize(MAX_ID)
	tex_side.resize(MAX_ID)
	tex_bottom.resize(MAX_ID)
	tex_variants.resize(MAX_ID)
	names.resize(MAX_ID)
	for i in MAX_ID:
		names[i] = ""

	_cube(BEDROCK, "Lecho de roca", "bedrock", "bedrock", "bedrock", Sound.STONE)
	_cube(STONE, "Piedra", "stone", "stone", "stone", Sound.STONE)
	_cube(DIRT, "Tierra", "dirt", "dirt", "dirt", Sound.DIRT)
	_cube(GRASS, "Hierba", "grass_top", "grass_side", "dirt", Sound.GRASS)
	tinted[GRASS] = 1
	_cube(SAND, "Arena", "sand", "sand", "sand", Sound.SAND)
	_cube(GRAVEL, "Grava", "gravel", "gravel", "gravel", Sound.STONE)
	_cube(SNOW, "Nieve", "snow", "snow_side", "dirt", Sound.SNOW)
	_cube(COBBLE, "Adoquín", "cobble", "cobble", "cobble", Sound.STONE)
	_cube(STONE_BRICK, "Sillería", "stone_brick", "stone_brick", "stone_brick", Sound.STONE)
	_cube(MOSSY_BRICK, "Sillería musgosa", "mossy_brick", "mossy_brick", "mossy_brick", Sound.STONE)
	_cube(CRACKED_BRICK, "Sillería agrietada", "cracked_brick", "cracked_brick", "cracked_brick", Sound.STONE)
	_cube(PLANKS, "Tablones de roble", "planks", "planks", "planks", Sound.WOOD)
	_cube(DARK_PLANKS, "Tablones oscuros", "dark_planks", "dark_planks", "dark_planks", Sound.WOOD)
	_cube(SPRUCE_PLANKS, "Tablones de abeto", "spruce_planks", "spruce_planks", "spruce_planks", Sound.WOOD)
	_cube(LOG, "Tronco de roble", "log_top", "log_side", "log_top", Sound.WOOD)
	_cube(SPRUCE_LOG, "Tronco de abeto", "spruce_log_top", "spruce_log_side", "spruce_log_top", Sound.WOOD)
	_cube(BIRCH_LOG, "Tronco de abedul", "birch_log_top", "birch_log_side", "birch_log_top", Sound.WOOD)
	_leaves(LEAVES, "Hojas de roble", "leaves")
	_leaves(SPRUCE_LEAVES, "Hojas de abeto", "spruce_leaves")
	_leaves(BIRCH_LEAVES, "Hojas de abedul", "birch_leaves")
	_define(WATER, "Agua", Shape.LIQUID, Layer.WATER, false, false, "water", "water", "water", Sound.NONE)
	_cube(PATH, "Camino", "path_top", "path_side", "dirt", Sound.DIRT)
	_cube(ROOF_TILE, "Tejas", "roof_tile", "roof_tile", "roof_tile", Sound.STONE)
	_cube(PLASTER, "Enlucido", "plaster", "plaster", "plaster", Sound.STONE)
	_cube(TIMBER, "Viga", "timber", "timber", "timber", Sound.WOOD)
	_define(GLASS, "Ventana", Shape.CUBE, Layer.CUTOUT, false, true, "glass", "glass", "glass", Sound.STONE)
	_define(TORCH, "Antorcha", Shape.TORCH, Layer.CUTOUT, false, false, "torch", "torch", "torch", Sound.NONE)
	emits_light[TORCH] = 1
	_plant(TALL_GRASS, "Hierba alta", "tall_grass", true)
	_plant(FLOWER_RED, "Amapola", "flower_red", false)
	_plant(FLOWER_YELLOW, "Diente de león", "flower_yellow", false)
	_plant(FLOWER_BLUE, "Aciano", "flower_blue", false)
	_plant(BUSH, "Arbusto", "bush", true)
	_plant(DEAD_BUSH, "Matorral seco", "dead_bush", false)
	_plant(MUSHROOM, "Seta", "mushroom", false)
	_plant(CROP, "Trigo", "crop", false)
	_plant(REEDS, "Juncos", "reeds", true)
	_plant(COBWEB, "Telaraña", "cobweb", false)
	_cube(HAY, "Paja", "hay_top", "hay_side", "hay_top", Sound.GRASS)
	_cube(THATCH, "Techo de paja", "thatch", "thatch", "thatch", Sound.GRASS)
	_cube(CLAY, "Arcilla", "clay", "clay", "clay", Sound.STONE)
	_cube(SANDSTONE, "Arenisca", "sandstone_top", "sandstone_side", "sandstone_top", Sound.STONE)
	_define(ICE, "Hielo", Shape.CUBE, Layer.OPAQUE, true, true, "ice", "ice", "ice", Sound.STONE)
	_cube(MUD, "Barro", "mud", "mud", "mud", Sound.DIRT)
	_cube(BOOKSHELF, "Estantería", "planks", "bookshelf", "planks", Sound.WOOD)
	_cube(WOOL_RED, "Tela roja", "wool_red", "wool_red", "wool_red", Sound.GRASS)
	_cube(DUNGEON_BRICK, "Ladrillo de mazmorra", "dungeon_brick", "dungeon_brick", "dungeon_brick", Sound.STONE)
	_cube(DUNGEON_FLOOR, "Losas de mazmorra", "dungeon_floor", "dungeon_brick", "dungeon_floor", Sound.STONE)
	_cube(MOSS_STONE, "Piedra musgosa", "moss_stone", "moss_stone", "moss_stone", Sound.STONE)
	_cube(CHISELED, "Piedra tallada", "chiseled", "chiseled", "chiseled", Sound.STONE)
	_cube(IRON_BLOCK, "Hierro", "iron_block", "iron_block", "iron_block", Sound.STONE)
	_cube(CANVAS, "Lona", "canvas", "canvas", "canvas", Sound.GRASS)
	_define(FENCE, "Valla", Shape.FENCE, Layer.OPAQUE, false, true, "planks", "planks", "planks", Sound.WOOD)

	_slab(COBBLE_SLAB, "Losa de adoquín", "cobble", Sound.STONE, false)
	_slab(PLANK_SLAB, "Losa de madera", "planks", Sound.WOOD, false)
	_slab(ROOF_SLAB, "Losa de tejas", "roof_tile", Sound.STONE, false)
	_slab(BRICK_SLAB, "Losa de sillería", "stone_brick", Sound.STONE, false)
	_slab(THATCH_SLAB, "Losa de paja", "thatch", Sound.GRASS, false)
	_slab(PLANK_SLAB_TOP, "Losa de madera (alta)", "planks", Sound.WOOD, true)
	_slab(BRICK_SLAB_TOP, "Losa de sillería (alta)", "stone_brick", Sound.STONE, true)
	_slab(CANVAS_SLAB, "Lona (remate)", "canvas", Sound.GRASS, false)

	_stairs(ROOF_STAIRS, "Escalera de tejas", "roof_tile", Sound.STONE)
	_stairs(PLANK_STAIRS, "Escalera de madera", "planks", Sound.WOOD)
	_stairs(COBBLE_STAIRS, "Escalera de adoquín", "cobble", Sound.STONE)
	_stairs(BRICK_STAIRS, "Escalera de sillería", "stone_brick", Sound.STONE)
	_stairs(THATCH_STAIRS, "Escalera de paja", "thatch", Sound.GRASS)
	_stairs(DARK_STAIRS, "Escalera oscura", "dark_planks", Sound.WOOD)
	_stairs(CANVAS_STAIRS, "Faldón de lona", "canvas", Sound.GRASS)


static func _define(id: int, display_name: String, shp: int, lyr: int, is_opaque: bool, is_solid: bool,
		top: String, side: String, bottom: String, snd: int) -> void:
	names[id] = display_name
	shape[id] = shp
	layer[id] = lyr
	opaque[id] = 1 if is_opaque else 0
	solid[id] = 1 if is_solid else 0
	sound[id] = snd
	tex_top[id] = int(texture_base[top])
	tex_side[id] = int(texture_base[side])
	tex_bottom[id] = int(texture_base[bottom])
	tex_variants[id] = int(texture_variants[side])


static func _cube(id: int, display_name: String, top: String, side: String, bottom: String, snd: int) -> void:
	_define(id, display_name, Shape.CUBE, Layer.OPAQUE, true, true, top, side, bottom, snd)


static func _leaves(id: int, display_name: String, tex: String) -> void:
	_define(id, display_name, Shape.CUBE, Layer.CUTOUT, false, true, tex, tex, tex, Sound.LEAVES)
	tinted[id] = 1


static func _plant(id: int, display_name: String, tex: String, is_tinted: bool) -> void:
	_define(id, display_name, Shape.CROSS, Layer.CUTOUT, false, false, tex, tex, tex, Sound.GRASS)
	tinted[id] = 1 if is_tinted else 0


static func _slab(id: int, display_name: String, tex: String, snd: int, top_half: bool) -> void:
	_define(id, display_name, Shape.SLAB_TOP if top_half else Shape.SLAB, Layer.OPAQUE, false, true, tex, tex, tex, snd)


static func _stairs(base_id: int, display_name: String, tex: String, snd: int) -> void:
	for f in 4:
		_define(base_id + f, display_name, Shape.STAIRS, Layer.OPAQUE, false, true, tex, tex, tex, snd)
		facing[base_id + f] = f


## Devuelve el id de escalera girado `quarter_turns` veces 90° en sentido horario
## (visto desde arriba). Para bloques sin orientación devuelve el mismo id.
static func rotate_block(id: int, quarter_turns: int) -> int:
	if id < MAX_ID and shape[id] == Shape.STAIRS:
		var base := id - int(facing[id])
		return base + (int(facing[id]) + quarter_turns) % 4
	return id


static func stairs(base_id: int, dir: int) -> int:
	return base_id + (dir % 4)


static func is_solid(id: int) -> bool:
	return id < MAX_ID and solid[id] == 1


static func sound_name(id: int) -> String:
	match int(sound[id]) if id < MAX_ID else 0:
		Sound.GRASS, Sound.LEAVES:
			return "step_grass"
		Sound.DIRT:
			return "step_dirt"
		Sound.STONE:
			return "step_stone"
		Sound.WOOD:
			return "step_wood"
		Sound.SAND:
			return "step_dirt"
		Sound.SNOW:
			return "step_snow"
	return "step_grass"
