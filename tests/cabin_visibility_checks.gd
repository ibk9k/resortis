extends SceneTree

var assets: ResortAssets
var cases: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _view(facing: int, mode: String, point := Vector2.ZERO, pose := {}, variant := "female", zoom := 1.0) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	world.position = Vector2(320.35, 240.3)
	world.scale = Vector2.ONE * zoom
	world.y_sort_enabled = true
	viewport.add_child(world)
	if zoom > 1.0:
		world.position = IsometricGrid.project(Vector2(6, 13))
		world.scale = Vector2.ONE
		var camera := Camera2D.new()
		camera.position = world.position + GroundRegistration.sort_offset(Vector2i(4, 4)) + Vector2(0, -35)
		camera.zoom = Vector2.ONE * zoom
		viewport.add_child(camera)
	var record := {"id": 1, "kind": "cabin", "position": Vector2.ZERO, "orientation": facing}
	if mode != "guest":
		var cabin := PlacedResortObject.new()
		cabin.configure(record, assets)
		if mode == "flat":
			cabin.y_sort_enabled = false
			for child in cabin.get_children(): child.hide()
			cabin.sprite.show()
		elif mode == "old_stairs":
			var stairs := cabin.get_node("Stairs") as Node2D
			var old_position := IsometricGrid.project(Vector2(3.45, 3.45)) - GroundRegistration.sort_offset(Vector2i(4, 4))
			(stairs.get_node("Art") as Sprite2D).position -= old_position - stairs.position
			stairs.position = old_position
		world.add_child(cabin)
	if mode in ["guest", "current", "old_stairs"] and (not pose.is_empty() or point != Vector2.ZERO):
		var population := Node2D.new()
		population.y_sort_enabled = true
		world.add_child(population)
		var guest := ResortWalker.new()
		guest.variant = variant
		guest.configure(1, Vector2i.ZERO, AStarGrid2D.new(), [], assets)
		population.add_child(guest)
		if pose.is_empty(): guest.present(point, 0.25, Vector2(-1, -1), false)
		else: guest.present_activity(pose, 0.0)
	return viewport

func _hidden(guest: Image, scene: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var expected := guest.get_pixel(x, y)
			var actual := scene.get_pixel(x, y)
			if expected.a > 0.98 and absf(expected.r-actual.r) + absf(expected.g-actual.g) + absf(expected.b-actual.b) > 0.15:
				count += 1
	return count

func _run() -> void:
	assets = ResortAssets.new()
	for facing in 2:
		var record := {"id": 1, "kind": "cabin", "position": Vector2.ZERO, "orientation": facing}
		var door := Vector2(ResortCatalog.entrance("cabin", facing))
		var aisle := CabinInterior.aisle(record, assets)[0]
		for step in range(3, 6):
			var point := door.lerp(aisle, float(step) / 8.0)
			cases.append({"kind":"stairs", "facing":facing, "point":point, "guest":_view(facing,"guest",point), "current":_view(facing,"current",point), "old":_view(facing,"old_stairs",point)})
		for role in 2:
			for variant in ["female", "male"]:
				var pose := GuestActivitySlots.slot(record, "sleeping", role, assets)
				cases.append({"kind":"sleep", "facing":facing, "role":role, "variant":variant, "guest":_view(facing,"guest",pose.position,pose,variant), "current":_view(facing,"current",pose.position,pose,variant)})
		cases.append({"kind":"seams", "facing":facing, "flat":_view(facing,"flat",Vector2.ZERO,{},"female",3.0), "current":_view(facing,"current",Vector2.ZERO,{},"female",3.0)})
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var old_stair_pixels := 0
	for sample in cases:
		var current: Image = sample.current.get_texture().get_image()
		if sample.kind == "seams":
			var flat: Image = sample.flat.get_texture().get_image()
			for y in flat.get_height():
				for x in flat.get_width():
					if flat.get_pixel(x,y).a < 0.98: continue
					if current.get_pixel(x,y).a < 0.95: failures.append("Cabin %d has a visible layer gap" % sample.facing); break
			continue
		var guest: Image = sample.guest.get_texture().get_image()
		var region := Rect2i(0,0,640,480)
		if sample.kind == "stairs":
			var foot := Vector2(320.35, 240.3) + IsometricGrid.project(sample.point)
			region = Rect2i(0, floori(foot.y)-12, 640, 17)
			old_stair_pixels += _hidden(guest, sample.old.get_texture().get_image(), region)
		var hidden := _hidden(guest, current, region)
		if hidden > 0: failures.append("Cabin %d hides %d guest pixels during %s" % [sample.facing, hidden, sample.kind])
	if old_stair_pixels == 0: failures.append("Previous stair clipping was not reproduced")
	print("CABIN_VISIBILITY_CHECKS ", JSON.stringify({"failures":failures,"previous_stair_pixels":old_stair_pixels}))
	quit(0 if failures.is_empty() else 1)
