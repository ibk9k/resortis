class_name ResortHUD
extends CanvasLayer

signal build_requested(kind: String)
signal category_requested(category: String)
signal action_requested(action: String)
signal save_slot_requested(slot: int, writing: bool)

const INK := Color("fff1cf")
const SECONDARY := Color("b9cbb4")
const GOLD := Color("edbd68")
const PANEL := Color("16352f")
const INSET := Color("102822")

var root: Control
var assets: ResortAssets
var tray: HBoxContainer
var detail_title: Label
var detail_text: Label
var detail_image: TextureRect
var detail_actions: HFlowContainer
var inspector: PanelContainer
var status: Label
var motion_label: Label
var cash_label: Label
var _statue_unlocked := false
var tools: Dictionary = {}
var build_buttons: Dictionary = {}
var category := "Resort"
var save_window: Window
var save_content: PanelContainer
var save_entries: Array[Dictionary]
var autosave_active := true
var saving_to_exit := false
var save_return_focus: Button

func build(library: ResortAssets) -> void:
	assets = library
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme()
	add_child(root)
	_build_top_bar()
	_build_inspector()
	_build_tray()
	show_category(category)
	show_overview()

func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INSET)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_stylebox("normal", "Button", _box(Color("23483d")))
	theme.set_stylebox("hover", "Button", _box(Color("345f4b"), Color("84987b")))
	theme.set_stylebox("pressed", "Button", _box(GOLD, GOLD))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color("b6e4c5"), 2))
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("6c8067")))
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 10)
	return theme

func _box(fill: Color, border := Color(0, 0, 0, 0), width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _panel(name_text: String, left: float, top: float, right: float, bottom: float, anchors := Vector4(0, 0, 1, 0)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = name_text
	root.add_child(panel)
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	return panel

func _label(text: String, size := 17, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: String, parent: Node, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size.y = 36
	button.pressed.connect(func() -> void: action_requested.emit(action))
	parent.add_child(button)
	tools[action] = button
	return button

func _build_top_bar() -> void:
	var bar := _panel("TopBar", 18, 16, -18, 76)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	var brand := _label("Resortis", 29, GOLD)
	brand.custom_minimum_size.x = 158
	row.add_child(brand)
	row.add_child(_label("Coastal resort", 17))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	motion_label = _label("14 guests exploring", 16, SECONDARY)
	row.add_child(motion_label)
	cash_label = _label("", 16, GOLD)
	cash_label.hide()
	row.add_child(cash_label)
	_button("Pause", "pause", row, "Pause the scene · Space")
	for speed in [1, 2, 4]:
		var button := _button("%d×" % speed, "speed_%d" % speed, row)
		button.toggle_mode = true
		button.button_pressed = speed == 1
	_button("Guests", "guest", row, "Inspect the current solo guest or couple")
	_button("Saves", "save", row, "Save or load your resort · Ctrl+S")
	_button("Map guide", "guide", row)
	_button("Main menu", "main_menu", row, "Return to the Resortis main menu")

func _ensure_save_window() -> void:
	if save_window == null:
		save_window = Window.new()
		save_window.name = "ResortSaves"
		save_window.title = "Resortis"
		save_window.visible = false
		save_window.transient = true
		save_window.exclusive = true
		save_window.unresizable = true
		root.add_child(save_window)
		save_window.close_requested.connect(close_save_menu)
		save_content = PanelContainer.new()
		save_content.theme = root.theme
		save_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		save_window.add_child(save_content)

func show_exit_menu(entries: Array[Dictionary], unsaved: bool) -> void:
	_ensure_save_window()
	saving_to_exit = false
	save_return_focus = tools.main_menu
	var column := _save_menu_column()
	column.add_child(_label("Return to the main menu?", 23))
	var message := "You can save your resort before leaving."
	if unsaved:
		message = "You have unsaved progress. Save it before leaving or exit without saving."
	column.add_child(_label(message, 16, SECONDARY))
	var row := HBoxContainer.new()
	column.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := _save_button(row, "Keep playing", close_save_menu)
	_bind_save_escape(cancel)
	_save_button(row, "Exit without saving", func() -> void: action_requested.emit("exit_to_menu"))
	_save_button(row, "Save and exit", func() -> void: show_save_menu(entries, "", true, true))
	_popup_save_menu(cancel)

func show_save_menu(entries: Array[Dictionary], message := "", valid := true, exit_after_save := false) -> void:
	_ensure_save_window()
	save_entries = entries
	saving_to_exit = exit_after_save
	save_return_focus = tools.main_menu if saving_to_exit else tools.save
	var column := _save_menu_column()
	column.add_child(_label("Save and exit" if saving_to_exit else "Resort saves", 23))
	var help := "Autosave runs every minute during play. Manual slots are separate."
	if not autosave_active:
		help = "Autosave is off for this session. You can still save manually."
	if saving_to_exit:
		help = "Choose a manual slot to save your resort before returning to the main menu."
	column.add_child(_label(help, 15, SECONDARY))
	if not message.is_empty():
		column.add_child(_label(message, 15, SECONDARY if valid else Color("f9b5a5")))
	for entry in entries:
		if saving_to_exit and entry.slot <= 0:
			continue
		var row := HBoxContainer.new()
		column.add_child(row)
		var title := _label(entry.label)
		title.custom_minimum_size.x = 145
		row.add_child(title)
		var detail := "Empty"
		if entry.exists:
			detail = Time.get_datetime_string_from_unix_time(entry.modified, true).left(16) + " UTC"
			if entry.backup_only: detail += " · Backup"
		var info := _label(detail, 15, SECONDARY)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if entry.slot > 0:
			var save_button := _save_button(row, "Save", func() -> void: _choose_save_slot(entry, true))
			save_button.name = "SaveSlot%d" % entry.slot
		if not saving_to_exit:
			var load_button := _save_button(row, "Load", func() -> void: _choose_save_slot(entry, false))
			load_button.name = "LoadSlot%d" % entry.slot
			load_button.disabled = not entry.exists
	var close := _save_button(column, "Keep playing" if saving_to_exit else "Close", close_save_menu)
	close.name = "CloseSaves"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	_bind_save_escape(close)
	_popup_save_menu(close)

func _popup_save_menu(focus: Button) -> void:
	var height := ceili(save_content.get_combined_minimum_size().y) + 8
	save_window.popup_centered(Vector2i(635, height))
	focus.grab_focus()

func _save_menu_column() -> VBoxContainer:
	for child in save_content.get_children():
		save_content.remove_child(child)
		child.queue_free()
	var column := VBoxContainer.new()
	save_content.add_child(column)
	return column

func _save_button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(76, 34)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _bind_save_escape(button: Button) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	var shortcut := Shortcut.new()
	shortcut.events = [key]
	button.shortcut = shortcut

func _choose_save_slot(entry: Dictionary, writing: bool) -> void:
	if writing and not entry.exists:
		save_slot_requested.emit(entry.slot, true)
		return
	var column := _save_menu_column()
	column.add_child(_label(("Overwrite %s?" if writing else "Load %s?") % entry.label, 23))
	var message := "The previous valid copy is kept as a backup."
	if not writing:
		message = "Progress since your last save may be lost."
	column.add_child(_label(message, 16, SECONDARY))
	var row := HBoxContainer.new()
	column.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_END
	var back := _save_button(row, "Back", func() -> void: show_save_menu(save_entries, "", true, saving_to_exit))
	_bind_save_escape(back)
	_save_button(row, "Overwrite" if writing else "Load resort",
		func() -> void: save_slot_requested.emit(entry.slot, writing))
	save_window.popup_centered(Vector2i(635, 166))
	back.grab_focus()

func save_menu_open() -> bool:
	return is_instance_valid(save_window) and save_window.visible

func close_save_menu() -> void:
	save_window.hide()
	saving_to_exit = false
	save_return_focus.grab_focus()

func _build_inspector() -> void:
	inspector = _panel("Inspector", -294, 94, -18, 430, Vector4(1, 0, 1, 0))
	var column := VBoxContainer.new()
	inspector.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	detail_title = _label("Your coastal resort", 20)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(detail_title)
	_button("×", "guide", heading, "Close the inspector")
	detail_image = TextureRect.new()
	detail_image.custom_minimum_size = Vector2(100, 98)
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(detail_image)
	detail_text = _label("", 16, SECONDARY)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_text.custom_minimum_size.x = 244
	detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "InspectorDetails"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 100
	column.add_child(scroll)
	scroll.add_child(detail_text)
	detail_actions = HFlowContainer.new()
	column.add_child(detail_actions)

func enable_management_menu() -> void:
	if tools.has("management"): return
	var old: Button=tools.guest
	var row := old.get_parent()
	var index := old.get_index()
	old.hide()
	var menu := MenuButton.new()
	menu.name="ManagementMenu"
	menu.text="Manage ▾"
	menu.tooltip_text="Guests, facilities, staff, operating results and challenges"
	menu.custom_minimum_size.y=36
	row.add_child(menu)
	row.move_child(menu,index)
	var actions := ["guest","facilities","staff","operations","challenges"]
	for label: String in ["Guests","Facilities","Staff","Operating results","Challenges"]: menu.get_popup().add_item(label)
	menu.get_popup().id_pressed.connect(func(id: int) -> void: action_requested.emit(actions[id]))
	tools["management"]=menu

func _build_tray() -> void:
	var panel := _panel("BuildTray", 18, -164, -18, -18, Vector4(0, 1, 1, 1))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var navigation := HBoxContainer.new()
	column.add_child(navigation)
	_button("Select", "cancel", navigation, "Inspect a building · Esc")
	for group in ["Resort", "Stay", "Leisure", "Beach", "Garden", "Paths"]:
		var button := Button.new()
		button.text = group
		button.toggle_mode = true
		button.button_pressed = group == category
		button.pressed.connect(func() -> void: show_category(group); category_requested.emit(group))
		navigation.add_child(button)
		tools["category_" + group] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	var grid_button := _button("Grid", "grid", navigation, "Show placement grid · G")
	grid_button.toggle_mode = true
	_button("Home", "home", navigation, "Frame the full resort · Home")
	_button("Inland", "inland_view", navigation, "View the inland facilities and buildable expansion")
	_button("Arrivals", "arrivals_view", navigation, "View reception, guest parking and the shuttle stop")
	_button("Undo", "undo", navigation, "Undo the last edit · Ctrl+Z").disabled = true
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	tray = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 8)
	scroll.add_child(tray)
	status = _label("Drag with the middle or right mouse button to pan · Wheel to zoom · Space to pause", 14, SECONDARY)
	column.add_child(status)

func set_statue_unlocked(unlocked: bool) -> void:
	if unlocked == _statue_unlocked: return
	_statue_unlocked = unlocked
	if category == "Garden": show_category(category)

func show_category(group: String) -> void:
	category = group
	for key in tools:
		if key.begins_with("category_"):
			tools[key].button_pressed = key == "category_" + group
	for child in tray.get_children():
		child.free()
	build_buttons.clear()
	if group == "Paths":
		_button("Lay stone path · $%d" % ResortEconomy.purchase("path"), "path", tray, "Click or drag to paint paths")
		_button("Remove path", "erase_path", tray)
		var label := _label("Paths connect cabins and services to the beach promenade.", 16, SECONDARY)
		tray.add_child(label)
		return
	for kind: String in ResortCatalog.DEFINITIONS:
		var def := ResortCatalog.definition(kind)
		if def.category != group:
			continue
		if kind == ResortChallenges.STATUE and not _statue_unlocked:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(178, 68)
		button.tooltip_text = "%s\nPurchase $%d · Upkeep $%d/day" % [def.description, ResortEconomy.purchase(kind), ResortEconomy.upkeep(kind)]
		if kind == ResortChallenges.STATUE:
			button.tooltip_text = def.description + "\nFree to place"
		button.toggle_mode = true
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		var icon := TextureRect.new()
		icon.texture = assets.display_texture_for(kind)
		icon.custom_minimum_size = Vector2(54, 60)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var price := "Reward · free" if kind == ResortChallenges.STATUE else "$%d" % ResortEconomy.purchase(kind)
		var tray_name: String = "Dolphin statue" if kind == ResortChallenges.STATUE else def.name
		var label := _label("%s\n%s" % [tray_name, price], 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 100
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		button.pressed.connect(func() -> void: build_requested.emit(kind))
		tray.add_child(button)
		if kind == ResortChallenges.STATUE:
			tray.move_child(button, 0)
		build_buttons[kind] = button

func highlight_build(kind: String) -> void:
	for id in build_buttons:
		build_buttons[id].button_pressed = id == kind

func show_overview() -> void:
	_reset_inspector()
	inspector.show()
	detail_title.text = "Your coastal resort"
	detail_image.texture = assets.texture_for("palm")
	detail_text.text = "Four furnished cabins, a garden pool and a welcoming café.\n\nA wide beach leaves room for lounging, volleyball and a fishing pier.\n\nChoose an item below to build, or click an object to inspect and move it."
	_clear_actions()
	_button("Beach view", "beach_view", detail_actions)
	_button("Light", "lighting", detail_actions, "Cycle daylight, sunset, and night")
	_button("Calm", "calm", detail_actions, "Toggle gentle water animation")

func show_object(kind: String, orientation: int = 0, selected := false, moving := false) -> void:
	_reset_inspector()
	var def := ResortCatalog.definition(kind)
	inspector.show()
	detail_title.text = def.name
	detail_image.texture = assets.display_texture_for(kind, orientation)
	var size := ResortCatalog.footprint(kind, orientation)
	detail_text.text = "%s\n\n%d × %d tiles · %s" % [def.description, size.x, size.y, "Half-tile snap" if ResortCatalog.is_decoration(kind) else "Grid snap"]
	if selected or moving:
		detail_text.text += "\nUpkeep $%d/day · Move free" % ResortEconomy.upkeep(kind)
	else:
		detail_text.text += "\nPurchase $%d · Upkeep $%d/day" % [ResortEconomy.purchase(kind), ResortEconomy.upkeep(kind)]
	_clear_actions()
	if selected:
		_button("Move", "move", detail_actions)
		_button("Remove", "remove", detail_actions)
	else:
		_button("Cancel", "cancel", detail_actions)
	if def.frames.size() > 1:
		_button("Rotate · R", "rotate", detail_actions)

func _clear_actions() -> void:
	for child in detail_actions.get_children():
		detail_actions.remove_child(child)
		child.queue_free()

func set_cash(amount: int) -> void:
	cash_label.text = "Cash $%d" % amount if amount >= 0 else "Cash −$%d" % absi(amount)
	cash_label.show()

func set_living_status(clock: float, guests: int, paused: bool) -> void:
	var day := floori(clock / ResortSimulation.DAY_SECONDS) + 1
	var minutes := floori(fposmod(clock, ResortSimulation.DAY_SECONDS) * 1440.0 / ResortSimulation.DAY_SECONDS)
	motion_label.text = "Day %d · %02d:%02d · %d guests%s" % [day, minutes / 60, minutes % 60, guests, " · Paused" if paused else ""]
	motion_label.tooltip_text = "Resort time · one day is 180 seconds at 1× speed"

func set_status(message: String, valid := true) -> void:
	status.text = message
	status.add_theme_color_override("font_color", SECONDARY if valid else Color("f9b5a5"))

func set_speed(speed: float, paused: bool) -> void:
	tools.pause.text = "Resume" if paused else "Pause"
	for n in [1, 2, 4]:
		tools["speed_%d" % n].button_pressed = is_equal_approx(speed, float(n))
	motion_label.text = "Scene paused" if paused else "14 guests exploring"

func _reset_inspector() -> void:
	(detail_text.get_parent() as ScrollContainer).scroll_vertical = 0
	inspector.anchor_bottom = 0
	inspector.offset_bottom = 430
	detail_image.show()

func show_guest(stay: GuestStay) -> void:
	(detail_text.get_parent() as ScrollContainer).scroll_vertical = 0
	inspector.show()
	inspector.anchor_bottom = 1
	inspector.offset_bottom = -186
	detail_title.text = "Maya & Leo" if stay.party_size==2 else "Maya's beach break"
	detail_image.hide()
	_clear_actions()
	_button("Follow / stop", "follow_guest", detail_actions, "Keep the camera on Maya; drag to stop following")
	_button("Welcome next guest", "new_stay", detail_actions).disabled = stay.state != "departed"
	update_guest(stay)

func update_guest(stay: GuestStay) -> void:
	var activity: String = {"arriving": "Arriving", "waiting": "Waiting for a cabin", "to_cabin": "Walking to the cabin", "entering": "Entering the cabin", "resting": "Settling in", "exiting": "Leaving the cabin", "to_cafe": "Going to lunch", "sitting": "Seated at the café", "eating": "Eating at the café", "playing_volleyball": "Playing volleyball", "to_beach": "Heading to the beach", "relaxing": "Sunbathing visit", "returning": "Returning to the cabin", "overnight": "Resting overnight", "departing": "Checking out", "departed": "Stay completed"}.get(stay.state, "Exploring")
	var cabin := "Cabin %d · $%d / night" % [stay.cabin_id, stay.booking_rate] if stay.cabin_id > 0 else "Two-night stay · $60 / night"
	activity = {"approaching_seats":"Taking seats","leaving_seats":"Leaving the café","approaching_loungers":"Choosing loungers","leaving_loungers":"Leaving the sunbeds","to_court":"Going to volleyball","approaching_court":"Taking court positions","playing_volleyball":"Playing volleyball","leaving_court":"Leaving the court"}.get(stay.state,activity)
	if stay.party_size==2: cabin += "\nCouple · one shared booking"
	var recent := ""
	for event in stay.history.slice(maxi(0, stay.history.size() - 3)):
		recent += "• " + event + "\n"
	detail_text.text = "%s\n%s\n\n%s\n\nInterests: sunshine, good food\n\nRest %d%% · Hunger satisfied %d%%\nEnjoyment %d%%\n\nBudget remaining  $%d\nSet aside for room  $%d\nRoom paid  $%d · %d / %d nights\nActivities paid  $%d\n\nRecent stay events\n%s" % [activity, cabin, stay.explanation, stay.rest, stay.hunger, stay.enjoyment, stay.budget, stay.reserve(), stay.accommodation_spent, stay.paid_nights, stay.nights, stay.activity_spent, recent]
	if tools.has("new_stay"): tools.new_stay.disabled = stay.state != "departed"
	if tools.has("new_stay"): tools.new_stay.text = "Welcome solo guest" if stay.party_size==2 else "Welcome next couple"

func update_stay_status(stay: GuestStay, paused: bool) -> void:
	motion_label.text = "%s · $%d from stay" % ["Paused" if paused else "Day %d" % (1 + int(stay.clock / GuestStay.DAY_SECONDS)), stay.revenue]
