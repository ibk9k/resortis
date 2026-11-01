extends SceneTree
## Isolated native render of real arrivals waiting at a full resort.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var resort = load("res://scenes/world/coastal_resort.tscn").instantiate()
	resort.save_path = "res://artifacts/arrival-preview-isolated-%d.json" % OS.get_process_id()
	root.add_child(resort)
	resort.set_process(false)
	resort.set_process_input(false)
	resort.set_process_unhandled_input(false)
	var cabins := 0
	for record in resort.layout.objects.duplicate():
		if record.kind == "cabin":
			cabins += 1
			if cabins > 1: resort.layout.remove_object(record.id)
	resort._refresh_layout()
	for tick in 500: resort._process(0.1)
	var notice: PanelContainer = resort.population_view.arrival_notice
	if not notice.visible:
		push_error("Actual arrival queue was not observed")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(700, 440)
	viewport.world_2d = resort.get_world_2d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera2D.new()
	camera.position = notice.position + Vector2(notice.size.x / 2, 70)
	camera.zoom = Vector2.ONE * 1.5
	viewport.add_child(camera)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://artifacts/arrival-wait-preview.png")
	print("ARRIVAL_WAIT_CAPTURE native viewport, actual booking queue")
	resort.free()
	quit()
