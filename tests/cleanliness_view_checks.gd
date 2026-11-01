extends SceneTree
## Presentation seam checks use inert frame fixtures, not unapproved art bakes.
## Staff source/motion appearance is covered separately by real GPU previews.
const Service = preload("res://scripts/simulation/cleanliness_system.gd")
const View = preload("res://scripts/world/cleanliness_view.gd")
const Art = preload("res://assets/staff/janitor_art.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _json(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data))

func _fixture_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	for facing: String in Art.DIRS:
		for kind in ["walk", "idle", "clean"]:
			var animation := "%s_%s" % [kind, facing]
			frames.add_animation(animation)
			for index in (16 if kind == "walk" else (4 if kind == "clean" else 1)): frames.add_frame(animation, texture)
	return frames

func _run() -> void:
	var map := ResortLayout.new()
	map.seed_default()
	var service := Service.new()
	service.configure(map, null)
	for record in map.objects:
		if record.kind == "cafe":
			for index in 40: service.on_activity_finished(index + 1, record.id, "meal", 0.0)
	for index in 3: service.hire()
	var view := View.new()
	# Suppress the production bake/import dependency in this state-only test.
	view._frames = _fixture_frames()
	view._attempted_frames = true
	root.add_child(view)
	view.configure(service, null)
	expect(view.y_sort_enabled and view.staff_nodes.size() == 3, "World view owns three janitor roots inside the Y-sorted traversal")
	expect(view.mess_nodes.size() == service.inspect().mess.size(), "Every live mess has one ground mark")
	var snapshot: Variant = _json(service.capture())
	for index in 100: view.refresh()
	expect(snapshot == _json(service.capture()), "Repeated refresh never advances routes, cleaning, RNG or payroll")
	for person: Dictionary in service.inspect().staff:
		var actor: Node2D = view.staff_nodes[person.id]
		expect(actor.position == IsometricGrid.project(person.position), "Staff root uses the canonical logical projection")
		var sprite: AnimatedSprite2D = actor.get_child(0)
		expect(sprite.offset == -Art.ROOT and sprite.scale == Vector2.ONE * Art.SCALE and not sprite.is_playing(), "Staff poses have a uniform scale and an externally owned pose clock")
	service.advance(1.0, 1.0)
	view.refresh()
	var walking := false
	for person: Dictionary in service.inspect().staff:
		var sprite: AnimatedSprite2D = view.staff_nodes[person.id].get_child(0)
		if person.moving:
			walking = true
			expect(sprite.animation.begins_with("walk_"), "Actual traveled motion selects the complete walking sheet")
	expect(walking, "A real claimed job is walking through the view")
	var cleaned := false
	for tick in 1200:
		service.advance(0.25, 1.0 + (tick + 1) * 0.25)
		view.refresh()
		for person: Dictionary in service.inspect().staff:
			if person.state == "cleaning":
				var sprite: AnimatedSprite2D = view.staff_nodes[person.id].get_child(0)
				expect(sprite.animation.begins_with("clean_"), "Reached cleaning work selects the coherent sweeping sheet")
				cleaned = true
		if cleaned: break
	expect(cleaned, "Real cleaning action reaches the presentation seam")
	snapshot = _json(service.capture())
	var pose_frames: Dictionary = {}
	for id: int in view.staff_nodes: pose_frames[id] = (view.staff_nodes[id].get_child(0) as AnimatedSprite2D).frame
	for index in 100: view.refresh()
	expect(snapshot == _json(service.capture()), "Refreshing a cleaning pose during pause preserves elapsed work and payroll")
	for id: int in pose_frames: expect(pose_frames[id] == (view.staff_nodes[id].get_child(0) as AnimatedSprite2D).frame, "Pause freezes each staff pose frame")
	var saved: Dictionary = service.capture()
	var resumed := Service.new()
	resumed.configure(map, null)
	expect(resumed.restore(_json(saved)), "Presentation fixture restores real in-progress jobs")
	view.configure(resumed, null)
	expect(view.staff_nodes.size() == 3 and view.mess_nodes.size() == resumed.inspect().mess.size(), "Reconfigure reuses stable identities without duplicating actors")
	resumed.dismiss(1)
	view.refresh()
	expect(not view.staff_nodes.has(1) and view.staff_nodes.size() == 2, "Dismissal removes the actual staff visual")
	resumed.advance(300.0, saved.clock + 300.0)
	view.refresh()
	expect(resumed.inspect().mess.is_empty() and view.mess_nodes.is_empty(), "Completed real cleanup removes every ground mark")
	expect(view.get_child_count() == 2, "View keeps only the two hired staff; no guest actors are spawned")
	view.free()
	print("CLEANLINESS_VIEW_CHECKS ", checks, " checks; ", failures.size(), " failures; frame fixtures only, no player saves or shared bakes")
	quit(0 if failures.is_empty() else 1)
