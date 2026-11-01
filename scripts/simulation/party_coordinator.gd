class_name PartyCoordinator
extends RefCounted
## Pure suggestions at a safe decision point. Lodging, money, movement and
## reunion remain in ResortSimulation; this helper never creates a wait state.

const FREE_STATES := ["deciding"]
const INVITABLE_STATES := ["deciding", "to_facility", "queueing", "approaching_activity", "waiting_partner"]
const SHARED_ACTIVITIES := ["sunbathe", "volleyball", "stroll"]
const INTERESTS := {
	"sunbathe": ["sunbathe", "sunbathing"],
	"volleyball": ["volleyball"],
	"stroll": ["stroll", "beach walks", "beach walk"]
}

static func should_join(person: Dictionary, partner: Dictionary, intent: Dictionary) -> bool:
	if person.is_empty() or partner.is_empty() or person.get("id") == partner.get("id"): return false
	for guest in [person, partner]:
		if not _integer(guest.get("id")) or guest.id < 1 or not _integer(guest.get("party_id")) or guest.party_id < 1: return false
	if person.get("party_id", -1) != partner.get("party_id", -2): return false
	if person.get("state") not in FREE_STATES or partner.get("state") not in INVITABLE_STATES: return false
	if _must_act_alone(person) or _must_act_alone(partner): return false
	var activity: String = intent.get("activity", "") if intent.get("activity", "") is String else ""
	if activity not in SHARED_ACTIVITIES: return false
	var facility_id: Variant = intent.get("facility_id", -1)
	if not _integer(facility_id) or (activity != "stroll" and float(facility_id) < 1.0) or (activity == "stroll" and int(facility_id) != -1): return false
	if partner.state != "deciding" and (partner.get("activity") != activity or partner.get("facility_id") != facility_id): return false
	if partner.state == "deciding" and partner.get("activity", "") not in ["", activity]: return false
	# A shared invitation must not replace an urgent meal/rest or keep a
	# companion doing strenuous sport when they should recover individually.
	var hunger := _need(person, "hunger")
	var rest := _need(person, "rest")
	var enjoyment := _need(person, "enjoyment")
	if hunger <= 40.0 or rest <= 35.0: return false
	if activity == "volleyball": return rest >= 50.0 and _need(partner, "rest") >= 50.0 and _likes(person, activity)
	if activity == "sunbathe": return _likes(person, activity) or (rest < 65.0 and enjoyment < 65.0)
	return _likes(person, activity) or enjoyment < 45.0

static func _must_act_alone(person: Dictionary) -> bool:
	return person.get("want_leave", false) != false or person.get("return_requested", false) != false or _need(person, "hunger") <= 30.0 or _need(person, "rest") <= 25.0

static func _need(person: Dictionary, key: String) -> float:
	if not person.get("needs") is Dictionary: return 0.0
	var value: Variant = person.needs.get(key)
	if not (value is int or value is float) or not is_finite(float(value)): return 0.0
	return clampf(float(value), 0.0, 100.0)

static func _likes(person: Dictionary, activity: String) -> bool:
	var profile: Variant = person.get("profile", {})
	if not profile is Dictionary or not profile.get("interests") is Array: return false
	for interest in profile.interests:
		if interest is String and interest.strip_edges().to_lower() in INTERESTS[activity]: return true
	return false

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 1000000000.0 and float(value) == floorf(float(value))
