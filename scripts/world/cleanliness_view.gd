class_name CleanlinessView
extends Node2D
## Pure presentation: logical ground roots share the world's Y-sort traversal.
const Art = preload("res://assets/staff/janitor_art.gd")
# One cycle is two painted steps. Staff have a longer cadence than guests.
const WALK_CYCLE_DISTANCE := 0.78
var system: RefCounted
var library: ResortAssets
var staff_nodes: Dictionary = {}
var mess_nodes: Dictionary = {}
var _frames: SpriteFrames
var _attempted_frames := false

class MessMark extends Node2D:
	var kind := "litter"
	var style := 0
	func _draw() -> void:
		if kind == "spill":
			var shape := PackedVector2Array([Vector2(-7, 0), Vector2(-4, -3), Vector2(1, -3.4), Vector2(5, -1.6), Vector2(8, 0), Vector2(4, 2.6), Vector2(-2, 3)])
			draw_colored_polygon(shape, Color(0.29, 0.17, 0.09, 0.56))
			draw_arc(Vector2(-1, -0.3), 3.2, 3.4, 5.3, 8, Color(0.83, 0.65, 0.37, 0.55), 0.7, true)
			draw_circle(Vector2(8, 3), 1.2, Color(0.29, 0.17, 0.09, 0.4))
		else:
			var offset := float(style % 3) - 1.0
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -2), Vector2(-1, -4), Vector2(3, -1), Vector2(-1, 1)]), Color(0.96, 0.90, 0.69))
			draw_line(Vector2(-3, -1), Vector2(0, -2), Color(0.55, 0.52, 0.32), 0.6, true)
			draw_colored_polygon(PackedVector2Array([Vector2(2 + offset, 0), Vector2(6 + offset, -1), Vector2(5 + offset, 3), Vector2(3 + offset, 3)]), Color(0.76, 0.34, 0.17))
			draw_line(Vector2(2 + offset, 0), Vector2(6 + offset, -1), Color(1, 0.91, 0.70), 1.0, true)

func configure(model: RefCounted, assets: ResortAssets) -> void:
	system = model
	library = assets
	y_sort_enabled = true
	refresh()

func refresh() -> void:
	if system == null: return
	var view: Dictionary = system.call("inspect")
	var dirt_ids: Dictionary = {}
	for dirt: Dictionary in view.get("mess", []):
		var id := int(dirt.id)
		dirt_ids[id] = true
		if not mess_nodes.has(id):
			var mark := MessMark.new()
			mark.name = "Mess_%d" % id
			mark.kind = dirt.kind
			mark.style = int(dirt.get("style", 0))
			mark.z_index = -1
			add_child(mark)
			mess_nodes[id] = mark
		mess_nodes[id].position = IsometricGrid.project(dirt.position)
	for id: int in mess_nodes.keys():
		if not dirt_ids.has(id):
			mess_nodes[id].free()
			mess_nodes.erase(id)
	if not view.get("staff", []).is_empty() and not _attempted_frames:
		_frames = Art.load_frames()
		_attempted_frames = true
	var staff_ids: Dictionary = {}
	for cleaner: Dictionary in view.get("staff", []):
		var id := int(cleaner.id)
		staff_ids[id] = true
		if _frames == null: continue
		if not staff_nodes.has(id):
			var actor := Node2D.new()
			actor.name = "Janitor_%d_%s" % [id, cleaner.name]
			var sprite := AnimatedSprite2D.new()
			sprite.name = "IllustratedStaff"
			sprite.sprite_frames = _frames
			sprite.centered = false
			sprite.offset = -Art.ROOT
			sprite.scale = Vector2.ONE * Art.SCALE
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			actor.add_child(sprite)
			add_child(actor)
			staff_nodes[id] = actor
		var actor: Node2D = staff_nodes[id]
		actor.position = IsometricGrid.project(cleaner.position)
		var sprite: AnimatedSprite2D = actor.get_child(0)
		var facing := ResortWalker.facing_for(IsometricGrid.project(cleaner.direction))
		var kind := "clean" if cleaner.state == "cleaning" else ("walk" if cleaner.state in ["walking", "returning"] else "idle")
		sprite.animation = "%s_%s" % [kind, facing]
		sprite.pause()
		if kind == "walk":
			var phase := fposmod(float(cleaner.distance) / WALK_CYCLE_DISTANCE, 1.0)
			sprite.set_frame_and_progress(floori(phase * 16), 0.0)
		elif kind == "clean": sprite.set_frame_and_progress(floori(fposmod(float(cleaner.activity_elapsed) / 1.2, 1.0) * 4), 0.0)
		else: sprite.set_frame_and_progress(0, 0.0)
	for id: int in staff_nodes.keys():
		if not staff_ids.has(id):
			staff_nodes[id].free()
			staff_nodes.erase(id)
