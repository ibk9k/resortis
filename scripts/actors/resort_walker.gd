class_name ResortWalker
extends Node2D
## Shared guest presentation; live movement belongs to GuestMotion. The optional
## autonomous routing methods remain for explicit legacy/art fixtures only.

var actor_id := 0
var logical_position := Vector2.ZERO
var route: Array[Vector2i] = []
var route_index := 0
var speed := 1.1
var wait_time := 0.0
var sprite: AnimatedSprite2D
var graph: AStarGrid2D
var destinations: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()
var walked_distance := 0.0
var facing := "se"
var variant := "female"
var library: ResortAssets
var paddle_hand := Vector2(INF, INF)
var paddle_angle := 0.0
static var _activity_contacts: Dictionary = {}
const STRIDE_DISTANCE := (0.46/0.6)*(220.0*ResortAssets.GUEST_SCALE)/(32.0*sqrt(2.0))

func configure(id: int, start: Vector2i, navigation: AStarGrid2D, targets: Array[Vector2i], assets: ResortAssets) -> void:
	actor_id = id
	library = assets
	name = "HolidayGuest_%02d" % id
	rng.seed = 8147 + id * 7919
	logical_position = Vector2(start)
	graph = navigation
	destinations = targets
	speed = rng.randf_range(0.70, 1.10)
	wait_time = rng.randf_range(0.0, 6.0)
	sprite = AnimatedSprite2D.new()
	sprite.name = "WalkAnimation"
	sprite.sprite_frames = assets.people_frames(variant)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = false
	if assets.walk_frames != null:
		sprite.offset = -ResortAssets.GUEST_ROOT
		sprite.scale = Vector2.ONE * ResortAssets.GUEST_SCALE
		sprite.animation = "se_idle"
	add_child(sprite)
	_update_position()

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	var moving := false
	while remaining > 0.00001:
		if wait_time > 0.0:
			var wait_step := minf(wait_time, remaining)
			wait_time -= wait_step
			remaining -= wait_step
			continue
		if route_index >= route.size():
			_choose_route()
			if route_index >= route.size():
				break
		var target := Vector2(route[route_index])
		var direction := target - logical_position
		var distance := direction.length()
		if distance < 0.00001:
			route_index += 1
			continue
		var step := minf(speed * remaining, distance)
		logical_position += direction / distance * step
		walked_distance += step
		remaining -= step / maxf(speed, 0.0001)
		moving = true
		var projected := IsometricGrid.project(direction)
		facing = facing_for(projected)
		if step >= distance - 0.00001:
			logical_position = target
			route_index += 1
			if route_index == route.size():
				wait_time = rng.randf_range(2.0, 9.0)
	present(logical_position, walked_distance, Vector2.ZERO, moving)

func present(point: Vector2, distance: float, heading: Vector2, moving: bool) -> void:
	if paddle_hand.is_finite():
		paddle_hand = Vector2(INF, INF)
		queue_redraw()
	sprite.sprite_frames = library.people_frames(variant)
	sprite.scale=Vector2.ONE*ResortAssets.GUEST_SCALE
	sprite.offset = -ResortAssets.GUEST_ROOT
	sprite.position = Vector2.ZERO
	logical_position = point
	walked_distance = distance
	if heading.length_squared() > 0.000001:
		facing = facing_for(IsometricGrid.project(heading))
	sprite.pause()
	var phase := fposmod(walked_distance / STRIDE_DISTANCE, 1.0)
	if moving:
		sprite.animation = facing
		sprite.set_frame_and_progress(int(phase * HolidayGuestModel.POSES) % HolidayGuestModel.POSES, fposmod(phase * HolidayGuestModel.POSES, 1.0))
	else:
		sprite.animation = facing+"_idle"
		sprite.set_frame_and_progress(0, 0.0)
	_update_position()

func present_activity(slot: Dictionary, time: float) -> void:
	if slot.pose in ["standing", "treadmill"]:
		var treadmill: bool = slot.pose == "treadmill"
		present(slot.position, time * 1.4, Vector2.UP, treadmill)
		sprite.position = slot.get("render_offset", Vector2(0, slot.offset))
		return
	logical_position = slot.position
	sprite.scale=Vector2.ONE*ResortAssets.GUEST_SCALE
	sprite.sprite_frames = library.activity_frames(variant)
	sprite.offset = -GuestActivityPose.ROOT
	sprite.position = Vector2(0,slot.offset)
	if slot.pose=="sleeping" and slot.has("head_offset"):
		# Register the complete painting by the head resting on its own pillow.
		# Its former guessed hip pivot put the two different bodies off the bed.
		var head := Vector2(194,316) if variant=="female" else Vector2(166,294)
		if slot.facing=="sw": head.x=GuestActivityPose.CANVAS.x-head.x
		sprite.position=slot.head_offset-(head-GuestActivityPose.ROOT)*sprite.scale
	# Fit each complete illustration to its supporting furniture.
	if slot.pose == "lying":
		sprite.scale *= 0.86
		sprite.position += Vector2(4.5, -8.5) if variant == "female" else Vector2(6, -7)
	elif slot.pose == "sleeping":
		sprite.position += Vector2(-2 if slot.facing == "se" else 2, -1)
	elif slot.pose in ["sitting", "eating"] and slot.has("seat_offset"):
		var contact := Vector2(310, 403) if variant == "female" else Vector2(300, 374)
		sprite.position = slot.seat_offset - (contact - GuestActivityPose.ROOT) * sprite.scale
	sprite.pause()
	sprite.animation = slot.pose+"_"+slot.facing
	var period: float = {"sitting":4.0,"eating":1.8,"lying":4.0,"sleeping":6.0,"volleyball":4.0}[slot.pose]
	var count: int = GuestActivityPose.FRAMES[slot.pose]
	var phase := fposmod(time/period,1.0)
	sprite.set_frame_and_progress(int(phase*count),fposmod(phase*count,1.0))
	if slot.get("paddle", false):
		if _activity_contacts.is_empty():
			_activity_contacts = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/illustrated-guests.json")).contacts
		var contact: Array = _activity_contacts[variant].volleyball[slot.facing][sprite.frame]
		paddle_hand = sprite.position + (Vector2(contact[0], contact[1]) - GuestActivityPose.ROOT) * sprite.scale
		paddle_angle = (-0.52 if slot.facing == "se" else PI + 0.52) + sin(phase * TAU) * 0.48
		queue_redraw()
	_update_position()

func _draw() -> void:
	if not paddle_hand.is_finite(): return
	draw_set_transform(paddle_hand, paddle_angle)
	draw_line(Vector2.ZERO, Vector2(6, 0), Color("553b30"), 2.0, true)
	var outline := PackedVector2Array([Vector2(5, -2), Vector2(7, -3.5), Vector2(11, -3.5), Vector2(13, -2), Vector2(13, 2), Vector2(11, 3.5), Vector2(7, 3.5), Vector2(5, 2)])
	draw_colored_polygon(outline, Color("1e4245"))
	draw_rect(Rect2(7, -2, 4.5, 4.0), Color("52b8a9"))

func _choose_route() -> void:
	if destinations.is_empty():
		return
	var start := Vector2i(logical_position.round())
	if not graph.is_in_boundsv(start) or graph.is_point_solid(start):
		wait_time = 1.0
		return
	var destination := destinations[rng.randi_range(0, destinations.size() - 1)]
	route = graph.get_id_path(start, destination)
	route_index = 1
	if route.size() < 2:
		wait_time = 1.0

func refresh_navigation(navigation: AStarGrid2D, targets: Array[Vector2i]) -> void:
	graph = navigation
	destinations = targets
	route.clear()
	route_index = 0
	var point := Vector2i(logical_position.round())
	if graph.is_in_boundsv(point) and not graph.is_point_solid(point):
		return
	# Layout editing can cover a walking guest in this visual proof. Rehome to an
	# accessible tile; the later simulation will arbitrate occupied editing itself.
	var nearest := INF
	for target in destinations:
		var distance := logical_position.distance_squared_to(Vector2(target))
		if distance < nearest:
			nearest = distance
			point = target
	logical_position = Vector2(point)
	_update_position()

func _update_position() -> void:
	position = IsometricGrid.project(logical_position)
	# Resting bodies must sort over the mattress, while the cabin's front edge
	# remains a separately sorted occluder. Preserve their exact drawn position.
	if sprite.animation.begins_with("lying_") or sprite.animation.begins_with("sleeping_"):
		position.y += 18.0
		sprite.position.y -= 18.0

func hit_test(point: Vector2) -> bool:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var pixel := Vector2i((sprite.to_local(point) - sprite.offset).floor())
	var image := texture.get_image()
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a > 0.2

static func facing_for(screen_direction: Vector2) -> String:
	var names := ["e","se","s","sw","w","nw","n","ne"]
	return names[posmod(roundi(screen_direction.angle()/(PI/4.0)),8)]
