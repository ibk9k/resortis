class_name GuestStay
extends RefCounted
## One inspectable stay. UI and presentation read this state, never own bookings.

const DAY_SECONDS := 180.0
const NIGHTLY_RATE := 60
const STATES := ["arriving", "to_cabin", "entering", "resting", "exiting", "to_cafe", "sitting", "eating", "to_beach", "relaxing", "returning", "overnight", "departing", "departed", "waiting", "approaching_seats", "leaving_seats", "approaching_loungers", "leaving_loungers", "to_court", "approaching_court", "playing_volleyball", "leaving_court"]
const FACILITY_STATES := ["to_cafe","approaching_seats","sitting","eating","leaving_seats","to_beach","approaching_loungers","relaxing","leaving_loungers","to_court","approaching_court","playing_volleyball","leaving_court"]
const IN_FACILITY := ["approaching_seats","sitting","eating","leaving_seats","approaching_loungers","relaxing","leaving_loungers","approaching_court","playing_volleyball","leaving_court"]
var layout: ResortLayout
var assets: ResortAssets
var state := "arriving"
var logical_position := Vector2(ResortLayout.ARRIVAL)
var route: Array[Vector2] = []
var route_index := 0
var walked_distance := 0.0
var direction := Vector2(1, 0)
var moving := false
var clock := 0.0
var timer := 0.0
var cabin_id := -1
var facility_id := -1
var booking_rate := NIGHTLY_RATE
var nights := 2
var paid_nights := 0
var budget := 240
var accommodation_spent := 0
var activity_spent := 0
var hunger := 75.0
var rest := 65.0
var enjoyment := 60.0
var next_night := 0.0
var revenue := 0
var explanation := "Looking for an affordable cabin with a connected entrance."
var departure_reason := ""
var history: Array[String] = []
var after_exit := "cafe"
var party_size := 1
var companion := GuestMotion.new()
var activity_elapsed := 0.0

func configure(map: ResortLayout, library: ResortAssets) -> void:
	layout = map
	assets = library
	if clock == 0 and state == "arriving": budget = 240*party_size

func advance(delta: float) -> void:
	# Fixed bounded steps make route endpoints, payments and pause/speed equivalent.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 30.0)
		remaining -= step
		_tick(step)

func _tick(delta: float) -> void:
	moving = false
	if state == "departed": return
	clock += delta
	activity_elapsed += delta
	if party_size == 2: companion.advance(delta)
	hunger = maxf(0.0, hunger - delta * 0.12)
	enjoyment = maxf(0.0, enjoyment - delta * 0.03)
	rest = clampf(rest + delta * (0.5 if state in ["resting", "overnight"] else -0.04), 0.0, 100.0)
	if state in ["arriving", "waiting"]:
		timer -= delta
		if timer <= 0.0: _book()
		return
	if route_index < route.size():
		var remaining := delta * 1.2
		while remaining > 0.000001 and route_index < route.size():
			var offset := route[route_index] - logical_position
			var distance := offset.length()
			if distance < 0.000001:
				route_index += 1
				continue
			direction = offset.normalized()
			var length := minf(remaining, distance)
			logical_position += direction * length
			walked_distance += length
			remaining -= length
			moving = true
			if length >= distance - 0.000001: route_index += 1
		if route_index >= route.size() and (party_size == 1 or companion.finished()): _arrived()
		return
	if not route.is_empty():
		if party_size == 1 or companion.finished(): _arrived()
		return
	if state == "overnight":
		if clock + 0.00001 >= next_night:
			if paid_nights >= nights:
				departure_reason = "Completed a two-night beach break."
				_exit_cabin("checkout")
			elif budget >= booking_rate:
				_charge_night()
				next_night += DAY_SECONDS
				_exit_cabin("cafe")
			else:
				departure_reason = "Could not afford another night."
				_exit_cabin("checkout")
		return
	timer -= delta
	if timer > 0.0: return
	match state:
		"sitting":
			state = "eating"
			timer = 12.0
			activity_elapsed = 0.0
			explanation = "Sitting at the café and eating."
		"resting":
			rest = 100
			_exit_cabin("cafe")
		"eating":
			hunger = 100
			_leave_facility("eating","leaving_seats")
		"relaxing":
			enjoyment = 100
			_leave_facility("lying","leaving_loungers")
		"playing_volleyball":
			enjoyment = 100
			_leave_facility("volleyball","leaving_court")

func _book() -> void:
	var graph := layout.navigation()
	var best := INF
	var chosen: Dictionary = {}
	for record in layout.objects:
		if record.kind != "cabin" or budget < nights * NIGHTLY_RATE: continue
		var door := Vector2i(record.position) + ResortCatalog.entrance("cabin", record.orientation)
		var path := graph.get_id_path(ResortLayout.ARRIVAL, door)
		if not path.is_empty() and path.size() < best:
			chosen = record
			best = path.size()
	if chosen.is_empty():
		state = "waiting"
		timer = 2.0
		explanation = "Waiting for an affordable cabin with a path from arrivals."
		return
	cabin_id = chosen.id
	state = "to_cabin"
	explanation = "Chose Cabin %d: $%d per night, a private bathroom and a connected path." % [cabin_id, booking_rate]
	_event("Reserved Cabin %d for two nights." % cabin_id)
	_outdoor_route(Vector2i(chosen.position) + ResortCatalog.entrance("cabin", chosen.orientation))

func _outdoor_route(destination: Vector2i) -> bool:
	var graph := layout.navigation()
	var start := Vector2i(logical_position.round())
	if not graph.is_in_boundsv(start) or graph.is_point_solid(start) or not graph.is_in_boundsv(destination) or graph.is_point_solid(destination): return false
	var path := graph.get_id_path(start, destination)
	if path.is_empty(): return false
	route.clear()
	for point in path: route.append(Vector2(point))
	route_index = 0
	if party_size == 2:
		var other := graph.get_id_path(Vector2i(companion.position.round()), destination)
		var points: Array[Vector2] = []
		for point in other: points.append(Vector2(point))
		companion.set_route(points)
	return true

func _arrived() -> void:
	route.clear()
	route_index = 0
	companion.route.clear()
	companion.index = 0
	activity_elapsed = 0.0
	match state:
		"to_cabin", "returning":
			var pose := "sleeping"
			state = "entering"
			route = CabinInterior.aisle(layout.find_object(cabin_id), assets)
			route.append(GuestActivitySlots.slot(layout.find_object(cabin_id),pose,0,assets).position)
			if party_size == 2:
				var second := CabinInterior.aisle(layout.find_object(cabin_id), assets)
				second.append(GuestActivitySlots.slot(layout.find_object(cabin_id),pose,1,assets).position)
				companion.set_route(second)
			route_index = 0
			explanation = "Entering through the cabin's own doorway."
		"entering":
			if paid_nights == 0:
				_charge_night()
				next_night = clock + DAY_SECONDS
				_event("Checked in through the cabin door.")
				state = "resting"
				timer = 8.0
				explanation = "Settling into the cabin before lunch."
			else:
				state = "overnight"
				rest = 100
				explanation = "Resting in the cabin until the next morning."
		"exiting":
			if after_exit == "checkout":
				state = "departing"
				explanation = "Checked out. " + departure_reason
				_event(explanation)
				cabin_id = -1
				_outdoor_route(ResortLayout.ARRIVAL)
			else: _visit("cafe", "to_cafe", "Walking to the café for food and a drink.")
		"to_cafe":
			if _pay_activity(12*party_size):
				_enter_facility("eating","approaching_seats")
				explanation = "Taking a seat for food and a drink · $12 per person."
				_event("Bought food and drinks for $%d." % (12*party_size))
			else: _visit("sunbeds", "to_beach", "Keeping room money aside; heading to the beach.")
		"to_beach":
			if _pay_activity(8*party_size):
				_enter_facility("lying","approaching_loungers")
				explanation = "Heading to the reserved loungers · $8 per person."
				_event("Visited sunbathing for $%d." % (8*party_size))
			else: _go_home()
		"approaching_seats": state = "sitting"; timer = 4.0; explanation = "Taking a seat while lunch is prepared."
		"leaving_seats": _visit("sunbeds", "to_beach", "Walking to the beach for some sunshine.")
		"approaching_loungers": state = "relaxing"; timer = 16.0; explanation = "Lying back on the sunbeds."
		"leaving_loungers":
			if party_size == 2: _visit("volleyball","to_court","Walking together to the volleyball court.")
			else: _go_home()
		"to_court":
			if _pay_activity(10*party_size):
				_enter_facility("volleyball","approaching_court")
				_event("Booked a volleyball game for $%d." % (10*party_size))
			else: _go_home()
		"approaching_court": state = "playing_volleyball"; timer = 20.0; explanation = "Maya and Leo are rallying across the net."
		"leaving_court": _go_home()
		"departing":
			state = "departed"
			route.clear()
			route_index = 0
			facility_id = -1
			explanation = departure_reason
			_event("Left the resort.")

func _exit_cabin(next: String) -> void:
	after_exit = next
	state = "exiting"
	route = CabinInterior.aisle(layout.find_object(cabin_id), assets)
	route.reverse()
	var record := layout.find_object(cabin_id)
	route.append(record.position + Vector2(ResortCatalog.entrance("cabin", record.orientation)))
	route_index = 0
	if party_size == 2: companion.set_route(route)
	explanation = "Leaving through the cabin doorway."

func _enter_facility(activity: String, next: String) -> void:
	state = next
	var record := layout.find_object(facility_id)
	route = GuestActivitySlots.approach(record,activity,0,assets)
	route_index = 0
	if party_size == 2: companion.set_route(GuestActivitySlots.approach(record,activity,1,assets))

func _leave_facility(activity: String, next: String) -> void:
	_enter_facility(activity,next)
	route.reverse()
	if party_size == 2: companion.route.reverse()

func activity_slot(role: int) -> Dictionary:
	var pose: String = {"resting":"sleeping","overnight":"sleeping","sitting":"sitting","eating":"eating","relaxing":"lying","playing_volleyball":"volleyball"}.get(state,"")
	if pose.is_empty(): return {}
	return GuestActivitySlots.slot(layout.find_object(cabin_id if pose=="sleeping" else facility_id),pose,role,assets)

func _visit(kind: String, next_state: String, reason: String) -> void:
	var best := INF
	var chosen: Dictionary = {}
	var graph := layout.navigation()
	for record in layout.objects:
		if record.kind != kind: continue
		var door := Vector2i(record.position) + ResortCatalog.entrance(kind, record.orientation)
		var path := graph.get_id_path(Vector2i(logical_position.round()), door)
		if not path.is_empty() and path.size() < best:
			best = path.size()
			chosen = record
	if chosen.is_empty():
		_event("No accessible café." if kind == "cafe" else "No accessible sunbathing area.")
		if kind == "cafe": _visit("sunbeds", "to_beach", "Heading to the beach.")
		else: _go_home()
		return
	facility_id = chosen.id
	state = next_state
	explanation = reason
	_outdoor_route(Vector2i(chosen.position) + ResortCatalog.entrance(kind, chosen.orientation))

func _go_home() -> void:
	state = "returning"
	var record := layout.find_object(cabin_id)
	explanation = "Returning to the cabin to rest."
	_outdoor_route(Vector2i(record.position) + ResortCatalog.entrance("cabin", record.orientation))

func reserve() -> int:
	return maxi(0, nights - paid_nights) * booking_rate

func _charge_night() -> void:
	budget -= booking_rate
	accommodation_spent += booking_rate
	revenue += booking_rate
	paid_nights += 1
	_event("Paid $%d for night %d of %d." % [booking_rate, paid_nights, nights])

func _pay_activity(price: int) -> bool:
	if budget - reserve() < price: return false
	budget -= price
	activity_spent += price
	revenue += price
	return true

func _event(message: String) -> void:
	history.append(message)
	if history.size() > 12: history.pop_front()

func protects(id: int) -> bool:
	return id > 0 and (id == cabin_id or (id == facility_id and state in FACILITY_STATES))

func layout_changed() -> void:
	# Edits can change an outdoor route even when a building's door stays connected.
	match state:
		"to_cabin", "returning":
			var record := layout.find_object(cabin_id)
			_outdoor_route(Vector2i(record.position) + ResortCatalog.entrance("cabin", record.orientation))
		"to_cafe": _visit("cafe", "to_cafe", "Walking to the café for food and a drink.")
		"to_beach": _visit("sunbeds", "to_beach", "Walking to the beach for some sunshine.")
		"to_court": _visit("volleyball","to_court","Walking to the volleyball court.")
		"departing": _outdoor_route(ResortLayout.ARRIVAL)

func access_survives(candidate: ResortLayout) -> bool:
	if state in ["entering", "resting", "exiting", "overnight", "departed"] or state in IN_FACILITY: return true
	var graph := candidate.navigation()
	var cell := Vector2i(logical_position.round())
	if not (graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not graph.get_id_path(cell, ResortLayout.ARRIVAL).is_empty()): return false
	cell = Vector2i(companion.position.round())
	return party_size == 1 or (graph.is_in_boundsv(cell) and not graph.is_point_solid(cell) and not graph.get_id_path(cell, ResortLayout.ARRIVAL).is_empty())

func edit_reason() -> String:
	return "This cabin is reserved. Move, rotation and removal become available after checkout."

func capture() -> Dictionary:
	var points: Array = []
	for point in route: points.append([point.x, point.y])
	return {"version": 2, "party_size":party_size, "companion":companion.capture(), "activity_elapsed":activity_elapsed, "state": state, "position": [logical_position.x, logical_position.y], "route": points, "route_index": route_index,
		"distance": walked_distance, "direction": [direction.x, direction.y], "clock": clock, "timer": timer, "cabin_id": cabin_id, "facility_id": facility_id,
		"booking_rate": booking_rate, "nights": nights, "paid_nights": paid_nights, "budget": budget, "accommodation_spent": accommodation_spent,
		"activity_spent": activity_spent, "hunger": hunger, "rest": rest, "enjoyment": enjoyment, "next_night": next_night, "revenue": revenue,
		"explanation": explanation, "departure_reason": departure_reason, "history": history.duplicate(), "after_exit": after_exit}

func restore(data: Dictionary) -> bool:
	if not (data.get("version") is int or data.get("version") is float): return false
	var version := int(data.version)
	if version not in [1,2] or data.version != version or not data.get("state", "") in STATES: return false
	var size := int(data.get("party_size",1))
	if size not in [1,2] or data.get("party_size",1)!=size: return false
	var partner := GuestMotion.new()
	if data.version == 2:
		if not data.get("companion") is Dictionary or not partner.restore(data.companion): return false
		if not (data.get("activity_elapsed") is int or data.get("activity_elapsed") is float) or not is_finite(float(data.activity_elapsed)) or data.activity_elapsed < 0: return false
	for key in ["position", "direction"]:
		if not data.get(key) is Array or data[key].size() != 2: return false
		for number in data[key]:
			if not (number is float or number is int) or not is_finite(float(number)): return false
	for key in ["distance", "clock", "timer", "cabin_id", "facility_id", "booking_rate", "nights", "paid_nights", "budget", "accommodation_spent", "activity_spent", "hunger", "rest", "enjoyment", "next_night", "revenue", "route_index"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])): return false
	if not data.get("route") is Array or not data.get("history") is Array: return false
	if data.route_index < 0 or data.route_index > data.route.size() or data.budget < 0 or data.nights != 2 or data.paid_nights < 0 or data.paid_nights > data.nights or data.booking_rate != NIGHTLY_RATE: return false
	if data.cabin_id > 0 and layout.find_object(int(data.cabin_id)).get("kind") != "cabin": return false
	if not data.state in ["arriving", "waiting", "departing", "departed"] and data.cabin_id < 1: return false
	var points: Array[Vector2] = []
	for point in data.route:
		if not point is Array or point.size() != 2: return false
		for number in point:
			if not (number is float or number is int) or not is_finite(float(number)): return false
		points.append(Vector2(point[0], point[1]))
	for key in ["state", "clock", "timer", "cabin_id", "facility_id", "booking_rate", "nights", "paid_nights", "budget", "accommodation_spent", "activity_spent", "hunger", "rest", "enjoyment", "next_night", "revenue", "route_index", "explanation", "departure_reason", "after_exit"]:
		if not data.has(key): return false
	for entry in data.history:
		if not entry is String: return false
	for key in ["explanation", "departure_reason", "after_exit"]:
		if not data[key] is String: return false
	if data.after_exit not in ["cafe", "checkout"] or data.clock < 0 or data.distance < 0: return false
	if data.accommodation_spent != data.paid_nights * data.booking_rate or data.revenue != data.accommodation_spent + data.activity_spent or data.budget + data.revenue != 240*size or data.activity_spent < 0: return false
	var point := Vector2(data.position[0], data.position[1])
	if not ResortLayout.POINT_BOUNDS.has_point(point): return false
	var graph := layout.navigation()
	var interior: bool = data.state in ["entering", "resting", "exiting", "overnight"]
	if data.state in ["to_cabin", "returning", "entering", "exiting", "to_cafe", "to_beach", "departing", "to_court"] and (points.is_empty() or (data.route_index >= points.size() and (size==1 or partner.finished()))): return false
	if data.state in ["to_cafe", "eating"] and layout.find_object(int(data.facility_id)).get("kind") != "cafe": return false
	if data.state in ["to_beach", "relaxing"] and layout.find_object(int(data.facility_id)).get("kind") != "sunbeds": return false
	if interior:
		var cabin := layout.find_object(int(data.cabin_id))
		var door: Vector2 = cabin.position + Vector2(ResortCatalog.entrance("cabin", cabin.orientation))
		if not layout.object_rect(cabin).grow(0.7).has_point(point): return false
		for waypoint in points:
			if not layout.object_rect(cabin).grow(0.7).has_point(waypoint) and not waypoint.is_equal_approx(door): return false
	elif data.state in IN_FACILITY:
		var facility := layout.find_object(int(data.facility_id))
		if facility.is_empty(): return false
		var bounds := layout.object_rect(facility).grow(1.1)
		if not bounds.has_point(point): return false
		for waypoint in points:
			if not bounds.has_point(waypoint): return false
	else:
		if graph.is_point_solid(Vector2i(point.round())): return false
		for waypoint in points:
			var cell := Vector2i(waypoint.round())
			if not waypoint.is_equal_approx(Vector2(cell)) or not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): return false
		for index in range(1, points.size()):
			if points[index].distance_to(points[index-1]) > 1.001: return false
		if data.route_index < points.size() and point.distance_to(points[int(data.route_index)]) > 1.01: return false
	if size==2:
		if interior:
			var cabin := layout.find_object(int(data.cabin_id))
			var door: Vector2=cabin.position+Vector2(ResortCatalog.entrance("cabin",cabin.orientation))
			if not layout.object_rect(cabin).grow(0.7).has_point(partner.position): return false
			for waypoint in partner.route:
				if not layout.object_rect(cabin).grow(0.7).has_point(waypoint) and not waypoint.is_equal_approx(door): return false
		elif data.state in IN_FACILITY:
			var facility := layout.find_object(int(data.facility_id))
			var bounds := layout.object_rect(facility).grow(1.1)
			if not bounds.has_point(partner.position): return false
			for waypoint in partner.route:
				if not bounds.has_point(waypoint): return false
		else:
			if graph.is_point_solid(Vector2i(partner.position.round())): return false
			for waypoint in partner.route:
				var cell := Vector2i(waypoint.round())
				if not waypoint.is_equal_approx(Vector2(cell)) or not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): return false
			for index in range(1,partner.route.size()):
				if partner.route[index].distance_to(partner.route[index-1])>1.001: return false
			if partner.index<partner.route.size() and partner.position.distance_to(partner.route[partner.index])>1.01: return false
	for key in ["state", "clock", "timer", "cabin_id", "facility_id", "booking_rate", "nights", "paid_nights", "budget", "accommodation_spent", "activity_spent", "hunger", "rest", "enjoyment", "next_night", "revenue", "route_index", "explanation", "departure_reason", "after_exit"]:
		set(key, data[key])
	logical_position = Vector2(data.position[0], data.position[1])
	direction = Vector2(data.direction[0], data.direction[1])
	walked_distance = data.distance
	route = points
	history.assign(data.history)
	party_size = size
	companion = partner
	activity_elapsed = float(data.get("activity_elapsed",0))
	if version==1 and assets!=null:
		var slot := activity_slot(0)
		if not slot.is_empty(): logical_position = slot.position
	return true
