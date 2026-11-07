class_name FacilityAmbience
extends Node2D
## A packed asset component. Placed resorts drive it from their clock;
## individual asset scenes can run it independently for previews.

const WATER_SHADER = preload("res://assets/shaders/pool_motion.gdshader")
const KINDS := ["cabin", "reception", "cafe", "pool", "sunbeds", "volleyball", "pier",
	"gym", "sauna", "ice_cream", "restaurant", "yoga", "massage", "gear", "pickleball"]
const MODEL_HEIGHT := 32.0 * sqrt(1.5)

@export var facility_kind := ""
@export var facing := 0
@export var art_to_local := Transform2D.IDENTITY
@export var model_origin := Vector2.ZERO
@export var plot_origin := Vector2.ZERO
@export var phase_offset := 0.0
@export var automatic_clock := true
var elapsed := 0.0
var _water_materials: Array[ShaderMaterial] = []
var _workstation: AnimatedSprite2D
var _step := -1

func configure(kind: String, orientation: int, source: Transform2D, model: Vector2, plot: Vector2, id: int, art: Texture2D) -> void:
	name = "Ambience"
	facility_kind = kind
	facing = orientation
	art_to_local = source
	model_origin = model
	plot_origin = plot
	phase_offset = fposmod(id * 0.379, 7.0)
	if kind == "pool": _build_water(art)
	if kind in FacilityStaff.KINDS: _build_workstation(source)

func _ready() -> void:
	_workstation = get_node_or_null("OccupiedVenue") as AnimatedSprite2D
	for child in get_children():
		if child is Polygon2D and child.material is ShaderMaterial:
			# Packed scenes share their subresources. Each placed pool needs its
			# own uniform state, including its object phase.
			child.material = child.material.duplicate()
			_water_materials.append(child.material as ShaderMaterial)
	set_process(automatic_clock)
	present(0.0)

func _process(delta: float) -> void:
	present(elapsed + delta)

func present(time: float) -> void:
	elapsed = time
	var tick := floori(time * 24.0)
	if tick == _step: return
	_step = tick
	var local_time := time + phase_offset
	if _workstation != null:
		_workstation.set_frame_and_progress(FacilityStaff.pose_at(facility_kind, local_time), 0.0)
	for material in _water_materials:
		material.set_shader_parameter("elapsed", local_time)
	queue_redraw()

func _build_workstation(source: Transform2D) -> void:
	var venue := AnimatedSprite2D.new()
	venue.name = "OccupiedVenue"
	venue.sprite_frames = StaffedVenueArt.frames(facility_kind)
	venue.animation = &"work"
	venue.centered = false
	venue.transform = source
	venue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	venue.show_behind_parent = true
	add_child(venue)

func _build_water(texture: Texture2D) -> void:
	# Trace the original water edge and leave a notch for both ladder rails.
	_water_surface("Surface", texture, [Vector2(241, 696), Vector2(677, 501), Vector2(715, 522),
		Vector2(751, 503), Vector2(849, 556), Vector2(913, 573), Vector2(1076, 666),
		Vector2(902, 756), Vector2(894, 731), Vector2(881, 715), Vector2(862, 707),
		Vector2(845, 712), Vector2(830, 729), Vector2(818, 756), Vector2(802, 741),
		Vector2(783, 739), Vector2(767, 755), Vector2(757, 783), Vector2(747, 837),
		Vector2(605, 909)], false)
	_water_surface("Waterfall", texture, [Vector2(899, 414), Vector2(938, 421), Vector2(931, 450),
		Vector2(922, 485), Vector2(923, 534), Vector2(940, 554), Vector2(930, 576),
		Vector2(896, 571), Vector2(864, 558), Vector2(853, 541), Vector2(865, 506),
		Vector2(873, 461), Vector2(882, 434)], true)

func _water_surface(label: String, texture: Texture2D, outline: Array[Vector2], fall: bool) -> void:
	var surface := Polygon2D.new()
	surface.name = label
	surface.texture = texture
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	surface.polygon = _atlas_points(outline)
	surface.uv = PackedVector2Array(outline)
	var shader := ShaderMaterial.new()
	shader.shader = WATER_SHADER
	shader.set_shader_parameter("waterfall", fall)
	surface.material = shader
	add_child(surface)

func _atlas_points(outline: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in outline: points.append(art_to_local * point)
	return points

func _model(x: float, height: float, z: float) -> Vector2:
	return model_origin + IsometricGrid.project(Vector2(x, z)) - Vector2(0, MODEL_HEIGHT * height)

func _draw() -> void:
	var t := elapsed + phase_offset
	match facility_kind:
		"cabin":
			var lamp := Vector2(164, 185) if facing == 0 else Vector2(912, 184)
			_lamplight(art_to_local * lamp, 6.0, t)
		"reception":
			_lamplight(_venue_point("lamp"), 5.5, t)
			_lamplight(_venue_point("lamp_right"), 5.5, t + 0.5)
		"cafe":
			_lamplight(_venue_point("lamp"), 5.5, t)
		"sunbeds":
			_glint(art_to_local * Vector2(1297, 781), t)
		"volleyball":
			_streamer(_model(0, 1.91, 2.25), t, Color("318fbb"))
		"pier":
			_pier_ripples(t)
		"gym":
			for x in [-2.62, -1.39, -0.16]:
				var tint := Color(0.53, 1.0, 0.83, 0.46 + sin(t * 4.3 + x) * 0.28)
				draw_line(_model(x - 0.11, 1.54, -1.60), _model(x + 0.11, 1.54, -1.60), tint, 1.2, true)
				var position_on_belt := lerpf(-1.68, -0.66, fposmod(t * 0.62 + x, 1.0))
				draw_line(_model(x - 0.20, 0.522, position_on_belt), _model(x + 0.20, 0.522, position_on_belt), Color(0.70, 0.86, 0.80, 0.20), 1.0, true)
		"sauna":
			_steam(_model(0.88, 1.12, 0.57), t, 24.0, 0.36)
			_steam(_model(2.18, 0.78, -0.05), t + 0.64, 12.0, 0.17)
		"ice_cream":
			_glint(_venue_point("glint"), t)
		"restaurant":
			_steam(_venue_point("steam"), t, 17.0, 0.38)
		"yoga":
			_streamer(_venue_point("wind"), t, Color("ead0a1"))
		"massage":
			for x in [-2.02, 0.0, 2.02]:
				_lamplight(_model(x, 2.18, -0.03), 7.0, t + x)
			_steam(_model(1.75, 0.38, 1.08), t, 13.0, 0.14)
		"gear":
			_streamer(_venue_point("wind"), t, Color("e0ac58"))
		"pickleball":
			_streamer(_model(0, 1.23, 2.30), t, Color("e0a951"))

func _venue_point(effect: String) -> Vector2:
	return plot_origin + StaffedVenueArt.point(facility_kind, effect)

func _lamplight(point: Vector2, radius: float, t: float) -> void:
	var flicker := 0.72 + 0.20 * sin(t * 7.0) + 0.08 * sin(t * 13.0)
	draw_circle(point, radius, Color(1.0, 0.62, 0.26, flicker * 0.075), true, -1.0, true)
	draw_circle(point, radius * 0.58, Color(1.0, 0.77, 0.37, flicker * 0.15), true, -1.0, true)
	draw_circle(point, radius * 0.24, Color(1.0, 0.91, 0.63, flicker * 0.24), true, -1.0, true)

func _steam(source: Vector2, t: float, rise: float, opacity: float) -> void:
	for i in 5:
		var age := fposmod(t * 0.62 + i / 5.0, 1.0)
		var drift := sin(age * 5.0 + i * 1.6) * (1.3 + age * 4.0)
		var point := source + Vector2(drift, -age * rise)
		var alpha := sin(age * PI) * opacity
		draw_circle(point, 1.5 + age * 3.0, Color(0.87, 0.96, 0.96, alpha * 0.45), true, -1.0, true)
		draw_circle(point + Vector2(0.7, -0.8), 0.9 + age * 1.3, Color(0.95, 0.99, 0.97, alpha), true, -1.0, true)

func _glint(point: Vector2, t: float) -> void:
	var pulse := pow(maxf(0.0, sin(t * 2.3)), 9.0)
	var color := Color(1, 0.98, 0.82, 0.74 * pulse)
	draw_line(point - Vector2(2.7, 0), point + Vector2(2.7, 0), color, 0.8, true)
	draw_line(point - Vector2(0, 2.7), point + Vector2(0, 2.7), color, 0.8, true)

func _streamer(point: Vector2, t: float, tint: Color) -> void:
	var tip := Vector2(9.5 + sin(t * 3.3) * 2.1, 2.0 + sin(t * 5.1) * 2.6)
	var bend := Vector2(4.5, sin(t * 5.1 - 1.0) * 1.45)
	draw_colored_polygon(PackedVector2Array([point, point + bend, point + tip,
		point + bend + Vector2(0.0, 3.6), point + Vector2(0.0, 3.8)]), tint)
	draw_line(point, point + bend, tint.lightened(0.32), 0.8, true)

func _pier_ripples(t: float) -> void:
	for side in [-0.32, 1.32]:
		for i in 3:
			var age := fposmod(t * 0.45 + i / 3.0, 1.0)
			var center := plot_origin + IsometricGrid.project(Vector2(side, 7.9 + 0.42 * i))
			var from := 1.25 if side < 0 else -0.5
			draw_set_transform(center, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, 3.0 + age * 7.0, from, from + 1.6, 12,
				Color(0.87, 1.0, 0.98, sin(age * PI) * 0.27), 1.1, true)
	draw_set_transform(Vector2.ZERO)
