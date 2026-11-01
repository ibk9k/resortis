extends SceneTree
## Focused W5 checks: pure ledger and sample management views in an isolated
## viewport. No world scene, player save, import, bake or source approval.
const Ledger = preload("res://scripts/simulation/operating_ledger.gd")
const Management = preload("res://scripts/ui/resort_management_ui.gd")
const PROTECTED := ["res://artifacts/coastal-layout.json", "res://artifacts/coastal-layout.json.bak", "user://coastal-layout.json", "user://coastal-layout.json.bak"]
var checks := 0
var failures: Array[String] = []
var actions: Array[Dictionary] = []
var protected_before: Dictionary = {}
var capture_ui := false

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _same(first: Variant, second: Variant) -> bool:
	return JSON.stringify(first) == JSON.stringify(second)

func _event(id: String, kind: String, amount: int, time := 0.0) -> Dictionary:
	return {"id": id, "kind": kind, "amount": amount, "time": time}

func _ledger_totals() -> void:
	var ledger := Ledger.new()
	var empty := ledger.inspect(0)
	expect(empty.income_total == 0 and empty.wages_total == 0 and empty.net_total == 0, "Fresh ledger has zero lifetime totals")
	expect(empty.day == 1 and empty.days.size() == 1 and empty.days[0].day == 1, "Fresh day is displayed without manufacturing events")
	var events: Array[Dictionary] = [
		{"id": "room:1:1", "kind": "room", "amount": 60, "time": 0.0, "party_id": 1},
		{"id": "meal:1", "kind": "meal", "amount": 12, "time": 179.9999999, "party_id": 1, "person_id": 1},
		{"id": "wage:1:1", "kind": "wage", "amount": -30, "time": 180.0, "staff_id": 1},
		{"id": "room:1:2", "kind": "room", "amount": 60, "time": 180.0, "party_id": 1},
		_event("sunbed:1", "sunbathe", 8, 181), _event("court:1", "volleyball", 10, 182),
		_event("opening:1", "legacy_income", 24, 0)]
	for event in events: expect(ledger.record(event), "First receipt records " + event.id)
	var before := ledger.capture()
	for event in events: expect(not ledger.record(event), "Repeated receipt is idempotent " + event.id)
	expect(_same(before, ledger.capture()), "Duplicates change neither history nor totals")
	var view := ledger.inspect(180.0)
	expect(view.income_total == 174 and view.wages_total == 30 and view.net_total == 144, "Signed journal reconciles lifetime $174 income / $30 wages / $144 net")
	expect(view.today_income == 78 and view.today_wages == 30 and view.today_net == 48 and view.day == 2, "Exact boundary event belongs to day 2")
	expect(view.days[0].income == 96 and view.days[0].wages == 0 and view.days[0].net == 96, "Day 1 contains room, pre-boundary meal and honest legacy opening income")
	expect(view.room_income == 120 and view.activity_income == 54 and view.legacy_income == 24, "Room and activity subtotals include unclassified legacy activity income exactly once")
	expect(view.meal_income == 12 and view.sunbathe_income == 8 and view.volleyball_income == 10, "All activity categories remain distinct")
	expect(view.event_count == events.size() and view.last_event_time == 182.0, "Inspect exposes receipt count and maximum event time")
	var sum_income := 0
	var sum_wages := 0
	for day: Dictionary in view.days:
		sum_income += int(day.income)
		sum_wages += int(day.wages)
		expect(day.net == day.income - day.wages, "Each daily net reconciles")
	expect(sum_income == view.income_total and sum_wages == view.wages_total, "Daily totals reconcile to lifetime totals")
	var future := ledger.inspect(540)
	expect(future.day == 4 and future.today_income == 0 and future.today_wages == 0 and future.days.size() == 3, "Empty current day is shown; empty historical days are sparse")
	expect(_same(before, ledger.capture()), "Inspect never changes saved state or receipt history")
	var clone := Ledger.new()
	expect(clone.restore(_json(before)), "Journal survives normal JSON serialization")
	expect(_same(view, clone.inspect(180)), "Restored inspection matches uninterrupted ledger")
	for event in events: expect(not clone.record(event), "Resume remembers receipt " + event.id)
	var altered := before.duplicate(true)
	altered.events[0].amount = 999
	view.days[0].income = -999
	expect(_same(before, ledger.capture()), "Returned journal and daily dictionaries are detached from ledger state")
	var reordered := Ledger.new()
	for index in range(events.size() - 1, -1, -1): expect(reordered.record(events[index]), "Late delivery can record original event time")
	expect(_same(ledger.inspect(180), reordered.inspect(180)), "Delivery order does not change day allocation or displayed amounts")

func _ledger_rejection() -> void:
	var ledger := Ledger.new()
	expect(ledger.record(_event("kept", "room", 60)), "Prepare transactional rejection fixture")
	var stable := ledger.capture()
	var invalid: Array[Dictionary] = [
		{}, _event("", "room", 60), _event(" leading", "room", 60), _event("line\nbreak", "room", 60),
		_event("unknown", "construction", 30), _event("zero", "meal", 0), _event("income-sign", "room", -60),
		_event("wage-sign", "wage", 30), {"id": "fraction", "kind": "meal", "amount": 12.5, "time": 0},
		{"id": "bool", "kind": "meal", "amount": true, "time": 0},
		{"id": "string", "kind": "meal", "amount": "12", "time": 0},
		{"id": "nan", "kind": "meal", "amount": 12, "time": NAN},
		{"id": "inf", "kind": "meal", "amount": 12, "time": INF},
		{"id": "negative-time", "kind": "meal", "amount": 12, "time": -0.001},
		{"id": "boolean-time", "kind": "meal", "amount": 12, "time": false},
		{"id": 1, "kind": "room", "amount": 60, "time": 0},
		{"id": "fraction-id", "kind": "meal", "amount": 12, "time": 0, "person_id": 1.5},
		{"id": "negative-id", "kind": "wage", "amount": -30, "time": 0, "staff_id": -1},
		{"id": "metadata", "kind": "room", "amount": 60, "time": 0, "position": Vector2.ZERO},
		{"id": "kept", "kind": "room", "amount": "malformed duplicate", "time": 0},
		{"id": "kept", "kind": "room", "amount": 999, "time": 0}]
	for bad in invalid:
		expect(not ledger.record(bad), "Reject invalid receipt " + str(bad.get("id", "missing")))
		expect(_same(stable, ledger.capture()), "Invalid receipt leaves the complete journal untouched")
	expect(ledger.record(_event("fraction", "meal", 12)), "Rejected ID is not poisoned and accepts a later valid delivery")
	stable = ledger.capture()
	for mutation: String in ["version", "missing", "extra", "events_type", "entry_type", "duplicate", "malformed_duplicate", "fractional_amount", "negative_income", "nonfinite_time", "fractional_identity", "unknown_kind", "income_total", "wages_total", "net_total", "hash", "event_amount", "event_time", "event_identity", "event_id", "event_order", "fractional_version"]:
		var bad: Dictionary = _json(stable)
		match mutation:
			"version": bad.version = 2
			"fractional_version": bad.version = 1.5
			"missing": bad.erase("journal_hash")
			"extra": bad.surprise = true
			"events_type": bad.events = {}
			"entry_type": bad.events.append("not an event")
			"duplicate": bad.events.append(bad.events[0].duplicate(true))
			"malformed_duplicate":
				bad.events.append({"id": "kept", "kind": "room", "amount": "sixty", "time": 0})
			"fractional_amount": bad.events[0].amount = 60.25
			"negative_income": bad.events[0].amount = -60
			"nonfinite_time": bad.events[0].time = INF
			"fractional_identity": bad.events[0].party_id = 1.25
			"unknown_kind": bad.events[0].kind = "loan"
			"income_total": bad.income_total += 1
			"wages_total": bad.wages_total += 1
			"net_total": bad.net_total += 1
			"hash": bad.journal_hash = "0".repeat(64)
			"event_amount": bad.events[0].amount = 61
			"event_time": bad.events[0].time = 180
			"event_identity": bad.events[0].party_id = 2
			"event_id": bad.events[0].id = "changed"
			"event_order": bad.events.reverse()
		expect(not ledger.restore(bad), "Restore rejects " + mutation)
		expect(_same(stable, ledger.capture()), "Rejected " + mutation + " restore is transactional")
	var safe := Ledger.new()
	expect(safe.record(_event("largest-income", "room", Ledger.MAX_SAFE_INTEGER)), "Exact JSON-safe money limit is supported")
	expect(not safe.record(_event("overflow-income", "meal", 1)), "Income cannot overflow exact JSON-safe integers")
	expect(safe.record(_event("largest-wage", "wage", -Ledger.MAX_SAFE_INTEGER)), "Wages use the same exact integer guard")
	expect(not safe.record(_event("overflow-wages", "wage", -1)), "Wage total cannot overflow")
	expect(safe.inspect(0).net_total == 0 and Ledger.new().restore(_json(safe.capture())), "Boundary-sized exact totals round-trip")
	var floats := Ledger.new()
	expect(floats.record({"id": "json-floats", "kind": "meal", "amount": 12.0, "time": 0, "party_id": 1.0, "person_id": 2.0}), "Integral JSON floats normalize correctly")
	expect(floats.capture().events[0].amount is int and floats.capture().events[0].party_id is int, "Restored/runtime money and identities remain integer values")
	for time: float in [179.999999999, 180.0, 180.000000001, 359.999999999, 360.0]:
		var boundary := Ledger.new()
		expect(boundary.record(_event("boundary", "room", 60, time)), "Record deterministic boundary fixture")
		var view := boundary.inspect(time)
		expect(view.day == 1 + floori(time / 180.0) and view.today_income == 60, "No tolerance moves receipts across a day boundary")
		var resumed := Ledger.new()
		expect(resumed.restore(_json(boundary.capture())) and resumed.inspect(time).day == view.day, "Day boundary survives JSON capture")

func _legacy_opening_and_palette() -> void:
	# The real envelope seeds aggregate historical room/activity income at the
	# import clock. It cannot reconstruct original activity categories or dates.
	var ledger := Ledger.new()
	var room := {"id": "import-1-room", "kind": "room", "amount": 120, "time": 271.25, "party_id": 1}
	var activities := {"id": "import-1-legacy_income", "kind": "legacy_income", "amount": 46, "time": 271.25, "party_id": 1}
	expect(ledger.record(room) and ledger.record(activities), "Real legacy-opening IDs and aggregate categories record without guessing visits")
	var resumed := Ledger.new()
	expect(resumed.restore(_json(ledger.capture())), "Legacy aggregate opening journal restores through the actual JSON boundary")
	expect(not resumed.record(room) and not resumed.record(activities), "Loading the opening journal cannot bill legacy income again")
	expect(resumed.record({"id": "resort:activity:1:2", "kind": "meal", "amount": 12, "time": 275, "party_id": 1, "person_id": 1}), "A newly admitted activity extends the imported journal normally")
	var display := resumed.inspect(280)
	expect(display.income_total == 178 and display.room_income == 120 and display.activity_income == 58 and display.legacy_income == 46 and display.meal_income == 12,
		"Imported room/activity totals and new visit reconcile without reclassifying earlier meals")
	expect(display.days.size() == 1 and display.days[0].legacy_income == 46 and display.today_income == 178, "Unknown historical dates remain an opening entry on the import day")
	for pair: Array in [[Management.INK, Management.PANEL], [Management.SECONDARY, Management.PANEL], [Management.WARNING, Management.PANEL],
		[Management.MINT, Management.PANEL], [Management.INK, Color("23483d")], [Management.INK, Color("345f4b")], [Management.INSET, Management.GOLD], [Management.SECONDARY, Management.INSET]]:
		var first: float = (pair[0] as Color).srgb_to_linear().get_luminance()
		var second: float = (pair[1] as Color).srgb_to_linear().get_luminance()
		expect((maxf(first, second) + 0.05) / (minf(first, second) + 0.05) >= 4.5, "Management text and action palette meets 4.5:1 contrast")

func _sample() -> Dictionary:
	var people: Array[Dictionary] = []
	var parties: Array[Dictionary] = []
	for index in 12:
		var id := index + 1
		var party_id := 1 + index / 2
		people.append({"id": id, "party_id": party_id, "name": ["Maya", "Leo", "Amara", "Samir", "Nina", "Omar", "Sofia", "Hugo", "Lina", "Ivo", "A very long guest name", "Noah"][index],
			"variant": "female" if index % 2 == 0 else "male", "state": "queueing" if index < 4 else ("departed" if id == 12 else "strolling"),
			"position": Vector2(index, 10), "needs": {"hunger": 25 + index, "rest": 65, "enjoyment": 80}, "mood": 28 if id == 7 else 65,
			"warning_elapsed": 10.0 if id == 7 else 0.0, "want_leave": false, "reason": "Waiting for a place at the café." if index < 4 else "Taking a free walk while keeping room money aside.",
			"mood_reason": "The mess nearby is spoiling the stay." if id == 7 else "Feeling comfortable.", "interests": ["Beach walks", "Good food", "Sunbathing"],
			"budget": 240, "reserve": 120, "cabin_id": party_id, "nights": 3, "paid_nights": 1,
			"partner_id": id + 1 if index % 2 == 0 else id - 1, "history": ["Booked a shared cabin.", "Paid for the first night.", "Enjoyed a meal.", "Looking for sunshine."]})
		if index % 2 == 0: parties.append({"id": party_id, "cabin_id": party_id, "budget": 240, "reserve": 120})
	var facilities: Array[Dictionary] = []
	for index in 12:
		facilities.append({"id": 100 + index, "name": "Coastal café", "kind": "cafe", "price": 12, "capacity": 2,
			"occupants": [5, 6], "occupancy": 2, "active": [5], "reserved": [6], "exiting": [],
			"queue": [1, 2, 3, 4], "queue_count": 4, "queue_limit": 4, "reachable": index != 1, "available": false})
	facilities[2].kind = "volleyball"
	facilities[2].name = "Beach volleyball"
	facilities[2].price = 10
	facilities[2].queue = []
	facilities[2].queue_count = 0
	facilities[2].active = []
	facilities[2].reserved = [5, 6]
	facilities[2].available = true
	var staff: Array[Dictionary] = []
	for index in 3:
		staff.append({"id": index + 1, "name": ["Rina", "Ada", "Noor"][index], "role": "Janitor", "state": "cleaning" if index == 0 else "walking",
			"target_mess_id": index + 1, "activity_elapsed": 2.0, "progress": 0.45, "cleaned_count": 4, "daily_wage": 30, "reason": "Cleaning a spill beside the café."})
	var mess: Array[Dictionary] = []
	for index in 12: mess.append({"id": index + 1, "kind": "spill" if index % 2 == 0 else "litter", "facility_id": 100 + index, "claimed_by": index + 1 if index < 3 else 0})
	var ledger := Ledger.new()
	for day in 12:
		for kind: String in ["room", "meal", "sunbathe", "volleyball", "wage"]:
			ledger.record(_event("sample:%d:%s" % [day, kind], kind, {"room": 60, "meal": 12, "sunbathe": 8, "volleyball": 10, "wage": -30}[kind], day * 180.0))
	ledger.record(_event("sample:opening", "legacy_income", 24))
	return {"clock": 1990.0, "people": people, "parties": parties, "facilities": facilities,
		"cleanliness": {"mess": mess, "staff": staff, "cleanliness": 38.0, "hired_count": 3, "max_staff": 3, "daily_wage": 30, "mess_count": 12, "total_wages": 360},
		"operations": ledger.inspect(1990), "selected_person_id": 7, "following": false}

func _frames(count := 3) -> void:
	for index in count: await process_frame

func _ui() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui := Management.new()
	viewport.add_child(ui)
	ui.build()
	ui.action_requested.connect(func(action: String, id: int) -> void: actions.append({"action": action, "id": id}))
	var view := _sample()
	var original := JSON.stringify(view)
	ui.refresh(view)
	ui.show_section("guests")
	await _frames(6)
	expect(ui.panel.get_global_rect().end.y <= 722, "First opened panel fits before any navigation or viewport resize")
	var stable_count := ui.root.get_child_count()
	ui.build()
	expect(ui.root.get_child_count() == stable_count, "Building twice keeps one panel and one control tree")
	expect(ui._guest_rows.size() == 12 and ui._displayed_person_id == 7, "Every real customer has a keyed row and root selection is honored")
	expect(ui._guest_name.text == "Sofia" and ui._guest_details.warning.text.contains("20 seconds"), "Profile identifies the selected guest and remaining departure grace")
	expect(ui._guest_details.reason.text.contains("mess nearby") and ui._guest_details.budget.text.contains("$120") and ui._guest_details.budget.text.contains("shared budget"), "Profile explains complaints and the party budget/reserve")
	expect((ui._guest_rows[7].root as Button).text.contains("May leave early"), "Departure warning is visible in the guest list as well as the profile")
	var recovered := view.duplicate(true)
	recovered.people[6].warning_elapsed = 0.0
	recovered.people[6].mood = 65.0
	recovered.people[6].reason = "Feeling better and happy to continue the stay."
	recovered.people[6].mood_reason = "Feeling comfortable."
	ui.refresh(recovered)
	expect(not ui._guest_details.warning.visible and not (ui._guest_rows[7].root as Button).text.contains("May leave early"), "Root-reported recovery removes the departure warning without keeping stale UI state")
	ui.refresh(view)
	for id: int in ui._guest_rows:
		(ui._guest_rows[id].root as Button).pressed.emit()
		expect(actions.back() == {"action": "select_guest", "id": id}, "Selecting guest emits the exact model identity")
	ui._guest_follow.pressed.emit()
	expect(actions.back() == {"action": "follow_guest", "id": 7}, "Follow uses authoritative selected identity")
	var selected_button: Button = ui._guest_rows[7].root
	selected_button.grab_focus()
	var details: ScrollContainer = ui.root.find_child("GuestDetailScroll", true, false)
	details.scroll_vertical = 60
	ui._guest_list_scroll.scroll_vertical = 90
	await _frames()
	var detail_offset := details.scroll_vertical
	var list_offset: int = ui._guest_list_scroll.scroll_vertical
	for iteration in 20: ui.refresh(view)
	await _frames()
	expect(ui._guest_rows[7].root == selected_button and viewport.gui_get_focus_owner() == selected_button, "5 Hz refresh retains the focused guest control")
	expect(details.scroll_vertical == detail_offset and ui._guest_list_scroll.scroll_vertical == list_offset and detail_offset > 0 and list_offset > 0,
		"Refresh preserves independently scrolled guest list and details (detail %d → %d, list %d → %d)" % [detail_offset, details.scroll_vertical, list_offset, ui._guest_list_scroll.scroll_vertical])
	view.following = true
	ui.refresh(view)
	expect(ui._guest_follow.text == "Stop following", "Follow label reflects root camera state")
	view.selected_person_id = 12
	ui.refresh(view)
	expect(ui._guest_follow.disabled and ui._guest_details.status.text == "Stay completed", "Departed guest remains inspectable without a misleading follow action")
	view.selected_person_id = 7
	view.following = false
	ui.refresh(view)
	ui.show_section("facilities")
	await _frames()
	expect(ui._facility_rows[100].occupancy.text.contains("2 / 2") and ui._facility_rows[100].queue.text.contains("1. Maya"), "Facilities show real held places and FIFO names")
	expect(ui._facility_rows[100].users.text.contains("Using: Nina") and ui._facility_rows[100].users.text.contains("Omar"), "Active use is distinguished from approaching guests")
	expect(ui._facility_rows[101].issue.text.contains("Path blocked") and ui._facility_rows[102].issue.text.contains("both players"), "Blocked paths and volleyball partner waits are explained")
	for section: String in ["facilities", "staff", "operations"]:
		ui.show_section(section)
		await _frames()
		var scroll_name: String = {"facilities": "FacilitiesScroll", "staff": "StaffScroll", "operations": "OperationsScroll"}[section]
		var scroll: ScrollContainer = ui.root.find_child(scroll_name, true, false)
		scroll.scroll_vertical = 160
		await _frames()
		var offset := scroll.scroll_vertical
		ui.refresh(view)
		await _frames()
		expect(scroll.scroll_vertical == offset and offset > 0, section + " retains its scroll position during live refresh")
		ui.show_section("guests")
		ui.show_section(section)
		expect(scroll.scroll_vertical == offset, section + " retains scroll across navigation")
	ui.show_section("staff")
	expect(ui._hire.disabled and ui._wage_notice.text.contains("$90") and ui._wage_notice.text.contains("No hiring fee"), "Staff limit and clear recurring wage are displayed")
	for id: int in ui._staff_rows:
		(ui._staff_rows[id].dismiss as Button).pressed.emit()
		expect(actions.back() == {"action": "dismiss_janitor", "id": id}, "Dismiss only emits the exact staff intent")
	var changed := view.duplicate(true)
	changed.cleanliness.staff.pop_back()
	changed.cleanliness.hired_count = 2
	ui.refresh(changed)
	expect(not ui._hire.disabled and ui._staff_rows.size() == 2, "Root staff changes remove only the departed row and re-enable hire")
	ui._hire.pressed.emit()
	expect(actions.back() == {"action": "hire_janitor", "id": 0} and changed.cleanliness.hired_count == 2, "Hire emits intent without inventing staff state")
	ui.refresh(view)
	ui.show_section("operations")
	expect(ui._operation_cells.income.total.text == "$1104" and ui._operation_cells.wages.total.text == "−$360" and ui._operation_cells.net.total.text == "$744", "Operations labels reconcile to the event journal")
	expect(ui._operation_cells.legacy_income.total.text == "$24" and ui._operation_cells.net.today.text == "$60", "Legacy opening income stays distinct; today's net uses current-day totals")
	for size: Vector2i in [Vector2i(1440, 900), Vector2i(1280, 720), Vector2i(1024, 640), Vector2i(960, 600)]:
		viewport.size = size
		await _frames()
		for section: String in Management.SECTIONS:
			ui.show_section(section)
			await _frames()
			var rect := ui.panel.get_global_rect()
			expect(rect.position.y >= 94 and rect.end.y <= size.y - 178 and rect.position.x >= 12 and rect.end.x <= size.x - 12,
				"%s fits between HUD and build tray at %s (%s)" % [section, size, rect])
			expect(ui.panel.get_combined_minimum_size().x <= ui.panel.size.x + 1, "%s has no minimum-width overflow at %s" % [section, size])
			if capture_ui and (size == Vector2i(1440, 900) or size == Vector2i(960, 600)):
				# Capture a first-view composition after preservation assertions;
				# the production refresh never resets these scroll positions.
				for scroll_name: String in ["GuestDetailScroll", "GuestListScroll", "FacilitiesScroll", "StaffScroll", "OperationsScroll"]:
					(ui.root.find_child(scroll_name, true, false) as ScrollContainer).scroll_vertical = 0
				await _frames()
				await RenderingServer.frame_post_draw
				var picture := viewport.get_texture().get_image()
				expect(picture != null and picture.save_png("res://artifacts/worker-5-%s-%dx%d.png" % [section, size.x, size.y]) == OK, "Save sample panel render")
	ui.show_section("guests")
	await _frames()
	expect(ui._guest_switch.visible and ui._guest_details_side.visible and not ui._guest_list_scroll.visible and ui._guest_detail_scroll.size.y >= 90,
		"Small windows give the selected profile a readable scrolling area")
	ui._guest_switch.pressed.emit()
	await _frames()
	expect(ui._guest_list_scroll.visible and not ui._guest_details_side.visible, "Compact guest navigation exposes the complete list")
	(ui._guest_rows[7].root as Button).pressed.emit()
	await _frames()
	expect(ui._guest_details_side.visible and not ui._guest_list_scroll.visible and actions.back() == {"action": "select_guest", "id": 7}, "Compact selection returns to the profile and emits the guest identity")
	expect(JSON.stringify(view) == original, "UI refreshes, navigation and emitted intents do not mutate the supplied model view")
	var row: Node = ui._guest_rows[7].root
	var reduced := view.duplicate(true)
	reduced.people.remove_at(0)
	reduced.facilities.remove_at(0)
	ui.refresh(reduced)
	expect(not ui._guest_rows.has(1) and not ui._facility_rows.has(100) and ui._guest_rows[7].root == row, "Removing guests/facilities keeps unaffected rows intact")
	ui.show_section("guests")
	ui.close()
	expect(not ui.root.visible, "Root close method hides management without emitting another intent")
	ui.show_section("staff")
	ui._request_close()
	expect(not ui.root.visible and actions.back() == {"action": "close", "id": 0}, "Player close both hides and emits the root intent")
	ui.refresh({})
	ui.show_section("guests")
	expect(ui._guest_empty.visible and ui._guest_follow.disabled and ui._guest_rows.is_empty(), "Empty resort teaches arrivals and has no stale selected guest")
	ui.show_section("staff")
	expect(ui._staff_empty.visible and ui._hire.disabled, "Unavailable staff view cannot imply a working hire action")
	viewport.queue_free()
	await _frames()

func _hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in PROTECTED: result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result

func _run() -> void:
	protected_before = _hashes()
	capture_ui = "--capture" in OS.get_cmdline_user_args()
	if "--workspace-data" in OS.get_cmdline_user_args():
		expect(false, "Management checks must never use player workspace saves")
	else:
		_ledger_totals()
		_ledger_rejection()
		_legacy_opening_and_palette()
		await _ui()
	expect(_same(protected_before, _hashes()), "Player workspace/direct-play saves and backups are unchanged")
	print("MANAGEMENT_CHECKS %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
