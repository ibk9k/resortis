extends SceneTree
## Controlled dirty-area boundary through the complete runtime. Uses a valid
## saved fixture of a resting beach walker and eight reachable mess marks;
## actual shared-clock needs, warning, hiring, work and recovery run normally.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var map := ResortLayout.new()
	if map.load_layout("res://data/coastal_map.json")!=OK:
		quit(1)
		return
	var runtime := LivingResortRuntime.new()
	if not runtime.configure(map,ResortAssets.new()):
		quit(1)
		return
	# First reach a genuine checked-in strolling guest. Keep the booking, all
	# receipts and services intact; the fixture pauses this one outdoor route.
	for tick in 1000:
		runtime.advance(0.1)
		if runtime.simulation.call("person",2).get("state")=="strolling": break
	var person: Dictionary=runtime.simulation.call("person",2)
	if person.get("state")!="strolling":
		push_error("Could not prepare actual checked-in walker")
		quit(1)
		return
	var dirty: Dictionary=runtime.capture()
	var graph := map.navigation()
	var center := Vector2i(-1,-1)
	for y in range(22,29):
		for x in range(35,41):
			var clear := true
			for dy in range(-1,2):
				for dx in range(-1,2):
					if graph.is_point_solid(Vector2i(x+dx,y+dy)): clear=false
			if clear and not graph.get_id_path(Vector2i(x,y),ResortLayout.ARRIVAL).is_empty():
				center=Vector2i(x,y)
				break
		if center.x>=0: break
	if center.x<0:
		push_error("Fixture needs a reachable open three-by-three patch")
		quit(1)
		return
	# A nearby open patch gives hired staff a short real route so cleanup can
	# finish during grace; no model method is stubbed and no staff is teleported.
	for saved: Dictionary in dirty.simulation.people:
		if saved.id!=2: continue
		saved.needs={"hunger":90.0,"rest":90.0,"enjoyment":90.0}
		saved.motion.position=[center.x,center.y]
		saved.motion.route=[[center.x,center.y]]
		saved.motion.index=0
		saved.motion.delay=60.0
		saved.motion.moving=false
		saved.outdoor_target=[]
	dirty.cleanliness.mess=[]
	var facility_id := 0
	for object: Dictionary in map.objects:
		if object.kind=="cafe": facility_id=object.id
	var identity := 1
	for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
		var cell: Vector2i=center+offset
		if identity>8: break
		if not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): continue
		dirty.cleanliness.mess.append({"id":identity,"kind":"spill","position":[cell.x,cell.y],"facility_id":facility_id,"created_at":dirty.cleanliness.clock,"claimed_by":0,"style":0})
		identity+=1
	dirty.cleanliness.next_mess_id=identity
	if identity!=9 or not runtime.restore(JSON.parse_string(JSON.stringify(dirty))):
		push_error("Controlled dirty-area fixture must pass complete restore validation")
		quit(1)
		return
	var evidence: Dictionary={"fixture":"Validated checked-in walker waiting outdoors; eight pre-existing reachable spills; healthy initial needs; no invented transactions or claims","position":[center.x,center.y],"start_clock":runtime.simulation.get("clock"),"warning":{},"recovered":{},"staff":[],"peak_mess":0}
	var watched := -1
	for tick in 900:
		runtime.advance(0.1)
		var view: Dictionary=runtime.cleanliness.call("inspect")
		evidence.peak_mess=maxi(int(evidence.peak_mess),view.mess.size())
		if watched<0:
			for guest: Dictionary in runtime.simulation.get("people"):
				if guest.id!=2 or float(guest.warning_elapsed)<=0 or not "mess nearby" in str(guest.get("mood_reason","")) or guest.want_leave: continue
				watched=int(guest.id)
				evidence.warning={"clock":runtime.simulation.get("clock"),"person":watched,"state":guest.state,"mood":guest.mood,"needs":guest.needs.duplicate(),"score":runtime.cleanliness.call("score_at",guest.motion.position),"warning_elapsed":guest.warning_elapsed,"mess":view.mess.size(),"reason":guest.reason}
				for hire in 3: evidence.staff.append(runtime.cleanliness.call("hire"))
				break
		else:
			var guest: Dictionary=runtime.simulation.call("person",watched)
			if guest.is_empty(): break
			if guest.warning_elapsed==0 and not guest.want_leave and guest.mood>=43 and view.mess.size()<int(evidence.warning.mess) and guest.motion.position.distance_to(Vector2(center))<0.001:
				evidence.recovered={"clock":runtime.simulation.get("clock"),"mood":guest.mood,"warning_elapsed":guest.warning_elapsed,"wants_leave":guest.want_leave,"position":[guest.motion.position.x,guest.motion.position.y],"score":runtime.cleanliness.call("score_at",guest.motion.position),"mess":view.mess.size(),"cleaned":0,"history":guest.history.duplicate()}
				for staff: Dictionary in view.staff: evidence.recovered.cleaned+=staff.cleaned_count
				if evidence.recovered.cleaned>0: break
			if float(runtime.simulation.get("clock"))-float(evidence.warning.clock)>90: break
	var passed: bool=not evidence.warning.is_empty() and not evidence.recovered.is_empty() and int(evidence.recovered.cleaned)>0
	evidence.passed=passed
	var file := FileAccess.open("res://artifacts/living-mood-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	file.close()
	print("LIVING_MOOD_CHECKS ",JSON.stringify(evidence))
	quit(0 if passed else 1)
