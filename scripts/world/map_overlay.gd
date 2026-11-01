class_name MapOverlay
extends Node2D

var footprint := PackedVector2Array()
var valid := true
var entrance := Vector2(INF, INF)
var selected := PackedVector2Array()

func _draw() -> void:
	if selected.size() > 0:
		var outline := selected.duplicate()
		outline.append(outline[0])
		draw_colored_polygon(selected, Color(0.98, 0.83, 0.45, 0.10))
		draw_polyline(outline, Color("edbd68"), 2.0, true)
	if footprint.size() > 0:
		var color := Color("8cdbb0") if valid else Color("f28c77")
		draw_colored_polygon(footprint, Color(color, 0.24))
		var outline := footprint.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, color, 2.0, true)
		if is_finite(entrance.x):
			draw_circle(entrance, 5.0, color)
			draw_arc(entrance, 9.0, 0, TAU, 24, Color(color, 0.5), 1.0, true)
