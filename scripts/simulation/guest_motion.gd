class_name GuestMotion
extends RefCounted
var position := Vector2(ResortLayout.ARRIVAL + Vector2i(1,0))
var distance := 0.0
var direction := Vector2(1,0)
var moving := false
var route: Array[Vector2] = []
var index := 0
var delay := 0.0
func set_route(points: Array[Vector2]) -> void:
	route = points.duplicate()
	index = 0
	delay = 0.6
func finished() -> bool: return index >= route.size() and delay <= 0
func advance(delta: float) -> void:
	moving = false
	if delay > 0:
		var step := minf(delta,delay)
		delta -= step
		delay -= step
	var remaining := delta*1.2
	while remaining > 0.000001 and index < route.size():
		var offset := route[index]-position
		var length := offset.length()
		if length < 0.000001:
			index += 1
			continue
		direction = offset/length
		var step := minf(remaining,length)
		position += direction*step
		distance += step
		remaining -= step
		moving = true
		if step >= length-0.000001: index += 1
func capture() -> Dictionary:
	var points: Array = []
	for point in route: points.append([point.x,point.y])
	return {"position":[position.x,position.y],"distance":distance,"direction":[direction.x,direction.y],"route":points,"index":index,"delay":delay}
func restore(data: Dictionary) -> bool:
	for key in ["position","direction"]:
		if not data.get(key) is Array or data[key].size()!=2: return false
		for n in data[key]:
			if not (n is float or n is int) or not is_finite(float(n)): return false
	if not data.get("route") is Array or not (data.get("index") is int or data.get("index") is float): return false
	if data.index < 0 or data.index > data.route.size() or data.index != int(data.index): return false
	if not (data.get("distance") is float or data.get("distance") is int) or not is_finite(float(data.distance)) or data.distance < 0: return false
	var points: Array[Vector2] = []
	for point in data.route:
		if not point is Array or point.size()!=2: return false
		for n in point:
			if not (n is float or n is int) or not is_finite(float(n)): return false
		points.append(Vector2(point[0],point[1]))
		if not ResortLayout.POINT_BOUNDS.has_point(points[-1]): return false
	position = Vector2(data.position[0],data.position[1])
	if not ResortLayout.POINT_BOUNDS.has_point(position): return false
	direction = Vector2(data.direction[0],data.direction[1])
	distance = data.distance
	route = points
	index = int(data.index)
	if not (data.get("delay",0) is int or data.get("delay",0) is float) or not is_finite(float(data.get("delay",0))) or data.get("delay",0)<0: return false
	delay = float(data.get("delay",0))
	return true
