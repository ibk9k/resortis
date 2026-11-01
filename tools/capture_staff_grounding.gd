extends SceneTree
const Art=preload("res://assets/staff/janitor_art.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var view := SubViewport.new()
	view.size=Vector2i(1024,560)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bg := ColorRect.new()
	bg.size=view.size
	bg.color=Color("d7d3bc")
	view.add_child(bg)
	for row in 2:
		for col in 4:
			var offset := Vector2(col*256,row*280)
			var sprite := Sprite2D.new()
			sprite.centered=false
			sprite.position=offset
			sprite.texture=load(Art.OUTPUT.path_join("clean-%s-%02d.png" % ["s" if row==0 else "e",col]))
			view.add_child(sprite)
			var line := Line2D.new()
			line.points=PackedVector2Array([offset+Art.ROOT+Vector2(-35,0),offset+Art.ROOT+Vector2(35,0)])
			line.width=1
			line.default_color=Color("ce3e41")
			view.add_child(line)
	await process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://artifacts/staff-grounding-review.png")
	quit()
