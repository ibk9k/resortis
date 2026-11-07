extends SceneTree
## Visit each starter facility through the real navigation, admission, and ledger.
var failures: Array[String] = []
var checks := 0
var resort: CoastalResort

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var map := ResortLayout.new()
	expect(map.load_layout("res://data/coastal_map.json") == OK, "Expanded starter layout loads")
	if not failures.is_empty():
		quit(1)
		return
	expect(map.contains(Vector2i(0, -22)) and not map.contains(Vector2i(0, -23)), "Exactly 22 new inland rows")
	var assets := ResortAssets.new()
	var capture := "--capture-expansion" in OS.get_cmdline_user_args()
	if capture:
		resort = (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
		root.add_child(resort)
		resort.set_process(false)
		resort.hud.hide()
		await _capture("overview", Vector2(22, -5), 0.55)
	for kind: String in ResortServices.EXPANSION:
		var record := _find(map, kind)
		expect(not record.is_empty(), "Starter facility exists: " + kind)
		if record.is_empty(): continue
		expect(assets.texture_for(kind) != null and ResourceLoader.exists("res://scenes/assets/%s.tscn" % kind), "Registered runtime and reusable art: " + kind)
		var runtime := LivingResortRuntime.new()
		if not runtime.configure(map, assets):
			expect(false, "Configure runtime")
			break
		var sim := runtime.simulation as ResortSimulation
		sim.arrivals_enabled = false
		for tick in 200:
			if sim.parties[0].state == "active": break
			runtime.advance(0.2)
		expect(sim.parties[0].state == "active", "First party has real paid lodging")
		if sim.parties[0].state != "active": break
		var first := sim.people[0]
		var second := sim.people[1]
		# Put the booked couple on the public promenade before the controlled
		# choice. The full outdoor and furniture approach is simulated from here.
		for guest in [first, second]:
			sim._decision_state(guest)
			guest.timer = 120.0
			guest.motion.position = Vector2(22, 4)
			guest.motion.route.clear()
			guest.motion.index = 0
		expect(sim._visit(first, record, kind), "Guest can reserve " + kind)
		if kind == "pickleball":
			expect(not first.session_paid, "A lone court reservation has no charge")
		expect(sim._visit(second, record, kind), "Second place is usable at " + kind)
		for tick in 380:
			if first.session_paid and second.session_paid: break
			runtime.advance(0.2)
		expect(first.session_paid and second.session_paid, "Both guests reach and pay at " + kind)
		if not first.session_paid or not second.session_paid: continue
		expect(first.motion.position.distance_to(sim.activity_slot(first.id).position) < 0.06, "Female guest reaches registered fixture at " + kind)
		expect(second.motion.position.distance_to(sim.activity_slot(second.id).position) < 0.06, "Male guest reaches registered fixture at " + kind)
		expect(sim.total_activity_income == 2 * map.price(kind), "One admission per guest at " + kind)
		expect(runtime.ledger.inspect(sim.clock).facility_income == 2 * map.price(kind), "New revenue appears in the operating statement for " + kind)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(runtime.capture()))
		var resumed := LivingResortRuntime.new()
		expect(resumed.configure(map, assets) and resumed.restore(saved), "Active " + kind + " restores with its exact fixtures and payments")
		if capture:
			resort.population_view.configure(runtime, assets)
			resort.population_view.refresh()
			var center: Vector2 = record.position + Vector2(ResortCatalog.footprint(kind) - Vector2i.ONE) / 2.0
			await _capture(kind, center, 1.28 if kind == "restaurant" else 1.54)
		for tick in 200:
			if first.facility_id != record.id and second.facility_id != record.id: break
			runtime.advance(0.2)
		expect(first.facility_id != record.id and second.facility_id != record.id, "Both guests leave and release " + kind)
	_capacity_checks(map, assets)
	print("EXPANSION_FACILITY_CHECKS %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _capacity_checks(map: ResortLayout, assets: ResortAssets) -> void:
	for kind: String in ResortServices.CAPACITIES:
		var record := _find(map, kind)
		var sessions := FacilitySessions.new()
		sessions.configure(map, assets)
		var fixtures := {}
		for index in ResortServices.capacity(kind):
			var id := index + 1
			var ticket := sessions.request(id, id, record.id, kind, 0.0)
			expect(ticket.get("slot", -1) == index, "Reserve each of the " + kind + " places in order")
			var slot := sessions.slot(id)
			if slot.is_empty(): continue
			expect(not fixtures.has(slot.position), "Each " + kind + " place has a distinct fixture")
			fixtures[slot.position] = true
			expect(sessions.confirm_arrival(id, 0.0), "Each " + kind + " fixture admits a guest")
		var resumed := FacilitySessions.new()
		resumed.configure(map, assets)
		expect(resumed.restore(sessions.capture()), "Full occupancy survives restore for " + kind)

func _find(map: ResortLayout, kind: String) -> Dictionary:
	for record in map.objects:
		if record.kind == kind: return record
	return {}

func _capture(label: String, center: Vector2, zoom: float) -> void:
	resort.camera.position = IsometricGrid.project(center) - Vector2(0, 32)
	resort.camera.zoom = Vector2.ONE * zoom
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/expansion-%s.png" % label
	expect(root.get_texture().get_image().save_png(path) == OK, "Saved capture " + label)
