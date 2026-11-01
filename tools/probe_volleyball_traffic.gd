extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var map := ResortLayout.new()
	var existing := "--existing" in OS.get_cmdline_user_args()
	var source := "user://coastal-layout.json" if existing else "res://data/coastal_map.json"
	if map.load_layout(source)!=OK:
		push_error("Traffic probe could not load its map")
		quit(1)
		return
	var runtime := LivingResortRuntime.new()
	if not runtime.configure(map,ResortAssets.new()):
		quit(1)
		return
	if existing:
		var valid := runtime.restore(map.live_resort) if not map.live_resort.is_empty() else (runtime.import_legacy(map.guest_stay) if not map.guest_stay.is_empty() else true)
		if not valid:
			push_error("Existing save cannot initialize the traffic probe")
			quit(1)
			return
	var started: float=runtime.simulation.get("clock")
	var report := {"seconds":0.0,"first_court_request":-1.0,"first_rally":-1.0,"rally_people":{},"court_requests":0,"paired_wait_resume":false,"events":[]}
	var previous := {}
	var states := {}
	for tick in 3600:
		runtime.advance(0.1)
		for person: Dictionary in runtime.simulation.get("people"):
			var last: String=previous.get(person.id,"")
			if person.activity=="volleyball" and last!="volleyball":
				report.court_requests+=1
				if report.first_court_request<0: report.first_court_request=runtime.simulation.get("clock")
			previous[person.id]=person.activity
			if person.activity=="volleyball" and states.get(person.id,"")!=person.state:
				var ticket: Dictionary=runtime.facilities.call("ticket",int(person.id))
				report.events.append({"clock":runtime.simulation.get("clock"),"id":person.id,"state":person.state,"partner":ticket.get("partner_id"),"arrived_at":ticket.get("arrived_at"),"reason":person.reason})
			states[person.id]=person.state
			if person.state=="volleyball":
				if report.first_rally<0: report.first_rally=runtime.simulation.get("clock")
				report.rally_people[str(person.id)]=true
			if not report.paired_wait_resume and person.state=="waiting_partner":
				var claim: Dictionary=runtime.facilities.call("ticket",int(person.id))
				if int(claim.get("partner_id",0))>0 and float(runtime.simulation.get("clock"))>float(claim.arrived_at)+22:
					var resumed := LivingResortRuntime.new()
					resumed.configure(map,ResortAssets.new())
					report.paired_wait_resume=resumed.restore(JSON.parse_string(JSON.stringify(runtime.capture())))
	report.seconds=runtime.simulation.get("clock")
	report["starting_clock"]=started
	print("VOLLEYBALL_TRAFFIC_CHECKS ",JSON.stringify(report))
	var file := FileAccess.open("res://artifacts/volleyball-traffic-saved.json" if existing else "res://artifacts/volleyball-traffic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	quit(0 if report.first_rally>0 and report.first_rally-started<=180 and (existing or report.paired_wait_resume) else 1)
