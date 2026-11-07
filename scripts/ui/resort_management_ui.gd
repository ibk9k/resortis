class_name ResortManagementUI
extends CanvasLayer
## A view of the root's inspect dictionary. Controls emit intents only. Keyed
## rows survive refreshes, retaining focus and each section's scroll position.

signal action_requested(action: String, id: int)
signal price_requested(service: String, price: int)
signal challenge_requested(action: String, id: String)

const INK := Color("fff1cf")
const SECONDARY := Color("b9cbb4")
const GOLD := Color("edbd68")
const PANEL := Color("16352f")
const INSET := Color("102822")
const MINT := Color("8cdbb0")
const WARNING := Color("f9b5a5")
const SECTIONS := ["guests", "facilities", "staff", "operations", "challenges"]
const STATE_NAMES := {"arriving": "Arriving", "waiting_room": "Waiting for a cabin", "to_cabin": "Walking to the cabin",
	"entering": "Entering the cabin", "sleeping": "Resting in the cabin", "exiting": "Leaving the cabin",
	"deciding": "Choosing what to do", "to_facility": "Walking to a facility", "queueing": "Waiting in line",
	"approaching_activity": "Taking a place", "sitting": "Seated for a meal", "eating": "Enjoying a meal",
	"lying": "Sunbathing", "volleyball": "Playing a court match", "using_facility": "Using a facility", "leaving_activity": "Leaving a facility",
	"strolling": "Walking along the beach", "waiting_partner": "Waiting for a partner", "returning": "Returning to the cabin",
	"departing": "Checking out", "departed": "Stay completed"}

var root: Control
var panel: PanelContainer
var _view: Dictionary = {}
var _section := "guests"
var _sections: Dictionary = {}
var _tabs: Dictionary = {}
var _day_label: Label
var _people: Dictionary = {}
var _staff: Dictionary = {}
var _displayed_person_id := 0
var _guest_rows: Dictionary = {}
var _facility_rows: Dictionary = {}
var _staff_rows: Dictionary = {}
var _day_rows: Dictionary = {}
var _guest_summary: Label
var _guest_switch: Button
var _guest_body: BoxContainer
var _guest_details_side: VBoxContainer
var _guest_detail_scroll: ScrollContainer
var _compact_guests := false
var _compact_show_list := false
var _guest_list_scroll: ScrollContainer
var _guest_list: VBoxContainer
var _guest_empty: Label
var _guest_name: Label
var _guest_follow: Button
var _guest_details: Dictionary = {}
var _need_bars: Dictionary = {}
var _facility_summary: Label
var _facility_list: VBoxContainer
var _facility_empty: Label
var _clean_summary: Label
var _wage_notice: Label
var _hire: Button
var _staff_list: VBoxContainer
var _staff_empty: Label
var _mess_summary: Label
var _operations_day: Label
var _operation_cells: Dictionary = {}
var _daily_list: VBoxContainer
var _cash_summary: Label
var _finance_views := {}
var _finance_tabs := {}
var _prices := {}
var _price_status: Label
var _receipt_list: VBoxContainer
var _receipt_rows: Array = []
var _receipt_position: Label
var _receipt_back: Button
var _receipt_next: Button
var _receipt_page := 0
var _challenge_rows := {}

func build() -> void:
	if is_instance_valid(root): return
	layer = 2 # Above the existing HUD; transparent outside the management panel.
	root = Control.new()
	root.name = "ResortManagement"
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	panel = PanelContainer.new()
	panel.name = "ManagementPanel"
	root.add_child(panel)
	var column := _column(panel)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("Resort management", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	var close_button := _button("×", heading, "Close management · Esc")
	close_button.name = "CloseManagement"
	close_button.pressed.connect(_request_close)
	_day_label = _text(column, "", 14, SECONDARY)
	var navigation := HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation", 6)
	navigation.add_theme_constant_override("v_separation", 6)
	column.add_child(navigation)
	var captions := ["Guests", "Facilities", "Staff", "Results", "Challenges"]
	for index in SECTIONS.size():
		var section: String = SECTIONS[index]
		var button := _button(captions[index], navigation, "Operating results" if section == "operations" else captions[index])
		button.name = section.capitalize() + "Tab"
		button.toggle_mode = true
		button.pressed.connect(func() -> void: show_section(section))
		_tabs[section] = button
	column.add_child(HSeparator.new())
	var pages := _column(column)
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for section: String in SECTIONS:
		var page := _column(pages)
		page.name = section.capitalize() + "Section"
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		page.visible = section == _section
		_sections[section] = page
	_build_guests(_sections.guests)
	_build_facilities(_sections.facilities)
	_build_staff(_sections.staff)
	_build_operations(_sections.operations)
	_build_challenges(_sections.challenges)
	root.resized.connect(_fit_panel)
	# Wrapped text is measured again after its first container layout. Refit
	# when that minimum settles so an initially narrow label cannot leave the
	# whole panel taller than the available space when it first opens.
	panel.minimum_size_changed.connect(_fit_panel.call_deferred)
	_fit_panel()
	refresh(_view)
	root.hide()

func refresh(view: Dictionary) -> void:
	_view = view # A read-only presentation snapshot; no model dictionary is changed.
	if not is_instance_valid(root): return
	_people.clear()
	for person: Dictionary in view.get("people", []): _people[int(person.get("id", 0))] = person
	var clock := float(view.get("clock", 0.0))
	_day_label.text = "Day %d" % (1 + floori(maxf(0.0, clock) / 180.0))
	_refresh_guests()
	_refresh_facilities()
	_refresh_staff()
	_refresh_operations()
	_refresh_challenges()

func show_section(section: String) -> void:
	if section not in SECTIONS: return
	if not is_instance_valid(root): build()
	_section = section
	for key: String in SECTIONS:
		_sections[key].visible = key == section
		(_tabs[key] as Button).set_pressed_no_signal(key == section)
	root.show()
	_fit_panel()

func close() -> void:
	if is_instance_valid(root): root.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(root) and root.visible and event.is_action_pressed("ui_cancel"):
		_request_close()
		get_viewport().set_input_as_handled()

func _request_close() -> void:
	close()
	action_requested.emit("close", 0)

func _fit_panel() -> void:
	if not is_instance_valid(panel): return
	var viewport_size := root.size
	if viewport_size.x <= 0.0: viewport_size = get_viewport().get_visible_rect().size
	var width := minf(600.0, maxf(360.0, viewport_size.x * 0.43))
	width = minf(width, viewport_size.x - 36.0)
	panel.position = Vector2(viewport_size.x - width - 18.0, 94.0)
	panel.size = Vector2(width, maxf(220.0, viewport_size.y - 278.0))
	_day_label.visible = viewport_size.y >= 720.0
	if is_instance_valid(_guest_body):
		_compact_guests = width < 540.0
		_guest_list_scroll.custom_minimum_size = Vector2.ZERO if _compact_guests else Vector2(158, 0)
		_guest_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _compact_guests else Control.SIZE_FILL
		_guest_list_scroll.visible = not _compact_guests or _compact_show_list
		_guest_details_side.visible = not _compact_guests or not _compact_show_list
		_guest_switch.visible = _compact_guests
		_guest_switch.text = "Profile" if _compact_show_list else "All guests"

func _build_guests(page: VBoxContainer) -> void:
	var summary := HBoxContainer.new()
	page.add_child(summary)
	_guest_summary = _text(summary, "")
	_guest_switch = _button("All guests", summary, "Switch between the guest list and the selected profile")
	_guest_switch.name = "CompactGuestNavigation"
	_guest_switch.pressed.connect(func() -> void:
		_compact_show_list = not _compact_show_list
		_fit_panel())
	_guest_body = BoxContainer.new()
	_guest_body.add_theme_constant_override("separation", 12)
	_guest_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_guest_body)
	_guest_list_scroll = _scroll(_guest_body, "GuestListScroll")
	_guest_list = _column(_guest_list_scroll)
	_guest_list.add_theme_constant_override("separation", 6)
	_guest_empty = _text(_guest_list, "New arrivals will appear here when a cabin is available.", 15, SECONDARY)
	var detail := _column(_guest_body)
	_guest_details_side = detail
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	detail.add_child(heading)
	_guest_name = _label("Choose a guest", 20)
	_guest_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guest_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(_guest_name)
	_guest_follow = _button("Follow", heading, "Keep the camera on this guest; drag the map to stop following")
	_guest_follow.name = "FollowGuest"
	_guest_follow.pressed.connect(func() -> void:
		if _people.has(_displayed_person_id) and _people[_displayed_person_id].get("state") != "departed":
			action_requested.emit("follow_guest", _displayed_person_id))
	var scroll := _scroll(detail, "GuestDetailScroll")
	_guest_detail_scroll = scroll
	var body := _column(scroll)
	for key in ["status", "warning", "reason", "mood"]:
		_guest_details[key] = _text(body, "", 16, WARNING if key == "warning" else INK)
	for key in ["hunger", "rest", "enjoyment"]:
		var row := HBoxContainer.new()
		body.add_child(row)
		var caption := _label({"hunger": "Food", "rest": "Rest", "enjoyment": "Enjoyment"}[key], 14, SECONDARY)
		caption.custom_minimum_size.x = 82
		row.add_child(caption)
		var bar := ProgressBar.new()
		bar.name = key.capitalize() + "Need"
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(40, 18)
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.tooltip_text = "How satisfied this need is; higher is better"
		row.add_child(bar)
		var value := _label("", 14)
		value.custom_minimum_size.x = 40
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_need_bars[key] = {"bar": bar, "value": value, "root": row}
	for key in ["booking", "budget", "interests", "history"]:
		_guest_details[key] = _text(body, "", 15, SECONDARY)

func _refresh_guests() -> void:
	var active := 0
	var bookings: Dictionary = {}
	var live_ids: Array = []
	for id: int in _people:
		var person: Dictionary = _people[id]
		live_ids.append(id)
		if person.get("state") != "departed":
			active += 1
			if int(person.get("cabin_id", -1)) > 0: bookings[int(person.cabin_id)] = true
		if not _guest_rows.has(id):
			var button := _button("", _guest_list)
			button.name = "Guest%d" % id
			button.toggle_mode = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.custom_minimum_size.y = 54
			button.pressed.connect(func() -> void:
				if not _people.has(id): return
				_compact_show_list = false
				_guest_detail_scroll.scroll_vertical = 0
				_fit_panel()
				action_requested.emit("select_guest", id))
			_guest_rows[id] = {"root": button}
		var row: Button = _guest_rows[id].root
		var status := _state(person)
		if person.get("want_leave", false) and person.get("state") != "departed": status = "Leaving early"
		elif float(person.get("warning_elapsed", 0)) > 0 or float(person.get("unhappy_elapsed", 0)) >= 18.0: status = "May leave early"
		row.text = "%s\n%s" % [person.get("name", "Guest"), status]
		row.tooltip_text = "%s · %s\n%s" % [person.get("name", "Guest"), _state(person), person.get("reason", "")]
	_prune(_guest_rows, live_ids)
	_guest_summary.text = "%d guests staying · %d cabins booked" % [active, bookings.size()]
	_guest_empty.visible = _people.is_empty()
	var selected := int(_view.get("selected_person_id", 0))
	_displayed_person_id = selected if _people.has(selected) else 0
	if _displayed_person_id == 0:
		for id: int in _people:
			if _people[id].get("state") != "departed":
				_displayed_person_id = id
				break
	if _displayed_person_id == 0 and not _people.is_empty(): _displayed_person_id = int(_people.keys()[0])
	for id: int in _guest_rows: (_guest_rows[id].root as Button).set_pressed_no_signal(id == _displayed_person_id)
	var person: Dictionary = _people.get(_displayed_person_id, {})
	_guest_follow.disabled = person.is_empty() or person.get("state") == "departed"
	_guest_follow.text = "Stop following" if selected == _displayed_person_id and _view.get("following", false) else "Follow"
	_guest_name.text = String(person.get("name", "Choose a guest"))
	for key: String in _guest_details: _guest_details[key].visible = not person.is_empty()
	for key: String in _need_bars: _need_bars[key].root.visible = not person.is_empty()
	if person.is_empty(): return
	_guest_details.status.text = _state(person)
	var warning := ""
	if person.get("want_leave", false) and person.get("state") != "departed": warning = "Leaving early · see the reason below."
	elif float(person.get("warning_elapsed", 0.0)) > 0.0 or float(person.get("unhappy_elapsed", 0.0)) >= 18.0:
		warning = "May leave early · %.0f seconds to help. A meal, rest or cleaner surroundings may help them recover." % maxf(0, 30.0 - float(person.get("warning_elapsed", 0.0)))
	_guest_details.warning.text = warning
	_guest_details.warning.visible = not warning.is_empty()
	var reasons: Array[String] = []
	for reason: String in [String(person.get("reason", "")), String(person.get("mood_reason", ""))]:
		if not reason.is_empty() and not reasons.has(reason): reasons.append(reason)
	_guest_details.reason.text = "\n".join(reasons)
	_guest_details.mood.text = "Mood %d%%" % roundi(float(person.get("mood", 0)))
	for key: String in _need_bars:
		var value := clampf(float(person.get("needs", {}).get(key, 0)), 0, 100)
		_need_bars[key].bar.value = value
		_need_bars[key].value.text = "%d%%" % roundi(value)
	var nights := int(person.get("nights", 0))
	var partner: Dictionary = _people.get(int(person.get("partner_id", 0)), {})
	var cabin := "Cabin %d" % int(person.cabin_id) if int(person.get("cabin_id", -1)) > 0 else "Awaiting a cabin"
	_guest_details.booking.text = "%s · %d-night stay\n%d / %d nights paid%s" % [cabin, nights, int(person.get("paid_nights", 0)), nights,
		"\nSharing with " + String(partner.get("name", "partner")) if int(person.get("partner_id", 0)) > 0 else ""]
	var budget := int(person.get("budget", 0))
	var reserve := int(person.get("reserve", 0))
	_guest_details.budget.text = "Party budget remaining  %s\nSet aside for unpaid nights  %s\nAvailable for activities  %s%s" % [_money(budget), _money(reserve), _money(maxi(0, budget - reserve)),
		"\nOne shared budget for this couple." if int(person.get("partner_id", 0)) > 0 else ""]
	_guest_details.interests.text = "Interests: " + _join_values(person.get("interests", []), ", ")
	var history: Array = person.get("history", [])
	var recent: Array[String] = []
	for event: Variant in history.slice(maxi(0, history.size() - 4)): recent.append("• " + str(event))
	_guest_details.history.text = "Recent stay events\n" + ("\n".join(recent) if not recent.is_empty() else "The stay has just begun.")

func _build_facilities(page: VBoxContainer) -> void:
	_facility_summary = _text(page, "")
	var scroll := _scroll(page, "FacilitiesScroll")
	_facility_list = _column(scroll)
	_facility_empty = _text(_facility_list, "Build a venue to give guests more things to do.", 16, SECONDARY)

func _refresh_facilities() -> void:
	var live_ids: Array = []
	var occupied := 0
	var capacity := 0
	var waiting := 0
	for facility: Dictionary in _view.get("facilities", []):
		var id := int(facility.get("id", facility.get("facility_id", 0)))
		live_ids.append(id)
		if not _facility_rows.has(id):
			var body := _column(_facility_list)
			body.add_child(HSeparator.new())
			var fields := {"root": body}
			for key in ["title", "occupancy", "users", "queue", "issue"]:
				fields[key] = _text(body, "", 18 if key == "title" else 15, WARNING if key == "issue" else INK)
			_facility_rows[id] = fields
		var fields: Dictionary = _facility_rows[id]
		var occupants: Array = facility.get("occupants", [])
		var queue: Array = facility.get("queue", [])
		var held := int(facility.get("occupancy", occupants.size()))
		var spaces := int(facility.get("capacity", 2))
		var queued := int(facility.get("queue_count", queue.size()))
		occupied += held
		capacity += spaces
		waiting += queued
		fields.title.text = "%s #%d · %s / person" % [_facility_name(facility), id, _money(int(facility.get("price", 0)))]
		fields.occupancy.text = "%d / %d places held · %d waiting (limit %d)" % [held, spaces, queued, int(facility.get("queue_limit", 4))]
		var uses: Array[String] = []
		for pair: Array in [["active", "Using"], ["reserved", "On the way / taking a place"], ["exiting", "Leaving"]]:
			var ids: Array = facility.get(pair[0], [])
			if not ids.is_empty(): uses.append(pair[1] + ": " + _guest_names(ids))
		if uses.is_empty() and not occupants.is_empty(): uses.append("Places held by: " + _guest_names(occupants))
		fields.users.text = "\n".join(uses) if not uses.is_empty() else "No guests using this facility."
		var names: Array[String] = []
		for index in queue.size(): names.append("%d. %s" % [index + 1, _guest_name_for(int(queue[index]))])
		fields.queue.text = "Queue: " + ", ".join(names) if not names.is_empty() else "No queue."
		var issue := ""
		if not facility.get("reachable", true): issue = "Path blocked. Reconnect the entrance so guests can visit."
		elif queued >= int(facility.get("queue_limit", 4)): issue = "The queue is full. New visitors will choose something else."
		elif not facility.get("available", true): issue = "No safe waiting space. Leave clear ground by the entrance."
		elif facility.get("kind") in ResortServices.PAIRED and (facility.get("active", []) as Array).is_empty() and not (facility.get("reserved", []) as Array).is_empty():
			issue = "Waiting for both players to reach opposite sides of the net. No fee is taken until play can begin."
		fields.issue.text = issue
		fields.issue.visible = not issue.is_empty()
	_prune(_facility_rows, live_ids)
	_facility_empty.visible = live_ids.is_empty()
	_facility_summary.text = "%d facilities · %d / %d places held · %d waiting" % [live_ids.size(), occupied, capacity, waiting]

func _build_staff(page: VBoxContainer) -> void:
	_clean_summary = _text(page, "")
	var scroll := _scroll(page, "StaffScroll")
	var body := _column(scroll)
	_wage_notice = _text(body, "", 15, SECONDARY)
	_hire = _button("Hire janitor · $30 / day", body, "No hiring fee. Wages are paid at each completed simulation day; up to three janitors.")
	_hire.name = "HireJanitor"
	_hire.pressed.connect(func() -> void: action_requested.emit("hire_janitor", 0))
	_staff_list = _column(body)
	_staff_empty = _text(_staff_list, "No janitors hired. Hire a janitor to walk to mess and clean it up.", 16, SECONDARY)
	body.add_child(HSeparator.new())
	_text(body, "Cleanup tasks", 18)
	_mess_summary = _text(body, "", 15, SECONDARY)

func _refresh_staff() -> void:
	var clean: Dictionary = _view.get("cleanliness", {})
	var mess: Array = clean.get("mess", [])
	var wage := int(clean.get("daily_wage", 30))
	var hired := int(clean.get("hired_count", (clean.get("staff", []) as Array).size()))
	var maximum := int(clean.get("max_staff", 3))
	_clean_summary.text = "Cleanliness %d%% · %d messes to clean" % [roundi(float(clean.get("cleanliness", 100))), int(clean.get("mess_count", mess.size()))]
	_wage_notice.text = "%d / %d janitors hired · %s per day for current staff\n%s per janitor per completed day. No hiring fee." % [hired, maximum, _money(hired * wage), _money(wage)]
	_hire.text = "Hire janitor · %s / day" % _money(wage) if hired < maximum else "All %d janitor positions filled" % maximum
	_hire.disabled = hired >= maximum or clean.is_empty()
	var live_ids: Array = []
	_staff.clear()
	for cleaner: Dictionary in clean.get("staff", []):
		var id := int(cleaner.get("id", 0))
		_staff[id] = cleaner
		live_ids.append(id)
		if not _staff_rows.has(id):
			var entry := _column(_staff_list)
			entry.add_child(HSeparator.new())
			var heading := HBoxContainer.new()
			entry.add_child(heading)
			var title := _label("", 18)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			heading.add_child(title)
			var dismiss := _button("Dismiss", heading, "Dismiss this janitor and release their cleanup task")
			dismiss.name = "DismissJanitor%d" % id
			dismiss.pressed.connect(func() -> void:
				if _staff.has(id): action_requested.emit("dismiss_janitor", id))
			var progress := ProgressBar.new()
			progress.custom_minimum_size.y = 16
			progress.show_percentage = false
			progress.max_value = 1.0
			entry.add_child(progress)
			_staff_rows[id] = {"root": entry, "title": title, "dismiss": dismiss,
				"status": _text(entry, "", 15), "progress": progress, "reason": _text(entry, "", 15, SECONDARY)}
		var fields: Dictionary = _staff_rows[id]
		fields.title.text = "%s · Janitor" % cleaner.get("name", "Janitor")
		var state: String = cleaner.get("state", "idle")
		fields.status.text = "%s · %s / day · %d tasks completed" % [{"walking": "Walking to a mess", "cleaning": "Cleaning", "returning": "Returning to standby", "idle": "Ready for work"}.get(state, "Ready for work"),
			_money(int(cleaner.get("daily_wage", wage))), int(cleaner.get("cleaned_count", 0))]
		fields.reason.text = String(cleaner.get("reason", ""))
		fields.progress.visible = state == "cleaning"
		fields.progress.value = float(cleaner.get("progress", 0))
	_prune(_staff_rows, live_ids)
	_staff_empty.visible = live_ids.is_empty()
	var tasks: Array[String] = []
	for dirt: Dictionary in mess:
		var cleaner: Dictionary = _staff.get(int(dirt.get("claimed_by", 0)), {})
		var assignment := "Waiting for a janitor" if cleaner.is_empty() else "%s %s" % [cleaner.get("name", "Janitor"), "is cleaning" if cleaner.get("state") == "cleaning" else "is on the way"]
		tasks.append("%s by facility #%d · %s" % [String(dirt.get("kind", "mess")).capitalize(), int(dirt.get("facility_id", 0)), assignment])
	_mess_summary.text = "\n".join(tasks) if not tasks.is_empty() else "The resort is clean. Janitors will look for the next mess."

func _build_operations(page: VBoxContainer) -> void:
	_operations_day = _text(page, "Resort finances", 18)
	_cash_summary = _text(page, "", 15, GOLD)
	var tabs := HFlowContainer.new()
	page.add_child(tabs)
	for name: String in ["Statement", "Receipts", "Prices"]:
		var button := _button(name, tabs)
		button.toggle_mode = true
		button.pressed.connect(_show_finance_view.bind(name))
		_finance_tabs[name] = button
	var scroll := _scroll(page, "OperationsScroll")
	_finance_views["Statement"] = scroll
	var body := _column(scroll)
	_text(body, "Profit and loss", 18)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for caption: String in ["", "Today", "All time"]:
		var label := _label(caption, 14, SECONDARY)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(label)
	var captions := {"room_income": "Rooms", "meal_income": "Meals", "sunbathe_income": "Sunbeds", "volleyball_income": "Volleyball", "facility_income": "Other facilities",
		"legacy_income": "Earlier activities", "reward_income": "Challenge rewards", "income": "Total income", "wages": "Janitor wages", "upkeep": "Daily upkeep",
		"construction": "Construction after refunds", "expenses": "Total expenses", "net": "Profit / loss"}
	for key: String in captions:
		var title := _label(captions[key], 15)
		if key == "legacy_income": title.tooltip_text = "Activity income brought forward from an older save. Its original activity categories and dates were not recorded."
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(title)
		var today := _label("", 15)
		today.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(today)
		var total := _label("", 15)
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(total)
		_operation_cells[key] = {"title": title, "today": today, "total": total}
	body.add_child(HSeparator.new())
	_text(body, "Daily history", 18)
	_text(body, "Days with recorded transactions, plus today.", 14, SECONDARY)
	_daily_list = _column(body)
	_build_receipts(page)
	_build_prices(page)
	_show_finance_view("Statement")

func _show_finance_view(selected: String) -> void:
	for name: String in _finance_views:
		_finance_views[name].visible = name == selected
		_finance_tabs[name].set_pressed_no_signal(name == selected)

func _build_receipts(page: VBoxContainer) -> void:
	var section := _column(page)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_finance_views["Receipts"] = section
	var navigation := HBoxContainer.new()
	section.add_child(navigation)
	_receipt_back = _button("Newer", navigation)
	_receipt_back.pressed.connect(func() -> void: action_requested.emit("receipt_page", _receipt_page - 1))
	_receipt_position = _text(navigation, "", 14, SECONDARY)
	_receipt_position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_receipt_next = _button("Older", navigation)
	_receipt_next.pressed.connect(func() -> void: action_requested.emit("receipt_page", _receipt_page + 1))
	_receipt_list = _column(_scroll(section, "ReceiptScroll"))

func _build_prices(page: VBoxContainer) -> void:
	var scroll := _scroll(page, "PriceScroll")
	_finance_views["Prices"] = scroll
	var body := _column(scroll)
	_text(body, "Guest prices", 18)
	_text(body, "Prices apply to all locations of each type. Booked room rates stay fixed. Activity prices apply when guests are admitted.", 15, SECONDARY)
	for service: String in ResortEconomy.DEFAULT_PRICES:
		var row := HBoxContainer.new()
		body.add_child(row)
		_text(row, ResortServices.label(service) + (" / night" if service == "room" else " / guest"), 15)
		var input := SpinBox.new()
		input.name = "Price" + service.capitalize()
		input.min_value = 1
		input.max_value = ResortEconomy.MAX_PRICE
		input.step = 1
		input.prefix = "$"
		row.add_child(input)
		var apply := _button("Apply", row)
		apply.name = "Apply" + service.capitalize()
		apply.pressed.connect(func() -> void:
			price_requested.emit(service, int(input.value))
			_price_status.text = "Price saved at %s." % _money(int(input.value))
		)
		_prices[service] = {"input": input, "published": 0}
	_price_status = _text(body, "", 14, MINT)

func _refresh_receipts(operations: Dictionary) -> void:
	_receipt_page = int(operations.get("receipt_page", 0))
	var pages := int(operations.get("receipt_pages", 1))
	_receipt_position.text = "Page %d of %d" % [_receipt_page + 1, pages]
	_receipt_back.disabled = _receipt_page == 0
	_receipt_next.disabled = _receipt_page >= pages - 1
	var receipts: Array = operations.get("receipts", [])
	if receipts == _receipt_rows and _receipt_list.get_child_count() > 0: return
	_receipt_rows = receipts
	for child in _receipt_list.get_children():
		_receipt_list.remove_child(child)
		child.queue_free()
	if receipts.is_empty():
		_text(_receipt_list, "Purchases, guest payments, upkeep and wages will appear here.", 15, SECONDARY)
	for event: Dictionary in receipts:
		var title: String = {"room": "Cabin night", "meal": "Café meal", "sunbathe": "Sunbed", "volleyball": "Volleyball",
			"legacy_income": "Earlier activities", "wage": "Janitor wage", "construction": "Purchase", "refund": "Purchase refund", "upkeep": "Daily upkeep"}.get(event.kind, ResortServices.label(event.kind))
		if event.kind == "reward":
			var challenge := ResortChallenges.challenge_for_receipt(event.id)
			title = "Challenge reward · " + ResortChallenges.GOALS[challenge].name
		if event.has("item"):
			title += " · %s × %d" % [ResortEconomy.item_name(event.item), event.quantity]
		var row := HBoxContainer.new()
		_receipt_list.add_child(row)
		var detail := _column(row)
		_text(detail, title, 15)
		var day := 1 + floori(float(event.time) / OperatingLedger.DAY_SECONDS)
		var identity := "Day %d · %s" % [day, event.id]
		_text(detail, identity, 12, SECONDARY)
		var amount := int(event.amount)
		row.add_child(_label(_money(amount) if amount < 0 else "+" + _money(amount), 15, WARNING if amount < 0 else MINT))

func _refresh_operations() -> void:
	var operations: Dictionary = _view.get("operations", {})
	var day := int(operations.get("day", 1))
	_operations_day.text = "Resort finances · Day %d" % day
	_cash_summary.text = "Cash %s  ·  Opening cash %s" % [_money(int(operations.get("cash", ResortEconomy.OPENING_CASH))), _money(int(operations.get("opening_cash", ResortEconomy.OPENING_CASH)))]
	var prices: Dictionary = _view.get("prices", ResortEconomy.DEFAULT_PRICES)
	for service: String in _prices:
		var published := int(prices[service])
		if _prices[service].published != published:
			_prices[service].input.set_value_no_signal(published)
			_prices[service].published = published
	_refresh_receipts(operations)
	var today: Dictionary = {}
	var live_ids: Array = []
	var days: Array = operations.get("days", [])
	for entry: Dictionary in days:
		if int(entry.get("day", 0)) == day: today = entry
	for key: String in _operation_cells:
		var total_key: String = key + "_total" if key in ["income", "wages", "upkeep", "construction", "expenses", "net"] else key
		var today_key := "today_" + key
		var current := int(operations.get(today_key, today.get(key, 0)))
		var total := int(operations.get(total_key, 0))
		var expense := key in ["wages", "upkeep", "construction", "expenses"]
		_operation_cells[key].today.text = _money(-current if expense else current)
		_operation_cells[key].total.text = _money(-total if expense else total)
		if key == "net":
			_operation_cells[key].today.add_theme_color_override("font_color", WARNING if current < 0 else MINT)
			_operation_cells[key].total.add_theme_color_override("font_color", WARNING if total < 0 else MINT)
		if key == "legacy_income":
			for label: Label in _operation_cells[key].values(): label.visible = total != 0
	for index in range(days.size() - 1, -1, -1):
		var entry: Dictionary = days[index]
		var number := int(entry.get("day", 1))
		live_ids.append(number)
		if not _day_rows.has(number):
			var label := _text(_daily_list, "", 15)
			_day_rows[number] = {"root": label}
		var label: Label = _day_rows[number].root
		label.text = "Day %d%s\nIncome %s · Expenses %s · Net %s" % [number, " · today" if number == day else "", _money(int(entry.get("income", 0))), _money(int(entry.get("expenses", 0))), _money(int(entry.get("net", 0)))]
		if label.get_index() != live_ids.size() - 1: _daily_list.move_child(label, live_ids.size() - 1)
	_prune(_day_rows, live_ids)

func _build_challenges(page: VBoxContainer) -> void:
	_text(page, "Resort challenges", 18)
	_text(page, "Track goals as you play and claim rewards here.", 15, SECONDARY)
	var body := _column(_scroll(page, "ChallengesScroll"))
	body.add_theme_constant_override("separation", 4)
	for id: String in ResortChallenges.GOALS:
		var goal: Dictionary = ResortChallenges.GOALS[id]
		if body.get_child_count() > 0: body.add_child(HSeparator.new())
		var heading := HBoxContainer.new()
		body.add_child(heading)
		var words := _column(heading)
		words.add_theme_constant_override("separation", 2)
		_text(words, goal.name, 17)
		_text(words, goal.description, 15, SECONDARY)
		var reward := _money(goal.cash) + " cash" if goal.cash > 0 else "Bronze dolphin statue"
		_text(words, reward, 14, GOLD)
		if id == ResortChallenges.STATUE_CHALLENGE:
			var icon := TextureRect.new()
			icon.texture = load("res://assets/structures/dolphin_statue-v1.png") as Texture2D
			icon.custom_minimum_size = Vector2(70, 66)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			heading.add_child(icon)
		var bar := ProgressBar.new()
		bar.max_value = goal.target
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		body.add_child(bar)
		var footer := HBoxContainer.new()
		body.add_child(footer)
		var status := _text(footer, "0 / %d" % goal.target, 14, SECONDARY)
		var button := _button("Claim reward", footer)
		button.custom_minimum_size.y = 30
		button.name = "Challenge" + id.to_pascal_case()
		button.hide()
		button.pressed.connect(func() -> void: challenge_requested.emit(_challenge_rows[id].action, id))
		_challenge_rows[id] = {"bar": bar, "status": status, "button": button, "action": ""}

func _refresh_challenges() -> void:
	for goal: Dictionary in _view.get("challenges", []):
		var row: Dictionary = _challenge_rows[goal.id]
		row.bar.value = goal.progress
		var text := "%d / %d" % [goal.progress, goal.target]
		var button := ""
		var action := ""
		match goal.state:
			"ready", "expired":
				text = "Ready to start · 3 minutes" if goal.state == "ready" else "Time ran out · " + text
				button = "Start challenge" if goal.state == "ready" else "Try again"
				action = "start"
			"timed":
				var seconds := ceili(float(goal.remaining))
				text += " · %d:%02d left" % [floori(seconds / 60.0), seconds % 60]
			"complete":
				text += " · Ready to claim"
				button = "Claim reward"
				action = "claim"
			"claimed":
				text = "Reward claimed"
				if not goal.decoration.is_empty():
					button = "Place statue"
					action = "place"
		row.status.text = text
		row.button.text = button
		row.button.visible = not action.is_empty()
		row.action = action

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	for type: String in ["Label", "Button"]: theme.set_color("font_color", type, INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INSET)
	theme.set_color("font_hover_pressed_color", "Button", INSET)
	theme.set_color("font_disabled_color", "Button", SECONDARY)
	theme.set_stylebox("normal", "Button", _box(Color("23483d")))
	theme.set_stylebox("hover", "Button", _box(Color("345f4b"), Color("84987b")))
	theme.set_stylebox("pressed", "Button", _box(GOLD, GOLD))
	theme.set_stylebox("hover_pressed", "Button", _box(GOLD.lightened(0.07), GOLD))
	theme.set_stylebox("disabled", "Button", _box(INSET, Color("496356")))
	theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, MINT, 2))
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("6c8067"), 1, 12))
	theme.set_stylebox("background", "ProgressBar", _box(INSET, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _box(MINT, Color.TRANSPARENT, 0, 0))
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	return theme

static func _box(fill: Color, border := Color.TRANSPARENT, width := 0, margin := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(4)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box

static func _label(value: String, font_size := 16, color := INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func _text(parent: Node, value: String, font_size := 16, color := INK) -> Label:
	var label := _label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

static func _column(parent: Node) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	return column

static func _scroll(parent: Node, node_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	return scroll

static func _button(value: String, parent: Node, tip := "") -> Button:
	var button := Button.new()
	button.text = value
	button.tooltip_text = tip
	button.custom_minimum_size.y = 36
	button.add_theme_font_size_override("font_size", 15)
	parent.add_child(button)
	return button

static func _prune(rows: Dictionary, live_ids: Array) -> void:
	for id: int in rows.keys():
		if live_ids.has(id): continue
		var node: Node = rows[id].root
		node.get_parent().remove_child(node)
		node.queue_free()
		rows.erase(id)

static func _state(person: Dictionary) -> String:
	return STATE_NAMES.get(person.get("state", ""), "Enjoying the resort")

static func _facility_name(facility: Dictionary) -> String:
	return facility.get("name", {"cafe": "Café", "sunbeds": "Sunbeds", "volleyball": "Volleyball court"}.get(facility.get("kind", ""), "Facility"))

func _guest_name_for(id: int) -> String:
	return String(_people.get(id, {}).get("name", "Guest %d" % id))

func _guest_names(ids: Array) -> String:
	var names: Array[String] = []
	for id: int in ids: names.append(_guest_name_for(id))
	return ", ".join(names)

static func _join_values(values: Array, separator: String) -> String:
	var words: Array[String] = []
	for value: Variant in values: words.append(str(value))
	return separator.join(words)

static func _money(amount: int) -> String:
	return "−$%d" % -amount if amount < 0 else "$%d" % amount
