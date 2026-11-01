extends SceneTree
func _initialize() -> void:
	var result: Dictionary = {}
	for direction: String in ["se","sw","ne","nw"]:
		var path := "res://assets/characters/guest-parts-%s-v1.png" % direction
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		var regions := AlphaRegions.components(image)
		if regions.size() != 8:
			push_error("Expected eight complete rig parts: " + direction + " found " + str(regions.size()))
			quit(1)
			return
		regions.sort_custom(func(a: Rect2i,b: Rect2i) -> bool:
			var ay := 0 if a.get_center().y < image.get_height()/2 else 1
			var by := 0 if b.get_center().y < image.get_height()/2 else 1
			return a.position.x < b.position.x if ay == by else ay < by)
		var arrays: Array = []
		for rect in regions: arrays.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
		result[direction] = {"file":path,"sha256":FileAccess.get_sha256(path),"regions":arrays}
	var file := FileAccess.open("res://assets/registration/guest-rig.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"parts":result},"\t"))
	file.close()
	print("GUEST_RIG_REGISTRATION four views, eight connected parts each")
	quit()
