extends SceneTree
## Compact native viewport of a naturally admitted live rally, not image crops.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var resort = load("res://scenes/world/coastal_resort.tscn").instantiate()
	resort.save_path="res://artifacts/volleyball-hit-preview-isolated-"+str(OS.get_process_id())+".json"
	root.add_child(resort)
	resort.set_process(false)
	resort.set_process_input(false)
	resort.set_process_unhandled_input(false)
	var pair: Array[Dictionary]=[]
	for tick in 1800:
		resort._process(0.1)
		pair.clear()
		for person: Dictionary in resort.living.simulation.people:
			if person.state=="volleyball": pair.append(person)
		if pair.size()==2: break
	if pair.size()!=2:
		push_error("No natural rally for compact preview")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size=Vector2i(640,400)
	viewport.world_2d=resort.get_world_2d()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera2D.new()
	camera.position=IsometricGrid.project((pair[0].motion.position+pair[1].motion.position)*0.5)+Vector2(0,-22)
	camera.zoom=Vector2.ONE*1.65
	viewport.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/volleyball-hit-compact")
	for frame in 40:
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://artifacts/volleyball-hit-compact/frame-%02d.png" % frame)
		resort._process(0.1)
	print("VOLLEYBALL_HIT_PREVIEW 40 native frames at 640x400")
	resort.free()
	quit()
