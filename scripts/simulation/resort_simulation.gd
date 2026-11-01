class_name ResortSimulation
extends RefCounted
## Sole population, clock and guest-money owner. The renderer reads GuestMotion
## and activity_slot(); no screen coordinates or player-file writes live here.

const Bookings = preload("res://scripts/simulation/booking_registry.gd")
const DAY_SECONDS := 180.0
const STEP := 1.0 / 30.0
const TIME_EPSILON := 0.000001
const MAX_STEPS_PER_ADVANCE := 36000
const POPULATION_CAP := 12
const DEPARTED_LIMIT := 24
const REUNION_LEAD := 65.0
const ROOM_WAIT := 32.0
const STATES := ["arriving", "waiting_room", "to_cabin", "entering", "sleeping", "exiting", "deciding", "to_facility", "queueing", "approaching_activity", "sitting", "eating", "lying", "volleyball", "leaving_activity", "strolling", "waiting_partner", "returning", "departing", "departed"]
const FACILITY_STATES := ["to_facility", "queueing", "approaching_activity", "sitting", "eating", "lying", "volleyball", "waiting_partner", "leaving_activity"]
const IN_FACILITY := ["approaching_activity", "sitting", "eating", "lying", "volleyball", "waiting_partner", "leaving_activity"]
const INTERIOR_STATES := ["entering", "sleeping", "exiting"]
const TRAVEL_STATES := ["to_cabin", "entering", "exiting", "to_facility", "approaching_activity", "leaving_activity", "returning", "departing"]
const ACTIVITIES := ["", "meal", "sunbathe", "volleyball", "rest", "stroll"]
const PRICES := {"meal": 12, "sunbathe": 8, "volleyball": 10}
const KINDS := {"meal": "cafe", "sunbathe": "sunbeds", "volleyball": "volleyball"}
const POSES := {"meal": "eating", "sunbathe": "lying", "volleyball": "volleyball"}

var layout: ResortLayout
var assets: ResortAssets
var clock := 0.0
var people: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var facilities: RefCounted
var cleanliness: RefCounted
var ledger: RefCounted
var bookings := Bookings.new()
var population_cap := POPULATION_CAP
var arrivals_enabled := true
var total_room_income := 0
var total_activity_income := 0
var _retired_room_income := 0
var _retired_activity_income := 0

var _rng := RandomNumberGenerator.new()
var _seed_value := 8147
var _ticks := 0
var _clock_origin := 0.0
var _pending_time := 0.0
var _next_person_id := 1
var _next_party_id := 1
var _next_arrival := 22.0
var _event_sequence := 0
var _pending_events: Array[Dictionary] = []
var _local_tickets: Array[Dictionary] = []
var _sessions_external := false
var _brain: Script
var _profiles: Script
var _party_coordinator: Script
var _graph: AStarGrid2D
var _graph_revision := -1

func configure(map: ResortLayout, library: ResortAssets, seed_value: int = 8147) -> void:
	layout = map
	assets = library
	facilities = null
	cleanliness = null
	ledger = null
	clock = 0.0
	_ticks = 0
	_clock_origin = 0.0
	_pending_time = 0.0
	_seed_value = seed_value
	_rng.seed = seed_value
	people.clear()
	parties.clear()
	_local_tickets.clear()
	_pending_events.clear()
	_next_person_id = 1
	_next_party_id = 1
	_next_arrival = 22.0
	_event_sequence = 0
	total_room_income = 0
	total_activity_income = 0
	_retired_room_income = 0
	_retired_activity_income = 0
	population_cap = POPULATION_CAP
	arrivals_enabled = true
	_sessions_external = false
	_graph_revision = -1
	bookings.configure(map)
	_load_optional_scripts()
	_create_party(true)

func _load_optional_scripts() -> void:
	# Other workers own these files. Missing modules never prevent this class
	# from parsing or the lodging/navigation base from running.
	_brain = null
	_profiles = null
	_party_coordinator = null
	for item in [["_brain", "guest_brain"], ["_profiles", "guest_profiles"], ["_party_coordinator", "party_coordinator"]]:
		var path: String = "res://scripts/simulation/%s.gd" % item[1]
		if ResourceLoader.exists(path): set(item[0], load(path))

func advance(delta: float) -> void:
	if layout == null or not is_finite(delta) or delta < 0.0: return
	# Restored external tickets must be attached before time can move. Their
	# snapshot is owned by the envelope, not reconstructed from guest positions.
	if _sessions_external and facilities == null: return
	_adopt_external_tickets()
	if facilities != null and _local_tickets.is_empty(): _sessions_external = true
	_pending_time += delta
	var steps := mini(int(floor((_pending_time + 0.00000001) / STEP)), MAX_STEPS_PER_ADVANCE)
	_pending_time = maxf(0.0, _pending_time - steps * STEP)
	for index in steps:
		_ticks += 1
		clock = _clock_origin + _ticks * STEP
		_tick()
	_flush_events()

func _tick() -> void:
	if arrivals_enabled and _time_reached(_next_arrival):
		if _active_count() < population_cap: _create_party(false)
		_next_arrival = clock + _rng.randf_range(20.0, 29.0)
	if not _sessions_external and facilities != null and _local_tickets.is_empty(): _sessions_external = true
	if facilities != null: facilities.call("advance", STEP, clock, people)
	if not _sessions_external: _advance_local_sessions()
	if cleanliness != null: cleanliness.call("advance", STEP, clock)
	for group in parties:
		_advance_party(group)
	for guest in people:
		_advance_person(guest)
	# Arrival and reunion can complete on either member's movement this tick.
	for group in parties:
		_finish_party_transitions(group)
	if ledger != null and cleanliness != null and cleanliness.has_method("drain_events"):
		var wages: Array = cleanliness.call("drain_events")
		for event in wages: _pending_events.append(event.duplicate(true))
	_flush_events()
	_prune_departed()

func person(id: int) -> Dictionary:
	for guest in people:
		if guest.id == id: return guest
	return {}

func party(id: int) -> Dictionary:
	for group in parties:
		if group.id == id: return group
	return {}

func _active_count() -> int:
	var count := 0
	for guest in people:
		if guest.state != "departed": count += 1
	return count

func _create_party(first: bool) -> void:
	var space := population_cap - _active_count()
	if space < 1: return
	var definition: Dictionary
	if first:
		definition = {"nights": 2, "budget": 480, "members": [
			_profile("Maya", "female", ["sunbathe", "meal"], 72.0, 65.0, 57.0),
			_profile("Leo", "male", ["volleyball", "stroll"], 84.0, 68.0, 42.0)]}
	elif _profiles != null:
		definition = _profiles.call("create_party", _rng, _next_party_id, 1 if space == 1 else 0)
	else:
		var size := 2 if space > 1 and _rng.randf() < 0.6 else 1
		var members: Array[Dictionary] = []
		for role in size:
			var variant := "female" if _rng.randi_range(0, 1) == 0 else "male"
			var names := ["Asha", "Nora", "Iris", "Zara"] if variant == "female" else ["Eli", "Omar", "Finn", "Arlo"]
			members.append(_profile(names[_rng.randi_range(0, 3)], variant, ["meal", "sunbathe" if role == 0 else "volleyball"], _rng.randf_range(40, 85), _rng.randf_range(45, 80), _rng.randf_range(35, 80)))
		var nights := _rng.randi_range(1, 3)
		definition = {"nights": nights, "budget": nights * Bookings.NIGHTLY_RATE + _rng.randi_range(65, 140) * size, "members": members}
	if not _valid_definition(definition) or definition.members.size() > space: return
	var group := {"id": _next_party_id, "member_ids": [], "nights": int(definition.nights), "initial_budget": int(definition.budget), "budget": int(definition.budget), "cabin_id": -1,
		"paid_nights": 0, "room_spent": 0, "activity_spent": 0, "created_at": clock, "next_night": 0.0, "state": "waiting_room", "history": [],
		"rate": Bookings.NIGHTLY_RATE, "departure_reason": "", "checkout_requested": false, "receipts": [], "legacy": false}
	_next_party_id += 1
	for role in definition.members.size():
		var motion := GuestMotion.new()
		motion.position = _waiting_point(_next_person_id)
		var guest := _new_person(_next_person_id, group.id, role, definition.members[role], motion)
		people.append(guest)
		group.member_ids.append(_next_person_id)
		_next_person_id += 1
	parties.append(group)
	_history(group, "Arrived for %d night%s with $%d shared room-and-activity money." % [group.nights, "" if group.nights == 1 else "s", group.budget])

func _profile(name_value: String, variant: String, interests: Array, hunger: float, rest: float, enjoyment: float) -> Dictionary:
	return {"name": name_value, "variant": variant, "interests": interests, "initial_needs": {"hunger": hunger, "rest": rest, "enjoyment": enjoyment}}

func _new_person(id: int, party_id: int, role: int, profile: Dictionary, motion: GuestMotion) -> Dictionary:
	return {"id": id, "party_id": party_id, "role": role, "profile": profile.duplicate(true), "motion": motion, "state": "arriving", "needs": profile.initial_needs.duplicate(true),
		"mood": 78.0, "warning_elapsed": 0.0, "unhappy_elapsed": 0.0, "mood_reason": "Feeling comfortable.", "want_leave": false, "reason": "Looking for an affordable connected cabin.", "history": [],
		"activity": "", "facility_id": -1, "slot": -1, "activity_elapsed": 0.0, "timer": 0.0, "session_paid": false,
		"visit_sequence": 0, "visit_notified": false, "approach": [], "after_exit": "decide", "after_activity": "decide", "sleep_until": 0.0,
		"queue_started": 0.0, "return_requested": false, "decision_cooldown": 0.0, "last_activity": "", "last_facility_id": -1, "departed_at": 0.0, "exit_prefix": 0}

func _advance_party(group: Dictionary) -> void:
	if group.state == "departed": return
	if group.state == "waiting_room":
		if _time_reached(float(group.created_at) + ROOM_WAIT):
			_start_unbooked_departure(group)
		elif _ticks % 60 == 1 or _members(group)[0].state == "arriving":
			_try_book(group)
		return
	if group.state == "active":
		for guest in _members(group):
			if guest.want_leave:
				_request_reunion(group, true, guest.reason)
				return
		if _time_reached(float(group.next_night) - REUNION_LEAD):
			_request_reunion(group, false, "Reuniting at the cabin before checkout." if group.paid_nights >= group.nights else "Reuniting at the cabin before the next night.")

func _try_book(group: Dictionary) -> void:
	var booking: Dictionary = bookings.choose(group.id, group.nights, group.budget)
	if booking.is_empty():
		for guest in _members(group):
			guest.state = "waiting_room"
			guest.reason = "Waiting for an affordable unreserved cabin with a connected entrance."
		return
	group.cabin_id = booking.cabin_id
	group.rate = booking.rate
	group.state = "reserved"
	_history(group, "Reserved Cabin %d at $%d per cabin per night." % [group.cabin_id, group.rate])
	var door := _door(layout.find_object(group.cabin_id))
	for guest in _members(group):
		guest.state = "to_cabin"
		guest.activity = "rest"
		guest.reason = "Walking to the party's reserved cabin."
		_set_outdoor(guest, door)

func _finish_party_transitions(group: Dictionary) -> void:
	var members := _members(group)
	if members.is_empty() or group.state == "departed": return
	if group.state == "reserved" and _all_state(members, ["sleeping"]):
		if not _charge_night(group):
			_request_reunion(group, true, "Could not afford the first night.")
			return
		group.next_night = clock + DAY_SECONDS
		group.state = "active"
		for guest in members:
			guest.sleep_until = clock + 8.0
			guest.reason = "Settling into the cabin before choosing an activity."
	if group.state == "reuniting" and _all_state(members, ["sleeping"]):
		if group.checkout_requested or _time_reached(group.next_night):
			if group.checkout_requested or group.paid_nights >= group.nights:
				if group.departure_reason.is_empty(): group.departure_reason = "Completed a %d-night resort break." % group.nights
				group.state = "checkout"
				for guest in members: _exit_cabin(guest, "depart")
			elif _charge_night(group):
				group.next_night += DAY_SECONDS
				group.state = "active"
				for guest in members:
					guest.return_requested = false
					guest.sleep_until = clock + 8.0
					guest.reason = "The next shared cabin night is paid; resting before another day."
			else:
				group.checkout_requested = true
				group.departure_reason = "Could not afford another night."
	if group.state == "checkout" and _all_state(members, ["departing", "departed"]):
		bookings.release(group.id)
		group.cabin_id = -1
		group.state = "departing"
		_history(group, "Both guests checked out; the cabin reservation is released." if members.size() == 2 else "Checked out; the cabin reservation is released.")
	if group.state == "departing" and _all_state(members, ["departed"]):
		group.state = "departed"

func _members(group: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in group.member_ids:
		var guest := person(id)
		if not guest.is_empty(): result.append(guest)
	return result

func _all_state(members: Array[Dictionary], states: Array) -> bool:
	for guest in members:
		if guest.state not in states: return false
	return true

func reserve(group: Dictionary) -> int:
	return maxi(0, int(group.nights) - int(group.paid_nights)) * int(group.rate)

func _charge_night(group: Dictionary) -> bool:
	if group.paid_nights >= group.nights or group.budget < group.rate: return false
	group.budget -= group.rate
	group.room_spent += group.rate
	group.paid_nights += 1
	total_room_income += group.rate
	_emit({"id": "resort:room:%d:%d" % [group.id, group.paid_nights], "kind": "room", "amount": group.rate, "time": clock, "party_id": group.id})
	_history(group, "Paid $%d for night %d of %d, once for the shared cabin." % [group.rate, group.paid_nights, group.nights])
	return true

func _request_reunion(group: Dictionary, checkout: bool, reason: String) -> void:
	group.state = "reuniting"
	group.checkout_requested = checkout
	if checkout: group.departure_reason = reason
	_history(group, reason)
	for guest in _members(group):
		guest.return_requested = true
		guest.reason = reason
		if guest.state == "sleeping" or guest.state in ["entering", "returning", "to_cabin"]: continue
		if guest.state == "exiting":
			guest.after_exit = "home"
		elif guest.state == "approaching_activity":
			_leave_activity(guest, "home")
		elif guest.state == "leaving_activity":
			guest.after_activity = "home"
		elif guest.state in ["sitting", "eating", "lying", "volleyball", "waiting_partner"]:
			_leave_activity(guest, "home")
		else:
			_release_ticket(guest.id)
			guest.facility_id = -1
			guest.slot = -1
			_go_home(guest)

func _start_unbooked_departure(group: Dictionary) -> void:
	group.state = "departing"
	group.departure_reason = "No affordable connected cabin became available during the wait."
	_history(group, group.departure_reason)
	for guest in _members(group):
		guest.state = "departing"
		guest.reason = group.departure_reason
		_set_outdoor(guest, ResortLayout.ARRIVAL)

func _advance_person(guest: Dictionary) -> void:
	var motion: GuestMotion = guest.motion
	motion.moving = false
	if guest.state == "departed": return
	guest.activity_elapsed += STEP
	guest.decision_cooldown = maxf(0, float(guest.decision_cooldown) - STEP)
	var score := 100.0
	if cleanliness != null: score = float(cleanliness.call("score_at", motion.position))
	if _brain != null:
		_brain.call("advance", guest, STEP, score)
	else:
		_fallback_needs(guest, score)
	if guest.state in ["arriving", "waiting_room"]: return
	if guest.state in FACILITY_STATES and guest.state != "leaving_activity":
		var ticket := _ticket(guest.id)
		if ticket.is_empty() or ticket.get("status") == "expired":
			guest["failed_facility_id"] = guest.facility_id
			guest["facility_retry_at"] = clock + 55.0
			guest.reason = str(ticket.get("reason", "The facility reservation ended; choosing another activity."))
			if guest.state in IN_FACILITY: _leave_activity(guest, "home" if guest.return_requested else "decide")
			else: _cancel_visit(guest, "The facility reservation expired; choosing another activity.")
	if not motion.route.is_empty():
		motion.advance(STEP)
		if motion.finished(): _arrived(guest)
		return
	guest.timer = maxf(0.0, float(guest.timer) - STEP)
	if guest.timer < TIME_EPSILON: guest.timer = 0.0
	match guest.state:
		"sleeping":
			var group := party(guest.party_id)
			if group.state == "active" and _time_reached(guest.sleep_until): _exit_cabin(guest, "decide")
		"deciding":
			if guest.timer <= 0: _decide(guest)
		"queueing": _advance_queue(guest)
		"waiting_partner":
			if _ready(guest.id): _start_activity(guest)
			if guest.state == "waiting_partner" and guest.timer <= 0 and not _sessions_external:
				guest["failed_facility_id"] = guest.facility_id
				guest["facility_retry_at"] = clock + 70.0
				guest.reason = "No second player arrived; leaving the court without a charge."
				_leave_activity(guest, "decide")
		"sitting":
			if guest.timer <= 0:
				guest.state = "eating"
				guest.timer = 12.0
				guest.activity_elapsed = 0.0
				guest.reason = "Eating at the café."
		"eating", "lying", "volleyball":
			if guest.timer <= 0: _leave_activity(guest, "decide")
		"strolling":
			if guest.timer <= 0: _decision_state(guest)

func _arrived(guest: Dictionary) -> void:
	var motion: GuestMotion = guest.motion
	motion.route.clear()
	motion.index = 0
	motion.delay = 0.0
	guest.activity_elapsed = 0.0
	match guest.state:
		"to_cabin", "returning": _enter_cabin(guest)
		"entering":
			guest.state = "sleeping"
			guest.activity = "rest"
			guest.sleep_until = clock + 14.0
			guest.reason = "Resting in the cabin." if not guest.return_requested else "Together at the cabin, waiting for the next night or checkout."
		"exiting":
			match guest.after_exit:
				"depart":
					guest.state = "departing"
					guest.activity = ""
					guest.reason = party(guest.party_id).departure_reason
					_set_outdoor(guest, ResortLayout.ARRIVAL)
				"home": _go_home(guest)
				_: _decision_state(guest)
		"to_facility":
			var ticket := _ticket(guest.id)
			if ticket.get("status") == "queued":
				guest.state = "queueing"
				guest.queue_started = clock
				guest.reason = "Waiting in the facility's visible queue."
			else:
				var door := _door(layout.find_object(guest.facility_id))
				if not motion.position.is_equal_approx(Vector2(door)): _set_outdoor(guest, door)
				else: _approach_activity(guest)
		"approaching_activity":
			if guest.return_requested:
				_leave_activity(guest, "home")
			elif _confirm_arrival(guest.id):
				if _ready(guest.id): _start_activity(guest)
				else:
					guest.state = "waiting_partner"
					guest.timer = 22.0
					guest.reason = "Waiting at the court for a second player; no charge yet."
			else: _leave_activity(guest, "decide")
		"leaving_activity":
			_release_ticket(guest.id)
			guest.last_activity = guest.activity
			guest.last_facility_id = guest.facility_id
			guest.facility_id = -1
			guest.slot = -1
			guest.session_paid = false
			guest.approach = []
			if guest.after_activity == "home" or guest.return_requested: _go_home(guest)
			else: _decision_state(guest)
		"strolling": guest.timer = 7.0
		"departing":
			guest.state = "departed"
			guest.departed_at = clock
			guest.facility_id = -1
			guest.activity = ""
			_history(guest, "Left the resort. " + guest.reason)

func _enter_cabin(guest: Dictionary) -> void:
	var record := layout.find_object(party(guest.party_id).cabin_id)
	var route := CabinInterior.aisle(record, assets)
	route.append(GuestActivitySlots.slot(record, "sleeping", guest.role, assets).position)
	guest.state = "entering"
	guest.activity = "rest"
	guest.reason = "Entering through the cabin's own doorway and clear aisle."
	_set_route(guest, route)

func _exit_cabin(guest: Dictionary, after: String) -> void:
	var record := layout.find_object(party(guest.party_id).cabin_id)
	var route := CabinInterior.aisle(record, assets)
	route.reverse()
	route.append(Vector2(_door(record)))
	guest.state = "exiting"
	guest.after_exit = after
	guest.reason = "Leaving through the cabin aisle and doorway."
	_set_route(guest, route)

func _go_home(guest: Dictionary) -> void:
	guest.state = "returning"
	guest.activity = "rest"
	guest.facility_id = -1
	guest.slot = -1
	guest.reason = "Returning to the cabin to reunite." if guest.return_requested else "Returning to the cabin for some rest."
	_set_outdoor(guest, _door(layout.find_object(party(guest.party_id).cabin_id)))

func _decision_state(guest: Dictionary) -> void:
	guest.state = "deciding"
	guest.activity = ""
	guest.timer = 0.3
	guest.decision_cooldown = 2.0
	guest.activity_elapsed = 0.0

func _fallback_needs(guest: Dictionary, score: float) -> void:
	guest.needs.hunger = clampf(float(guest.needs.hunger) + STEP * (2.5 if guest.state == "eating" else -0.20), 0, 100)
	guest.needs.rest = clampf(float(guest.needs.rest) + STEP * (2.0 if guest.state == "sleeping" else (0.45 if guest.state == "lying" else -0.09)), 0, 100)
	guest.needs.enjoyment = clampf(float(guest.needs.enjoyment) + STEP * (2.0 if guest.state in ["lying", "volleyball"] else (0.35 if guest.state == "strolling" else -0.10)), 0, 100)
	var target: float = (guest.needs.hunger + guest.needs.rest + guest.needs.enjoyment) / 3.0 - maxf(0, 55 - score) * 0.6
	guest.mood = move_toward(float(guest.mood), clampf(target, 0, 100), STEP * 2.0)
	guest.warning_elapsed = float(guest.warning_elapsed) + STEP if guest.mood < 22 else maxf(0, float(guest.warning_elapsed) - STEP * 3)
	guest.want_leave = guest.warning_elapsed >= 28
	if guest.want_leave: guest.reason = "Prolonged dissatisfaction after a warning; asking the party to check out."

func _decide(guest: Dictionary) -> void:
	var group := party(guest.party_id)
	if group.state == "reuniting" or guest.return_requested:
		_go_home(guest)
		return
	var available := _available(guest)
	var spending_view := group.duplicate()
	spending_view["reserve"] = reserve(group)
	spending_view["booking_rate"] = group.rate
	spending_view["nightly_rate"] = group.rate
	var intent: Dictionary
	if _brain != null:
		var decision_view := guest.duplicate()
		decision_view.activity = guest.last_activity
		intent = _brain.call("choose", decision_view, spending_view, available, clock)
	else:
		intent = _fallback_choice(guest, spending_view, available)
	# Shared leisure is an invitation at a safe decision point. Each partner's
	# urgent needs still get their own choice and their own route.
	var partner := _partner(guest)
	if _party_coordinator != null and not partner.is_empty() and partner.activity in ["sunbathe", "volleyball"] and partner.state in ["to_facility", "queueing", "approaching_activity", "waiting_partner"]:
		var invitation := {"activity": partner.activity, "facility_id": partner.facility_id, "reason": "Joining a partner for some shared leisure."}
		if _party_coordinator.call("should_join", guest, partner, invitation): intent = invitation
	guest.reason = str(intent.get("reason", "Choosing the next activity."))
	var activity: String = str(intent.get("activity", "stroll"))
	if activity == "rest":
		_go_home(guest)
	elif activity in PRICES:
		var record := layout.find_object(int(intent.get("facility_id", -1)))
		if record.get("kind") == KINDS[activity] and _can_spend(guest, PRICES[activity]) and _visit(guest, record, activity):
			_history(guest, guest.reason)
			return
		_stroll(guest, "That visit is unavailable or would spend protected room money; taking a free stroll.")
	else:
		_stroll(guest, guest.reason)

func _partner(guest: Dictionary) -> Dictionary:
	for id in party(guest.party_id).member_ids:
		if id != guest.id: return person(id)
	return {}

func _fallback_choice(guest: Dictionary, group: Dictionary, available: Array[Dictionary]) -> Dictionary:
	if guest.needs.rest < 35: return {"activity": "rest", "facility_id": -1, "reason": "Tired; choosing a rest at the cabin."}
	var wanted := "meal" if guest.needs.hunger < 74 else ("volleyball" if "volleyball" in guest.profile.interests and guest.last_activity != "volleyball" else "sunbathe")
	if guest.last_activity == wanted and guest.needs.enjoyment > 70 and guest.needs.hunger > 65: wanted = "stroll"
	for option in available:
		if option.kind == KINDS.get(wanted) and option.available and group.budget - group.reserve >= option.price:
			return {"activity": wanted, "facility_id": option.id, "reason": "Choosing %s from current needs and interests." % wanted}
	return {"activity": "stroll", "facility_id": -1, "reason": "Enjoying a free beach stroll while keeping room money aside."}

func _available(guest: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	var graph := _navigation()
	var start := Vector2i((guest.motion as GuestMotion).position.round())
	if not _open(graph, start): return available
	for record in layout.objects:
		if record.kind not in KINDS.values(): continue
		var destination := _door(record)
		if not _open(graph, destination): continue
		var path := graph.get_id_path(start, destination)
		if path.is_empty(): continue
		var activity: String = {"cafe": "meal", "sunbeds": "sunbathe", "volleyball": "volleyball"}[record.kind]
		var queued := 0
		var accepts_queue := true
		if _sessions_external and facilities != null:
			var facility_view: Array = facilities.call("inspect")
			for entry in facility_view:
				if entry.get("id", entry.get("facility_id", -1)) == record.id:
					var count: Variant = entry.get("queue", entry.get("queue_count", 0))
					queued = count.size() if count is Array else int(count)
					if entry.get("available") is bool: accepts_queue = entry.available
		else:
			for ticket in _local_tickets:
				if ticket.facility_id == record.id and ticket.status == "queued": queued += 1
		var retry_blocked: bool = guest.get("failed_facility_id", -1) == record.id and not _time_reached(float(guest.get("facility_retry_at", 0)))
		var waiting_players := 0
		if activity=="volleyball":
			for other: Dictionary in people:
				if other.id!=guest.id and other.facility_id==record.id and other.activity=="volleyball" and other.state in ["to_facility","queueing","approaching_activity","waiting_partner"] and not other.return_requested: waiting_players+=1
		available.append({"kind": record.kind, "id": record.id, "price": PRICES[activity], "distance": float(path.size()), "available": accepts_queue and queued < 4 and not retry_blocked, "queue": queued,"waiting_players":waiting_players})
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
	return available

func _can_spend(guest: Dictionary, amount: int) -> bool:
	var group := party(guest.party_id)
	var carefree: bool = guest.profile.get("carefree", false) == true or guest.profile.get("spending_style", "") == "carefree"
	return group.budget >= amount and (carefree or group.budget - reserve(group) >= amount)

func _visit(guest: Dictionary, record: Dictionary, activity: String) -> bool:
	var preferred := 0
	var partner := _partner(guest)
	if not partner.is_empty() and partner.facility_id == record.id: preferred = partner.id
	var ticket := _request_ticket(guest.id, guest.party_id, record.id, activity, preferred)
	if ticket.is_empty() or ticket.get("status") == "expired": return false
	guest.facility_id = record.id
	guest.activity = activity
	guest.slot = int(ticket.get("slot", ticket.get("slot_index", -1)))
	guest.visit_sequence += 1
	guest.session_paid = false
	guest.visit_notified = false
	guest.approach = []
	guest.exit_prefix = 0
	guest.after_activity = "decide"
	guest.state = "to_facility"
	guest.queue_started = clock
	var destination := _queue_position(ticket) if ticket.get("status") == "queued" else Vector2(_door(record))
	if not _set_outdoor_point(guest, destination):
		_release_ticket(guest.id)
		guest.facility_id = -1
		guest.slot = -1
		return false
	return true

func _advance_queue(guest: Dictionary) -> void:
	var ticket := _ticket(guest.id)
	if ticket.get("status") in ["reserved", "active"]:
		guest.slot = int(ticket.get("slot", ticket.get("slot_index", -1)))
		guest.state = "to_facility"
		guest.reason = "A place is free; walking from the queue to the facility entrance."
		_set_outdoor(guest, _door(layout.find_object(guest.facility_id)))
	elif _time_reached(float(guest.queue_started) + 55.0):
		_cancel_visit(guest, "The queue is taking too long; choosing a different activity.")
	else:
		var position := _queue_position(ticket)
		if (guest.motion as GuestMotion).position.distance_to(position) > 0.05: _set_outdoor_point(guest, position)

func _approach_activity(guest: Dictionary) -> void:
	var ticket := _ticket(guest.id)
	guest.slot = int(ticket.get("slot", ticket.get("slot_index", -1)))
	if guest.slot not in [0, 1]:
		_cancel_visit(guest, "No physical place is reserved; choosing another activity.")
		return
	var route: Array[Vector2] = []
	if _sessions_external and facilities != null:
		var points: Array = facilities.call("route", guest.id, false)
		for point in points: route.append(point)
	else:
		route = GuestActivitySlots.approach(layout.find_object(guest.facility_id), POSES[guest.activity], guest.slot, assets)
	if route.is_empty():
		_cancel_visit(guest, "No reachable approach to the reserved place.")
		return
	guest.approach = route.duplicate()
	guest.state = "approaching_activity"
	_set_route(guest, route)

func _start_activity(guest: Dictionary) -> void:
	if guest.session_paid and guest.state in ["sitting", "eating", "lying", "volleyball"]: return
	if guest.activity == "volleyball" and not guest.session_paid:
		_start_volleyball(guest)
		return
	var amount: int = PRICES.get(guest.activity, 0)
	if amount <= 0 or not _ready(guest.id) or (not guest.session_paid and not _can_spend(guest, amount)):
		guest.reason = "Keeping the remaining cabin nights paid for."
		_leave_activity(guest, "decide")
		return
	if not guest.session_paid:
		_charge_activity(guest, amount)
	_activate_activity(guest)

func _charge_activity(guest: Dictionary, amount: int) -> void:
	var group := party(guest.party_id)
	group.budget -= amount
	group.activity_spent += amount
	total_activity_income += amount
	guest.session_paid = true
	var event := {"id": "resort:activity:%d:%d" % [guest.id, guest.visit_sequence], "kind": guest.activity, "amount": amount, "time": clock, "party_id": group.id, "person_id": guest.id}
	group.receipts.append(event.duplicate(true))
	_emit(event)
	_history(guest, "Paid $%d after reaching the reserved %s place." % [amount, guest.activity])

func _start_volleyball(guest: Dictionary) -> void:
	if not _ready(guest.id):
		_wait_for_partner(guest)
		return
	var other := person(int(_ticket(guest.id).get("partner_id", 0)))
	if other.is_empty():
		for candidate in people:
			if candidate.id != guest.id and candidate.facility_id == guest.facility_id and candidate.activity == "volleyball" and candidate.slot != guest.slot and _ready(candidate.id):
				other = candidate
				break
	if other.is_empty() or other.state not in ["waiting_partner", "approaching_activity"] or not _ready(other.id) or not (other.motion as GuestMotion).finished():
		_wait_for_partner(guest)
		return
	var players: Array[Dictionary] = [guest, other]
	var amounts := {}
	var protected := {}
	var affordable: bool = not other.session_paid
	for player in players:
		amounts[int(player.party_id)] = int(amounts.get(int(player.party_id), 0)) + PRICES.volleyball
		var carefree: bool = player.profile.get("carefree", false) == true or player.profile.get("spending_style", "") == "carefree"
		if not carefree: protected[int(player.party_id)] = true
		var slot := GuestActivitySlots.slot(layout.find_object(player.facility_id), "volleyball", player.slot, assets)
		affordable = affordable and (player.motion as GuestMotion).position.distance_to(slot.position) < 0.06
	for id in amounts:
		var group := party(id)
		var spendable: int = int(group.budget) - (reserve(group) if protected.has(id) else 0)
		affordable = affordable and spendable >= int(amounts[id])
	if not affordable:
		for player in players:
			player.reason = "Both players need an affordable admission before a rally can start; no fees were charged."
			player["failed_facility_id"] = player.facility_id
			player["facility_retry_at"] = clock + 70.0
			_leave_activity(player, "home" if player.return_requested else "decide")
		return
	# Validate the complete two-person purchase before mutating either budget.
	for player in players: _charge_activity(player, PRICES.volleyball)
	for player in players: _activate_activity(player)

func _wait_for_partner(guest: Dictionary) -> void:
	if guest.state != "waiting_partner": guest.timer = 22.0
	guest.state = "waiting_partner"
	guest.reason = "Waiting at the court for a second player; no charge yet."

func _activate_activity(guest: Dictionary) -> void:
	guest.activity_elapsed = 0.0
	match guest.activity:
		"meal":
			guest.state = "sitting"
			guest.timer = 3.0
			guest.reason = "Seated while the café prepares a meal."
		"sunbathe":
			guest.state = "lying"
			guest.timer = 18.0
			guest.reason = "Relaxing on a reserved lounger."
		"volleyball":
			guest.state = "volleyball"
			guest.timer = 20.0
			guest.reason = "Rallying with another admitted player on the opposite side of the net."

func _leave_activity(guest: Dictionary, after: String) -> void:
	if guest.state == "leaving_activity":
		guest.after_activity = after
		return
	var was_approaching: bool = guest.state == "approaching_activity"
	var traversed: int = (guest.motion as GuestMotion).index
	var had_route: bool = not (guest.motion as GuestMotion).route.is_empty()
	if guest.session_paid and not guest.visit_notified:
		guest.visit_notified = true
		if cleanliness != null: cleanliness.call("on_activity_finished", guest.id, guest.facility_id, guest.activity, clock)
	guest.after_activity = after
	guest.state = "leaving_activity"
	if not _sessions_external and guest.activity == "volleyball" and guest.session_paid:
		var ticket := _ticket(guest.id)
		var partner := person(int(ticket.get("partner_id", 0)))
		if not partner.is_empty() and partner.state == "volleyball": _leave_activity(partner, "home" if partner.return_requested else "decide")
	var route: Array[Vector2] = []
	for point in guest.approach: route.append(point)
	if route.is_empty() and guest.slot in [0, 1]:
		route = GuestActivitySlots.approach(layout.find_object(guest.facility_id), POSES[guest.activity], guest.slot, assets)
	if was_approaching and had_route: route.resize(clampi(traversed, 1, route.size()))
	guest.exit_prefix = route.size()
	route.reverse()
	_set_route(guest, route)
	if route.is_empty(): _arrived(guest)

func _cancel_visit(guest: Dictionary, reason: String) -> void:
	guest["failed_facility_id"] = guest.facility_id
	guest["facility_retry_at"] = clock + 55.0
	_release_ticket(guest.id)
	guest.facility_id = -1
	guest.slot = -1
	guest.session_paid = false
	guest.approach = []
	(guest.motion as GuestMotion).route.clear()
	(guest.motion as GuestMotion).index = 0
	(guest.motion as GuestMotion).delay = 0
	if guest.return_requested: _go_home(guest)
	else: _stroll(guest, reason)

func _stroll(guest: Dictionary, reason: String) -> void:
	var graph := _navigation()
	var destination := Vector2i(ResortLayout.ARRIVAL)
	var start := Vector2i((guest.motion as GuestMotion).position.round())
	for attempt in 32:
		var candidate := Vector2i(_rng.randi_range(3, 40), _rng.randi_range(21, 36))
		if _open(graph, start) and _open(graph, candidate) and not graph.get_id_path(start, candidate).is_empty():
			destination = candidate
			break
	guest.state = "strolling"
	guest.activity = "stroll"
	guest.reason = reason
	guest.timer = 7.0
	_set_outdoor(guest, destination)

func _set_route(guest: Dictionary, points: Array[Vector2]) -> void:
	var motion: GuestMotion = guest.motion
	motion.set_route(points)
	motion.delay = 0.0

func _set_outdoor(guest: Dictionary, destination: Vector2i) -> bool:
	var graph := _navigation()
	var start := Vector2i((guest.motion as GuestMotion).position.round())
	if not _open(graph, start) or not _open(graph, destination): return false
	var path := graph.get_id_path(start, destination)
	if path.is_empty(): return false
	var points: Array[Vector2] = []
	for cell in path: points.append(Vector2(cell))
	_set_route(guest, points)
	guest["outdoor_target"] = []
	return true

func _set_outdoor_point(guest: Dictionary, destination: Vector2) -> bool:
	if not is_finite(destination.x) or not is_finite(destination.y): return false
	if not _set_outdoor(guest, Vector2i(destination.round())): return false
	var motion: GuestMotion = guest.motion
	if not destination.is_equal_approx(destination.round()): motion.route.append(destination)
	guest["outdoor_target"] = [destination.x, destination.y]
	return true

func _navigation() -> AStarGrid2D:
	if _graph == null or _graph_revision != layout.revision:
		_graph = layout.navigation()
		_graph_revision = layout.revision
	return _graph

func _door(record: Dictionary) -> Vector2i:
	return Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)

func _open(graph: AStarGrid2D, cell: Vector2i) -> bool:
	return graph.is_in_boundsv(cell) and not graph.is_point_solid(cell)

func _entrance_cells() -> Dictionary:
	var cells := {}
	for record in layout.objects:
		if ResortCatalog.definition(record.kind).get("access", false): cells[_door(record)] = true
	return cells

func _waiting_point(identity: int) -> Vector2:
	var graph := _navigation()
	var used := _entrance_cells()
	used.merge(_facility_waiting_cells())
	used[ResortLayout.ARRIVAL] = true # Keep the shared exit clear.
	var waiting_positions: Array[Vector2] = []
	for guest in people:
		if guest.state in ["arriving", "waiting_room"]:
			waiting_positions.append(guest.motion.position)
			used[Vector2i((guest.motion as GuestMotion).position.round())] = true
	# Numbered waiting places along the arrival promenade are actual nav cells.
	for radius in range(0, 12):
		for offset in [Vector2i(-radius, 1), Vector2i(-radius, 0), Vector2i(radius, 1), Vector2i(radius, 0)]:
			var cell: Vector2i = ResortLayout.ARRIVAL + offset
			if used.has(cell) or not _open(graph, cell): continue
			var clear := true
			for position in waiting_positions:
				var gap := (IsometricGrid.project(Vector2(cell)) - IsometricGrid.project(position)).abs()
				if gap.x < 42 and gap.y < 60:
					clear = false
					break
			if clear and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty(): return Vector2(cell)
	# Extremely edited layouts may have fewer waiting cells than the proof cap.
	return Vector2(ResortLayout.ARRIVAL) + Vector2(0, float(identity % 3) * 0.18)

func _facility_waiting_cells() -> Dictionary:
	var used := {}
	for ticket in _local_tickets: used[Vector2i(_queue_position(ticket).round())] = true
	if facilities != null and facilities.has_method("capture"):
		var saved: Dictionary = facilities.call("capture")
		var tickets: Variant = saved.get("tickets", [])
		if tickets is Dictionary: tickets = tickets.values()
		if tickets is Array:
			for ticket in tickets:
				if ticket is Dictionary and (ticket.get("status") != "expired" or ticket.get("claim_held", false)):
					used[Vector2i(_queue_position(ticket).round())] = true
	return used

func activity_slot(person_id: int) -> Dictionary:
	var guest := person(person_id)
	if guest.is_empty(): return {}
	var pose: String = {"sleeping": "sleeping", "sitting": "sitting", "eating": "eating", "lying": "lying", "volleyball": "volleyball"}.get(guest.state, "")
	if pose.is_empty(): return {}
	if pose == "sleeping":
		return GuestActivitySlots.slot(layout.find_object(party(guest.party_id).cabin_id), pose, guest.role, assets)
	if _sessions_external and facilities != null:
		var result: Dictionary = facilities.call("slot", guest.id)
		if not result.is_empty():
			result = result.duplicate()
			result["pose"] = pose
			return result
	return GuestActivitySlots.slot(layout.find_object(guest.facility_id), pose, guest.slot, assets)

func _history(record: Dictionary, message: String) -> void:
	record.history.append(message)
	if record.history.size() > 16: record.history.pop_front()

func _emit(event: Dictionary) -> void:
	_event_sequence += 1
	_pending_events.append(event.duplicate(true))

func _flush_events() -> void:
	if ledger == null: return
	# record() is idempotent; false also means an already-recorded ID. Both
	# outcomes are delivered. The pending list is part of every snapshot.
	for event in _pending_events: ledger.call("record", event)
	_pending_events.clear()

func drain_events() -> Array[Dictionary]:
	var events := _pending_events.duplicate(true)
	_pending_events.clear()
	return events

func _prune_departed() -> void:
	var departed_people := 0
	for guest in people:
		if guest.state == "departed": departed_people += 1
	while departed_people > DEPARTED_LIMIT:
		var found := false
		for index in parties.size():
			var group: Dictionary = parties[index]
			if group.state != "departed": continue
			_retired_room_income += group.room_spent
			_retired_activity_income += group.activity_spent
			for id in group.member_ids:
				for person_index in range(people.size() - 1, -1, -1):
					if people[person_index].id == id:
						people.remove_at(person_index)
						departed_people -= 1
			parties.remove_at(index)
			found = true
			break
		if not found: break

func _request_ticket(person_id: int, party_id: int, facility_id: int, activity: String, preferred: int) -> Dictionary:
	if _sessions_external and facilities != null:
		return facilities.call("request", person_id, party_id, facility_id, activity, clock, preferred)
	var existing := _ticket(person_id)
	if not existing.is_empty(): return existing
	var occupied := {}
	var queued := 0
	for ticket in _local_tickets:
		if ticket.facility_id != facility_id: continue
		if ticket.status == "queued": queued += 1
		elif ticket.slot >= 0: occupied[int(ticket.slot)] = true
	if queued >= 4: return {}
	var index := -1
	if queued == 0:
		for candidate in 2:
			if not occupied.has(candidate):
				index = candidate
				break
	var point := _local_queue_point(layout.find_object(facility_id))
	if not is_finite(point.x): return {}
	var ticket := {"person_id": person_id, "party_id": party_id, "facility_id": facility_id, "activity": activity, "slot": index,
		"status": "reserved" if index >= 0 else "queued", "queue_position": point, "partner_id": preferred,
		"arrived": false, "admitted": false, "requested_at": clock, "reserved_at": clock if index >= 0 else 0.0, "arrived_at": 0.0}
	_local_tickets.append(ticket)
	return ticket

func _adopt_external_tickets() -> void:
	# The legacy envelope may already have reconstructed matching W3 claims.
	# Adopt only a complete, identical set so no claimed furniture is orphaned.
	if _sessions_external or facilities == null or _local_tickets.is_empty(): return
	for ticket in _local_tickets:
		var external: Dictionary = facilities.call("ticket", ticket.person_id)
		if external.get("status") not in ["queued", "reserved", "active"] or external.get("facility_id") != ticket.facility_id or external.get("activity") != ticket.activity or external.get("slot", external.get("slot_index", -1)) != ticket.slot: return
	_local_tickets.clear()
	_sessions_external = true

func _ticket(person_id: int) -> Dictionary:
	if _sessions_external and facilities != null: return facilities.call("ticket", person_id)
	for ticket in _local_tickets:
		if ticket.person_id == person_id: return ticket
	return {}

func _confirm_arrival(person_id: int) -> bool:
	if _sessions_external and facilities != null: return facilities.call("confirm_arrival", person_id, clock)
	var ticket := _ticket(person_id)
	if ticket.is_empty() or ticket.status not in ["reserved", "active"]: return false
	ticket.arrived = true
	ticket.arrived_at = clock
	if ticket.activity != "volleyball":
		ticket.status = "active"
		ticket.admitted = true
	else:
		for other in _local_tickets:
			if other.person_id != person_id and other.facility_id == ticket.facility_id and other.arrived and other.status == "reserved" and person(other.person_id).get("state") in ["waiting_partner", "approaching_activity"]:
				ticket.status = "active"
				ticket.admitted = true
				ticket.partner_id = other.person_id
				other.status = "active"
				other.admitted = true
				other.partner_id = person_id
	return true

func _ready(person_id: int) -> bool:
	if _sessions_external and facilities != null: return facilities.call("ready", person_id)
	var ticket := _ticket(person_id)
	return not ticket.is_empty() and ticket.status == "active" and ticket.admitted and ticket.arrived

func _release_ticket(person_id: int) -> void:
	if _sessions_external and facilities != null:
		facilities.call("release", person_id)
		return
	for index in range(_local_tickets.size() - 1, -1, -1):
		if _local_tickets[index].person_id == person_id: _local_tickets.remove_at(index)

func _advance_local_sessions() -> void:
	for index in range(_local_tickets.size() - 1, -1, -1):
		var ticket: Dictionary = _local_tickets[index]
		if (ticket.status == "queued" and _time_reached(float(ticket.requested_at) + 100.0)) or (ticket.status == "reserved" and not ticket.arrived and _time_reached(float(ticket.reserved_at) + 90.0)):
			_local_tickets.remove_at(index)
	# Insertion order is the persisted FIFO order. A new request cannot jump it.
	for ticket in _local_tickets:
		if ticket.status != "queued": continue
		var occupied := {}
		for other in _local_tickets:
			if other.facility_id == ticket.facility_id and other.status != "queued": occupied[int(other.slot)] = true
		for index in 2:
			if not occupied.has(index):
				ticket.slot = index
				ticket.status = "reserved"
				ticket.reserved_at = clock
				break

func _local_queue_point(record: Dictionary) -> Vector2:
	var graph := _navigation()
	var door := _door(record)
	var used := _entrance_cells()
	used[ResortLayout.ARRIVAL] = true
	for ticket in _local_tickets: used[Vector2i(_queue_position(ticket).round())] = true
	for guest in people:
		if guest.state in ["arriving", "waiting_room"]: used[Vector2i((guest.motion as GuestMotion).position.round())] = true
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dy in [-radius, radius]:
				var cell := door + Vector2i(dx, dy)
				if not used.has(cell) and _open(graph, cell) and not graph.get_id_path(door, cell).is_empty(): return Vector2(cell)
	return Vector2(INF, INF)

func _queue_position(ticket: Dictionary) -> Vector2:
	var point: Variant = ticket.get("queue_position", Vector2(ResortLayout.ARRIVAL))
	if point is Vector2: return point
	if point is Array and point.size() == 2: return Vector2(point[0], point[1])
	return Vector2(ResortLayout.ARRIVAL)

func protects(object_id: int) -> bool:
	if object_id < 1: return false
	if bookings.protects(object_id): return true
	for guest in people:
		if guest.facility_id == object_id and guest.state in FACILITY_STATES: return true
	for ticket in _local_tickets:
		if ticket.facility_id == object_id: return true
	if facilities != null and facilities.has_method("protects") and facilities.call("protects", object_id): return true
	return false

func access_survives(candidate: ResortLayout) -> bool:
	if candidate == null: return false
	for record in layout.objects:
		if not protects(record.id): continue
		var other := candidate.find_object(record.id)
		if other.is_empty() or other.kind != record.kind or other.position != record.position or other.orientation != record.orientation: return false
	var graph := candidate.navigation()
	if not _open(graph, ResortLayout.ARRIVAL): return false
	for guest in people:
		if guest.state == "departed": continue
		var cell := Vector2i((guest.motion as GuestMotion).position.round())
		if guest.state in INTERIOR_STATES:
			var record := candidate.find_object(party(guest.party_id).cabin_id)
			if record.is_empty(): return false
			cell = _door(record)
		elif guest.state in IN_FACILITY:
			var record := candidate.find_object(guest.facility_id)
			if record.is_empty(): return false
			cell = _door(record)
		if not _open(graph, cell) or graph.get_id_path(cell, ResortLayout.ARRIVAL).is_empty(): return false
		if guest.state in ["to_cabin", "returning"]:
			var destination := _door(candidate.find_object(party(guest.party_id).cabin_id))
			if not _open(graph, destination) or graph.get_id_path(cell, destination).is_empty(): return false
		if guest.state in ["to_facility", "queueing"]:
			var ticket := _ticket(guest.id)
			var destination := Vector2i(_queue_position(ticket).round()) if ticket.get("status") == "queued" else _door(candidate.find_object(guest.facility_id))
			if not _open(graph, destination) or graph.get_id_path(cell, destination).is_empty(): return false
	for ticket in _local_tickets:
		var cell := Vector2i(_queue_position(ticket).round())
		if not _open(graph, cell) or graph.get_id_path(cell, ResortLayout.ARRIVAL).is_empty(): return false
	if facilities != null and facilities.has_method("access_survives") and not facilities.call("access_survives", candidate): return false
	if cleanliness != null and not cleanliness.call("access_survives", candidate): return false
	return true

func layout_changed() -> void:
	_graph_revision = -1
	if facilities != null and facilities.has_method("layout_changed"): facilities.call("layout_changed")
	if cleanliness != null: cleanliness.call("layout_changed")
	for guest in people:
		match guest.state:
			"to_cabin", "returning": _set_outdoor(guest, _door(layout.find_object(party(guest.party_id).cabin_id)))
			"to_facility", "queueing":
				var ticket := _ticket(guest.id)
				var destination := _queue_position(ticket) if ticket.get("status") == "queued" else Vector2(_door(layout.find_object(guest.facility_id)))
				_set_outdoor_point(guest, destination)
			"departing": _set_outdoor(guest, ResortLayout.ARRIVAL)
			"strolling":
				var motion: GuestMotion = guest.motion
				if not motion.route.is_empty():
					var destination := Vector2i(motion.route[-1].round())
					if not _set_outdoor(guest, destination): _stroll(guest, "Taking a new route after the layout changed.")

func inspect() -> Dictionary:
	var population: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	for guest in people:
		var group := party(guest.party_id)
		var partner := _partner(guest)
		population.append({"id": guest.id, "party_id": guest.party_id, "name": guest.profile.name, "variant": guest.profile.variant, "state": guest.state,
			"position": (guest.motion as GuestMotion).position, "needs": guest.needs.duplicate(true), "mood": guest.mood, "warning_elapsed": guest.warning_elapsed,
			"reason": guest.reason, "interests": guest.profile.interests.duplicate(), "budget": group.budget, "reserve": reserve(group), "cabin_id": group.cabin_id,
			"nights": group.nights, "paid_nights": group.paid_nights, "history": guest.history.duplicate(), "partner_id": partner.get("id", 0),
			"activity": guest.activity, "facility_id": guest.facility_id, "slot": guest.slot, "want_leave": guest.want_leave,
			"unhappy_elapsed": guest.get("unhappy_elapsed", 0.0), "mood_reason": guest.get("mood_reason", "")})
	for group in parties: groups.append(group.duplicate(true))
	var facility_view: Array = []
	if facilities != null: facility_view = facilities.call("inspect")
	else:
		for record in layout.objects:
			if record.kind not in KINDS.values(): continue
			var occupants: Array = []
			var queue: Array = []
			for ticket in _local_tickets:
				if ticket.facility_id == record.id:
					if ticket.status == "queued": queue.append(ticket.person_id)
					else: occupants.append(ticket.person_id)
			facility_view.append({"id": record.id, "facility_id": record.id, "kind": record.kind, "capacity": 2, "occupants": occupants, "queue": queue})
	var clean: Dictionary = cleanliness.call("inspect") if cleanliness != null else {"mess": [], "staff": [], "cleanliness": 100.0, "hired_count": 0}
	var operations: Dictionary = ledger.call("inspect", clock) if ledger != null else {"room_income": total_room_income, "activity_income": total_activity_income, "income": total_room_income + total_activity_income, "wages": 0, "net": total_room_income + total_activity_income}
	return {"clock": clock, "people": population, "parties": groups, "facilities": facility_view, "cleanliness": clean, "operations": operations, "selected_person_id": 0, "following": false}

func capture() -> Dictionary:
	var residents: Array[Dictionary] = []
	for guest in people:
		var entry := guest.duplicate(true)
		entry["motion"] = (guest.motion as GuestMotion).capture()
		entry.motion["moving"] = (guest.motion as GuestMotion).moving
		entry["approach"] = _encode_points(guest.approach)
		residents.append(entry)
	var tickets: Array[Dictionary] = []
	for ticket in _local_tickets:
		var entry := ticket.duplicate(true)
		var point := _queue_position(ticket)
		entry.queue_position = [point.x, point.y]
		tickets.append(entry)
	# Decimal strings preserve the full signed 64-bit RNG state across JSON.
	return {"version": 1, "clock": clock, "ticks": _ticks, "clock_origin": _clock_origin, "pending_time": _pending_time, "seed": str(_seed_value), "rng_state": str(_rng.state),
		"next_person_id": _next_person_id, "next_party_id": _next_party_id, "next_arrival": _next_arrival, "event_sequence": _event_sequence,
		"population_cap": population_cap, "arrivals_enabled": arrivals_enabled, "people": residents, "parties": parties.duplicate(true),
		"bookings": bookings.capture(), "local_tickets": tickets, "sessions_external": _sessions_external,
		"pending_events": _pending_events.duplicate(true), "total_room_income": total_room_income, "total_activity_income": total_activity_income,
		"retired_room_income": _retired_room_income, "retired_activity_income": _retired_activity_income}

func restore(data: Dictionary) -> bool:
	if layout == null: return false
	var candidate := ResortSimulation.new()
	candidate.layout = layout
	candidate.assets = assets
	candidate.bookings.configure(layout)
	if not candidate._decode_snapshot(data): return false
	# Nothing in the visible controller or attached services changes until all
	# identities, finances, routes and internal reservations have been checked.
	for key in ["clock", "people", "parties", "bookings", "population_cap", "arrivals_enabled", "total_room_income", "total_activity_income",
		"_ticks", "_clock_origin", "_pending_time", "_seed_value", "_next_person_id", "_next_party_id", "_next_arrival", "_event_sequence", "_pending_events", "_local_tickets", "_sessions_external", "_retired_room_income", "_retired_activity_income"]:
		set(key, candidate.get(key))
	_rng.seed = candidate._seed_value
	_rng.state = candidate._rng.state
	_graph_revision = -1
	_load_optional_scripts()
	return true

func _decode_snapshot(data: Dictionary) -> bool:
	if not Bookings.integral(data.get("version"), 1, 1): return false
	for key in ["ticks", "next_person_id", "next_party_id", "event_sequence", "total_room_income", "total_activity_income", "retired_room_income", "retired_activity_income"]:
		if not Bookings.integral(data.get(key), 0, 9007199254740991): return false
	if data.next_person_id < 1 or data.next_party_id < 1: return false
	for key in ["clock", "pending_time", "next_arrival"]:
		if not _number(data.get(key), 0, 1000000000000.0): return false
	if not _number(data.get("clock_origin"), 0, STEP) or absf(data.clock - data.clock_origin - data.ticks * STEP) > 0.000001: return false
	if not Bookings.integral(data.get("population_cap"), 1, POPULATION_CAP): return false
	if not data.get("arrivals_enabled") is bool or not data.get("sessions_external") is bool: return false
	for key in ["seed", "rng_state"]:
		if not _valid_rng_string(data.get(key)): return false
	for key in ["people", "parties", "local_tickets", "pending_events"]:
		if not data.get(key) is Array: return false
	if data.people.size() > POPULATION_CAP + DEPARTED_LIMIT or data.parties.size() > POPULATION_CAP + DEPARTED_LIMIT or data.local_tickets.size() > POPULATION_CAP or data.pending_events.size() > 100000: return false
	if not data.get("bookings") is Dictionary or not bookings.restore(data.bookings): return false
	clock = float(data.clock)
	_ticks = int(data.ticks)
	_clock_origin = float(data.clock_origin)
	_pending_time = float(data.pending_time)
	_seed_value = int(data.seed)
	_rng.seed = _seed_value
	_rng.state = int(data.rng_state)
	_next_person_id = int(data.next_person_id)
	_next_party_id = int(data.next_party_id)
	_next_arrival = float(data.next_arrival)
	_event_sequence = int(data.event_sequence)
	population_cap = int(data.population_cap)
	arrivals_enabled = data.arrivals_enabled
	_sessions_external = data.sessions_external
	total_room_income = int(data.total_room_income)
	total_activity_income = int(data.total_activity_income)
	_retired_room_income = int(data.retired_room_income)
	_retired_activity_income = int(data.retired_activity_income)
	var party_ids := {}
	var receipt_ids := {}
	var room_total := _retired_room_income
	var activity_total := _retired_activity_income
	for value in data.parties:
		if not value is Dictionary or not _valid_party(value, party_ids, receipt_ids): return false
		var group: Dictionary = value.duplicate(true)
		for key in ["id", "nights", "initial_budget", "budget", "cabin_id", "paid_nights", "room_spent", "activity_spent", "rate"]: group[key] = int(group[key])
		var ids: Array = []
		for id in group.member_ids: ids.append(int(id))
		group.member_ids = ids
		parties.append(group)
		room_total += group.room_spent
		activity_total += group.activity_spent
	if total_room_income != room_total or total_activity_income != activity_total: return false
	var person_ids := {}
	for value in data.people:
		if not value is Dictionary or not _valid_person(value, person_ids): return false
		var guest: Dictionary = value.duplicate(true)
		var motion := GuestMotion.new()
		if not motion.restore(value.motion): return false
		motion.moving = value.motion.get("moving", false)
		guest.motion = motion
		guest.approach = _decode_points(value.approach)
		for key in ["id", "party_id", "role", "facility_id", "slot", "visit_sequence", "last_facility_id"]: guest[key] = int(guest[key])
		people.append(guest)
	var active := 0
	var departed := 0
	for group in parties:
		var members := _members(group)
		if members.size() != group.member_ids.size(): return false
		var roles := {}
		for guest in members:
			if guest.party_id != group.id or roles.has(guest.role): return false
			roles[guest.role] = true
			if guest.state == "departed": departed += 1
			else: active += 1
		if not roles.has(0) or (members.size() == 2 and not roles.has(1)): return false
		var booking: Dictionary = bookings.booking(group.id)
		if group.cabin_id > 0:
			if booking.is_empty() or booking.cabin_id != group.cabin_id or booking.rate != group.rate or booking.nights != group.nights: return false
		elif not booking.is_empty(): return false
		if group.state == "departed" and not _all_state(members, ["departed"]): return false
		if group.state == "waiting_room" and not _all_state(members, ["arriving", "waiting_room"]): return false
		if group.state == "departing" and not _all_state(members, ["departing", "departed"]): return false
	if active > population_cap or departed > DEPARTED_LIMIT: return false
	for booking in bookings.reservations:
		if party(booking.party_id).is_empty(): return false
	for guest in people:
		if not _valid_motion(guest): return false
	for group in parties:
		for receipt in group.receipts:
			var owner := person(int(receipt.person_id))
			if owner.is_empty() or int(receipt.id.get_slice(":", 3)) > int(owner.visit_sequence): return false
	if _sessions_external and not data.local_tickets.is_empty(): return false
	var ticket_people := {}
	var occupied := {}
	var queue_points := {}
	for value in data.local_tickets:
		if not value is Dictionary or not _valid_local_ticket(value, ticket_people, occupied, queue_points): return false
		var ticket: Dictionary = value.duplicate(true)
		ticket.queue_position = Vector2(value.queue_position[0], value.queue_position[1])
		for key in ["person_id", "party_id", "facility_id", "slot", "partner_id"]: ticket[key] = int(ticket[key])
		_local_tickets.append(ticket)
	if not _sessions_external:
		for guest in people:
			if guest.state in FACILITY_STATES and _ticket(guest.id).is_empty(): return false
	var event_ids := {}
	var pending_room := 0
	var pending_activity := 0
	for value in data.pending_events:
		if not value is Dictionary or not _valid_event(value) or event_ids.has(value.id) or not _pending_event_matches_money(value): return false
		event_ids[value.id] = true
		if value.kind == "room": pending_room += int(value.amount)
		elif value.kind != "wage": pending_activity += int(value.amount)
		_pending_events.append(value.duplicate(true))
	if pending_room > total_room_income or pending_activity > total_activity_income: return false
	return true

func _valid_party(group: Dictionary, ids: Dictionary, receipt_ids: Dictionary) -> bool:
	for key in ["id", "nights", "initial_budget", "budget", "paid_nights", "room_spent", "activity_spent", "rate"]:
		if not Bookings.integral(group.get(key), 0, 1000000000): return false
	if group.id < 1 or group.id >= _next_party_id or ids.has(int(group.id)): return false
	ids[int(group.id)] = true
	if group.nights < 1 or group.nights > 3 or group.rate < 1 or group.paid_nights > group.nights: return false
	if not Bookings.integral(group.get("cabin_id"), -1, 1000000000) or group.cabin_id == 0: return false
	if group.get("state") not in ["waiting_room", "reserved", "active", "reuniting", "checkout", "departing", "departed"]: return false
	if not group.get("checkout_requested") is bool or not group.get("legacy") is bool or not group.get("departure_reason") is String: return false
	if not _history_valid(group.get("history")): return false
	if not _number(group.get("created_at"), 0, clock) or not _number(group.get("next_night"), 0, clock + 4 * DAY_SECONDS): return false
	if not group.get("member_ids") is Array or group.member_ids.size() not in [1, 2]: return false
	var members := {}
	for id in group.member_ids:
		if not Bookings.integral(id, 1, _next_person_id - 1) or members.has(int(id)): return false
		members[int(id)] = true
	if group.budget + group.room_spent + group.activity_spent != group.initial_budget or group.room_spent != group.paid_nights * group.rate: return false
	if group.state in ["waiting_room", "departing", "departed"]:
		if group.cabin_id != -1: return false
	elif group.cabin_id < 1 or layout.find_object(int(group.cabin_id)).get("kind") != "cabin": return false
	if group.state in ["active", "reuniting", "checkout"] and (group.paid_nights < 1 or group.next_night <= 0): return false
	if group.state in ["waiting_room", "reserved"] and (group.paid_nights != 0 or group.next_night != 0): return false
	if not group.get("receipts") is Array or group.receipts.size() > 1000: return false
	var amount := int(group.get("legacy_activity_spent", 0))
	if not Bookings.integral(group.get("legacy_activity_spent", 0), 0, 1000000000) or (not group.legacy and amount != 0): return false
	for receipt in group.receipts:
		if not receipt is Dictionary or not _valid_event(receipt) or receipt.kind not in PRICES or receipt.get("party_id") != group.id: return false
		if not Bookings.integral(receipt.get("person_id"), 1, 1000000000): return false
		if not _activity_event_identity(receipt): return false
		if not _has_id(group.member_ids, int(receipt.person_id)) or receipt.amount != PRICES[receipt.kind] or receipt_ids.has(receipt.id): return false
		receipt_ids[receipt.id] = true
		amount += int(receipt.amount)
	return amount == group.activity_spent

func _valid_person(guest: Dictionary, ids: Dictionary) -> bool:
	if not _json_safe(guest): return false
	for key in ["id", "party_id", "role", "visit_sequence"]:
		if not Bookings.integral(guest.get(key), 0, 1000000000): return false
	if guest.id < 1 or guest.id >= _next_person_id or ids.has(int(guest.id)) or int(guest.role) not in [0, 1]: return false
	ids[int(guest.id)] = true
	var group := party(int(guest.party_id))
	if group.is_empty() or not _has_id(group.member_ids, int(guest.id)): return false
	if not _valid_profile(guest.get("profile")) or not _needs_valid(guest.get("needs")): return false
	if guest.get("state") not in STATES or guest.get("activity") not in ACTIVITIES: return false
	for key in ["reason", "last_activity", "after_exit", "after_activity"]:
		if not guest.get(key) is String or guest[key].length() > 2000: return false
	if guest.after_exit not in ["decide", "home", "depart"] or guest.after_activity not in ["decide", "home"] or guest.last_activity not in ACTIVITIES: return false
	if not _history_valid(guest.get("history")): return false
	if not _number(guest.get("mood"), 0, 100): return false
	if not _number(guest.get("unhappy_elapsed", 0), 0, 18): return false
	if not guest.get("mood_reason", "") is String or str(guest.get("mood_reason", "")).length() > 2000: return false
	for key in ["warning_elapsed", "activity_elapsed", "timer", "sleep_until", "queue_started", "decision_cooldown", "departed_at"]:
		if not _number(guest.get(key), 0, 1000000000000.0): return false
	for key in ["want_leave", "session_paid", "visit_notified", "return_requested"]:
		if not guest.get(key) is bool: return false
	for key in ["facility_id", "last_facility_id"]:
		if not Bookings.integral(guest.get(key), -1, 1000000000) or guest[key] == 0: return false
	if not Bookings.integral(guest.get("slot"), -1, 1): return false
	if not Bookings.integral(guest.get("exit_prefix", 0), 0, 4096): return false
	if guest.state in FACILITY_STATES:
		if guest.activity not in KINDS or layout.find_object(int(guest.facility_id)).get("kind") != KINDS[guest.activity]: return false
		if guest.state in IN_FACILITY and int(guest.slot) not in [0, 1]: return false
	elif guest.facility_id != -1 or guest.slot != -1 or guest.session_paid: return false
	if guest.state in ["sitting", "eating", "lying", "volleyball"] and not guest.session_paid: return false
	if guest.session_paid and guest.visit_sequence < 1: return false
	if guest.state in ["arriving", "waiting_room", "departing", "departed"] and group.state not in ["waiting_room", "checkout", "departing", "departed"]: return false
	if not guest.get("motion") is Dictionary or not _points_valid(guest.get("approach")): return false
	if not Bookings.integral(guest.motion.get("index"), 0, 4096): return false
	if guest.motion.has("moving") and not guest.motion.moving is bool: return false
	if guest.has("outdoor_target") and guest.outdoor_target != [] and not _point_valid(guest.outdoor_target): return false
	if guest.motion.get("route") is Array and guest.motion.route.size() > 4096: return false
	return true

func _valid_motion(guest: Dictionary) -> bool:
	var motion: GuestMotion = guest.motion
	if motion.direction.length() > 1.001 or motion.route.size() > 4096: return false
	if guest.state in TRAVEL_STATES and motion.route.is_empty(): return false
	var route: Array[Vector2] = []
	var record: Dictionary = {}
	if guest.state in INTERIOR_STATES:
		record = layout.find_object(party(guest.party_id).cabin_id)
		if assets != null:
			route.append(Vector2(_door(record)))
			route.append_array(CabinInterior.aisle(record, assets))
			route.append(GuestActivitySlots.slot(record, "sleeping", guest.role, assets).position)
	elif guest.state in IN_FACILITY:
		record = layout.find_object(guest.facility_id)
		if assets != null:
			route = GuestActivitySlots.approach(record, POSES[guest.activity], guest.slot, assets)
			if guest.approach.size() != route.size(): return false
			for index in route.size():
				if not (guest.approach[index] as Vector2).is_equal_approx(route[index]): return false
	if not record.is_empty():
		if not layout.object_rect(record).grow(1.1).has_point(motion.position) and not motion.position.is_equal_approx(Vector2(_door(record))): return false
		if not route.is_empty() and not _on_polyline(motion.position, route): return false
		for point in motion.route:
			if not route.is_empty() and not _on_polyline(point, route): return false
			if not layout.object_rect(record).grow(1.1).has_point(point) and not point.is_equal_approx(Vector2(_door(record))): return false
		if not route.is_empty():
			var expected: Array[Vector2] = []
			if guest.state == "entering":
				expected = CabinInterior.aisle(record, assets)
				expected.append(route[-1])
			elif guest.state == "exiting":
				expected = CabinInterior.aisle(record, assets)
				expected.reverse()
				expected.append(Vector2(_door(record)))
			elif guest.state in ["approaching_activity", "leaving_activity"]:
				expected = route.duplicate()
				if guest.state == "leaving_activity":
					var prefix := int(guest.get("exit_prefix", route.size()))
					if prefix < 1 or prefix > route.size(): return false
					expected.resize(prefix)
					expected.reverse()
			if not expected.is_empty():
				if expected.size() != motion.route.size(): return false
				for index in expected.size():
					if not expected[index].is_equal_approx(motion.route[index]): return false
			elif motion.position.distance_to(route[-1]) > 0.06: return false
		return true
	var graph := _navigation()
	var cell := Vector2i(motion.position.round())
	if not _open(graph, cell) or graph.get_id_path(cell, ResortLayout.ARRIVAL).is_empty(): return false
	for index in motion.route.size():
		var point: Vector2 = motion.route[index]
		if not _open(graph, Vector2i(point.round())): return false
		if not point.is_equal_approx(Vector2(point.round())):
			if guest.state not in ["to_facility", "queueing"] or index != motion.route.size() - 1 or not _point_valid(guest.get("outdoor_target")): return false
			var target := Vector2(guest.outdoor_target[0], guest.outdoor_target[1])
			if not target.is_equal_approx(point) or point.distance_to(point.round()) > 0.708: return false
		if index > 0 and point.distance_to(motion.route[index - 1]) > 1.001: return false
	if motion.index < motion.route.size() and motion.position.distance_to(motion.route[motion.index]) > 1.01: return false
	return true

func _valid_local_ticket(ticket: Dictionary, ids: Dictionary, occupied: Dictionary, queue_points: Dictionary) -> bool:
	for key in ["person_id", "party_id", "facility_id", "partner_id"]:
		if not Bookings.integral(ticket.get(key), 0, 1000000000): return false
	if ids.has(int(ticket.person_id)) or ticket.get("status") not in ["queued", "reserved", "active"]: return false
	ids[int(ticket.person_id)] = true
	var guest := person(int(ticket.person_id))
	if guest.is_empty() or guest.party_id != ticket.party_id or guest.facility_id != ticket.facility_id or guest.activity != ticket.get("activity") or guest.state not in FACILITY_STATES: return false
	if not Bookings.integral(ticket.get("slot"), -1, 1): return false
	if ticket.status == "queued":
		if ticket.slot != -1 or ticket.get("arrived") != false or ticket.get("admitted") != false: return false
	else:
		if ticket.slot < 0: return false
		var key: String = "%d:%d" % [ticket.facility_id, ticket.slot]
		if occupied.has(key): return false
		occupied[key] = true
		# A queued walker may receive a place before reaching the queue point.
		if guest.slot != ticket.slot and guest.state not in ["to_facility", "queueing"]: return false
	if not ticket.get("arrived") is bool or not ticket.get("admitted") is bool: return false
	if ticket.status == "active" and (not ticket.arrived or not ticket.admitted): return false
	for key in ["requested_at", "reserved_at", "arrived_at"]:
		if not _number(ticket.get(key), 0, clock): return false
	if not _point_valid(ticket.get("queue_position")): return false
	var point := Vector2(ticket.queue_position[0], ticket.queue_position[1])
	if not point.is_equal_approx(point.round()) or queue_points.has(point) or _entrance_cells().has(Vector2i(point)): return false
	queue_points[point] = true
	var graph := _navigation()
	return _open(graph, Vector2i(point)) and not graph.get_id_path(Vector2i(point), ResortLayout.ARRIVAL).is_empty()

func _valid_event(event: Dictionary) -> bool:
	if not event.get("id") is String or event.id.is_empty() or event.id.length() > 160: return false
	if event.get("kind") not in ["room", "meal", "sunbathe", "volleyball", "wage"]: return false
	if not Bookings.integral(event.get("amount"), -1000000000, 1000000000) or not _number(event.get("time"), 0, clock): return false
	if (event.kind == "wage" and event.amount >= 0) or (event.kind != "wage" and event.amount <= 0): return false
	for key in ["party_id", "person_id", "staff_id"]:
		if event.has(key) and not Bookings.integral(event[key], 0, 1000000000): return false
	return true

func _activity_event_identity(event: Dictionary) -> bool:
	var pieces: PackedStringArray = str(event.get("id", "")).split(":")
	if pieces.size() != 4 or pieces[0] != "resort" or pieces[1] != "activity": return false
	if not pieces[2].is_valid_int() or pieces[2].length() > 10 or not pieces[3].is_valid_int() or pieces[3].length() > 10: return false
	var person_id := int(pieces[2])
	var sequence := int(pieces[3])
	return person_id > 0 and person_id < _next_person_id and sequence > 0 and sequence <= 1000000000 and event.get("person_id") == person_id and event.id == "resort:activity:%d:%d" % [person_id, sequence]

func _pending_event_matches_money(event: Dictionary) -> bool:
	if event.kind == "wage": return true # Cross-validated with W4/ledger by the envelope.
	if not Bookings.integral(event.get("party_id"), 1, _next_party_id - 1): return false
	var group := party(int(event.party_id))
	if event.kind == "room":
		var pieces: PackedStringArray = event.id.split(":")
		if pieces.size() != 4 or not pieces[3].is_valid_int() or pieces[3].length() > 1: return false
		var night := int(pieces[3])
		if night < 1 or night > 3 or event.id != "resort:room:%d:%d" % [int(event.party_id), night]: return false
		return (night <= int(group.paid_nights) and event.amount == group.rate) if not group.is_empty() else event.amount == Bookings.NIGHTLY_RATE
	if not _activity_event_identity(event) or event.amount != PRICES.get(event.kind): return false
	if group.is_empty(): return true # Retired parties retain aggregate lifetime totals.
	for receipt in group.receipts:
		if receipt.id == event.id:
			return receipt.kind == event.kind and receipt.amount == event.amount and receipt.person_id == event.person_id and absf(float(receipt.time) - float(event.time)) < 0.000001
	return false

func _valid_definition(value: Dictionary) -> bool:
	if not Bookings.integral(value.get("nights"), 1, 3) or not Bookings.integral(value.get("budget"), 1, 1000000): return false
	if not value.get("members") is Array or value.members.size() not in [1, 2]: return false
	for profile in value.members:
		if not _valid_profile(profile): return false
	return true

func _valid_profile(profile: Variant) -> bool:
	if not profile is Dictionary or not profile.get("name") is String or profile.name.is_empty() or profile.name.length() > 80: return false
	if profile.get("variant") not in ["female", "male"] or not profile.get("interests") is Array or profile.interests.size() < 1 or profile.interests.size() > 8: return false
	for interest in profile.interests:
		if not interest is String or interest.length() > 80: return false
	return _needs_valid(profile.get("initial_needs")) and _json_safe(profile)

func _needs_valid(needs: Variant) -> bool:
	if not needs is Dictionary: return false
	for key in ["hunger", "rest", "enjoyment"]:
		if not _number(needs.get(key), 0, 100): return false
	return true

func _history_valid(history: Variant) -> bool:
	if not history is Array or history.size() > 24: return false
	for item in history:
		if not item is String or item.length() > 2000: return false
	return true

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

func _time_reached(deadline: float) -> bool:
	# Default Godot JSON formatting can round an exact fixed-step deadline a
	# fraction above its original value (241.56666666666666 -> 241.566666666667).
	# That is serialization noise, not another 1/30 second of sleeping/waiting.
	return clock + TIME_EPSILON >= deadline

func _valid_rng_string(value: Variant) -> bool:
	if not value is String or not value.is_valid_int(): return false
	var negative: bool = value.begins_with("-")
	var digits: String = value.substr(1) if negative else value
	if digits.is_empty() or digits.begins_with("+") or (digits.length() > 1 and digits.begins_with("0")): return false
	if digits.length() > 19: return false
	if digits.length() == 19 and digits > ("9223372036854775808" if negative else "9223372036854775807"): return false
	return str(int(value)) == value

func _has_id(ids: Array, id: int) -> bool:
	for item in ids:
		if int(item) == id: return true
	return false

func _point_valid(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -0.5, ResortLayout.MAP_SIZE.x - 0.5) and _number(value[1], -0.5, ResortLayout.MAP_SIZE.y - 0.5)

func _points_valid(value: Variant) -> bool:
	if not value is Array or value.size() > 4096: return false
	for point in value:
		if not _point_valid(point): return false
	return true

func _encode_points(points: Array) -> Array:
	var result: Array = []
	for point in points: result.append([point.x, point.y])
	return result

func _decode_points(points: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points: result.append(Vector2(point[0], point[1]))
	return result

func _on_polyline(point: Vector2, points: Array[Vector2]) -> bool:
	for index in range(1, points.size()):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[index - 1], points[index])) < 0.06: return true
	return not points.is_empty() and point.distance_to(points[0]) < 0.06

func _json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 10: return false
	if value is String or value is bool or value == null: return true
	if value is int or value is float: return is_finite(float(value))
	if value is Array:
		if value.size() > 4096: return false
		for item in value:
			if not _json_safe(item, depth + 1): return false
		return true
	if value is Dictionary:
		if value.size() > 128: return false
		for key in value:
			if not key is String or not _json_safe(value[key], depth + 1): return false
		return true
	return false

func import_legacy(data: Dictionary) -> bool:
	if layout == null: return false
	if not Bookings.integral(data.get("version"), 1, 2) or not Bookings.integral(data.get("party_size", 1), 1, 2): return false
	if int(data.version) == 2 and (not data.get("companion") is Dictionary or not Bookings.integral(data.companion.get("index"), 0, 4096)): return false
	# GuestStay remains the schema authority for its own old fixture. Strengthen
	# its old integer checks here before importing identities or money.
	for key in ["cabin_id", "facility_id", "booking_rate", "nights", "paid_nights", "budget", "accommodation_spent", "activity_spent", "revenue", "route_index"]:
		if not Bookings.integral(data.get(key), -1 if key in ["cabin_id", "facility_id"] else 0, 1000000000): return false
	var old := GuestStay.new()
	old.configure(layout, assets)
	if not old.restore(data): return false
	var candidate := ResortSimulation.new()
	candidate.layout = layout
	candidate.assets = assets
	candidate.bookings.configure(layout)
	candidate._seed_value = _seed_value
	candidate._rng.seed = _seed_value
	candidate._ticks = int(floor(old.clock / STEP))
	candidate._clock_origin = maxf(0, old.clock - candidate._ticks * STEP)
	candidate.clock = old.clock
	candidate._next_arrival = old.clock + 22.0
	candidate._next_party_id = 2
	candidate._next_person_id = old.party_size + 1
	candidate.population_cap = population_cap
	candidate.arrivals_enabled = arrivals_enabled
	candidate.total_room_income = old.accommodation_spent
	candidate.total_activity_income = old.activity_spent
	var group_state := "active"
	match old.state:
		"arriving", "waiting": group_state = "waiting_room"
		"to_cabin": group_state = "reserved"
		"entering": group_state = "reserved" if old.paid_nights == 0 else "reuniting"
		"overnight", "returning": group_state = "reuniting"
		"exiting": group_state = "checkout" if old.after_exit == "checkout" else "active"
		"departing": group_state = "departing"
		"departed": group_state = "departed"
	var group := {"id": 1, "member_ids": [], "nights": old.nights, "initial_budget": 240 * old.party_size, "budget": old.budget,
		"cabin_id": old.cabin_id, "paid_nights": old.paid_nights, "room_spent": old.accommodation_spent, "activity_spent": old.activity_spent,
		"created_at": 0.0, "next_night": old.next_night, "state": group_state, "history": old.history.duplicate(), "rate": old.booking_rate,
		"departure_reason": old.departure_reason, "checkout_requested": old.after_exit == "checkout", "receipts": [], "legacy": true, "legacy_activity_spent": old.activity_spent}
	if group.cabin_id > 0 and not candidate.bookings.reserve(1, group.cabin_id, group.nights, group.initial_budget, group.rate): return false
	var mapping := {"arriving": "arriving", "waiting": "waiting_room", "to_cabin": "to_cabin", "entering": "entering", "resting": "sleeping", "overnight": "sleeping",
		"exiting": "exiting", "returning": "returning", "departing": "departing", "departed": "departed",
		"to_cafe": "to_facility", "approaching_seats": "approaching_activity", "sitting": "sitting", "eating": "eating", "leaving_seats": "leaving_activity",
		"to_beach": "to_facility", "approaching_loungers": "approaching_activity", "relaxing": "lying", "leaving_loungers": "leaving_activity",
		"to_court": "to_facility", "approaching_court": "approaching_activity", "playing_volleyball": "volleyball", "leaving_court": "leaving_activity"}
	for role in old.party_size:
		var motion := GuestMotion.new()
		if role == 0:
			motion.position = old.logical_position
			motion.direction = old.direction
			motion.distance = old.walked_distance
			motion.route = old.route.duplicate()
			motion.index = old.route_index
		else:
			if not motion.restore(old.companion.capture()): return false
		motion.moving = not motion.finished() and motion.delay <= 0
		var profile := candidate._profile("Maya" if role == 0 else "Leo", "female" if role == 0 else "male", ["meal", "sunbathe"] if role == 0 else ["volleyball", "stroll"], 75, 65, 60)
		var guest := candidate._new_person(role + 1, 1, role, profile, motion)
		guest.state = mapping[old.state]
		guest.needs = {"hunger": old.hunger, "rest": old.rest, "enjoyment": old.enjoyment}
		guest.reason = old.explanation
		guest.history = old.history.duplicate()
		guest.timer = maxf(0, old.timer)
		guest.activity_elapsed = old.activity_elapsed
		guest.sleep_until = old.clock + maxf(0, old.timer)
		guest.after_exit = "depart" if old.after_exit == "checkout" else "decide"
		guest.return_requested = group_state in ["reuniting", "checkout"]
		guest.after_activity = "home" if guest.return_requested else "decide"
		if guest.state in INTERIOR_STATES or guest.state in ["to_cabin", "returning"]: guest.activity = "rest"
		if guest.state in FACILITY_STATES:
			guest.activity = "meal" if old.state in ["to_cafe", "approaching_seats", "sitting", "eating", "leaving_seats"] else ("sunbathe" if old.state in ["to_beach", "approaching_loungers", "relaxing", "leaving_loungers"] else "volleyball")
			guest.facility_id = old.facility_id
			guest.slot = role
			guest.visit_sequence = 1
			guest.session_paid = old.state not in ["to_cafe", "to_beach", "to_court"]
			guest.visit_notified = guest.state == "leaving_activity"
			guest.queue_started = old.clock
			if assets != null: guest.approach = GuestActivitySlots.approach(layout.find_object(old.facility_id), POSES[guest.activity], role, assets)
			if guest.state == "leaving_activity": guest.exit_prefix = guest.approach.size()
			var point := candidate._local_queue_point(layout.find_object(old.facility_id))
			if not is_finite(point.x): return false
			var arrived: bool = guest.state in ["sitting", "eating", "lying", "volleyball", "leaving_activity"]
			candidate._local_tickets.append({"person_id": guest.id, "party_id": 1, "facility_id": old.facility_id, "activity": guest.activity, "slot": role,
				"status": "active" if arrived else "reserved", "queue_position": point, "partner_id": (2 if role == 0 else 1) if old.party_size == 2 else 0,
				"arrived": arrived, "admitted": arrived, "requested_at": old.clock, "reserved_at": old.clock, "arrived_at": old.clock if arrived else 0.0})
		if guest.state == "departed": guest.departed_at = old.clock
		candidate.people.append(guest)
		group.member_ids.append(guest.id)
	candidate.parties.append(group)
	# No historical income is emitted: the envelope seeds the ledger exactly
	# once from the preserved totals. Only future payments enter drain_events().
	return restore(candidate.capture())
