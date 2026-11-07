extends SceneTree

func _initialize() -> void:
	var entries: Array = []
	for folder: String in ["res://assets/atlases", "res://assets/characters", "res://assets/characters/frames", "res://assets/characters/frames-v2", "res://assets/structures", "res://assets/interiors", "res://assets/characters/illustrated-masters", "res://assets/characters/illustrated/female/walk", "res://assets/characters/illustrated/male/walk", "res://assets/characters/illustrated/female/activities", "res://assets/characters/illustrated/male/activities", "res://assets/staff/masters", "res://assets/staff/illustrated", "res://assets/facility-staff/masters", "res://assets/facility-staff/frames", "res://assets/staffed-venues/masters", "res://assets/staffed-venues/frames"]:
		var filenames := DirAccess.get_files_at(folder)
		filenames.sort()
		for asset_file: String in filenames:
			if not asset_file.ends_with(".png"):
				continue
			var path := folder.path_join(asset_file)
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				push_error("Cannot read manifest source: " + path)
				quit(1)
				return
			var illustrated := "/illustrated/" in folder or folder.ends_with("/illustrated")
			var derived := illustrated or folder.ends_with("/frames-v2") or folder.ends_with("/structures")
			var experiment := asset_file in ["beach-v1.png", "buildings-v1.png", "people-v1.png", "props-v1.png","female-walk-v2.png"] or (asset_file.begins_with("guest-") and not folder.ends_with("illustrated-masters")) or folder.ends_with("/frames") or folder.ends_with("/frames-v2")
			var source_note := "Godot registration of complete guided illustrations" if illustrated else ("Original buildings-v2 atlas furniture layer" if folder.ends_with("/interiors") else ("Godot render from editable 3D model" if derived else "Built-in image-generation tool or retained rig experiment"))
			var role := "retained experiment or gait baseline" if experiment else ("runtime illustrated guest" if illustrated else ("runtime furniture layer" if folder.ends_with("/interiors") else ("runtime model render" if derived else "production input")))
			if "/staff/" in folder:
				source_note = "Godot registration of complete staff paintings" if illustrated else "Built-in image-generation tool; exact prompts in assets/staff/prompts"
				role = "runtime illustrated janitor" if illustrated else "production staff master"
				if asset_file == "janitor-walk-v1.png": role = "retained earlier staff master"
			var created := "2026-11-01" if "/staff/" in folder or asset_file=="guest-volleyball-v2.png" or (illustrated and asset_file.begins_with("volleyball-")) else "2026-10-31"
			if asset_file == "dolphin_statue-v1.png": created = "2026-11-03"
			if "/facility-staff/" in folder:
				var master := folder.ends_with("/masters")
				source_note = "Built-in ImageGen; see assets/facility-staff/prompts.txt" if master else "Whole painted poses registered by tools/bake_illustrated_attendants.gd"
				role = "production attendant master" if master else "registered input to the staffed venue bake"
				created = "2026-11-04"
			if "/staffed-venues/" in folder:
				var master := folder.ends_with("/masters")
				source_note = "Built-in ImageGen; see assets/staffed-venues/prompts.txt" if master else "Complete facility keys composited by tools/bake_staffed_venues.gd"
				role = "production facility master" if master else "runtime occupied facility"
				created = "2026-11-04"
			if folder.ends_with("/structures") and asset_file.trim_suffix("-v1.png") in ResortServices.EXPANSION:
				source_note = "Godot render from the editable inland facility model"
				created = "2026-11-04"
			if asset_file in ["grass-wang.png", "sand-wang.png"]:
				source_note = "Wang tiles baked from terrain-v1.png by tools/bake_terrain_wang.gd"
				role = "runtime terrain atlas, 16 edge-matched variants"
				created = "2026-11-04"
			if asset_file == "janitor-walk-v2.png" or ("/staff/" in folder and illustrated and asset_file.begins_with("walk-")): created = "2026-11-03"
			entries.append({"file": path.trim_prefix("res://"), "width": image.get_width(), "height": image.get_height(), "alpha": image.detect_alpha(), "sha256": FileAccess.get_sha256(path), "source":source_note,"role":role,"created":created})
	var file := FileAccess.open("res://docs/assets/asset-manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 2, "assets": entries}, "\t"))
	file.close()
	print("ASSET_MANIFEST_RESULT ", entries.size(), " source and derived images")
	quit()
