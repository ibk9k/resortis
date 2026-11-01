class_name GuestProfiles
extends RefCounted
## Booking profiles use only the population controller's persisted RNG.

const NIGHTLY_RATE := 60
const FEMALE_NAMES := ["Aisha", "Nora", "Sofia", "Amara", "Lina", "Zara", "Iris", "Elena", "Mina", "Hana", "Ruby", "Leila"]
const MALE_NAMES := ["Arjun", "Omar", "Noah", "Luca", "Adam", "Ravi", "Elias", "Sam", "Theo", "Idris", "Finn", "Daniel"]
const INTERESTS := ["Beach walks", "Good food", "Sunbathing", "Volleyball", "Quiet time"]

static func create_party(rng: RandomNumberGenerator, party_id: int, size: int = 0) -> Dictionary:
	var count := rng.randi_range(1, 2) if size == 0 else clampi(size, 1, 2)
	var nights := rng.randi_range(1, 3)
	# These are daily spending allowances per person, in addition to shared lodging.
	# Even the modest range allows a meal and some paid/free leisure each day.
	var allowances := [rng.randi_range(22, 30), rng.randi_range(36, 48), rng.randi_range(54, 70)]
	var allowance: int = allowances[rng.randi_range(0, allowances.size() - 1)]
	var budget := nights * NIGHTLY_RATE + count * (nights * allowance + rng.randi_range(8, 24))
	var members: Array[Dictionary] = []
	var used_names: Array[String] = []
	# Companions share one interest, while their other interests and needs vary.
	var shared_interest: String = INTERESTS[rng.randi_range(0, INTERESTS.size() - 1)]
	for role in count:
		var variant := "female" if rng.randi_range(0, 1) == 0 else "male"
		var names: Array = FEMALE_NAMES if variant == "female" else MALE_NAMES
		var name_index := rng.randi_range(0, names.size() - 1)
		var guest_name: String = names[name_index]
		if guest_name in used_names:
			guest_name = names[(name_index + 1) % names.size()]
		used_names.append(guest_name)
		var interests: Array[String] = [shared_interest]
		var pool: Array[String] = []
		for interest: String in INTERESTS:
			if interest != shared_interest: pool.append(interest)
		var interest_count := rng.randi_range(2, 3)
		while interests.size() < interest_count:
			var index := rng.randi_range(0, pool.size() - 1)
			interests.append(pool[index])
			pool.remove_at(index)
		members.append({
			"name": guest_name,
			"variant": variant,
			"interests": interests,
			"initial_needs": {
				"hunger": float(rng.randi_range(42, 88)),
				"rest": float(rng.randi_range(38, 86)),
				"enjoyment": float(rng.randi_range(35, 78)),
			},
		})
	# Identity is assigned by the caller; party_id never reseeds or forks its RNG.
	assert(party_id >= 0, "Party identities must be nonnegative.")
	return {"nights": nights, "budget": budget, "members": members}
