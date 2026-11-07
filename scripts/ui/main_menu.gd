extends Control

const World := preload("res://scenes/world/coastal_resort.tscn")
const SaveSlots := preload("res://scripts/world/resort_save_slots.gd")
const SIGNATURE := preload("res://assets/menu/resortis-signature.png")
const MONOGRAM := preload("res://assets/menu/resortis-monogram.svg")
const POSTER := preload("res://assets/menu/resort-poster.jpg")
const FILM := "res://assets/menu/resort-tour.ogv"
const INK := Color("fff1cf")
const MUTED := Color("cbdcc8")
const FOREST := Color("16352f")
const DEEP := Color("102822")
const GOLD := Color("edbd68")

var save_path := SaveSlots.launch_path()
var bypass_on_launch := true
var slots: SaveSlots
var screen := ""
var selection := {}
var panel: PanelContainer
var column: VBoxContainer
var video: VideoStreamPlayer
var brand: TextureRect
var header: HBoxContainer
var motion := true
var changing_scene := false

func _ready() -> void:
	if bypass_on_launch:
		for argument in OS.get_cmdline_user_args():
			if argument in ["--fresh", "--bake", "--beach", "--hide-ui", "--stay-view"] or argument.begins_with("--capture="):
				get_tree().change_scene_to_packed.call_deferred(World)
				return
	DisplayServer.window_set_title("Resortis")
	texture_filter = TEXTURE_FILTER_LINEAR
	slots = SaveSlots.new(save_path)
	var config := ConfigFile.new()
	if config.load(_preferences_path()) == OK:
		motion = bool(config.get_value("menu", "background_motion", true))
	theme = _menu_theme()
	_build_backdrop()
	_build_frame()
	_show("home")
	resized.connect(_layout)
	_layout()

func _preferences_path() -> String:
	return save_path.get_base_dir().path_join("menu-settings.cfg")

func _build_backdrop() -> void:
	var poster := _image(POSTER)
	poster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(poster)
	video = VideoStreamPlayer.new()
	video.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	video.mouse_filter = MOUSE_FILTER_IGNORE
	video.expand = true
	video.loop = true
	if ResourceLoader.exists(FILM):
		video.stream = load(FILM) as VideoStream
	add_child(video)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	float left = 0.88 * pow(1.0 - smoothstep(0.0, 0.74, UV.x), 1.50);
	float foot = 0.81 * smoothstep(0.74, 1.0, UV.y);
	float head = 0.19 * (1.0 - smoothstep(0.0, 0.20, UV.y));
	COLOR = vec4(vec3(0.031, 0.105, 0.083), 1.0 - (1.0-left)*(1.0-foot)*(1.0-head));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	add_child(shade)

func _build_frame() -> void:
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var emblem := _image(MONOGRAM, Vector2(59, 59))
	header.add_child(emblem)
	header.add_child(_label("M A I N   M E N U", 14))
	add_child(header)
	brand = _image(SIGNATURE)
	add_child(brand)
	_update_motion()

func _layout() -> void:
	var gutter := size.x * 0.05
	header.position = Vector2(gutter, 34)
	var brand_x := size.x * 0.395
	brand.position = Vector2(brand_x, size.y * 0.12)
	brand.size = Vector2(size.x * 0.565, size.y * 0.35)
	if is_instance_valid(panel):
		panel.size = Vector2(322 if screen == "home" else 442, 0)
		panel.position = Vector2(gutter, maxf(112, size.y * 0.55 - panel.size.y * 0.5))

func _show(next: String, message := "") -> void:
	screen = next
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if screen == "home" else _box(DEEP, Color("687c61"), 1, 8, 24))
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	add_child(panel)
	var focus: Control
	match screen:
		"home":
			focus = _row("Play", func() -> void: _show("play"), true, "play")
			_row("Settings", func() -> void: _show("settings"), false, "settings")
			_row("About us", func() -> void: _show("about"), false, "info")
		"play":
			_heading("Play")
			focus = _row("New game", func() -> void: _show("new"), true, "plus")
			column.add_child(_label("Continue a world", 19))
			var list := ScrollContainer.new()
			list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			list.follow_focus = true
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = SIZE_EXPAND_FILL
			rows.add_theme_constant_override("separation", 6)
			list.add_child(rows)
			var count := 0
			for entry: Dictionary in slots.startup_slots():
				if not entry.exists:
					continue
				count += 1
				var detail := Time.get_datetime_string_from_unix_time(entry.modified).replace("T", " ").left(16) + " UTC"
				if entry.backup_only:
					detail += " · Backup"
				var button := _button("%s\n%s" % [entry.label, detail], _select_save.bind(entry))
				button.custom_minimum_size.y = 74
				button.add_theme_font_size_override("font_size", 17)
				for state in ["normal", "hover", "pressed"]:
					var style := get_theme_stylebox(state, "Button").duplicate() as StyleBox
					style.set_content_margin(SIDE_TOP, 8)
					style.set_content_margin(SIDE_BOTTOM, 8)
					button.add_theme_stylebox_override(state, style)
				rows.add_child(button)
			if count == 0:
				list.free()
				column.add_child(_paragraph("Your saved resorts will appear here."))
			else:
				list.custom_minimum_size.y = mini(count, 6) * 80 - 6
				column.add_child(list)
		"new":
			_heading("New game", "play")
			column.add_child(_paragraph("Start a fresh coastal resort with furnished cabins and room to expand. The next autosave will belong to this resort."))
			focus = _row("Start new game", _launch.bind(true), true, "play")
		"continue":
			_heading(selection.label, "play")
			var description := "Resume this resort from its local save."
			if selection.backup_only:
				description = "Resume this resort from its previous copy."
			column.add_child(_paragraph(description))
			focus = _row("Continue world", _launch.bind(false), true, "play")
		"settings":
			_heading("Settings")
			var toggle := CheckButton.new()
			toggle.text = "Background motion"
			toggle.button_pressed = motion
			toggle.disabled = video.stream == null
			toggle.custom_minimum_size.y = 50
			toggle.toggled.connect(_set_motion)
			column.add_child(toggle)
			column.add_child(_paragraph("Play the resort tour behind the menu."))
			focus = toggle if not toggle.disabled else column.get_child(0)
		"about":
			_heading("About us")
			column.add_child(_paragraph("Resortis is an isometric management game about building a beach resort and watching guests make it their own."))
			column.add_child(_paragraph("Furnish cabins, lay out the promenade, and keep the café and beach busy as your resort grows."))
			focus = column.get_child(0)
	if not message.is_empty():
		column.add_child(_paragraph(message))
	_layout()
	_layout.call_deferred()
	if focus != null:
		focus.grab_focus()

func _heading(title: String, back := "home") -> void:
	var button := _row("Main menu" if back == "home" else "Back to Play", _show.bind(back), false, "back")
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	button.custom_minimum_size.y = 37
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 4, 5))
	button.add_theme_stylebox_override("hover", _box(FOREST, Color.TRANSPARENT, 0, 4, 5))
	button.add_theme_stylebox_override("pressed", _box(Color("285247"), Color.TRANSPARENT, 0, 4, 5))
	column.add_child(_label(title, 39))

func _select_save(entry: Dictionary) -> void:
	selection = entry
	_show("continue")

func _launch(fresh: bool) -> void:
	if changing_scene:
		return
	changing_scene = true
	var resort := World.instantiate() as CoastalResort
	resort.save_path = save_path
	resort.start_new = fresh
	if not fresh and not resort.prepare_start(selection.slot, selection.label):
		resort.free()
		changing_scene = false
		_show("play", "Could not load %s. Choose another save or start a new game." % selection.label)
		return
	_enter_world.call_deferred(resort)

func _enter_world(resort: CoastalResort) -> void:
	var error := get_tree().change_scene_to_node(resort)
	if error != OK:
		resort.free()
		changing_scene = false
		_show("play", "Could not open the resort. Please try again.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not changing_scene and screen not in ["home", ""]:
		get_viewport().set_input_as_handled()
		_show("play" if screen in ["new", "continue"] else "home")

func _set_motion(enabled: bool) -> void:
	motion = enabled
	_update_motion()
	var config := ConfigFile.new()
	config.set_value("menu", "background_motion", motion)
	config.save(_preferences_path())

func _update_motion() -> void:
	if motion and video.stream != null and not video.is_playing():
		video.play()
	video.paused = not motion
	video.visible = video.is_playing()

func _row(title: String, action: Callable, primary := false, icon_name := "") -> Button:
	var button := _button(title, action, primary)
	if not icon_name.is_empty():
		button.icon = _icon(icon_name)
	column.add_child(button)
	return button

func _button(title: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 69 if primary else 60
	button.pressed.connect(action)
	if primary:
		button.add_theme_stylebox_override("normal", _box(GOLD, Color("ffda9a"), 1, 5, 15))
		button.add_theme_stylebox_override("hover", _box(Color("ffd58e"), Color("fff1cf"), 1, 5, 15))
		button.add_theme_stylebox_override("pressed", _box(Color("dba854"), Color("fff1cf"), 1, 5, 15))
		for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color"]:
			button.add_theme_color_override(state, DEEP)
	return button

func _label(title: String, font_size: int, ink := INK) -> Label:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	return label

func _paragraph(copy: String) -> Label:
	var label := _label(copy, 18, MUTED)
	label.custom_minimum_size.x = 370
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _image(texture: Texture2D, dimensions := Vector2.ZERO) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = dimensions
	art.mouse_filter = MOUSE_FILTER_IGNORE
	return art

func _icon(kind: String) -> Texture2D:
	var path: String = {
		"play": '<path d="M7 5l12 7-12 7Z" fill="white" stroke="none"/>',
		"plus": '<path d="M12 5v14M5 12h14"/>',
		"info": '<circle cx="12" cy="12" r="8"/><path d="M12 11v5m0-8h.01"/>',
		"settings": '<path d="M5 7h14M5 12h14M5 17h14M9 5v4m6 1v4m-4 1v4"/>',
		"back": '<path d="M19 12H5m5-5-5 5 5 5"/>',
	}[kind]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="23" height="23" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % path
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _box(fill: Color, border: Color, thickness: int, corner: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(thickness)
	box.set_corner_radius_all(corner)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box

func _menu_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 22
	result.set_stylebox("normal", "Button", _box(FOREST, Color("637b60"), 1, 5, 15))
	result.set_stylebox("hover", "Button", _box(Color("285247"), Color("c8c49d"), 1, 5, 15))
	result.set_stylebox("pressed", "Button", _box(Color("315c4f"), Color("c8c49d"), 1, 5, 15))
	var focus := _box(Color.TRANSPARENT, INK, 2, 5, 0)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		focus.set_expand_margin(side, 3)
	result.set_stylebox("focus", "Button", focus)
	result.set_constant("h_separation", "Button", 13)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		result.set_color(state, "Button", INK)
	return result
