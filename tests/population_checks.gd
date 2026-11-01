extends SceneTree

const Simulation = preload("res://scripts/simulation/resort_simulation.gd")
const Registry = preload("res://scripts/simulation/booking_registry.gd")
var failures: Array[String] = []
var checks := 0

class CleanlinessProbe extends RefCounted:
	var advances := 0
	var finishes: Array = []
	func advance(_delta: float, _clock: float) -> void: advances += 1
	func score_at(_position: Vector2) -> float: return 100.0
	func on_activity_finished(id: int, facility_id: int, activity: String, clock: float) -> void: finishes.append([id, facility_id, activity, clock])
	func drain_events() -> Array[Dictionary]: return []
	func inspect() -> Dictionary: return {"mess": [], "staff": [], "cleanliness": 100, "hired_count": 0}
	func access_survives(_candidate: ResortLayout) -> bool: return true
	func layout_changed() -> void: pass

class LedgerProbe extends RefCounted:
	var events: Dictionary = {}
	func record(event: Dictionary) -> bool:
		if events.has(event.id): return false
		events[event.id] = event.duplicate(true)
		return true
	func inspect(_clock: float) -> Dictionary: return {"events": events.size()}

class FacilityProbe extends RefCounted:
	var advances := 0
	func advance(_delta: float, _clock: float, _people: Array = []) -> void: advances += 1
	func inspect() -> Array: return []
	func ticket(_id: int) -> Dictionary: return {}
	func release(_id: int) -> void: pass

class FractionalQueueProbe extends RefCounted:
	var records: Dictionary = {}
	var position := Vector2(35.2, 17.2)
	func request(id: int, party_id: int, facility_id: int, activity: String, _clock: float, _preferred: int = 0) -> Dictionary:
		records[id] = {"person_id": id, "party_id": party_id, "facility_id": facility_id, "activity": activity, "slot": -1, "status": "queued", "queue_position": position, "partner_id": 0}
		return records[id]
	func advance(_delta: float, _clock: float, _people: Array = []) -> void: pass
	func inspect() -> Array: return []
	func ticket(id: int) -> Dictionary: return records.get(id, {})
	func release(id: int) -> void: records.erase(id)
	func ready(_id: int) -> bool: return false
	func capture() -> Dictionary: return {"tickets": records.values()}

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func make_sim(map: ResortLayout, library: ResortAssets, seed_value: int = 8147) -> RefCounted:
	var simulation := Simulation.new()
	simulation.configure(map, library, seed_value)
	return simulation

func _run() -> void:
	var map := ResortLayout.new()
	map.seed_default()
	var library := ResortAssets.new()
	if "--focus-resume" in OS.get_cmdline_user_args():
		_default_precision_resume_checks(library)
		print("POPULATION_PRECISION_CHECKS ", checks, " checks; ", failures.size(), " failures")
		quit(0 if failures.is_empty() else 1)
		return
	if "--focus-admission" in OS.get_cmdline_user_args():
		_admission_checks(library)
		_atomic_admission_checks(library)
		_fractional_queue_checks(library)
		_partial_exit_checks(library)
		_service_checks(library)
		_external_session_checks(library)
		print("POPULATION_ADMISSION_CHECKS ", checks, " checks; ", failures.size(), " failures")
		quit(0 if failures.is_empty() else 1)
		return
	_booking_checks(map)
	_population_checks(map, library)
	_lifecycle_checks(library)
	_resume_checks(map, library)
	_default_precision_resume_checks(library)
	_admission_checks(library)
	_atomic_admission_checks(library)
	_fractional_queue_checks(library)
	_partial_exit_checks(library)
	_service_checks(library)
	_external_session_checks(library)
	_invalid_checks(map, library)
	_no_room_checks(library)
	_legacy_checks(library)
	print("POPULATION_CHECKS ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _booking_checks(map: ResortLayout) -> void:
	var registry := Registry.new()
	registry.configure(map)
	var first: Dictionary = registry.choose(1, 2, 480)
	var second: Dictionary = registry.choose(2, 3, 400)
	expect(not first.is_empty() and not second.is_empty() and first.cabin_id != second.cabin_id, "Concurrent bookings reserve different reachable cabins")
	expect(not registry.reserve(3, first.cabin_id, 1, 200), "A third party cannot reserve an occupied cabin")
	var bad := registry.capture()
	bad.reservations[0].party_id = 1.5
	var before := registry.capture()
	expect(not registry.restore(bad) and registry.capture() == before, "Fractional booking identities are rejected transactionally")
	registry.release(1)
	expect(registry.reserve(3, first.cabin_id, 1, 200), "A checked-out cabin can be reserved by a new party")

func _population_checks(map: ResortLayout, library: ResortAssets) -> void:
	var simulation := make_sim(map, library)
	expect(simulation.people.size() == 2 and simulation.people[0].profile.name == "Maya" and simulation.people[1].profile.name == "Leo", "The first shared booking preserves Maya and Leo")
	expect(simulation.people[0].motion.position != simulation.people[1].motion.position, "New companions have distinct visible arrival positions")
	simulation.advance(0.1)
	expect(simulation.parties[0].cabin_id > 0 and simulation.parties[0].budget == 480, "Reserving a shared cabin does not charge before check-in")
	simulation.advance(90)
	expect(simulation.parties[0].paid_nights == 1 and simulation.parties[0].room_spent == 60, "Two people share one first-night cabin charge")
	var max_people: int = simulation._active_count()
	var max_bookings := 0
	var unique := true
	var conserved := true
	var reserves := true
	var separated := false
	var varied_nights := {}
	var profile_names := {}
	for tick in 4000:
		simulation.advance(0.25)
		max_people = maxi(max_people, simulation._active_count())
		max_bookings = maxi(max_bookings, simulation.bookings.reservations.size())
		var rooms := {}
		for group in simulation.parties:
			varied_nights[int(group.nights)] = true
			conserved = conserved and group.budget + group.room_spent + group.activity_spent == group.initial_budget and group.room_spent == group.paid_nights * group.rate
			if group.state not in ["waiting_room", "departing", "departed"]:
				reserves = reserves and group.budget >= simulation.reserve(group)
			if group.cabin_id > 0:
				unique = unique and not rooms.has(group.cabin_id)
				rooms[group.cabin_id] = true
		for guest in simulation.people: profile_names[guest.profile.name] = true
		if not simulation.person(1).is_empty() and not simulation.person(2).is_empty():
			separated = separated or simulation.person(1).state != simulation.person(2).state
	expect(max_people <= 12 and max_people >= 6, "Arrivals replenish real customers within the twelve-person proof cap")
	expect(max_bookings == 4 and unique, "All four rooms can be occupied without duplicate bookings")
	expect(conserved and reserves, "Shared room charges and admitted activities conserve every party's money and room reserve")
	expect(separated, "Companions make independent journeys and can split activities")
	expect(varied_nights.size() == 3 and profile_names.size() > 4, "Replenishing bookings vary profiles and one-to-three-night stays")
	expect(simulation.people.size() <= 36, "Departed population records remain bounded")
	var events: Array = simulation.drain_events()
	var ids := {}
	var duplicate := false
	var room_income := 0
	var activity_income := 0
	for event in events:
		duplicate = duplicate or ids.has(event.id)
		ids[event.id] = true
		if event.kind == "room": room_income += event.amount
		else: activity_income += event.amount
	expect(not duplicate and room_income == simulation.total_room_income and activity_income == simulation.total_activity_income, "Undelivered financial events reconcile exactly and have unique IDs")
	expect(simulation.drain_events().is_empty(), "Draining events delivers them once")
	var restored := make_sim(map, library)
	expect(restored.restore(_json(simulation.capture())), "Long-running population, bounded history and RNG restore through JSON")

func _single_cabin(facing: int) -> ResortLayout:
	var map := ResortLayout.new()
	map.seed_default()
	var kept := false
	for record in map.objects.duplicate():
		if record.kind != "cabin": continue
		if kept: map.remove_object(record.id)
		else:
			record.orientation = facing
			kept = true
	map.revision += 1
	return map

func _lifecycle_checks(library: ResortAssets) -> void:
	for facing in 2:
		for nights in range(1, 4):
			var map := _single_cabin(facing)
			var simulation := make_sim(map, library)
			simulation.arrivals_enabled = false
			simulation.parties[0].nights = nights
			var states := {}
			var reservation_released_early := false
			var reunion := false
			for tick in 3000:
				simulation.advance(0.25)
				var group: Dictionary = simulation.parties[0]
				for guest in simulation.people: states[guest.state] = true
				if group.state == "reuniting": reunion = true
				if group.cabin_id < 0:
					for guest in simulation.people:
						reservation_released_early = reservation_released_early or guest.state not in ["departing", "departed"]
				if group.state == "departed": break
			var finished: Dictionary = simulation.parties[0]
			expect(finished.state == "departed" and finished.paid_nights == nights and finished.room_spent == nights * 60, "Facing %d, %d nights: full stay has exactly one shared charge per night" % [facing, nights])
			expect(reunion and not reservation_released_early and finished.cabin_id == -1 and simulation.bookings.reservations.is_empty(), "Facing %d, %d nights: reunion precedes checkout and release waits for both people" % [facing, nights])
			for state in ["to_cabin", "entering", "sleeping", "exiting", "returning", "departing", "departed"]:
				expect(states.has(state), "Facing %d, %d nights includes actual %s motion" % [facing, nights, state])

func _resume_checks(map: ResortLayout, library: ResortAssets) -> void:
	var simulation := make_sim(map, library)
	var phases := {}
	for tick in 2200:
		simulation.advance(0.25)
		for guest in simulation.people:
			if phases.has(guest.state): continue
			phases[guest.state] = true
			var live: Dictionary = simulation.capture()
			var resumed := make_sim(map, library)
			var control := make_sim(map, library)
			var restored: bool = resumed.restore(_json(live))
			expect(restored and control.restore(live), "Mid-%s population/routes/reservations restore transactionally" % guest.state)
			if restored:
				resumed.advance(18.4)
				control.advance(18.4)
				expect(_equivalent(resumed.capture(), control.capture()), "Mid-%s JSON resume matches uninterrupted routes, RNG, needs, money and events" % guest.state)
	for state in ["to_cabin", "entering", "sleeping", "exiting", "to_facility", "approaching_activity", "lying", "waiting_partner", "sitting", "eating", "strolling", "returning", "departing", "departed"]:
		expect(phases.has(state), "Resume scenarios exercise " + state)
	var small := make_sim(map, library, 8147)
	var fast := make_sim(map, library, 8147)
	for tick in 18000: small.advance(1.0 / 60.0)
	for tick in 750: fast.advance(0.4)
	expect(_equivalent(small.capture(), fast.capture()), "60fps and 4x advances use the same fixed clock, decisions, routes, reservations and RNG")
	var before: Dictionary = fast.capture()
	fast.advance(0)
	fast.advance(-1)
	fast.advance(NAN)
	expect(_equivalent(before, fast.capture()), "Pause and invalid deltas do not advance any simulation clock")

func _invalid_checks(map: ResortLayout, library: ResortAssets) -> void:
	var simulation := make_sim(map, library)
	simulation.advance(30)
	var original: Dictionary = simulation.capture()
	var mutations: Array[Dictionary] = []
	var bad := _json(original)
	bad.people[0].id = 1.5
	mutations.append(bad)
	bad = _json(original)
	bad.parties[0].budget += 1
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].motion.route = []
	bad.people[0].motion.index = 0
	bad.people[0].state = "returning"
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].motion.position = [999, 999]
	mutations.append(bad)
	bad = _json(original)
	bad.parties[0].member_ids[0] = 9999
	mutations.append(bad)
	bad = _json(original)
	bad.bookings.reservations.append(bad.bookings.reservations[0].duplicate())
	mutations.append(bad)
	bad = _json(original)
	bad.rng_state = "92233720368547758080000"
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].warning_elapsed = NAN
	mutations.append(bad)
	bad = _json(original)
	bad.total_room_income += 60
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].unhappy_elapsed = 18.5
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].mood_reason = []
	mutations.append(bad)
	bad = _json(original)
	bad.pending_events[0].amount += 1
	mutations.append(bad)
	bad = _json(original)
	bad.people[0].motion.index = NAN
	mutations.append(bad)
	for index in mutations.size():
		expect(not simulation.restore(mutations[index]) and _equivalent(simulation.capture(), original), "Corrupt snapshot %d cannot replace any live state" % index)
	var candidate := ResortLayout.new()
	candidate.seed_default()
	var cabin_id: int = simulation.parties[0].cabin_id
	expect(simulation.protects(cabin_id), "Every reserved cabin is protected")
	candidate.find_object(cabin_id).orientation = 1 - int(candidate.find_object(cabin_id).orientation)
	expect(not simulation.access_survives(candidate), "A proposed occupied cabin rotation is blocked")
	candidate.seed_default()
	var route_simulation := make_sim(map, library)
	route_simulation.advance(0.1)
	var guest: Dictionary = route_simulation.people[0]
	var cell := Vector2i((guest.motion as GuestMotion).position.round())
	candidate.paths.erase(cell)
	candidate.revision += 1
	expect(not route_simulation.access_survives(candidate), "Removing the current route under a guest is blocked")

func _no_room_checks(library: ResortAssets) -> void:
	var map := ResortLayout.new()
	map.seed_default()
	for record in map.objects.duplicate():
		if record.kind == "cabin": map.remove_object(record.id)
	var simulation := make_sim(map, library)
	simulation.arrivals_enabled = false
	simulation.advance(5)
	expect(simulation.people[0].state == "waiting_room" and simulation.people[0].motion.position != simulation.people[1].motion.position and simulation.parties[0].budget == 480, "A full/blocked resort has visible distinct waits and no charges")
	var restored := make_sim(map, library)
	expect(restored.restore(_json(simulation.capture())), "Room-wait snapshots preserve profiles and waiting positions")
	simulation.advance(70)
	expect(simulation.parties[0].state == "departed" and not simulation.parties[0].departure_reason.is_empty() and simulation.parties[0].budget == 480, "No room causes a bounded explained departure without spending")
	var recovered := make_sim(map, library)
	recovered.arrivals_enabled = false
	recovered.advance(5)
	expect(map.place("cabin", Vector2(14, 12)).ok, "A connected room can be added during the waiting grace")
	recovered.layout_changed()
	recovered.advance(600)
	expect(recovered.parties[0].state == "departed" and recovered.parties[0].paid_nights == 2, "Guests can book a room added during their wait and complete the stay")

func _admission_checks(library: ResortAssets) -> void:
	var map := ResortLayout.new()
	map.seed_default()
	for record in map.objects.duplicate():
		if record.kind in ["sunbeds", "volleyball"]: map.remove_object(record.id)
	var simulation := make_sim(map, library)
	simulation.arrivals_enabled = false
	while simulation.parties.size() < 4: simulation._create_party(false)
	for guest in simulation.people:
		guest.profile.interests = ["Good food", "Beach walks"]
		guest.needs = {"hunger": 20.0, "rest": 90.0, "enjoyment": 80.0}
	var queued := false
	var unique := true
	var premature := false
	var queue_resumed := false
	for tick in 600:
		simulation.advance(0.25)
		var occupied := {}
		var points := {}
		for ticket in simulation._local_tickets:
			if ticket.status != "queued":
				var key: String = "%d/%d" % [ticket.facility_id, ticket.slot]
				unique = unique and not occupied.has(key)
				occupied[key] = true
			else:
				unique = unique and not points.has(ticket.queue_position) and not simulation._entrance_cells().has(Vector2i(ticket.queue_position))
				points[ticket.queue_position] = true
		for guest in simulation.people:
			if guest.state in ["to_facility", "queueing", "approaching_activity"]: premature = premature or guest.session_paid
			if guest.state == "queueing": queued = true
		if queued and not queue_resumed:
			queue_resumed = true
			var restored := make_sim(map, library)
			var accepted: bool = restored.restore(_json(simulation.capture()))
			expect(accepted, "A real café queue preserves all people, waiting points and physical claims")
			if accepted:
				var control := make_sim(map, library)
				control.restore(simulation.capture())
				control.advance(35)
				restored.advance(35)
				expect(_equivalent(control.capture(), restored.capture()), "Queue resume preserves promotion order, new charges and routes")
	expect(queued and unique and not premature, "Full café has distinct off-entrance queue places, unique seats and no advance admission fees")
	for size in [1, 2]:
		var court_map := _single_cabin(0)
		for record in court_map.objects.duplicate():
			if record.kind in ["sunbeds", "cafe"]: court_map.remove_object(record.id)
		var players := make_sim(court_map, library)
		players.arrivals_enabled = false
		players.parties[0].nights = 1
		if size == 1:
			players.people.remove_at(1)
			players.parties[0].member_ids.remove_at(1)
		for guest in players.people:
			guest.profile.interests = ["Volleyball", "Quiet time"]
			guest.needs = {"hunger": 100.0, "rest": 95.0, "enjoyment": 0.0}
		var played := false
		var waiting := false
		var slots_distinct := true
		var no_early_fee := true
		for tick in 1200:
			players.advance(0.25)
			for guest in players.people:
				if guest.state == "waiting_partner":
					waiting = true
					no_early_fee = no_early_fee and not guest.session_paid
				if guest.state == "volleyball":
					played = true
					if size == 2:
						var one: Dictionary = players.activity_slot(1)
						var two: Dictionary = players.activity_slot(2)
						if not one.is_empty() and not two.is_empty(): slots_distinct = slots_distinct and one.position.distance_to(two.position) > 3.0
		if size == 1:
			expect(waiting and not played and players.parties[0].activity_spent == 0 and players.parties[0].state == "departed", "A lone volleyball arrival has a bounded unpaid wait and completes checkout")
		else:
			expect(played and slots_distinct and no_early_fee and players.parties[0].activity_spent >= 20, "Two court arrivals pay individually only after admission and rally on opposite physical sides")

func _service_checks(library: ResortAssets) -> void:
	var map := _single_cabin(0)
	for record in map.objects.duplicate():
		if record.kind in ["cafe", "sunbeds", "volleyball"]: map.remove_object(record.id)
	var simulation := make_sim(map, library)
	simulation.arrivals_enabled = false
	var clean := CleanlinessProbe.new()
	var service := FacilityProbe.new()
	var ledger := LedgerProbe.new()
	simulation.cleanliness = clean
	simulation.facilities = service
	simulation.ledger = ledger
	simulation.advance(250)
	expect(clean.advances == 7500 and service.advances == 7500, "Attached facilities and cleanliness each advance exactly once per fixed step")
	var income := 0
	for event in ledger.events.values(): income += event.amount
	expect(income == simulation.total_room_income + simulation.total_activity_income and simulation.drain_events().is_empty(), "Attached ledger receives financial events once without a second drain channel")
	var waiting := make_sim(map, library)
	expect(waiting.restore(_json(simulation.capture())), "External session ownership survives a simulation-only snapshot")
	var clock: float = waiting.clock
	waiting.advance(1)
	expect(waiting.clock == clock, "External session snapshots wait for service attachment instead of losing reservations")
	var pending := make_sim(map, library)
	pending.arrivals_enabled = false
	pending.advance(60)
	var snapshot: Dictionary = _json(pending.capture())
	var restored := make_sim(map, library)
	expect(restored.restore(snapshot), "Undelivered income remains valid before ledger attachment")
	var delivery := LedgerProbe.new()
	pending.ledger = delivery
	pending.advance(0)
	restored.ledger = delivery
	restored.advance(0)
	expect(delivery.events.size() == 1 and restored.drain_events().is_empty(), "Restoring undelivered income into an existing idempotent ledger does not duplicate revenue")

func _atomic_admission_checks(library: ResortAssets) -> void:
	var map := _single_cabin(0)
	for record in map.objects.duplicate():
		if record.kind in ["cafe", "sunbeds"]: map.remove_object(record.id)
	var couple := make_sim(map, library)
	couple.arrivals_enabled = false
	couple.parties[0].nights = 1
	couple.parties[0].budget = 70
	couple.parties[0].initial_budget = 70
	for guest in couple.people:
		guest.profile.interests = ["Volleyball", "Quiet time"]
		guest.needs = {"hunger": 100.0, "rest": 95.0, "enjoyment": 0.0}
	var refused := false
	for tick in 1200:
		couple.advance(0.25)
		for guest in couple.people:
			refused = refused or (guest.state == "leaving_activity" and guest.activity == "volleyball" and not guest.session_paid)
	expect(refused and couple.parties[0].activity_spent == 0 and couple.parties[0].budget == 10, "A couple with only one spare court fee cancels both admissions without charging either person")
	map = ResortLayout.new()
	map.seed_default()
	for record in map.objects.duplicate():
		if record.kind in ["cafe", "sunbeds"]: map.remove_object(record.id)
	var separate := make_sim(map, library)
	separate.people.remove_at(1)
	separate.parties[0].member_ids.remove_at(1)
	separate.population_cap = 2
	separate._create_party(false)
	separate.arrivals_enabled = false
	for group in separate.parties:
		group.nights = 1
		group.budget = 80
		group.initial_budget = 80
	for guest in separate.people:
		guest.profile.interests = ["Volleyball", "Quiet time"]
		guest.needs = {"hunger": 100.0, "rest": 95.0, "enjoyment": 0.0}
	var depleted := false
	for tick in 1280:
		separate.advance(0.25)
		var guest: Dictionary = separate.people[1]
		if not depleted and guest.state == "approaching_activity":
			var group: Dictionary = separate.party(guest.party_id)
			group.budget -= 20
			group.initial_budget -= 20
			depleted = true
	expect(depleted and separate.total_activity_income == 0, "Cross-party court admission rechecks both budgets atomically when one loses spending money en route")

func _fractional_queue_checks(library: ResortAssets) -> void:
	var map := ResortLayout.new()
	map.seed_default()
	var simulation := make_sim(map, library)
	simulation.arrivals_enabled = false
	simulation.people.remove_at(1)
	simulation.parties[0].member_ids.remove_at(1)
	simulation.advance(40)
	var guest: Dictionary = simulation.people[0]
	simulation._release_ticket(guest.id)
	var motion: GuestMotion = guest.motion
	motion.position = Vector2(34, 17)
	motion.route.clear()
	motion.index = 0
	motion.delay = 0
	guest.state = "deciding"
	guest.facility_id = -1
	guest.slot = -1
	guest.activity = ""
	guest.session_paid = false
	var service := FractionalQueueProbe.new()
	simulation.facilities = service
	simulation._sessions_external = true
	var cafe: Dictionary = {}
	for record in map.objects:
		if record.kind == "cafe": cafe = record
	expect(simulation._visit(guest, cafe, "meal"), "A reachable fractional queue point accepts a real visit")
	simulation.advance(2)
	expect(guest.state == "queueing" and motion.position.distance_to(service.position) < 0.00001 and motion.route.is_empty(), "A queued guest reaches the exact fractional endpoint and stops rerouting")
	var resumed := make_sim(map, library)
	var restored: bool = resumed.restore(_json(simulation.capture()))
	expect(restored, "Fractional queue endpoints and routes survive snapshot validation")
	if restored:
		var clone := FractionalQueueProbe.new()
		clone.records = service.records.duplicate(true)
		resumed.facilities = clone
		resumed.advance(4)
		simulation.advance(4)
		expect(_equivalent(resumed.capture(), simulation.capture()), "Resumed fractional queues preserve position, distance, timing and no admission charge")

func _external_session_checks(library: ResortAssets) -> void:
	var path := "res://scripts/simulation/facility_sessions.gd"
	if not ResourceLoader.exists(path):
		print("POPULATION_DEPENDENCY: W3 unavailable; external session integration deferred.")
		return
	var module := load(path) as Script
	if module == null or not module.can_instantiate():
		expect(false, "Present W3 session module must compile for external integration")
		return
	var map := ResortLayout.new()
	map.seed_default()
	var simulation := make_sim(map, library)
	var service: RefCounted = module.new()
	service.call("configure", map, library)
	simulation.facilities = service
	var resumed_states := {}
	var used_facility := false
	for tick in 1600:
		simulation.advance(0.25)
		for guest in simulation.people:
			if guest.state in ["eating", "lying", "volleyball"]: used_facility = true
			if guest.state not in ["queueing", "eating", "lying", "volleyball", "waiting_partner", "leaving_activity"] or resumed_states.has(guest.state): continue
			resumed_states[guest.state] = true
			var candidate := make_sim(map, library)
			var second_service: RefCounted = module.new()
			second_service.call("configure", map, library)
			var accepted: bool = candidate.restore(_json(simulation.capture())) and second_service.call("restore", _json(service.call("capture")))
			expect(accepted, "Real W3 service and population both restore during " + guest.state)
			if accepted:
				candidate.facilities = second_service
				var control := make_sim(map, library)
				var control_service: RefCounted = module.new()
				control_service.call("configure", map, library)
				control.restore(simulation.capture())
				control_service.call("restore", service.call("capture"))
				control.facilities = control_service
				candidate.advance(24)
				control.advance(24)
				expect(_equivalent(candidate.capture(), control.capture()) and _equivalent(second_service.call("capture"), control_service.call("capture")), "Real W3 %s resume preserves admission, charges, exits and queues" % guest.state)
	expect(used_facility and simulation._sessions_external and simulation._local_tickets.is_empty(), "Attached W3 owns live facility claims while simulation owns movement and money")
	var legacy := GuestStay.new()
	legacy.party_size = 2
	legacy.configure(map, library)
	for tick in 1000:
		legacy.advance(0.1)
		if legacy.state == "to_cafe": break
	var migrated := make_sim(map, library)
	migrated.arrivals_enabled = false
	expect(migrated.import_legacy(_json(legacy.capture())), "Legacy outdoor facility travel imports with its existing room money")
	var adopted_service: RefCounted = module.new()
	adopted_service.call("configure", map, library)
	migrated.facilities = adopted_service
	migrated.advance(90)
	var service_state: Dictionary = adopted_service.call("capture")
	expect(migrated._sessions_external and migrated._local_tickets.is_empty() and absf(float(service_state.clock) - float(migrated.clock)) < 0.000001, "An imported local visit drains safely into W3 ownership while both services retain the shared clock")

func _partial_exit_checks(library: ResortAssets) -> void:
	var map := _single_cabin(0)
	for record in map.objects.duplicate():
		if record.kind in ["cafe", "sunbeds"]: map.remove_object(record.id)
	var simulation := make_sim(map, library)
	simulation.arrivals_enabled = false
	for guest in simulation.people:
		guest.profile.interests = ["Volleyball", "Quiet time"]
		guest.needs = {"hunger": 100.0, "rest": 95.0, "enjoyment": 0.0}
	var exercised := false
	for tick in 4000:
		simulation.advance(0.05)
		var guest: Dictionary = simulation.people[0]
		var motion: GuestMotion = guest.motion
		if guest.state != "approaching_activity" or motion.index < 2 or motion.index >= guest.approach.size(): continue
		var prior: Vector2 = guest.approach[motion.index - 1]
		if motion.position.distance_to(prior) < 0.12: continue
		exercised = true
		var count: int = motion.index
		var position := motion.position
		simulation._leave_activity(guest, "decide")
		expect(motion.position == position and motion.route.size() == count and motion.route[0].is_equal_approx(prior), "A half-approached guest retreats through the traversed prefix without visiting the unvisited fixture")
		var restored := make_sim(map, library)
		expect(restored.restore(_json(simulation.capture())), "Partial evacuation routes and claim ownership survive JSON")
		break
	expect(exercised, "The partial-exit regression exercises an actual post-avoiding court segment")
	map = ResortLayout.new()
	map.seed_default()
	var waiting := make_sim(map, library)
	var station := FractionalQueueProbe.new()
	station.position = Vector2(38, 20)
	station.request(999, 999, 6, "meal", 0)
	waiting.facilities = station
	waiting._create_party(false)
	var distinct := true
	for guest in waiting.people:
		if guest.id > 2: distinct = distinct and (guest.motion as GuestMotion).position != station.position
	expect(waiting.people.size() > 2 and distinct, "New arrival-room waiting anchors avoid existing live facility stations")

func _default_precision_resume_checks(library: ResortAssets) -> void:
	var map := ResortLayout.new()
	map.seed_default()
	for external in [false, true]:
		var simulation := make_sim(map, library)
		var service: RefCounted
		var module: Script
		if external:
			var path := "res://scripts/simulation/facility_sessions.gd"
			if not ResourceLoader.exists(path): continue
			module = load(path)
			service = module.new()
			service.call("configure", map, library)
			simulation.facilities = service
		simulation.advance(240)
		var resumed := make_sim(map, library)
		expect(resumed.restore(JSON.parse_string(JSON.stringify(simulation.capture()))), "Default-precision JSON restores a live population, external=" + str(external))
		if external:
			var restored_service: RefCounted = module.new()
			restored_service.call("configure", map, library)
			expect(restored_service.call("restore", JSON.parse_string(JSON.stringify(service.call("capture")))), "Default-precision JSON restores actual W3 claims")
			resumed.facilities = restored_service
		simulation.advance(40)
		for frame in 1200: resumed.advance(1.0 / 30.0)
		for guest in simulation.people:
			var other: Dictionary = resumed.person(guest.id)
			expect(not other.is_empty() and guest.state == other.get("state") and (guest.motion as GuestMotion).position.distance_to((other.motion as GuestMotion).position) < 0.001, "Default JSON continuation preserves person %d with external=%s: %s vs %s" % [guest.id, external, (guest.motion as GuestMotion).position, (other.motion as GuestMotion).position])

func _legacy_checks(library: ResortAssets) -> void:
	for facing in 2:
		for size in [1, 2]:
			var map := _single_cabin(facing)
			var old := GuestStay.new()
			old.party_size = size
			old.configure(map, library)
			var phases := {}
			for tick in 7000:
				old.advance(0.1)
				if not phases.has(old.state):
					phases[old.state] = true
					var simulation := make_sim(map, library)
					simulation.arrivals_enabled = false
					var imported: bool = simulation.import_legacy(_json(old.capture()))
					expect(imported, "Legacy facing %d size %d imports %s" % [facing, size, old.state])
					if imported:
						var group: Dictionary = simulation.parties[0]
						expect(group.budget == old.budget and group.room_spent == old.accommodation_spent and group.activity_spent == old.activity_spent and group.paid_nights == old.paid_nights and group.next_night == old.next_night and group.cabin_id == old.cabin_id, "Legacy %s preserves exact shared money, paid nights, reservation and deadline" % old.state)
						expect(simulation.people[0].motion.position.distance_to(old.logical_position) < 0.00001 and absf(simulation.people[0].motion.distance - old.walked_distance) < 0.00001 and simulation.people.size() == size, "Legacy %s preserves primary position and distance and all members" % old.state)
						expect(simulation.drain_events().is_empty(), "Legacy %s emits no historical financial events" % old.state)
						simulation.advance(12)
						expect(group.budget <= old.budget and group.budget + group.room_spent + group.activity_spent == group.initial_budget, "Legacy %s continues without refunding or duplicating money" % old.state)
				if old.state == "departed": break
			if size == 1:
				var version_one := old.capture()
				version_one.version = 1
				for key in ["party_size", "companion", "activity_elapsed"]: version_one.erase(key)
				expect(make_sim(map, library).import_legacy(_json(version_one)), "Version-one solo stay remains importable")

func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data, "", true, true))

func _equivalent(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 0.00001
	if a is Vector2 and b is Vector2: return a.distance_to(b) < 0.00001
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _equivalent(a[index], b[index]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]): return false
		return true
	return a == b
