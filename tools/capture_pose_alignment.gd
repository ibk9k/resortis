extends SceneTree
var views: Array[SubViewport]=[]
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var assets := ResortAssets.new()
	var activities := "--activities" in OS.get_cmdline_user_args()
	root.size=Vector2i(1200,860)
	var stage := Node2D.new()
	root.add_child(stage)
	for facing in 2:
		for swap in 2:
			var viewport := SubViewport.new()
			viewport.size=Vector2i(600,400)
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			views.append(viewport)
			var world := Node2D.new()
			world.position=Vector2(300,160)
			world.scale=Vector2.ONE*2.3
			world.y_sort_enabled=true
			viewport.add_child(world)
			var pose: String=("eating" if facing==0 else "lying") if activities else "sleeping"
			var record := {"id":1,"kind":("cafe" if facing==0 else "sunbeds") if activities else "cabin","position":Vector2.ZERO,"orientation":0 if activities else facing}
			var cabin := PlacedResortObject.new()
			cabin.configure(record,assets)
			world.add_child(cabin)
			for role in 2:
				var actor := ResortWalker.new()
				actor.variant="female" if role==swap else "male"
				actor.configure(role+1,Vector2i.ZERO,AStarGrid2D.new(),[],assets)
				world.add_child(actor)
				actor.present_activity(GuestActivitySlots.slot(record,pose,role,assets),0)
			var picture := Sprite2D.new()
			picture.centered=false
			picture.texture=viewport.get_texture()
			picture.position=Vector2(swap*600,40+facing*420)
			stage.add_child(picture)
			var label := Label.new()
			label.text="%s %d · role 0 %s / role 1 %s" % [pose,facing,"female" if swap==0 else "male","male" if swap==0 else "female"]
			label.position=Vector2(swap*600+15,facing*420+12)
			stage.add_child(label)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var tag := "before"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="): tag=argument.trim_prefix("--tag=")
	var path := "res://artifacts/bed-alignment-"+tag+".png"
	root.get_texture().get_image().save_png(path)
	print("BED_ALIGNMENT_CAPTURE ",path)
	quit()
