extends SceneTree

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var only := ""
	var expansion := "--expansion" in OS.get_cmdline_user_args()
	var ambience := "--ambience" in OS.get_cmdline_user_args()
	var staff := "--staff" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if not only.is_empty() and not ResortCatalog.DEFINITIONS.has(only):
		push_error("Unknown catalogue item: " + only)
		quit(1)
		return
	var assets := ResortAssets.new()
	DirAccess.make_dir_recursive_absolute("res://assets/sprites")
	DirAccess.make_dir_recursive_absolute("res://scenes/assets")
	var count := 0
	for kind: String in ResortCatalog.DEFINITIONS:
		if not only.is_empty() and kind != only: continue
		if expansion and kind not in ResortServices.EXPANSION: continue
		if ambience and kind not in FacilityAmbience.KINDS: continue
		if staff and kind not in FacilityStaff.KINDS: continue
		var def := ResortCatalog.definition(kind)
		for orientation in def.frames.size():
			var suffix := "_%d" % orientation if def.frames.size() > 1 else ""
			var label := kind + suffix
			var texture := assets.display_texture_for(kind, orientation)
			var error := ResourceSaver.save(texture, "res://assets/sprites/" + label + ".tres")
			if error != OK:
				quit(1)
				return
			var object := PlacedResortObject.new()
			object.configure({"id": 1, "kind": kind, "position": Vector2.ZERO, "orientation": orientation}, assets)
			object.name = label.to_pascal_case()
			object.position = Vector2.ZERO
			_set_owner(object, object)
			var packed := PackedScene.new()
			packed.pack(object)
			ResourceSaver.save(packed, "res://scenes/assets/" + label + ".tscn")
			object.free()
			count += 1
	if only.is_empty() and not expansion and not ambience and not staff:
		ResourceSaver.save(assets.walk_frames, "res://assets/sprites/holiday_guest_walk.tres")
	print("BAKED_ASSETS_RESULT ", count, " placeable scenes; eight-direction guest SpriteFrames")
	quit()

func _set_owner(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		_set_owner(child, scene)
