extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1536,1280)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for row in 5:
		for col in 8:
			var sprite := Sprite2D.new()
			sprite.texture=load("res://assets/characters/frames-v2/%s_%02d.png" % [["s","se","e","ne","n"][row],col*2])
			sprite.centered=false
			sprite.scale=Vector2.ONE*0.5
			sprite.position=Vector2(col*192,row*256)
			view.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://artifacts/walk-pose-guide.png")
	quit()
