extends SceneTree
## Independent acceptance checks. Never bind a player save or manufacture passes
## for modules which have not been delivered. See docs/plans/living-resort-qa.md.

const MODULES := {
	"simulation": "res://scripts/simulation/resort_simulation.gd",
	"profiles": "res://scripts/simulation/guest_profiles.gd",
	"brain": "res://scripts/simulation/guest_brain.gd",
	"facilities": "res://scripts/simulation/facility_sessions.gd",
	"cleanliness": "res://scripts/simulation/cleanliness_system.gd",
	"ledger": "res://scripts/simulation/operating_ledger.gd",
	"runtime": "res://scripts/simulation/living_resort_runtime.gd"
}
const REPORT := "res://artifacts/living-resort-checks.json"
const PROTECTED := ["res://artifacts/coastal-layout.json", "res://artifacts/coastal-layout.json.bak", "user://coastal-layout.json", "user://coastal-layout.json.bak"]
const PERSON_FIELDS := ["id", "party_id", "role", "profile", "motion", "state", "needs", "mood", "warning_elapsed", "want_leave", "reason", "history", "activity", "facility_id", "slot", "activity_elapsed", "timer", "session_paid"]
const PARTY_FIELDS := ["id", "member_ids", "nights", "initial_budget", "budget", "cabin_id", "paid_nights", "room_spent", "activity_spent", "created_at", "next_night", "state", "history"]
var cases: Array[Dictionary] = []
var current: Dictionary = {}
var modules: Dictionary = {}
var protected_before: Dictionary = {}
var assets: ResortAssets
var checks := 0
var only := ""
var allow_pending := false
var prepare_only := false
var run_tag := ""
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _case(id: String, description: String) -> void:
	current = {"id": id, "description": description, "status": "passed", "checks": 0, "failures": [], "pending": []}
	cases.append(current)

func expect(condition: bool, label: String) -> void:
	checks += 1
	current.checks += 1
	if not condition:
		current.status = "failed"
		if not label in current.failures:
			current.failures.append(label)
			push_error(current.id + ": " + label)

func pending(reason: String) -> void:
	if current.status != "failed": current.status = "pending"
	if not reason in current.pending: current.pending.append(reason)

func _selected(section: String) -> bool:
	return only.is_empty() or only == section

func _module(key: String) -> Variant:
	if modules.has(key): return modules[key]
	var path: String = MODULES[key]
	if not FileAccess.file_exists(path):
		pending("Implementation pending: " + path)
		return null
	var script = load(path)
	if script == null or not script.can_instantiate():
		expect(false, "Existing module could not load: " + path + "; coordinator must resolve parse/class-registration dependencies")
		return null
	modules[key] = script
	return script

func _methods(value: Object, names: Array) -> bool:
	var valid := true
	for method in names:
		if not value.has_method(method):
			expect(false, "Required public method missing: " + str(method))
			valid = false
	return valid

func _hashes() -> Dictionary:
	var result := {}
	for path in PROTECTED:
		result[path] = {"exists": FileAccess.file_exists(path), "sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return result

func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _equal(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		if a == int(a) and b == int(b): return int(a) == int(b)
		return absf(float(a) - float(b)) < 0.0001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equal(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _equal(a[index], b[index]): return false
		return true
	return a == b

func _has_property(value: Object, key: String) -> bool:
	for info in value.get_property_list():
		if info.name == key: return true
	return false

func _find_simulation(resort: Node) -> Variant:
	if _has_property(resort, "living"):
		var runtime = resort.get("living")
		if runtime != null: return runtime.simulation
	# Scene property names are coordinator-owned; discover the actual public seam.
	for info in resort.get_property_list():
		if info.type != TYPE_OBJECT: continue
		var value = resort.get(info.name)
		if value != null and value.has_method("person") and value.has_method("party") and value.has_method("drain_events") and value.has_method("import_legacy"):
			return value
	return null

func _world_capture(resort: Node, sim: Variant) -> Dictionary:
	if _has_property(resort, "living") and resort.get("living") != null:
		return resort.get("living").capture()
	return {"simulation": sim.capture()}

func _map() -> ResortLayout:
	var result := ResortLayout.new()
	result.seed_default()
	return result

func _crowd_map() -> ResortLayout:
	# Six real, validated cabins, both facings, and ordinary facilities. No actors
	# or bookings are fabricated. This fixture is NOT written over the starter.
	var result := ResortLayout.new()
	for x in range(44):
		result.paths[Vector2i(x, 9)] = true
		result.paths[Vector2i(x, 19)] = true
	for y in range(9, 21): result.paths[Vector2i(42, y)] = true
	for index in 6:
		var origin := Vector2(1 + index * 7, 3)
		var facing := index % 2
		var door := Vector2i(origin) + ResortCatalog.entrance("cabin", facing)
		for y in range(door.y, 10): result.paths[Vector2i(door.x, y)] = true
		expect(result.place("cabin", origin, facing).get("ok", false), "Crowd fixture cabin validates " + str(index))
	for y in range(16, 20): result.paths[Vector2i(34, y)] = true
	for entry in [["cafe", Vector2(32, 12)], ["sunbeds", Vector2(7, 23)], ["sunbeds", Vector2(12, 23)], ["volleyball", Vector2(28, 26)]]:
		expect(result.place(entry[0], entry[1]).get("ok", false), "Crowd fixture facility validates " + entry[0])
	return result

func _simulation(map: ResortLayout, attach_services: bool = false) -> Variant:
	var script = _module("simulation")
	if script == null: return null
	var value = script.new()
	if not _methods(value, ["configure", "advance", "person", "party", "inspect", "activity_slot", "protects", "access_survives", "layout_changed", "capture", "restore", "import_legacy", "drain_events"]): return null
	value.configure(map, assets, 8147)
	if attach_services:
		for key in ["facilities", "cleanliness", "ledger"]:
			var service_script = _module(key)
			if service_script == null: return null
			var service = service_script.new()
			if key != "ledger": service.configure(map, assets)
			value.set(key, service)
	return value

func _profiles() -> void:
	_case("PROFILE-01", "Deterministic generated solo/couple profiles cover 1–3 nights, budgets and interests")
	var script = _module("profiles")
	if script == null: return
	if not _methods(script, ["create_party"]): return
	var left := RandomNumberGenerator.new()
	var right := RandomNumberGenerator.new()
	left.seed = 8147
	right.seed = 8147
	var nights := {}
	var sizes := {}
	var budgets := {}
	for index in 120:
		var a = script.call("create_party", left, index + 1, 0)
		var b = script.call("create_party", right, index + 1, 0)
		expect(a is Dictionary and _equal(a, b), "Same caller RNG produces identical party " + str(index))
		if not a is Dictionary: return
		expect(a.get("nights", 0) in [1, 2, 3] and a.nights == int(a.nights), "Stay length is integral 1–3")
		expect(a.get("members") is Array and a.members.size() in [1, 2], "Party contains one or two profiles")
		if not a.get("members") is Array: return
		expect(a.get("budget", 0) >= int(a.get("nights", 0)) * 60, "Generated budget covers shared unpaid room reserve")
		nights[a.get("nights", 0)] = true
		sizes[a.members.size()] = true
		budgets[a.get("budget", 0)] = true
		for profile in a.members:
			expect(profile.get("name", "") is String and not profile.get("name", "").is_empty(), "Profile has a name")
			expect(profile.get("variant", "") in ["female", "male"], "Profile uses an approved appearance")
			var interests = profile.get("interests", [])
			expect(interests is Array and interests.size() in [2, 3], "Profile exposes 2–3 interests")
			var unique := {}
			for interest in interests: unique[interest] = true
			expect(unique.size() == interests.size(), "Interests are distinct")
			for key in ["hunger", "rest", "enjoyment"]:
				expect(profile.get("initial_needs", {}).has(key), "Profile initializes " + key)
	for length in [1, 2, 3]: expect(nights.has(length), "Seed sample includes " + str(length) + " night stays")
	expect(sizes.size() == 2 and budgets.size() >= 3, "Arrival sample varies party size and budget")
	for size in [1, 2]:
		var forced = script.call("create_party", left, 500 + size, size)
		expect(forced.get("members", []).size() == size, "Explicit party size is honored")

func _person_fixture() -> Dictionary:
	return {"id": 1, "party_id": 1, "role": 0, "profile": {"name": "QA guest", "variant": "female", "interests": ["food", "beach"], "initial_needs": {"hunger": 90.0, "rest": 90.0, "enjoyment": 90.0}}, "motion": GuestMotion.new(), "state": "deciding", "needs": {"hunger": 90.0, "rest": 90.0, "enjoyment": 90.0}, "mood": 80.0, "warning_elapsed": 0.0, "want_leave": false, "reason": "", "history": [], "activity": "", "facility_id": -1, "slot": -1, "activity_elapsed": 0.0, "timer": 0.0, "session_paid": false}

func _brain() -> void:
	_case("BRAIN-01", "Actual need urgency changes choices and ordinary activity spending protects room money")
	var script = _module("brain")
	if script == null: return
	if not _methods(script, ["choose", "advance"]): return
	var party := {"id": 1, "member_ids": [1], "nights": 3, "initial_budget": 240, "budget": 240, "cabin_id": 1, "paid_nights": 1, "room_spent": 60, "activity_spent": 0}
	var available: Array[Dictionary] = [{"kind": "cafe", "id": 10, "price": 12, "distance": 5.0, "available": true, "queue": 0}, {"kind": "sunbeds", "id": 11, "price": 8, "distance": 5.0, "available": true, "queue": 0}, {"kind": "volleyball", "id": 12, "price": 10, "distance": 5.0, "available": true, "queue": 0}]
	var hungry := _person_fixture()
	hungry.needs.hunger = 1.0
	var tired := _person_fixture()
	tired.needs.rest = 1.0
	var meal = script.call("choose", hungry, party, available, 20.0)
	var rest = script.call("choose", tired, party, available, 20.0)
	expect(meal.get("activity", "") == "meal" and meal.get("facility_id", -1) == 10, "Urgent hunger chooses the available café")
	expect(rest.get("activity", "") == "rest" and rest.get("facility_id", 0) == -1, "Urgent rest chooses the shared cabin")
	party.budget = 120
	party.initial_budget = 180
	var reserved = script.call("choose", hungry, party, available, 20.0)
	expect(reserved.get("facility_id", -1) == -1, "Unpaid two-night reserve cannot buy a meal")
	for entry in available: entry.available = false
	var fallback = script.call("choose", hungry, party, available, 20.0)
	expect(fallback.get("activity", "") in ["stroll", "rest"] and fallback.get("facility_id", 0) == -1 and not fallback.get("reason", "").is_empty(), "Unavailable services produce an explained free alternative")
	var eating := _person_fixture()
	eating.state = "eating"
	eating.needs.hunger = 25.0
	var walking := _person_fixture()
	walking.state = "to_facility"
	walking.activity = "meal"
	walking.needs.hunger = 25.0
	script.call("advance", eating, 5.0, 100.0)
	script.call("advance", walking, 5.0, 100.0)
	expect(eating.needs.hunger > 25 and walking.needs.hunger <= 25, "Food recovery follows actual eating, never a walking intention")
	var sleeping := _person_fixture()
	sleeping.state = "sleeping"
	sleeping.needs.rest = 25.0
	script.call("advance", sleeping, 5.0, 100.0)
	expect(sleeping.needs.rest > 25, "Actual sleeping recovers rest")
	_case("MOOD-01", "Local dirt lowers mood, severe dissatisfaction warns before departure, cleaning allows recovery")
	var dirty := _person_fixture()
	var clean := _person_fixture()
	var warned := false
	var warning_before_departure := false
	var recoverable: Dictionary = {}
	var first_warning_at := 0.0
	for index in 3600:
		for p in [dirty, clean]: p.needs = {"hunger": 90.0, "rest": 90.0, "enjoyment": 90.0}
		script.call("advance", dirty, 0.25, 0.0)
		script.call("advance", clean, 0.25, 100.0)
		if dirty.warning_elapsed > 0 and not dirty.want_leave:
			warned = true
			if recoverable.is_empty():
				recoverable = dirty.duplicate(true)
				first_warning_at = (index + 1) * 0.25
		if dirty.want_leave:
			warning_before_departure = warned
			break
	expect(dirty.mood < clean.mood, "Dirt mood effect is independent of healthy needs")
	expect(warning_before_departure and dirty.want_leave and not dirty.reason.is_empty(), "Sustained dirt gives a visible grace period before explained early departure")
	if recoverable.is_empty(): return
	var low_mood: float = recoverable.mood
	var warning_at_recovery: float = recoverable.warning_elapsed
	for index in 3600:
		recoverable.needs = {"hunger": 90.0, "rest": 90.0, "enjoyment": 90.0}
		script.call("advance", recoverable, 0.25, 100.0)
	expect(not recoverable.want_leave and recoverable.warning_elapsed == 0 and recoverable.mood > low_mood, "Cleaning during grace cancels warning and recovers mood")
	observations.dirt_warning_recovery = {"healthy_needs_held_at": 90, "dirty_score": 0, "clean_score": 100, "first_warning_after_seconds": first_warning_at, "dirty_mood": dirty.mood, "clean_control_mood": clean.mood, "dirty_warning_elapsed": dirty.warning_elapsed, "dirty_wants_leave": dirty.want_leave, "warning_before_clean_recovery": warning_at_recovery, "recovered_mood": recoverable.mood, "recovered_warning_elapsed": recoverable.warning_elapsed, "recovered_wants_leave": recoverable.want_leave}

func _invariants(sim: Variant, violations: Dictionary) -> int:
	var people_by_id := {}
	var owners := {}
	var live := 0
	for p in sim.people:
		for key in PERSON_FIELDS:
			if not p.has(key): violations["Missing person field " + key] = true
		if people_by_id.has(p.get("id")): violations["Duplicate person identity"] = true
		people_by_id[p.get("id")] = p
		if p.get("state", "") != "departed": live += 1
		if not p.get("motion") is GuestMotion: violations["Person lacks its single GuestMotion"] = true
		if p.get("state", "") == "queueing" and p.get("session_paid", false): violations["Queued person already charged for admission"] = true
	for party in sim.parties:
		for key in PARTY_FIELDS:
			if not party.has(key): violations["Missing party field " + key] = true
		var id: int = party.get("id", 0)
		var cabin: int = party.get("cabin_id", -1)
		if cabin > 0:
			if owners.has(cabin): violations["Two active parties reserve one cabin"] = true
			owners[cabin] = id
			if not sim.protects(cabin): violations["Active booking is not protected from editing"] = true
		var initial: int = party.get("initial_budget", 0)
		var budget: int = party.get("budget", 0)
		var room: int = party.get("room_spent", 0)
		var activity: int = party.get("activity_spent", 0)
		var paid: int = party.get("paid_nights", 0)
		if initial != budget + room + activity or mini(budget, mini(room, activity)) < 0: violations["Party money does not conserve initial budget"] = true
		if room != paid * 60: violations["Nightly fee is duplicated or not shared"] = true
		if paid < 0 or paid > int(party.get("nights", 0)): violations["Paid nights outside planned stay"] = true
		if cabin > 0 and budget < maxi(0, int(party.get("nights", 0)) - paid) * 60: violations["Ordinary guest spent the unpaid accommodation reserve"] = true
		var roles := {}
		for member_id in party.get("member_ids", []):
			if not people_by_id.has(member_id):
				violations["Party references an absent person"] = true
				continue
			var p: Dictionary = people_by_id[member_id]
			if p.get("party_id") != id: violations["Person belongs to a different party"] = true
			if roles.has(p.get("role")): violations["Partners share one physical bed role"] = true
			roles[p.get("role")] = true
	if live > 12: violations["Live population exceeds proof cap 12"] = true
	return live

func _population() -> void:
	_case("POP-01", "Concurrent real bookings, replenishing varied 1–3-night stays, money and room uniqueness")
	var map := _crowd_map()
	var sim = _simulation(map)
	if sim == null: return
	var violations := {}
	var max_people := 0
	var max_bookings := 0
	var completed := {}
	var ids := {}
	var first_seen := false
	for index in 4800:
		sim.advance(0.25)
		max_people = maxi(max_people, _invariants(sim, violations))
		var booked := 0
		for p in sim.people: ids[p.id] = true
		for party in sim.parties:
			if party.cabin_id > 0: booked += 1
			if party.state == "departed": completed[party.nights] = true
			if not first_seen and party.id == 1:
				first_seen = true
				expect(party.nights == 2 and party.initial_budget == 480 and party.member_ids.size() == 2, "First party preserves Maya/Leo two-night $480 continuity")
		max_bookings = maxi(max_bookings, booked)
	for label in violations: expect(false, label)
	expect(violations.is_empty(), "All sampled money, identity, occupancy and reserve invariants hold")
	expect(first_seen and max_bookings >= 3, "Several different cabins are booked concurrently")
	expect(max_people >= 8 and max_people <= 12, "Six available cabins sustain a genuine 8–12-person sample")
	expect(ids.size() > 12, "Arrivals replenish after original parties leave")
	for length in [1, 2, 3]: expect(completed.has(length), "A generated " + str(length) + "-night stay completes")
	observations.population = {"sim_seconds": 1200, "peak_live_people": max_people, "peak_bookings": max_bookings, "unique_people": ids.size(), "completed_lengths": completed.keys()}
	_case("POP-02", "Full or blocked accommodation does not reserve or charge an impossible room")
	var no_rooms := _map()
	for record in no_rooms.objects.duplicate():
		if record.kind == "cabin": no_rooms.remove_object(record.id)
	var waiting = _simulation(no_rooms)
	if waiting == null: return
	waiting.advance(20.0)
	for party in waiting.parties:
		expect(party.cabin_id < 1 and party.room_spent == 0 and party.activity_spent == 0, "No room means no reservation or payment")
	for p in waiting.people:
		expect(not p.reason.is_empty() and p.state in ["arriving", "waiting_room", "departing", "departed"], "Unaccommodated customer has an explained wait/departure")
	_case("SAVE-SIM-01", "Simulation JSON round-trip retains identity, RNG, money, routes and deadlines transactionally")
	var snapshot: Dictionary = _json(sim.capture())
	var restored = _simulation(map)
	if restored == null: return
	expect(restored.restore(snapshot), "Accept valid JSON simulation snapshot")
	var control = _simulation(map)
	if control == null: return
	expect(control.restore(snapshot), "Restore independent uninterrupted control")
	for index in 600: restored.advance(0.1)
	for index in 240: control.advance(0.25)
	expect(_equal(restored.capture(), control.capture()), "Equivalent elapsed time preserves complete state, future arrivals and distance phase")
	_test_bad_simulation(restored)

func _test_bad_simulation(sim: Variant) -> void:
	var source: Dictionary = _json(sim.capture())
	if not source.get("people") is Array or not source.get("parties") is Array or source.people.is_empty() or source.parties.is_empty():
		pending("Malformed simulation mutations need actual snapshot people/parties key mapping; publish in handoff")
		return
	for mutation in ["fractional_id", "duplicate_person", "orphan_party", "money", "fractional_night", "role", "position", "state", "need", "missing_route"]:
		var bad: Dictionary = source.duplicate(true)
		match mutation:
			"fractional_id": bad.people[0].id = 1.5
			"duplicate_person": bad.people.append(bad.people[0].duplicate(true))
			"orphan_party": bad.people[0].party_id = 999999
			"money": bad.parties[0].budget += 1
			"fractional_night": bad.parties[0].paid_nights = 0.5
			"role": bad.people[0].role = 2
			"position": bad.people[0].motion.position = [10000, 10000]
			"state": bad.people[0].state = "unrecognized_state"
			"need": bad.people[0].needs.hunger = "hungry"
			"missing_route":
				bad.people[0].state = "to_cabin"
				bad.people[0].motion.route = []
				bad.people[0].motion.index = 0
		expect(not sim.restore(bad), "Reject malformed simulation " + mutation)
		expect(_equal(sim.capture(), source), "Rejected restore preserves open simulation " + mutation)

func _facilities() -> void:
	_case("FAC-01", "Physical café capacity, reachable unique waiting positions, FIFO and cancellation")
	var script = _module("facilities")
	if script == null: return
	var map := _map()
	var service = script.new()
	if not _methods(service, ["configure", "request", "ticket", "confirm_arrival", "ready", "release", "advance", "slot", "route", "inspect", "capture", "restore"]): return
	service.configure(map, assets)
	var cafe: Dictionary = {}
	var court: Dictionary = {}
	for record in map.objects:
		if record.kind == "cafe": cafe = record
		if record.kind == "volleyball": court = record
	var waiting: Array[int] = []
	var points: Array[Vector2] = []
	var graph := map.navigation()
	for id in range(1, 13):
		var ticket: Dictionary = service.request(id, id, cafe.id, "meal", float(id) / 10.0)
		if id <= 2: expect(ticket.get("status", "") == "reserved", "First two customers reserve separate café seats")
		if ticket.get("status", "") == "queued":
			waiting.append(id)
			var point = ticket.get("queue_position")
			expect(point is Vector2, "Queued ticket exposes its physical waiting point")
			if not point is Vector2: continue
			for other in points: expect(point.distance_to(other) > 0.4, "Waiting customers have separate physical positions")
			points.append(point)
			var cell := Vector2i(point.round())
			expect(graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(), "Queue point is reachable ground")
			for record in map.objects:
				if ResortCatalog.definition(record.kind).get("access", false):
					var door: Vector2 = record.position + Vector2(ResortCatalog.entrance(record.kind, record.orientation))
					expect(point.distance_to(door) > 0.45, "Queue leaves every protected doorway clear")
	expect(not waiting.is_empty() and waiting.size() < 10, "Visible queue exists and rejects overflow at a finite limit")
	expect(service.confirm_arrival(1, 2.0) and service.confirm_arrival(2, 2.0), "Actual arrivals activate reserved café tickets")
	expect(service.ready(1) and service.ready(2), "Both occupied café seats become ready")
	var a: Dictionary = service.slot(1)
	var b: Dictionary = service.slot(2)
	expect(not a.is_empty() and not b.is_empty() and a.get("position", Vector2.ZERO).distance_to(b.get("position", Vector2.ZERO)) > 0.1, "Two café customers use distinct measured furniture")
	if not a.is_empty(): expect(a.position.is_equal_approx(GuestActivitySlots.slot(cafe, "eating", 0, assets).position), "First seat reuses the accepted fixture")
	service.release(1)
	if not waiting.is_empty():
		expect(service.ticket(waiting[0]).get("status", "") in ["reserved", "active"], "Releasing capacity admits the oldest waiting customer")
		for id in waiting.slice(1): expect(service.ticket(id).get("status", "") == "queued", "Later arrivals cannot jump the queue")
	var saved: Dictionary = _json(service.capture())
	var resumed = script.new()
	resumed.configure(map, assets)
	expect(resumed.restore(saved) and _equal(resumed.capture(), saved), "Active/queued service state survives JSON round-trip")
	service.advance(900.0, 902.0, [])
	for id in range(1, 13): expect(not service.ready(id), "Timeout/cancel does not leave usable orphan reservations")
	_case("FAC-02", "Two people from different parties rally on opposite sides; a lone arrival never pays/plays")
	var volley = script.new()
	volley.configure(map, assets)
	volley.request(101, 10, court.id, "volleyball", 0.0)
	volley.confirm_arrival(101, 1.0)
	expect(not volley.ready(101), "First volleyball arrival waits for a partner")
	volley.request(202, 20, court.id, "volleyball", 1.0)
	volley.confirm_arrival(202, 2.0)
	expect(volley.ready(101) and volley.ready(202), "Cross-party arrivals are paired")
	var left: Dictionary = volley.slot(101)
	var right: Dictionary = volley.slot(202)
	expect(not left.is_empty() and not right.is_empty(), "Both participants have court fixtures")
	if not left.is_empty() and not right.is_empty():
		expect((left.position.x - court.position.x - 4.0) * (right.position.x - court.position.x - 4.0) < 0, "Rally positions straddle the net")
		expect(left.facing != right.facing, "Participants face opposing court directions")
	expect(volley.ticket(101).get("partner_id", 0) == 202 and volley.ticket(202).get("partner_id", 0) == 101, "Partner ownership is reciprocal across parties")
	volley.release(101)
	volley.advance(900.0, 902.0, [])
	expect(not volley.ready(101) and not volley.ready(202), "Partner release/timeout cannot orphan a one-person match")

func _cleanliness() -> void:
	_case("CLEAN-01", "Mess comes from completed visits, stays local/reachable/bounded, and cleaners walk to exclusive jobs")
	var script = _module("cleanliness")
	if script == null: return
	var map := _map()
	var service = script.new()
	if not _methods(service, ["configure", "advance", "on_activity_finished", "score_at", "hire", "dismiss", "inspect", "layout_changed", "access_survives", "capture", "restore", "drain_events"]): return
	service.configure(map, assets)
	for index in 240: service.advance(0.25, (index + 1) * 0.25)
	expect(service.inspect().get("mess", []).is_empty(), "Rendering/idle time alone does not generate visit litter")
	var cafe_id := -1
	for record in map.objects:
		if record.kind == "cafe": cafe_id = record.id
	for index in 400: service.on_activity_finished(index + 1, cafe_id, "meal", 60.0)
	var view: Dictionary = service.inspect()
	var mess: Array = view.get("mess", [])
	expect(not mess.is_empty() and mess.size() < 400, "Many completed meals generate bounded visible mess")
	var graph := map.navigation()
	var ids := {}
	for entry in mess:
		expect(not ids.has(entry.get("id")), "Mess identities are unique")
		ids[entry.get("id")] = true
		var point = entry.get("position")
		expect(point is Vector2, "Mess exposes logical ground position")
		if not point is Vector2: continue
		var cell := Vector2i(point.round())
		expect(graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(), "Mess can actually be reached")
		expect(service.score_at(point) < service.score_at(Vector2(4, 20)), "Dirt has a local rather than global cleanliness penalty")
	var first_id := 0
	for index in 4:
		var hired: Dictionary = service.hire()
		expect(hired.get("ok", false) == (index < 3), "Janitor hiring respects maximum three")
		if index == 0: first_id = hired.get("id", 0)
	var saw_walking := false
	var saw_cleaning := false
	var saw_dismiss_claim := false
	var minimum_mess := mess.size()
	for index in 1200:
		service.advance(0.25, 60.0 + (index + 1) * 0.25)
		view = service.inspect()
		var targets := {}
		var by_id := {}
		for entry in view.get("mess", []): by_id[entry.id] = entry
		minimum_mess = mini(minimum_mess, by_id.size())
		for staff in view.get("staff", []):
			var target: int = staff.get("target_mess_id", -1)
			if target > 0:
				expect(not targets.has(target), "Only one janitor claims each cleanup job")
				targets[target] = staff.id
			saw_walking = saw_walking or staff.get("state", "") == "walking"
			if staff.get("state", "") == "cleaning":
				saw_cleaning = true
				expect(by_id.has(target) and staff.get("position") is Vector2, "Cleaning references live mess and a logical staff position")
				if by_id.has(target) and staff.get("position") is Vector2:
					expect(staff.position.distance_to(by_id[target].position) <= 1.1, "Janitor cleans within reach, never remotely")
			if not saw_dismiss_claim and staff.id == first_id and target > 0:
				saw_dismiss_claim = service.dismiss(first_id)
				break
	expect(saw_walking and saw_cleaning and minimum_mess < mess.size(), "Actual walking and cleaning removes visible mess")
	expect(saw_dismiss_claim, "Dismiss a janitor while a live job is claimed")
	for staff in service.inspect().get("staff", []): expect(staff.id != first_id, "Dismissed janitor has no remaining staff record")
	var snapshot: Dictionary = _json(service.capture())
	var restored = script.new()
	restored.configure(map, assets)
	expect(restored.restore(snapshot), "Staff, routes, job claims and RNG restore from JSON")
	_case("WAGE-01", "One $30 wage per completed 180-second day/staff, including a boundary resume")
	var wage = script.new()
	wage.configure(map, assets)
	expect(wage.hire().get("ok", false), "Hire wage fixture janitor without an upfront cost")
	wage.drain_events()
	wage.advance(179.75, 179.75)
	expect(wage.drain_events().is_empty(), "No daily wage before the day completes")
	var before_boundary: Dictionary = _json(wage.capture())
	var wage_resume = script.new()
	wage_resume.configure(map, assets)
	expect(wage_resume.restore(before_boundary), "Restore just before a wage boundary")
	wage.advance(0.25, 180.0)
	wage_resume.advance(0.25, 180.0)
	var events: Array = wage.drain_events()
	expect(_equal(events, wage_resume.drain_events()), "Resume emits the same uniquely identified wage")
	expect(events.size() == 1 and events[0].get("kind", "") == "wage" and events[0].get("amount", 0) == -30 and not events[0].get("id", "").is_empty(), "Day one produces exactly one signed $30 wage")
	wage.advance(0.0, 180.0)
	expect(wage.drain_events().is_empty(), "Same-day update cannot charge wages twice")
	wage.advance(360.0, 540.0)
	var later: Array = wage.drain_events()
	expect(later.size() == 2, "Advancing two more days charges exactly two more wages")
	var unique := {}
	for event in events + later:
		expect(not unique.has(event.get("id")) and event.get("amount", 0) == -30, "Wage IDs and amounts remain consistent")
		unique[event.get("id")] = true

func _ledger() -> void:
	_case("LEDGER-01", "Signed financial events are idempotent and survive day-boundary JSON restore")
	var script = _module("ledger")
	if script == null: return
	var ledger = script.new()
	if not _methods(ledger, ["record", "inspect", "capture", "restore"]): return
	var events: Array[Dictionary] = [{"id": "qa-room-1-1", "kind": "room", "amount": 60, "time": 0.0, "party_id": 1}, {"id": "qa-meal-1", "kind": "meal", "amount": 12, "time": 179.9, "party_id": 1, "person_id": 1}, {"id": "qa-wage-1-1", "kind": "wage", "amount": -30, "time": 180.0, "staff_id": 1}, {"id": "qa-room-1-2", "kind": "room", "amount": 60, "time": 180.0, "party_id": 1}]
	for event in events: expect(ledger.record(event), "First delivery records " + event.id)
	var before: Dictionary = _json(ledger.capture())
	var display: Dictionary = ledger.inspect(180.0)
	for event in events: expect(not ledger.record(event), "Duplicate delivery is ignored " + event.id)
	expect(_equal(before, ledger.capture()) and _equal(display, ledger.inspect(180.0)), "Duplicate deliveries cannot change totals or history")
	var resumed = script.new()
	expect(resumed.restore(before) and _equal(display, resumed.inspect(180.0)), "Ledger JSON restore preserves displayed totals")
	for event in events: expect(not resumed.record(event), "Resume remembers the recorded event ID")
	for bad in [{"id": "bad-fraction", "kind": "meal", "amount": 12.5, "time": 1.0}, {"id": "bad-wage", "kind": "wage", "amount": 30, "time": 1.0}, {"id": "bad-room", "kind": "room", "amount": -60, "time": 1.0}, {"id": "", "kind": "room", "amount": 60, "time": 1.0}]:
		expect(not resumed.record(bad), "Reject malformed/signed-wrong financial event " + bad.id)
	expect(_equal(before, resumed.capture()), "Invalid ledger events preserve existing operating state")
	observations.ledger_expected_fixture = {"income": 132, "wages": 30, "net": 102, "day_0_income": 72, "day_1_income": 60, "day_1_wages": 30, "actual_inspect": display}
	expect(display.get("income_total", -1) == 132 and display.get("wages_total", -1) == 30 and display.get("net_total", -1) == 102, "Displayed lifetime income/wages/net reconcile with actual events")
	expect(display.get("day", -1) == 2 and display.get("today_income", -1) == 60 and display.get("today_wages", -1) == 30 and display.get("today_net", -1) == 30, "Exactly-180 events appear once in the second half-open day")
	var days := {}
	for entry in display.get("days", []): days[int(entry.day)] = entry
	expect(days.has(1) and days[1].income == 72 and days[1].wages == 0 and days[1].net == 72, "First displayed day contains precisely room plus meal income")
	expect(days.has(2) and days[2].income == 60 and days[2].wages == 30 and days[2].net == 30, "Second displayed day reconciles room income and signed staff wage")

func _legacy() -> void:
	_case("LEGACY-01", "Import schema-3 solo/couple and older solo snapshots without resetting money, phase or night deadline")
	if _module("simulation") == null: return
	var map := _map()
	for size in [1, 2]:
		var legacy := GuestStay.new()
		legacy.party_size = size
		legacy.configure(map, assets)
		for index in 4000:
			legacy.advance(0.1)
			if legacy.state == "eating": break
		expect(legacy.state == "eating", "Legacy fixture reaches a paid activity")
		for version in ([1, 2] if size == 1 else [2]):
			var saved: Dictionary = _json(legacy.capture())
			saved.version = version
			if version == 1:
				saved.erase("companion")
				saved.erase("activity_elapsed")
			var sim = _simulation(map)
			if sim == null: return
			expect(sim.import_legacy(saved), "Import legacy size/version " + str(size) + "/" + str(version))
			if sim.parties.size() != 1:
				expect(false, "Legacy import creates exactly one shared booking")
				continue
			var party: Dictionary = sim.parties[0]
			expect(party.member_ids.size() == size and party.budget == legacy.budget and party.room_spent == legacy.accommodation_spent and party.activity_spent == legacy.activity_spent, "Legacy member count and exact paid money survive")
			expect(party.cabin_id == legacy.cabin_id and party.paid_nights == legacy.paid_nights and is_equal_approx(party.next_night, legacy.next_night), "Legacy reservation, night count and remaining deadline survive")
			expect(absf(sim.clock - legacy.clock) < 0.0001, "Legacy simulation clock is preserved")
			var first: Dictionary = sim.person(party.member_ids[0])
			expect(first.get("motion") is GuestMotion and first.motion.position.distance_to(legacy.logical_position) < 0.001 and absf(first.motion.distance - legacy.walked_distance) < 0.001, "Legacy route position and walked phase survive")
			var stable: Dictionary = _json(sim.capture())
			var broken: Dictionary = saved.duplicate(true)
			broken.budget += 1
			expect(not sim.import_legacy(broken) and _equal(stable, sim.capture()), "Malformed legacy import preserves open population")

func _envelope_key(data: Dictionary) -> String:
	for key in data:
		var value = data[key]
		if value is Dictionary and value.has("simulation") and value.has("facilities") and value.has("cleanliness") and value.has("ledger"): return str(key)
	return ""

func _runtime(map: ResortLayout) -> Variant:
	var script = _module("runtime")
	if script == null: return null
	var model = script.new()
	if not model.configure(map, assets):
		expect(false, "Real backend wrapper configures all contracted services")
		return null
	return model

func _first_difference(a: Variant, b: Variant, path: String = "root") -> String:
	if _equal(a, b): return ""
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): return path + "." + str(key) + " missing"
			var difference := _first_difference(a[key], b[key], path + "." + str(key))
			if not difference.is_empty(): return difference
		return path + " dictionary keys differ"
	if a is Array and b is Array:
		if a.size() != b.size(): return path + " sizes " + str(a.size()) + "/" + str(b.size())
		for index in a.size():
			var difference := _first_difference(a[index], b[index], path + "[" + str(index) + "]")
			if not difference.is_empty(): return difference
	return path + ": " + str(a).left(120) + " versus " + str(b).left(120)

func _save_backend_evidence(label: String, value: Dictionary) -> void:
	var path := "res://artifacts/worker-6-backend-" + label + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		expect(false, "Write isolated backend reproducer " + label)
		return
	file.store_string(JSON.stringify(value, "\t"))
	file.close()

func _backend_probe(map: ResortLayout, source: Dictionary, label: String) -> void:
	_case("BACKEND-RESUME-" + label.to_upper(), "Real attached-service JSON resume at observed " + label)
	var control = _runtime(map)
	var resumed = _runtime(map)
	if control == null or resumed == null: return
	var raw_ok: bool = control.restore(source)
	var json_ok: bool = resumed.restore(_json(source))
	expect(raw_ok and json_ok, "Observed live " + label + " envelope is accepted by raw and JSON restore")
	if not raw_ok or not json_ok:
		_save_backend_evidence("rejected-live-" + label, source)
		return
	expect(_equal(source, resumed.capture()), "Immediate JSON round-trip preserves every service at " + label)
	control.advance(40.0)
	for index in 1200: resumed.advance(1.0 / 30.0)
	var actual: Dictionary = resumed.capture()
	var expected: Dictionary = control.capture()
	var difference := _first_difference(expected, actual)
	expect(difference.is_empty(), "Equal 40-second futures from " + label + " agree across raw/JSON and step sizes: " + difference)
	observations["backend_resume_" + label] = {"clock": source.simulation.clock, "raw_restore": raw_ok, "json_restore": json_ok, "first_difference": difference}
	if not difference.is_empty():
		_save_backend_evidence("resume-" + label, {"initial": source, "expected": expected, "actual": actual, "first_difference": difference})

func _backend_reject(map: ResortLayout, good: Dictionary, bad: Dictionary, label: String) -> void:
	var target = _runtime(map)
	if target == null: return
	var baseline_ok: bool = target.restore(_json(good))
	expect(baseline_ok, "Valid positive control restores before cross-service mutation " + label)
	if not baseline_ok: return
	var before: Dictionary = _json(target.capture())
	var accepted: bool = target.restore(_json(bad))
	expect(not accepted, "Reject individually well-formed but cross-service inconsistent " + label)
	expect(_equal(before, target.capture()), "Rejected cross-service mutation preserves all open state: " + label)
	observations["cross_service_" + label] = {"accepted": accepted, "clock": good.simulation.clock}
	if accepted: _save_backend_evidence("accepted-" + label, {"valid": good, "malformed": bad})

func _backend_corruptions(map: ResortLayout, meal: Dictionary, latest: Dictionary) -> void:
	_case("BACKEND-CROSS-01", "Retained live guests cannot lose required tickets or gain a forged financial owner")
	if meal.is_empty():
		pending("No actual paid meal snapshot was observed for cross-service ownership mutations")
		return
	var good: Dictionary = _json(meal)
	var stripped: Dictionary = good.duplicate(true)
	stripped.facilities.tickets = []
	var facility_script = _module("facilities")
	if facility_script == null: return
	var standalone = facility_script.new()
	standalone.configure(map, assets)
	expect(standalone.restore(stripped.facilities), "Stripped ticket service is individually well-formed; envelope must detect live owners")
	_backend_reject(map, good, stripped, "missing-live-tickets")
	var ledger_script = _module("ledger")
	if ledger_script == null: return
	var journal = ledger_script.new()
	var changed := false
	var entries_ok := true
	for entry in good.ledger.events:
		var event: Dictionary = entry.duplicate(true)
		if not changed and event.kind in ["meal", "sunbathe", "volleyball"]:
			event.person_id = 999999
			changed = true
		entries_ok = journal.record(event) and entries_ok
	expect(changed and entries_ok, "Build valid-checksummed ledger with same receipts/totals but nonexistent activity payer")
	if changed and entries_ok:
		var orphan: Dictionary = good.duplicate(true)
		orphan.ledger = journal.capture()
		_backend_reject(map, good, orphan, "orphan-ledger-person")
	var wage_journal = ledger_script.new()
	changed = false
	entries_ok = true
	for entry in latest.ledger.events:
		var event: Dictionary = entry.duplicate(true)
		if not changed and event.kind == "wage":
			event.staff_id = 999999
			changed = true
		entries_ok = wage_journal.record(event) and entries_ok
	if changed and entries_ok:
		var bad_staff: Dictionary = _json(latest)
		bad_staff.ledger = wage_journal.capture()
		_backend_reject(map, _json(latest), bad_staff, "orphan-ledger-staff")
	else:
		pending("No actual wage receipt was available for journal/staff ownership mutation")

func _backend_replay_rejections() -> void:
	_case("BACKEND-CROSS-REPLAY", "Fast positive/negative replay of independently captured cross-service defects")
	var map := _crowd_map()
	for label in ["missing-live-tickets", "orphan-ledger-person", "orphan-ledger-staff"]:
		var path: String = "res://tests/fixtures/cross-service-" + str(label) + ".json"
		if not FileAccess.file_exists(path):
			pending("Missing retained valid/malformed regression fixture: " + path)
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or not data.get("valid") is Dictionary or not data.get("malformed") is Dictionary:
			expect(false, "Captured reproducer has both actual valid and malformed envelopes")
			continue
		_backend_reject(map, data.valid, data.malformed, label)

func _backend_cross_party() -> void:
	_case("BACKEND-COURT-01", "Actual decisions and routes admit two players from different parties to a single court")
	var map := _crowd_map()
	for record in map.objects.duplicate():
		if record.kind in ["cafe", "sunbeds"]: map.remove_object(record.id)
	var model = _runtime(map)
	if model == null: return
	var matched := false
	var players: Array = []
	# Controlled NEEDS fixture: one member of each arriving party wants sport;
	# a companion has urgent rest. No state, motion, ticket or payment is forged.
	for tick in 4000:
		for p in model.simulation.people:
			var party: Dictionary = model.simulation.party(p.party_id)
			if not party.state in ["active", "reserved"]: continue
			var chosen_role := 1 if party.member_ids.size() == 2 else 0
			if p.role == chosen_role:
				p.needs = {"hunger": 90.0, "rest": 90.0, "enjoyment": 1.0}
				p.profile.interests = ["volleyball", "stroll"]
			else:
				p.needs = {"hunger": 90.0, "rest": 1.0, "enjoyment": 90.0}
		model.advance(0.25)
		for p in model.simulation.people:
			if p.state != "volleyball": continue
			var ticket: Dictionary = model.facilities.ticket(p.id)
			var partner: Dictionary = model.simulation.person(ticket.get("partner_id", 0))
			if partner.is_empty() or partner.party_id == p.party_id or partner.state != "volleyball": continue
			matched = true
			players = [p.id, partner.id]
			expect(p.session_paid and partner.session_paid and model.facilities.ready(p.id) and model.facilities.ready(partner.id), "Both cross-party players are physically admitted and individually paid")
			var a: Dictionary = model.facilities.slot(p.id)
			var b: Dictionary = model.facilities.slot(partner.id)
			expect(not a.is_empty() and not b.is_empty() and a.position.distance_to(b.position) > 3.0 and a.facing != b.facing, "Actual cross-party players occupy opposing measured court sides")
			var receipts := {}
			for event in model.ledger.capture().events:
				if event.kind == "volleyball" and event.get("person_id", 0) in players:
					receipts[event.person_id] = event.amount
			expect(receipts.size() == 2 and receipts[p.id] == 10 and receipts[partner.id] == 10, "Two distinct parties each pay the one-person $10 court fee")
			break
		if matched: break
	expect(matched, "A real cross-party rally starts from autonomous needs choices without fixture tickets")
	observations.backend_cross_party = {"matched": matched, "clock": model.simulation.clock, "person_ids": players, "fixture": "one urgent-sport member per party; companions urgently tired; court is the only paid leisure facility"}
	if not matched: _save_backend_evidence("cross-party-not-observed", model.capture())

func _backend() -> void:
	_case("BACKEND-POP-01", "Natural population advances real facilities, dirt, cleaner jobs and ledger through one shared clock")
	var map := _crowd_map()
	var model = _runtime(map)
	if model == null: return
	var sim = model.simulation
	expect(sim.facilities == model.facilities and sim.cleanliness == model.cleanliness and sim.ledger == model.ledger, "Population uses the actual shared service instances")
	expect(model.cleanliness.hire().get("ok", false), "Hire one real cleaner through the attached service")
	var violations := {}
	var snapshots := {}
	var peak_live := 0
	var peak_accommodated := 0
	var peak_bookings := 0
	var max_queue := 0
	var max_dirt := 0
	var completed := {}
	var states := {}
	var admissions := {"meal": 0, "sunbathe": 0, "volleyball": 0}
	var event_count := 0
	var event_ids := {}
	var cross_party_matches := {}
	var saw_cleaning := false
	var split := false
	var split_parties := {}
	var joined_after_split := false
	for tick in 4800:
		model.advance(0.25)
		peak_live = maxi(peak_live, _invariants(sim, violations))
		var booked := 0
		var accommodated := 0
		for party in sim.parties:
			if party.cabin_id > 0:
				booked += 1
				accommodated += party.member_ids.size()
			if party.state == "departed": completed[party.nights] = true
			if party.state == "checkout" and not snapshots.has("checkout"): snapshots.checkout = model.capture()
			if party.member_ids.size() == 2:
				var a: Dictionary = sim.person(party.member_ids[0])
				var b: Dictionary = sim.person(party.member_ids[1])
				if a.activity != b.activity and a.motion.position.distance_to(b.motion.position) > 2 and not a.state in ["departed", "departing"] and not b.state in ["departed", "departing"]:
					split = true
					split_parties[party.id] = true
					if not snapshots.has("split"): snapshots.split = model.capture()
				if split_parties.has(party.id) and a.state == "sleeping" and b.state == "sleeping" and party.state == "reuniting": joined_after_split = true
		peak_accommodated = maxi(peak_accommodated, accommodated)
		peak_bookings = maxi(peak_bookings, booked)
		var clean: Dictionary = model.cleanliness.inspect()
		max_dirt = maxi(max_dirt, clean.mess.size())
		var claimed := {}
		for staff in clean.staff:
			if staff.target_mess_id > 0:
				if claimed.has(staff.target_mess_id): violations["Integrated cleaners claim the same mess"] = true
				claimed[staff.target_mess_id] = staff.id
			if staff.state == "cleaning":
				saw_cleaning = true
				if not snapshots.has("cleaning"): snapshots.cleaning = model.capture()
		var queued := 0
		for p in sim.people:
			states[p.state] = true
			if p.state == "queueing":
				queued += 1
				if not snapshots.has("queue"): snapshots.queue = model.capture()
			if p.state == "eating" and not snapshots.has("meal"): snapshots.meal = model.capture()
		max_queue = maxi(max_queue, queued)
		var finance: Dictionary = model.ledger.inspect(sim.clock)
		if finance.income_total != sim.total_room_income + sim.total_activity_income: violations["Attached ledger income does not reconcile with population"] = true
		if finance.wages_total != model.cleanliness.total_wages: violations["Attached wages do not reconcile with actual payroll"] = true
		if absf(float(clean.clock) - sim.clock) > 0.000001: violations["Cleanliness clock diverges from population"] = true
		if finance.event_count != event_count:
			var journal: Dictionary = model.ledger.capture()
			for index in range(event_count, journal.events.size()):
				var event: Dictionary = journal.events[index]
				if event_ids.has(event.id): violations["Duplicate attached financial event ID"] = true
				event_ids[event.id] = true
				if not event.kind in ["meal", "sunbathe", "volleyball"]: continue
				admissions[event.kind] += 1
				var payer: Dictionary = sim.person(int(event.get("person_id", 0)))
				if payer.is_empty():
					violations["New admission event has no actual guest"] = true
					continue
				var ticket: Dictionary = model.facilities.ticket(payer.id)
				if ticket.get("status") != "active" or not model.facilities.ready(payer.id) or not payer.session_paid: violations["Activity was charged before actual ready admission"] = true
				var fixture: Dictionary = model.facilities.slot(payer.id)
				if fixture.is_empty() or payer.motion.position.distance_to(fixture.get("position", Vector2(-999, -999))) > 0.06: violations["Admission payment was collected away from the physical fixture"] = true
				if event.kind == "volleyball":
					var partner: Dictionary = sim.person(int(ticket.get("partner_id", 0)))
					if partner.is_empty() or partner.state != "volleyball": violations["Court admission lacks an actual rally partner"] = true
					elif partner.party_id != payer.party_id: cross_party_matches[ticket.get("match_id", "")] = true
			event_count = journal.events.size()
	for label in violations: expect(false, label)
	expect(violations.is_empty(), "Live attached-service invariants and physical admission charges hold throughout 1200 seconds")
	expect(peak_bookings >= 4 and peak_accommodated >= 8 and peak_live <= 12, "Actual attached backend supports several bookings and at least eight accommodated people")
	for length in [1, 2, 3]: expect(completed.has(length), "Real services permit complete " + str(length) + "-night stays")
	expect(admissions.meal > 0 and admissions.sunbathe > 0, "Need choices create real paid meals and lounger visits")
	expect(max_dirt > 0 and saw_cleaning, "Real completed visits generate dirt and a janitor actually reaches cleaning")
	expect(split and joined_after_split, "An actual couple splits activities and later reunites for overnight progression")
	expect(model.ledger.inspect(sim.clock).wages_total == 180, "One attached janitor receives exactly six $30 global-day wages")
	observations.backend_population = {"seconds": sim.clock, "peak_live": peak_live, "peak_accommodated": peak_accommodated, "peak_bookings": peak_bookings, "max_queued": max_queue, "max_mess": max_dirt, "completed_lengths": completed.keys(), "paid_admissions": admissions, "cross_party_matches": cross_party_matches.size(), "states": states.keys(), "snapshots": snapshots.keys()}
	for label in ["queue", "meal", "split", "cleaning", "checkout"]:
		if snapshots.has(label): _backend_probe(map, snapshots[label], label)
		else:
			_case("BACKEND-RESUME-" + label.to_upper(), "Observed real attached " + label + " trigger")
			pending("Required " + label + " was not observed in this deterministic natural sample; construct a targeted valid backend fixture")
	_backend_corruptions(map, snapshots.get("meal", {}), model.capture())

func _new_world(path: String) -> Variant:
	var scene = load("res://scenes/world/coastal_resort.tscn")
	if scene == null: return null
	var resort = scene.instantiate()
	# Must happen BEFORE add_child/_ready; do not pass --workspace-data.
	resort.save_path = path
	resort.set_process(false)
	root.add_child(resort)
	resort.set_process(false)
	return resort

func _world_ui(resort: Variant) -> void:
	_case("WORLD-UI-01", "Real management controls select/follow every live guest, hire/dismiss staff and reconcile results")
	var ui = resort.management
	var sim = resort.living.simulation
	ui.show_section("guests")
	resort._refresh_management()
	var people: Array = sim.people.duplicate()
	for p in people:
		if p.state == "departed": continue
		var rows: Dictionary = ui.get("_guest_rows")
		expect(rows.has(p.id), "Actual guest list includes person " + str(p.id))
		if not rows.has(p.id): continue
		rows[p.id].root.pressed.emit()
		expect(resort.selected_person_id == p.id and not resort.following_guest, "Guest button selects the correct actual identity " + str(p.id))
		ui.get("_guest_follow").pressed.emit()
		resort._process(0.0)
		expect(resort.following_guest and resort.selected_person_id == p.id and resort.camera.position.distance_to(resort.population_view.actor_position(p.id) + Vector2(0, -35)) < 0.001, "Follow button tracks the selected live actor " + str(p.id))
		var actor = resort.population_view.actors[p.id]
		var texture = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame)
		var bitmap: Image = texture.get_image()
		var picked := false
		for y in range(0, bitmap.get_height(), 2):
			if picked: break
			for x in range(0, bitmap.get_width(), 2):
				if bitmap.get_pixel(x, y).a < 0.95: continue
				var point: Vector2 = actor.sprite.to_global(actor.sprite.offset + Vector2(x + 0.5, y + 0.5))
				if resort.population_view.hit_test(point) != p.id: continue
				resort.select_at(point)
				picked = resort.selected_person_id == p.id
				if picked: break
		expect(picked, "Picking an opaque actual actor selects person " + str(p.id))
	ui.show_section("staff")
	resort._refresh_management()
	var count: int = resort.living.cleanliness.inspect().hired_count
	ui.get("_hire").pressed.emit()
	var staff: Array = resort.living.cleanliness.inspect().staff
	expect(staff.size() == count + 1, "Actual Hire button changes the same staff service displayed in the panel")
	if not staff.is_empty():
		var id: int = staff.back().id
		var staff_rows: Dictionary = ui.get("_staff_rows")
		expect(staff_rows.has(id), "Hired cleaner immediately has a real panel row")
		if staff_rows.has(id): staff_rows[id].dismiss.pressed.emit()
		expect(resort.living.cleanliness.inspect().hired_count == count, "Actual Dismiss button removes the same staff identity")
	ui.get("_hire").pressed.emit()
	expect(resort.living.cleanliness.inspect().hired_count == count + 1, "Hire replacement through actual UI for the live cleaning/save cases")
	ui.show_section("operations")
	resort._refresh_management()
	var finance: Dictionary = resort.living.ledger.inspect(sim.clock)
	var cells: Dictionary = ui.get("_operation_cells")
	expect(cells.income.total.text == "$" + str(finance.income_total), "Actual Results income label matches live receipts")
	expect(cells.wages.total.text == ("−$" if finance.wages_total > 0 else "$") + str(finance.wages_total), "Actual Results wages label matches live payroll")
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(960, 600)]:
		root.size = size
		for section_name in ["guests", "facilities", "staff", "operations"]:
			ui.show_section(section_name)
			for frame in 3: await process_frame
			var bounds: Rect2 = ui.panel.get_global_rect()
			var viewport: Vector2 = root.get_visible_rect().size
			expect(bounds.position.y >= 94 and bounds.end.y <= viewport.y - 178 and bounds.position.x >= 12 and bounds.end.x <= viewport.x - 12, "Live " + section_name + " panel fits between HUD and tray at " + str(size))
	root.size = Vector2i(1440, 900)
	resort.following_guest = false
	ui.close()

func _world_trigger_resume(resort: Variant, label: String) -> void:
	_case("WORLD-RESUME-" + label.to_upper(), "Actual Save and scene restart during observed " + label)
	var path := "res://artifacts/living-resort-qa-" + run_tag + "-" + label + ".json"
	resort.save_path = path
	resort._on_action("speed_1")
	var before: Dictionary = resort.living.capture()
	resort._on_action("save")
	var resumed = _new_world(path)
	expect(resumed != null and resumed.living != null and _equal(before, resumed.living.capture()), "Actual scene startup restores all services at " + label)
	if resumed == null or resumed.living == null:
		if resumed != null: resumed.free()
		return
	if label == "cleaning":
		var dismissal = _new_world(path)
		dismissal.management.show_section("staff")
		dismissal._refresh_management()
		var dismissed_job := false
		for worker in dismissal.living.cleanliness.inspect().staff:
			if worker.target_mess_id <= 0: continue
			var id: int = worker.id
			var target: int = worker.target_mess_id
			dismissal.management.get("_staff_rows")[id].dismiss.pressed.emit()
			var remains := false
			for other in dismissal.living.cleanliness.inspect().staff:
				if other.id == id: remains = true
			expect(not remains, "Actual Dismiss button removes a cleaner with a live saved job")
			for dirt in dismissal.living.cleanliness.inspect().mess:
				if dirt.id == target: expect(dirt.claimed_by == 0, "Dismissing an actively cleaning janitor releases the actual mess claim")
			dismissed_job = true
			break
		expect(dismissed_job, "Dismissal fixture uses a genuine observed active cleanup claim")
		dismissal.free()
	resumed._on_action("speed_1")
	for frame in 100:
		resort._process(0.1)
		resumed._process(0.1)
	expect(_equal(resort.living.capture(), resumed.living.capture()), "Uninterrupted original and scene-restarted world agree ten seconds after " + label)
	resumed.free()
	if label == "meal":
		var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		malformed.live_resort.facilities.tickets = []
		var invalid_path := path.trim_suffix(".json") + "-missing-tickets.json"
		var output := FileAccess.open(invalid_path, FileAccess.WRITE)
		output.store_string(JSON.stringify(malformed))
		output.close()
		var opened := ResortLayout.new()
		expect(opened.load_layout(path) == OK, "Actual file loader accepts the observed paid meal positive control")
		var previous: Dictionary = opened.live_resort.duplicate(true)
		var objects: Array = opened.objects.duplicate(true)
		expect(opened.load_layout(invalid_path) != OK and opened.live_resort == previous and opened.objects == objects, "Malformed real file with missing paid-user tickets cannot replace the open layout or live resort")

func _world_extended(resort: Variant) -> void:
	await _world_ui(resort)
	_case("WORLD-TRIGGERS", "Default-world real queues, meal, split couple, cleaning and checkout are exercised")
	var seen := {}
	# Replay an actual default-world queue captured by the earlier independent
	# run. Social volleyball choices legitimately changed subsequent traffic;
	# keep the real queue/save regression independent of incidental crowd timing.
	# This is a preserved scene snapshot, not manufactured tickets/positions.
	var queue_world = _new_world("res://tests/fixtures/occupied-facility-queue.json")
	queue_world._on_action("speed_1")
	var queued := false
	for p in queue_world.living.simulation.people:
		if p.state == "queueing": queued=true
	expect(queued,"Preserved default-world fixture contains a real physically waiting guest")
	if queued:
		seen.queue=queue_world.living.simulation.clock
		_world_trigger_resume(queue_world,"queue")
	queue_world.free()
	resort._on_action("speed_1")
	for frame in 7000:
		resort._process(0.1)
		var sim = resort.living.simulation
		var possible := {}
		for p in sim.people:
			if p.state == "queueing": possible.queue = true
			if p.state == "eating": possible.meal = true
		for staff in resort.living.cleanliness.inspect().staff:
			if staff.state == "cleaning": possible.cleaning = true
		for party in sim.parties:
			if party.state == "checkout": possible.checkout = true
			if party.member_ids.size() != 2: continue
			var a: Dictionary = sim.person(party.member_ids[0])
			var b: Dictionary = sim.person(party.member_ids[1])
			if a.activity != b.activity and a.motion.position.distance_to(b.motion.position) > 2 and not a.state in ["departed", "departing"] and not b.state in ["departed", "departing"]: possible.split = true
		for label in possible:
			if seen.has(label): continue
			seen[label] = sim.clock
			_world_trigger_resume(resort, label)
		if seen.size() == 5: break
		if frame % 500 == 0: await process_frame
	_case("WORLD-TRIGGER-COVERAGE", "All five required default-world live-save fixtures were actually observed")
	for label in ["queue", "meal", "split", "cleaning", "checkout"]: expect(seen.has(label), "Observed and round-tripped actual " + label)
	observations.world_save_triggers = seen
	_case("WORLD-EDIT-02", "Protected facilities, booked rooms, undo/redo and route removal are enforced by actual scene controls")
	var guarded := 0
	for record in resort.layout.objects:
		if not resort.living.protects(record.id): continue
		guarded += 1
		resort.selected_id = record.id
		var before: Dictionary = record.duplicate(true)
		for action in ["move", "rotate", "remove"]:
			resort._on_action(action)
			expect(resort.layout.find_object(record.id) == before and resort.mode == "select", "Actual guarded " + action + " preserves " + record.kind + " " + str(record.id))
		resort.mode = "move"
		resort.moving_id = record.id
		resort.build_kind = record.kind
		resort._commit_preview()
		expect(resort.layout.find_object(record.id) == before and resort.mode == "select", "A move opened before reservation cannot bypass the actual protected commit")
		var invalid: Dictionary = resort._snapshot().duplicate(true)
		for index in range(invalid.objects.size() - 1, -1, -1):
			if invalid.objects[index].id == record.id: invalid.objects.remove_at(index)
		resort.redo_stack.append(invalid)
		var redo_count: int = resort.redo_stack.size()
		var undo_count: int = resort.undo_stack.size()
		resort._on_action("redo")
		expect(resort.redo_stack.size() == redo_count and resort.undo_stack.size() == undo_count, "Blocked redo preserves history for guarded " + record.kind)
		resort.redo_stack.pop_back()
	expect(guarded > 0, "At least one actually occupied object was tested")
	var cut: Dictionary = resort._snapshot().duplicate(true)
	cut.paths = {}
	var original: Dictionary = resort._snapshot()
	expect(not resort._restore(cut) and _equal(original, resort._snapshot()), "Actual restore/edit seam rejects a path edit that strands guests or staff")

func _world_clock_matrix(resort: Variant) -> void:
	_case("WORLD-CLOCK-MATRIX", "Actual 30/60/120 FPS and 1x/2x/4x calls agree across global day and wage boundaries")
	resort._on_action("speed_1")
	while resort.living.simulation.clock < 350.0: resort._process(0.1)
	var path := "res://artifacts/living-resort-qa-" + run_tag + "-clock.json"
	resort.save_path = path
	resort._on_action("save")
	var control: Dictionary = {}
	for fps in [30, 60, 120]:
		for multiplier in [1, 2, 4]:
			var sample = _new_world(path)
			sample._on_action("speed_" + str(multiplier))
			for frame in int(24 * fps / multiplier): sample._process(1.0 / fps)
			var state: Dictionary = sample.living.capture()
			if control.is_empty(): control = state
			expect(_equal(control, state), "Whole live state agrees at " + str(fps) + " FPS / " + str(multiplier) + "x: " + _first_difference(control, state))
			for p in sample.living.simulation.people:
				if p.state == "departed": continue
				var actor = sample.population_view.actors[p.id]
				expect(absf(actor.walked_distance - p.motion.distance) < 0.000001, "Rendered walk phase retains actual distance for person " + str(p.id))
			sample.free()
	resort._on_action("speed_1")
	for frame in 110: resort._process(0.1)
	resort.management.show_section("operations")
	resort._refresh_management()
	var finance: Dictionary = resort.living.ledger.inspect(resort.living.simulation.clock)
	expect(finance.wages_total > 0 and resort.management.get("_operation_cells").wages.total.text == "−$" + str(finance.wages_total), "Actual Results panel shows the real negative daily wage after a live day boundary")

func _dirty_world() -> void:
	_case("WORLD-DIRT-RECOVERY", "Validated dirty queue fixture drives real world complaint, warning, UI hire, cleaning and recovery")
	var chosen := ""
	var newest := 0
	for name in DirAccess.get_files_at("res://artifacts"):
		if name.begins_with("living-resort-qa-") and name.ends_with("-queue.json"):
			var path: String = "res://artifacts/" + name
			if FileAccess.get_modified_time(path) > newest:
				newest = FileAccess.get_modified_time(path)
				chosen = path
	expect(not chosen.is_empty(), "Actual saved default-world queue fixture is available")
	if chosen.is_empty(): return
	var resort = _new_world(chosen)
	resort._on_action("speed_1")
	var target: Dictionary = {}
	for p in resort.living.simulation.people:
		if p.state == "queueing":
			target = p
			break
	expect(not target.is_empty(), "Fixture contains an actual physically queued guest")
	if target.is_empty():
		resort.free()
		return
	for worker in resort.living.cleanliness.inspect().staff: resort._management_action("dismiss_janitor", worker.id)
	var start: float = resort.living.simulation.clock
	var activity: String = target.activity
	for index in 128: resort.living.cleanliness.on_activity_finished(10000 + index, target.facility_id, activity, start)
	var dirty: Dictionary = resort.living.cleanliness.capture()
	var point: Vector2 = target.motion.position
	var graph: AStarGrid2D = resort.layout.navigation()
	var doors := {}
	for record in resort.layout.objects:
		if ResortCatalog.definition(record.kind).get("access", false): doors[Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)] = true
	var points: Array[Vector2] = []
	for x in range(int(point.x) - 4, int(point.x) + 5):
		for y in range(int(point.y) - 4, int(point.y) + 5):
			var cell := Vector2i(x, y)
			if graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not doors.has(cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(): points.append(Vector2(cell))
	points.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(point) < b.distance_squared_to(point))
	# Explicit persisted fixture: service-generated dirt is concentrated onto
	# validated nearby ground, and two real occupied visits are held for 50s.
	# No guest position, queue ticket, fee or renderer pose is invented.
	for index in mini(dirty.mess.size(), points.size()): dirty.mess[index].position = [points[index].x, points[index].y]
	expect(resort.living.cleanliness.restore(_json(dirty)), "Service accepts the explicitly concentrated reachable dirt fixture")
	for p in resort.living.simulation.people:
		if p.facility_id == target.facility_id and p.state in ["sitting", "eating", "lying"]: p.timer = 50.0
	var validator = _runtime(resort.layout)
	expect(validator.restore(_json(resort.living.capture())), "Complete staged wrapper validates the dirty queue fixture before behavioral advancement")
	var initial_score: float = resort.living.cleanliness.score_at(point)
	var warning_at := -1.0
	var recovery_at := -1.0
	var warning_mood := 0.0
	var ui_warned := false
	for frame in 650:
		target.needs = {"hunger": 60.0, "rest": 60.0, "enjoyment": 60.0}
		resort._process(0.1)
		if warning_at < 0 and target.warning_elapsed > 0 and not target.want_leave:
			warning_at = resort.living.simulation.clock
			warning_mood = target.mood
			resort._management_action("select_guest", target.id)
			resort.management.show_section("guests")
			resort._refresh_management()
			ui_warned = resort.management.get("_guest_details").warning.visible
			resort.management.show_section("staff")
			for index in 3: resort.management.get("_hire").pressed.emit()
			resort.management.show_section("guests")
		if warning_at >= 0 and target.warning_elapsed == 0 and not target.want_leave and target.mood >= 43.0:
			recovery_at = resort.living.simulation.clock
			break
	var cleaned := 0
	for worker in resort.living.cleanliness.inspect().staff: cleaned += worker.cleaned_count
	resort._refresh_management()
	expect(warning_at > start and ui_warned, "Actual local dirt produces a grace warning in the real guest panel")
	expect(recovery_at > warning_at and recovery_at - warning_at < 30.0 and cleaned > 0, "Real hired janitors clean the area and recover the guest inside the grace period")
	expect(target.motion.position.distance_to(point) < 0.05, "Recovery happens at the same queue position, not by walking away from dirt")
	expect(not target.want_leave and not resort.management.get("_guest_details").warning.visible, "Recovered real guest stays and the actual UI clears the warning")
	observations.combined_dirty_recovery = {"fixture_source": chosen, "person_id": target.id, "activity": activity, "adequate_needs_held": 60, "initial_score": initial_score, "final_score": resort.living.cleanliness.score_at(point), "start": start, "warning_at": warning_at, "warning_mood": warning_mood, "recovery_at": recovery_at, "recovered_mood": target.mood, "cleaned_jobs": cleaned, "displacement": target.motion.position.distance_to(point), "still_wants_leave": target.want_leave, "controlled_fixture": "Service-generated dirt concentrated on validated nearby ground; existing occupied visits held for 50 seconds; actual guest state, route, queue, charges and janitor work unchanged"}
	resort.free()

func _world() -> void:
	_case("WORLD-01", "Actual scene pause/speed call site and occupied edits use the live population")
	for service_key in ["simulation", "facilities", "cleanliness", "ledger"]:
		if not FileAccess.file_exists(MODULES[service_key]):
			pending("Default-scene integration awaits " + MODULES[service_key])
			return
	for path_required in ["res://scripts/ui/resort_management_ui.gd", "res://scripts/world/cleanliness_view.gd"]:
		if not FileAccess.file_exists(path_required):
			pending("Default-scene integration awaits " + path_required)
			return
	var path := "res://artifacts/living-resort-qa-" + run_tag + ".json"
	var resort = _new_world(path)
	if resort == null:
		expect(false, "Actual world scene loads")
		return
	var sim = _find_simulation(resort)
	if sim == null:
		pending("World still exposes only the legacy stay; coordinator scene integration is pending")
		resort.free()
		return
	expect(not resort.get("legacy_stay_fixture"), "Independent acceptance uses default living mode")
	expect(resort.get("walkers").is_empty(), "Fourteen ambient walkers are absent from the default simulation")
	expect(resort.get("population_view") != null, "Actual population presentation is attached")
	resort._on_action("speed_1")
	for index in 200: resort._process(0.1)
	var before: Dictionary = _json(_world_capture(resort, sim))
	resort._on_action("pause")
	for index in 60: resort._process(1.0 / 30.0)
	expect(_equal(before, _world_capture(resort, sim)), "Pause freezes money, needs, RNG, routes, queues and staff")
	for speed in [1, 2, 4]:
		resort._on_action("speed_" + str(speed))
		var clock: float = sim.clock
		resort._process(0.1)
		expect(absf(sim.clock - clock - 0.1 * speed) < 0.001, "Actual world speed " + str(speed) + " scales the shared clock once")
	for party in sim.parties:
		if party.cabin_id <= 0: continue
		resort.selected_id = party.cabin_id
		var cabin: Dictionary = resort.layout.find_object(party.cabin_id).duplicate(true)
		for action in ["move", "rotate", "remove"]:
			resort._on_action(action)
			expect(resort.layout.find_object(cabin.id) == cabin and resort.mode == "select", "Every booked cabin rejects actual " + action + " action")
		var undo: Dictionary = resort._snapshot().duplicate(true)
		for record in undo.objects:
			if record.id == cabin.id: record.orientation = (record.orientation + 1) % 2
		resort.undo_stack.append(undo)
		var count: int = resort.undo_stack.size()
		resort._on_action("undo")
		expect(resort.undo_stack.size() == count and resort.redo_stack.is_empty(), "Blocked occupied undo preserves both histories")
		resort.undo_stack.pop_back()
		break
	var candidate := ResortLayout.new()
	candidate.objects.assign(resort.layout.objects.duplicate(true))
	candidate.next_id = resort.layout.next_id
	expect(not sim.access_survives(candidate), "Removing all connected paths is rejected for live guests/services")
	_case("WORLD-SAVE-01", "Actual Save action and scene startup round-trip the new envelope; invalid files preserve the open map")
	resort._on_action("save")
	expect(FileAccess.file_exists(path), "Save control writes only its isolated QA path")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		expect(false, "Saved resort is JSON")
		resort.free()
		return
	var key := _envelope_key(data)
	if key.is_empty():
		pending("New live-resort envelope is not yet present in actual Save output")
		resort.free()
		return
	expect(data[key].get("version", 0) == 1, "Actual save writes envelope version one")
	var resumed = _new_world(path)
	var resumed_sim = _find_simulation(resumed)
	expect(resumed_sim != null, "Scene startup restores the authoritative population")
	if resumed_sim != null:
		expect(_equal(sim.capture(), resumed_sim.capture()), "Actual scene save/load preserves complete simulation")
		for service_key in ["facilities", "cleanliness", "ledger"]:
			var a = sim.get(service_key)
			var b = resumed_sim.get(service_key)
			expect(a != null and b != null and _equal(a.capture(), b.capture()), "Actual save/load preserves " + service_key)
		resort._on_action("speed_2")
		resumed._on_action("speed_2")
		for index in 300:
			resort._process(0.1)
			resumed._process(0.1)
		expect(_equal(sim.capture(), resumed_sim.capture()), "Uninterrupted and resumed actual worlds agree after another minute at 2x")
	resumed.free()
	for mutation in ["envelope_version", "missing_service", "fractional_person"]:
		var bad: Dictionary = data.duplicate(true)
		match mutation:
			"envelope_version": bad[key].version = 1.5
			"missing_service": bad[key].cleanliness = null
			"fractional_person":
				if not bad[key].simulation.get("people") is Array or bad[key].simulation.people.is_empty():
					pending("Top-level mutation needs the finalized simulation people key mapping")
					continue
				bad[key].simulation.people[0].id = 1.5
		var corrupt_path: String = "res://artifacts/living-resort-qa-" + run_tag + "-" + str(mutation) + ".json"
		var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(bad))
		file.close()
		var loaded := ResortLayout.new()
		expect(loaded.load_layout(path) == OK, "Load valid map before invalid-load preservation test")
		var objects: Array = loaded.objects.duplicate(true)
		var paths: Dictionary = loaded.paths.duplicate(true)
		expect(loaded.load_layout(corrupt_path) != OK and loaded.objects == objects and loaded.paths == paths, "Actual layout loader rejects " + mutation + " without replacing open edits")
	await _world_extended(resort)
	_world_clock_matrix(resort)
	resort.free()

func _run() -> void:
	run_tag = str(OS.get_process_id()) + "-" + str(Time.get_ticks_msec())
	protected_before = _hashes()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
		if arg == "--allow-pending": allow_pending = true
		if arg == "--prepare-only": prepare_only = true
	_case("SAFE-01", "QA binds isolated saves and rejects player-save launch flags")
	if not only.is_empty() and not only in ["profiles", "brain", "population", "facilities", "cleanliness", "ledger", "legacy", "backend", "backend-reject", "backend-court", "world", "dirty-world"]:
		expect(false, "Unknown focused section: " + only)
		_finish()
		return
	if "--workspace-data" in OS.get_cmdline_user_args() or "--fresh" in OS.get_cmdline_user_args():
		expect(false, "Run without --workspace-data/--fresh; QA must isolate startup and exercise resume")
		_finish()
		return
	expect(true, "Protected save hashes captured before any scene startup")
	observations.source_hashes = {}
	for key in MODULES:
		if FileAccess.file_exists(MODULES[key]): observations.source_hashes[key] = FileAccess.get_sha256(MODULES[key])
	if prepare_only:
		_case("PREPARE-01", "Wave-1 acceptance harness readiness; no feature claims")
		for key in MODULES:
			observations[key + "_source_present"] = FileAccess.file_exists(MODULES[key])
		pending("Preparation-only run: production APIs, integration and visual/performance acceptance have not been exercised")
	else:
		assets = ResortAssets.new()
		if _selected("profiles"): _profiles()
		if _selected("brain"): _brain()
		if _selected("population"): _population()
		if _selected("facilities"): _facilities()
		if _selected("cleanliness"): _cleanliness()
		if _selected("ledger"): _ledger()
		if _selected("legacy"): _legacy()
		if _selected("backend"): _backend()
		if _selected("backend-reject"): _backend_replay_rejections()
		if _selected("backend-court"): _backend_cross_party()
		if _selected("world"): await _world()
		if only == "dirty-world": _dirty_world()
	_finish()

func _finish() -> void:
	_case("SAFE-02", "Player workspace and direct-play saves/backups are byte-for-byte unchanged")
	expect(_equal(protected_before, _hashes()), "Protected save presence and SHA-256 are unchanged")
	var failures := 0
	var incomplete := 0
	for result in cases:
		if result.status == "failed": failures += 1
		if result.status == "pending": incomplete += 1
	var report := {"suite": "living_resort_checks", "mode": "prepare" if prepare_only else ("all" if only.is_empty() else only), "engine": Engine.get_version_info().string, "checks": checks, "failed_cases": failures, "pending_cases": incomplete, "automated_complete": failures == 0 and incomplete == 0 and not prepare_only and only.is_empty(), "acceptance_complete": false, "manual_review_required": ["GPU screenshots and in-motion staff/guest/furniture review", "Actual 8–12-customer rendered performance sample", "Wave-2 integrated acceptance cases documented in living-resort-qa.md"], "cases": cases, "observations": observations, "protected_saves_before": protected_before, "protected_saves_after": _hashes()}
	var report_path: String = REPORT.trim_suffix(".json") + ("-prepare" if prepare_only else ("-" + only if not only.is_empty() else "")) + ".json"
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write independent QA report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("LIVING_RESORT_CHECKS checks=", checks, " failed_cases=", failures, " pending_cases=", incomplete, " report=", ProjectSettings.globalize_path(report_path))
	quit(1 if failures > 0 else (2 if incomplete > 0 and not allow_pending else 0))
