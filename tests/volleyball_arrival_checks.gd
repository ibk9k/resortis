extends SceneTree
var failures: Array[String]=[]
func expect(value: bool,label: String) -> void:
	if not value: failures.append(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var map := ResortLayout.new()
	map.load_layout("res://data/coastal_map.json")
	var assets := ResortAssets.new()
	var court: Dictionary={}
	for object: Dictionary in map.objects:
		if object.kind=="volleyball": court=object
	var sessions := FacilitySessions.new()
	sessions.configure(map,assets)
	sessions.request(1,1,court.id,"volleyball",0)
	sessions.confirm_arrival(1,0)
	sessions.advance(15,15)
	sessions.request(2,2,court.id,"volleyball",15)
	sessions.advance(8,23)
	expect(sessions.ticket(1).status=="reserved" and sessions.ticket(1).partner_id==2,"A committed travelling opponent keeps the first player waiting beyond the lone-player deadline")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(sessions.capture()))
	var resumed := FacilitySessions.new()
	resumed.configure(map,assets)
	expect(resumed.restore(snapshot),"Save/reload an extended paired wait after the original lone deadline")
	if resumed.restore(snapshot):
		resumed.confirm_arrival(2,30)
		expect(resumed.ready(1) and resumed.ready(2),"Both actual arrivals start the same rally")
	sessions.advance(83,106)
	expect(sessions.ticket(1).status=="expired" and sessions.ticket(2).status=="expired","A missing opponent still has a bounded reservation timeout")
	var solo := FacilitySessions.new()
	solo.configure(map,assets)
	solo.request(3,3,court.id,"volleyball",0)
	solo.confirm_arrival(3,0)
	solo.advance(23,23)
	expect(solo.ticket(3).status=="expired","A truly lone visitor still leaves after 22 seconds without a fee")
	print("VOLLEYBALL_ARRIVAL_CHECKS ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
