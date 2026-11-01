extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/walk-preview")
	var view := WalkCyclePreview.new()
	root.add_child(view)
	view.set_process(false)
	for frame in HolidayGuestModel.POSES:
		view.pose(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/walk-preview/frame-%02d.png" % frame)
	print("WALK_PREVIEW_CAPTURE sixteen rendered poses")
	quit()
