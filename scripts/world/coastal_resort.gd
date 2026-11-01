class_name CoastalResort
extends Node2D
## Editable resort presentation. GuestStay owns the first simulated stay.

var layout: ResortLayout
var assets: ResortAssets
var terrain_view: CoastalTerrain
var world: Node2D
var camera: Camera2D
var overlay: MapOverlay
var hud: ResortHUD
var lighting: CanvasModulate
var placed: Array[PlacedResortObject] = []
var walkers: Array[ResortWalker] = []
var graph: AStarGrid2D
var targets: Array[Vector2i] = []
var build_kind := ""
var orientation := 0
var selected_id := -1
var moving_id := -1
var preview: PlacedResortObject
var preview_position := Vector2(INF, INF)
var preview_result: Dictionary = {}
var mode := "select"
var paused := false
var scene_speed := 1.0
var dragging_camera := false
var drag_origin := Vector2.ZERO
var dragged_distance := 0.0
var painting := false
var last_path_cell := Vector2i(-999, -999)
var elapsed := 0.0
var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var save_path := ResortLayout.SAVE_PATH
var capture_path := ""
var capture_frames := 0
var dirty := false
var toast_time := 0.0
var lighting_index := 0
var stay: GuestStay
var stay_actor: ResortWalker
var companion_actor: ResortWalker
var volley_ball: VolleyBallView
var inspecting_guest := false
var following_guest := false
# Only deterministic legacy stay/art regression tools select this fixture.
# The playable default is the live multi-booking resort.
var legacy_stay_fixture := false
var living: LivingResortRuntime
var population_view: ResortPopulationView
var management: CanvasLayer
var cleanliness_view: Node2D
var selected_person_id := -1
var management_refresh := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Resortis — Living resort")
	# The baked .tscn provides an actual editor preview. Runtime reconstructs it
	# from the authored JSON or saved layout so map tools share the same state.
	for child in get_children():
		child.free()
	for arg in OS.get_cmdline_user_args():
		if arg == "--workspace-data":
			save_path = "res://artifacts/coastal-layout.json"
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	assets = ResortAssets.new()
	layout = ResortLayout.new()
	layout.seed_default()
	if FileAccess.file_exists("res://data/coastal_map.json"):
		var authored_error := layout.load_layout("res://data/coastal_map.json")
		if authored_error != OK:
			push_warning("Authored layout could not be loaded; using the seed layout.")
	if FileAccess.file_exists(save_path) and not "--fresh" in OS.get_cmdline_user_args():
		var saved_error := layout.load_layout(save_path)
		if saved_error != OK:
			push_warning("Saved layout is invalid; the authored coastal map remains active.")
	terrain_view = CoastalTerrain.new()
	terrain_view.name = "Terrain"
	terrain_view.z_index = -100
	add_child(terrain_view)
	world = Node2D.new()
	world.name = "ResortObjects"
	world.y_sort_enabled = true
	add_child(world)
	overlay = MapOverlay.new()
	overlay.name = "PlacementAndSelection"
	overlay.z_index = -1
	add_child(overlay)
	lighting = CanvasModulate.new()
	lighting.name = "WorldLighting"
	add_child(lighting)
	camera = Camera2D.new()
	camera.name = "ResortCamera"
	add_child(camera)
	home_view()
	_refresh_layout()
	_add_backdrop_gardens()
	if legacy_stay_fixture: _spawn_walkers()
	home_view()
	hud = ResortHUD.new()
	hud.name = "ResortInterface"
	add_child(hud)
	hud.build(assets)
	hud.inspector.hide()
	hud.build_requested.connect(start_build)
	hud.action_requested.connect(_on_action)
	hud.category_requested.connect(func(_category: String) -> void: cancel_tool())
	if legacy_stay_fixture:
		stay = GuestStay.new()
		if layout.guest_stay.is_empty(): stay.party_size = 2
		stay.configure(layout, assets)
		if not layout.guest_stay.is_empty(): stay.restore(layout.guest_stay)
		stay_actor = ResortWalker.new()
		stay_actor.configure(100, ResortLayout.ARRIVAL, graph, [], assets)
		stay_actor.name = "Maya_FirstStay"
		world.add_child(stay_actor)
		companion_actor = ResortWalker.new()
		companion_actor.variant = "male"
		companion_actor.configure(101,ResortLayout.ARRIVAL,graph,[],assets)
		companion_actor.name = "Leo_Companion"
		world.add_child(companion_actor)
		volley_ball = VolleyBallView.new()
		world.add_child(volley_ball)
		_present_stay()
	else:
		_setup_living()
	if "--stay-view" in OS.get_cmdline_user_args():
		_inspect_guest()
		following_guest = true
		camera.zoom = Vector2.ONE * 1.65
	set_process_unhandled_input(true)
	if "--beach" in OS.get_cmdline_user_args():
		beach_view()
	if "--hide-ui" in OS.get_cmdline_user_args():
		hud.hide()
	if "--bake" in OS.get_cmdline_user_args():
		set_process(false)
		set_process_unhandled_input(false)

func home_view() -> void:
	camera.position = Vector2(-30, 700)
	camera.zoom = Vector2.ONE * 0.60
	if placed.is_empty():
		return
	var bounds := placed[0].sprite.get_global_transform() * placed[0].sprite.get_rect()
	for object in placed:
		bounds = bounds.merge(object.sprite.get_global_transform() * object.sprite.get_rect())
	bounds = bounds.grow(32)
	var viewport := get_viewport_rect().size
	var available := viewport - Vector2(64, 280)
	var factor := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	camera.zoom = Vector2.ONE * clampf(factor, 0.38, 0.9)
	camera.position = bounds.get_center() + Vector2(0, 45.0 / camera.zoom.x)

func beach_view() -> void:
	camera.position = IsometricGrid.project(Vector2(22, 30))
	camera.zoom = Vector2.ONE * 0.88

func _refresh_layout() -> void:
	for object in placed:
		object.free()
	placed.clear()
	terrain_view.build(layout)
	for record in layout.objects:
		var object := PlacedResortObject.new()
		object.configure(record, assets)
		world.add_child(object)
		placed.append(object)
	graph = layout.navigation()
	_rebuild_targets()
	for walker in walkers:
		walker.refresh_navigation(graph, targets)
	if stay != null: stay.layout_changed()
	if living != null: living.layout_changed()
	if preview != null:
		preview.queue_free()
		preview = null
	preview_position = Vector2(INF, INF)
	_update_selected_outline()
	if hud != null:
		hud.tools.undo.disabled = undo_stack.is_empty()

func _rebuild_targets() -> void:
	targets.clear()
	var candidates: Array[Vector2i] = [Vector2i(22, 19), Vector2i(22, 10), Vector2i(39, 19), Vector2i(9, 10), Vector2i(16, 10), Vector2i(9, 17), Vector2i(16, 17), Vector2i(26, 17), Vector2i(34, 17), Vector2i(32, 10), Vector2i(10, 28), Vector2i(17, 28), Vector2i(24, 28), Vector2i(38, 28), Vector2i(8, 26), Vector2i(13, 26), Vector2i(18, 26), Vector2i(32, 32), Vector2i(5, 35), Vector2i(14, 35), Vector2i(23, 35)]
	var entrance := Vector2i(22, 19)
	if graph.is_point_solid(entrance):
		for cell in layout.paths:
			if not graph.is_point_solid(cell):
				entrance = cell
				break
	for cell in candidates:
		if graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not graph.get_id_path(entrance, cell).is_empty():
			targets.append(cell)

func _spawn_walkers() -> void:
	if targets.is_empty():
		return
	for index in 14:
		var walker := ResortWalker.new()
		walker.variant = "male" if index%3==0 else "female"
		walker.configure(index, targets[(index * 5 + 3) % targets.size()], graph, targets, assets)
		world.add_child(walker)
		walkers.append(walker)

func _add_backdrop_gardens() -> void:
	# Scenery beyond the editable property's rear edge gives the coast a setting.
	# It has no occupancy or placement state inside the buildable map.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3101026
	for x in range(-6, 51, 2):
		for y in [-3, 0]:
			var object := PlacedResortObject.new()
			object.configure({"id": 5000 + x * 10 + y, "kind": "palm" if rng.randf() > 0.35 else "small_palm", "position": Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4)), "orientation": 0}, assets)
			object.name = "RearCanopy_%d_%d" % [x, y]
			world.add_child(object)
	for y in range(3, 21, 3):
		for x in [-2, 46]:
			var object := PlacedResortObject.new()
			object.configure({"id": 6000 + y * 10 + x, "kind": "palm", "position": Vector2(x, y), "orientation": 0}, assets)
			object.name = "EdgeCanopy_%d_%d" % [x, y]
			world.add_child(object)

func _process(delta: float) -> void:
	toast_time = maxf(0.0, toast_time - delta)
	if not paused:
		var time_step := minf(delta, 0.1) * scene_speed
		elapsed += time_step
		terrain_view.advance(time_step)
		for walker in walkers:
			walker.advance(time_step)
		if stay != null:
			stay.advance(time_step)
			_present_stay()
			if moving_id > 0 and stay.protects(moving_id):
				cancel_tool()
				_toast("The guest has reserved this building. Editing is available after use finishes.", false)
		if living != null:
			living.advance(time_step)
			population_view.refresh()
			if cleanliness_view!=null: cleanliness_view.call("refresh")
			if moving_id>0 and living.protects(moving_id):
				cancel_tool()
				_toast("This building is now in use. Wait until it is free.",false)
	else:
		for walker in walkers:
			walker.sprite.pause()
	_keyboard_camera(delta)
	if following_guest and stay_actor != null:
		camera.position = stay_actor.position + Vector2(0, -35)
		camera.force_update_scroll()
	if following_guest and population_view!=null and population_view.actors.has(selected_person_id):
		var person: Dictionary=living.simulation.call("person",selected_person_id)
		if person.get("state")=="departed": following_guest=false
		else:
			camera.position=population_view.actor_position(selected_person_id)+Vector2(0,-35)
			camera.force_update_scroll()
	if inspecting_guest and hud.inspector.visible:
		hud.update_guest(stay)
	if stay != null: hud.update_stay_status(stay, paused)
	if living!=null:
		management_refresh-=delta
		if management_refresh<=0:
			_refresh_management()
			management_refresh=0.2
	if mode in ["build", "move"]:
		_update_preview()
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 18:
			_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	print("CAPTURE_RESULT ", error, " ", capture_path)
	get_tree().quit(0 if error == OK else 1)

func _keyboard_camera(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if direction != Vector2.ZERO: following_guest = false
		camera.position += direction.normalized() * delta * 650.0 / camera.zoom.x
	_clamp_camera()

func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, -1200, 1500)
	camera.position.y = clampf(camera.position.y, 150, 1500)

func _input(event: InputEvent) -> void:
	# A drag may end over a toolbar; releases must still reach the map controller.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			dragging_camera = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = false
			last_path_cell = Vector2i(-999, -999)
	if event is InputEventKey and event.pressed and not event.echo:
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		if event.keycode == KEY_SPACE:
			_on_action("pause")
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode in [KEY_S, KEY_Z, KEY_Y]:
			if event.keycode == KEY_S: _on_action("save")
			elif event.keycode == KEY_Y or event.shift_pressed: _on_action("redo")
			else: _on_action("undo")
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before := get_global_mouse_position()
			var factor := 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12
			camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.38, 1.8)
			camera.force_update_scroll()
			camera.position += before - get_global_mouse_position()
			_clamp_camera()
		elif event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			following_guest = false
			dragging_camera = event.pressed
			if event.pressed:
				drag_origin = event.position
				dragged_distance = 0.0
			elif event.button_index == MOUSE_BUTTON_RIGHT and dragged_distance < 4.0:
				cancel_tool()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			painting = event.pressed and mode in ["path", "erase_path"]
			if not event.pressed:
				last_path_cell = Vector2i(-999, -999)
				return
			if mode in ["build", "move"]:
				_commit_preview()
			elif mode in ["path", "erase_path"]:
				_paint_path()
			else:
				select_at(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if dragging_camera:
			dragged_distance = maxf(dragged_distance, event.position.distance_to(drag_origin))
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera()
		elif painting:
			_paint_path()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_S:
			_on_action("save")
		elif event.ctrl_pressed and event.keycode == KEY_Z:
			_on_action("redo" if event.shift_pressed else "undo")
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			_on_action("redo")
		else:
			match event.keycode:
				KEY_ESCAPE: cancel_tool()
				KEY_SPACE: _on_action("pause")
				KEY_G: _on_action("grid")
				KEY_HOME: home_view()
				KEY_R: _on_action("rotate")
				KEY_DELETE: _on_action("remove")
				KEY_B: hud.show_category("Resort")
				KEY_F1: _on_action("guide")

func start_build(kind: String) -> void:
	cancel_tool(false)
	build_kind = kind
	orientation = 0
	mode = "build"
	hud.show_object(kind)
	hud.highlight_build(kind)
	preview_position = Vector2(INF, INF)
	_update_preview()

func _update_preview() -> void:
	var logical := IsometricGrid.unproject(get_global_mouse_position())
	var size := ResortCatalog.footprint(build_kind, orientation)
	var position := layout.snapped_position(build_kind, logical - Vector2(size - Vector2i.ONE) * 0.5)
	if position == preview_position and preview != null:
		return
	preview_position = position
	preview_result = layout.validate(build_kind, position, orientation, moving_id)
	if preview_result.ok and stay != null and stay.state != "departed" and Rect2(position - Vector2(0.5, 0.5), Vector2(size)).has_point(stay.logical_position):
		preview_result = {"ok": false, "reason": "A guest is passing through this space. Wait until it is clear."}
	if preview_result.ok and stay != null and stay.party_size==2 and stay.state!="departed" and Rect2(position-Vector2(0.5,0.5),Vector2(size)).has_point(stay.companion.position):
		preview_result = {"ok":false,"reason":"Wait until the other guest has passed this space."}
	if preview_result.ok and living!=null and living.contains_person(Rect2(position-Vector2(0.5,0.5),Vector2(size))):
		preview_result={"ok":false,"reason":"Wait until the guests or staff have passed this space."}
	if preview != null:
		preview.free()
	preview = PlacedResortObject.new()
	preview.configure({"id": -1, "kind": build_kind, "position": position, "orientation": orientation}, assets)
	preview.name = "PlacementPreview"
	preview.modulate = Color(1, 1, 1, 0.65) if preview_result.ok else Color(1, 0.55, 0.48, 0.60)
	preview.z_index = 1
	world.add_child(preview)
	overlay.footprint = IsometricGrid.footprint_polygon(position, size)
	overlay.valid = preview_result.ok
	var def := ResortCatalog.definition(build_kind)
	overlay.entrance = IsometricGrid.project(position + Vector2(ResortCatalog.entrance(build_kind, orientation))) if def.get("access", false) else Vector2(INF, INF)
	overlay.queue_redraw()
	hud.set_status(preview_result.reason + (" · R changes the cabin view" if def.frames.size() > 1 else ""), preview_result.ok)

func _commit_preview() -> void:
	if moving_id > 0 and _protected(moving_id):
		cancel_tool()
		_toast("This building is now reserved. Wait until the guest has finished using it.", false)
		return
	# A guest can enter a previously clear preview while the pointer stays still.
	preview_position = Vector2(INF, INF)
	_update_preview()
	if not preview_result.get("ok", false):
		_toast(preview_result.get("reason", "Choose a valid placement."), false)
		return
	var before := _snapshot()
	var result: Dictionary
	if mode == "move":
		result = layout.move_object(moving_id, preview_position, orientation)
	else:
		result = layout.place(build_kind, preview_position, orientation)
	if result.ok and not _access_survives(layout):
		layout.objects.assign(before.objects)
		layout.paths=before.paths.duplicate(true)
		layout.next_id=before.next_id
		layout.revision+=1
		_toast("Keep an accessible route open for every guest and cleaner.",false)
		return
	if result.ok:
		_remember(before)
		if mode == "move":
			cancel_tool()
		_refresh_layout()
		dirty = true
		_toast("Layout updated · Ctrl+Z to undo")

func cancel_tool(show_guide := true) -> void:
	inspecting_guest = false
	following_guest = false
	if management!=null: management.call("close")
	if preview != null:
		preview.free()
		preview = null
	for object in placed:
		object.show()
	mode = "select"
	build_kind = ""
	moving_id = -1
	selected_id = -1
	painting = false
	overlay.footprint.clear()
	overlay.selected.clear()
	overlay.entrance = Vector2(INF, INF)
	overlay.queue_redraw()
	if hud != null:
		hud.highlight_build("")
		hud.set_status("Drag with the middle or right mouse button to pan · Wheel to zoom · Space to pause")
		if show_guide:
			hud.inspector.hide()

func select_at(point: Vector2) -> void:
	cancel_tool(false)
	if population_view!=null:
		var person_id := population_view.hit_test(point)
		if person_id>0:
			selected_person_id=person_id
			_inspect_guest()
			return
	if stay_actor!=null and ((stay_actor.visible and stay_actor.hit_test(point)) or (companion_actor.visible and companion_actor.hit_test(point))):
		_inspect_guest()
		return
	var candidates := placed.duplicate()
	candidates.sort_custom(func(a: PlacedResortObject, b: PlacedResortObject) -> bool: return a.position.y > b.position.y)
	for object in candidates:
		if object.hit_test(point):
			selected_id = object.object_id
			hud.show_object(object.kind, object.orientation, true)
			_update_selected_outline()
			return
	hud.inspector.hide()

func _update_selected_outline() -> void:
	overlay.selected.clear()
	var selected := layout.find_object(selected_id)
	if not selected.is_empty():
		overlay.selected = IsometricGrid.footprint_polygon(selected.position, ResortCatalog.footprint(selected.kind, selected.orientation))
	overlay.queue_redraw()

func _paint_path() -> void:
	var cell := IsometricGrid.cell_at(get_global_mouse_position())
	if cell == last_path_cell:
		return
	last_path_cell = cell
	if layout.is_path(cell) == (mode == "path"):
		return
	if mode == "erase_path" and stay != null and (cell == Vector2i(stay.logical_position.round()) or (stay.party_size==2 and cell==Vector2i(stay.companion.position.round()))):
		_toast("Wait until the guest has left this path tile.", false)
		return
	if mode=="erase_path" and living!=null and living.contains_person(Rect2(Vector2(cell)-Vector2(0.49,0.49),Vector2(0.98,0.98))):
		_toast("Wait until the guests or staff have left this path tile.",false)
		return
	var before := _snapshot()
	var result := layout.set_path(cell, mode == "path")
	if result.ok and not _access_survives(layout):
		layout.paths = before.paths
		result = {"ok": false, "reason": "Keep a route open for the guest currently using this path."}
	if result.ok:
		_remember(before)
		_refresh_layout()
		dirty = true
	hud.set_status(result.reason, result.ok)

func _snapshot() -> Dictionary:
	return {"objects": layout.objects.duplicate(true), "paths": layout.paths.duplicate(true), "next_id": layout.next_id}

func _remember(before: Dictionary) -> void:
	undo_stack.append(before)
	if undo_stack.size() > 80:
		undo_stack.pop_front()
	redo_stack.clear()

func _restore(snapshot: Dictionary) -> bool:
	if living!=null:
		for record in layout.objects:
			if not living.protects(record.id): continue
			var found := false
			for previous: Dictionary in snapshot.objects:
				if previous==record: found=true
			if not found:
				_toast("Wait until guests have finished using this building before undoing it.",false)
				return false
		var candidate := ResortLayout.new()
		candidate.objects.assign(snapshot.objects)
		candidate.paths=snapshot.paths
		if not living.access_survives(candidate):
			_toast("Keep an accessible route open for every guest and cleaner.",false)
			return false
	if stay != null:
		for id in [stay.cabin_id, stay.facility_id]:
			if not stay.protects(id): continue
			var found := false
			for record in snapshot.objects:
				if record == layout.find_object(id): found = true
			if not found:
				_toast("Undo is waiting until the guest finishes using this building.", false)
				return false
		var candidate := ResortLayout.new()
		candidate.objects.assign(snapshot.objects)
		candidate.paths = snapshot.paths
		if not stay.access_survives(candidate):
			_toast("Wait until the guest has left the path affected by this edit.", false)
			return false
	cancel_tool()
	layout.objects.assign(snapshot.objects)
	layout.paths = snapshot.paths.duplicate(true)
	layout.next_id = snapshot.next_id
	layout.revision += 1
	_refresh_layout()
	dirty = true
	return true

func _toast(message: String, valid := true) -> void:
	toast_time = 4.0
	hud.set_status(message, valid)

func _on_action(action: String) -> void:
	if action in ["move", "remove", "rotate"] and _protected(selected_id):
		_toast("Wait until the guests have finished using this building.", false)
		return
	if living!=null and action in ["staff","facilities","operations"]:
		cancel_tool(false)
		hud.inspector.hide()
		management.call("show_section",action)
		_refresh_management()
		return
	match action:
		"guest": _inspect_guest()
		"follow_guest":
			following_guest = not following_guest
			if following_guest: camera.zoom = Vector2.ONE * 1.65
		"new_stay":
			if stay!=null and stay.state == "departed":
				var size := 1 if stay.party_size == 2 else 2
				stay = GuestStay.new()
				stay.party_size = size
				stay.configure(layout, assets)
				_inspect_guest()
		"cancel": cancel_tool()
		"pause":
			paused = not paused
			hud.set_speed(scene_speed, paused)
		"speed_1", "speed_2", "speed_4":
			scene_speed = float(action.trim_prefix("speed_"))
			paused = false
			hud.set_speed(scene_speed, paused)
		"grid":
			terrain_view.show_grid = not terrain_view.show_grid
			terrain_view.queue_redraw()
			hud.tools.grid.button_pressed = terrain_view.show_grid
		"home": following_guest = false; home_view()
		"beach_view": following_guest = false; beach_view(); hud.inspector.hide()
		"guide":
			if management!=null: management.call("close")
			inspecting_guest = false
			if hud.inspector.visible: hud.inspector.hide()
			else: hud.show_overview()
		"save":
			layout.guest_stay = stay.capture() if stay!=null else {}
			layout.live_resort = living.capture() if living!=null else {}
			var result := layout.save_layout(save_path)
			if result == OK:
				dirty = false
				_toast("Resort, guests and staff saved. The previous copy is kept as a backup.")
			else:
				_toast("Could not save this layout. Your current map is still open.", false)
		"move":
			var selected := layout.find_object(selected_id)
			if not selected.is_empty():
				build_kind = selected.kind
				orientation = selected.orientation
				moving_id = selected_id
				mode = "move"
				for object in placed:
					if object.object_id == moving_id: object.hide()
				preview_position = Vector2(INF, INF)
				hud.show_object(build_kind, orientation)
		"remove":
			if selected_id > 0:
				_remember(_snapshot())
				layout.remove_object(selected_id)
				cancel_tool()
				_refresh_layout()
				dirty = true
				_toast("Object removed · Ctrl+Z to undo")
		"rotate": _rotate()
		"path", "erase_path":
			cancel_tool()
			mode = action
			hud.set_status("Click or drag to lay a stone path." if action == "path" else "Click or drag to remove a path.")
		"undo":
			if not undo_stack.is_empty():
				var before := _snapshot()
				if _restore(undo_stack.back()):
					undo_stack.pop_back()
					redo_stack.append(before)
					_toast("Undid the last layout change.")
		"redo":
			if not redo_stack.is_empty():
				var before := _snapshot()
				if _restore(redo_stack.back()):
					redo_stack.pop_back()
					undo_stack.append(before)
					_toast("Restored the layout change.")
		"calm": terrain_view.calm_water = not terrain_view.calm_water
		"lighting":
			lighting_index = (lighting_index + 1) % 3
			lighting.color = [Color.WHITE, Color(1.0, 0.82, 0.65), Color(0.52, 0.64, 0.84)][lighting_index]

func _rotate() -> void:
	var record := layout.find_object(selected_id)
	var kind := build_kind if not build_kind.is_empty() else str(record.get("kind", ""))
	if kind.is_empty(): return
	var count: int = ResortCatalog.definition(kind).frames.size()
	if count < 2:
		_toast("This object has one authored view.")
		return
	if mode in ["build", "move"]:
		orientation = (orientation + 1) % count
		preview_position = Vector2(INF, INF)
		_update_preview()
		hud.show_object(kind, orientation)
	elif not record.is_empty():
		var before := _snapshot()
		var result := layout.move_object(record.id, record.position, (int(record.orientation) + 1) % count)
		if result.ok:
			_remember(before)
			_refresh_layout()
			dirty = true
			hud.show_object(kind, record.orientation, true)

func _inspect_guest() -> void:
	cancel_tool(false)
	inspecting_guest = true
	if living!=null:
		hud.inspector.hide()
		management.call("show_section","guests")
		_refresh_management()
	else: hud.show_guest(stay)

func _protected(id: int) -> bool:
	return living.protects(id) if living!=null else stay!=null and stay.protects(id)

func _access_survives(candidate: ResortLayout) -> bool:
	return living.access_survives(candidate) if living!=null else stay==null or stay.access_survives(candidate)

func _setup_living() -> void:
	living=LivingResortRuntime.new()
	if not living.configure(layout,assets):
		push_error("The living-resort modules are missing or could not initialize.")
		living=null
		return
	if not layout.live_resort.is_empty():
		if not living.restore(layout.live_resort): push_error("The saved living resort could not be restored.")
	elif not layout.guest_stay.is_empty():
		if not living.import_legacy(layout.guest_stay): push_error("The saved booking could not be migrated.")
	for person: Dictionary in living.simulation.get("people"):
		if person.state!="departed":
			selected_person_id=int(person.id)
			break
	population_view=ResortPopulationView.new()
	population_view.configure(living,assets)
	world.add_child(population_view)
	var art_script := load("res://scripts/world/cleanliness_view.gd") as Script
	cleanliness_view=art_script.new()
	world.add_child(cleanliness_view)
	cleanliness_view.call("configure",living.cleanliness,assets)
	var ui_script := load("res://scripts/ui/resort_management_ui.gd") as Script
	management=ui_script.new()
	add_child(management)
	if management.has_method("build"): management.call("build")
	management.connect("action_requested",_management_action)
	management.call("close")
	hud.enable_management_menu()
	_refresh_management()

func _refresh_management() -> void:
	if living==null or management==null: return
	var view := living.inspect(selected_person_id,following_guest)
	management.call("refresh",view)
	var count := 0
	for person: Dictionary in living.simulation.get("people"):
		if person.state!="departed": count+=1
	hud.motion_label.text="%s · %d guests" % ["Paused" if paused else "Day %d" % (1+int(float(view.clock)/180)),count]

func _management_action(action: String,id: int) -> void:
	if action in ["select_guest","follow_guest"] and living.simulation.call("person",id).is_empty(): return
	match action:
		"select_guest":
			selected_person_id=id
			following_guest=false
		"follow_guest":
			if selected_person_id==id: following_guest=not following_guest
			else:
				selected_person_id=id
				following_guest=true
			if following_guest: camera.zoom=Vector2.ONE*1.65
		"hire_janitor":
			var result: Dictionary=living.cleanliness.call("hire")
			_toast(str(result.get("reason","Janitor hired.")),bool(result.get("ok",false)))
			if result.get("ok",false): dirty=true
		"dismiss_janitor":
			var result: bool=living.cleanliness.call("dismiss",id)
			_toast("Janitor dismissed." if result else "This janitor is no longer on staff.",result)
			if result: dirty=true
		"close":
			inspecting_guest=false
			management.call("close")
	if cleanliness_view!=null: cleanliness_view.call("refresh")
	_refresh_management()

func _present_stay() -> void:
	stay_actor.present(stay.logical_position, stay.walked_distance, stay.direction, stay.moving)
	stay_actor.visible = stay.state != "departed"
	companion_actor.present(stay.companion.position,stay.companion.distance,stay.companion.direction,stay.companion.moving)
	companion_actor.visible = stay.party_size == 2 and stay.state != "departed"
	var slot := stay.activity_slot(0)
	if not slot.is_empty():
		stay_actor.present_activity(slot,stay.activity_elapsed)
		if stay.party_size == 2: companion_actor.present_activity(stay.activity_slot(1),stay.activity_elapsed+(2.0 if stay.state=="playing_volleyball" else 0.2))
	volley_ball.present(stay)
	hud.update_stay_status(stay, paused)
