extends SceneTree
## Prueba de rendimiento y validez del generador y del mallado.

func _init() -> void:
	var t0 := Time.get_ticks_usec()
	var tf := TextureFactory.new()
	var imgs := tf.build_images()
	var t1 := Time.get_ticks_usec()
	print("Texturas: %d capas en %.1f ms" % [imgs.size(), (t1 - t0) / 1000.0])
	var gen := WorldGenerator.new(12345)
	var t2 := Time.get_ticks_usec()
	print("Generador creado en %.1f ms" % ((t2 - t1) / 1000.0))
	var total_gen := 0.0
	var total_mesh := 0.0
	var faces := 0
	var verts := 0
	var ents := 0
	for cz in range(-2, 2):
		for cx in range(-2, 2):
			var a := Time.get_ticks_usec()
			var data := gen.generate_chunk(cx, cz)
			var b := Time.get_ticks_usec()
			var mesh := ChunkMesher.build(data)
			var c := Time.get_ticks_usec()
			total_gen += (b - a) / 1000.0
			total_mesh += (c - b) / 1000.0
			faces += (mesh["collision"] as PackedVector3Array).size() / 3
			if mesh["opaque"] != null:
				verts += ((mesh["opaque"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			ents += data.entities.size()
	print("16 chunks: generación %.1f ms (%.1f/chunk), mallado %.1f ms (%.1f/chunk)" % [total_gen, total_gen / 16.0, total_mesh, total_mesh / 16.0])
	print("Triángulos de colisión: %d, vértices opacos: %d, entidades: %d" % [faces, verts, ents])
	print("Altura en spawn: %d, bioma: %s" % [gen.height_at(3, 3), gen.biome_name(3, 3)])
	print("Altura ruinas: %d" % gen.height_at(64, 0))
	quit()
