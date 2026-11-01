extends SceneTree
## Worker-4 focused behavior. Pure services only: no scene startup or save I/O.
const Service = preload("res://scripts/simulation/cleanliness_system.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _map() -> ResortLayout:
	var map := ResortLayout.new()
	map.seed_default()
	return map

func _service(map: ResortLayout) -> RefCounted:
	var service := Service.new()
	service.configure(map, null)
	return service

func _json(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data))

func _same(a: Variant, b: Variant) -> bool:
	return _json(a) == _json(b)

func _visits(service: RefCounted, map: ResortLayout, count: int = 60, clock: float = 0.0) -> void:
	var person := 1
	for record in map.objects:
		var activity: String = {"cafe": "meal", "sunbeds": "sunbathe", "volleyball": "volleyball"}.get(record.kind, "")
		if activity.is_empty(): continue
		for index in count:
			service.on_activity_finished(person, record.id, activity, clock)
			person += 1

func _generation() -> void:
	var map := _map()
	var service := _service(map)
	service.advance(60.0, 60.0)
	expect(service.inspect().mess.is_empty(), "Idle time never generates mess")
	var stable: Dictionary = service.capture()
	for args in [[0, 6, "meal", 60.0], [1, -1, "meal", 60.0], [1, 1, "meal", 60.0], [1, 6, "rest", 60.0]]:
		service.on_activity_finished(args[0], args[1], args[2], args[3])
	expect(_same(stable, service.capture()), "Invalid or mismatched visit cannot alter dirt/RNG")
	_visits(service, map, 100, 60.0)
	var view: Dictionary = service.inspect()
	expect(view.mess.size() > 8 and view.mess.size() <= Service.MAX_MESS, "Many real visits produce bounded dirt at several facilities")
	var graph := map.navigation()
	var ids: Dictionary = {}
	var sources: Dictionary = {}
	for dirt: Dictionary in view.mess:
		expect(not ids.has(dirt.id), "Mess has stable unique identity")
		ids[dirt.id] = true
		sources[dirt.facility_id] = sources.get(dirt.facility_id, 0) + 1
		var cell := Vector2i(dirt.position.round())
		expect(not graph.is_point_solid(cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(), "Every spawned mess is reachable open ground")
		expect(service.score_at(dirt.position) < 100.0, "Dirt lowers local cleanliness")
	for count: int in sources.values(): expect(count <= Service.MAX_MESS_PER_FACILITY, "One facility cannot monopolize the mess bound")
	expect(service.score_at(Vector2(4, 20)) == 100.0, "A distant clean area keeps its local score")
	var before: Dictionary = service.capture()
	service.on_activity_finished(99999, 6, "meal", 60.0)
	var once: Dictionary = service.capture()
	service.on_activity_finished(99999, 6, "meal", 60.0)
	expect(_same(once, service.capture()), "Duplicate completion callback is harmless")
	expect(before.mess.size() == service.capture().mess.size(), "Global cap prevents unbounded generation")
	var a := _service(map)
	var b := _service(map)
	_visits(a, map, 3)
	expect(b.restore(_json(a.capture())), "Seeded dirt snapshot restores")
	for service_copy: RefCounted in [a, b]: _visits(service_copy, map, 9)
	expect(_same(a.capture(), b.capture()), "RNG and completion receipts resume the exact future dirt stream")

func _jobs_and_resume() -> void:
	var map := _map()
	var service := _service(map)
	_visits(service, map)
	var original: int = service.inspect().mess.size()
	var first: Dictionary = service.hire()
	expect(first.ok and first.id == 1 and service.drain_events().is_empty(), "Hire has no upfront fee")
	for index in 2: expect(service.hire().ok, "Can hire the remaining janitor positions")
	expect(not service.hire().ok and service.inspect().hired_count == 3, "Fourth janitor is refused")
	var positions: Dictionary = {}
	for person: Dictionary in service.inspect().staff:
		expect(not positions.has(person.position), "New hires stand on distinct arrival cells")
		positions[person.position] = true
	service.advance(1.0, 1.0)
	var saved: Dictionary = _json(service.capture())
	var resumed := _service(map)
	expect(resumed.restore(saved), "Mid-walk staff/routes/exclusive claims restore transactionally")
	expect(_same(saved, resumed.capture()), "Mid-walk snapshot preserves distance, phase and elapsed route delay")
	var walking := false
	var cleaning := false
	var cleaned_snapshot: Dictionary = {}
	var graph := map.navigation()
	for index in 1600:
		var clock := 1.0 + (index + 1) * 0.25
		service.advance(0.25, clock)
		resumed.advance(0.25, clock)
		if index % 80 == 0: expect(_same(service.capture(), resumed.capture()), "Uninterrupted and resumed cleanup/wages agree")
		var claimed: Dictionary = {}
		var dirt_by_id: Dictionary = {}
		for dirt: Dictionary in service.inspect().mess: dirt_by_id[dirt.id] = dirt
		for person: Dictionary in service.inspect().staff:
			if person.target_mess_id > 0:
				expect(not claimed.has(person.target_mess_id), "A mess has only one live janitor claimant")
				claimed[person.target_mess_id] = person.id
			var cell := Vector2i(person.position.round())
			expect(not graph.is_point_solid(cell), "Staff walk only on navigable ground")
			walking = walking or person.state == "walking"
			if person.state == "cleaning":
				cleaning = true
				expect(dirt_by_id.has(person.target_mess_id) and person.position.distance_to(dirt_by_id[person.target_mess_id].position) <= 0.50001, "Staff clean only a physically reached claimed job")
				if cleaned_snapshot.is_empty() and person.activity_elapsed > 0.5:
					cleaned_snapshot = _json(service.capture())
		if service.inspect().mess.is_empty(): break
	expect(walking and cleaning and service.inspect().mess.is_empty(), "Actual walk-clean loops clear all %d bounded jobs" % original)
	expect(not cleaned_snapshot.is_empty(), "Observed a partially completed real cleaning action")
	if not cleaned_snapshot.is_empty():
		var a := _service(map)
		var b := _service(map)
		expect(a.restore(cleaned_snapshot) and b.restore(_json(a.capture())), "Mid-cleaning elapsed progress and claims survive JSON")
		for index in 200:
			var clock: float = cleaned_snapshot.clock + (index + 1) * 0.1
			a.advance(0.1, clock)
			b.advance(0.1, clock)
		expect(_same(a.capture(), b.capture()), "Resumed cleaning completes once with unchanged future routing")
	var dismissed := _service(map)
	_visits(dismissed, map)
	dismissed.hire()
	dismissed.advance(0.1, 0.1)
	var target: int = dismissed.inspect().staff[0].target_mess_id
	expect(target > 0 and dismissed.dismiss(1), "Dismissal works during a claimed route")
	for dirt: Dictionary in dismissed.inspect().mess: expect(dirt.claimed_by == 0, "Dismissal releases every live claim")
	expect(dismissed.inspect().staff.is_empty() and not dismissed.dismiss(1), "Dismissed staff is absent and repeated dismissal is harmless")
	dismissed.hire()
	dismissed.advance(0.1, 0.2)
	expect(dismissed.inspect().staff[0].id == 2 and dismissed.inspect().staff[0].target_mess_id > 0, "Replacement uses a fresh identity and claims released work")

func _wages_and_time() -> void:
	var map := _map()
	var a := _service(map)
	a.hire()
	a.advance(179.75, 179.75)
	expect(a.drain_events().is_empty(), "No wage before global day completion")
	var b := _service(map)
	expect(b.restore(_json(a.capture())), "Boundary wage snapshot restores")
	a.advance(0.25, 180.0)
	b.advance(0.25, 180.0)
	var events: Array = a.drain_events()
	expect(_same(events, b.drain_events()) and events.size() == 1, "Resume emits the identical wage once")
	expect(events[0] == {"id": "staff:wage:1:1", "kind": "wage", "amount": -30, "time": 180.0, "staff_id": 1}, "Daily wage has exact signed amount, stable identity and boundary time")
	var frozen: Dictionary = a.capture()
	a.advance(0.0, 180.0)
	a.advance(-1, 179.0)
	a.advance(NAN, NAN)
	expect(_same(frozen, a.capture()) and a.drain_events().is_empty(), "Pause/invalid delta cannot advance staff or reissue wages")
	a.hire()
	a.advance(360.0, 540.0)
	var later: Array = a.drain_events()
	expect(later.size() == 4, "Two hires over two completed days produce four wages")
	var ids: Dictionary = {}
	for event: Dictionary in events + later:
		expect(not ids.has(event.id) and event.amount == -30, "Every completed staff-day has one unique wage id")
		ids[event.id] = true
	a.dismiss(1)
	a.advance(180.0, 720.0)
	expect(a.drain_events().size() == 1, "Dismissed staff cannot accrue another daily wage")
	expect(a.total_wages == 180 and a.inspect().total_wages == 180 and a.capture().total_wages == 180, "Lifetime payroll retains all six wages including dismissed staff")
	var payroll_resume := _service(map)
	expect(payroll_resume.restore(_json(a.capture())) and payroll_resume.total_wages == 180, "Lifetime payroll survives JSON resume after dismissal")
	var c := _service(map)
	c.advance(179.0, 179.0)
	c.hire()
	c.advance(1.0, 180.0)
	expect(c.drain_events().size() == 1, "Late-day hire pays once on the shared global boundary")
	c.hire()
	expect(c.drain_events().is_empty(), "A hire on the boundary has no retroactive fee")
	var precise := _service(map)
	precise.hire()
	precise.advance(179.9999999, 179.9999999)
	expect(precise.drain_events().is_empty(), "Wages never round an unfinished global day up to completion")
	precise.advance(0.0000001, 180.0)
	expect(precise.drain_events().size() == 1, "The exact boundary completes the wage after a fractional near-boundary step")
	var one := _service(map)
	_visits(one, map, 12)
	one.hire()
	var many := _service(map)
	expect(many.restore(_json(one.capture())), "Speed-equivalence fixture restores")
	one.advance(90.0, 90.0)
	for index in 900: many.advance(0.1, (index + 1) * 0.1)
	expect(_same(one.capture(), many.capture()), "Equivalent elapsed time preserves jobs, movement, pose distance and cleaning progress")
	var pending := _service(map)
	pending.hire()
	pending.advance(180.0, 180.0)
	var pending_resume := _service(map)
	expect(pending_resume.restore(_json(pending.capture())), "Undelivered wage event survives snapshot")
	expect(_same(pending.drain_events(), pending_resume.drain_events()), "Pending wage drains once on either side of resume")

func _editing_and_validation() -> void:
	var map := _map()
	var service := _service(map)
	_visits(service, map, 10)
	service.hire()
	service.advance(1.0, 1.0)
	var stable: Dictionary = _json(service.capture())
	var candidate := _map()
	candidate.paths.clear()
	expect(not service.access_survives(candidate), "Removing all paths cannot strand staff or jobs")
	candidate = _map()
	var point: Vector2 = service.inspect().staff[0].position
	candidate.paths.erase(Vector2i(point.floor()))
	candidate.paths.erase(Vector2i(point.ceil()))
	expect(not service.access_survives(candidate), "Deleting either end of an occupied path segment is refused")
	candidate = _map()
	candidate.paths[Vector2i(1, 19)] = true
	expect(service.access_survives(candidate), "An unrelated safe path extension remains editable")
	map.paths[Vector2i(1, 19)] = true
	map.revision += 1
	service.layout_changed()
	expect(_same(stable, service.capture()), "Unrelated layout refresh preserves motion distance, route and job progress")
	for mutation in ["fractional_id", "bool_id", "orphan_claim", "unknown_target", "bad_route", "bad_elapsed", "bad_rng", "fractional_day", "future_dirt", "staff_teleport"]:
		var bad: Dictionary = stable.duplicate(true)
		match mutation:
			"fractional_id": bad.staff[0].id = 1.5
			"bool_id": bad.mess[0].id = true
			"orphan_claim": bad.mess[0].claimed_by = 999999
			"unknown_target": bad.staff[0].target_mess_id = 999999
			"bad_route": bad.staff[0].motion.route[bad.staff[0].motion.index] = [0, 0]
			"bad_elapsed": bad.staff[0].activity_elapsed = -0.5
			"bad_rng": bad.rng_state = "9223372036854775808123"
			"fractional_day": bad.wage_day = 0.5
			"future_dirt": bad.mess[0].created_at = 10000
			"staff_teleport": bad.staff[0].motion.position = [1, 1]
		expect(not service.restore(bad) and _same(stable, service.capture()), "Reject %s without replacing live staff/jobs/RNG" % mutation)
	var pending := _service(map)
	pending.hire()
	pending.advance(180.0, 180.0)
	var wage_data: Dictionary = _json(pending.capture())
	var duplicate: Dictionary = wage_data.duplicate(true)
	duplicate.pending_events.append(duplicate.pending_events[0].duplicate())
	expect(not pending.restore(duplicate) and _same(wage_data, pending.capture()), "Duplicate pending wage cannot replace the open service")
	var malformed: Dictionary = wage_data.duplicate(true)
	malformed.pending_events[0].amount = -30.5
	expect(not pending.restore(malformed), "Fractional wage amount is rejected")
	var underreported: Dictionary = wage_data.duplicate(true)
	underreported.pending_events.clear()
	underreported.total_wages = 0
	expect(not pending.restore(underreported), "Lifetime payroll cannot underreport the completed wages of retained staff")
	var fractional_boundary: Dictionary = wage_data.duplicate(true)
	fractional_boundary.pending_events[0].time = 179.9999999
	expect(not pending.restore(fractional_boundary), "Pending wage must carry the exact completed global boundary")
	var edit_map := _map()
	var reroute := _service(edit_map)
	for record in edit_map.objects:
		if record.kind == "cafe":
			for index in 40: reroute.on_activity_finished(index + 1, record.id, "meal", 0.0)
	reroute.hire()
	var far_start: Dictionary = _json(reroute.capture())
	far_start.staff[0].motion.position = [6, 19]
	far_start.staff[0].stand_position = [6, 19]
	expect(reroute.restore(far_start), "Restore a janitor at a distant connected path for the detour fixture")
	reroute.advance(1.0, 1.0)
	var cleaner: Dictionary = reroute.staff[0]
	var motion: GuestMotion = cleaner.motion
	var start_position := motion.position
	var start_distance := motion.distance
	var target: int = cleaner.target_mess_id
	var detour: ResortLayout
	var removed := Vector2i(-1, -1)
	for index in range(motion.index + 2, motion.route.size() - 2):
		var cell := Vector2i(motion.route[index])
		if not edit_map.is_path(cell): continue
		detour = _map()
		detour.paths.erase(cell)
		if reroute.access_survives(detour):
			removed = cell
			break
	expect(removed.x >= 0, "Found an alternate safe route around a future path edit")
	if removed.x >= 0:
		edit_map.paths.erase(removed)
		edit_map.revision += 1
		reroute.layout_changed()
		expect(motion.position == start_position and motion.distance == start_distance and cleaner.target_mess_id == target, "Safe detour preserves current root, distance phase and exclusive claim")
		for point_on_route in motion.route: expect(Vector2i(point_on_route) != removed, "Replanned janitor route avoids the removed path")
		var after_edit := _service(edit_map)
		expect(after_edit.restore(_json(reroute.capture())), "A safely replanned route can be saved and resumed")

func _run() -> void:
	_generation()
	_jobs_and_resume()
	_wages_and_time()
	_editing_and_validation()
	print("CLEANLINESS_CHECKS ", checks, " checks; ", failures.size(), " failures; no player save opened or written")
	quit(0 if failures.is_empty() else 1)
