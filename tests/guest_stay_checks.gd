extends SceneTree

var failures: Array[String] = []
var checks := 0

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	_run.call_deferred()

func make_stay(layout: ResortLayout, assets: ResortAssets) -> GuestStay:
	var stay := GuestStay.new()
	stay.configure(layout, assets)
	return stay

func _run() -> void:
	var assets := ResortAssets.new()
	for facing in 2:
		var layout := ResortLayout.new()
		layout.seed_default()
		var cabins: Array[Dictionary] = []
		for record in layout.objects:
			if record.kind == "cabin": cabins.append(record)
		for index in range(1, cabins.size()): layout.remove_object(cabins[index].id)
		cabins[0].orientation = facing
		var stay := make_stay(layout, assets)
		var states: Dictionary = {}
		var resumed_states: Dictionary = {}
		for tick in 14000:
			stay.advance(0.05)
			states[stay.state] = true
			if stay.state in ["entering", "exiting", "eating", "relaxing", "overnight", "departing"] and not resumed_states.has(stay.state):
				resumed_states[stay.state] = true
				layout.guest_stay = stay.capture()
				var path := "res://artifacts/test-stay-%d.json" % facing
				expect(layout.save_layout(path) == OK, "Write mid-stay snapshot " + stay.state)
				var restored := ResortLayout.new()
				expect(restored.load_layout(path) == OK, "Load mid-stay snapshot " + stay.state)
				var resumed := make_stay(restored, assets)
				expect(resumed.restore(restored.guest_stay), "Restore reservation and route " + stay.state)
				var control := make_stay(layout, assets)
				control.restore(stay.capture())
				resumed.advance(60)
				control.advance(60)
				expect(resumed.state == control.state and resumed.budget == control.budget and resumed.logical_position.is_equal_approx(control.logical_position), "Resume reproduces the next minute " + stay.state)
			if stay.state == "departed": break
		expect(stay.state == "departed", "Guest completes stay, facing %d" % facing)
		for phase in ["to_cabin", "entering", "resting", "exiting", "eating", "relaxing", "overnight", "departing"]:
			expect(states.has(phase), "Stay includes " + phase)
		expect(stay.paid_nights == 2 and stay.accommodation_spent == 120, "Exactly two nightly charges")
		expect(stay.activity_spent == 40 and stay.budget == 80 and stay.revenue == 160, "Two meals and two visits conserve money")
		expect(stay.cabin_id == -1 and not stay.departure_reason.is_empty(), "Checkout releases cabin and explains departure")
		# Exact pixel partition catches omitted pixels and overlaps in both room views.
		var source := assets.image_for("cabin", facing)
		var parts: Array[Image] = []
		for layer in CabinInterior.layers(facing, assets): parts.append(layer.texture.get_image())
		var differences := 0
		for y in source.get_height():
			for x in source.get_width():
				var count := 0
				for part in parts:
					if part.get_pixel(x,y).a > 0:
						count += 1
						if part.get_pixel(x,y) != source.get_pixel(x,y): differences += 1
				if count != (1 if source.get_pixel(x,y).a > 0 else 0): differences += 1
		expect(differences == 0, "Cabin layers preserve every original pixel exactly once")
	var map := ResortLayout.new()
	map.seed_default()
	var small := make_stay(map, assets)
	var fast := make_stay(map, assets)
	for i in 24000: small.advance(1.0 / 60.0)
	for i in 1000: fast.advance(0.4)
	expect(small.state == fast.state and small.budget == fast.budget and small.logical_position.distance_to(fast.logical_position) < 0.2, "Normal and 4x steps agree")
	var invalid := fast.capture()
	invalid.budget = 999
	expect(not make_stay(map, assets).restore(invalid), "Inconsistent money is rejected")
	var no_rooms := ResortLayout.new()
	no_rooms.seed_default()
	for record in no_rooms.objects.duplicate():
		if record.kind in ["cabin", "cafe", "sunbeds"]: no_rooms.remove_object(record.id)
	var waiting := make_stay(no_rooms, assets)
	waiting.advance(5)
	expect(waiting.state == "waiting" and waiting.budget == 240, "No cabin gives an explained wait without charges")
	expect(no_rooms.place("cabin", Vector2(14,12)).ok, "Add a cabin while guest waits")
	waiting.advance(700)
	expect(waiting.state == "departed" and waiting.activity_spent == 0, "Missing facilities still allow a completed stay")
	var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
	resort.legacy_stay_fixture=true
	resort.save_path = "res://artifacts/test-complete-resort.json"
	root.add_child(resort)
	await process_frame
	resort.set_process(false)
	resort.stay.advance(0.1)
	var broken_route := resort.stay.capture()
	broken_route.route = []
	broken_route.route_index = 0
	expect(not make_stay(resort.layout, assets).restore(broken_route), "A travelling stay without its route is rejected")
	resort.selected_id = resort.stay.cabin_id
	var cabin := resort.layout.find_object(resort.selected_id).duplicate()
	for action in ["move", "rotate", "remove"]:
		resort._on_action(action)
		expect(resort.layout.find_object(cabin.id) == cabin and resort.mode == "select", "Reserved room rejects " + action)
	resort.mode = "move"
	resort.moving_id = cabin.id
	resort.build_kind = "cabin"
	resort._commit_preview()
	expect(resort.layout.find_object(cabin.id) == cabin and resort.mode == "select", "Reservation arriving during an open move cannot be bypassed at commit")
	resort._on_action("guest")
	await process_frame
	expect(resort.hud.inspector.visible and resort.hud.detail_title.text.contains("Maya"), "Guest button opens actual stay profile")
	expect(resort.hud.inspector.get_global_rect().end.y < resort.hud.tools["category_Stay"].get_global_rect().position.y, "Guest profile and actions stay above the building tray")
	var actor_texture := resort.stay_actor.sprite.sprite_frames.get_frame_texture(resort.stay_actor.sprite.animation, resort.stay_actor.sprite.frame)
	var actor_image := actor_texture.get_image()
	var picked := false
	for y in actor_image.get_height():
		if picked: break
		for x in actor_image.get_width():
			if actor_image.get_pixel(x,y).a > 0.98:
				var point := resort.stay_actor.sprite.to_global(resort.stay_actor.sprite.offset + Vector2(x+0.5,y+0.5))
				resort.select_at(point)
				picked = true
				break
	expect(picked and resort.inspecting_guest, "Clicking an opaque guest pixel selects the live stay")
	resort._on_action("guide")
	resort._on_action("guide")
	resort._process(0)
	expect(not resort.inspecting_guest and resort.hud.detail_title.text == "Your coastal resort", "Map guide is not overwritten by the guest inspector")
	var undo_before := resort._snapshot()
	for record in undo_before.objects:
		if record.id == cabin.id: record.orientation = (int(record.orientation) + 1) % 2
	resort.undo_stack.append(undo_before)
	var undo_count := resort.undo_stack.size()
	resort._on_action("undo")
	expect(resort.undo_stack.size() == undo_count and resort.redo_stack.is_empty(), "Blocked occupied-room undo preserves history")
	resort._on_action("guest")
	resort.paused = true
	var clock := resort.stay.clock
	resort._process(1)
	expect(resort.stay.clock == clock, "Pause freezes booking time")
	resort.stay.advance(10)
	resort.save_path = "res://artifacts/test-complete-resort.json"
	resort._on_action("save")
	var saved := ResortLayout.new()
	expect(saved.load_layout(resort.save_path) == OK and saved.guest_stay.state == resort.stay.state, "Save control captures layout and live stay together")
	var existing := saved.objects.duplicate(true)
	var corrupt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resort.save_path))
	corrupt.guest_stay.budget = 999
	var bad := FileAccess.open("res://artifacts/test-corrupt-stay.json", FileAccess.WRITE)
	bad.store_string(JSON.stringify(corrupt))
	bad.close()
	expect(saved.load_layout("res://artifacts/test-corrupt-stay.json") != OK and saved.objects == existing, "Corrupt stay cannot replace an open layout")
	print("GUEST_STAY_CHECKS ", checks, " checks; ", failures.size(), " failures")
	resort.free()
	quit(0 if failures.is_empty() else 1)
