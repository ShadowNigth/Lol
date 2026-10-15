class_name ChunkData
extends RefCounted
## Datos de un chunk de 16 x 16 columnas con un borde de 1 bloque replicado
## (18 x 18) para poder generar la malla sin consultar a los vecinos.

const SIZE := 16
const PAD := 18
const HEIGHT := 128
const LAYER := PAD * PAD

var cx: int = 0
var cz: int = 0
var blocks := PackedByteArray()
var tints := PackedColorArray()        # tinte de vegetación por columna (PAD*PAD)
var max_y: int = 1                     # y máxima no vacía (incluye borde)
var entities: Array[Dictionary] = []   # objetos/criaturas a instanciar (solo zona interior)
var biome_ids := PackedByteArray()     # bioma por columna interior (SIZE*SIZE)


func _init(chunk_x: int = 0, chunk_z: int = 0) -> void:
	cx = chunk_x
	cz = chunk_z
	blocks.resize(PAD * PAD * HEIGHT)
	tints.resize(PAD * PAD)
	tints.fill(Color(1, 1, 1))
	biome_ids.resize(SIZE * SIZE)


func origin_x() -> int:
	return cx * SIZE


func origin_z() -> int:
	return cz * SIZE


static func index(px: int, y: int, pz: int) -> int:
	return px + pz * PAD + y * LAYER


## Coordenadas mundiales -> valor, o -1 si cae fuera de la zona con borde.
func get_world(wx: int, wy: int, wz: int) -> int:
	var px := wx - cx * SIZE + 1
	var pz := wz - cz * SIZE + 1
	if px < 0 or px >= PAD or pz < 0 or pz >= PAD or wy < 0 or wy >= HEIGHT:
		return -1
	return blocks[px + pz * PAD + wy * LAYER]


func set_world(wx: int, wy: int, wz: int, id: int) -> void:
	var px := wx - cx * SIZE + 1
	var pz := wz - cz * SIZE + 1
	if px < 0 or px >= PAD or pz < 0 or pz >= PAD or wy < 1 or wy >= HEIGHT - 1:
		return
	blocks[px + pz * PAD + wy * LAYER] = id
	if id != 0 and wy > max_y:
		max_y = wy


func contains_world_core(wx: int, wz: int) -> bool:
	var lx := wx - cx * SIZE
	var lz := wz - cz * SIZE
	return lx >= 0 and lx < SIZE and lz >= 0 and lz < SIZE


## Altura del bloque sólido más alto de una columna interior (o -1).
func surface_y(lx: int, lz: int) -> int:
	var base := (lx + 1) + (lz + 1) * PAD
	for y in range(mini(max_y, HEIGHT - 2), 0, -1):
		var id := blocks[base + y * LAYER]
		if id != 0 and BlockTypes.solid[id] == 1:
			return y
	return -1
