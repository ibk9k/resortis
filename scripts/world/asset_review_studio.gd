class_name AssetReviewStudio
extends Node2D
## Deterministic visual gate for the complete catalogue and every guest frame.
@export var walking_frames := false
var library: ResortAssets
var elapsed := 0.0
var floor_nodes: Array[Node2D] = []

class GroundGuide extends Node2D:
	var size := Vector2i.ONE
	var door := Vector2i.ZERO
	var has_door := false
	func _draw() -> void:
		for x in range(-1, size.x + 1):
			for y in range(-1, size.y + 1):
				var polygon := IsometricGrid.footprint_polygon(Vector2(x, y), Vector2i.ONE)
				draw_colored_polygon(polygon, Color("35483f") if (x + y) % 2 == 0 else Color("3b5045"))
				polygon.append(polygon[0])
				draw_polyline(polygon, Color("789383"), 0.75)
		var footprint := IsometricGrid.footprint_polygon(Vector2.ZERO, size)
		footprint.append(footprint[0])
		draw_polyline(footprint, Color("ffe191"), 2.0)
		if has_door:
			draw_circle(IsometricGrid.project(Vector2(door)), 5, Color("a9f8c7"))

func _ready() -> void:
	library = ResortAssets.new()
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1600, 0), Vector2(1600, 1000), Vector2(0, 1000)])
	background.color = Color("102821")
	background.z_index = -100
	add_child(background)
	var title := Label.new()
	title.position = Vector2(28, 15)
	title.add_theme_font_size_override("font_size", 24)
	title.text = "Illustrated guest · eight walk keys over sixteen phase slots" if walking_frames else "Catalogue · full base containment · upright structures"
	add_child(title)
	if walking_frames:
		_build_walks()
	else:
		_build_objects()

func _build_objects() -> void:
	var index := 0
	for kind: String in ResortCatalog.DEFINITIONS:
		var def := ResortCatalog.definition(kind)
		for orientation in def.frames.size():
			var unit := Node2D.new()
			var guide := GroundGuide.new()
			guide.size = ResortCatalog.footprint(kind, orientation)
			guide.has_door = def.get("access", false)
			guide.door = ResortCatalog.entrance(kind, orientation)
			unit.add_child(guide)
			var item := PlacedResortObject.new()
			item.configure({"id":index + 1, "kind":kind, "position":Vector2.ZERO, "orientation":orientation}, library)
			unit.add_child(item)
			var diagnostic := GroundGuide.new()
			diagnostic.size = guide.size
			diagnostic.has_door = guide.has_door
			diagnostic.door = guide.door
			diagnostic.z_index = -1
			unit.add_child(diagnostic)
			var bounds := item.transform * item.sprite.transform * item.sprite.get_rect()
			for x in [-1.5,guide.size.x+0.5]:
				for y in [-1.5,guide.size.y+0.5]:
					bounds = bounds.expand(IsometricGrid.project(Vector2(x,y)))
			var factor := minf(350.0 / maxf(bounds.size.x, 1), 170.0 / maxf(bounds.size.y, 1))
			unit.scale = Vector2.ONE * factor
			unit.position = Vector2((index % 4) * 400 + 200, (index / 4) * 232 + 150) - bounds.get_center() * factor
			add_child(unit)
			var label := Label.new()
			label.position = Vector2((index % 4) * 400 + 18, (index / 4) * 232 + 62)
			label.add_theme_font_size_override("font_size", 17)
			label.text = "%s · view %d · %d × %d" % [def.name, orientation, guide.size.x, guide.size.y]
			add_child(label)
			index += 1

func _build_walks() -> void:
	var directions := HolidayGuestModel.DIRECTIONS
	for row in 8:
		var label := Label.new()
		label.position = Vector2(12, 70 + row * 115)
		label.text = str(directions[row]).to_upper()
		label.add_theme_font_size_override("font_size", 20)
		add_child(label)
		for frame in HolidayGuestModel.POSES:
			var sprite := Sprite2D.new()
			sprite.texture = library.walk_frames.get_frame_texture(directions[row], frame)
			sprite.centered = false
			sprite.offset = -ResortAssets.GUEST_ROOT
			sprite.scale = Vector2.ONE * 0.21
			sprite.position = Vector2(100 + frame * 96, 165 + row * 115)
			add_child(sprite)
			var number := Label.new()
			number.position = sprite.position + Vector2(-4, 5)
			number.text = str(frame + 1)
			add_child(number)
