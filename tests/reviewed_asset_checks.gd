extends SceneTree
func _initialize() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/reviewed-sources.json"))
	if not data is Dictionary or not data.has("sources"):
		push_error("Catalogue sources need registration and rendered review before acceptance.")
		quit(1)
		return
	var failures: Array[String] = []
	for path: String in data.sources:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != data.sources[path]:
			failures.append(path)
	print("REVIEWED_ASSET_CHECKS ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
