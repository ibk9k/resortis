extends SceneTree

func _initialize() -> void:
	var layout := ResortLayout.new()
	layout.seed_default()
	var invalid: Array = []
	for record in layout.objects:
		var result := layout.validate(record.kind, record.position, record.orientation, record.id)
		if not result.ok:
			invalid.append({"id": record.id, "kind": record.kind, "position": str(record.position), "reason": result.reason})
	print("DEFAULT_LAYOUT_VALIDATION ", JSON.stringify(invalid))
	var graph := layout.navigation()
	var entrances: Array = []
	for record in layout.objects:
		var def := ResortCatalog.definition(record.kind)
		if def.get("access", false):
			var door := Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)
			entrances.append({"kind": record.kind, "door": str(door), "connected": not graph.get_id_path(Vector2i(22, 19), door).is_empty()})
	print("ENTRANCE_VALIDATION ", JSON.stringify(entrances))
	print("USER_DATA_DIR ", OS.get_user_data_dir())
	for property in ProjectSettings.get_property_list():
		if "shader" in property.name and "cache" in property.name:
			print(property.name, " = ", ProjectSettings.get_setting(property.name))
	quit(0 if invalid.is_empty() else 1)
