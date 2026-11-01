extends SceneTree
## Actual-world GPU evidence, with isolated startup and honest crowd accounting.
## Run with a real Compatibility renderer. This script cannot approve artwork.

const OUTPUT := "res://artifacts/living-resort-capture.json"
const PROTECTED := ["res://artifacts/coastal-layout.json", "res://artifacts/coastal-layout.json.bak", "user://coastal-layout.json", "user://coastal-layout.json.bak"]
var report: Dictionary = {"status": "pending", "screenshots": [], "reasons": [], "visual_review": "pending human/independent inspection; PNG existence is not approval"}
var before: Dictionary = {}
var resort: Node
var simulation: Variant
var sample_frames := 600
var minimum_people := 8
var seek_seconds := 1200.0
var condition := "crowd"
var fixture := "default"
var output_tag := ""
var section := ""
var speed := 1
var seek_people := 8
var hire_cleaner := false
var sequence_frames := 0

func _six_cabin_fixture() -> ResortLayout:
	var map := ResortLayout.new()
	for x in range(44):
		map.paths[Vector2i(x, 9)] = true
		map.paths[Vector2i(x, 19)] = true
	for y in range(9, 21): map.paths[Vector2i(42, y)] = true
	for index in 6:
		var origin := Vector2(1 + index * 7, 3)
		var facing := index % 2
		var door := Vector2i(origin) + ResortCatalog.entrance("cabin", facing)
		for y in range(door.y, 10): map.paths[Vector2i(door.x, y)] = true
		var result := map.place("cabin", origin, facing)
		if not result.ok:
			report.reasons.append("Invalid isolated cabin fixture: " + str(result))
			return null
	for y in range(16, 20): map.paths[Vector2i(34, y)] = true
	for entry in [["cafe", Vector2(32, 12)], ["sunbeds", Vector2(7, 23)], ["sunbeds", Vector2(12, 23)], ["volleyball", Vector2(28, 26)]]:
		if fixture == "court-pair" and entry[0] != "volleyball": continue
		var result := map.place(entry[0], entry[1])
		if not result.ok:
			report.reasons.append("Invalid isolated facility fixture: " + str(result))
			return null
	return map

func _initialize() -> void:
	_run.call_deferred()

func _hashes() -> Dictionary:
	var values := {}
	for path in PROTECTED:
		values[path] = {"exists": FileAccess.file_exists(path), "sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""}
	return values

func _find_simulation() -> Variant:
	for info in resort.get_property_list():
		if info.name == "living":
			var runtime = resort.get("living")
			if runtime != null: return runtime.simulation
	for info in resort.get_property_list():
		if info.type != TYPE_OBJECT: continue
		var value = resort.get(info.name)
		if value != null and value.has_method("person") and value.has_method("party") and value.has_method("import_legacy"): return value
	return null

func _counts() -> Dictionary:
	var customers := 0
	var accommodated := 0
	var bookings := 0
	var queue := 0
	var activities := {}
	var staff := 0
	var cleaning := 0
	var walking := 0
	var dirt := 0
	for p in simulation.people:
		if p.state == "departed": continue
		customers += 1
		var party: Dictionary = simulation.party(p.party_id)
		if party.get("cabin_id", -1) > 0: accommodated += 1
		if p.state == "queueing": queue += 1
		activities[p.state] = int(activities.get(p.state, 0)) + 1
	for party in simulation.parties:
		if party.get("cabin_id", -1) > 0: bookings += 1
	if simulation.cleanliness != null:
		var view: Dictionary = simulation.cleanliness.inspect()
		dirt = view.get("mess", []).size()
		for record in view.get("staff", []):
			staff += 1
			if record.get("state", "") == "cleaning": cleaning += 1
			if record.get("state", "") == "walking": walking += 1
	return {"customers": customers, "accommodated_customers": accommodated, "active_bookings": bookings, "queueing": queue, "states": activities, "staff": staff, "cleaning": cleaning, "walking_staff": walking, "mess": dirt}

func _matches(counts: Dictionary) -> bool:
	match condition:
		"crowd": return counts.accommodated_customers >= seek_people and counts.active_bookings >= 4
		"queue": return counts.queueing > 0
		"meal": return counts.states.get("eating", 0) > 0
		"volleyball": return counts.states.get("volleyball", 0) >= 2
		"cleaning": return counts.cleaning > 0 and counts.mess > 0
		"staff-walking": return counts.walking_staff > 0
		"split":
			for party in simulation.parties:
				if party.member_ids.size() != 2: continue
				var a: Dictionary = simulation.person(party.member_ids[0])
				var b: Dictionary = simulation.person(party.member_ids[1])
				if a.activity != b.activity and a.motion.position.distance_to(b.motion.position) > 2.0 and not a.state in ["departing", "departed"] and not b.state in ["departing", "departed"]: return true
		"sleeping": return counts.states.get("sleeping", 0) >= 2
	return false

func _capture(suffix: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		report.reasons.append("Renderer did not return an actual viewport image")
		return false
	var path := "res://artifacts/living-resort-" + (output_tag if not output_tag.is_empty() else condition) + "-" + suffix + ".png"
	var error := image.save_png(path)
	if error != OK:
		report.reasons.append("GPU screenshot write failed: " + str(error))
		return false
	report.screenshots.append({"path": ProjectSettings.globalize_path(path), "width": image.get_width(), "height": image.get_height(), "clock": simulation.clock, "population": _counts()})
	if condition == "volleyball":
		if not report.has("rally_samples"): report.rally_samples = []
		for key in resort.get("population_view").balls:
			var ball = resort.get("population_view").balls[key]
			report.rally_samples.append({"clock": simulation.clock, "players": key, "ball_world_center": ball.position + ball.ball_offset, "ball_screen_center": ball.get_global_transform_with_canvas() * ball.ball_offset})
	return true

func _percentile(values: Array[float], quantile: float) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(ceil(quantile * sorted.size())) - 1, 0, sorted.size() - 1)]

func _run() -> void:
	before = _hashes()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sample-frames="): sample_frames = int(arg.trim_prefix("--sample-frames="))
		if arg.begins_with("--minimum-people="): minimum_people = int(arg.trim_prefix("--minimum-people="))
		if arg.begins_with("--seek-seconds="): seek_seconds = float(arg.trim_prefix("--seek-seconds="))
		if arg.begins_with("--condition="): condition = arg.trim_prefix("--condition=")
		if arg.begins_with("--fixture="): fixture = arg.trim_prefix("--fixture=")
		if arg.begins_with("--output-tag="): output_tag = arg.trim_prefix("--output-tag=")
		if arg.begins_with("--section="): section = arg.trim_prefix("--section=")
		if arg.begins_with("--speed="): speed = int(arg.trim_prefix("--speed="))
		if arg.begins_with("--seek-people="): seek_people = int(arg.trim_prefix("--seek-people="))
		if arg == "--hire-cleaner": hire_cleaner = true
		if arg.begins_with("--sequence-frames="): sequence_frames = int(arg.trim_prefix("--sequence-frames="))
	if "--workspace-data" in OS.get_cmdline_user_args() or "--fresh" in OS.get_cmdline_user_args():
		report.reasons.append("Refusing --workspace-data; capture must bind an isolated save before scene startup")
		_finish(1)
		return
	seek_people = maxi(minimum_people, seek_people)
	var safe_tag := output_tag.is_empty() or (output_tag.validate_filename() == output_tag and not output_tag.contains("."))
	if not safe_tag or not fixture in ["default", "six-cabins", "court-pair"] or not speed in [1, 2, 4] or not section in ["", "guests", "facilities", "staff", "operations"] or sequence_frames < 0 or sequence_frames > 40 or seek_people > 12 or not condition in ["crowd", "queue", "meal", "volleyball", "cleaning", "staff-walking", "split", "sleeping"] or sample_frames < 60 or sample_frames > 3600 or minimum_people < 1 or minimum_people > 12 or not is_finite(seek_seconds) or seek_seconds < 0 or seek_seconds > 3600:
		report.reasons.append("Invalid capture parameters; see living-resort-qa.md")
		_finish(1)
		return
	if DisplayServer.get_name() == "headless":
		report.reasons.append("GPU evidence unavailable in headless mode; no screenshot or performance pass claimed")
		_finish(2)
		return
	var scene = load("res://scenes/world/coastal_resort.tscn")
	if scene == null:
		report.reasons.append("World scene did not load")
		_finish(1)
		return
	resort = scene.instantiate()
	# Do not read/write the player's workspace or user:// save, even at _ready.
	var isolated_path := "res://artifacts/living-resort-capture-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_msec()) + ".json"
	if fixture in ["six-cabins", "court-pair"]:
		var map := _six_cabin_fixture()
		if map == null or map.save_layout(isolated_path) != OK:
			report.reasons.append("Validated six-cabin fixture could not be saved to its isolated path")
			_finish(1)
			return
	resort.set("save_path", isolated_path)
	root.add_child(resort)
	resort.set_process(false)
	resort.set_process_input(false)
	resort.set_process_unhandled_input(false)
	simulation = _find_simulation()
	if simulation == null:
		report.reasons.append("Coordinator has not connected the new population to the actual world scene")
		_finish(2)
		return
	resort.call("_on_action", "speed_1")
	# Hiring uses the real staff service. No artificial mess, guests, routes,
	# facility tickets or presented actor duplicates are injected for evidence.
	if (condition in ["cleaning", "staff-walking"] or hire_cleaner) and simulation.cleanliness != null:
		resort.call("_management_action", "hire_janitor", 0)
		report.hired_staff = simulation.cleanliness.inspect().hired_count
	var found := _matches(_counts())
	var peak := 0
	var begin: float = simulation.clock
	var seek_ticks := 0
	while not found and simulation.clock - begin < seek_seconds:
		if fixture == "court-pair":
			for p in simulation.people:
				if p.party_id == 1:
					p.needs = {"hunger": 90.0, "rest": 90.0, "enjoyment": 1.0}
					p.profile.interests = ["volleyball", "stroll"]
		resort.call("_process", 0.1)
		var counts := _counts()
		peak = maxi(peak, counts.accommodated_customers)
		found = _matches(counts)
		seek_ticks += 1
		if seek_ticks % 120 == 0: await process_frame
	report.renderer = {"display": DisplayServer.get_name(), "adapter": RenderingServer.get_video_adapter_name(), "vendor": RenderingServer.get_video_adapter_vendor(), "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"), "engine": Engine.get_version_info().string}
	report.seek = {"condition": condition, "simulation_seconds": simulation.clock - begin, "peak_accommodated_customers": peak, "minimum_people": minimum_people, "found": found}
	if not found:
		report.reasons.append("Required actual-world scenario was not observed within the bounded seek; evidence remains pending")
		_finish(2)
		return
	resort.call("home_view")
	if not section.is_empty():
		resort.get("management").call("show_section", section)
		resort.call("_refresh_management")
	report.fixture = fixture
	report.ui_section = section
	report.ambient_walkers = resort.get("walkers").size()
	report.visible_customer_actors = 0
	for actor in resort.get("population_view").actors.values():
		if actor.visible: report.visible_customer_actors += 1
	var overview := await _capture("overview")
	var camera = resort.get("camera")
	var focus: Variant = null
	for p in simulation.people:
		if p.state == "departed": continue
		if condition == "queue" and p.state != "queueing": continue
		if condition == "meal" and p.state != "eating": continue
		if condition == "volleyball" and p.state != "volleyball": continue
		if condition == "sleeping" and p.state != "sleeping": continue
		focus = p.motion.position
		break
	if condition in ["cleaning", "staff-walking"]:
		for staff in simulation.cleanliness.inspect().get("staff", []):
			if staff.get("state", "") == ("walking" if condition == "staff-walking" else "cleaning"): focus = staff.get("position")
	if focus is Vector2 and camera != null:
		camera.position = IsometricGrid.project(focus) + Vector2(0, -35)
		camera.zoom = Vector2.ONE * 1.8
		camera.force_update_scroll()
	var closeup := await _capture("closeup")
	for frame in sequence_frames:
		resort.call("_process", 0.10)
		await _capture("motion-%02d" % frame)
	resort.call("home_view")
	resort.call("_on_action", "speed_" + str(speed))
	# Real rendered frames at ordinary 1x. Wall frame intervals include vsync/OS
	# scheduling. CPU _process timings are separate; neither is a GPU timer.
	var intervals: Array[float] = []
	var cpu: Array[float] = []
	var minimum_sample := 1000000
	var maximum_sample := 0
	var minimum_bookings := 1000000
	var last := Time.get_ticks_usec()
	for frame in sample_frames:
		await process_frame
		var now := Time.get_ticks_usec()
		var seconds := float(now - last) / 1000000.0
		last = now
		var start_cpu := Time.get_ticks_usec()
		resort.call("_process", seconds)
		cpu.append(float(Time.get_ticks_usec() - start_cpu) / 1000.0)
		intervals.append(seconds * 1000.0)
		var counts := _counts()
		minimum_sample = mini(minimum_sample, counts.accommodated_customers)
		maximum_sample = maxi(maximum_sample, counts.accommodated_customers)
		minimum_bookings = mini(minimum_bookings, counts.active_bookings)
	report.performance = {"frames": sample_frames, "speed": 1, "wall_frame_ms_p50": _percentile(intervals, 0.50), "wall_frame_ms_p95": _percentile(intervals, 0.95), "world_cpu_ms_p50": _percentile(cpu, 0.50), "world_cpu_ms_p95": _percentile(cpu, 0.95), "minimum_accommodated_customers": minimum_sample, "maximum_accommodated_customers": maximum_sample, "minimum_active_bookings": minimum_bookings, "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "draw_calls_last_frame": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "scope": "Rendered real world at 1x; includes UI and staff. Wall pacing is not GPU execution time. No 100–200-person claim."}
	report.performance.speed = speed
	report.performance.scope = "Actual rendered world and management UI at %dx; wall frame intervals include OS/vsync, separate CPU time is not GPU execution time; no 100–200-person claim." % speed
	var crowd_valid := condition != "crowd" or (minimum_sample >= minimum_people and minimum_bookings >= 4)
	if not crowd_valid: report.reasons.append("Crowd fell below the requested accommodated population during profiling; do not label this a qualifying crowd sample")
	report.status = "captured_review_pending" if overview and closeup and crowd_valid else "pending"
	_finish(0 if overview and closeup and crowd_valid else 2)

func _finish(code: int) -> void:
	report.protected_saves_before = before
	report.protected_saves_after = _hashes()
	if report.protected_saves_before != report.protected_saves_after:
		report.reasons.append("Protected player save hash/presence changed during capture")
		report.status = "failed"
		code = 1
	if resort != null and is_instance_valid(resort): resort.free()
	var result_path: String = OUTPUT if output_tag.is_empty() else "res://artifacts/living-resort-" + output_tag + ".json"
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write living resort capture report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("LIVING_RESORT_CAPTURE status=", report.status, " reasons=", report.reasons, " report=", ProjectSettings.globalize_path(result_path))
	quit(code)
