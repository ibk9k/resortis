extends SceneTree

var checks := 0
var failures: Array[String] = []

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/world/coastal_resort.tscn") as PackedScene
	var resort := scene.instantiate() as CoastalResort
	resort.legacy_stay_fixture=true
	# Bind the isolated save before _ready; never use the player's workspace save.
	resort.save_path = "res://artifacts/test-ui-layout.json"
	root.add_child(resort)
	await process_frame
	resort.set_process(false)
	expect(resort.placed.size() == resort.layout.objects.size(), "Every placed record has an independent scene object")
	expect(resort.walkers.size() == 14, "The proof starts with fourteen ambient guests")
	expect(not resort.hud.inspector.visible, "The initial view leaves the pool unobstructed")
	var point := Vector2.ZERO
	var first := resort.placed[0]
	var first_id := first.object_id
	var image := first.sprite.texture.get_image()
	for y in range(int(image.get_height() * 0.45), int(image.get_height() * 0.75)):
		var x := image.get_width() / 2
		if image.get_pixel(x, y).a > 0.75:
			point = first.sprite.to_global(first.sprite.offset + Vector2(x, y))
			break
	expect(first.hit_test(point), "The visible cabin pixels can be picked")
	resort.select_at(point)
	expect(resort.selected_id == first_id, "Clicking the cabin selects its logical record")
	expect(resort.hud.inspector.visible, "Selection opens the inspector")
	var before: int = resort.layout.find_object(first_id).orientation
	resort.hud.tools.rotate.pressed.emit()
	expect(resort.layout.find_object(first_id).orientation != before, "The rotate action changes the cabin view")
	resort._on_action("undo")
	expect(resort.layout.find_object(first_id).orientation == before, "Undo restores the original cabin view")
	resort._on_action("redo")
	expect(resort.layout.find_object(first_id).orientation != before, "Redo restores the edited cabin view")
	resort.selected_id = first_id
	resort._on_action("move")
	expect(resort.mode == "move", "Move enters placement mode")
	resort.cancel_tool()
	expect(resort.placed[0].visible and resort.mode == "select", "Cancelling a move restores the existing cabin")
	resort.hud.show_category("Beach")
	expect(resort.hud.build_buttons.has("volleyball") and resort.hud.build_buttons.has("pier"), "Beach facilities are present in the working catalogue")
	resort.hud.build_buttons.sunbeds.pressed.emit()
	expect(resort.build_kind == "sunbeds" and resort.mode == "build", "The build button opens the correct placement tool")
	resort.cancel_tool()
	resort._on_action("grid")
	expect(resort.terrain_view.show_grid, "Grid control enables the world overlay")
	var original_zoom := resort.camera.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	resort._unhandled_input(wheel)
	expect(resort.camera.zoom.x > original_zoom.x, "Mouse wheel zooms the camera")
	resort.home_view()
	var positions: Array[Vector2] = []
	for walker in resort.walkers:
		positions.append(walker.logical_position)
	resort._on_action("pause")
	for frame in 30:
		resort._process(1.0 / 60.0)
	for i in resort.walkers.size():
		expect(resort.walkers[i].logical_position == positions[i], "Pause holds guest position " + str(i))
	var clock_before := resort.elapsed
	resort._on_action("speed_4")
	resort._process(0.1)
	expect(is_equal_approx(resort.elapsed - clock_before, 0.4), "The scene clock advances at four times speed")
	resort._on_action("speed_1")
	resort._on_action("lighting")
	expect(resort.lighting.color != Color.WHITE, "Lighting preview changes the world tint")
	resort._on_action("lighting")
	resort._on_action("lighting")
	resort._on_action("calm")
	expect(resort.terrain_view.calm_water, "Calm water is independently selectable")
	resort._on_action("calm")
	for frame in 3600:
		for walker in resort.walkers:
			walker.advance(1.0 / 60.0)
	for walker in resort.walkers:
		var cell := Vector2i(walker.logical_position.round())
		expect(resort.graph.is_in_boundsv(cell) and not resort.graph.is_point_solid(cell), "Walking guest remains on navigable ground " + str(walker.actor_id))
	resort._on_action("save")
	expect(FileAccess.file_exists(resort.save_path), "Save layout control writes the current edited map")
	resort._on_action("guide")
	await process_frame
	expect(resort.hud.inspector.visible, "The guide can be reopened")
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for control in [resort.hud.inspector, resort.hud.tools.save, resort.hud.tools["category_Paths"], resort.hud.tools.undo]:
		expect(viewport.encloses(control.get_global_rect()), "Control stays inside viewport: " + control.name)
	if not DisplayServer.get_name() == "headless":
		resort.hud.show_category("Garden")
		resort.hud.inspector.hide()
		resort.terrain_view.show_grid = false
		resort.terrain_view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/coastal-map-qa.png")
	print("SCENE_CHECKS ", checks, " checks; ", failures.size(), " failures")
	var report := FileAccess.open("res://artifacts/scene-checks.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	resort.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
