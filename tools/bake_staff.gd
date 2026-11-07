extends SceneTree
## Staff-only authoring. Coordinator runs --bake, imports, and approves shared
## sources after review. --preview-only writes only worker-4 review artifacts.
const Art = preload("res://assets/staff/janitor_art.gd")
const JanitorSkin = preload("res://assets/staff/janitor_skin.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not "--bake" in args and not "--preview-only" in args:
		push_error("Choose --bake (coordinator) or --preview-only (artifacts only). Requires a real renderer.")
		quit(1)
		return
	var metadata := Art.metadata()
	if "--bake" in args: await _bake(metadata, "--walk-only" in args)
	if "--preview-only" in args: await _preview(metadata)
	quit()

func _bake(metadata: Dictionary, walk_only: bool) -> void:
	DirAccess.make_dir_recursive_absolute(Art.OUTPUT)
	var viewport := SubViewport.new()
	viewport.size = Art.CANVAS
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for facing: String in Art.DIRS:
		for kind in (["walk"] if walk_only else ["walk", "idle", "clean"]):
			var skin := JanitorSkin.new()
			skin.configure(facing, kind)
			viewport.add_child(skin)
			for index in (16 if kind == "walk" else (4 if kind == "clean" else 1)):
				skin.pose(float(index) / (16 if kind == "walk" else 4))
				await process_frame
				await RenderingServer.frame_post_draw
				var suffix := "idle" if kind == "idle" else "%02d" % index
				var error := viewport.get_texture().get_image().save_png(Art.OUTPUT.path_join("%s-%s-%s.png" % [kind, facing, suffix]))
				assert(error == OK, "Unable to save isolated staff frame")
			skin.free()
	viewport.free()
	var file := FileAccess.open(Art.REGISTRATION, FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("JANITOR_BAKED 128 walking, guarded complete paintings" if walk_only else "JANITOR_BAKED 128 walking + 8 idle + 32 cleaning, guarded complete paintings")

func _preview(metadata: Dictionary) -> void:
	var folder := "res://artifacts/worker-4-staff-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 620)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new()
	bg.color = Color("d8d5bd")
	bg.size = viewport.size
	viewport.add_child(bg)
	var skins: Array[Node2D] = []
	var col := 0
	for facing: String in Art.DIRS:
		for kind in ["walk", "clean", "idle"]:
			var skin := JanitorSkin.new()
			skin.configure(facing, kind)
			skin.scale = Vector2.ONE * Art.SCALE * 3.0
			skin.position = Vector2(80 + col * 158, 185 + ["walk", "clean", "idle"].find(kind) * 200) - Art.ROOT * skin.scale
			viewport.add_child(skin)
			skins.append(skin)
			var label := Label.new()
			label.text = "%s · %s" % [facing, kind]
			label.position = Vector2(20 + col * 158, 8 + ["walk", "clean", "idle"].find(kind) * 200)
			label.add_theme_color_override("font_color", Color("264637"))
			viewport.add_child(label)
			var small := JanitorSkin.new()
			small.configure(facing, kind)
			small.scale = Vector2.ONE * Art.SCALE
			small.position = Vector2(134 + col * 158, 185 + ["walk", "clean", "idle"].find(kind) * 200) - Art.ROOT * small.scale
			viewport.add_child(small)
			skins.append(small)
		col += 1
	for frame in 16:
		for skin in skins: skin.pose(float(frame) / 16.0)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(folder.path_join("frame-%02d.png" % frame))
	var file := FileAccess.open(folder.path_join("source-regions.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	viewport.free()
	print("JANITOR_PREVIEW frames=16; 8 facings; normal 49px and enlarged 147px; ", folder)
