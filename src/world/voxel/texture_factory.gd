class_name TextureFactory
extends RefCounted
## Genera procedimentalmente las texturas pixel-art (16x16) de los bloques y
## las empaqueta en un Texture2DArray con mipmaps propios (los de recorte
## conservan la cobertura alfa para que las hojas no desaparezcan a lo lejos).

const S := 16

var _rng := RandomNumberGenerator.new()
var _cutout_names := {
	"leaves": true, "spruce_leaves": true, "birch_leaves": true, "glass": true, "torch": true,
	"tall_grass": true, "flower_red": true, "flower_yellow": true, "flower_blue": true, "bush": true,
	"dead_bush": true, "mushroom": true, "crop": true, "reeds": true, "cobweb": true,
}


## Crea todas las capas en el orden de BlockTypes.TEXTURES.
func build_images() -> Array[Image]:
	var out: Array[Image] = []
	for entry: Array in BlockTypes.TEXTURES:
		var tex_name: String = entry[0]
		var variants: int = entry[1]
		for v in variants:
			_rng.seed = hash(tex_name) + v * 7919
			var img := _generate(tex_name, v)
			out.append(_with_mipmaps(img, _cutout_names.has(tex_name)))
	return out


func build_texture_array() -> Texture2DArray:
	var arr := Texture2DArray.new()
	var err := arr.create_from_images(build_images())
	if err != OK:
		push_error("No se pudo crear el Texture2DArray de bloques: %s" % error_string(err))
	return arr


# ---------------------------------------------------------------------------
# Mipmaps
# ---------------------------------------------------------------------------

func _with_mipmaps(img: Image, cutout: bool) -> Image:
	var data := PackedByteArray()
	var level := img.get_data()
	var w := S
	data.append_array(level)
	while w > 1:
		var nw := w / 2
		var nxt := PackedByteArray()
		nxt.resize(nw * nw * 4)
		for y in nw:
			for x in nw:
				var r := 0.0
				var g := 0.0
				var b := 0.0
				var opaque_count := 0
				var a_sum := 0.0
				for dy in 2:
					for dx in 2:
						var i := ((y * 2 + dy) * w + (x * 2 + dx)) * 4
						var a := level[i + 3] / 255.0
						a_sum += a
						if a > 0.5 or not cutout:
							r += level[i]
							g += level[i + 1]
							b += level[i + 2]
							opaque_count += 1
				var o := (y * nw + x) * 4
				if opaque_count > 0:
					nxt[o] = int(r / opaque_count)
					nxt[o + 1] = int(g / opaque_count)
					nxt[o + 2] = int(b / opaque_count)
				if cutout:
					nxt[o + 3] = 255 if opaque_count >= 2 else 0
				else:
					nxt[o + 3] = int(a_sum / 4.0 * 255.0)
		data.append_array(nxt)
		level = nxt
		w = nw
	return Image.create_from_data(S, S, true, Image.FORMAT_RGBA8, data)


# ---------------------------------------------------------------------------
# Utilidades de dibujo
# ---------------------------------------------------------------------------

func _img() -> Image:
	return Image.create_empty(S, S, false, Image.FORMAT_RGBA8)


static func _hex(s: String) -> Color:
	return Color.html(s)


## Ruido de valor periódico (tileable) en [0,1].
func _vnoise_grid(period: int) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(period * period)
	for i in g.size():
		g[i] = _rng.randf()
	return g


func _vnoise(grid: PackedFloat32Array, period: int, x: float, y: float) -> float:
	var fx := x / S * period
	var fy := y / S * period
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := grid[posmod(x0, period) + posmod(y0, period) * period]
	var b := grid[posmod(x0 + 1, period) + posmod(y0, period) * period]
	var c := grid[posmod(x0, period) + posmod(y0 + 1, period) * period]
	var d := grid[posmod(x0 + 1, period) + posmod(y0 + 1, period) * period]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _fbm_map() -> PackedFloat32Array:
	var g4 := _vnoise_grid(4)
	var g8 := _vnoise_grid(8)
	var g16 := _vnoise_grid(16)
	var m := PackedFloat32Array()
	m.resize(S * S)
	for y in S:
		for x in S:
			m[x + y * S] = _vnoise(g4, 4, x, y) * 0.5 + _vnoise(g8, 8, x, y) * 0.3 + _vnoise(g16, 16, x, y) * 0.2
	return m


func _pal(palette: Array, t: float) -> Color:
	var i := clampi(int(t * palette.size()), 0, palette.size() - 1)
	return palette[i]


func _fill_palette_noise(img: Image, palette: Array, jitter: float = 0.18) -> void:
	var m := _fbm_map()
	for y in S:
		for x in S:
			var t := clampf(m[x + y * S] + _rng.randf_range(-jitter, jitter), 0.0, 0.999)
			img.set_pixel(x, y, _pal(palette, t))


func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a)


func _speckle(img: Image, color: Color, count: int) -> void:
	for i in count:
		img.set_pixel(_rng.randi() % S, _rng.randi() % S, color)


func _crack(img: Image, color: Color, length: int) -> void:
	var x := _rng.randi() % S
	var y := _rng.randi() % S
	for i in length:
		img.set_pixel(posmod(x, S), posmod(y, S), color)
		x += _rng.randi_range(-1, 1)
		y += 1 if _rng.randf() < 0.6 else 0


func _transparent(img: Image) -> void:
	img.fill(Color(0, 0, 0, 0))


# ---------------------------------------------------------------------------
# Generadores
# ---------------------------------------------------------------------------

func _generate(tex_name: String, variant: int) -> Image:
	var img := _img()
	match tex_name:
		"bedrock":
			_fill_palette_noise(img, [_hex("232326"), _hex("2f2f33"), _hex("3c3c41"), _hex("4a4a50")], 0.35)
		"stone":
			_stone(img, [_hex("5f6064"), _hex("6f7075"), _hex("808186"), _hex("909196")])
		"dirt":
			_dirt(img)
		"grass_top":
			_grass_top(img)
		"grass_side":
			_dirt(img)
			_top_fringe(img, [_hex("4f7f2c"), _hex("5b8f33"), _hex("69a03b")], 3)
		"sand":
			_fill_palette_noise(img, [_hex("c9b27c"), _hex("d4bf8a"), _hex("dccb98"), _hex("e5d6a8")], 0.25)
			_speckle(img, _hex("b39b67"), 6)
		"gravel":
			_gravel(img)
		"snow":
			_fill_palette_noise(img, [_hex("dfe7f0"), _hex("e9eff6"), _hex("f2f6fb"), _hex("fbfdff")], 0.2)
			_speckle(img, _hex("cdd9e6"), 5)
		"snow_side":
			_dirt(img)
			_top_fringe(img, [_hex("e9eff6"), _hex("f2f6fb"), _hex("fbfdff")], 4)
		"cobble":
			_cobble(img, [_hex("5a5b60"), _hex("6c6d72"), _hex("7d7e84"), _hex("8f9096")], _hex("3d3d42"), 0)
		"stone_brick":
			_bricks(img, [_hex("707177"), _hex("7c7d83"), _hex("878890"), _hex("93949b")], _hex("47484d"), 8, 8)
		"mossy_brick":
			_bricks(img, [_hex("6c6d70"), _hex("78797d"), _hex("83858a"), _hex("8f9095")], _hex("45464a"), 8, 8)
			_moss(img, 0.55)
		"cracked_brick":
			_bricks(img, [_hex("6c6d72"), _hex("77787e"), _hex("82838a"), _hex("8d8e95")], _hex("424347"), 8, 8)
			for i in 3:
				_crack(img, _hex("3a3a3e"), 6)
		"planks":
			_planks(img, [_hex("8a6239"), _hex("9a6e41"), _hex("a97a4a"), _hex("b78755")], _hex("5e4026"))
		"dark_planks":
			_planks(img, [_hex("4a3220"), _hex("553a25"), _hex("60422b"), _hex("6b4a31")], _hex("2e1f14"))
		"spruce_planks":
			_planks(img, [_hex("6e4a2c"), _hex("7a5332"), _hex("865c38"), _hex("92653f")], _hex("45301c"))
		"log_side":
			_bark(img, [_hex("4d3a26"), _hex("5a442d"), _hex("675036"), _hex("735a3d")])
		"log_top":
			_rings(img, [_hex("a07a4b"), _hex("b38b58")], _hex("5a442d"))
		"spruce_log_side":
			_bark(img, [_hex("3a2a1c"), _hex("443222"), _hex("4f3a28"), _hex("5a432e")])
		"spruce_log_top":
			_rings(img, [_hex("86603a"), _hex("976d43")], _hex("3f2e20"))
		"birch_log_side":
			_birch(img)
		"birch_log_top":
			_rings(img, [_hex("c9b48a"), _hex("d8c49a")], _hex("d9d6cc"))
		"leaves":
			_leaves(img, [_hex("2f5a1e"), _hex("3a6b25"), _hex("467c2d"), _hex("548d36")], 0.16)
		"spruce_leaves":
			_leaves(img, [_hex("1f3d26"), _hex("27492d"), _hex("2f5534"), _hex("38613c")], 0.14)
		"birch_leaves":
			_leaves(img, [_hex("4f7a2a"), _hex("5d8a32"), _hex("6c9a3b"), _hex("7aa846")], 0.18)
		"water":
			_water(img)
		"path_top":
			_fill_palette_noise(img, [_hex("7a5f3c"), _hex("876a43"), _hex("94764c"), _hex("a08256")], 0.3)
			_speckle(img, _hex("8c8a86"), 7)
			_speckle(img, _hex("6b5233"), 6)
		"path_side":
			_dirt(img)
			_top_fringe(img, [_hex("876a43"), _hex("94764c")], 2)
		"roof_tile":
			_roof_tiles(img, [_hex("7c2f22"), _hex("8e3b2b"), _hex("a24632"), _hex("b4553b")])
		"plaster":
			_fill_palette_noise(img, [_hex("cbbf9f"), _hex("d4c9aa"), _hex("ddd3b6"), _hex("e5dcc2")], 0.12)
			if variant == 1:
				for i in 2:
					_crack(img, _hex("b5a888"), 4)
		"timber":
			_timber(img)
		"glass":
			_glass(img)
		"torch":
			_torch(img)
		"tall_grass":
			_tall_grass(img, variant)
		"flower_red":
			_flower(img, _hex("c4281c"), _hex("e0452f"), _hex("2b1b12"))
		"flower_yellow":
			_flower(img, _hex("e2b417"), _hex("f5d33c"), _hex("c9861a"))
		"flower_blue":
			_flower(img, _hex("3a5fc8"), _hex("5c7fe0"), _hex("f0e6a0"))
		"bush":
			_bush(img)
		"hay_side":
			_hay(img, true)
		"hay_top":
			_hay(img, false)
		"thatch":
			_thatch(img)
		"clay":
			_fill_palette_noise(img, [_hex("8f4f33"), _hex("9b5939"), _hex("a66341"), _hex("b06d49")], 0.15)
		"sandstone_side":
			_sandstone(img)
		"sandstone_top":
			_fill_palette_noise(img, [_hex("cdb27a"), _hex("d6bc85"), _hex("dec690"), _hex("e5cf9b")], 0.1)
		"ice":
			_fill_palette_noise(img, [_hex("8fb8e0"), _hex("9cc3e8"), _hex("aacdee"), _hex("b9d8f3")], 0.08)
			for i in 3:
				_crack(img, _hex("e4f1fb"), 6)
		"mud":
			_fill_palette_noise(img, [_hex("3a2a1d"), _hex("433122"), _hex("4d3828"), _hex("56402e")], 0.25)
			_speckle(img, _hex("2b1f15"), 8)
		"dead_bush":
			_dead_bush(img)
		"mushroom":
			_mushroom(img)
		"bookshelf":
			_bookshelf(img)
		"wool_red":
			_wool(img, [_hex("7e1d1d"), _hex("8f2323"), _hex("a02a2a"), _hex("b03232")])
		"canvas":
			_canvas(img, variant)
		"dungeon_brick":
			_bricks(img, [_hex("3d3f46"), _hex("464850"), _hex("50525a"), _hex("5a5c65")], _hex("23242a"), 8, 4)
			if variant >= 1:
				_moss(img, 0.62)
			if variant == 2:
				for i in 2:
					_crack(img, _hex("1f2025"), 5)
		"dungeon_floor":
			_flagstones(img)
		"crop":
			_crop(img)
		"reeds":
			_reeds(img)
		"moss_stone":
			_cobble(img, [_hex("55585a"), _hex("66696b"), _hex("77797c"), _hex("888a8d")], _hex("3a3c3e"), 1)
			_moss(img, 0.45)
		"chiseled":
			_chiseled(img)
		"iron_block":
			_iron(img)
		"wrought_iron":
			_wrought_iron(img)
		"cobweb":
			_cobweb(img)
		_:
			img.fill(Color.MAGENTA)
	return img


func _stone(img: Image, palette: Array) -> void:
	_fill_palette_noise(img, palette, 0.12)
	for i in 2:
		_crack(img, _shade(palette[0], 0.8), _rng.randi_range(3, 6))
	_speckle(img, palette[3], 6)


func _dirt(img: Image) -> void:
	_fill_palette_noise(img, [_hex("5b3d24"), _hex("6a4729"), _hex("7a5432"), _hex("8a6039")], 0.3)
	_speckle(img, _hex("7f7a73"), 4)
	_speckle(img, _hex("4a3019"), 6)


func _grass_top(img: Image) -> void:
	var pal := [_hex("467528"), _hex("51832e"), _hex("5c9035"), _hex("679c3c"), _hex("73a845")]
	_fill_palette_noise(img, pal, 0.35)
	_speckle(img, _hex("82b752"), 8)
	_speckle(img, _hex("3d6823"), 6)


func _top_fringe(img: Image, palette: Array, depth: int) -> void:
	for x in S:
		var d := depth + _rng.randi_range(-1, 2)
		for y in maxi(d, 1):
			img.set_pixel(x, y, palette[_rng.randi() % palette.size()])


func _gravel(img: Image) -> void:
	var pal := [_hex("6d6a66"), _hex("7d7975"), _hex("8e8a85"), _hex("5d5a56"), _hex("8a7a68"), _hex("9c9892")]
	img.fill(_hex("5a5753"))
	for i in 34:
		var x := _rng.randi() % S
		var y := _rng.randi() % S
		var c: Color = pal[_rng.randi() % pal.size()]
		img.set_pixel(x, y, c)
		img.set_pixel((x + 1) % S, y, _shade(c, 0.92))
		if _rng.randf() < 0.6:
			img.set_pixel(x, (y + 1) % S, _shade(c, 0.8))


func _cobble(img: Image, palette: Array, mortar: Color, seed_shift: int) -> void:
	# Celdas de Voronoi periódicas: cada celda es una piedra redondeada.
	var pts: Array[Vector2] = []
	var count := 8 + seed_shift
	for i in count:
		pts.append(Vector2(_rng.randf() * S, _rng.randf() * S))
	var shades: Array[float] = []
	for i in count:
		shades.append(_rng.randf())
	for y in S:
		for x in S:
			var best := 1e9
			var second := 1e9
			var best_i := 0
			var best_off := Vector2.ZERO
			for i in count:
				for ox in [-S, 0, S]:
					for oy in [-S, 0, S]:
						var p := pts[i] + Vector2(ox, oy)
						var d := p.distance_squared_to(Vector2(x + 0.5, y + 0.5))
						if d < best:
							second = best
							best = d
							best_i = i
							best_off = p
						elif d < second:
							second = d
			var edge := sqrt(second) - sqrt(best)
			if edge < 1.0:
				img.set_pixel(x, y, mortar)
			else:
				var rel := Vector2(x + 0.5, y + 0.5) - best_off
				var light := clampf(0.5 - (rel.x + rel.y) * 0.06, 0.0, 1.0)
				var t := clampf(shades[best_i] * 0.6 + light * 0.4 + _rng.randf_range(-0.08, 0.08), 0.0, 0.999)
				img.set_pixel(x, y, _pal(palette, t))


func _bricks(img: Image, palette: Array, mortar: Color, brick_w: int, brick_h: int) -> void:
	var rows := S / brick_h
	for row in rows:
		var offset := (brick_w / 2) * (row % 2)
		var y0 := row * brick_h
		var bx := -offset
		while bx < S:
			var tone := _rng.randf_range(0.2, 0.8)
			for y in range(y0, y0 + brick_h):
				for x in range(bx, bx + brick_w):
					if x < 0 or x >= S:
						continue
					var lx := x - bx
					var ly := y - y0
					var c: Color
					if ly == brick_h - 1 or lx == brick_w - 1:
						c = mortar
					else:
						var t := tone + _rng.randf_range(-0.15, 0.15)
						if ly == 0 or lx == 0:
							t += 0.25
						elif ly == brick_h - 2 or lx == brick_w - 2:
							t -= 0.2
						c = _pal(palette, clampf(t, 0.0, 0.999))
					img.set_pixel(x, y, c)
			bx += brick_w


func _moss(img: Image, threshold: float) -> void:
	var m := _fbm_map()
	var pal := [_hex("3f5f26"), _hex("4b6f2d"), _hex("587d35")]
	for y in S:
		for x in S:
			var v := m[x + y * S] + (float(y) / S) * 0.15
			if v > threshold + _rng.randf_range(-0.05, 0.05):
				img.set_pixel(x, y, pal[_rng.randi() % pal.size()])


func _planks(img: Image, palette: Array, dark: Color) -> void:
	var board_h := 4
	for b in S / board_h:
		var tone := _rng.randf_range(0.25, 0.75)
		var seam := _rng.randi() % S
		for y in range(b * board_h, b * board_h + board_h):
			for x in S:
				var ly := y - b * board_h
				var t := tone + _rng.randf_range(-0.12, 0.12)
				if ly == board_h - 1:
					img.set_pixel(x, y, dark)
					continue
				if ly == 0:
					t += 0.15
				var c := _pal(palette, clampf(t, 0.0, 0.999))
				img.set_pixel(x, y, c)
			# Vetas
		for g in 2:
			var gy := b * board_h + _rng.randi_range(0, board_h - 2)
			var gx := _rng.randi() % S
			for k in _rng.randi_range(3, 7):
				img.set_pixel((gx + k) % S, gy, _shade(palette[0], 0.85))
		for y in range(b * board_h, b * board_h + board_h - 1):
			img.set_pixel(seam, y, dark)
		img.set_pixel((seam + 1) % S, b * board_h + 1, _hex("3a3a3a"))


func _bark(img: Image, palette: Array) -> void:
	for x in S:
		var tone := _rng.randf_range(0.0, 1.0)
		for y in S:
			if _rng.randf() < 0.12:
				tone = _rng.randf()
			img.set_pixel(x, y, _pal(palette, clampf(tone * 0.8 + _rng.randf() * 0.2, 0.0, 0.999)))
	for i in 3:
		var x := _rng.randi() % S
		var y := _rng.randi() % S
		for k in 4:
			img.set_pixel(x, (y + k) % S, _shade(palette[0], 0.75))


func _rings(img: Image, ring_cols: Array, bark: Color) -> void:
	for y in S:
		for x in S:
			var d := Vector2(x + 0.5 - 8.0, y + 0.5 - 8.0).length()
			if x == 0 or y == 0 or x == S - 1 or y == S - 1:
				img.set_pixel(x, y, bark)
			else:
				var ring := int(d * 0.9 + _rng.randf() * 0.4) % 2
				var c: Color = ring_cols[ring]
				img.set_pixel(x, y, _shade(c, 1.0 - d * 0.015))


func _birch(img: Image) -> void:
	_fill_palette_noise(img, [_hex("d4d0c5"), _hex("dcd9cf"), _hex("e4e1d8"), _hex("ecebe4")], 0.1)
	for i in 7:
		var x := _rng.randi() % S
		var y := _rng.randi() % S
		var l := _rng.randi_range(2, 4)
		for k in l:
			img.set_pixel((x + k) % S, y, _hex("2b2b2b") if k % 3 != 2 else _hex("6b675e"))


func _leaves(img: Image, palette: Array, hole_chance: float) -> void:
	_fill_palette_noise(img, palette, 0.35)
	for y in S:
		for x in S:
			if _rng.randf() < hole_chance:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_speckle(img, _shade(palette[3], 1.15), 6)


func _water(img: Image) -> void:
	var g := _vnoise_grid(4)
	for y in S:
		for x in S:
			var v := _vnoise(g, 4, x + sin(y * 0.8) * 1.5, y)
			var c := _hex("2a5aa0").lerp(_hex("4a86cf"), v)
			if v > 0.72:
				c = _hex("7fb2e8")
			c.a = 0.78
			img.set_pixel(x, y, c)


func _roof_tiles(img: Image, palette: Array) -> void:
	var tile_h := 4
	var tile_w := 4
	for row in S / tile_h:
		var off := (tile_w / 2) * (row % 2)
		for y in range(row * tile_h, row * tile_h + tile_h):
			for x in S:
				var lx := posmod(x + off, tile_w)
				var ly := y - row * tile_h
				var t := 0.55 + _rng.randf_range(-0.12, 0.12)
				if ly == tile_h - 1:
					t = 0.0
				elif lx == 0:
					t -= 0.3
				elif ly == 0:
					t += 0.3
				elif lx == tile_w - 1:
					t -= 0.1
				img.set_pixel(x, y, _pal(palette, clampf(t, 0.0, 0.999)))


func _timber(img: Image) -> void:
	var pal := [_hex("3a271a"), _hex("45301f"), _hex("503825"), _hex("5b402a")]
	for x in S:
		var tone := _rng.randf()
		for y in S:
			if _rng.randf() < 0.08:
				tone = _rng.randf()
			img.set_pixel(x, y, _pal(pal, clampf(tone, 0.0, 0.999)))
	for y in S:
		img.set_pixel(0, y, _hex("2e1f14"))
		img.set_pixel(S - 1, y, _hex("2e1f14"))


func _glass(img: Image) -> void:
	_transparent(img)
	var frame := _hex("4a3220")
	var frame_hi := _hex("5f4129")
	for i in S:
		img.set_pixel(i, 0, frame_hi)
		img.set_pixel(i, S - 1, frame)
		img.set_pixel(0, i, frame_hi)
		img.set_pixel(S - 1, i, frame)
		img.set_pixel(7, i, frame)
		img.set_pixel(8, i, frame_hi)
		img.set_pixel(i, 7, frame)
		img.set_pixel(i, 8, frame_hi)
	# Reflejos
	var hi := Color(0.85, 0.93, 1.0, 1.0)
	for k in 3:
		img.set_pixel(2 + k, 5 - k, hi)
		img.set_pixel(10 + k, 13 - k, hi)
	img.set_pixel(12, 4, hi)
	img.set_pixel(3, 12, hi)


func _torch(img: Image) -> void:
	_transparent(img)
	for y in range(6, 16):
		img.set_pixel(7, y, _hex("6b4a2b"))
		img.set_pixel(8, y, _hex("5a3d22"))
	img.set_pixel(7, 5, _hex("ffd75a"))
	img.set_pixel(8, 5, _hex("ffb43a"))
	img.set_pixel(7, 4, _hex("fff1a8"))
	img.set_pixel(8, 4, _hex("ffd75a"))
	img.set_pixel(7, 3, _hex("ff9a2a"))


func _tall_grass(img: Image, variant: int) -> void:
	_transparent(img)
	var pal := [_hex("3f6d24"), _hex("4b7d2b"), _hex("588c33"), _hex("66993c")]
	var blades := 9 + variant * 2
	for i in blades:
		var x := _rng.randi_range(1, S - 2)
		var h := _rng.randi_range(5, 14)
		var lean := _rng.randf_range(-0.25, 0.25)
		for k in h:
			var px := clampi(int(round(x + lean * k)), 0, S - 1)
			img.set_pixel(px, S - 1 - k, pal[clampi(k * pal.size() / h, 0, pal.size() - 1)])


func _flower(img: Image, petal: Color, petal_hi: Color, center: Color) -> void:
	_transparent(img)
	var stem := _hex("3f6d24")
	for y in range(7, 16):
		img.set_pixel(7, y, stem)
	img.set_pixel(6, 11, _hex("4b7d2b"))
	img.set_pixel(5, 10, _hex("4b7d2b"))
	img.set_pixel(8, 12, _hex("4b7d2b"))
	img.set_pixel(9, 11, _hex("4b7d2b"))
	for p: Vector2i in [Vector2i(6, 4), Vector2i(7, 3), Vector2i(8, 4), Vector2i(6, 6), Vector2i(8, 6), Vector2i(7, 7), Vector2i(5, 5), Vector2i(9, 5)]:
		img.set_pixel(p.x, p.y, petal)
	img.set_pixel(7, 4, petal_hi)
	img.set_pixel(6, 5, petal_hi)
	img.set_pixel(7, 5, center)


func _bush(img: Image) -> void:
	_transparent(img)
	var pal := [_hex("2f5a1e"), _hex("3a6b25"), _hex("467c2d"), _hex("548d36")]
	for y in S:
		for x in S:
			var d := Vector2(x - 7.5, (y - 9.0) * 1.2).length()
			if d < 7.0 - _rng.randf() * 1.5:
				img.set_pixel(x, y, pal[clampi(int((1.0 - d / 7.0) * 3.0 + _rng.randf()), 0, 3)])


func _hay(img: Image, side: bool) -> void:
	var pal := [_hex("a8862c"), _hex("bb9834"), _hex("c9a83f"), _hex("d8b84c")]
	for y in S:
		for x in S:
			var t := _rng.randf()
			if side and (x + y * 3) % 5 == 0:
				t *= 0.5
			img.set_pixel(x, y, _pal(pal, t))
	if side:
		for x in S:
			img.set_pixel(x, 5, _hex("7a5a1c"))
			img.set_pixel(x, 10, _hex("7a5a1c"))


func _thatch(img: Image) -> void:
	var pal := [_hex("7a6230"), _hex("8c7238"), _hex("9e8242"), _hex("b0934d")]
	for y in S:
		for x in S:
			var t := 0.5 + 0.35 * sin(x * 2.1 + _rng.randf()) + _rng.randf_range(-0.2, 0.2)
			if y % 4 == 3:
				t -= 0.4
			img.set_pixel(x, y, _pal(pal, clampf(t, 0.0, 0.999)))


func _sandstone(img: Image) -> void:
	var pal := [_hex("c2a46c"), _hex("cdb078"), _hex("d7bb84"), _hex("e0c590")]
	for y in S:
		var band := int(y / 4) % 2
		for x in S:
			var t := 0.45 + band * 0.25 + _rng.randf_range(-0.12, 0.12)
			if y % 4 == 0:
				t -= 0.3
			img.set_pixel(x, y, _pal(pal, clampf(t, 0.0, 0.999)))


func _dead_bush(img: Image) -> void:
	_transparent(img)
	var col := _hex("6b4a2b")
	for i in 6:
		var x := 7.5
		var y := 15.0
		var dx := _rng.randf_range(-0.7, 0.7)
		for k in _rng.randi_range(6, 11):
			img.set_pixel(clampi(int(x), 0, S - 1), clampi(int(y), 0, S - 1), col if k % 3 else _hex("8a6239"))
			x += dx
			y -= 1.0


func _mushroom(img: Image) -> void:
	_transparent(img)
	for y in range(10, 16):
		img.set_pixel(7, y, _hex("e8dcc4"))
		img.set_pixel(8, y, _hex("d6c8ad"))
	for y in range(6, 10):
		for x in range(4, 12):
			var d := absf(x - 7.5)
			if y == 6 and d > 2.5:
				continue
			img.set_pixel(x, y, _hex("b8231b") if (x + y) % 4 else _hex("f2efe6"))


func _bookshelf(img: Image) -> void:
	var wood := _hex("6b4a2b")
	img.fill(wood)
	var book_cols := [_hex("7e1d1d"), _hex("1f3f6e"), _hex("2f5a2a"), _hex("6e5a1f"), _hex("4a2a5e"), _hex("8a6a3a")]
	for shelf in 2:
		var y0 := 1 + shelf * 8
		var x := 1
		while x < S - 1:
			var w := _rng.randi_range(1, 2)
			var h := _rng.randi_range(5, 6)
			var c: Color = book_cols[_rng.randi() % book_cols.size()]
			for bx in range(x, mini(x + w, S - 1)):
				for by in range(y0 + (6 - h), y0 + 6):
					img.set_pixel(bx, by, c if bx == x else _shade(c, 0.8))
				img.set_pixel(bx, y0 + (6 - h) + 1, _hex("d8c48f"))
			x += w
		for xx in S:
			img.set_pixel(xx, y0 + 6, _hex("4a3220"))


func _wool(img: Image, palette: Array) -> void:
	for y in S:
		for x in S:
			var t := 0.5 + (0.2 if (x + y) % 2 == 0 else -0.1) + _rng.randf_range(-0.15, 0.15)
			img.set_pixel(x, y, _pal(palette, clampf(t, 0.0, 0.999)))


## Lona de tienda: lino crudo claro con trama fina, costuras verticales con
## puntadas, pliegues suaves y el borde inferior sucio; la variante 1 tiene una
## mancha de agua y la 3 un remiendo de tela rojiza cosido con puntadas.
func _canvas(img: Image, variant: int) -> void:
	var pal := [_hex("b39a6c"), _hex("c4ab7e"), _hex("d2ba8e"), _hex("dfc99f")]
	for y in S:
		for x in S:
			var weave := 0.03 if (x % 2 == 0) != (y % 2 == 0) else -0.02
			var fold := -0.12 * (0.5 + 0.5 * sin((y + 2.0) * PI / 8.0))
			var t := 0.66 + weave + fold + _rng.randf_range(-0.04, 0.04)
			if y >= S - 2:
				t -= 0.3                           # borde sucio de barro
			img.set_pixel(x, y, _pal(pal, clampf(t, 0.0, 0.999)))
	# Costuras entre paños: línea oscura y puntadas claras al lado
	for sx: int in [0, 8]:
		for y2 in S:
			img.set_pixel(sx, y2, _hex("806a48"))
			if y2 % 3 == 1:
				img.set_pixel(sx + 1, y2, _hex("eadbb6"))
	if variant == 1:
		# Mancha de agua y barro que baja desde la cumbrera
		for y3 in range(3, S - 2):
			for x3 in range(11, 14):
				if _rng.randf() < 0.75 - y3 * 0.02:
					img.set_pixel(x3, y3, img.get_pixel(x3, y3).darkened(0.12))
	if variant == 3:
		var patch := [_hex("7a4a32"), _hex("86533a"), _hex("935d41"), _hex("9e6748")]
		for py in range(7, 13):
			for px in range(10, 15):
				var edge := py == 7 or py == 12 or px == 10 or px == 14
				if edge:
					img.set_pixel(px, py, _hex("4f3324") if (px + py) % 2 == 0 else _hex("b98f6f"))
				else:
					img.set_pixel(px, py, _pal(patch, clampf(0.5 + _rng.randf_range(-0.15, 0.15), 0.0, 0.999)))


func _flagstones(img: Image) -> void:
	var pal := [_hex("3a3b40"), _hex("43444a"), _hex("4d4e55"), _hex("575860")]
	var mortar := _hex("1f2024")
	for ty in 2:
		for tx in 2:
			var tone := _rng.randf_range(0.2, 0.8)
			for y in range(ty * 8, ty * 8 + 8):
				for x in range(tx * 8, tx * 8 + 8):
					var lx := x - tx * 8
					var ly := y - ty * 8
					if lx == 7 or ly == 7:
						img.set_pixel(x, y, mortar)
					else:
						var t := tone + _rng.randf_range(-0.15, 0.15) + (0.15 if lx == 0 or ly == 0 else 0.0)
						img.set_pixel(x, y, _pal(pal, clampf(t, 0.0, 0.999)))
	_crack(img, mortar, 4)


func _crop(img: Image) -> void:
	_transparent(img)
	var pal := [_hex("9c8a2c"), _hex("b39d34"), _hex("c9b244"), _hex("7d8a2c")]
	for i in 6:
		var x := 1 + i * 2 + _rng.randi_range(0, 1)
		var h := _rng.randi_range(9, 14)
		for k in h:
			img.set_pixel(clampi(x, 0, S - 1), S - 1 - k, pal[3] if k < h - 4 else pal[_rng.randi() % 3])
		img.set_pixel(clampi(x + 1, 0, S - 1), S - h + 1, pal[2])


func _reeds(img: Image) -> void:
	_transparent(img)
	for i in 5:
		var x := 2 + i * 3
		var h := _rng.randi_range(10, 16)
		for k in h:
			img.set_pixel(clampi(x, 0, S - 1), S - 1 - k, _hex("5d7a34") if k < h - 3 else _hex("6b4a2b"))


func _chiseled(img: Image) -> void:
	_stone(img, [_hex("6f7075"), _hex("7b7c81"), _hex("86878c"), _hex("909196")])
	var dark := _hex("4a4b50")
	var light := _hex("a0a1a6")
	for i in range(2, 14):
		img.set_pixel(i, 2, light)
		img.set_pixel(2, i, light)
		img.set_pixel(i, 13, dark)
		img.set_pixel(13, i, dark)
	for i in range(5, 11):
		img.set_pixel(i, 5, dark)
		img.set_pixel(5, i, dark)
		img.set_pixel(i, 10, light)
		img.set_pixel(10, i, light)


func _cobweb(img: Image) -> void:
	_transparent(img)
	var c := Color(0.92, 0.92, 0.95, 1.0)
	for k in 8:
		var a := TAU * k / 8.0 + 0.2
		for r in range(1, 9):
			var x := int(round(7.5 + cos(a) * r))
			var y := int(round(7.5 + sin(a) * r))
			if x >= 0 and x < S and y >= 0 and y < S:
				img.set_pixel(x, y, c)
	for ring: float in [3.0, 5.5]:
		for k in 24:
			var a2 := TAU * k / 24.0
			var x2 := int(round(7.5 + cos(a2) * ring))
			var y2 := int(round(7.5 + sin(a2) * ring))
			if (k % 3) != 0:
				img.set_pixel(clampi(x2, 0, S - 1), clampi(y2, 0, S - 1), c)


## Hierro forjado oscuro con algún punto de óxido (barrotes de calabozo).
func _wrought_iron(img: Image) -> void:
	_fill_palette_noise(img, [_hex("2b2c30"), _hex("333539"), _hex("3c3e43"), _hex("47494e")], 0.1)
	for k in 9:
		img.set_pixel(_rng.randi() % S, _rng.randi() % S, _hex("5b3b27") if k % 3 else _hex("6e6f74"))


func _iron(img: Image) -> void:
	_fill_palette_noise(img, [_hex("8a8d93"), _hex("979aa0"), _hex("a3a6ac"), _hex("b0b3b9")], 0.08)
	for i in S:
		img.set_pixel(i, 0, _hex("c8cbd1"))
		img.set_pixel(0, i, _hex("c8cbd1"))
		img.set_pixel(i, S - 1, _hex("62656b"))
		img.set_pixel(S - 1, i, _hex("62656b"))
	for p: Vector2i in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(p.x, p.y, _hex("55585e"))
		img.set_pixel(p.x - 1, p.y - 1, _hex("d5d8de"))
