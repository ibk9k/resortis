extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var studio := AssetReviewStudio.new()
	studio.walking_frames = "--walks" in args
	root.add_child(studio)
	for n in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var name := "guest-frames-registered.png" if studio.walking_frames else "catalogue-registered.png"
	var result := root.get_texture().get_image().save_png("res://artifacts/" + name)
	print("ASSET_REVIEW_CAPTURE ", result, " ", name)
	quit(0 if result == OK else 1)
