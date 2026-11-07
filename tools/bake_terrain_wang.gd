extends SceneTree
## Two edge colors per side give 16 Wang tiles per material. Opposite
## sides of the same color use the same painted strip and corner samples.

const SIZE := 160
const GUTTER := 2
const STRIDE := SIZE + GUTTER * 2
const BLEND := 14

func _initialize() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/atlases/terrain-v1.png"))
	if source == null or source.get_width() / 2 < SIZE + 20 or source.get_height() / 2 < SIZE + 20:
		push_error("Missing or undersized terrain source")
		quit(1)
		return
	for material in ["grass", "sand"]:
		var swatch := source.get_region(Rect2i(Vector2i(0 if material == "grass" else source.get_width() / 2, 0), source.get_size() / 2))
		var result := _bake(swatch)
		var path := "res://assets/atlases/%s-wang.png" % material
		if result.save_png(path) != OK:
			push_error("Could not save " + path)
			quit(1)
			return
	print("WANG_TERRAIN_BAKED 16 grass and 16 sand variants")
	quit()

func _bake(swatch: Image) -> Image:
	var atlas := Image.create(STRIDE * 4, STRIDE * 4, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42863
	var origins: Array[Vector2i] = []
	for i in 21:
		origins.append(Vector2i(rng.randi_range(10, swatch.get_width() - SIZE - 10), rng.randi_range(10, swatch.get_height() - SIZE - 10)))
	for variant in 16:
		var tile := Vector2i(variant % 4, variant / 4) * STRIDE
		for v in STRIDE:
			var y := clampi(v - GUTTER, 0, SIZE - 1)
			var dy := mini(y, SIZE - 1 - y)
			var horizontal := (variant >> (0 if y < SIZE / 2 else 2)) & 1
			var fy := 1.0 - smoothstep(0.0, float(BLEND), float(dy))
			for u in STRIDE:
				var x := clampi(u - GUTTER, 0, SIZE - 1)
				var dx := mini(x, SIZE - 1 - x)
				var vertical := (variant >> (3 if x < SIZE / 2 else 1)) & 1
				var fx := 1.0 - smoothstep(0.0, float(BLEND), float(dx))
				var inside := swatch.get_pixelv(origins[variant] + Vector2i(x, y))
				var across := swatch.get_pixelv(origins[16 + horizontal] + Vector2i(x, dy))
				var down := swatch.get_pixelv(origins[18 + vertical] + Vector2i(dx, y))
				var corner := swatch.get_pixelv(origins[20] + Vector2i(dx, dy))
				var pixel: Color
				if dx == 0 and dy == 0:
					pixel = corner
				elif dy == 0:
					pixel = across.lerp(corner, fx)
				elif dx == 0:
					pixel = down.lerp(corner, fy)
				else:
					pixel = inside.lerp(down, fx).lerp(across.lerp(corner, fx), fy)
				atlas.set_pixelv(tile + Vector2i(u, v), pixel)
	return atlas
