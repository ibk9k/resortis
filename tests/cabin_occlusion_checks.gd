extends SceneTree
## Compare actual GPU body pixels along both authored aisles. An unsplit cabin
## is the negative control, so this checks the real hidden-body failure.
var library: ResortAssets
var sets: Array = []

func _initialize() -> void:
	_run.call_deferred()

func view(point: Vector2, facing: int, mode: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400,300)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world := Node2D.new()
	world.position = Vector2(200,150)
	world.y_sort_enabled = true
	viewport.add_child(world)
	if mode != "solo":
		var cabin := PlacedResortObject.new()
		cabin.configure({"id": 1, "kind": "cabin", "position": Vector2.ZERO, "orientation": facing}, library)
		if mode == "legacy":
			cabin.y_sort_enabled = false
			for child in cabin.get_children(): child.hide()
			cabin.sprite.show()
		world.add_child(cabin)
	var guest := ResortWalker.new()
	guest.configure(100, Vector2i.ZERO, AStarGrid2D.new(), [], library)
	guest.present(point, 0.25, Vector2(-1,-1), false)
	world.add_child(guest)
	root.add_child(viewport)
	return viewport

func _run() -> void:
	library = ResortAssets.new()
	for facing in 2:
		var record := {"id": 1, "kind": "cabin", "position": Vector2.ZERO, "orientation": facing}
		for point in CabinInterior.aisle(record, library):
			sets.append({"point": point, "views": [view(point, facing, "solo"), view(point, facing, "current"), view(point, facing, "legacy")]})
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var current_hidden := 0
	var legacy_hidden := 0
	for sample in sets:
		var solo: Image = sample.views[0].get_texture().get_image()
		var current: Image = sample.views[1].get_texture().get_image()
		var legacy: Image = sample.views[2].get_texture().get_image()
		var foot: Vector2 = Vector2(200,150) + IsometricGrid.project(sample.point)
		for y in mini(solo.get_height(), int(foot.y - 10)):
			for x in solo.get_width():
				var expected := solo.get_pixel(x,y)
				if expected.a < 0.98: continue
				if difference(expected, current.get_pixel(x,y)) > 0.04: current_hidden += 1
				if difference(expected, legacy.get_pixel(x,y)) > 0.04: legacy_hidden += 1
	print("CABIN_OCCLUSION_CHECKS ", JSON.stringify({"current_hidden_torso_pixels": current_hidden, "unsplit_hidden_torso_pixels": legacy_hidden}))
	quit(0 if current_hidden == 0 and legacy_hidden > 20 else 1)

func difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))
