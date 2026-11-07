class_name CleanlinessSystem
extends RefCounted
## Event-driven local dirt and exclusive, physically reached cleanup jobs.
## Owns no population, ledger, player files or independent simulation clock.

const DAY_SECONDS := 180.0
const DAILY_WAGE := 30
const MAX_STAFF := 3
const MAX_MESS := 32
const MAX_MESS_PER_FACILITY := 8
const STEP := 1.0 / 30.0
const CLEAN_SECONDS := {"litter": 4.5, "spill": 6.0}
const DIRT_CHANCE := {"meal": 0.65, "sunbathe": 0.35, "volleyball": 0.40, "gym": 0.34, "sauna": 0.32, "ice_cream": 0.45, "restaurant": 0.65, "yoga": 0.18, "massage": 0.21, "gear": 0.30, "pickleball": 0.40}
const FACILITY_KIND := ResortServices.KINDS
const SCORE_RADIUS := 4.5
const EPS := 0.000001
# Allow accumulated rounding when a saved root is partway through a step.
const ROUTE_EPS := 0.0001
const NAMES := ["Rina", "Ada", "Noor"]
const ARRIVAL_SPAWN_OFFSETS := [Vector2i(-2, 0), Vector2i(-1, 1), Vector2i(-3, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
const STANDBY_CLEARANCE := 128.0

var layout: ResortLayout
var assets: ResortAssets
var mess: Array[Dictionary] = []
var staff: Array[Dictionary] = []
var total_wages := 0
var _clock := 0.0
var _pending_time := 0.0
var _next_mess_id := 1
var _next_staff_id := 1
var _wage_day := 0
var _rng := RandomNumberGenerator.new()
var _events: Array[Dictionary] = []
var _recent_visits: Array[String] = []
var _graph: AStarGrid2D
var _revision := -1
var _standby_revision := -1
var _standby_points: Array[Vector2] = []

func configure(map: ResortLayout, library: ResortAssets) -> void:
	layout = map
	assets = library
	mess.clear()
	staff.clear()
	_events.clear()
	_recent_visits.clear()
	_clock = 0.0
	_pending_time = 0.0
	_next_mess_id = 1
	_next_staff_id = 1
	_wage_day = 0
	total_wages = 0
	_rng.seed = 194731
	_revision = -1
	_standby_revision = -1
	_navigation()

func advance(delta: float, clock: float) -> void:
	if layout == null or not _number(delta, 0.0, 1200.0) or not _number(clock, 0.0) or clock < _clock: return
	# A zero-time sync is useful after importing a legacy guest-only save. It
	# cannot bill staff or advance a cleaning pose while the world is paused.
	if delta == 0.0:
		if staff.is_empty():
			_clock = clock
			_wage_day = floori(clock / DAY_SECONDS)
		return
	if clock <= _clock: return
	if not staff.is_empty() and clock - _clock > 1200.0 + EPS: return
	if layout.revision != _revision: layout_changed()
	_clock = clock
	_pay_completed_days()
	_pending_time += delta
	var steps := mini(36000, floori((_pending_time + 0.00000001) / STEP))
	_pending_time = maxf(0.0, _pending_time - steps * STEP)
	for tick in steps:
		for cleaner in staff: _advance_staff(cleaner, STEP)

func on_activity_finished(person_id: int, facility_id: int, activity: String, clock: float) -> void:
	if layout == null or person_id < 1 or not activity in DIRT_CHANCE or not _number(clock, 0.0) or clock > _clock + STEP: return
	var facility := layout.find_object(facility_id)
	if facility.get("kind", "") != FACILITY_KIND[activity]: return
	var receipt := "%d/%d/%s/%s" % [person_id, facility_id, activity, String.num(clock, 6)]
	if receipt in _recent_visits: return
	_recent_visits.append(receipt)
	if _recent_visits.size() > 128: _recent_visits.pop_front()
	if mess.size() >= MAX_MESS: return
	var local_count := 0
	for dirt in mess:
		if dirt.facility_id == facility_id: local_count += 1
	if local_count >= MAX_MESS_PER_FACILITY or _rng.randf() > DIRT_CHANCE[activity]: return
	var candidates := _mess_candidates(facility)
	if candidates.is_empty(): return
	var point: Vector2 = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var kind := "spill" if activity in ResortServices.FOOD and _rng.randf() < 0.40 else "litter"
	mess.append({"id": _next_mess_id, "kind": kind, "position": point, "facility_id": facility_id,
		"created_at": clock, "claimed_by": 0, "style": _rng.randi_range(0, 3)})
	_next_mess_id += 1

func score_at(position: Vector2) -> float:
	if not position.is_finite(): return 100.0
	var penalty := 0.0
	for dirt in mess:
		var distance := position.distance_to(dirt.position)
		if distance >= SCORE_RADIUS: continue
		var weight := 1.0 - distance / SCORE_RADIUS
		penalty += (24.0 if dirt.kind == "spill" else 19.0) * weight
	return clampf(100.0 - penalty, 0.0, 100.0)

func hire() -> Dictionary:
	if layout == null: return {"ok": false, "reason": "The resort is not ready.", "id": 0}
	if staff.size() >= MAX_STAFF: return {"ok": false, "reason": "All three janitor positions are filled.", "id": 0}
	var point := _hire_point()
	if not point.is_finite(): return {"ok": false, "reason": "Reconnect the arrival path before hiring.", "id": 0}
	var motion := GuestMotion.new()
	motion.position = point
	var cleaner := {"id": _next_staff_id, "name": NAMES[(_next_staff_id - 1) % NAMES.size()], "state": "idle",
		"motion": motion, "target_mess_id": 0, "stand_position": point, "activity_elapsed": 0.0,
		"hired_at": _clock, "last_wage_day": _wage_day, "cleaned_count": 0, "reason": "Ready to clean the resort."}
	staff.append(cleaner)
	_next_staff_id += 1
	return {"ok": true, "reason": "%s hired · $30 per completed resort day." % cleaner.name, "id": cleaner.id}

func dismiss(staff_id: int) -> bool:
	for index in staff.size():
		if staff[index].id != staff_id: continue
		_release_claim(staff[index])
		staff.remove_at(index)
		for cleaner in staff:
			if cleaner.state == "returning": _release_claim(cleaner)
		return true
	return false

func inspect() -> Dictionary:
	var dirt_view: Array[Dictionary] = []
	var staff_view: Array[Dictionary] = []
	var total_score := 0.0
	for dirt in mess:
		dirt_view.append(dirt.duplicate(true))
		total_score += score_at(dirt.position)
	for cleaner in staff:
		var motion: GuestMotion = cleaner.motion
		var dirt := _mess(cleaner.target_mess_id)
		staff_view.append({"id": cleaner.id, "name": cleaner.name, "role": "Janitor", "state": cleaner.state,
			"position": motion.position, "direction": motion.direction, "distance": motion.distance, "moving": motion.moving,
			"target_mess_id": cleaner.target_mess_id, "activity_elapsed": cleaner.activity_elapsed,
			"progress": clampf(cleaner.activity_elapsed / CLEAN_SECONDS.get(dirt.get("kind", "litter"), 4.5), 0, 1) if cleaner.state == "cleaning" else 0.0,
			"cleaned_count": cleaner.cleaned_count, "wage": DAILY_WAGE, "daily_wage": DAILY_WAGE, "reason": cleaner.reason})
	return {"mess": dirt_view, "staff": staff_view, "cleanliness": total_score / mess.size() if not mess.is_empty() else 100.0,
		"hired_count": staff.size(), "max_staff": MAX_STAFF, "daily_wage": DAILY_WAGE, "mess_count": mess.size(), "clock": _clock, "total_wages": total_wages}

func access_survives(candidate: ResortLayout) -> bool:
	if candidate == null: return false
	var graph := candidate.navigation()
	for dirt in mess:
		if not _reachable(graph, dirt.position): return false
	for cleaner in staff:
		var motion: GuestMotion = cleaner.motion
		# An occupied edge or corner stays open around a fractional root.
		if not _position_open(graph, motion.position) or not _reachable(graph, motion.position): return false
		if cleaner.state == "cleaning" and not _position_open(graph, cleaner.stand_position): return false
	return true

func layout_changed() -> void:
	_revision = -1
	var graph := _navigation()
	for index in range(mess.size() - 1, -1, -1):
		if not _reachable(graph, mess[index].position):
			var cleaner := _staff(mess[index].claimed_by)
			if not cleaner.is_empty(): _release_claim(cleaner)
			mess.remove_at(index)
	for cleaner in staff:
		var motion: GuestMotion = cleaner.motion
		if not _position_open(graph, motion.position):
			_release_claim(cleaner)
			cleaner.reason = "Reconnect the path beneath this janitor."
			continue
		if cleaner.state == "walking" and not _remaining_route_open(motion, graph):
			var dirt := _mess(cleaner.target_mess_id)
			if dirt.is_empty() or not _set_job_route(cleaner, dirt): _release_claim(cleaner)
		elif cleaner.state == "returning" and (not _remaining_route_open(motion, graph) or cleaner.stand_position != _standby_point(cleaner)):
			_release_claim(cleaner)

func capture() -> Dictionary:
	var saved_mess: Array[Dictionary] = []
	var saved_staff: Array[Dictionary] = []
	for dirt in mess:
		var entry := dirt.duplicate(true)
		entry.position = _encode(dirt.position)
		saved_mess.append(entry)
	for cleaner in staff:
		var entry := cleaner.duplicate(true)
		entry.motion = (cleaner.motion as GuestMotion).capture()
		entry.moving = (cleaner.motion as GuestMotion).moving
		entry.stand_position = _encode(cleaner.stand_position)
		saved_staff.append(entry)
	return {"version": 1, "clock": _clock, "pending_time": _pending_time, "wage_day": _wage_day,
		"next_mess_id": _next_mess_id, "next_staff_id": _next_staff_id, "total_wages": total_wages, "rng_seed": str(_rng.seed), "rng_state": str(_rng.state),
		"mess": saved_mess, "staff": saved_staff, "pending_events": _events.duplicate(true), "recent_visits": _recent_visits.duplicate()}

func restore(data: Dictionary) -> bool:
	if layout == null: return false
	var candidate := get_script().new() as RefCounted
	candidate.configure(layout, assets)
	if not candidate._decode_snapshot(data): return false
	for key in ["mess", "staff", "total_wages", "_clock", "_pending_time", "_next_mess_id", "_next_staff_id", "_wage_day", "_events", "_recent_visits"]:
		set(key, candidate.get(key))
	_rng.seed = candidate.get("_rng").seed
	_rng.state = candidate.get("_rng").state
	return true

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = _events.duplicate(true)
	_events.clear()
	return result

func _pay_completed_days() -> void:
	var completed := floori(_clock / DAY_SECONDS)
	if staff.is_empty():
		_wage_day = completed
		return
	for day in range(_wage_day + 1, completed + 1):
		for cleaner in staff:
			if day <= cleaner.last_wage_day or cleaner.hired_at >= day * DAY_SECONDS: continue
			_events.append({"id": "staff:wage:%d:%d" % [cleaner.id, day], "kind": "wage", "amount": -DAILY_WAGE,
				"time": day * DAY_SECONDS, "staff_id": cleaner.id})
			total_wages += DAILY_WAGE
			cleaner.last_wage_day = day
	_wage_day = completed

func _advance_staff(cleaner: Dictionary, delta: float) -> void:
	var motion: GuestMotion = cleaner.motion
	motion.moving = false
	var remaining := delta
	for transition in 8:
		if remaining <= EPS: break
		if cleaner.state == "returning" and cleaner.stand_position != _standby_point(cleaner):
			_release_claim(cleaner)
		if cleaner.state in ["idle", "returning"] and not _claim_job(cleaner):
			if cleaner.state == "idle" and not _start_standby_walk(cleaner): break
			remaining -= _advance_walk(motion, remaining)
			if not motion.finished(): break
			_release_claim(cleaner)
			continue
		var dirt := _mess(cleaner.target_mess_id)
		if dirt.is_empty() or dirt.claimed_by != cleaner.id:
			_release_claim(cleaner)
			continue
		if cleaner.state == "walking":
			remaining -= _advance_walk(motion, remaining)
			if not motion.finished(): break
			if motion.position.distance_to(dirt.position) > 0.5 + EPS:
				_release_claim(cleaner)
				continue
			motion.route.clear()
			motion.index = 0
			motion.delay = 0.0
			motion.moving = false
			var heading: Vector2 = dirt.position - motion.position
			if heading.length_squared() > EPS: motion.direction = heading.normalized()
			cleaner.state = "cleaning"
			cleaner.activity_elapsed = 0.0
			cleaner.reason = "Sweeping a spill." if dirt.kind == "spill" else "Sweeping up litter."
		if cleaner.state == "cleaning":
			if motion.position.distance_to(dirt.position) > 0.5 + EPS:
				_release_claim(cleaner)
				continue
			var duration: float = CLEAN_SECONDS[dirt.kind]
			var amount := minf(remaining, maxf(0.0, duration - cleaner.activity_elapsed))
			cleaner.activity_elapsed += amount
			remaining -= amount
			if cleaner.activity_elapsed + EPS < duration: break
			mess.erase(dirt)
			cleaner.cleaned_count += 1
			_release_claim(cleaner)

func _advance_walk(motion: GuestMotion, delta: float) -> float:
	var travel := _motion_seconds(motion)
	var amount := minf(delta, travel)
	if travel <= EPS and not motion.route.is_empty():
		motion.distance += motion.position.distance_to(motion.route[-1])
		motion.position = motion.route[-1]
		motion.index = motion.route.size()
		motion.delay = 0.0
	else:
		motion.advance(amount)
	return amount

func _start_standby_walk(cleaner: Dictionary) -> bool:
	var motion: GuestMotion = cleaner.motion
	var point := _standby_point(cleaner)
	if not point.is_finite() or motion.position.distance_to(point) <= ROUTE_EPS: return false
	var route := _route_to(motion.position, point)
	if route.is_empty(): return false
	cleaner.state = "returning"
	cleaner.stand_position = point
	cleaner.reason = "Walking back to standby."
	motion.set_route(route)
	motion.delay = 0.0
	return true

func _standby_point(cleaner: Dictionary) -> Vector2:
	var slot := staff.find(cleaner)
	var points := _available_standby_points()
	return points[slot] if slot >= 0 and slot < points.size() else Vector2.INF

func _available_standby_points() -> Array[Vector2]:
	if _standby_revision == layout.revision: return _standby_points
	_standby_revision = layout.revision
	_standby_points.clear()
	var graph := _navigation()
	var entrances: Array[Vector2i] = [ResortLayout.ARRIVAL]
	var services: Array[Vector2i] = []
	for record in layout.objects:
		if not ResortCatalog.definition(record.kind).get("access", false): continue
		var entrance := Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)
		entrances.append(entrance)
		if record.kind in FACILITY_KIND.values(): services.append(entrance)
	var candidates := {}
	var screen_arrival := IsometricGrid.project(Vector2(ResortLayout.ARRIVAL))
	for entrance in services:
		for y in range(entrance.y - 3, entrance.y + 4):
			for x in range(entrance.x - 3, entrance.x + 4):
				var cell := Vector2i(x, y)
				if candidates.has(cell) or cell.distance_squared_to(entrance) > 12: continue
				var screen := IsometricGrid.project(Vector2(cell))
				if screen.distance_to(screen_arrival) < STANDBY_CLEARANCE: continue
				if entrances.any(func(door: Vector2i) -> bool: return cell.distance_squared_to(door) < 4):
					continue
				if _reachable(graph, Vector2(cell)): candidates[cell] = screen
	# Start near a working facility, then cover the greatest gaps between posts.
	var screens: Array[Vector2] = []
	for slot in MAX_STAFF:
		var best := Vector2.INF
		var separation := STANDBY_CLEARANCE - 0.001
		for cell: Vector2i in candidates:
			var screen: Vector2 = candidates[cell]
			var distance := INF
			for other in screens:
				distance = minf(distance, screen.distance_to(other))
			if distance <= separation: continue
			best = Vector2(cell)
			separation = distance
		if not best.is_finite(): break
		_standby_points.append(best)
		screens.append(candidates[Vector2i(best)])
	return _standby_points

func _claim_job(cleaner: Dictionary) -> bool:
	var motion: GuestMotion = cleaner.motion
	if not _position_open(_navigation(), motion.position): return false
	var best: Dictionary = {}
	var best_route: Array[Vector2] = []
	var best_distance := INF
	for dirt in mess:
		if dirt.claimed_by != 0: continue
		var route := _route_to(motion.position, dirt.position)
		if route.is_empty(): continue
		var length := _route_length(motion.position, route)
		if length < best_distance:
			best = dirt
			best_route = route
			best_distance = length
	if best.is_empty():
		if cleaner.state == "idle":
			cleaner.reason = "On standby. Waiting for litter or spills." if mess.is_empty() else "No unclaimed cleanup job within reach."
		return false
	_set_job_route(cleaner, best, best_route)
	best.claimed_by = cleaner.id
	cleaner.target_mess_id = best.id
	cleaner.state = "walking"
	cleaner.activity_elapsed = 0.0
	cleaner.reason = "Walking to a claimed cleanup job."
	return true

func _set_job_route(cleaner: Dictionary, dirt: Dictionary, route: Array[Vector2] = []) -> bool:
	var motion: GuestMotion = cleaner.motion
	if route.is_empty(): route = _route_to(motion.position, dirt.position)
	if route.is_empty(): return false
	var prior: Vector2 = route[-2] if route.size() > 1 else motion.position
	var heading: Vector2 = dirt.position - prior
	var stand: Vector2 = dirt.position
	if heading.length() > 0.4: stand -= heading.normalized() * 0.4
	elif route.size() == 1: stand = prior
	route[-1] = stand
	cleaner.stand_position = stand
	motion.set_route(route)
	motion.delay = 0.0
	return true

func _release_claim(cleaner: Dictionary) -> void:
	var dirt := _mess(cleaner.target_mess_id)
	if not dirt.is_empty() and dirt.claimed_by == cleaner.id: dirt.claimed_by = 0
	var motion: GuestMotion = cleaner.motion
	motion.route.clear()
	motion.index = 0
	motion.delay = 0.0
	motion.moving = false
	cleaner.state = "idle"
	cleaner.target_mess_id = 0
	cleaner.stand_position = motion.position
	cleaner.activity_elapsed = 0.0
	cleaner.reason = "Ready for the next cleanup job."

func _mess(id: int) -> Dictionary:
	for dirt in mess:
		if dirt.id == id: return dirt
	return {}

func _staff(id: int) -> Dictionary:
	for cleaner in staff:
		if cleaner.id == id: return cleaner
	return {}

func _navigation() -> AStarGrid2D:
	if layout != null and (_graph == null or _revision != layout.revision):
		_graph = layout.navigation(-1, true)
		_revision = layout.revision
	return _graph

func _mess_candidates(facility: Dictionary) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var graph := _navigation()
	var door := Vector2i(facility.position) + ResortCatalog.entrance(facility.kind, facility.orientation)
	for y in range(door.y - 3, door.y + 4):
		for x in range(door.x - 3, door.x + 4):
			var cell := Vector2i(x, y)
			var point := Vector2(cell)
			if point.distance_to(Vector2(door)) > 3.5 or _protected_entrance(cell) or not _reachable(graph, point): continue
			var occupied := false
			for dirt in mess:
				if point.distance_to(dirt.position) < 0.8:
					occupied = true
					break
			if not occupied: candidates.append(point)
	return candidates

func _protected_entrance(cell: Vector2i) -> bool:
	if cell == ResortLayout.ARRIVAL: return true
	for record in layout.objects:
		if ResortCatalog.definition(record.kind).get("access", false):
			if Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation) == cell: return true
	return false

func _hire_point() -> Vector2:
	var graph := _navigation()
	for offset: Vector2i in ARRIVAL_SPAWN_OFFSETS:
		var point := Vector2(ResortLayout.ARRIVAL + offset)
		if not _reachable(graph, point): continue
		var occupied := false
		for cleaner in staff:
			if (cleaner.motion as GuestMotion).position.distance_to(point) < 0.75: occupied = true
		if not occupied: return point
	return Vector2(INF, INF)

func _route_to(start: Vector2, end: Vector2) -> Array[Vector2]:
	var best_route: Array[Vector2] = []
	var graph := _navigation()
	if not _position_open(graph, start) or not _position_open(graph, end): return best_route
	var best_distance := INF
	# A broom stance can end between tile centres. Route through either
	# reachable end of the occupied edge instead of stepping back to round().
	for x in range(floori(start.x + EPS), ceili(start.x - EPS) + 1):
		for y in range(floori(start.y + EPS), ceili(start.y - EPS) + 1):
			var cell := Vector2i(x, y)
			if not _route_step_open(graph, start, Vector2(cell)): continue
			var route: Array[Vector2] = []
			for point in graph.get_id_path(cell, Vector2i(end.round())):
				route.append(Vector2(point))
			if route.is_empty(): continue
			var distance := _route_length(start, route)
			if distance >= best_distance: continue
			best_distance = distance
			best_route = route
	return best_route

static func _route_length(start: Vector2, points: Array[Vector2]) -> float:
	var length := 0.0
	for point in points:
		length += start.distance_to(point)
		start = point
	return length

static func _motion_seconds(motion: GuestMotion) -> float:
	var points: Array[Vector2] = motion.route.slice(motion.index)
	return motion.delay + _route_length(motion.position, points) / 1.2

static func _cell_open(graph: AStarGrid2D, cell: Vector2i) -> bool:
	return graph != null and graph.is_in_boundsv(cell) and not graph.is_point_solid(cell)

static func _position_open(graph: AStarGrid2D, point: Vector2) -> bool:
	if not point.is_finite(): return false
	for x in [floori(point.x + EPS), ceili(point.x - EPS)]:
		for y in [floori(point.y + EPS), ceili(point.y - EPS)]:
			if not _cell_open(graph, Vector2i(x, y)): return false
	return true

static func _reachable(graph: AStarGrid2D, point: Vector2) -> bool:
	return _position_open(graph, point) and _cell_open(graph, ResortLayout.ARRIVAL) and not graph.get_id_path(ResortLayout.ARRIVAL, Vector2i(point.round())).is_empty()

static func _remaining_route_open(motion: GuestMotion, graph: AStarGrid2D) -> bool:
	var previous := motion.position
	for index in range(motion.index, motion.route.size()):
		var point := motion.route[index]
		if not _route_step_open(graph, previous, point): return false
		previous = point
	return true

static func _route_step_open(graph: AStarGrid2D, from: Vector2, to: Vector2) -> bool:
	var offset := (to - from).abs()
	if maxf(offset.x, offset.y) > 1.001: return false
	if not _position_open(graph, from) or not _position_open(graph, to): return false
	if offset.x <= ROUTE_EPS or offset.y <= ROUTE_EPS: return true
	return absf(offset.x - offset.y) <= ROUTE_EPS and _position_open(graph, Vector2(from.x, to.y)) and _position_open(graph, Vector2(to.x, from.y))

static func _encode(point: Vector2) -> Array:
	return [point.x, point.y]

static func _number(value: Variant, minimum: float, maximum: float = 1000000000000.0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _integer(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -0.5, ResortLayout.MAP_SIZE.x - 0.5) and _number(value[1], ResortLayout.INLAND_START - 0.5, ResortLayout.WALKABLE_END - 0.5)

static func _int64_string(value: Variant) -> bool:
	if not value is String or not value.is_valid_int(): return false
	var digits: String = value.trim_prefix("-")
	if digits.length() > 19: return false
	if digits.length() == 19 and digits > ("9223372036854775808" if value.begins_with("-") else "9223372036854775807"): return false
	return str(int(value)) == value

func _decode_snapshot(data: Dictionary) -> bool:
	if not _integer(data.get("version"), 1, 1) or not _number(data.get("clock"), 0): return false
	if not _number(data.get("pending_time"), 0, 1200): return false
	if not _integer(data.get("wage_day")) or data.wage_day != floori(data.clock / DAY_SECONDS): return false
	if not _integer(data.get("total_wages"), 0, int(data.wage_day) * MAX_STAFF * DAILY_WAGE) or int(data.total_wages) % DAILY_WAGE != 0: return false
	for key in ["next_mess_id", "next_staff_id"]:
		if not _integer(data.get(key), 1): return false
	for key in ["rng_seed", "rng_state"]:
		if not _int64_string(data.get(key)): return false
	for key in ["mess", "staff", "pending_events", "recent_visits"]:
		if not data.get(key) is Array: return false
	if data.mess.size() > MAX_MESS or data.staff.size() > MAX_STAFF or data.recent_visits.size() > 128 or data.pending_events.size() > 100000: return false
	var graph := _navigation()
	var dirt_ids: Dictionary = {}
	var staff_ids: Dictionary = {}
	var local_counts: Dictionary = {}
	var minimum_wages := 0
	for entry: Variant in data.mess:
		if not entry is Dictionary or not _integer(entry.get("id"), 1, int(data.next_mess_id) - 1) or dirt_ids.has(int(entry.id)): return false
		if entry.get("kind") not in CLEAN_SECONDS or not _point(entry.get("position")): return false
		if not _integer(entry.get("facility_id"), 1) or not _number(entry.get("created_at"), 0, data.clock + STEP): return false
		if not _integer(entry.get("claimed_by"), 0, int(data.next_staff_id) - 1) or not _integer(entry.get("style"), 0, 3): return false
		var point := Vector2(entry.position[0], entry.position[1])
		if point != point.round() or not _reachable(graph, point) or _protected_entrance(Vector2i(point)): return false
		for prior in mess:
			if point.distance_to(prior.position) < 0.8: return false
		# A removed/moved facility can leave genuine litter behind. Its historical
		# source id remains valid provenance; the dirt itself must stay reachable.
		local_counts[int(entry.facility_id)] = local_counts.get(int(entry.facility_id), 0) + 1
		if local_counts[int(entry.facility_id)] > MAX_MESS_PER_FACILITY: return false
		var dirt: Dictionary = entry.duplicate(true)
		dirt.position = point
		mess.append(dirt)
		dirt_ids[int(dirt.id)] = dirt
	for entry: Variant in data.staff:
		if not entry is Dictionary or not _integer(entry.get("id"), 1, int(data.next_staff_id) - 1) or staff_ids.has(int(entry.id)): return false
		if not entry.get("name") is String or entry.name.is_empty() or not entry.get("reason") is String: return false
		if entry.get("state") not in ["idle", "walking", "cleaning", "returning"] or not entry.get("moving") is bool or not entry.get("motion") is Dictionary: return false
		if not _integer(entry.get("target_mess_id")) or not _point(entry.get("stand_position")): return false
		if not _number(entry.get("activity_elapsed"), 0, 6.0) or not _number(entry.get("hired_at"), 0, data.clock): return false
		if not _integer(entry.get("last_wage_day"), 0, int(data.wage_day)) or entry.last_wage_day != data.wage_day: return false
		minimum_wages += (int(data.wage_day) - floori(entry.hired_at / DAY_SECONDS)) * DAILY_WAGE
		if not _integer(entry.get("cleaned_count")): return false
		var motion := GuestMotion.new()
		if not motion.restore(entry.motion) or motion.delay > 0.6 + EPS or motion.direction.length() > 1.001: return false
		if not _reachable(graph, motion.position) or not _remaining_route_open(motion, graph): return false
		motion.moving = entry.moving
		var stand := Vector2(entry.stand_position[0], entry.stand_position[1])
		if not _position_open(graph, stand): return false
		if entry.state == "idle":
			if entry.target_mess_id != 0 or not motion.route.is_empty() or entry.activity_elapsed != 0 or entry.moving or stand.distance_to(motion.position) > EPS: return false
		elif entry.state == "returning":
			if entry.target_mess_id != 0 or entry.activity_elapsed != 0 or motion.route.is_empty() or motion.finished() or motion.route[-1].distance_to(stand) > EPS: return false
			if stand != stand.round(): return false
			# Prior saves can still be walking to the old arrival posts. The
			# first simulation tick sends them to the new distributed posts.
			if not _available_standby_points().has(stand) and not ARRIVAL_SPAWN_OFFSETS.has(Vector2i(stand) - ResortLayout.ARRIVAL): return false
		else:
			if not dirt_ids.has(int(entry.target_mess_id)): return false
			var dirt: Dictionary = dirt_ids[int(entry.target_mess_id)]
			if dirt.claimed_by != entry.id or stand.distance_to(dirt.position) > 0.5 + EPS: return false
			if entry.state == "cleaning":
				if not motion.route.is_empty() or entry.moving or not motion.finished() or motion.position.distance_to(stand) > EPS: return false
				if entry.activity_elapsed >= CLEAN_SECONDS[dirt.kind]: return false
			else:
				if motion.route.is_empty() or motion.finished() or entry.activity_elapsed != 0 or motion.route[-1].distance_to(stand) > EPS: return false
		var cleaner: Dictionary = entry.duplicate(true)
		cleaner.erase("moving")
		cleaner.motion = motion
		cleaner.stand_position = stand
		staff.append(cleaner)
		staff_ids[int(cleaner.id)] = cleaner
	if minimum_wages > data.total_wages: return false
	for dirt in mess:
		if dirt.claimed_by != 0 and (not staff_ids.has(int(dirt.claimed_by)) or staff_ids[int(dirt.claimed_by)].target_mess_id != dirt.id): return false
	var event_ids: Dictionary = {}
	var pending_wages := 0
	for entry: Variant in data.pending_events:
		if not entry is Dictionary or entry.get("kind") != "wage" or not _integer(entry.get("amount"), -DAILY_WAGE, -DAILY_WAGE): return false
		if not _integer(entry.get("staff_id"), 1, int(data.next_staff_id) - 1) or not _number(entry.get("time"), DAY_SECONDS, data.clock): return false
		var day := floori(entry.time / DAY_SECONDS)
		if entry.time != day * DAY_SECONDS: return false
		if staff_ids.has(int(entry.staff_id)) and entry.time <= staff_ids[int(entry.staff_id)].hired_at: return false
		var expected := "staff:wage:%d:%d" % [entry.staff_id, day]
		if entry.get("id") != expected or event_ids.has(expected): return false
		event_ids[expected] = true
		_events.append(entry.duplicate(true))
		pending_wages += DAILY_WAGE
	if pending_wages > data.total_wages: return false
	for receipt: Variant in data.recent_visits:
		if not receipt is String or receipt.is_empty() or receipt in _recent_visits: return false
		_recent_visits.append(receipt)
	_clock = float(data.clock)
	_pending_time = float(data.pending_time)
	_next_mess_id = int(data.next_mess_id)
	_next_staff_id = int(data.next_staff_id)
	_wage_day = int(data.wage_day)
	total_wages = int(data.total_wages)
	_rng.seed = int(data.rng_seed)
	_rng.state = int(data.rng_state)
	return true
