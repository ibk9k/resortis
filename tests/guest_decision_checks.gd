extends SceneTree
## Pure rule scenarios: no world is started and no layout/player save is opened.

const Brain = preload("res://scripts/simulation/guest_brain.gd")
const Profiles = preload("res://scripts/simulation/guest_profiles.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	_profile_scenarios()
	_choice_scenarios()
	_recovery_scenarios()
	_warning_scenarios()
	_elapsed_time_scenarios()
	print("GUEST_DECISION_CHECKS ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func _person(hunger: float = 80.0, rest: float = 80.0, enjoyment: float = 60.0, interests: Array = []) -> Dictionary:
	return {
		"id": 1, "party_id": 1, "role": 0,
		"profile": {"name": "Maya", "variant": "female", "interests": interests.duplicate(), "initial_needs": {"hunger": hunger, "rest": rest, "enjoyment": enjoyment}},
		# The rule layer never reads motion; this fixture needs no world scene.
		"motion": null, "state": "deciding",
		"needs": {"hunger": hunger, "rest": rest, "enjoyment": enjoyment},
		"mood": 75.0, "warning_elapsed": 0.0, "want_leave": false,
		"reason": "Ready to choose an activity.", "history": [], "activity": "",
		"facility_id": -1, "slot": -1, "activity_elapsed": 0.0,
		"timer": 0.0, "session_paid": false,
	}

func _party(budget: int = 240, nights: int = 2, paid_nights: int = 1) -> Dictionary:
	return {"id": 1, "member_ids": [1, 2], "nights": nights, "initial_budget": budget, "budget": budget, "cabin_id": 10, "paid_nights": paid_nights, "room_spent": paid_nights * 60, "activity_spent": 0, "created_at": 0.0, "next_night": 180.0, "state": "staying", "history": []}

func _facilities() -> Array[Dictionary]:
	return [
		{"kind": "cafe", "id": 11, "price": 12, "distance": 1.0, "available": true, "queue": 0},
		{"kind": "sunbeds", "id": 12, "price": 8, "distance": 1.0, "available": true, "queue": 0},
		{"kind": "volleyball", "id": 13, "price": 10, "distance": 1.0, "available": true, "queue": 0},
	]

func _profile_scenarios() -> void:
	var rng := RandomNumberGenerator.new()
	var replay := RandomNumberGenerator.new()
	rng.seed = 8147
	replay.seed = 8147
	var counts: Dictionary = {}
	var lengths: Dictionary = {}
	var budgets: Dictionary = {}
	var signatures: Dictionary = {}
	for id in range(1, 65):
		var generated := Profiles.create_party(rng, id)
		expect(generated == Profiles.create_party(replay, id), "Same seeded arrival stream reproduces party %d" % id)
		counts[generated.members.size()] = true
		lengths[generated.nights] = true
		budgets[generated.budget] = true
		expect(generated.nights >= 1 and generated.nights <= 3 and generated.members.size() in [1, 2], "Arrival has supported party/stay size %d" % id)
		expect(generated.budget >= generated.nights * 60 + generated.members.size() * generated.nights * 22, "Budget covers shared lodging and plausible daily spending %d" % id)
		for member in generated.members:
			var unique: Dictionary = {}
			for interest in member.interests: unique[interest] = true
			expect(member.variant in ["female", "male"] and not member.name.is_empty(), "Profile has a supported appearance and a name %d" % id)
			expect(member.interests.size() in [2, 3] and unique.size() == member.interests.size(), "Profile has two or three distinct interests %d" % id)
			var valid_needs := true
			for key in ["hunger", "rest", "enjoyment"]:
				valid_needs = valid_needs and member.initial_needs[key] > 0 and member.initial_needs[key] <= 100
			expect(valid_needs, "Profile starts with valid satisfied-need values %d" % id)
			signatures[JSON.stringify(member.initial_needs)] = true
		if generated.members.size() == 2:
			expect(generated.members[0].name != generated.members[1].name, "Companions are separately identifiable %d" % id)
	var saved_rng := rng.state
	var next := Profiles.create_party(rng, 65)
	var resumed := RandomNumberGenerator.new()
	resumed.seed = 8147
	resumed.state = saved_rng
	# Godot's RNG state is restored after seed, just as the population snapshot does.
	expect(next == Profiles.create_party(resumed, 65), "Saving caller RNG state resumes the next complete profile")
	expect(counts.size() == 2 and lengths.size() == 3, "Repeated arrivals include solos, couples and all three stay lengths")
	expect(budgets.size() > 15 and signatures.size() > 30, "Arrivals vary budgets and individual starting needs")
	for size in [1, 2]:
		var forced := Profiles.create_party(rng, 100 + size, size)
		expect(forced.members.size() == size, "Caller can explicitly request %d member(s)" % size)
		if size == 2:
			var other: Dictionary = forced.members[1].duplicate(true)
			forced.members[0].initial_needs.hunger = 0.0
			forced.members[0].interests.append("Test")
			expect(forced.members[1] == other, "Companions do not share mutable profile arrays or need dictionaries")

func _choice_scenarios() -> void:
	var available := _facilities()
	var party := _party()
	var hungry := _person(12, 80, 20, ["Volleyball", "Sunbathing"])
	expect(Brain.choose(hungry, party, available, 0).activity == "meal", "Urgent hunger overrides both leisure interests")
	expect(Brain.choose(_person(80, 10, 0, ["Volleyball"]), party, available, 0).activity == "rest", "Urgent rest overrides an enjoyable game")
	expect(Brain.choose(_person(20, 3, 10), party, available, 0).activity == "rest", "Exhaustion wins when it is more urgent than hunger")
	expect(Brain.choose(_person(3, 20, 10), party, available, 0).activity == "meal", "Critical hunger wins when it is more urgent than rest")
	expect(Brain.choose(_person(80, 80, 60, ["Volleyball"]), party, available, 0).activity == "volleyball", "A sporting guest seeks volleyball")
	expect(Brain.choose(_person(80, 80, 60, ["Sunbathing"]), party, available, 0).activity == "sunbathe", "A sunbathing guest seeks a lounger")
	expect(Brain.choose(_person(80, 80, 60, ["Beach walks"]), party, available, 0).activity == "stroll", "A beach walker chooses a free walk")
	expect(Brain.choose(_person(80, 35, 90, ["Quiet time"]), party, available, 0).activity == "rest", "A quiet guest takes a useful cabin break")
	var varied := _person(80, 80, 60, ["Volleyball", "Sunbathing"])
	expect(Brain.choose(varied, party, available, 0).activity == "volleyball", "A fresh choice favours the stronger leisure interest")
	varied["last_activity"] = "volleyball"
	expect(Brain.choose(varied, party, available, 0).activity == "sunbathe", "The controller's previous completed activity encourages a different compatible leisure choice")
	var reserve_only := _party(70)
	var blocked := Brain.choose(hungry, reserve_only, available, 0)
	expect(blocked.activity == "stroll" and blocked.facility_id == -1 and blocked.reason.contains("room money"), "An unaffordable meal never consumes the unpaid room reserve")
	expect(Brain.choose(hungry, _party(72), available, 0).activity == "meal", "Exactly $12 above the shared reserve buys one meal")
	expect(Brain.choose(hungry, _party(12, 2, 2), available, 0).activity == "meal", "Fully paid lodging releases the room reserve")
	expect(Brain.choose(hungry, _party(132, 2, 0), available, 0).activity == "meal", "Before check-in all unpaid nights are protected")
	var changed_rate := _party(191, 3, 1)
	changed_rate["booking_rate"] = 90
	expect(Brain.choose(hungry, changed_rate, available, 0).facility_id == -1, "An explicit booking rate protects the correct unpaid amount")
	changed_rate.budget = 192
	expect(Brain.choose(hungry, changed_rate, available, 0).activity == "meal", "An exact meal purchase respects a changed booking rate")
	for key in ["nights", "paid_nights", "budget", "booking_rate"]:
		var invalid_money := _party(240)
		invalid_money[key] = 1.5
		expect(Brain.choose(hungry, invalid_money, available, 0).facility_id == -1, "Fractional JSON money/stay field cannot enable a paid purchase: " + key)
	var oversized := _party()
	oversized.budget = 1.0e30
	expect(Brain.choose(hungry, oversized, available, 0).facility_id == -1, "Out-of-range JSON money is rejected before integer conversion")
	available[0].available = false
	expect(Brain.choose(hungry, party, available, 0).facility_id == -1, "Unavailable food produces a free alternative, not unrelated paid leisure")
	expect(Brain.choose(_person(10, 20, 70), party, available, 0).activity == "rest", "No food and low rest produces useful cabin rest")
	var none: Array[Dictionary] = []
	expect(Brain.choose(_person(), party, none, 0).activity == "stroll", "An empty facility catalogue still permits a free stroll")
	var cafes: Array[Dictionary] = [
		{"kind": "cafe", "id": 20, "price": 12, "distance": 1.0, "available": true, "queue": 3},
		{"kind": "cafe", "id": 21, "price": 12, "distance": 3.0, "available": true, "queue": 0},
	]
	expect(Brain.choose(hungry, party, cafes, 0).facility_id == 21, "A short walk beats a long café queue")
	cafes[0].queue = 0
	expect(Brain.choose(hungry, party, cafes, 0).facility_id == 20, "Otherwise the nearer café is preferred")
	cafes[0].distance = 3.0
	var before := Brain.choose(hungry, party, cafes, 0)
	cafes.reverse()
	expect(before == Brain.choose(hungry, party, cafes, 300), "Tied choices are stable across offer order and repeated updates")
	var malformed: Array[Dictionary] = []
	for key in ["id", "price", "queue"]:
		var bad := _facilities()[0].duplicate()
		bad[key] = 1.5
		malformed.append(bad)
	var bad_distance := _facilities()[0].duplicate()
	bad_distance.distance = NAN
	malformed.append(bad_distance)
	expect(Brain.choose(hungry, party, malformed, 0).facility_id == -1, "Fractional JSON identities/prices/queues and nonfinite distance are rejected")
	var json_offers: Array[Dictionary] = []
	for entry in JSON.parse_string(JSON.stringify(_facilities())): json_offers.append(entry)
	expect(Brain.choose(hungry, party, json_offers, 0).activity == "meal", "Integral JSON numeric facility fields remain valid")
	var budget_before: int = party.budget
	var needs_before: Dictionary = hungry.needs.duplicate()
	var offers_before := json_offers.duplicate(true)
	Brain.choose(hungry, party, json_offers, 0)
	expect(party.budget == budget_before and hungry.needs == needs_before and json_offers == offers_before, "Choosing an intent neither charges nor satisfies needs nor edits offers")
	var committed := _person(5, 5, 5, ["Volleyball"])
	committed.state = "queueing"
	committed.activity = "meal"
	committed.facility_id = 11
	expect(Brain.choose(committed, party, none, 0).activity == "meal", "An accepted task stays stable until the controller completes or cancels it")

func _recovery_scenarios() -> void:
	for activity_state in ["to_facility", "queueing", "approaching_activity", "sitting", "leaving_activity"]:
		var walking := _person(40, 40, 40)
		walking.state = activity_state
		walking.activity = "meal"
		Brain.advance(walking, 5)
		expect(walking.needs.hunger < 40, "Selecting a meal does not feed a guest while " + activity_state)
	for activity_state in ["eating", "sleeping", "lying", "volleyball", "strolling"]:
		var active := _person(40, 40, 40, ["Good food", "Sunbathing", "Volleyball", "Beach walks"])
		active.state = activity_state
		Brain.advance(active, 5)
		match activity_state:
			"eating": expect(active.needs.hunger > 40 and active.needs.rest < 40, "Actual eating restores hunger without replacing sleep")
			"sleeping": expect(active.needs.rest > 40 and active.needs.hunger < 40, "Actual sleep restores rest without feeding the guest")
			"lying": expect(active.needs.rest > 40 and active.needs.enjoyment > 40 and active.needs.hunger < 40, "A real lounger visit restores rest and enjoyment")
			"volleyball": expect(active.needs.enjoyment > 40 and active.needs.rest < 40, "Playing volleyball improves enjoyment and costs energy")
			"strolling": expect(active.needs.enjoyment > 40 and active.needs.rest < 40, "An actual free stroll improves enjoyment")
		Brain.advance(active, 1000)
		var bounded := true
		for key in ["hunger", "rest", "enjoyment"]: bounded = bounded and active.needs[key] >= 0 and active.needs[key] <= 100
		expect(bounded and active.mood >= 0 and active.mood <= 100, "Long activity updates keep needs and mood bounded: " + activity_state)
	var paused := _person()
	var original := paused.duplicate(true)
	for delta in [0.0, -1.0, NAN, INF]: Brain.advance(paused, delta)
	expect(paused == original, "Pause, negative and nonfinite elapsed time do not change a person")
	paused.state = "departed"
	original = paused.duplicate(true)
	Brain.advance(paused, 180)
	expect(paused == original, "Departed guests stop accumulating needs and complaints")

func _warning_scenarios() -> void:
	var clean := _person(80, 80, 80)
	var dirty := _person(80, 80, 80)
	Brain.advance(clean, 2, 100)
	Brain.advance(dirty, 2, 0)
	expect(clean.needs == dirty.needs and clean.mood > dirty.mood + 50, "Local dirt lowers mood separately from hunger, rest and enjoyment")
	expect(dirty.warning_elapsed == 0 and not dirty.want_leave, "Brief disgust does not cause an immediate departure warning")
	Brain.advance(dirty, 15, 0)
	expect(dirty.warning_elapsed == 0 and not dirty.reason.contains("early checkout"), "A warning waits for prolonged severe dissatisfaction")
	Brain.advance(dirty, 2, 0)
	expect(dirty.warning_elapsed > 0 and not dirty.want_leave and dirty.reason.contains("mess"), "Sustained severe dirt produces an explained warning with time to help")
	Brain.advance(dirty, 20, 0)
	expect(not dirty.want_leave, "The warning provides a usable grace interval")
	Brain.advance(dirty, 1, 100)
	expect(dirty.warning_elapsed == 0 and dirty.unhappy_elapsed == 0 and not dirty.want_leave and dirty.reason.contains("Feeling better"), "Cleaning allows mood recovery and cancels the departure warning")
	Brain.advance(dirty, 10, 0)
	expect(dirty.warning_elapsed == 0 and not dirty.want_leave, "A new bad spell starts a fresh warning interval after recovery")
	var failure := _person(80, 80, 80)
	Brain.advance(failure, 47, 0)
	expect(not failure.want_leave and failure.warning_elapsed > 0, "Even sustained failure does not leave before the grace interval ends")
	Brain.advance(failure, 1.1, 0)
	expect(failure.want_leave and failure.reason.contains("Leaving early"), "Sustained severe dissatisfaction eventually requests early checkout")
	var hungry := _person(0, 80, 80)
	Brain.advance(hungry, 20, 100)
	expect(hungry.warning_elapsed > 0 and hungry.reason.contains("hungry"), "An unmet vital need can independently cause an explained warning")
	hungry.state = "eating"
	Brain.advance(hungry, 10, 100)
	expect(not hungry.want_leave and hungry.warning_elapsed == 0 and hungry.needs.hunger > 40, "Reaching an actual meal can resolve a hunger warning")
	var frozen_warning := _person(80, 80, 80)
	Brain.advance(frozen_warning, 20, 0)
	var elapsed: float = frozen_warning.warning_elapsed
	Brain.advance(frozen_warning, 1, 45)
	expect(is_equal_approx(elapsed, float(frozen_warning.warning_elapsed)) and not frozen_warning.want_leave, "Improvement below full recovery pauses severe-failure time")
	var resumed: Dictionary = JSON.parse_string(JSON.stringify(_serializable_person(frozen_warning)))
	Brain.advance(frozen_warning, 4, 0)
	Brain.advance(resumed, 4, 0)
	expect(_same_rules(frozen_warning, resumed), "JSON persistence of the warning and pre-warning timers resumes the same outcome")

func _elapsed_time_scenarios() -> void:
	var coarse := _person(80, 80, 80, ["Volleyball", "Good food"])
	var fine := _person(80, 80, 80, ["Volleyball", "Good food"])
	var fast := _person(80, 80, 80, ["Volleyball", "Good food"])
	var schedule := [
		["queueing", 23.75, 0.0],
		["eating", 14.5, 100.0],
		["volleyball", 31.25, 70.0],
		["sleeping", 55.5, 100.0],
		["strolling", 13.0, 100.0],
	]
	for phase in schedule:
		coarse.state = phase[0]
		fine.state = phase[0]
		fast.state = phase[0]
		Brain.advance(coarse, phase[1], phase[2])
		_advance_chunks(fine, phase[1], phase[2], 1.0 / 60.0)
		_advance_chunks(fast, phase[1], phase[2], 0.4)
		expect(_same_rules(coarse, fine), "One elapsed update and 60 Hz agree through " + String(phase[0]))
		expect(_same_rules(coarse, fast), "One elapsed update and 4x-sized updates agree through " + String(phase[0]))
	var deprived := _person(15, 10, 30)
	var deprived_fine := _person(15, 10, 30)
	deprived.state = "sleeping"
	deprived_fine.state = "sleeping"
	Brain.advance(deprived, 70, 65)
	_advance_chunks(deprived_fine, 70, 65, 1.0 / 60.0)
	expect(_same_rules(deprived, deprived_fine), "Recovery crossing rest/hunger, mood thresholds and clamps is time-step equivalent")
	var severe := _person(80, 80, 80)
	var severe_fine := _person(80, 80, 80)
	Brain.advance(severe, 48, 0)
	_advance_chunks(severe_fine, 48, 0, 1.0 / 60.0)
	expect(_same_rules(severe, severe_fine) and severe.want_leave, "Warning and departure thresholds agree exactly at the grace boundary")
	var changing_complaint := _person(25, 80, 80)
	var changing_complaint_fine := _person(25, 80, 80)
	Brain.advance(changing_complaint, 200, 30)
	_advance_chunks(changing_complaint_fine, 200, 30, 0.1)
	expect(_same_rules(changing_complaint, changing_complaint_fine), "Complaint history describes the cause at each actual warning/departure boundary")
	# Deterministic fixed profiles exercise both mood thresholds, the vital-need
	# minimum switching between hunger/rest, and all activity-specific clamps.
	for state in ["deciding", "eating", "sleeping", "lying", "volleyball", "strolling"]:
		for values in [[8.0, 15.0, 70.0], [24.0, 20.0, 95.0], [55.0, 80.0, 25.0], [95.0, 95.0, 95.0]]:
			for cleanliness in [0.0, 45.0, 100.0]:
				var bulk := _person(values[0], values[1], values[2], ["Quiet time", "Volleyball"])
				var stepped := _person(values[0], values[1], values[2], ["Quiet time", "Volleyball"])
				bulk.state = state
				stepped.state = state
				Brain.advance(bulk, 120, cleanliness)
				_advance_chunks(stepped, 120, cleanliness, 0.4)
				expect(_same_rules(bulk, stepped), "Elapsed-time scenario: %s %s cleanliness %.0f" % [state, str(values), cleanliness])

func _advance_chunks(person: Dictionary, duration: float, cleanliness: float, step: float) -> void:
	var count := int(floor(duration / step))
	for index in count: Brain.advance(person, step, cleanliness)
	var remainder := duration - count * step
	if remainder > 0.000000001: Brain.advance(person, remainder, cleanliness)

func _same_rules(first: Dictionary, second: Dictionary) -> bool:
	for key in ["hunger", "rest", "enjoyment"]:
		if absf(float(first.needs[key]) - float(second.needs[key])) > 0.00001: return false
	for key in ["mood", "warning_elapsed", "unhappy_elapsed"]:
		if absf(float(first.get(key, 0.0)) - float(second.get(key, 0.0))) > 0.00001: return false
	return first.want_leave == second.want_leave and first.history == second.history

func _serializable_person(person: Dictionary) -> Dictionary:
	var result := person.duplicate(true)
	result.erase("motion")
	return result
