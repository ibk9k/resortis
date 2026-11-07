class_name ArrivalTraffic
extends RefCounted
## Public court geometry and timetable. The saved party owns its parking bay.

const Geometry = preload("res://scripts/simulation/arrival_geometry.gd")
const BAY_COUNT := Geometry.STALLS_PER_ROW * 2
const BUS := -1
const BUS_DWELL := 4.2
const ROAD_END := -22.0
const SERVICE_SECONDS := 2.0

# Saved parties record the bay and clock, so these phase durations are part
# of the save format. New pavement changes the path, not its phase boundaries.
const DRIVE_IN := [11.9312173111098, 12.4640075377056, 13.0068648440497, 13.5497218779155, 14.0925791842597, 14.635436303275]
const BACKOUT := [2.13436551860401, 2.13436542281083, 2.13436542281083, 2.13436542281083, 2.13436542281083, 2.13436523973942]
const DRIVE_OUT := [17.834577533177, 17.2917202268328, 16.7488629204886, 16.2060058866228, 15.6631485802787, 15.1202915464129]
const WALK_NEAR := [12.3749839342557, 11.400625644586, 10.4262663767888, 9.45190759805533, 8.4775483302581, 7.50318906246088]
const WALK_FAR := [16.4980613268339, 15.5237030371642, 14.5493437693669, 13.5749849906335, 12.6006257228362, 11.626266455039]

static func bay(index: int) -> Vector2:
	return Geometry.stall_center(index)

static func arrival_route(index: int) -> PackedVector2Array:
	var start := Vector2(Geometry.INBOUND, ROAD_END)
	if index == BUS:
		return rounded([start, Vector2(Geometry.INBOUND, Geometry.BUS_TAPER_IN + 1.25), Vector2(Geometry.BUS_STOP.x, Geometry.BUS_STRAIGHT_IN + 1.0), Geometry.BUS_STOP], 1.45)
	var spot := bay(index)
	return rounded([start, Vector2(Geometry.INBOUND, Geometry.ENTRY_Y), Vector2(Geometry.AISLE, Geometry.ENTRY_Y), Vector2(Geometry.AISLE, spot.y), spot], 1.1)

static func exit_route(index: int) -> PackedVector2Array:
	var end := Vector2(Geometry.OUTBOUND, ROAD_END)
	if index == BUS:
		var radius := (Geometry.OUTBOUND - Geometry.BUS_STOP.x) * 0.5
		var center := Vector2(Geometry.BUS_STOP.x + radius, Geometry.BUS_TURN_Y)
		var points := PackedVector2Array([Geometry.BUS_STOP])
		for step in 25:
			var angle := PI * (1.0 - float(step) / 24.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		points.append(end)
		return points
	return rounded([backout_route(index)[-1], Vector2(Geometry.AISLE, Geometry.EXIT_Y), Vector2(Geometry.OUTBOUND, Geometry.EXIT_Y), end], 1.15)

static func backout_route(index: int) -> PackedVector2Array:
	var spot := bay(index)
	return rounded([spot, Vector2(Geometry.AISLE, spot.y), Vector2(Geometry.AISLE, spot.y - 1.06)])

static func boarding_seconds(index: int) -> float:
	return walk_seconds(index, 1) + 1.45

static func clear_seconds(index: int) -> float:
	return boarding_seconds(index) + backout_seconds(index) + exit_seconds(index)

static func pedestrian_route(index: int, role: int) -> PackedVector2Array:
	var gate := Vector2(ResortLayout.ARRIVAL)
	var lane := Geometry.WALK_CENTER + (float(role) - 0.5) * 0.37
	if index == BUS:
		var door := Geometry.BUS_STOP + Vector2(-0.77, 0.94)
		var curb := Geometry.BUS_WALK.get_center().x
		return PackedVector2Array([door, Vector2(curb, door.y), Vector2(curb, lane), Vector2(40.45, lane), gate])
	var spot := bay(index)
	var curb := Geometry.ROAD_EAST + Geometry.INNER_WALK * 0.5 if index < Geometry.STALLS_PER_ROW else Geometry.LOT_EAST + Geometry.OUTER_WALK * 0.5
	var door := spot + Vector2(0, 0.58)
	return PackedVector2Array([door, Vector2(curb, door.y), Vector2(curb, lane), Vector2(40.45, lane), gate])

static func walk_start(index: int, role: int) -> float:
	return arrival_seconds(index) + 0.75 + role * 0.65

static func walk_end(index: int, role: int) -> float:
	return walk_start(index, role) + walk_seconds(index, role)

static func walk_seconds(index: int, role: int) -> float:
	var row := index % Geometry.STALLS_PER_ROW
	var first: float = 4.44677829742432 if index == BUS else (WALK_NEAR[row] if index < Geometry.STALLS_PER_ROW else WALK_FAR[row])
	return first + role * 0.3088179612771

static func arrival_seconds(index: int) -> float:
	return 12.1372037683214 if index == BUS else DRIVE_IN[index % Geometry.STALLS_PER_ROW]

static func backout_seconds(index: int) -> float:
	return BACKOUT[index % Geometry.STALLS_PER_ROW]

static func exit_seconds(index: int) -> float:
	return 14.4286258501666 if index == BUS else DRIVE_OUT[index % Geometry.STALLS_PER_ROW]

static func length(points: PackedVector2Array) -> float:
	var result := 0.0
	for i in range(1, points.size()):
		result += points[i].distance_to(points[i - 1])
	return result

static func sample(points: PackedVector2Array, distance: float) -> Vector2:
	for i in range(1, points.size()):
		var segment := points[i] - points[i - 1]
		var span := segment.length()
		if distance <= span: return points[i - 1] + segment.normalized() * maxf(0.0, distance)
		distance -= span
	return points[-1]

static func roadside_point(point: Vector2) -> Vector2:
	# The outer approach stretches to the horizon. Keep its timetable so a
	# saved vehicle resumes at the same stage of its trip.
	var approach := clampf(inverse_lerp(-10.0, ROAD_END, point.y), 0.0, 1.0)
	point.y += (ResortLayout.BACKDROP_REAR_EDGE - ROAD_END) * approach * approach
	return point

static func rounded(corners: Array[Vector2], trim := 0.7) -> PackedVector2Array:
	var points := PackedVector2Array([corners[0]])
	for i in range(1, corners.size() - 1):
		var corner := corners[i]
		var before := corner.move_toward(corners[i - 1], minf(trim, corner.distance_to(corners[i - 1]) * 0.40))
		var after := corner.move_toward(corners[i + 1], minf(trim, corner.distance_to(corners[i + 1]) * 0.40))
		for step in range(7):
			var t := float(step) / 6.0
			points.append(before.lerp(corner, t).lerp(corner.lerp(after, t), t))
	points.append(corners[-1])
	return points
