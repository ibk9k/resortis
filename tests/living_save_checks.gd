extends SceneTree
## Real schema-4 file operations and cross-service corruption checks. These are
## coordinator integration cases; all paths are isolated from the player's save.
var checks := 0
var failures: Array[String]=[]
func expect(value: bool,label: String) -> void:
	checks+=1
	if not value:
		failures.append(label)
		push_error(label)
func _initialize() -> void: _run.call_deferred()
func _runtime(map: ResortLayout,assets: ResortAssets) -> LivingResortRuntime:
	var model := LivingResortRuntime.new()
	if not model.configure(map,assets): return null
	return model
func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
func _run() -> void:
	var map := ResortLayout.new()
	map.seed_default()
	var assets := ResortAssets.new()
	var model := _runtime(map,assets)
	if model==null:
		push_error("Living service modules are not ready for save acceptance")
		quit(2)
		return
	expect(model.cleanliness.call("hire").get("ok",false),"Hire a real cleaner for payroll/job persistence")
	model.advance(240)
	var snapshot := _json(model.capture())
	var resumed := _runtime(map,assets)
	expect(resumed.restore(snapshot),"Restore complete population/facilities/cleanliness/ledger JSON")
	model.advance(40)
	for frame in 1200: resumed.advance(1.0/30.0)
	var a: Dictionary=model.simulation.call("capture")
	var b: Dictionary=resumed.simulation.call("capture")
	expect(a.people.size()==b.people.size() and a.parties.size()==b.parties.size(),"Resume preserves population and arrival generation")
	for person: Dictionary in model.simulation.get("people"):
		var other: Dictionary=resumed.simulation.call("person",int(person.id))
		expect(not other.is_empty() and person.state==other.get("state") and person.motion.position.distance_to(other.motion.position)<0.001,"Resume preserves person %s: %s %s versus %s %s" % [person.id,person.state,person.motion.position,other.get("state"),other.motion.position if not other.is_empty() else "missing"])
	expect(model.ledger.call("inspect",280.0)==resumed.ledger.call("inspect",280.0),"Different advance sizes preserve all operating results")
	if "--resume-only" in OS.get_cmdline_user_args():
		print("LIVING_SAVE_RESUME_CHECKS ",checks," failures=",failures)
		quit(0 if failures.is_empty() else 1)
		return
	var path := "res://artifacts/test-living-save-integration.json"
	map.live_resort=model.capture()
	expect(map.save_layout(path)==OK,"Save control's real atomic schema-4 file path")
	var loaded := ResortLayout.new()
	expect(loaded.load_layout(path)==OK and not loaded.live_resort.is_empty(),"Load new schema without losing the living snapshot")
	var current := _runtime(map,assets)
	expect(current.restore(_json(model.capture())),"Prepare corruption-control runtime from valid state")
	var before := JSON.stringify(current.capture())
	var crooked := _runtime(map,assets)
	expect(crooked.restore(_json(model.capture())),"Prepare independently valid ledger corruption source")
	var clock: float=crooked.simulation.get("clock")
	expect(crooked.ledger.call("record",{"id":"forged-extra-income","kind":"room","amount":60,"time":clock,"party_id":1}),"Construct a well-formed but unearned income event")
	expect(not current.restore(_json(crooked.capture())),"Reject ledger income that disagrees with actual guest payments")
	expect(JSON.stringify(current.capture())==before,"Failed cross-service restore is transactional")
	var corrupt_path := "res://artifacts/test-living-save-corrupt.json"
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.live_resort=crooked.capture()
	var file := FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	var map_before := loaded.objects.duplicate(true)
	var state_before := loaded.live_resort.duplicate(true)
	expect(loaded.load_layout(corrupt_path)!=OK and loaded.objects==map_before and loaded.live_resort==state_before,"Corrupt living file cannot replace an open map or simulation")
	# File-level corruption must fail before numeric coercion, including old
	# layouts with no service envelope. The open valid map remains the control.
	var valid_file: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for damage in ["path_type","path_fraction","object_type","id_fraction","facing_fraction","coordinate_string"]:
		var malformed: Dictionary=valid_file.duplicate(true)
		match damage:
			"path_type": malformed.paths="broken"
			"path_fraction": malformed.paths[0][0]=0.5
			"object_type": malformed.objects="broken"
			"id_fraction": malformed.objects[0].id=1.5
			"facing_fraction": malformed.objects[0].orientation=0.5
			"coordinate_string": malformed.objects[0].position[0]="broken"
		file=FileAccess.open(corrupt_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(malformed))
		file.close()
		expect(loaded.load_layout(corrupt_path)!=OK and loaded.objects==map_before and loaded.live_resort==state_before,"Malformed "+damage+" cannot coerce values or replace the open state")
	var hash_before := FileAccess.get_sha256(path)
	loaded.live_resort=crooked.capture()
	expect(loaded.save_layout(path)!=OK and FileAccess.get_sha256(path)==hash_before,"Invalid temporary snapshot cannot overwrite an existing save")
	var legacy := GuestStay.new()
	legacy.party_size=2
	legacy.configure(map,assets)
	for phase in ["entering","resting","eating","relaxing","playing_volleyball","overnight"]:
		for tick in 16000:
			legacy.advance(0.05)
			if legacy.state==phase: break
		expect(legacy.state==phase,"Reach real legacy migration fixture "+phase)
		if legacy.state!=phase: continue
		var legacy_file: Dictionary=valid_file.duplicate(true)
		legacy_file.schema=3
		legacy_file.live_resort={}
		legacy_file.guest_stay=_json(legacy.capture())
		file=FileAccess.open(corrupt_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy_file))
		file.close()
		var legacy_map := ResortLayout.new()
		expect(legacy_map.load_layout(corrupt_path)==OK,"Actual schema-3 file remains loadable "+phase)
		if phase=="entering":
			legacy_file.guest_stay.route_index+=0.5
			file=FileAccess.open(corrupt_path,FileAccess.WRITE)
			file.store_string(JSON.stringify(legacy_file))
			file.close()
			var previous_stay := legacy_map.guest_stay.duplicate(true)
			expect(legacy_map.load_layout(corrupt_path)!=OK and legacy_map.guest_stay==previous_stay,"File migration rejects fractional old route index before replacing the open map")
		var migrated := _runtime(map,assets)
		expect(migrated.import_legacy(_json(legacy.capture())),"Migrate old booking with complete attached services "+phase)
		var saved := _json(migrated.capture())
		var reloaded := _runtime(map,assets)
		expect(reloaded.restore(saved),"Immediately save/reload the migrated booking "+phase)
		var totals: Dictionary=migrated.ledger.call("inspect",float(migrated.simulation.get("clock")))
		expect(int(totals.get("income_total",-1))==legacy.revenue,"Historical income is imported once and reconciles "+phase)
		migrated.advance(2)
		reloaded.advance(2)
		expect(migrated.ledger.call("inspect",float(migrated.simulation.get("clock")))==reloaded.ledger.call("inspect",float(reloaded.simulation.get("clock"))),"Migrated activity does not replay charges on resume "+phase)
	print("LIVING_SAVE_CHECKS ",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
