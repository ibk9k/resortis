class_name GuestBrain
extends RefCounted
## Individual needs and choices. Money, routes, admissions and task timers belong
## to ResortSimulation. High need values mean satisfied, as in the legacy stay.

const NIGHTLY_RATE := 60
const URGENT_HUNGER := 30.0
const URGENT_REST := 25.0
const SEVERE_MOOD := 28.0
const RECOVERED_MOOD := 43.0
const WARNING_AFTER := 18.0
const WARNING_GRACE := 30.0
const HISTORY_LIMIT := 12
const EPSILON := 0.000000001
const ACTIVITIES := ["meal", "sunbathe", "volleyball", "rest", "stroll"] + ResortServices.EXPANSION
const COMMITTED_STATES := ["to_cabin", "entering", "sleeping", "exiting", "to_facility", "queueing", "approaching_activity", "sitting", "eating", "lying", "volleyball", "using_facility", "leaving_activity", "strolling", "waiting_partner", "returning"]

static func advance(person: Dictionary, delta: float, cleanliness_score: float = 100.0) -> void:
	if not is_finite(delta) or delta <= 0.0 or person.get("state", "") == "departed": return
	var needs := _needs(person)
	var rates := _rates(person)
	var cleanliness := clampf(cleanliness_score, 0.0, 100.0) if is_finite(cleanliness_score) else 100.0
	# Split only where clamping or the mood formula changes slope. This integrates
	# warning/grace time exactly without a second clock or frame-sized timer drift.
	var times: Array[float] = [0.0, delta]
	for index in 3:
		if absf(rates[index]) <= EPSILON: continue
		_add_time(times, (0.0 - needs[index]) / rates[index], delta)
		_add_time(times, (100.0 - needs[index]) / rates[index], delta)
		if index < 2: _add_time(times, (25.0 - needs[index]) / rates[index], delta)
	times.sort()
	for index in range(times.size() - 1):
		var start := _at(needs, rates, times[index])
		var finish := _at(needs, rates, times[index + 1])
		var duration := times[index + 1] - times[index]
		if duration <= EPSILON: continue
		var difference_start := start[0] - start[1]
		var difference_end := finish[0] - finish[1]
		if difference_start * difference_end < 0.0:
			var fraction := difference_start / (difference_start - difference_end)
			var middle := _interpolate(start, finish, fraction)
			_mood_interval(person, start, middle, duration * fraction, cleanliness)
			_mood_interval(person, middle, finish, duration * (1.0 - fraction), cleanliness)
		else:
			_mood_interval(person, start, finish, duration, cleanliness)
	var final_needs := _at(needs, rates, delta)
	person["needs"] = {"hunger": final_needs[0], "rest": final_needs[1], "enjoyment": final_needs[2]}
	person["mood"] = clampf(_raw_mood(final_needs, cleanliness), 0.0, 100.0)
	person["mood_reason"] = _mood_reason(final_needs, cleanliness)
	if float(person.mood) >= RECOVERED_MOOD: _recover(person)

@warning_ignore("unused_parameter")
static func choose(person: Dictionary, party: Dictionary, available: Array[Dictionary], clock: float) -> Dictionary:
	var needs := _needs(person)
	var activity: String = person.get("activity", "")
	# Calling this more often cannot replace a task that is already in progress.
	# The controller decides when completion/cancellation makes a new choice safe.
	if person.get("state", "") in COMMITTED_STATES and activity in ACTIVITIES:
		if activity in ["rest", "stroll"]:
			return _intent(activity, -1, person.get("reason", "Finishing the current activity."))
		if _integer(person.get("facility_id")) and float(person.facility_id) > 0.0:
			return _intent(activity, int(person.facility_id), person.get("reason", "Finishing the current activity."))
	var reserve := _reserve(party)
	var budget := int(party.budget) if _integer(party.get("budget")) and float(party.budget) >= 0.0 else 0
	var spending_money := maxi(0, budget - reserve) if reserve >= 0 else 0
	var offers := _offers(available, spending_money)
	var meal := _best_facility("meal", offers, person, needs)
	for service in ["restaurant", "ice_cream"]:
		var food := _best_facility(service, offers, person, needs)
		if not food.is_empty() and (meal.is_empty() or _better(food, meal)): meal = food
	var needs_meal := needs[0] <= URGENT_HUNGER
	var needs_rest := needs[1] <= URGENT_REST
	if needs_rest and (not needs_meal or needs[1] / URGENT_REST < needs[0] / URGENT_HUNGER):
		return _intent("rest", -1, "Tired; returning to the cabin for proper rest.")
	if needs_meal:
		if not meal.is_empty(): return _facility_intent(meal, person, true)
		if needs_rest or needs[1] < 55.0:
			return _intent("rest", -1, "No affordable meal is available just now; resting in the cabin while waiting for food.")
		return _intent("stroll", -1, "No affordable meal is available just now; taking a short free walk while keeping room money aside.")
	if needs_rest: return _intent("rest", -1, "Tired; returning to the cabin for proper rest.")
	var best := {"activity": "stroll", "facility_id": -1, "score": 10.0 + maxf(0.0, 70.0 - needs[2]) * 0.65 + (24.0 if _likes(person, "stroll") else 0.0) - _repeat_penalty(person, "stroll")}
	var rest_score := -12.0 + maxf(0.0, 70.0 - needs[1]) * 1.05 + (8.0 if _likes(person, "rest") and needs[1] < 80.0 else 0.0) - _repeat_penalty(person, "rest")
	if rest_score > float(best.score): best = {"activity": "rest", "facility_id": -1, "score": rest_score}
	var options := [meal]
	for service in ["sunbathe", "volleyball", "gym", "sauna", "yoga", "massage", "gear", "pickleball"]:
		options.append(_best_facility(service, offers, person, needs))
	for option in options:
		if not option.is_empty() and _better(option, best): best = option
	if int(best.facility_id) >= 0: return _facility_intent(best, person, false)
	if best.activity == "rest": return _intent("rest", -1, "Taking a quiet break in the cabin to recover some rest.")
	if not available.is_empty() and offers.is_empty():
		return _intent("stroll", -1, "The facilities are busy or beyond today's spending money; enjoying a free beach walk and keeping $%d for room nights." % maxi(0, reserve))
	return _intent("stroll", -1, "Enjoying a free walk along the beach.")

static func _rates(person: Dictionary) -> Array[float]:
	var activity: String = person.get("activity", "")
	match String(person.get("state", "")):
		"using_facility":
			match activity:
				"ice_cream": return [2.6, -0.1, 1.45]
				"gym": return [-0.28, -0.52, 2.6]
				"sauna": return [-0.18, 1.25, 1.65]
				"yoga": return [-0.17, 0.7, 1.95]
				"massage": return [-0.12, 1.7, 1.8]
				"gear": return [-0.17, -0.12, 2.1]
		"eating":
			if activity == "restaurant": return [5.4, -0.07, 1.2]
			return [4.5, -0.07, 0.65 if _likes(person, "meal") else 0.25]
		"sleeping": return [-0.12, 2.4, -0.02]
		"lying": return [-0.16, 0.5, 2.8 if _likes(person, "sunbathe") else 1.9]
		"volleyball": return [-0.28, -0.45, 3.5 if _likes(person, activity) else 2.3]
		"strolling": return [-0.22, -0.16, 1.1 if _likes(person, "stroll") else 0.65]
		"queueing", "waiting_room", "waiting_partner": return [-0.2, -0.12, -0.25]
		"to_cabin", "entering", "exiting", "to_facility", "approaching_activity", "leaving_activity", "returning", "departing": return [-0.22, -0.15, -0.1]
	return [-0.2, -0.12, -0.18]

static func _needs(person: Dictionary) -> Array[float]:
	var values: Dictionary = person.get("needs", {})
	return [_need(values.get("hunger", 75.0)), _need(values.get("rest", 65.0)), _need(values.get("enjoyment", 60.0))]

static func _need(value: Variant) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return 60.0
	return clampf(float(value), 0.0, 100.0)

static func _at(needs: Array[float], rates: Array[float], elapsed: float) -> Array[float]:
	# Keep needs in GDScript's 64-bit scalars; Vector3 rounds every update to
	# 32-bit components in the standard engine and drifts at different speeds.
	return [clampf(needs[0] + rates[0] * elapsed, 0.0, 100.0), clampf(needs[1] + rates[1] * elapsed, 0.0, 100.0), clampf(needs[2] + rates[2] * elapsed, 0.0, 100.0)]

static func _interpolate(start: Array[float], finish: Array[float], fraction: float) -> Array[float]:
	return [lerpf(start[0], finish[0], fraction), lerpf(start[1], finish[1], fraction), lerpf(start[2], finish[2], fraction)]

static func _raw_mood(needs: Array[float], cleanliness: float) -> float:
	var deprivation := maxf(0.0, 25.0 - minf(needs[0], needs[1])) * 1.4
	return needs[0] * 0.4 + needs[1] * 0.35 + needs[2] * 0.25 - deprivation - (100.0 - cleanliness) * 0.65

static func _add_time(times: Array[float], value: float, duration: float) -> void:
	if value > EPSILON and value < duration - EPSILON: times.append(value)

static func _mood_interval(person: Dictionary, start: Array[float], finish: Array[float], duration: float, cleanliness: float) -> void:
	if person.get("want_leave", false) or person.get("state", "") == "departing": return
	var first := _raw_mood(start, cleanliness)
	var last := _raw_mood(finish, cleanliness)
	var times: Array[float] = [0.0, duration]
	if absf(last - first) > EPSILON:
		for threshold in [SEVERE_MOOD, RECOVERED_MOOD]:
			_add_time(times, (threshold - first) / (last - first) * duration, duration)
	times.sort()
	for index in range(times.size() - 1):
		var step := times[index + 1] - times[index]
		if step <= EPSILON: continue
		var fraction := (times[index] + step * 0.5) / duration
		var mood := lerpf(first, last, fraction)
		if mood >= RECOVERED_MOOD:
			_recover(person)
		elif mood <= SEVERE_MOOD:
			_dissatisfied(person, step, _interpolate(start, finish, times[index] / duration), _interpolate(start, finish, times[index + 1] / duration), cleanliness)
		elif float(person.get("unhappy_elapsed", 0.0)) < WARNING_AFTER:
			person["unhappy_elapsed"] = 0.0

static func _dissatisfied(person: Dictionary, delta: float, start: Array[float], finish: Array[float], cleanliness: float) -> void:
	if person.get("want_leave", false): return
	var unhappy := clampf(float(person.get("unhappy_elapsed", 0.0)), 0.0, WARNING_AFTER)
	var was_warned := unhappy >= WARNING_AFTER - EPSILON
	if was_warned: unhappy = WARNING_AFTER
	var before_warning := minf(delta, WARNING_AFTER - unhappy)
	unhappy += before_warning
	person["unhappy_elapsed"] = WARNING_AFTER if unhappy >= WARNING_AFTER - EPSILON else unhappy
	if unhappy < WARNING_AFTER - EPSILON: return
	if not was_warned:
		var cause := _mood_reason(_interpolate(start, finish, before_warning / delta), cleanliness)
		person["reason"] = cause + " Considering an early checkout; there is still time to help."
		_event(person, "Considering an early checkout. " + cause)
	var previous_warning := float(person.get("warning_elapsed", 0.0))
	person["warning_elapsed"] = minf(WARNING_GRACE, previous_warning + delta - before_warning)
	if float(person.warning_elapsed) >= WARNING_GRACE - EPSILON:
		var leave_fraction := clampf((before_warning + WARNING_GRACE - previous_warning) / delta, 0.0, 1.0)
		var cause := _mood_reason(_interpolate(start, finish, leave_fraction), cleanliness)
		person["warning_elapsed"] = WARNING_GRACE
		person["want_leave"] = true
		person["reason"] = cause + " Leaving early after a prolonged unhappy spell."
		_event(person, String(person.reason))

static func _recover(person: Dictionary) -> void:
	if person.get("want_leave", false): return
	if float(person.get("unhappy_elapsed", 0.0)) >= WARNING_AFTER - EPSILON or float(person.get("warning_elapsed", 0.0)) > 0.0:
		person["reason"] = "Feeling better and happy to continue the stay."
		_event(person, "Feeling better; cancelled the early-checkout warning.")
	person["unhappy_elapsed"] = 0.0
	person["warning_elapsed"] = 0.0

static func _mood_reason(needs: Array[float], cleanliness: float) -> String:
	if needs[0] < 20.0 and needs[0] <= needs[1]: return "Still hungry and unable to find a satisfying meal."
	if needs[1] < 20.0: return "Exhausted and in need of proper rest."
	if cleanliness < 45.0: return "The mess nearby is spoiling the stay."
	if needs[2] < 20.0: return "There has not been enough to enjoy."
	return "Feeling comfortable." if _raw_mood(needs, cleanliness) >= RECOVERED_MOOD else "The stay has not been comfortable enough."

static func _event(person: Dictionary, message: String) -> void:
	var history: Array = person.get("history", [])
	history.append(message)
	while history.size() > HISTORY_LIMIT: history.pop_front()
	person["history"] = history

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 9007199254740991.0 and float(value) == floorf(float(value))

static func _reserve(party: Dictionary) -> int:
	# Booking rate is optional; the current contract's fixed room price is $60.
	if not _integer(party.get("nights")) or float(party.nights) < 1.0 or float(party.nights) > 3.0: return -1
	if not _integer(party.get("paid_nights")) or float(party.paid_nights) < 0.0 or float(party.paid_nights) > float(party.nights): return -1
	if party.has("booking_rate") and (not _integer(party.booking_rate) or float(party.booking_rate) < 0.0): return -1
	var nights := int(party.nights)
	var paid := int(party.paid_nights)
	var rate := int(party.get("booking_rate", NIGHTLY_RATE))
	return (nights - paid) * rate

static func _offers(available: Array[Dictionary], spending_money: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for entry in available:
		if not entry.get("available") is bool or not entry.available: continue
		if not _integer(entry.get("id")) or float(entry.id) <= 0.0: continue
		if not _integer(entry.get("price")) or float(entry.price) < 0.0 or float(entry.price) > spending_money: continue
		if not _integer(entry.get("queue", 0)) or float(entry.get("queue", 0)) < 0.0: continue
		var distance: Variant = entry.get("distance", 0.0)
		if not (distance is int or distance is float) or not is_finite(float(distance)) or float(distance) < 0.0: continue
		var activity: String = String(ResortServices.KINDS.find_key(entry.get("kind", ""))) if entry.get("kind", "") in ResortServices.KINDS.values() else ""
		if activity.is_empty(): continue
		var waiting: Variant=entry.get("waiting_players",0)
		if not _integer(waiting) or waiting<0: continue
		offers.append({"activity": activity, "facility_id": int(entry.id), "price": int(entry.price), "distance": float(distance), "queue": int(entry.get("queue", 0)),"waiting_players":int(waiting)})
	return offers

static func _best_facility(activity: String, offers: Array[Dictionary], person: Dictionary, needs: Array[float]) -> Dictionary:
	var best: Dictionary = {}
	for offer in offers:
		if offer.activity != activity: continue
		var score := 0.0
		match activity:
			"meal": score = maxf(0.0, 75.0 - needs[0]) * 1.05 + (10.0 if _likes(person, activity) else 0.0)
			"sunbathe": score = 5.0 + maxf(0.0, 90.0 - needs[2]) * 0.7 + maxf(0.0, 80.0 - needs[1]) * 0.25 + (24.0 if _likes(person, activity) else 0.0) + (6.0 if _likes(person, "rest") else 0.0)
			"volleyball": score = 5.0 + maxf(0.0, 90.0 - needs[2]) * 0.8 + (28.0 if _likes(person, activity) else 0.0) - maxf(0.0, 55.0 - needs[1]) * 1.1 - maxf(0.0, 50.0 - needs[0]) * 0.5
			"restaurant": score = maxf(0.0, 82.0 - needs[0]) * 1.12 + (14.0 if _likes(person, activity) else 4.0)
			"ice_cream": score = maxf(0.0, 75.0 - needs[0]) * (0.98 if needs[0] > 32.0 else 0.80) + maxf(0.0, 70.0 - needs[2]) * 0.34
			"gym", "pickleball": score = 10.0 + maxf(0.0, 90.0 - needs[2]) * 0.80 + (22.0 if _likes(person, activity) else 0.0) - maxf(0.0, 60.0 - needs[1]) * 1.1
			"sauna", "yoga", "massage": score = 12.0 + maxf(0.0, 80.0 - needs[1]) * 0.70 + maxf(0.0, 80.0 - needs[2]) * 0.35 + (18.0 if _likes(person, activity) else 0.0)
			"gear": score = 14.0 + maxf(0.0, 85.0 - needs[2]) * 0.63 + (20.0 if _likes(person, activity) else 0.0)
		if activity in ResortServices.PAIRED and offer.waiting_players>0 and needs[0]>40 and needs[1]>=45 and (needs[2]<75 or _likes(person,activity)):
			score+=36.0
		score -= float(offer.price) * 0.35 + float(offer.distance) * 0.6 + float(offer.queue) * 6.0 + _repeat_penalty(person, activity)
		var candidate := offer.duplicate()
		candidate["score"] = score
		if best.is_empty() or _better(candidate, best): best = candidate
	return best

static func _better(candidate: Dictionary, current: Dictionary) -> bool:
	if absf(float(candidate.score) - float(current.score)) > 0.00001: return float(candidate.score) > float(current.score)
	if int(candidate.facility_id) != int(current.facility_id): return int(candidate.facility_id) < int(current.facility_id)
	return String(candidate.activity) < String(current.activity)

static func _repeat_penalty(person: Dictionary, activity: String) -> float:
	# W1 retains last_activity when it clears activity at the safe decision seam.
	return 8.0 if person.get("last_activity", person.get("activity", "")) == activity else 0.0

static func _likes(person: Dictionary, activity: String) -> bool:
	var profile: Dictionary = person.get("profile", {})
	var interests: Array = profile.get("interests", [])
	var aliases: Array = {
		"meal": ["good food", "food", "cafe", "café", "dining"],
		"sunbathe": ["sunbathing", "sunbathe", "sunbeds"],
		"volleyball": ["volleyball", "sport", "sports"],
		"rest": ["quiet time", "quiet rest", "rest", "relaxation"],
		"stroll": ["beach walks", "beach", "walking", "stroll"],
		"restaurant": ["meal", "good food", "food", "dining"],
		"ice_cream": ["ice cream", "food"],
		"gym": ["gym", "fitness", "sport", "sports", "volleyball"],
		"sauna": ["sauna", "quiet time", "rest"],
		"yoga": ["yoga", "rest", "sunbathe"],
		"massage": ["massage", "quiet rest", "relaxation", "sunbathe"],
		"gear": ["surfing", "beach", "beach walks", "stroll"],
		"pickleball": ["pickleball", "sport", "sports", "volleyball"],
	}.get(activity, [activity])
	for interest in interests:
		if interest is String and String(interest).strip_edges().to_lower() in aliases: return true
	return false

static func _facility_intent(option: Dictionary, person: Dictionary, urgent: bool) -> Dictionary:
	var reason := ""
	match String(option.activity):
		"meal": reason = "Hungry; heading to the café for a meal." if urgent else "Taking time for a satisfying café meal."
		"sunbathe": reason = "Sunbathing is a favourite; heading for a lounger." if _likes(person, "sunbathe") else "Relaxing on a lounger to enjoy the beach and recover some rest."
		"volleyball": reason = "Ready for a game; volleyball is a favourite." if _likes(person, "volleyball") else "Looking for an available volleyball game."
	if option.activity in ResortServices.EXPANSION: reason = "Heading to the %s." % ResortServices.label(option.activity).to_lower()
	if option.activity in ResortServices.PAIRED and int(option.get("waiting_players",0))>0: reason = "Joining another visitor at the court."
	if int(option.get("queue", 0)) > 0: reason += " There is a short queue."
	return _intent(String(option.activity), int(option.facility_id), reason)

static func _intent(activity: String, facility_id: int, reason: String) -> Dictionary:
	return {"activity": activity, "facility_id": facility_id, "reason": reason}
