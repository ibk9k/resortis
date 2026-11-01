class_name VolleyBallView
extends Node2D
var elevation := 0.0
var spin := 0.0
var shadow: Node2D
var ball_offset := Vector2.ZERO
var contacts: Dictionary = {}
func present(stay: GuestStay) -> void:
	visible = stay.state == "playing_volleyball" and stay.party_size == 2
	if not visible: return
	present_rally(stay.activity_slot(0),stay.activity_slot(1),stay.activity_elapsed)

func present_rally(left_slot: Dictionary, right_slot: Dictionary, elapsed: float, left_variant: String="female", right_variant: String="male") -> void:
	visible=true
	if contacts.is_empty():
		contacts=JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/illustrated-guests.json")).contacts
	var left: Vector2 = left_slot.position
	var right: Vector2 = right_slot.position
	var phase := fposmod(elapsed/2.0,2.0)
	var flight := phase if phase < 1 else 2-phase
	position = IsometricGrid.project(left.lerp(right,flight))
	var a: Array=contacts[left_variant].volleyball[left_slot.facing][0]
	var b: Array=contacts[right_variant].volleyball[right_slot.facing][0]
	var start := IsometricGrid.project(left)+(Vector2(a[0],a[1])-GuestActivityPose.ROOT)*ResortAssets.GUEST_SCALE
	var end := IsometricGrid.project(right)+(Vector2(b[0],b[1])-GuestActivityPose.ROOT)*ResortAssets.GUEST_SCALE
	ball_offset=start.lerp(end,flight)-position+Vector2(0,-sin(flight*PI)*60.0)
	spin = elapsed*4
	queue_redraw()
func _draw() -> void:
	_shadow_ellipse(Vector2.ZERO,Vector2(5,2),Color(0,0,0,0.17))
	var center := ball_offset
	draw_circle(center,4.8,Color("634e35"))
	draw_circle(center+Vector2(-0.4,-0.5),4.1,Color("fff0ca"))
	draw_arc(center,3.2,spin,spin+2.3,12,Color("348fc3"),2)
	draw_arc(center,2.1,spin+2.7,spin+4.7,10,Color("efbf4a"),2)
	draw_circle(center+Vector2(-1.3,-2),1,Color.WHITE)
func _shadow_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24: points.append(center+Vector2(cos(index*TAU/24)*radius.x,sin(index*TAU/24)*radius.y))
	draw_colored_polygon(points,color)
