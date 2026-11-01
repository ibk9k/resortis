extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var map := ResortLayout.new()
	var existing := "--existing" in OS.get_cmdline_user_args()
	var source := "res://artifacts/coastal-layout.json" if existing and FileAccess.file_exists("res://artifacts/coastal-layout.json") else ("user://coastal-layout.json" if existing else "res://data/coastal_map.json")
	if map.load_layout(source)!=OK:
		quit(1)
		return
	var model := LivingResortRuntime.new()
	if not model.configure(map,ResortAssets.new()):
		quit(1)
		return
	if existing:
		var restored := model.restore(map.live_resort) if not map.live_resort.is_empty() else (model.import_legacy(map.guest_stay) if not map.guest_stay.is_empty() else true)
		if not restored:
			push_error("Existing routing snapshot did not restore")
			quit(1)
			return
	var start: float=model.simulation.get("clock")
	var stationary := {}
	var events: Array[Dictionary]=[]
	var stuck: Dictionary={}
	var arrivals: Dictionary={}
	for tick in 2400:
		model.advance(0.25)
		for guest: Dictionary in model.simulation.get("people"):
			var previous: Dictionary=stationary.get(guest.id,{"position":guest.motion.position,"since":model.simulation.get("clock"),"state":guest.state})
			if previous.position.distance_to(guest.motion.position)>0.01 or previous.state!=guest.state:
				stationary[guest.id]={"position":guest.motion.position,"since":model.simulation.get("clock"),"state":guest.state}
			elif not stationary.has(guest.id): stationary[guest.id]=previous
			var elapsed: float=float(model.simulation.get("clock"))-float(stationary[guest.id].since)
			# Strolling deliberately includes a seven-second rest after arrival.
			var travelling: bool = guest.state in ["to_cabin","returning","departing","to_facility","approaching_activity","leaving_activity","entering","exiting"] or (guest.state == "strolling" and not guest.motion.finished())
			if travelling and elapsed>5 and not stuck.has(guest.id):
				stuck[guest.id]={"clock":model.simulation.get("clock"),"state":guest.state,"position":[guest.motion.position.x,guest.motion.position.y],"route":guest.motion.capture(),"reason":guest.reason}
			if guest.motion.position.distance_to(Vector2(ResortLayout.ARRIVAL))<6:
				var key: String="%s/%s" % [guest.id,guest.state]
				if not arrivals.has(key):
					arrivals[key]=true
					events.append({"clock":model.simulation.get("clock"),"id":guest.id,"state":guest.state,"position":[guest.motion.position.x,guest.motion.position.y],"party_age":float(model.simulation.get("clock"))-float(model.simulation.call("party",guest.party_id).created_at),"reason":guest.reason})
	var report := {"source":source,"starting_clock":start,"ending_clock":model.simulation.get("clock"),"objects":map.objects.size(),"stuck":stuck,"arrival_events":events}
	var file := FileAccess.open("res://artifacts/guest-route-probe-"+("existing" if existing else "starter")+".json",FileAccess.WRITE)
	if file == null:
		push_error("Could not write the isolated routing report")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("GUEST_ROUTE_PROBE stuck=",JSON.stringify(stuck)," arrival_events=",events.size())
	quit(0 if stuck.is_empty() else 1)
