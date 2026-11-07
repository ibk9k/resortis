class_name FacilitySessions
extends RefCounted
## Owns claims and admission, never people, routes in motion, payments or files.
## A cancelled occupant keeps its claim until its controller walks it clear.

const QUEUE_LIMIT := 4
const QUEUE_TIMEOUT := 55.0
const RESERVATION_TIMEOUT := 90.0
const PARTNER_TIMEOUT := 22.0
const ACTIVE_TIMEOUT := 60.0
const EXIT_TIMEOUT := 30.0
const MAX_QUEUE_DISTANCE := 18
const EXPIRED_LIMIT := 64
const MAX_ID := 1000000000
const MAX_TIME := 1000000000000.0
const EPSILON := 0.000001
const KINDS := ResortServices.KINDS
const POSES := ResortServices.POSES
const INSIDE_STATES := ["approaching_activity", "sitting", "eating", "lying", "volleyball", "using_facility", "waiting_partner", "leaving_activity"]
const DIRECTIONS := [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
const TICKET_FIELDS := ["person_id", "party_id", "facility_id", "activity", "status", "slot", "queue_position", "partner_id", "preferred_partner_id", "sequence", "arrived", "admitted", "claim_held", "requested_at", "reserved_at", "arrived_at", "active_at", "expired_at", "match_id", "reason"]

var layout: ResortLayout
var assets: ResortAssets
var _clock := 0.0
var _next_sequence := 1
var _tickets: Array[Dictionary] = []
var _people: Dictionary = {}
var _people_bound := false
var _graph: AStarGrid2D
var _revision := -1
var _queue_cache: Dictionary = {}

func configure(map: ResortLayout, library: ResortAssets) -> void:
	layout = map
	assets = library
	_clock = 0.0
	_next_sequence = 1
	_tickets.clear()
	_people.clear()
	_people_bound = false
	_invalidate_navigation()

func request(person_id: int, party_id: int, facility_id: int, activity: String, clock: float, preferred_partner_id: int = 0) -> Dictionary:
	if layout == null or assets == null or activity not in KINDS: return {}
	if person_id < 1 or person_id > MAX_ID or party_id < 1 or party_id > MAX_ID: return {}
	if preferred_partner_id < 0 or preferred_partner_id > MAX_ID or preferred_partner_id == person_id: return {}
	if not _valid_clock(clock): return {}
	var record := layout.find_object(facility_id)
	if record.get("kind") != KINDS[activity] or not _reachable(record): return {}
	_process_time(clock)
	var previous := _find(person_id)
	if not previous.is_empty():
		if previous.status != "expired":
			if previous.party_id == party_id and previous.facility_id == facility_id and previous.activity == activity: return previous.duplicate(true)
			return {}
		if previous.claim_held: return {}
		_tickets.erase(previous)
		_queue_cache.clear()
	_promote()
	if _queue_count(facility_id) >= QUEUE_LIMIT: return {}
	var waiting_point := _waiting_point(record)
	if not is_finite(waiting_point.x): return {}
	var index := _vacant_slot(facility_id) if _queue_count(facility_id) == 0 else -1
	var entry := {
		"person_id": person_id, "party_id": party_id, "facility_id": facility_id, "activity": activity,
		"status": "reserved" if index >= 0 else "queued", "slot": index, "queue_position": waiting_point,
		"partner_id": 0, "preferred_partner_id": preferred_partner_id, "sequence": _next_sequence,
		"arrived": false, "admitted": false, "claim_held": index >= 0,
		"requested_at": _clock, "reserved_at": _clock if index >= 0 else 0.0,
		"arrived_at": 0.0, "active_at": 0.0, "expired_at": 0.0, "match_id": "", "reason": ""
	}
	_next_sequence += 1
	_tickets.append(entry)
	_queue_cache.clear()
	_pair_courts()
	_prune_expired()
	return entry.duplicate(true)

func ticket(person_id: int) -> Dictionary:
	return _find(person_id).duplicate(true)

func confirm_arrival(person_id: int, clock: float) -> bool:
	if not _valid_clock(clock): return false
	_process_time(clock)
	var entry := _find(person_id)
	if entry.is_empty() or entry.status not in ["reserved", "active"] or not entry.claim_held: return false
	# In a running controller, inspect the SAME GuestMotion object, including a
	# movement completed later in this tick. Standalone callers assert arrival.
	if _people.has(person_id):
		var guest: Dictionary = _people[person_id]
		var fixture := slot(person_id)
		if not guest.get("motion") is GuestMotion or fixture.is_empty(): return false
		if (guest.motion as GuestMotion).position.distance_to(fixture.position) > 0.12: return false
		if guest.get("facility_id") != entry.facility_id or guest.get("activity") != entry.activity: return false
	if entry.arrived: return true
	entry.arrived = true
	entry.arrived_at = _clock
	if entry.activity in ResortServices.PAIRED:
		_pair_courts()
	else:
		_admit(entry)
	return true

func ready(person_id: int) -> bool:
	var entry := _find(person_id)
	if entry.is_empty() or entry.status != "active" or not entry.claim_held or not entry.arrived or not entry.admitted: return false
	if entry.activity not in ResortServices.PAIRED: return true
	var other := _find(int(entry.partner_id))
	return not other.is_empty() and other.status == "active" and other.arrived and other.admitted and other.claim_held and other.partner_id == person_id and other.facility_id == entry.facility_id and other.slot != entry.slot and other.match_id == entry.match_id

func release(person_id: int) -> void:
	var entry := _find(person_id)
	if entry.is_empty(): return
	# release means the controller has finished the physical exit. A matched
	# peer is cancelled too; its own claim remains until it walks out.
	var partner_id := int(entry.partner_id)
	_tickets.erase(entry)
	_queue_cache.clear()
	if partner_id > 0: _expire(partner_id, _clock, "The other player left the court.")
	_promote()
	_prune_expired()

func advance(delta: float, clock: float, people: Array = []) -> void:
	if layout == null or not _number(delta, 0.0, MAX_TIME) or not _valid_clock(clock): return
	_people.clear()
	_people_bound = not people.is_empty()
	for value in people:
		if value is Dictionary and _integer(value.get("id"), 1, MAX_ID): _people[int(value.id)] = value
	# The optional people list is authoritative when supplied. Missing/departed
	# actors cannot keep claims alive. It is never copied into a second position.
	if _people_bound:
		for entry in _tickets:
			if entry.status != "expired" and (not _people.has(int(entry.person_id)) or _people[int(entry.person_id)].get("state") == "departed"):
				_expire(int(entry.person_id), _clock, "The visitor is no longer using this facility.")
			elif entry.activity in ResortServices.PAIRED and entry.status == "active" and _people[int(entry.person_id)].get("state") in ["leaving_activity", "returning", "departing"]:
				_expire(int(entry.person_id), clock, "A player is leaving; the rally has ended.")
	_process_time(clock)
	_clear_exits()
	_promote()
	_prune_expired()

func slot(person_id: int) -> Dictionary:
	var entry := _find(person_id)
	if entry.is_empty() or not entry.claim_held or entry.slot < 0 or entry.slot >= ResortServices.capacity(entry.activity) or assets == null: return {}
	var record := layout.find_object(int(entry.facility_id))
	if record.get("kind") != KINDS.get(entry.activity): return {}
	return GuestActivitySlots.slot(record, POSES[entry.activity], int(entry.slot), assets)

func route(person_id: int, leaving: bool = false) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var entry := _find(person_id)
	if entry.is_empty() or not entry.claim_held or entry.slot < 0 or entry.slot >= ResortServices.capacity(entry.activity) or assets == null: return points
	var record := layout.find_object(int(entry.facility_id))
	if record.get("kind") != KINDS.get(entry.activity): return points
	points = GuestActivitySlots.approach(record, POSES[entry.activity], int(entry.slot), assets)
	if leaving: points.reverse()
	return points

func inspect() -> Array:
	var result: Array = []
	if layout == null: return result
	for record in layout.objects:
		if record.kind not in KINDS.values(): continue
		var occupants: Array[int] = []
		var active: Array[int] = []
		var reserved: Array[int] = []
		var exiting: Array[int] = []
		var queue: Array[int] = []
		var positions: Array[Vector2] = []
		var started := 0.0
		for entry in _tickets:
			if entry.facility_id != record.id: continue
			if entry.claim_held: occupants.append(int(entry.person_id))
			match entry.status:
				"queued":
					queue.append(int(entry.person_id))
					positions.append(entry.queue_position)
				"reserved": reserved.append(int(entry.person_id))
				"active":
					active.append(int(entry.person_id))
					started = float(entry.active_at)
				"expired":
					if entry.claim_held: exiting.append(int(entry.person_id))
		var reachable := _reachable(record)
		var available := reachable and queue.size() < QUEUE_LIMIT and is_finite(_waiting_point(record).x)
		var activity: String = KINDS.find_key(record.kind)
		var capacity := ResortServices.capacity(activity)
		result.append({"id": record.id, "facility_id": record.id, "name": ResortCatalog.definition(record.kind).name,
			"kind": record.kind, "activity": activity, "price": layout.price(activity), "capacity": capacity,
			"occupants": occupants, "occupancy": occupants.size(), "active": active, "reserved": reserved, "exiting": exiting,
			"queue": queue, "queue_count": queue.size(), "queue_limit": QUEUE_LIMIT, "waiting_positions": positions,
			"reachable": reachable, "available": available, "immediate_vacancy": capacity - occupants.size(),
			"available_now": available and occupants.size() < capacity and queue.is_empty(), "session_started_at": started})
	return result

func protects(object_id: int) -> bool:
	for entry in _tickets:
		if entry.facility_id == object_id and (entry.status != "expired" or entry.claim_held): return true
	return false

func access_survives(candidate: ResortLayout) -> bool:
	if candidate == null or layout == null: return false
	var graph := candidate.navigation()
	var stations: Dictionary = {}
	for entry in _tickets:
		if entry.status == "expired" and not entry.claim_held: continue
		var original := layout.find_object(int(entry.facility_id))
		var changed := candidate.find_object(int(entry.facility_id))
		if changed.is_empty() or changed.kind != original.kind or changed.position != original.position or changed.orientation != original.orientation: return false
		if not _connected(graph, _door(changed)): return false
		var cell := Vector2i((entry.queue_position as Vector2).round())
		if not _station_allowed(candidate, graph, cell) or not _connected(graph, cell): return false
		stations[cell] = true
	return _lanes_connected(candidate, graph, stations)

func layout_changed() -> void:
	_invalidate_navigation()
	# Normal edits have already passed access_survives. Defensive cancellation
	# handles callers which change a map directly without moving any actor here.
	for entry in _tickets:
		if entry.status == "expired": continue
		var record := layout.find_object(int(entry.facility_id))
		if record.get("kind") != KINDS.get(entry.activity) or not _reachable(record):
			_expire(int(entry.person_id), _clock, "Facility access changed.")
	_promote()

func capture() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry in _tickets:
		var saved := entry.duplicate(true)
		var point: Vector2 = entry.queue_position
		saved.queue_position = [point.x, point.y]
		entries.append(saved)
	return {"version": 1, "clock": _clock, "next_sequence": _next_sequence, "tickets": entries}

func restore(data: Dictionary) -> bool:
	if layout == null or assets == null or not _integer(data.get("version"), 1, 1): return false
	if not _number(data.get("clock"), 0.0, MAX_TIME) or not _integer(data.get("next_sequence"), 1, 9007199254740991): return false
	if not data.get("tickets") is Array or data.tickets.size() > layout.objects.size() * (ResortServices.MAX_CAPACITY + QUEUE_LIMIT) + EXPIRED_LIMIT: return false
	var decoded: Array[Dictionary] = []
	var ids: Dictionary = {}
	var claims: Dictionary = {}
	var stations: Dictionary = {}
	var queued: Dictionary = {}
	var last_sequence := 0
	var last_requested := 0.0
	var expired_count := 0
	for value in data.tickets:
		if not value is Dictionary or not _valid_ticket(value, float(data.clock)): return false
		var person_id := int(value.person_id)
		if ids.has(person_id) or int(value.sequence) <= last_sequence or float(value.requested_at) < last_requested: return false
		last_sequence = int(value.sequence)
		last_requested = float(value.requested_at)
		ids[person_id] = value
		var entry: Dictionary = value.duplicate(true)
		for key in ["person_id", "party_id", "facility_id", "slot", "partner_id", "preferred_partner_id", "sequence"]: entry[key] = int(entry[key])
		entry.queue_position = Vector2(value.queue_position[0], value.queue_position[1])
		decoded.append(entry)
		if entry.claim_held:
			var key := "%d:%d" % [entry.facility_id, entry.slot]
			if claims.has(key): return false
			claims[key] = true
		if entry.status != "expired" or entry.claim_held:
			if stations.has(entry.queue_position): return false
			stations[entry.queue_position] = true
		if entry.status == "queued":
			queued[entry.facility_id] = int(queued.get(entry.facility_id, 0)) + 1
			if queued[entry.facility_id] > QUEUE_LIMIT: return false
		if entry.status == "expired" and not entry.claim_held: expired_count += 1
	if last_sequence >= int(data.next_sequence) or expired_count > EXPIRED_LIMIT: return false
	for entry in decoded:
		if entry.status!="expired" and _deadline(entry,ids)<=float(data.clock)+EPSILON: return false
		if entry.status == "queued":
			for index in ResortServices.capacity(entry.activity):
				if not claims.has("%d:%d" % [entry.facility_id, index]): return false
		if entry.activity not in ResortServices.PAIRED or entry.status == "expired": continue
		if entry.partner_id == 0:
			if entry.status == "active" or not entry.match_id.is_empty(): return false
			if entry.status == "reserved":
				for other in decoded:
					if other.person_id != entry.person_id and other.facility_id == entry.facility_id and other.status in ["reserved", "active"]: return false
			continue
		var other: Dictionary = ids.get(entry.partner_id, {})
		if other.is_empty() or other.get("status") not in ["reserved", "active"]: return false
		if other.get("activity") != entry.activity or other.facility_id != entry.facility_id or other.slot == entry.slot or other.partner_id != entry.person_id: return false
		if entry.match_id != _match_id(entry, other) or other.match_id != entry.match_id: return false
		if entry.status == "active" and (other.status != "active" or not other.arrived or not other.admitted or absf(float(other.active_at) - float(entry.active_at)) > EPSILON): return false
		if entry.status == "reserved" and other.status == "reserved" and entry.arrived and other.arrived: return false
	# Validate the combined lanes, not just every point independently. Two
	# individually reachable waiting places must not close a narrow promenade.
	var cells: Dictionary = {}
	for point: Vector2 in stations: cells[Vector2i(point.round())] = true
	if not _lanes_connected(layout, _navigation(), cells): return false
	_tickets = decoded
	_clock = float(data.clock)
	_next_sequence = int(data.next_sequence)
	_people.clear()
	_people_bound = false
	_queue_cache.clear()
	# No promotion, pairing, arrival or admission is replayed during restore.
	return true

func _valid_ticket(entry: Dictionary, clock: float) -> bool:
	if entry.size() != TICKET_FIELDS.size(): return false
	for key in TICKET_FIELDS:
		if not entry.has(key): return false
	for key in ["person_id", "party_id", "facility_id"]:
		if not _integer(entry.get(key), 1, MAX_ID): return false
	for key in ["partner_id", "preferred_partner_id"]:
		if not _integer(entry.get(key), 0, MAX_ID) or entry[key] == entry.person_id: return false
	if not _integer(entry.get("sequence"), 1, 9007199254740990): return false
	if entry.get("activity") not in KINDS or entry.get("status") not in ["queued", "reserved", "active", "expired"]: return false
	if not _integer(entry.get("slot"), -1, ResortServices.capacity(entry.activity) - 1): return false
	for key in ["arrived", "admitted", "claim_held"]:
		if not entry.get(key) is bool: return false
	for key in ["requested_at", "reserved_at", "arrived_at", "active_at", "expired_at"]:
		if not _number(entry.get(key), 0.0, clock): return false
	if not entry.get("match_id") is String or entry.match_id.length() > 120 or not entry.get("reason") is String or entry.reason.length() > 240: return false
	if not entry.get("queue_position") is Array or entry.queue_position.size() != 2: return false
	if not _integer(entry.queue_position[0], 0, ResortLayout.MAP_SIZE.x - 1) or not _integer(entry.queue_position[1], ResortLayout.INLAND_START, ResortLayout.WALKABLE_END - 1): return false
	var point := Vector2(entry.queue_position[0], entry.queue_position[1])
	var record := layout.find_object(int(entry.facility_id))
	# Free expired tickets are bounded historical notifications; their object
	# may subsequently be removed, and their old station may be reused.
	if entry.status != "expired" or entry.claim_held:
		if record.get("kind") != KINDS[entry.activity] or not _reachable(record): return false
		if not _station_allowed(layout, _navigation(), Vector2i(point)) or not _connected(_navigation(), Vector2i(point)): return false
	if entry.claim_held and int(entry.slot) < 0: return false
	if entry.status == "queued":
		if entry.slot != -1 or entry.claim_held or entry.arrived or entry.admitted or entry.partner_id != 0 or not entry.match_id.is_empty(): return false
		if entry.reserved_at != 0 or entry.arrived_at != 0 or entry.active_at != 0: return false
	else:
		if entry.slot == -1 and (entry.status != "expired" or entry.arrived or entry.admitted): return false
		if entry.slot >= 0 and entry.reserved_at < entry.requested_at: return false
	if entry.status in ["reserved", "active"] and not entry.claim_held: return false
	if entry.arrived:
		if entry.slot < 0 or entry.arrived_at < entry.reserved_at: return false
	elif entry.arrived_at != 0 or entry.admitted: return false
	if entry.admitted:
		if entry.active_at < entry.arrived_at: return false
	elif entry.active_at != 0: return false
	if entry.status == "active" and (not entry.arrived or not entry.admitted): return false
	if entry.status == "reserved" and (entry.admitted or (entry.arrived and entry.activity not in ResortServices.PAIRED)): return false
	if entry.status == "expired":
		if entry.expired_at < entry.requested_at or entry.partner_id != 0 or not entry.match_id.is_empty() or entry.reason.is_empty(): return false
		if entry.expired_at < maxf(float(entry.reserved_at), maxf(float(entry.arrived_at), float(entry.active_at))): return false
	elif entry.expired_at != 0 or not entry.reason.is_empty(): return false
	if entry.activity not in ResortServices.PAIRED and (entry.partner_id != 0 or not entry.match_id.is_empty()): return false
	if entry.activity not in ResortServices.PAIRED and entry.admitted and entry.active_at != entry.arrived_at: return false
	return true

func _find(person_id: int) -> Dictionary:
	for entry in _tickets:
		if entry.person_id == person_id: return entry
	return {}

func _queue_count(facility_id: int) -> int:
	var count := 0
	for entry in _tickets:
		if entry.facility_id == facility_id and entry.status == "queued": count += 1
	return count

func _vacant_slot(facility_id: int) -> int:
	var used: Dictionary = {}
	for entry in _tickets:
		if entry.facility_id == facility_id and entry.claim_held: used[int(entry.slot)] = true
	var activity: String = KINDS.find_key(layout.find_object(facility_id).kind)
	for index in ResortServices.capacity(activity):
		if not used.has(index): return index
	return -1

func _promote() -> void:
	for entry in _tickets:
		if entry.status != "queued": continue
		var index := _vacant_slot(int(entry.facility_id))
		if index < 0 or not _reachable(layout.find_object(int(entry.facility_id))): continue
		entry.slot = index
		entry.status = "reserved"
		entry.claim_held = true
		entry.reserved_at = _clock
	_pair_courts()

func _pair_courts() -> void:
	for entry in _tickets:
		if entry.activity not in ResortServices.PAIRED or entry.status != "reserved" or entry.partner_id > 0: continue
		for other in _tickets:
			if other.person_id == entry.person_id or other.facility_id != entry.facility_id or other.status != "reserved" or other.partner_id > 0: continue
			# With two places, FIFO admission selects the pair. A companion hint
			# can never reserve an absent person or jump an older waiting guest.
			entry.partner_id = other.person_id
			other.partner_id = entry.person_id
			entry.match_id = _match_id(entry, other)
			other.match_id = entry.match_id
			break
	for entry in _tickets:
		if entry.activity not in ResortServices.PAIRED or entry.status != "reserved" or not entry.arrived or entry.partner_id == 0: continue
		var other := _find(int(entry.partner_id))
		if not other.is_empty() and other.status == "reserved" and other.arrived:
			_admit(entry)
			_admit(other)

func _match_id(a: Dictionary, b: Dictionary) -> String:
	return "court:%d:%d:%d" % [a.facility_id, mini(int(a.sequence), int(b.sequence)), maxi(int(a.sequence), int(b.sequence))]

func _admit(entry: Dictionary) -> void:
	if entry.admitted: return
	entry.status = "active"
	entry.admitted = true
	entry.active_at = _clock

func _expire(person_id: int, time: float, reason: String) -> void:
	var entry := _find(person_id)
	if entry.is_empty() or entry.status == "expired": return
	var partner_id := int(entry.partner_id)
	entry.status = "expired"
	entry.expired_at = time
	entry.reason = reason
	entry.partner_id = 0
	entry.match_id = ""
	if entry.claim_held and not entry.arrived and not _observed_inside(entry): entry.claim_held = false
	_queue_cache.clear()
	if partner_id > 0: _expire(partner_id, time, "The other player's reservation ended.")

func _deadline(entry: Dictionary,peers: Dictionary={}) -> float:
	match entry.status:
		"queued": return float(entry.requested_at) + QUEUE_TIMEOUT
		"reserved":
			if entry.arrived:
				var partner: Dictionary=peers.get(int(entry.partner_id),{}) if not peers.is_empty() else _find(int(entry.partner_id))
				# A committed second player needs time to walk the actual route.
				# Their existing bounded reservation owns that arrival deadline.
				if not partner.is_empty() and partner.status=="reserved" and partner.claim_held and not partner.arrived and partner.partner_id==entry.person_id:
					return maxf(float(entry.arrived_at)+PARTNER_TIMEOUT,float(partner.reserved_at)+RESERVATION_TIMEOUT)
				return float(entry.arrived_at) + PARTNER_TIMEOUT
			return float(entry.reserved_at) + RESERVATION_TIMEOUT
		"active": return float(entry.active_at) + ACTIVE_TIMEOUT
		"expired":
			if entry.claim_held and not _people_bound: return float(entry.expired_at) + EXIT_TIMEOUT
	return INF

func _process_time(target: float) -> void:
	# Resolve chronological deadlines, so one long elapsed-time update cannot
	# give newly promoted reservations a different lifetime from small steps.
	while true:
		var deadline := INF
		for entry in _tickets: deadline = minf(deadline, _deadline(entry))
		if deadline > target + EPSILON: break
		_clock = maxf(_clock, deadline)
		for entry in _tickets:
			if _deadline(entry) > _clock + EPSILON: continue
			if entry.status == "expired":
				entry.claim_held = false
				_queue_cache.clear()
			else: _expire(int(entry.person_id), deadline, "The facility wait or visit timed out.")
		_clear_exits()
		_promote()
	_clock = maxf(_clock, target)

func _clear_exits() -> void:
	if not _people_bound: return
	for entry in _tickets:
		if entry.status != "expired" or not entry.claim_held: continue
		if not _observed_inside(entry):
			entry.claim_held = false
			_queue_cache.clear()

func _observed_inside(entry: Dictionary) -> bool:
	if not _people.has(int(entry.person_id)): return false
	var guest: Dictionary = _people[int(entry.person_id)]
	if guest.get("state") not in INSIDE_STATES or not guest.get("motion") is GuestMotion: return false
	if guest.get("facility_id") != entry.facility_id: return false
	var record := layout.find_object(int(entry.facility_id))
	if record.is_empty(): return false
	return layout.object_rect(record).grow(0.25).has_point((guest.motion as GuestMotion).position)

func _prune_expired() -> void:
	var count := 0
	for entry in _tickets:
		if entry.status == "expired" and not entry.claim_held: count += 1
	var index := 0
	while count > EXPIRED_LIMIT and index < _tickets.size():
		var entry: Dictionary = _tickets[index]
		if entry.status == "expired" and not entry.claim_held:
			_tickets.remove_at(index)
			count -= 1
		else: index += 1

func _navigation() -> AStarGrid2D:
	if _graph == null or _revision != layout.revision:
		_graph = layout.navigation()
		_revision = layout.revision
		_queue_cache.clear()
	return _graph

func _invalidate_navigation() -> void:
	_graph = null
	_revision = -1
	_queue_cache.clear()

func _door(record: Dictionary) -> Vector2i:
	return Vector2i(record.position) + ResortCatalog.entrance(record.kind, int(record.orientation))

func _open(graph: AStarGrid2D, cell: Vector2i) -> bool:
	return graph.is_in_boundsv(cell) and not graph.is_point_solid(cell)

func _connected(graph: AStarGrid2D, cell: Vector2i) -> bool:
	return _open(graph, ResortLayout.ARRIVAL) and _open(graph, cell) and not graph.get_id_path(ResortLayout.ARRIVAL, cell).is_empty()

func _reachable(record: Dictionary) -> bool:
	return not record.is_empty() and _connected(_navigation(), _door(record))

func _station_allowed(map: ResortLayout, graph: AStarGrid2D, cell: Vector2i) -> bool:
	if not _open(graph, cell) or Vector2(cell).distance_to(Vector2(ResortLayout.ARRIVAL)) < 1.05: return false
	for record in map.objects:
		if ResortCatalog.definition(record.kind).get("access", false) and Vector2(cell).distance_to(Vector2(_door(record))) < 1.05: return false
	return true

func _waiting_point(record: Dictionary) -> Vector2:
	_navigation()
	if _queue_cache.has(int(record.id)): return _queue_cache[int(record.id)]
	var graph := _navigation()
	var used: Dictionary = {}
	for entry in _tickets:
		if entry.status != "expired" or entry.claim_held: used[Vector2i((entry.queue_position as Vector2).round())] = true
	# Each ticket retains its station while admitted as well. A newcomer cannot
	# stand on a just-promoted walker before that walker clears the queue.
	for cell: Vector2i in used:
		if not _open(graph, cell):
			_queue_cache[int(record.id)] = Vector2(INF, INF)
			return Vector2(INF, INF)
	for cell: Vector2i in used: graph.set_point_solid(cell, true)
	var door := _door(record)
	var frontier: Array[Vector2i] = [door]
	var distances: Dictionary = {door: 0}
	var cursor := 0
	var point := Vector2(INF, INF)
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		var distance := int(distances[cell])
		if not used.has(cell) and _station_allowed(layout, graph, cell):
			# Restore the used cells while the common validator stages all
			# stations together, including access to earlier waiting stations.
			for prior: Vector2i in used: graph.set_point_solid(prior, false)
			var proposed := used.duplicate()
			proposed[cell] = true
			var safe := _lanes_connected(layout, graph, proposed)
			for prior: Vector2i in used: graph.set_point_solid(prior, true)
			if safe:
				point = Vector2(cell)
				break
		if distance >= MAX_QUEUE_DISTANCE: continue
		for offset: Vector2i in DIRECTIONS:
			var next := cell + offset
			if not distances.has(next) and _open(graph, next):
				distances[next] = distance + 1
				frontier.append(next)
	for cell: Vector2i in used:
		graph.set_point_solid(cell, false)
	_queue_cache[int(record.id)] = point
	return point

func _doors_connected(map: ResortLayout, graph: AStarGrid2D) -> bool:
	if not _open(graph, ResortLayout.ARRIVAL): return false
	for record in map.objects:
		if ResortCatalog.definition(record.kind).get("access", false) and not _connected(graph, _door(record)): return false
	return true

func _lanes_connected(map: ResortLayout, graph: AStarGrid2D, stations: Dictionary) -> bool:
	if stations.is_empty(): return true
	var blocked: Array[Vector2i] = []
	for cell: Vector2i in stations:
		if not _open(graph, cell): return false
		blocked.append(cell)
	# Always restore the graph before returning; callers may share the cache.
	for cell in blocked: graph.set_point_solid(cell, true)
	var valid := _doors_connected(map, graph)
	for cell in blocked:
		if not valid: break
		var has_access := false
		for offset: Vector2i in DIRECTIONS:
			if _connected(graph, cell + offset):
				has_access = true
				break
		if not has_access: valid = false
	for cell in blocked: graph.set_point_solid(cell, false)
	return valid

func _valid_clock(value: float) -> bool:
	return _number(value, 0.0, MAX_TIME) and value + EPSILON >= _clock

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, float(minimum), float(maximum)) and float(value) == floorf(float(value))
