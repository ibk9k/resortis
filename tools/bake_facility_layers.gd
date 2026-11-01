extends SceneTree
func _initialize() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path("res://assets/atlases/buildings-v2.png"))
	var region := Rect2i(1082,579,421,378)
	var source := atlas.get_region(region)
	var canopy := PackedVector2Array([Vector2(1219,657),Vector2(1265,610),Vector2(1360,579),Vector2(1462,611),Vector2(1500,659),Vector2(1490,704),Vector2(1400,738),Vector2(1300,728),Vector2(1220,695)])
	var base := Image.create(421,378,false,Image.FORMAT_RGBA8)
	var top := Image.create(421,378,false,Image.FORMAT_RGBA8)
	for y in 378:
		for x in 421:
			var pixel := source.get_pixel(x,y)
			if Geometry2D.is_point_in_polygon(Vector2(x+1082.5,y+579.5),canopy): top.set_pixel(x,y,pixel)
			else: base.set_pixel(x,y,pixel)
	base.save_png("res://assets/interiors/sunbeds-base.png")
	top.save_png("res://assets/interiors/sunbeds-canopy.png")
	print("FACILITY_LAYERS_BAKED exact original-pixel partition")
	quit()
