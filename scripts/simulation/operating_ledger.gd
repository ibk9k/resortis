class_name OperatingLedger
extends RefCounted
## An append-only operating journal. The simulation owns money and event IDs;
## this service accepts each valid ID once and derives every displayed total.

const DAY_SECONDS := 180.0
const VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_EVENTS := 250000
const CONSTRUCTION := ["construction", "refund"]
const KINDS := ["room", "meal", "sunbathe", "volleyball", "wage", "legacy_income", "construction", "refund", "upkeep", "reward"] + ResortServices.EXPANSION
const EVENT_FIELDS := ["id", "kind", "amount", "time", "party_id", "person_id", "staff_id", "item", "quantity", "unit_price"]
const SNAPSHOT_FIELDS := ["version", "events", "income_total", "wages_total", "net_total", "journal_hash"]

var _events: Array[Dictionary] = []
var _ids: Dictionary = {}
var _days: Dictionary = {}
var _income := 0
var _wages := 0
var _upkeep := 0
var _construction := 0
var _purchased := {}
var _latest_time := 0.0
var _by_kind := {"room": 0, "meal": 0, "sunbathe": 0, "volleyball": 0, "wage": 0, "legacy_income": 0, "reward": 0}
var _guest_receipt_indices := {"room": [], "meal": [], "sunbathe": [], "volleyball": []}

func _init() -> void:
	for service in ResortServices.EXPANSION:
		_guest_receipt_indices[service] = []

func record(event: Dictionary) -> bool:
	# Validate before consulting the receipt set: a malformed duplicate never
	# becomes an accepted delivery, and a rejected new ID is still usable later.
	var entry := _normalize(event)
	if entry.is_empty() or _ids.has(entry.id) or _events.size() >= MAX_EVENTS: return false
	var amount: int = entry.amount
	var kind: String = entry.kind
	if amount < 0 and _wages + _upkeep + _construction > MAX_SAFE_INTEGER + amount: return false
	if amount > 0 and kind != "refund" and _income > MAX_SAFE_INTEGER - amount: return false
	if kind in CONSTRUCTION:
		var purchase_key := "%s:%d" % [entry.item, entry.unit_price]
		var bought: int = _purchased.get(purchase_key, 0)
		var change: int = entry.quantity if kind == "construction" else -entry.quantity
		if bought + change < 0: return false
		_purchased[purchase_key] = bought + change
	if _guest_receipt_indices.has(kind) and not entry.id.begins_with("import-"):
		_guest_receipt_indices[kind].append(_events.size())
	_events.append(entry)
	_ids[entry.id] = true
	_latest_time = maxf(_latest_time, float(entry.time))
	match kind:
		"wage": _wages -= amount
		"upkeep": _upkeep -= amount
		"construction", "refund": _construction -= amount
		_:
			_income += amount
			_by_kind[kind] = int(_by_kind.get(kind, 0)) + amount
	var day := _day(float(entry.time))
	if not _days.has(day): _days[day] = _empty_day(day)
	var result: Dictionary = _days[day]
	result.event_count += 1
	match kind:
		"wage": result.wages -= amount
		"upkeep": result.upkeep -= amount
		"construction", "refund": result.construction -= amount
		"reward":
			result.income += amount
			result.reward_income += amount
		_:
			result.income += amount
			var category := kind + "_income"
			if kind == "legacy_income":
				category = kind
			elif kind in ResortServices.EXPANSION:
				category = "facility_income"
			result[category] += amount
			if kind != "room": result.activity_income += amount
	result.expenses = int(result.wages) + int(result.upkeep) + int(result.construction)
	result.net = int(result.income) - int(result.expenses)
	return true

func profit() -> int:
	return _income - _wages - _upkeep - _construction

func receipt_count() -> int:
	return _events.size()

func receipt_time(index: int) -> float:
	return _events[index].time

func count_guest_receipts(kind: String, limit: int, first: int, until: float) -> int:
	var indices: Array = _guest_receipt_indices[kind]
	var count := 0
	for i in range(indices.bsearch(first), indices.size()):
		if float(_events[indices[i]].time) > until: break
		count += 1
		if count == limit: break
	return count

func record_daily_upkeep(objects: Array[Dictionary], day: int) -> void:
	var quantities := {}
	for object in objects:
		var kind: String = object.kind
		if ResortEconomy.upkeep(kind) > 0:
			quantities[kind] = int(quantities.get(kind, 0)) + 1
	# Canonical item order keeps receipts stable across save and resume.
	var kinds := quantities.keys()
	kinds.sort()
	for kind: String in kinds:
		var unit_price := ResortEconomy.upkeep(kind)
		var quantity: int = quantities[kind]
		record({"id": "resort:upkeep:%d:%s" % [day, kind], "kind": "upkeep",
			"item": kind, "quantity": quantity, "unit_price": unit_price, "amount": -unit_price * quantity,
			"time": day * DAY_SECONDS})

func receipt_page(page: int, limit: int) -> Array:
	var end := maxi(0, _events.size() - page * limit)
	var result := _events.slice(maxi(0, end - limit), end).duplicate(true)
	result.reverse()
	return result

func inspect(clock: float) -> Dictionary:
	var day := _day(clock)
	var today: Dictionary = _days.get(day, _empty_day(day))
	var day_numbers: Array = _days.keys()
	if not day_numbers.has(day): day_numbers.append(day)
	day_numbers.sort()
	var days: Array[Dictionary] = []
	for number: int in day_numbers:
		days.append((_days.get(number, _empty_day(number)) as Dictionary).duplicate(true))
	return {"income_total": _income, "wages_total": _wages, "net_total": profit(),
		"upkeep_total": _upkeep, "construction_total": _construction, "expenses_total": _wages + _upkeep + _construction,
		"today_income": int(today.income), "today_wages": int(today.wages), "today_net": int(today.net),
		"day": day, "days": days, "room_income": int(_by_kind.room),
		"activity_income": _income - int(_by_kind.room) - int(_by_kind.reward), "reward_income": int(_by_kind.reward),
		"meal_income": int(_by_kind.meal),
		"sunbathe_income": int(_by_kind.sunbathe), "volleyball_income": int(_by_kind.volleyball),
		"facility_income": _income - int(_by_kind.room) - int(_by_kind.meal) - int(_by_kind.sunbathe) - int(_by_kind.volleyball) - int(_by_kind.legacy_income) - int(_by_kind.reward),
		"legacy_income": int(_by_kind.legacy_income), "event_count": _events.size(),
		"last_event_time": _latest_time}

func capture() -> Dictionary:
	return {"version": VERSION, "events": _events.duplicate(true), "income_total": _income,
		"wages_total": _wages, "net_total": profit(), "journal_hash": _journal_hash(_events)}

func restore(data: Dictionary) -> bool:
	if not _exact_fields(data, SNAPSHOT_FIELDS) or not _integer(data.get("version"), 1, VERSION): return false
	if not data.get("events") is Array or data.events.size() > MAX_EVENTS: return false
	for key in ["income_total", "wages_total"]:
		if not _integer(data.get(key), 0, MAX_SAFE_INTEGER): return false
	if not _integer(data.get("net_total"), -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER): return false
	if not data.get("journal_hash") is String or data.journal_hash.length() != 64: return false
	# Build a candidate so even the last invalid receipt leaves the open journal
	# and its duplicate guards untouched. Integral JSON floats normalize to ints.
	var candidate: RefCounted = get_script().new()
	for event: Variant in data.events:
		if not event is Dictionary or not candidate.record(event): return false
	if candidate._income != int(data.income_total) or candidate._wages != int(data.wages_total): return false
	if candidate.profit() != int(data.net_total): return false
	if _journal_hash(candidate._events) != data.journal_hash: return false
	_events = candidate._events
	_ids = candidate._ids
	_days = candidate._days
	_income = candidate._income
	_wages = candidate._wages
	_upkeep = candidate._upkeep
	_construction = candidate._construction
	_purchased = candidate._purchased
	_latest_time = candidate._latest_time
	_by_kind = candidate._by_kind
	_guest_receipt_indices = candidate._guest_receipt_indices
	return true

static func _normalize(event: Dictionary) -> Dictionary:
	for key: Variant in event:
		if not key is String or key not in EVENT_FIELDS: return {}
	if not event.get("id") is String or event.id.is_empty() or event.id.length() > 256: return {}
	if event.id.strip_edges() != event.id: return {}
	for character in event.id:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127: return {}
	if not event.get("kind") is String or event.kind not in KINDS: return {}
	if not _integer(event.get("amount"), -MAX_SAFE_INTEGER, MAX_SAFE_INTEGER) or event.amount == 0: return {}
	if (event.kind in ["wage", "construction", "upkeep"]) != (event.amount < 0): return {}
	if not _number(event.get("time")) or float(event.time) < 0.0 or float(event.time) > MAX_SAFE_INTEGER: return {}
	var entry := {"id": String(event.id), "kind": String(event.kind), "amount": int(event.amount), "time": float(event.time)}
	if event.kind == "reward":
		var challenge := ResortChallenges.challenge_for_receipt(event.id)
		if event.size() != 4 or challenge.is_empty() or int(entry.amount) != int(ResortChallenges.GOALS[challenge].cash):
			return {}
	if event.kind in CONSTRUCTION or event.kind == "upkeep":
		if not event.get("item") is String or not ResortEconomy.COSTS.has(event.item): return {}
		if not _integer(event.get("quantity"), 1, 1000000): return {}
		for key in ["party_id", "person_id", "staff_id"]:
			if event.has(key): return {}
		if not _integer(event.get("unit_price"), 1, 1000000): return {}
		if absi(entry.amount) != int(event.quantity) * int(event.unit_price): return {}
		entry["item"] = event.item
		entry["quantity"] = int(event.quantity)
		entry["unit_price"] = int(event.unit_price)
	elif event.has("item") or event.has("quantity"): return {}
	elif event.has("unit_price"):
		if not ResortEconomy.DEFAULT_PRICES.has(event.kind) or not ResortEconomy.valid_price(event.unit_price) or event.unit_price != event.amount:
			return {}
		entry["unit_price"] = int(event.unit_price)
	for key in ["party_id", "person_id", "staff_id"]:
		if not event.has(key): continue
		if not _integer(event[key], 0, MAX_SAFE_INTEGER): return {}
		entry[key] = int(event[key])
	return entry

static func _empty_day(day: int) -> Dictionary:
	return {"day": day, "start_time": (day - 1) * DAY_SECONDS, "end_time": day * DAY_SECONDS,
		"income": 0, "wages": 0, "upkeep": 0, "construction": 0, "expenses": 0, "net": 0, "room_income": 0, "activity_income": 0,
		"meal_income": 0, "sunbathe_income": 0, "volleyball_income": 0, "legacy_income": 0, "reward_income": 0, "facility_income": 0, "event_count": 0}

static func _day(time: float) -> int:
	# Half-open days: [0,180) is day 1; an event at exactly 180 is in day 2.
	return 1 + floori(time / DAY_SECONDS) if is_finite(time) and time >= 0.0 and time <= MAX_SAFE_INTEGER else 1

static func _journal_hash(events: Array) -> String:
	# Integrity checksum, not authentication. Canonical field order survives
	# JSON key reordering; totals are independently rebuilt from every receipt.
	return JSON.stringify(events).sha256_text()

static func _exact_fields(data: Dictionary, fields: Array) -> bool:
	if data.size() != fields.size(): return false
	for key: Variant in data:
		if not key is String or key not in fields: return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))
