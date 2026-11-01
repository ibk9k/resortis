extends SceneTree
## Behavior checks for the editable map; no economy or save-game claims.

var failures: Array[String] = []
var checks := 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for x in range(-5, 50, 3):
		for y in range(-5, 50, 3):
			var cell := Vector2(x, y)
			expect(IsometricGrid.cell_at(IsometricGrid.project(cell)) == Vector2i(cell), "Projection and picking agree at " + str(cell))
	var layout := ResortLayout.new()
	layout.seed_default()
	for record in layout.objects:
		var result := layout.validate(record.kind, record.position, record.orientation, record.id)
		expect(result.ok, "Authored object is valid: " + record.kind + " " + str(record.position) + " " + result.reason)
	var graph := layout.navigation()
	for record in layout.objects:
		var def := ResortCatalog.definition(record.kind)
		if def.get("access", false):
			var door := Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)
			expect(not graph.get_id_path(ResortLayout.ARRIVAL, door).is_empty(), "Arrival reaches " + record.kind)
	expect(not layout.place("cabin", Vector2(26, 32)).ok, "Ordinary cabins reject beach terrain")
	expect(not layout.place("sunbeds", Vector2(1, 2)).ok, "Sunbeds reject inland grass")
	expect(not layout.place("cabin", Vector2(7, 5)).ok, "Building footprints cannot overlap")
	expect(not layout.place("flowers", Vector2(-0.5, 25)).ok, "Partial footprints outside the property are rejected")
	expect(not layout.place("pier", Vector2(28, 30)).ok, "Pier requires the shoreline")
	expect(not layout.place("cabin", Vector2(28, 8), 9).ok, "Unknown building orientation is rejected")
	expect(not layout.place("cabin", Vector2(35.5, 0)).ok, "A building cannot bypass whole-tile snapping")
	expect(not layout.place("flowers", Vector2(29.25, 33)).ok, "A decoration cannot bypass half-tile snapping")
	expect(layout.snapped_position("flowers", Vector2(28.2, 32.6)) == Vector2(28, 32.5), "Small decorations snap to half tiles")
	expect(layout.snapped_position("cabin", Vector2(28.2, 3.6)) == Vector2(28, 4), "Buildings snap to whole tiles")
	var path_snapshot := layout.paths.duplicate()
	expect(not layout.set_path(Vector2i(11, 7), false).ok, "Removing the active side entrance is rejected")
	expect(layout.paths == path_snapshot, "Rejected path removal leaves all paths intact")
	expect(not layout.set_path(ResortLayout.ARRIVAL, false).ok, "The arrival anchor stays accessible")
	# An isolated path tile is insufficient to open an inland facility.
	expect(layout.set_path(Vector2i(37, 4), true).ok, "An empty inland tile can receive a path")
	expect(not layout.validate("cabin", Vector2(35, 0)).ok, "A path disconnected from arrivals does not satisfy access")
	var original := layout.find_object(1).duplicate(true)
	expect(layout.move_object(1, original.position, 1).ok, "An existing cabin can use its second authored view")
	expect(layout.find_object(1).orientation == 1, "The changed orientation is retained")
	expect(not layout.move_object(1, Vector2(25, 30), 0).ok, "Invalid relocation is rejected")
	expect(layout.find_object(1).position == original.position, "Rejected relocation retains the cabin's original position")
	var created := layout.place("flowers", Vector2(29.5, 33.5))
	expect(created.ok, "A clear half-tile beach placement succeeds")
	var count := layout.objects.size()
	var path := "res://artifacts/test-layout.json"
	expect(layout.save_layout(path) == OK, "The edited layout saves")
	var restored := ResortLayout.new()
	expect(restored.load_layout(path) == OK, "The edited layout loads")
	expect(restored.objects.size() == count, "All objects survive the round trip")
	expect(restored.find_object(1).orientation == 1, "Cabin orientation survives saving")
	expect(restored.find_object(created.get("id", -1)).position == Vector2(29.5, 33.5), "Half-tile positions survive saving")
	expect(restored.paths == layout.paths, "Paths survive saving")
	# Migrate the original layout without side paths: select the real +Y cabin
	# view so the old recorded entrances remain connected, preserving all objects.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	legacy.schema = 1
	var old_paths: Array = []
	for cell in legacy.paths:
		if int(cell[0]) in [11,18] and int(cell[1]) in [7,8,9,14,15,16]: continue
		old_paths.append(cell)
	legacy.paths = old_paths
	var legacy_path := "res://artifacts/test-legacy-layout.json"
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated := ResortLayout.new()
	expect(migrated.load_layout(legacy_path) == OK,"Original layout migrates without losing the resort")
	expect(migrated.objects.size() == layout.objects.size(),"Migration preserves all placed objects")
	expect(migrated.find_object(1).position == layout.find_object(1).position,"Migration preserves cabin position")
	expect(migrated.find_object(1).orientation == 1,"Migration aligns the actual doorway to the existing path")
	var before_corrupt := restored.objects.duplicate(true)
	var bad_path := "res://artifacts/test-invalid-layout.json"
	var bad_file := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_file.store_string('{"schema":99,"objects":[],"paths":[]}')
	bad_file.close()
	expect(restored.load_layout(bad_path) != OK, "An unsupported schema is rejected")
	expect(restored.objects == before_corrupt, "A rejected load does not erase the open resort")
	var first_save := FileAccess.get_file_as_string(path)
	layout.remove_object(created.get("id", -1))
	expect(layout.save_layout(path) == OK, "A second edit saves over the working layout")
	expect(FileAccess.get_file_as_string(path + ".bak") == first_save, "The previous layout remains in the backup")
	var library := ResortAssets.new()
	for kind: String in ResortCatalog.DEFINITIONS:
		var def := ResortCatalog.definition(kind)
		for orientation in def.frames.size():
			var texture := library.texture_for(kind, orientation)
			expect(texture != null and texture.get_size().x > 0, "Sprite exists for " + kind)
	expect(library.walk_frames.get_animation_names().size() == 16, "Guest has eight walk directions and eight matching idle poses")
	for animation in library.walk_frames.get_animation_names():
		expect(library.walk_frames.get_frame_count(animation) == (1 if animation.ends_with("_idle") else 16), "Animation has the correct frame count: " + animation)
	# Persist the validated seed as a human-readable authored map, if requested.
	if "--write-authored" in OS.get_cmdline_user_args():
		var authored := ResortLayout.new()
		authored.seed_default()
		expect(authored.save_layout("res://data/coastal_map.json") == OK, "Validated authored map is written")
	print("LAYOUT_CHECKS ", checks, " checks; ", failures.size(), " failures")
	var report := FileAccess.open("res://artifacts/layout-checks.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	quit(0 if failures.is_empty() else 1)
