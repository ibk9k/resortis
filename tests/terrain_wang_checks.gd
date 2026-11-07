extends SceneTree

const Bake := preload("res://tools/bake_terrain_wang.gd")

func _initialize() -> void:
	var errors: Array[String] = []
	for material in ["grass", "sand"]:
		var atlas := load("res://assets/atlases/%s-wang.png" % material) as Texture2D
		if atlas == null or atlas.get_size() != Vector2.ONE * Bake.STRIDE * 4:
			errors.append("%s is missing its 4×4 atlas" % material)
			continue
		var image := atlas.get_image()
		var interiors := {}
		for tile in 16:
			var origin := _origin(tile)
			var center := origin + Vector2i.ONE * (Bake.SIZE / 2)
			interiors[image.get_region(Rect2i(center, Vector2i(8,8))).get_data()] = true
			for side in 4:
				var bit := (tile >> side) & 1
				var opposite := (side + 2) % 4
				if _edge(image, tile, side) != _edge(image, bit << opposite, opposite):
					errors.append("%s tile %d has a mismatched edge %d" % [material, tile, side])
		if interiors.size() != 16:
			errors.append("%s needs 16 distinct tile interiors" % material)
	print("TERRAIN_WANG_CHECKS ", JSON.stringify(errors))
	quit(0 if errors.is_empty() else 1)

func _origin(tile: int) -> Vector2i:
	return Vector2i(tile % 4, tile / 4) * Bake.STRIDE + Vector2i.ONE * Bake.GUTTER

func _edge(image: Image, tile: int, side: int) -> PackedColorArray:
	var origin := _origin(tile)
	var edge := PackedColorArray()
	for i in Bake.SIZE:
		var point: Vector2i = [Vector2i(i,0), Vector2i(Bake.SIZE-1,i), Vector2i(i,Bake.SIZE-1), Vector2i(0,i)][side]
		edge.append(image.get_pixelv(origin + point))
	return edge
