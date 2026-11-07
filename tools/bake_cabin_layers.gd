extends SceneTree

func _initialize() -> void:
	var assets := ResortAssets.new()
	DirAccess.make_dir_recursive_absolute("res://assets/interiors")
	for facing in 2:
		var layers := CabinInterior.generate_layers(facing, assets)
		for index in layers.size():
			var error: Error = layers[index].texture.get_image().save_png("res://assets/interiors/cabin-%d-%d.png" % [facing,index])
			if error != OK:
				quit(1)
				return
	var file := FileAccess.open("res://assets/registration/cabin-layers.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": FileAccess.get_sha256("res://assets/atlases/buildings-v2.png"), "authoring": FileAccess.get_sha256("res://scripts/content/cabin_interior.gd")}, "\t"))
	file.close()
	print("CABIN_LAYERS_BAKED exact atlas partitions")
	quit()
