class_name ResortAssets
extends RefCounted
## PNG originals stay intact; the game consumes measured AtlasTexture regions.

var atlases: Dictionary = {}
var frames: Dictionary = {}
var walk_frames: SpriteFrames
var source_images: Dictionary = {}
var people: Dictionary = {}
var activities: Dictionary = {}
const GUEST_ROOT := Vector2(192,440)
const GUEST_SCALE := 49.0/400.0

# Alpha component inspection provides measured regions rather than trusting the
# generator to place every object on an exact grid. Original PNGs remain untouched.
const REGIONS := {
	"buildings": [Rect2(44, 71, 455, 421), Rect2(556, 70, 455, 422), Rect2(1062, 59, 438, 450), Rect2(48, 530, 448, 434), Rect2(533, 590, 537, 365), Rect2(1082, 579, 421, 378)],
	"props": [Rect2(61, 70, 361, 505), Rect2(471, 185, 288, 388), Rect2(791, 289, 350, 292), Rect2(1181, 318, 318, 258), Rect2(64, 663, 361, 283), Rect2(559, 624, 140, 309), Rect2(889, 706, 150, 229), Rect2(1157, 751, 331, 189)],
	"beach": [Rect2(22, 263, 764, 497), Rect2(857, 202, 650, 588)]
}

func _init() -> void:
	_load_atlas("buildings", "res://assets/atlases/buildings-v2.png", 3, 2)
	_load_atlas("props", "res://assets/atlases/props-v2.png", 4, 2)
	_load_atlas("beach", "res://assets/atlases/beach-v2.png", 2, 1)
	_load_atlas("pool", "res://assets/atlases/pool-v3.png", 1, 1)
	_build_people()

func _load_atlas(key: String, path: String, cols: int, rows: int) -> void:
	assert(ResourceLoader.exists(path), "Registered source atlas is missing: " + path)
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("Missing atlas: " + path)
		return
	atlases[key] = texture
	var cell := Vector2i(texture.get_size()) / Vector2i(cols, rows)
	var source_image := texture.get_image()
	var textures: Array[AtlasTexture] = []
	for row in rows:
		for col in cols:
			var rectangle := Rect2i(Vector2i(col, row) * cell, cell)
			var image := source_image.get_region(rectangle)
			var used := image.get_used_rect()
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(rectangle.position + used.position, used.size)
			if REGIONS.has(key):
				frame.region = REGIONS[key][row * cols + col]
			frame.filter_clip = true
			textures.append(frame)
	frames[key] = textures

func texture_for(kind: String, orientation: int = 0) -> Texture2D:
	if kind in GroundRegistration.MODELED:
		return load("res://assets/structures/%s-v1.png" % kind) as Texture2D
	var def := ResortCatalog.definition(kind)
	var variants: Array = def.frames
	var available: Array = frames.get(def.atlas, [])
	var index: int = variants[orientation % variants.size()]
	return available[index] if index < available.size() else null

func image_for(kind: String,orientation: int) -> Image:
	var key := "%s/%d"%[kind,orientation]
	if not source_images.has(key): source_images[key] = texture_for(kind,orientation).get_image()
	return source_images[key]

func _build_people() -> void:
	walk_frames = SpriteFrames.new()
	walk_frames.remove_animation("default")
	for animation: String in HolidayGuestModel.DIRECTIONS:
		walk_frames.add_animation(animation)
		walk_frames.set_animation_speed(animation, float(HolidayGuestModel.POSES))
		walk_frames.set_animation_loop(animation, true)
		for index in HolidayGuestModel.POSES:
			var texture := load("res://assets/characters/illustrated/female/walk/%s_%02d.png" % [animation, index]) as Texture2D
			assert(texture != null, "Guest frames must pass import before running the game.")
			walk_frames.add_frame(animation, texture)
		var idle := animation+"_idle"
		walk_frames.add_animation(idle)
		walk_frames.set_animation_loop(idle,false)
		walk_frames.add_frame(idle,load("res://assets/characters/illustrated/female/walk/%s_idle.png" % animation) as Texture2D)
	people["female"] = walk_frames

func people_frames(variant: String) -> SpriteFrames:
	if people.has(variant): return people[variant]
	assert(variant == "male", "Unknown guest identity")
	var result := SpriteFrames.new()
	result.remove_animation("default")
	for facing: String in HolidayGuestModel.DIRECTIONS:
		for idle in [false,true]:
			var animation := facing+"_idle" if idle else facing
			result.add_animation(animation)
			for index in (1 if idle else 16):
				var suffix := "idle" if idle else "%02d" % index
				var path := "res://assets/characters/illustrated/male/walk/%s_%s.png" % [facing,suffix]
				assert(ResourceLoader.exists(path), "Missing male guest frame: "+path)
				result.add_frame(animation,load(path) as Texture2D)
	people[variant] = result
	return result

func activity_frames(variant: String) -> SpriteFrames:
	if activities.has(variant): return activities[variant]
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/illustrated-guests.json"))
	assert(metadata is Dictionary, "Bake guest activity frames before running")
	for path: String in metadata.sources:
		assert(FileAccess.get_sha256(path) == metadata.sources[path], "Activity frames are stale: "+path)
	var result := SpriteFrames.new()
	result.remove_animation("default")
	for pose: String in GuestActivityPose.FRAMES:
		for facing: String in metadata.facings[pose]:
			var animation := pose+"_"+facing
			result.add_animation(animation)
			for index in int(GuestActivityPose.FRAMES[pose]):
				var path := "res://assets/characters/illustrated/%s/activities/%s-%s-%02d.png" % [variant,pose,facing,index]
				assert(ResourceLoader.exists(path), "Missing activity frame: "+path)
				result.add_frame(animation,load(path) as Texture2D)
	activities[variant] = result
	return result
