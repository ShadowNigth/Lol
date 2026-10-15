class_name WorldSource
extends RefCounted
## Interfaz común de los generadores que alimentan a VoxelWorld (exterior o
## mazmorra). Las implementaciones deben ser de solo lectura tras crearse para
## poder usarse desde hilos de trabajo.

func generate_chunk(cx: int, cz: int) -> ChunkData:
	return ChunkData.new(cx, cz)


func height_at(_x: int, _z: int) -> int:
	return 0


func biome_name(_x: int, _z: int) -> String:
	return ""


func location_at(_x: float, _z: float) -> String:
	return ""


## Identificador del lugar con nombre (vacío si no tiene).
func location_id_at(_x: float, _z: float) -> String:
	return ""


func spawn_point() -> Vector3:
	return Vector3.ZERO


func spawn_yaw() -> float:
	return 0.0


func is_interior() -> bool:
	return false


## Ruta transitable entre dos puntos (vacía = usar dirección directa).
func find_path(_from: Vector3, _to: Vector3) -> PackedVector3Array:
	return PackedVector3Array()
