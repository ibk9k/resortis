extends SceneTree
var failures: Array[String]=[]
var checks := 0
func expect(value: bool, label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var assets := ResortAssets.new()
	for facing in 2:
		var map := ResortLayout.new()
		map.seed_default()
		var cabins: Array[Dictionary]=[]
		for item in map.objects:
			if item.kind=="cabin": cabins.append(item)
		for index in range(1,cabins.size()): map.remove_object(cabins[index].id)
		cabins[0].orientation=facing
		var stay := GuestStay.new()
		stay.party_size=2
		stay.configure(map,assets)
		var seen: Dictionary={}
		for tick in 14000:
			stay.advance(0.05)
			if not seen.has(stay.state):
				seen[stay.state]=true
				var snapshot: Dictionary=JSON.parse_string(JSON.stringify(stay.capture()))
				var resumed := GuestStay.new()
				resumed.configure(map,assets)
				expect(resumed.restore(snapshot),"Couple JSON restore "+stay.state)
				var control := GuestStay.new()
				control.configure(map,assets)
				control.restore(snapshot)
				resumed.advance(15)
				for step in 150: control.advance(0.1)
				expect(resumed.state==control.state and resumed.budget==control.budget and resumed.logical_position.distance_to(control.logical_position)<0.0001 and resumed.companion.position.distance_to(control.companion.position)<0.0001,"Couple resume/speed equivalence "+stay.state)
				var slot := stay.activity_slot(0)
				if not slot.is_empty():
					expect(slot.position.distance_to(stay.activity_slot(1).position)>0.1,"Separate partner furniture slots "+stay.state)
					var frames := assets.activity_frames("female")
					expect(frames.has_animation(slot.pose+"_"+slot.facing),"Supported female activity view "+stay.state)
					var other := stay.activity_slot(1)
					expect(assets.activity_frames("male").has_animation(other.pose+"_"+other.facing),"Supported male activity view "+stay.state)
			if stay.state=="departed": break
		for phase in ["sitting","eating","relaxing","playing_volleyball","overnight","departed"]: expect(seen.has(phase),"Couple reaches "+phase)
		expect(stay.accommodation_spent==120 and stay.activity_spent==120 and stay.revenue==240 and stay.budget==240,"Shared room and per-person activities conserve $480")
		expect(stay.cabin_id==-1,"Couple checkout releases shared booking")
		var broken := stay.capture()
		broken.companion.route=[[10000,10000]]
		broken.companion.index=0
		var invalid := GuestStay.new()
		invalid.configure(map,assets)
		expect(not invalid.restore(broken),"Reject out-of-map companion route")
	print("COUPLE_STAY_CHECKS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
