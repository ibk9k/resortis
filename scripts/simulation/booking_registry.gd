class_name BookingRegistry
extends RefCounted
## Room identity and the immutable rate agreed at reservation. Money stays with
## ResortSimulation; reserving a room never charges its occupants.

const NIGHTLY_RATE := 60
var layout: ResortLayout
var reservations: Array[Dictionary] = []

func configure(map: ResortLayout) -> void:
	layout = map
	reservations.clear()

func owner(cabin_id: int) -> int:
	for entry in reservations:
		if entry.cabin_id == cabin_id: return entry.party_id
	return 0

func booking(party_id: int) -> Dictionary:
	for entry in reservations:
		if entry.party_id == party_id: return entry
	return {}

func protects(cabin_id: int) -> bool:
	return owner(cabin_id) > 0

func reserve(party_id: int, cabin_id: int, nights: int, budget: int, rate: int = NIGHTLY_RATE) -> bool:
	if layout == null or party_id < 1 or cabin_id < 1 or nights < 1 or nights > 3 or rate < 1: return false
	if layout.find_object(cabin_id).get("kind") != "cabin" or budget < nights * rate: return false
	var existing := booking(party_id)
	if not existing.is_empty():
		return existing.cabin_id == cabin_id and existing.nights == nights and existing.rate == rate
	if protects(cabin_id): return false
	reservations.append({"party_id": party_id, "cabin_id": cabin_id, "nights": nights, "rate": rate})
	return true

func choose(party_id: int, nights: int, budget: int, start: Vector2i = ResortLayout.ARRIVAL) -> Dictionary:
	if layout == null or budget < nights * NIGHTLY_RATE: return {}
	var existing := booking(party_id)
	if not existing.is_empty(): return existing
	var graph := layout.navigation()
	if not _open(graph, start): return {}
	var chosen := -1
	var shortest := 2147483647
	for record in layout.objects:
		if record.kind != "cabin" or protects(record.id): continue
		var door := Vector2i(record.position) + ResortCatalog.entrance("cabin", record.orientation)
		if not _open(graph, door): continue
		var route := graph.get_id_path(start, door)
		if not route.is_empty() and (route.size() < shortest or (route.size() == shortest and record.id < chosen)):
			chosen = record.id
			shortest = route.size()
	if chosen < 1 or not reserve(party_id, chosen, nights, budget): return {}
	return booking(party_id)

func release(party_id: int) -> void:
	for index in range(reservations.size() - 1, -1, -1):
		if reservations[index].party_id == party_id: reservations.remove_at(index)

func capture() -> Dictionary:
	return {"version": 1, "reservations": reservations.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if layout == null or not integral(data.get("version"), 1, 1) or not data.get("reservations") is Array: return false
	if data.reservations.size() > 12: return false
	var entries: Array[Dictionary] = []
	var cabins := {}
	var parties := {}
	for value in data.reservations:
		if not value is Dictionary: return false
		for key in ["party_id", "cabin_id", "rate", "nights"]:
			if not integral(value.get(key), 1, 1000000000): return false
		if value.nights > 3 or value.rate > 1000000: return false
		if cabins.has(int(value.cabin_id)) or parties.has(int(value.party_id)): return false
		if layout.find_object(int(value.cabin_id)).get("kind") != "cabin": return false
		cabins[int(value.cabin_id)] = true
		parties[int(value.party_id)] = true
		entries.append({"party_id": int(value.party_id), "cabin_id": int(value.cabin_id), "rate": int(value.rate), "nights": int(value.nights)})
	reservations = entries
	return true

static func integral(value: Variant, minimum: int = 0, maximum: int = 1000000000) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and value == int(value)

static func _open(graph: AStarGrid2D, cell: Vector2i) -> bool:
	return graph.is_in_boundsv(cell) and not graph.is_point_solid(cell)
