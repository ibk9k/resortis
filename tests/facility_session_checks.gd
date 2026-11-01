extends SceneTree
## Focused service scenarios. No scene startup or player-save I/O.

const Sessions = preload("res://scripts/simulation/facility_sessions.gd")
const Couples = preload("res://scripts/simulation/party_coordinator.gd")
var checks := 0
var failures: Array[String] = []
var assets: ResortAssets
var map: ResortLayout
var cafe: Dictionary
var beds: Dictionary
var court: Dictionary

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))

func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _same(a[index], b[index]): return false
		return true
	return a == b

func _service() -> RefCounted:
	var service := Sessions.new()
	service.configure(map, assets)
	return service

func _view(service: RefCounted, id: int) -> Dictionary:
	for entry in service.inspect():
		if entry.id == id: return entry
	return {}

func _run() -> void:
	map = ResortLayout.new()
	map.seed_default()
	assets = ResortAssets.new()
	for record in map.objects:
		if record.kind == "cafe": cafe = record
		if record.kind == "sunbeds" and beds.is_empty(): beds = record
		if record.kind == "volleyball": court = record
	_capacity_and_fifo()
	_arrival_and_exits()
	_volleyball()
	_snapshots()
	_lanes_and_edits()
	_timeout_equivalence()
	_couples()
	print("FACILITY_SESSION_CHECKS ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _capacity_and_fifo() -> void:
	for fixture in [[cafe, "meal", "eating"], [beds, "sunbathe", "lying"], [court, "volleyball", "volleyball"]]:
		var service := _service()
		var record: Dictionary = fixture[0]
		var activity: String = fixture[1]
		for id in range(1, 7):
			var entry: Dictionary = service.request(id, id, record.id, activity, 0.0)
			expect(entry.get("status") == ("reserved" if id <= 2 else "queued"), activity + " has two places then four bounded waiting tickets")
			expect(not service.ready(id), "No activity is ready at reservation or in a queue")
		var full: Dictionary = service.capture()
		expect(service.request(7, 7, record.id, activity, 0.0).is_empty(), activity + " rejects queue overflow")
		expect(_same(full, service.capture()), "Rejecting overflow does not change reservations or order")
		expect(not _view(service, record.id).available, "A full bounded queue is unavailable")
		for id in [1, 2]:
			var slot: Dictionary = service.slot(id)
			var accepted := GuestActivitySlots.slot(record, fixture[2], id - 1, assets)
			expect(slot.position.is_equal_approx(accepted.position), activity + " reuses each accepted measured fixture")
			var path: Array = service.route(id)
			var reverse: Array = service.route(id, true)
			var original: Array = GuestActivitySlots.approach(record, fixture[2], id - 1, assets)
			expect(path == original, activity + " uses the accepted approach")
			reverse.reverse()
			expect(path == reverse, "Exit uses the same path in reverse")
		expect(service.slot(1).position.distance_to(service.slot(2).position) > 0.1, activity + " never stacks two physical users")
		expect(service.route(3).is_empty() and service.slot(3).is_empty(), "Queued guests cannot use furniture")
		var repeated: Dictionary = service.request(1, 1, record.id, activity, 0.0)
		expect(repeated == service.ticket(1) and _same(full, service.capture()), "Repeated request is idempotent")
		expect(service.request(1, 99, record.id, activity, 0.0).is_empty(), "A person cannot request a second party's ticket")
		# Cancelling a queued guest opens queue admission even while both seats
		# remain occupied. The offer must support real in-game queueing.
		service.release(6)
		var offer := _view(service, record.id)
		expect(offer.available and offer.immediate_vacancy == 0 and not offer.available_now, "An occupied facility still offers its reachable bounded queue")
		service.release(1)
		expect(service.ticket(3).status == "reserved", "FIFO promotes the oldest waiting person immediately")
		if activity == "volleyball":
			expect(service.ticket(4).status == "reserved" and service.ticket(5).status == "queued", "Both cancelled unarrived court reservations pass to the next FIFO pair")
		else:
			expect(service.ticket(4).status == "queued" and service.ticket(5).status == "queued", "Later waiting people retain order")
		service.request(8, 8, record.id, activity, 0.0)
		expect(service.ticket(8).status == "queued", "A new request cannot take an older waiting person's place")
		var copy: Dictionary = service.ticket(3)
		copy.slot = 100
		expect(service.ticket(3).slot in [0, 1], "Returned ticket dictionaries cannot mutate service claims")
	var service := _service()
	expect(service.request(0, 1, cafe.id, "meal", 0.0).is_empty(), "Zero person identity is rejected")
	expect(service.request(1, 0, cafe.id, "meal", 0.0).is_empty(), "Zero party identity is rejected")
	expect(service.request(1, 1, cafe.id, "volleyball", 0.0).is_empty(), "Activity must match the actual facility")
	expect(service.request(1, 1, -1, "meal", 0.0).is_empty(), "Unknown facility is rejected")
	expect(service.request(1, 1, cafe.id, "meal", NAN).is_empty(), "Nonfinite clock is rejected")

func _person(id: int, record: Dictionary, activity: String) -> Dictionary:
	var motion := GuestMotion.new()
	motion.position = Vector2(ResortLayout.ARRIVAL)
	return {"id": id, "party_id": id, "facility_id": record.id, "activity": activity, "motion": motion, "state": "to_facility"}

func _arrival_and_exits() -> void:
	var service := _service()
	service.request(1, 1, cafe.id, "meal", 0.0)
	service.request(2, 2, cafe.id, "meal", 0.0)
	service.request(3, 3, cafe.id, "meal", 0.0)
	var guest := _person(1, cafe, "meal")
	var other := _person(2, cafe, "meal")
	var queued := _person(3, cafe, "meal")
	service.advance(1.0, 1.0, [guest, other, queued])
	expect(not service.confirm_arrival(1, 1.0), "The real controller cannot admit someone still walking outside")
	expect(not service.confirm_arrival(3, 1.0), "A queued guest cannot confirm a physical arrival")
	guest.motion.position = service.slot(1).position
	guest.state = "approaching_activity"
	expect(service.confirm_arrival(1, 1.0) and service.ready(1), "Physical fixture arrival makes a meal ready")
	var admitted: Dictionary = service.capture()
	expect(service.confirm_arrival(1, 1.0) and _same(service.capture(), admitted), "Repeated arrival cannot restart admission or timers")
	guest.state = "eating"
	service.advance(60.0, 61.0, [guest, other, queued])
	expect(not service.ready(1) and service.ticket(1).status == "expired", "A stale active visit expires")
	expect(service.ticket(1).claim_held, "An expired customer physically at the table retains its evacuation claim")
	# Ticket 3 timed out in the queue at 55; request another person while the
	# expired occupant is still visible at the table.
	service.request(4, 4, cafe.id, "meal", 61.0)
	expect(service.ticket(4).status == "queued", "A new visitor cannot be assigned an exiting person's seat")
	guest.state = "leaving_activity"
	service.advance(1.0, 62.0, [guest, other, _person(4, cafe, "meal")])
	expect(service.ticket(1).claim_held, "Exit keeps the seat until the actual person clears the furniture")
	guest.motion.position = Vector2(cafe.position) + Vector2(ResortCatalog.entrance("cafe"))
	service.release(1)
	expect(service.ticket(4).status == "reserved" and service.ticket(4).slot == 0, "Physical exit releases the correct seat to FIFO admission")
	var source := _json(service.capture())
	var resumed := _service()
	expect(resumed.restore(source) and _same(resumed.capture(), source), "Expired and waiting notifications retain their exact cancellation timers")

func _volleyball() -> void:
	var service := _service()
	service.request(101, 10, court.id, "volleyball", 0.0, 102)
	expect(service.confirm_arrival(101, 1.0) and not service.ready(101), "A lone arrival waits without playing or admission")
	expect(not service.ticket(101).admitted and service.ticket(101).partner_id == 0, "An absent preferred companion holds no imaginary reservation")
	service.request(202, 20, court.id, "volleyball", 1.0)
	expect(not service.ready(101) and not service.ready(202), "Pair reservation alone does not begin a rally")
	expect(service.confirm_arrival(202, 2.0), "A guest from another party reaches the opposite court slot")
	expect(service.ready(101) and service.ready(202), "Both actual arrivals start a cross-party rally")
	var left: Dictionary = service.ticket(101)
	var right: Dictionary = service.ticket(202)
	expect(left.partner_id == 202 and right.partner_id == 101 and left.match_id == right.match_id, "Actual partner and match ownership is reciprocal")
	expect(left.active_at == 2.0 and right.active_at == 2.0, "Both partners share a persisted rally start time")
	expect((service.slot(101).position.x - court.position.x - 3.5) * (service.slot(202).position.x - court.position.x - 3.5) < 0, "Physical rally positions straddle the actual net")
	expect(service.slot(101).facing != service.slot(202).facing, "Opposing players use different accepted facings")
	service.confirm_arrival(101, 9.0)
	var after: Dictionary = service.ticket(101)
	expect(after.active_at == 2.0 and after.arrived_at == 1.0 and after.match_id == left.match_id, "Repeated confirm does not replay volleyball admission")
	var resumed := _service()
	expect(resumed.restore(_json(service.capture())) and resumed.ready(101) and resumed.ready(202), "A mid-rally snapshot keeps both arrivals and readiness")
	resumed.release(101)
	expect(not resumed.ready(202) and resumed.ticket(202).get("status") == "expired", "Partner cancellation immediately ends the peer's rally")
	resumed.advance(100.0, 109.0)
	expect(not resumed.ticket(202).get("claim_held", true), "An unbound timed-out match cannot leak a permanent claim")
	var lone := _service()
	lone.request(1, 1, court.id, "volleyball", 0.0)
	lone.confirm_arrival(1, 1.0)
	var waiting := _service()
	expect(waiting.restore(_json(lone.capture())) and not waiting.ready(1), "Resuming a lone arrived player does not invent a partner or admission")
	lone.advance(21.0, 22.0)
	waiting.advance(21.0, 22.0)
	expect(_same(lone.capture(), waiting.capture()), "Resuming a partner wait preserves its remaining deadline")
	lone.advance(22.0, 23.0)
	expect(lone.ticket(1).status == "expired" and not lone.ready(1), "A lone player's wait has a fixed deadline")
	var couple := _service()
	couple.request(1, 5, court.id, "volleyball", 0.0, 2)
	couple.request(2, 5, court.id, "volleyball", 0.0, 1)
	couple.confirm_arrival(1, 1.0)
	couple.confirm_arrival(2, 2.0)
	expect(couple.ready(1) and couple.ready(2), "Companions can form the same two-person match")
	couple.request(3, 6, court.id, "volleyball", 2.0, 4)
	couple.request(4, 6, court.id, "volleyball", 2.0, 3)
	couple.release(1)
	expect(couple.ticket(3).status == "reserved" and couple.ticket(4).status == "queued", "Cancelling a match preserves the peer's exit claim and FIFO")
	couple.release(2)
	expect(couple.ticket(4).status == "reserved" and couple.ticket(3).partner_id == 4, "Next companions pair after both preceding positions clear")
	for id in [3, 4]:
		var path: Array = couple.route(id)
		for index in range(1, path.size()):
			var a: Vector2 = path[index - 1] - court.position
			var b: Vector2 = path[index] - court.position
			if (a.x - 3.5) * (b.x - 3.5) <= 0.0 and absf(a.x - b.x) > 0.0001:
				var crossing := a.lerp(b, (3.5 - a.x) / (b.x - a.x))
				expect(crossing.y > 4.45 or crossing.y < -0.45, "Every net-crossing approach passes clear of the actual post and net")
	# Actual controller states announce an early exit before release() at the
	# door. The other player must stop rallying while that first player walks.
	var observed := _service()
	observed.request(1, 1, court.id, "volleyball", 0.0)
	observed.request(2, 2, court.id, "volleyball", 0.0)
	var one := _person(1, court, "volleyball")
	var two := _person(2, court, "volleyball")
	one.motion.position = observed.slot(1).position
	two.motion.position = observed.slot(2).position
	one.state = "approaching_activity"
	two.state = "approaching_activity"
	observed.advance(1.0, 1.0, [one, two])
	observed.confirm_arrival(1, 1.0)
	observed.confirm_arrival(2, 1.0)
	one.state = "volleyball"
	two.state = "volleyball"
	observed.advance(1.0, 2.0, [one, two])
	expect(observed.ready(1) and observed.ready(2), "A live pair stays admitted while both actually rally")
	one.state = "leaving_activity"
	observed.advance(0.1, 2.1, [one, two])
	expect(observed.ticket(1).status == "expired" and observed.ticket(2).status == "expired" and not observed.ready(2), "One player's actual early exit cancels both before the exit route finishes")
	expect(observed.ticket(1).claim_held and observed.ticket(2).claim_held, "Cancelling a visible rally preserves both physical exit claims")
	var cancelled := _json(observed.capture())
	var resumed_exit := _service()
	expect(resumed_exit.restore(cancelled) and _same(resumed_exit.capture(), cancelled), "Save/resume preserves a cancelled pair still standing on its court")
	var entrant: Dictionary = observed.request(3, 3, court.id, "volleyball", 2.1)
	expect(entrant.status == "queued", "A new player queues while a cancelled pair is still physically exiting")
	one.motion.position = court.position + Vector2(4, 5)
	observed.advance(0.1, 2.2, [one, two, _person(3, court, "volleyball")])
	expect(not observed.ticket(1).claim_held and observed.ticket(3).status == "reserved", "Observed clearance can safely release the first exiting slot")
	expect(observed.ticket(2).claim_held and not observed.ready(2), "The slower exiting peer keeps its own slot without a solo rally")

func _snapshots() -> void:
	var service := _service()
	for id in range(1, 7): service.request(id, id, cafe.id, "meal", 0.0)
	service.confirm_arrival(1, 1.0)
	service.confirm_arrival(2, 2.0)
	var source := _json(service.capture())
	var resumed := _service()
	expect(resumed.restore(source) and _same(resumed.capture(), source), "JSON round-trip preserves active seats, queue order and all timers")
	service.release(1)
	resumed.release(1)
	service.advance(3.0, 5.0)
	resumed.advance(3.0, 5.0)
	expect(_same(service.capture(), resumed.capture()), "A resumed queue promotes exactly the same oldest visitor")
	var mutations := ["duplicate_person", "duplicate_slot", "duplicate_station", "fractional_station", "near_duplicate_station", "fractional_id", "fractional_slot", "fractional_sequence", "nan_time", "future_time", "bad_facility", "wrong_activity", "invented_admission", "queued_slot", "queued_arrival", "queued_payment", "missing_flag", "reordered_fifo", "backward_request_time", "next_sequence", "door_station", "unreachable_station", "queue_with_vacancy", "unknown_field"]
	for mutation in mutations:
		var bad := source.duplicate(true)
		match mutation:
			"duplicate_person": bad.tickets[1].person_id = bad.tickets[0].person_id
			"duplicate_slot": bad.tickets[1].slot = bad.tickets[0].slot
			"duplicate_station": bad.tickets[3].queue_position = bad.tickets[2].queue_position.duplicate()
			"fractional_station": bad.tickets[3].queue_position[0] += 0.000001
			"near_duplicate_station":
				bad.tickets[3].queue_position = bad.tickets[2].queue_position.duplicate()
				bad.tickets[3].queue_position[0] += 0.000001
			"fractional_id": bad.tickets[0].person_id = 1.5
			"fractional_slot": bad.tickets[0].slot = 0.5
			"fractional_sequence": bad.tickets[0].sequence = 1.25
			"nan_time": bad.tickets[0].arrived_at = NAN
			"future_time": bad.tickets[0].arrived_at = 100.0
			"bad_facility": bad.tickets[0].facility_id = 9999
			"wrong_activity": bad.tickets[0].activity = "volleyball"
			"invented_admission": bad.tickets[2].admitted = true
			"queued_slot": bad.tickets[2].slot = 0
			"queued_arrival": bad.tickets[2].arrived = true
			"queued_payment": bad.tickets[2].active_at = 1.0
			"missing_flag": bad.tickets[0].erase("arrived")
			"reordered_fifo": bad.tickets.reverse()
			"backward_request_time": bad.tickets[2].requested_at = 1.0
			"next_sequence": bad.next_sequence = 1
			"door_station": bad.tickets[2].queue_position = [cafe.position.x + 2.0, cafe.position.y + 4.0]
			"unreachable_station": bad.tickets[2].queue_position = [0, 0]
			"queue_with_vacancy": bad.tickets.remove_at(0)
			"unknown_field": bad.tickets[0].invented = {"claims": true}
		var current: Dictionary = resumed.capture()
		expect(not resumed.restore(bad), "Reject malformed snapshot: " + mutation)
		expect(_same(resumed.capture(), current), "Rejected snapshot leaves open service unchanged: " + mutation)
	var volley := _service()
	volley.request(11, 1, court.id, "volleyball", 0.0)
	volley.request(22, 2, court.id, "volleyball", 0.0)
	volley.confirm_arrival(11, 1.0)
	volley.confirm_arrival(22, 2.0)
	var valid := _json(volley.capture())
	for mutation in ["partner", "match", "start", "one_arrival", "self_partner", "nonreciprocal"]:
		var bad := valid.duplicate(true)
		match mutation:
			"partner": bad.tickets[0].partner_id = 99
			"match": bad.tickets[0].match_id = "invented"
			"start": bad.tickets[1].active_at = 1.5
			"one_arrival": bad.tickets[1].arrived = false
			"self_partner": bad.tickets[0].partner_id = 11
			"nonreciprocal": bad.tickets[1].partner_id = 0
		expect(not volley.restore(bad) and _same(volley.capture(), valid), "Reject malformed paired court transactionally: " + mutation)

func _lanes_and_edits() -> void:
	var service := _service()
	var id := 1
	var all_points: Array[Vector2] = []
	var graph := map.navigation()
	for record in map.objects:
		if record.kind not in ["cafe", "sunbeds", "volleyball"]: continue
		var activity: String = {"cafe": "meal", "sunbeds": "sunbathe", "volleyball": "volleyball"}[record.kind]
		for unused in 6:
			var entry: Dictionary = service.request(id, id, record.id, activity, 0.0)
			id += 1
			expect(not entry.is_empty(), "Each starter facility can accept two users and four reachable waiting places")
			if entry.is_empty(): continue
			var point: Vector2 = entry.queue_position
			expect(not point in all_points, "Queue stations are distinct across every facility")
			all_points.append(point)
			var cell := Vector2i(point.round())
			expect(not graph.is_point_solid(cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(), "Every station is actual reachable navigation ground")
			for other in map.objects:
				if ResortCatalog.definition(other.kind).get("access", false):
					var door: Vector2 = other.position + Vector2(ResortCatalog.entrance(other.kind, other.orientation))
					expect(point.distance_to(door) >= 1.05, "Queues preserve the doorway and its immediate approach")
	# Treat every occupied/waiting station as an obstacle and demonstrate that
	# the whole arrangement still leaves EVERY entrance connected to arrival.
	for point in all_points: graph.set_point_solid(Vector2i(point), true)
	for record in map.objects:
		if not ResortCatalog.definition(record.kind).get("access", false): continue
		var door := Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)
		expect(not graph.get_id_path(ResortLayout.ARRIVAL, door).is_empty(), "Even all full queues together leave facility and cabin entrances reachable")
	expect(service.protects(cafe.id) and service.protects(court.id), "Active queue and fixture claims protect their facilities")
	var candidate := ResortLayout.new()
	candidate.seed_default()
	expect(service.access_survives(candidate), "An identical map preserves every queue claim")
	candidate.find_object(cafe.id).position += Vector2.ONE
	expect(not service.access_survives(candidate), "Moving a facility with pending claims is blocked")
	candidate.seed_default()
	var waiting: Vector2 = service.ticket(3).queue_position
	candidate.objects.append({"id": 9999, "kind": "flowers", "position": waiting, "orientation": 0})
	candidate.revision += 1
	expect(not service.access_survives(candidate), "Building over an occupied queue station is blocked")
	var restored := _service()
	expect(restored.restore(_json(service.capture())), "The fully occupied cross-facility queue geometry survives restore")
	var empty := Sessions.new()
	empty.configure(ResortLayout.new(), assets)
	expect(empty.restore(_json(empty.capture())), "An empty facility service can resume on an undeveloped map without claims")
	var blocked := ResortLayout.new()
	blocked.seed_default()
	blocked.paths.clear()
	blocked.revision += 1
	var unreachable := Sessions.new()
	unreachable.configure(blocked, assets)
	expect(unreachable.request(1, 1, cafe.id, "meal", 0.0).is_empty(), "An actually disconnected café cannot admit or queue a customer")
	expect(not _view(unreachable, cafe.id).available, "Decision offers explain that a disconnected café is unavailable")

func _timeout_equivalence() -> void:
	var coarse := _service()
	var fine := _service()
	for service in [coarse, fine]:
		for id in range(1, 7): service.request(id, id, cafe.id, "meal", 0.0)
		service.confirm_arrival(1, 0.0)
		service.confirm_arrival(2, 0.0)
	coarse.advance(150.0, 150.0)
	for step in 1500: fine.advance(0.1, float(step + 1) / 10.0)
	expect(_same(coarse.capture(), fine.capture()), "One elapsed update and 1x/4x-sized steps preserve queue and expiry results")
	for id in range(1, 7): expect(not coarse.ready(id) and not coarse.ticket(id).claim_held, "All unbound expired visits release their claims within a finite time")
	var before: Dictionary = coarse.capture()
	coarse.advance(-1.0, 151.0)
	coarse.advance(0.0, NAN)
	coarse.advance(1.0, 149.0)
	expect(_same(before, coarse.capture()), "Invalid or backward advances leave service state unchanged")

func _companion(id: int, role: int, interests: Array) -> Dictionary:
	return {"id": id, "party_id": 1, "role": role, "state": "deciding", "activity": "", "facility_id": -1,
		"needs": {"hunger": 80.0, "rest": 80.0, "enjoyment": 40.0}, "profile": {"interests": interests}, "want_leave": false, "return_requested": false}

func _couples() -> void:
	var person := _companion(1, 0, ["Sunbathing", "Volleyball"])
	var partner := _companion(2, 1, ["Volleyball", "Beach walks"])
	partner.state = "to_facility"
	partner.activity = "volleyball"
	partner.facility_id = court.id
	var intent := {"activity": "volleyball", "facility_id": court.id}
	var untouched := person.duplicate(true)
	expect(Couples.should_join(person, partner, intent), "A free compatible companion may join an en-route leisure invitation")
	expect(person == untouched, "A companion suggestion never edits motion, needs or ownership")
	for key in ["hunger", "rest"]:
		var urgent := person.duplicate(true)
		urgent.needs[key] = 20.0
		expect(not Couples.should_join(urgent, partner, intent), "Urgent individual " + key + " takes priority over joining")
	var tired := person.duplicate(true)
	tired.needs.rest = 45.0
	expect(not Couples.should_join(tired, partner, intent), "A tired companion does not enter strenuous sport")
	for state in ["eating", "sleeping", "queueing", "approaching_activity", "strolling", "returning", "departing"]:
		var busy := person.duplicate(true)
		busy.state = state
		expect(not Couples.should_join(busy, partner, intent), "Joining cannot interrupt a committed " + state + " state")
	for flag in ["want_leave", "return_requested"]:
		var reuniting := person.duplicate(true)
		reuniting[flag] = true
		expect(not Couples.should_join(reuniting, partner, intent), "Shared leisure cannot override night/checkout reunion")
	var stranger := partner.duplicate(true)
	stranger.party_id = 2
	expect(not Couples.should_join(person, stranger, intent), "Companion advice never conflates different parties")
	var incompatible := person.duplicate(true)
	incompatible.profile.interests = ["Quiet time", "Good food"]
	expect(not Couples.should_join(incompatible, partner, intent), "Independent interests can produce a split couple")
	partner.activity = "sunbathe"
	partner.facility_id = beds.id
	expect(Couples.should_join(person, partner, {"activity": "sunbathe", "facility_id": beds.id}), "A shared sunbathing interest is compatible")
	partner.return_requested = true
	expect(not Couples.should_join(person, partner, {"activity": "sunbathe", "facility_id": beds.id}), "An invited partner's urgent reunion wins too")
	expect(not Couples.should_join(person, person, intent), "A person cannot be its own companion")
