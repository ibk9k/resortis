class_name StaffedVenueArt
extends RefCounted
## Baked whole-facility keys. The originals stay available for old logical
## activity coordinates so a save in the middle of a visit still loads.
const DIRECTORY := "res://assets/staffed-venues"
const DENSITY := 2
const COLUMNS := 3
static var _records: Dictionary = {}
static var _animations: Dictionary = {}

static func record(kind: String) -> Dictionary:
	if _records.is_empty():
		_records = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "/baked.json"))
	return _records[kind]

static func origin(kind: String) -> Vector2:
	var point: Array = record(kind).origin
	return Vector2(point[0], point[1])

static func frames(kind: String) -> SpriteFrames:
	if _animations.has(kind): return _animations[kind]
	var texture := load(DIRECTORY.path_join("frames/%s.png" % kind)) as Texture2D
	assert(texture != null, "Bake and import the complete staffed venue: " + kind)
	var shape: Array = record(kind).canvas
	var size := Vector2i(int(shape[0]), int(shape[1]))
	var animation := SpriteFrames.new()
	animation.remove_animation("default")
	animation.add_animation("work")
	animation.set_animation_speed("work", 1.0)
	for entry: Array in FacilityStaff.SEQUENCES[kind]:
		var index := int(entry[0])
		var key := AtlasTexture.new()
		key.atlas = texture
		key.region = Rect2(Vector2(Vector2i(index % COLUMNS, index / COLUMNS) * size), Vector2(size))
		key.filter_clip = true
		animation.add_frame("work", key, float(entry[1]))
	_animations[kind] = animation
	return animation

static func fixture(kind: String, role: int) -> Vector2:
	var contacts: Array = record(kind).get("fixtures", [])
	if role >= contacts.size(): return Vector2.INF
	return Vector2(contacts[role][0], contacts[role][1])

static func point(kind: String, name: String) -> Vector2:
	var value: Array = record(kind).get("effects", {}).get(name, [])
	return Vector2.INF if value.is_empty() else Vector2(value[0], value[1])
