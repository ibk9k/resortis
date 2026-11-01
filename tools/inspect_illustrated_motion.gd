extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1152,900)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bg := ColorRect.new()
	bg.color=Color("9bb3a2")
	bg.size=view.size
	view.add_child(bg)
	for row in 2:
		for col in 4:
			var skin := IllustratedGuestSkin.new()
			skin.configure("female" if row==0 else "male","e")
			skin.position=Vector2(col*288-48,row*450-15)
			view.add_child(skin)
			skin.pose(col/4.0,true)
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://artifacts/illustrated-side-inspection.png")
	quit()
