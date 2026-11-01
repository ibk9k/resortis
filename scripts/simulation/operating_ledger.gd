class_name OperatingLedger
extends RefCounted
## An append-only operating journal. The simulation owns money and event IDs;
## this service accepts each valid ID once and derives every displayed total.

const DAY_SECONDS := 180.0
const VERSION := 1
const MAX_SAFE_INTEGER := 9007199254740991
const MAX_EVENTS := 250000
const KINDS := ["room", "meal", "sunbathe", "volleyball", "wage", "legacy_income"]
const EVENT_FIELDS := ["id", "kind", "amount", "time", "party_id", "person_id", "staff_id"]
const SNAPSHOT_FIELDS := ["version", "events", "income_total", "wages_total", "net_total", "journal_hash"]

var _events: Array[Dictionary] = []
var _ids: Dictionary = {}
var _days: Dictionary = {}
var _income := 0
var _wages := 0
var _latest_time := 0.0
var _by_kind := {"room": 0, "meal": 0, "sunbathe": 0, "volleyball": 0, "wage": 0, "legacy_income": 0}

func record(event: Dictionary) -> bool:
	# Validate before consulting the receipt set: a malformed duplicate never
	# becomes an accepted delivery, and a rejected new ID is still usable later.
	var entry := _normalize(event)
	if entry.is_empty() or _ids.has(entry.id) or _events.size() >= MAX_EVENTS: return false
	var amount: int = entry.amount
	if amount > 0 and _income > MAX_SAFE_INTEGER - amount: return false
	if amount < 0 and _wages > MAX_SAFE_INTEGER + amount: return false
	_events.append(entry)
	_ids[entry.id] = true
	_latest_time = maxf(_latest_time, float(entry.time))
	_by_kind[entry.kind] += amount
	if entry.kind == "wage": _wages -= amount
	else: _income += amount
	var day := _day(float(entry.time))
	if not _days.has(day): _days[day] = _empty_day(day)
	var result: Dictionary = _days[day]
	result.event_count += 1
	if entry.kind == "wage": result.wages -= amount
	else:
		result.income += amount
		var category: String = "legacy_income" if entry.kind == "legacy_income" else String(entry.kind) + "_income"
		result[category] += amount
		if entry.kind != "room": result.activity_income += amount
	result.net = int(result.income) - int(result.wages)
	return true

func inspect(clock: float) -> Dictionary:
	var day := _day(clock)
	var today: Dictionary = _days.get(day, _empty_day(day))
	var day_numbers: Array = _days.keys()
	if not day_numbers.has(day): day_numbers.append(day)
	day_numbers.sort()
	var days: Array[Dictionary] = []
	for number: int in day_numbers:
		days.append((_days.get(number, _empty_day(number)) as Dictionary).duplicate(true))
	return {"income_total": _income, "wages_total": _wages, "net_total": _income - _wages,
		"today_income": int(today.income), "today_wages": int(today.wages), "today_net": int(today.net),
		"day": day, "days": days, "room_income": int(_by_kind.room),
		"activity_income": _income - int(_by_kind.room), "meal_income": int(_by_kind.meal),
		"sunbathe_income": int(_by_kind.sunbathe), "volleyball_income": int(_by_kind.volleyball),
		"legacy_income": int(_by_kind.legacy_income), "event_count": _events.size(),
		"last_event_time": _latest_time}

func capture() -> Dictionary:
	return {"version": VERSION, "events": _events.duplicate(true), "income_total": _income,
		"wages_total": _wages, "net_total": _income - _wages, "journal_hash": _journal_hash(_events)}

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
	if candidate._income - candidate._wages != int(data.net_total): return false
	if _journal_hash(candidate._events) != data.journal_hash: return false
	_events = candidate._events
	_ids = candidate._ids
	_days = candidate._days
	_income = candidate._income
	_wages = candidate._wages
	_latest_time = candidate._latest_time
	_by_kind = candidate._by_kind
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
	if (event.kind == "wage") != (event.amount < 0): return {}
	if not _number(event.get("time")) or float(event.time) < 0.0 or float(event.time) > MAX_SAFE_INTEGER: return {}
	var entry := {"id": String(event.id), "kind": String(event.kind), "amount": int(event.amount), "time": float(event.time)}
	for key in ["party_id", "person_id", "staff_id"]:
		if not event.has(key): continue
		if not _integer(event[key], 0, MAX_SAFE_INTEGER): return {}
		entry[key] = int(event[key])
	return entry

static func _empty_day(day: int) -> Dictionary:
	return {"day": day, "start_time": (day - 1) * DAY_SECONDS, "end_time": day * DAY_SECONDS,
		"income": 0, "wages": 0, "net": 0, "room_income": 0, "activity_income": 0,
		"meal_income": 0, "sunbathe_income": 0, "volleyball_income": 0, "legacy_income": 0, "event_count": 0}

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
