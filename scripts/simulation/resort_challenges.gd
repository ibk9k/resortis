class_name ResortChallenges
extends RefCounted
## Goals are backed by actual paid transactions. One-off claims survive saves.

const STATUE := "dolphin_statue"
const STATUE_CHALLENGE := "rally_club"
const TIMED := "beach_rush"
const GOALS := {
	"first_nights": {"name": "A place to stay", "description": "Collect payment for 4 cabin nights.", "kind": "room", "target": 4, "cash": 160},
	"busy_cafe": {"name": "Lunch service", "description": "Serve 5 paid meals at the café or bistro.", "kind": "meal", "target": 5, "cash": 120},
	STATUE_CHALLENGE: {"name": "Rally club", "description": "Admit 4 paying volleyball players.", "kind": "volleyball", "target": 4, "cash": 0},
	TIMED: {"name": "Beach rush", "description": "Admit 2 paying sunbed guests within one resort day.", "kind": "sunbathe", "target": 2, "cash": 180},
}
const TIME_LIMIT := 180.0

var _claims := {}
var _attempt := {}

func statue_unlocked() -> bool:
	return _claims.has(STATUE_CHALLENGE)

func start(clock: float, ledger: RefCounted) -> bool:
	if _state(TIMED, clock, ledger) not in ["ready", "expired"]: return false
	_attempt = {"time": clock, "first": ledger.call("receipt_count")}
	return true

func claim(id: String, clock: float, ledger: RefCounted) -> bool:
	if not GOALS.has(id) or _state(id, clock, ledger) != "complete": return false
	var amount: int = GOALS[id].cash
	if amount > 0 and not ledger.call("record", {"id": receipt_id(id), "kind": "reward", "amount": amount, "time": clock}):
		return false
	_claims[id] = clock
	return true

func inspect(clock: float, ledger: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in GOALS:
		var goal: Dictionary = GOALS[id]
		var state := _state(id, clock, ledger)
		result.append({"id": id, "name": goal.name, "description": goal.description, "target": goal.target,
			"progress": _progress(id, ledger), "state": state, "cash": goal.cash,
			"decoration": STATUE if id == STATUE_CHALLENGE else "", "remaining": _remaining(clock) if state == "timed" else 0})
	return result

func _state(id: String, clock: float, ledger: RefCounted) -> String:
	if _claims.has(id): return "claimed"
	if _progress(id, ledger) >= GOALS[id].target: return "complete"
	if id != TIMED: return "tracking"
	if _attempt.is_empty(): return "ready"
	return "expired" if _remaining(clock) <= 0.0 else "timed"

func _remaining(clock: float) -> float:
	return maxf(0.0, float(_attempt.time) + TIME_LIMIT - clock)

func _progress(id: String, ledger: RefCounted, until := INF) -> int:
	var goal: Dictionary = GOALS[id]
	if id != TIMED:
		var target := int(goal.target)
		var count := int(ledger.call("count_guest_receipts", goal.kind, target, 0, until))
		if id == "busy_cafe" and count < target:
			count += int(ledger.call("count_guest_receipts", "restaurant", target - count, 0, until))
		return count
	if _attempt.is_empty(): return 0
	return ledger.call("count_guest_receipts", goal.kind, int(goal.target), int(_attempt.first), minf(until, float(_attempt.time) + TIME_LIMIT))

func capture() -> Dictionary:
	return {"version": 1, "claims": _claims.duplicate(), "attempt": _attempt.duplicate()}

func restore(data: Dictionary, clock: float, ledger: RefCounted) -> bool:
	if data.size() != 3 or not BookingRegistry.integral(data.get("version"), 1, 1) or not data.get("claims") is Dictionary or not data.get("attempt") is Dictionary:
		return false
	# This instance is staged by LivingResortRuntime before it can affect play.
	_attempt = data.attempt.duplicate()
	if not _attempt.is_empty():
		var count: int = ledger.call("receipt_count")
		if _attempt.size() != 2 or not _valid_time(_attempt.get("time"), clock) or not BookingRegistry.integral(_attempt.get("first"), 0, count):
			return false
		var first := int(_attempt.first)
		var started := float(_attempt.time)
		if first > 0 and float(ledger.call("receipt_time", first - 1)) > started: return false
		if first < count and float(ledger.call("receipt_time", first)) < started: return false
	for id: Variant in data.claims:
		if not GOALS.has(id) or not _valid_time(data.claims[id], clock): return false
		var claimed_at := float(data.claims[id])
		if id == TIMED and (_attempt.is_empty() or claimed_at < float(_attempt.time)): return false
		if _progress(id, ledger, claimed_at) != GOALS[id].target: return false
	_claims = data.claims.duplicate()
	return true

func matches_cash_receipt(event: Dictionary) -> bool:
	var id := challenge_for_receipt(event.id)
	return _claims.has(id) and float(_claims[id]) == float(event.time)

func has_cash_receipts(journal_ids: Dictionary) -> bool:
	for id: String in _claims:
		if GOALS[id].cash > 0 and not journal_ids.has(receipt_id(id)): return false
	return true

static func receipt_id(challenge: String) -> String:
	return "challenge:" + challenge

static func challenge_for_receipt(id: String) -> String:
	var challenge := id.trim_prefix("challenge:")
	return challenge if id == receipt_id(challenge) and GOALS.has(challenge) else ""

static func _valid_time(value: Variant, clock: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= clock
