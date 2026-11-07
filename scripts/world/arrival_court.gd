class_name ArrivalCourt
extends Node2D
## Painted public ground and the separate depth-sorted resort gate.

const ASPHALT := Color("59646a")
const EDGE := Color("e5d5b1")
const MARK := Color("f4e6ca")
const PAVER := Color("c8b38d")
const Geometry = preload("res://scripts/simulation/arrival_geometry.gd")
const LOT_ASPHALT := Color("646a69")
const BUS_ASPHALT := Color("567678")
@export_enum("Ground", "Gateway", "Shuttle", "Reception Banner") var part := 0

func _draw() -> void:
	match part:
		0: _draw_court()
		1: _draw_gate()
		2: _draw_shuttle_sign()
		3: _draw_reception_banner()

func _draw_court() -> void:
	var road := Geometry.ROAD
	# All these surfaces meet at shared edges. The driveway spans are breaks
	# in the sidewalks themselves, so there is no curb under a crossing.
	_rect(road, ASPHALT)
	_rect(Geometry.LOT, LOT_ASPHALT)
	_rect(Geometry.ENTRY_APRON, LOT_ASPHALT)
	_rect(Geometry.EXIT_APRON, LOT_ASPHALT)
	var bay := Geometry.bus_pavement()
	var projected := PackedVector2Array()
	for point in bay:
		projected.append(_p(point))
	draw_colored_polygon(projected, BUS_ASPHALT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1907
	for surface: Rect2 in [road, Geometry.LOT, Geometry.ENTRY_APRON, Geometry.EXIT_APRON]:
		for i in int(surface.get_area() * 15):
			var point := Vector2(rng.randf_range(surface.position.x, surface.end.x), rng.randf_range(surface.position.y, surface.end.y))
			var tone := Color(1, 1, 0.9, 0.07) if i % 2 == 0 else Color(0.12, 0.16, 0.19, 0.10)
			var tip := point.move_toward(surface.end, 0.034)
			draw_line(_p(point), _p(tip), tone, 1.0)
	_walk(Geometry.GATE_WALK)
	_walk(Geometry.BUS_WALK)
	# The end of the tapered bay forms a wider landing at the sidewalk turn.
	var landing := Vector2(Geometry.BUS_WEST, Geometry.WALK_NORTH)
	_face([_p(bay[2]), _p(bay[3]), _p(landing)], PAVER)
	_walk(Geometry.FRONT_WALK)
	_walk(Rect2(Geometry.ROAD_EAST, Geometry.STALL_START, Geometry.INNER_WALK, Geometry.STALL_END - Geometry.STALL_START))
	_walk(Rect2(Geometry.LOT_EAST, Geometry.ENTRY_NORTH, Geometry.OUTER_WALK, Geometry.WALK_NORTH - Geometry.ENTRY_NORTH))
	_line(Vector2(Geometry.LOT_WEST, Geometry.ENTRY_NORTH), Vector2(Geometry.LOT_EAST + Geometry.OUTER_WALK, Geometry.ENTRY_NORTH), EDGE.darkened(0.26), 2.2)
	_line(Vector2(road.position.x, road.end.y), Vector2(road.end.x, road.end.y), EDGE.darkened(0.26), 2.2)
	for i in range(3):
		_line(bay[i], bay[i + 1], EDGE.darkened(0.22), 2.0)
	_draw_road_markings()
	_draw_stalls()
	_zebra(Geometry.MAIN_CROSSING.grow(-0.12), true)
	_zebra(Geometry.EXIT_CROSSING.grow(-0.10), false)
	_ground_label(Vector2(Geometry.BUS_STOP.x, 16.10), "BUS", 14, MARK, true)
	_ground_label(Vector2(Geometry.AISLE, Geometry.WALK_CENTER), "GUEST PARKING", 14, Color("514d43"))
	_arrow(Vector2(Geometry.AISLE, Geometry.ENTRY_Y), Vector2.DOWN)
	_arrow(Vector2(Geometry.AISLE - 1.1, Geometry.EXIT_Y), Vector2.LEFT)

func _draw_road_markings() -> void:
	var rear := Geometry.ROAD.position.y
	var center_sections := [
		Vector2(rear, Geometry.ENTRY_NORTH),
		Vector2(Geometry.STALL_START, Geometry.STALL_END)
	]
	for section: Vector2 in center_sections:
		_dashes(Geometry.MEDIAN, section, Color("f5cc80"), 1.9)
	_line(Vector2(Geometry.WEST_EDGE, rear), Vector2(Geometry.WEST_EDGE, Geometry.BUS_TAPER_IN), MARK, 1.65)
	_dashes(Geometry.WEST_EDGE, Vector2(Geometry.BUS_TAPER_IN, Geometry.BUS_TURN_Y - 0.75), MARK, 1.65)
	for section: Vector2 in [Vector2(rear, Geometry.ENTRY_NORTH), Vector2(Geometry.STALL_START, Geometry.STALL_END)]:
		_line(Vector2(Geometry.EAST_EDGE, section.x), Vector2(Geometry.EAST_EDGE, section.y), MARK, 1.65)
	_arrow(Vector2(Geometry.INBOUND, 1.0), Vector2.DOWN)
	_arrow(Vector2(Geometry.OUTBOUND, 1.0), Vector2.UP)
	_arrow(Vector2(Geometry.OUTBOUND, 10.0), Vector2.UP)

func _dashes(x: float, span: Vector2, tint: Color, width: float) -> void:
	const PERIOD := 1.86
	const DASH := 0.94
	var origin := Geometry.ROAD.position.y + 0.32
	var start := origin + ceilf((span.x - origin) / PERIOD) * PERIOD
	while start + DASH <= span.y:
		_line(Vector2(x, start), Vector2(x, start + DASH), tint, width)
		start += PERIOD

func _draw_stalls() -> void:
	for index in range(Geometry.STALLS_PER_ROW * 2):
		var near := index < Geometry.STALLS_PER_ROW
		var back := Geometry.LOT_WEST if near else Geometry.LOT_EAST
		var aisle := Geometry.AISLE_WEST if near else Geometry.AISLE_EAST
		var spot := Geometry.stall_center(index)
		var edge := spot.y - Geometry.STALL_WIDTH * 0.5
		_line(Vector2(back, edge), Vector2(aisle, edge), MARK, 1.65)
		if index % Geometry.STALLS_PER_ROW == Geometry.STALLS_PER_ROW - 1:
			_line(Vector2(back, Geometry.STALL_END), Vector2(aisle, Geometry.STALL_END), MARK, 1.65)
		var stop_x := back + (0.17 if near else -0.29)
		_rect(Rect2(stop_x, spot.y - 0.43, 0.12, 0.86), Color("d7b985"))
		_ground_label(Vector2(back + (0.41 if near else -0.41), spot.y - 0.43), "%02d" % (index + 1), 12, MARK)
func _draw_gate() -> void:
	for side in [-1.0, 1.0]:
		_gate_pier(side * 1.00)
	# Give the opening depth, then lay individual stone blocks on the front.
	for i in 13:
		var a := PI * i / 13.0
		var b := PI * (i + 1) / 13.0
		_face([_arch_point(-0.23,a,true), _arch_point(-0.23,b,true), _arch_point(0.23,b,true), _arch_point(0.23,a,true)], Color("c18b55").lightened(0.17 * sin((a+b)*0.5)))
		_face([_arch_point(-0.23,a,false), _arch_point(-0.23,b,false), _arch_point(0.23,b,false), _arch_point(0.23,a,false)], Color("92603c"))
	for i in 13:
		var a := PI * i / 13.0
		var b := PI * (i + 1) / 13.0
		var stone := Color("e3b883").lightened(0.07 * sin(float(i) * 4.1))
		var points: Array[Vector2] = [_arch_point(0.23,a,true), _arch_point(0.23,b,true), _arch_point(0.23,b,false), _arch_point(0.23,a,false)]
		_face(points, stone)
		draw_line(points[0], points[3], Color("a47149"), 0.9, true)
		draw_line(points[0], points[1], Color("ffdda6"), 1.8, true)
		draw_line(points[3], points[2], Color("b48150"), 1.4, true)
	var crest := _p(Vector2(0.24, 0.0)) - Vector2(0, 98)
	_board(crest, "RESORTIS", 76)
	draw_circle(crest - Vector2(0, 15), 5, Color("754b36"))
	draw_circle(crest - Vector2(0, 16), 3.4, Color("ffc969"))
	for side in [-1.0, 1.0]:
		var mount := _p(Vector2(0.29, side * 1.00)) - Vector2(0, 40)
		draw_rect(Rect2(mount - Vector2(4, 4), Vector2(8, 11)), Color("654530"))
		draw_rect(Rect2(mount - Vector2(2.5, 2), Vector2(5, 7)), Color("ffd079"))
		draw_line(mount - Vector2(4, 5), mount + Vector2(4, -5), Color("a57442"), 2.0)
		_gate_planter(_p(Vector2(0.36, side * 1.29)))

func _arch_point(depth: float, angle: float, outer: bool) -> Vector2:
	var span := 1.19 if outer else 0.81
	var rise := 50.0 if outer else 36.0
	return _p(Vector2(depth, cos(angle) * span)) - Vector2(0, 54.0 + sin(angle) * rise)

func _gate_pier(y: float) -> void:
	draw_ellipse(_p(Vector2(0.04, y)) + Vector2(2, 2), 15, 5, Color(0.18, 0.13, 0.07, 0.29))
	_pier_block(y, 0.34, 0.29, 0.0, 7.0, Color("b08256"))
	_pier_block(y, 0.25, 0.19, 7.0, 49.0, Color("d6ad7e"))
	for height in [16.0, 27.0, 38.0]:
		draw_line(_p(Vector2(0.25, y - 0.19)) - Vector2(0,height), _p(Vector2(0.25, y + 0.19)) - Vector2(0,height), Color("ac7c52"), 0.9, true)
	_pier_block(y, 0.29, 0.23, 49.0, 55.0, Color("edc38e"))

func _pier_block(y: float, depth: float, width: float, low: float, high: float, stone: Color) -> void:
	var a := _p(Vector2(-depth, y + width))
	var b := _p(Vector2(depth, y + width))
	var c := _p(Vector2(depth, y - width))
	var d := _p(Vector2(-depth, y - width))
	var base := Vector2(0, low)
	var top := Vector2(0, high)
	_face([a-base,b-base,b-top,a-top], stone.darkened(0.24))
	_face([b-base,c-base,c-top,b-top], stone)
	_face([a-top,b-top,c-top,d-top], stone.lightened(0.23))

func _gate_planter(at: Vector2) -> void:
	draw_ellipse(at + Vector2(1, 1), 10, 4, Color(0.18, 0.13, 0.07, 0.27))
	_face([at+Vector2(-8,-10),at+Vector2(8,-10),at+Vector2(5,0),at+Vector2(-5,0)], Color("b7653d"))
	draw_ellipse(at - Vector2(0, 10), 8.5, 4, Color("e89e63"))
	draw_ellipse(at - Vector2(0, 11), 6.5, 2.8, Color("593d28"))
	for i in 7:
		var x := (float(i)-3.0) * 3.6
		var root := at - Vector2(0, 11)
		var tip := root + Vector2(x, -16.0 + absf(x) * 0.57)
		var bow := root.lerp(tip, 0.54)
		_face([root, bow+Vector2(2.5,0), tip, bow-Vector2(2.5,1)], Color("478041").lightened(0.10 * (i % 3)))
		draw_line(root, tip, Color("a1bd5c"), 0.65, true)
	for x in [-5, 1, 7]:
		draw_circle(at + Vector2(x, -22 + abs(x) * 0.5), 2.4, Color("f09e76"), true)

func _face(points: Array[Vector2], tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), tint)

func _zebra(rect: Rect2, along_x: bool) -> void:
	var span := rect.size.x if along_x else rect.size.y
	var count := maxi(3, roundi(span / 0.34))
	var step := span / count
	for i in count:
		var start := (i + 0.13) * step
		var stripe := Rect2(rect.position + Vector2(start, 0), Vector2(step * 0.57, rect.size.y)) if along_x else Rect2(rect.position + Vector2(0, start), Vector2(rect.size.x, step * 0.57))
		_rect(stripe, MARK)

func _draw_shuttle_sign() -> void:
	_post(Vector2.ZERO, 34)
	_board(Vector2(0, -34), "SHUTTLE", 61)

func _board(center: Vector2, title: String, width: float) -> void:
	# Boards run parallel to the road and the gate beam, with upright posts.
	draw_set_transform_matrix(Transform2D(Vector2(1, -0.5), Vector2.DOWN, center))
	draw_style_box(_sign_style(), Rect2(Vector2(-width * 0.5, -10), Vector2(width, 20)))
	_label(Vector2(0, 4), title, 12, Color("fff2c9"))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_reception_banner() -> void:
	# The parent is the hut sprite. These are pixels on its painted wood face.
	draw_set_transform_matrix(Transform2D(Vector2(0.86, 0.21), Vector2.DOWN, Vector2(155, 187)))
	_label(Vector2(0, 5.5), "RECEPTION", 13, Color("623416"))
	_label(Vector2(0, 4), "RECEPTION", 13, Color("fff0bf"))

func _post(foot: Vector2, height: float) -> void:
	draw_ellipse(foot + Vector2(2, 1), 10, 4, Color(0.18,0.13,0.07,0.27))
	draw_rect(Rect2(foot + Vector2(-6,-8), Vector2(12,10)), Color("756c59"))
	draw_rect(Rect2(foot + Vector2(-4,-height), Vector2(8,height-4)), Color("815632"))
	draw_rect(Rect2(foot + Vector2(-3,-height), Vector2(3,height-5)), Color("d19a5d"))

func _sign_style() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color("234e4d")
	result.border_color = Color("dfb77d")
	result.set_border_width_all(2)
	result.set_corner_radius_all(5)
	return result

func _walk(rect: Rect2) -> void:
	_rect(rect, EDGE.darkened(0.23))
	_rect(rect.grow(-0.07), PAVER)
	if rect.size.x > rect.size.y:
		for x in range(1, ceili(rect.size.x * 2)):
			var at := rect.position.x + x * 0.5
			_line(Vector2(at, rect.position.y + 0.08), Vector2(at, rect.end.y - 0.08), EDGE.darkened(0.27), 1.0)
	else:
		for y in range(1, ceili(rect.size.y * 2)):
			var at := rect.position.y + y * 0.5
			_line(Vector2(rect.position.x + 0.08, at), Vector2(rect.end.x - 0.08, at), EDGE.darkened(0.27), 1.0)

func _arrow(point: Vector2, direction: Vector2) -> void:
	var tip := point + direction * 0.28
	var tail := point - direction * 0.36
	var side := direction.orthogonal() * 0.18
	_line(tail, tip, MARK, 1.8)
	_line(tip, point + side, MARK, 1.8)
	_line(tip, point - side, MARK, 1.8)

func _ground_label(point: Vector2, word: String, size: int, tint: Color, along_road := false) -> void:
	var across := Vector2(1, -0.5) if along_road else Vector2(1, 0.5)
	var down := Vector2(0.8, 0.4) if along_road else Vector2(-0.8, 0.4)
	draw_set_transform_matrix(Transform2D(across, down, _p(point)))
	_label(Vector2(0, size * 0.3), word, size, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _label(point: Vector2, word: String, size: int, tint: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, point - Vector2(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, 0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)

func _rect(rect: Rect2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_p(rect.position), _p(Vector2(rect.end.x, rect.position.y)), _p(rect.end), _p(Vector2(rect.position.x, rect.end.y))]), color)

func _line(a: Vector2, b: Vector2, tint: Color, width: float) -> void:
	draw_line(_p(a), _p(b), tint, width, true)

func _p(point: Vector2) -> Vector2:
	return IsometricGrid.project(point)
