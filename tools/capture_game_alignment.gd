extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
	root.add_child(resort)
	var focus := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="): focus = arg.trim_prefix("--focus=")
		if arg == "--grid":
			resort.terrain_view.show_grid = true
			resort.terrain_view.queue_redraw()
			resort.hud.tools.grid.button_pressed = true
	if not focus.is_empty():
		for object in resort.placed:
			if object.kind == focus:
				resort.camera.position = object.position + Vector2(100,-25)
				resort.camera.zoom = Vector2.ONE * 1.3
				resort.selected_id = object.object_id
				resort._update_selected_outline()
				resort.hud.show_object(object.kind,object.orientation,true)
				break
	for n in 12: await process_frame
	await RenderingServer.frame_post_draw
	var file := "res://artifacts/coastal-resort-corrected.png" if focus.is_empty() else "res://artifacts/aligned-%s.png" % focus
	var error := root.get_texture().get_image().save_png(file)
	print("GAME_ALIGNMENT_CAPTURE ",error," ",file)
	quit(0 if error == OK else 1)
