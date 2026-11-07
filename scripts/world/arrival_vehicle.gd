class_name ArrivalVehicle
extends Node2D
## Orthographically projected mesh faces. Local X points through the bonnet.

const CAR_COLORS := [Color("39bdb1"), Color("f6c452"), Color("e97660"), Color("67aee5"), Color("96bb5d"), Color("f6deb0")]
const CAR_SCALE := 1.24
const SHUTTLE_SCALE := 1.28
const CAR_FRONT := 0.84
const SHUTTLE_FRONT := 1.32
const CAR_HALF_WIDTH := 0.39
const SHUTTLE_HALF_WIDTH := 0.46
var _bus := false
var _paint := Color.WHITE
var _angle := 0.0
var _rolling := 0.0
var _door := 0.0
var _door_side := 1.0
var _faces: Array[Dictionary] = []

func configure(identity: int, bay: int) -> void:
	_bus = bay == ArrivalTraffic.BUS
	_door_side = -1.0 if not _bus and bay < 6 else 1.0
	_paint = Color("2db9ab") if _bus else CAR_COLORS[identity % CAR_COLORS.size()]

func present(point: Vector2, heading: Vector2, distance: float, door: float) -> void:
	var angle := heading.angle()
	position = IsometricGrid.project(point)
	if is_equal_approx(_angle, angle) and is_equal_approx(_rolling, distance) and is_equal_approx(_door, door): return
	_angle = angle
	_rolling = distance
	_door = door
	queue_redraw()

func _draw() -> void:
	_faces.clear()
	var front := SHUTTLE_FRONT if _bus else CAR_FRONT
	var half_width := SHUTTLE_HALF_WIDTH if _bus else CAR_HALF_WIDTH
	var floor_height := 0.16
	var shoulder := 0.49 if _bus else 0.43
	var roof := 0.99 if _bus else 0.69
	_shadow(front, half_width)
	_shell(-front + 0.015, front - 0.015, half_width * 0.96, floor_height - 0.025, -front, front, half_width, floor_height + 0.05, _paint.darkened(0.35))
	_shell(-front, front, half_width, floor_height + 0.05, -front + 0.06, front - 0.06, half_width * 0.98, shoulder, _paint)
	if _bus:
		_shell(-front + 0.06, front - 0.06, half_width * 0.98, shoulder, -front + 0.09, front - 0.10, half_width * 0.98, roof - 0.10, Color("f7e6bb"))
		_shell(-front + 0.09, front - 0.10, half_width * 0.98, roof - 0.10, -front + 0.17, front - 0.18, half_width * 0.82, roof, Color("ffefc4"))
		for x in [-0.87, -0.46, -0.05, 0.36]:
			for side in [-1.0, 1.0]:
				_window_side(x, x + 0.32, half_width * 0.982 * side, 0.57, 0.87)
		for side in [-1.0, 1.0]:
			var y: float = side * (half_width - 0.002)
			_quad(Vector3(-1.10,y,0.345), Vector3(1.09,y,0.345), Vector3(1.09,y,0.395), Vector3(-1.10,y,0.395), Color("b6efe0"), side > 0, 0.045)
			_quad(Vector3(-1.10,y,0.318), Vector3(1.09,y,0.318), Vector3(1.09,y,0.34), Vector3(-1.10,y,0.34), Color("c59249"), side > 0, 0.05)
		_end_glass(front - 0.079, front - 0.133, half_width * 0.82, 0.56, 0.90)
		_end_glass(-front + 0.079, -front + 0.115, half_width * 0.75, 0.61, 0.88, true)
		_door_panel(0.76, 1.13, half_width * 0.986, 0.27, 0.88)
		_shell(-0.61, 0.55, 0.25, roof, -0.57, 0.51, 0.21, roof + 0.055, Color("d4c393"))
		for x in [-0.35, -0.18, -0.01, 0.16, 0.33]:
			_quad(Vector3(x,-0.15,roof+0.056), Vector3(x+0.035,-0.15,roof+0.056), Vector3(x+0.035,0.15,roof+0.056), Vector3(x,0.15,roof+0.056), Color("9d8b69"), false, 0.012)
	else:
		_shell(-0.58, 0.44, half_width * 0.94, shoulder, -0.44, 0.22, half_width * 0.76, roof, _paint.lightened(0.13))
		var glass := Color("334c59")
		for side in [-1.0, 1.0]:
			var y: float = side * (half_width - 0.002)
			_quad(Vector3(-0.69,y,0.369), Vector3(0.69,y,0.369), Vector3(0.69,y,0.403), Vector3(-0.69,y,0.403), _paint.lightened(0.38), side > 0, 0.055)
			_quad(Vector3(-0.50, side * 0.365, 0.46), Vector3(-0.07, side * 0.365, 0.46), Vector3(-0.07, side * 0.313, 0.64), Vector3(-0.40, side * 0.313, 0.64), glass, side > 0.0, 0.28)
			_quad(Vector3(0.0, side * 0.365, 0.46), Vector3(0.37, side * 0.365, 0.46), Vector3(0.19, side * 0.313, 0.64), Vector3(0.0, side * 0.313, 0.64), glass.lightened(0.11), side > 0.0, 0.20)
		_end_glass(0.421, 0.247, 0.30, 0.45, 0.66)
		_end_glass(-0.571, -0.452, 0.29, 0.45, 0.66, true)
		_door_panel(-0.26, 0.34, _door_side * half_width * 0.987, 0.24, 0.44)
	for end in [-1.0, 1.0]:
		var x: float = (front - 0.005) * end
		_end_detail(x, -0.32, 0.32, 0.20, 0.257, Color("344148"), end < 0.0)
		_end_detail(x + end * 0.006, -0.30, 0.30, 0.244, 0.267, Color("c3c0a6"), end < 0.0)
		if end > 0.0:
			_end_detail(x + 0.005, -0.15, 0.15, 0.288, 0.348, Color("344148"), false)
			_end_detail(x + 0.010, -0.135, 0.135, 0.306, 0.325, Color("aeb9ad"), false)
		else:
			_end_detail(x - 0.007, -0.10, 0.10, 0.285, 0.328, Color("efe5bc"), true)
		for side in [-1.0, 1.0]:
			var center: float = side * 0.26
			_end_detail(x + end * 0.009, center - 0.075, center + 0.075, 0.302, 0.397, Color("765842"), end < 0.0)
			_end_detail(x + end * 0.013, center - 0.059, center + 0.059, 0.318, 0.383, Color("ffeab5") if end > 0.0 else Color("e55942"), end < 0.0)
			_end_detail(x + end * 0.016, center - 0.045, center + 0.045, 0.364, 0.384, Color("fff8dc") if end > 0.0 else Color("ffb384"), end < 0.0)
	for x in [-front * 0.69, front * 0.69]:
		for side in [-1.0, 1.0]:
			_wheel(x, side, half_width)
	_faces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth < b.depth)
	for face in _faces:
		_draw_panel(face.points, face.color)

func _draw_panel(points: PackedVector2Array, paint: Color) -> void:
	var top := INF
	var bottom := -INF
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var shades := PackedColorArray()
	for point in points:
		var light := (point.y - top) / maxf(1.0, bottom - top)
		shades.append(paint.lightened(0.13).lerp(paint.darkened(0.19), light))
	draw_polygon(points, shades)

func _shadow(front: float, width: float) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(_screen(Vector3(cos(angle) * (front + 0.21), sin(angle) * (width + 0.21), 0.0)) + Vector2(1, 2))
	draw_colored_polygon(points, Color(0.10, 0.14, 0.16, 0.28))

func _shell(back: float, front: float, width: float, bottom: float, top_back: float, top_front: float, top_width: float, top: float, color: Color) -> void:
	var lower := _ring(back, front, width, bottom)
	var upper := _ring(top_back, top_front, top_width, top)
	for i in 8:
		var j := (i + 1) % 8
		var edge := Vector2(lower[j].x - lower[i].x, lower[j].y - lower[i].y)
		var normal := Vector2(edge.y, -edge.x).normalized().rotated(_angle)
		var tint := color.darkened(0.09 + 0.16 * maxf(0.0, normal.dot(Vector2(0.28, 0.96))))
		_quad(lower[i], lower[j], upper[j], upper[i], tint)
	_face(upper, color.lightened(0.18))

func _ring(back: float, front: float, width: float, height: float) -> Array[Vector3]:
	var corner := 0.085
	return [Vector3(back + corner, -width, height), Vector3(front - corner, -width, height),
		Vector3(front, -width + corner, height), Vector3(front, width - corner, height),
		Vector3(front - corner, width, height), Vector3(back + corner, width, height),
		Vector3(back, width - corner, height), Vector3(back, -width + corner, height)]

func _window_side(a: float, b: float, y: float, bottom: float, top: float) -> void:
	var bias := 0.08 + absf((a+b) * 0.5)
	_quad(Vector3(a-0.017,y,bottom-0.018), Vector3(b+0.017,y,bottom-0.018), Vector3(b+0.017,y * 0.967,top+0.017), Vector3(a-0.017,y * 0.967,top+0.017), Color("a08361"), y > 0, bias - 0.008)
	_quad(Vector3(a,y,bottom), Vector3(b,y,bottom), Vector3(b,y * 0.967,top), Vector3(a,y * 0.967,top), Color("354f5e"), y > 0, bias)
	_quad(Vector3(a+0.035,y*0.997,top-0.10), Vector3(b-0.015,y*0.997,top-0.10), Vector3(b-0.015,y*0.977,top-0.042), Vector3(a+0.035,y*0.977,top-0.042), Color("688e9b"), y > 0, bias + 0.01)

func _end_glass(low_x: float, high_x: float, width: float, bottom: float, top: float, reverse := false) -> void:
	_quad(Vector3(low_x,-width,bottom), Vector3(low_x,width,bottom), Vector3(high_x,width*0.87,top), Vector3(high_x,-width*0.87,top), Color("405e6d"), reverse)
	var shine := lerpf(low_x, high_x, 0.65) + (-0.005 if reverse else 0.005)
	_quad(Vector3(shine,-width*0.66,lerpf(bottom,top,0.65)), Vector3(shine,width*0.50,lerpf(bottom,top,0.65)), Vector3(high_x,width*0.63,top-0.018), Vector3(high_x,-width*0.62,top-0.018), Color("7196a1"), reverse)

func _end_detail(x: float, a: float, b: float, bottom: float, top: float, color: Color, reverse: bool) -> void:
	_quad(Vector3(x,a,bottom), Vector3(x,b,bottom), Vector3(x,b,top), Vector3(x,a,top), color, reverse)

func _door_panel(back: float, front: float, y: float, low: float, high: float) -> void:
	var hinge := Vector2(front,y)
	var open := Vector2(back-front, 0).rotated(-signf(y) * _door * 1.10) + hinge
	var tint := _paint.darkened(0.25) if _bus else _paint.darkened(0.15)
	_quad(Vector3(open.x,open.y,low), Vector3(front,y,low), Vector3(front,y,high), Vector3(open.x,open.y,high), tint, y > 0)
	if _door > 0.02:
		_quad(Vector3(back,y,low), Vector3(front,y,low), Vector3(front,y,high), Vector3(back,y,high), Color("293c3d"), y > 0)
	if _bus:
		var window_edge := hinge.lerp(open, 0.85)
		var window_front := hinge.lerp(open, 0.12)
		_quad(Vector3(window_edge.x,window_edge.y,high-0.30), Vector3(window_front.x,window_front.y,high-0.30), Vector3(window_front.x,window_front.y,high-0.035), Vector3(window_edge.x,window_edge.y,high-0.035), Color("547583"), y > 0)

func _wheel(x: float, side: float, width: float) -> void:
	var radius := 0.16 if _bus else 0.135
	var tire: Array[Vector3] = []
	var hub: Array[Vector3] = []
	for i in 12:
		var angle := -side * TAU * i / 12.0
		var spoke := Vector2(cos(angle), sin(angle))
		tire.append(Vector3(x + spoke.x * radius, side * (width + 0.018), radius + spoke.y * radius))
		hub.append(Vector3(x + spoke.x * radius * 0.56, side * (width + 0.020), radius + spoke.y * radius * 0.56))
	_face(tire, Color("2d2c2a"))
	_face(hub, Color("c4bcaa"))
	var spin := _rolling / (radius * _vehicle_scale())
	var a := Vector2(cos(spin), sin(spin)) * radius * 0.46
	var b := Vector2(-a.y, a.x) * 0.19
	var points: Array[Vector3] = []
	for p in [a-b, a+b, -a+b, -a-b]:
		points.append(Vector3(x+p.x, side*(width+0.023), radius+p.y))
	if side > 0.0: points.reverse()
	_face(points, Color("4d565a"))

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, reverse := false, depth_bias := 0.0) -> void:
	var vertices: Array[Vector3] = [a,b,c,d]
	if reverse: vertices.reverse()
	_face(vertices, color, depth_bias)

func _face(vertices: Array[Vector3], color: Color, depth_bias := 0.0) -> void:
	var points := PackedVector2Array()
	var depth := 0.0
	for vertex in vertices:
		points.append(_screen(vertex))
		var point := Vector2(vertex.x, vertex.y).rotated(_angle)
		depth += point.x + point.y + vertex.z * 1.12
	if (points[1]-points[0]).cross(points[2]-points[1]) <= 0.001: return
	_faces.append({"points": points, "depth": depth / vertices.size() + depth_bias, "color": color})

func _screen(point: Vector3) -> Vector2:
	return (IsometricGrid.project(Vector2(point.x, point.y).rotated(_angle)) - Vector2(0, point.z * 32)) * _vehicle_scale()

func _vehicle_scale() -> float:
	return SHUTTLE_SCALE if _bus else CAR_SCALE
