extends RefCounted
## Staff-only illustrated source registration. Whole paintings, uniform scaling,
## translation and authored facing mirrors; no skeleton or limb deformation.
const ROOT := Vector2(128, 220)
const CANVAS := Vector2i(256, 256)
const HEIGHT := 200.0
const SCALE := 49.0 / HEIGHT
const DIRS := {"s": [0, false], "se": [1, false], "e": [2, false], "ne": [3, false], "n": [4, false], "nw": [3, true], "w": [2, true], "sw": [1, true]}
const SOURCES := {"walk": "res://assets/staff/masters/janitor-walk-v2.png", "clean": "res://assets/staff/masters/janitor-clean-v1.png"}
const OUTPUT := "res://assets/staff/illustrated/"
const REGISTRATION := "res://assets/staff/registration.json"
static var _images: Dictionary = {}
static var _regions: Dictionary = {}
static var _scales: Dictionary = {}
static var _paintings: Dictionary = {}

static func source(kind: String) -> Image:
	if not _images.has(kind): _images[kind] = Image.load_from_file(ProjectSettings.globalize_path(SOURCES[kind]))
	return _images[kind]

static func regions(kind: String) -> Array[Rect2i]:
	if _regions.has(kind): return _regions[kind]
	var sheet := source(kind)
	var columns := 8 if kind == "walk" else 4
	var bodies := AlphaRegions.components(sheet)
	assert(bodies.size() == columns * 5, "Staff sheet needs complete separated figures: %s (%d found)" % [kind, bodies.size()])
	bodies.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().y < b.get_center().y)
	var result: Array[Rect2i] = []
	for row in 5:
		var group: Array[Rect2i] = bodies.slice(row * columns, row * columns + columns)
		group.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().x < b.get_center().x)
		for region in group: result.append(region.intersection(Rect2i(Vector2i.ZERO, sheet.get_size())))
	_regions[kind] = result
	return result

static func painting(kind: String, row: int, column: int) -> Image:
	var key := "%s/%d/%d" % [kind, row, column]
	if _paintings.has(key): return _paintings[key]
	var image := source(kind).get_region(regions(kind)[row * (8 if kind == "walk" else 4) + column])
	# Some neighboring broom tips enter the rectangular padding around another
	# row. Extract the complete connected painting, retaining a two-pixel AA
	# guard from the original. Never carry a neighboring character into a frame.
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var largest := PackedInt32Array()
	for y in height:
		for x in width:
			var start := y * width + x
			if visited[start] or image.get_pixel(x, y).a < 0.20: continue
			var queue := PackedInt32Array([start])
			visited[start] = 1
			var head := 0
			while head < queue.size():
				var current := queue[head]
				head += 1
				var pixel := Vector2i(current % width, current / width)
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = pixel + offset
					if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height: continue
					var index := next.y * width + next.x
					if not visited[index] and image.get_pixelv(next).a >= 0.20:
						visited[index] = 1
						queue.append(index)
			if queue.size() > largest.size(): largest = queue
	var guard := PackedByteArray()
	guard.resize(width * height)
	for index in largest:
		var pixel := Vector2i(index % width, index / width)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var next := pixel + Vector2i(dx, dy)
				if next.x >= 0 and next.y >= 0 and next.x < width and next.y < height: guard[next.y * width + next.x] = 1
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			if guard[y * width + x]: result.set_pixel(x, y, image.get_pixel(x, y))
	_paintings[key] = result
	return result

static func anchor(image: Image) -> Vector2:
	var used := image.get_used_rect()
	var head := Rect2i()
	for y in range(used.position.y, used.position.y + roundi(used.size.y * 0.28)):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a > 0.6: head = head.expand(Vector2i(x, y)) if head.has_area() else Rect2i(x, y, 1, 1)
	# The dark brown shoe soles set the ground root, not the broom bristles.
	var feet_y := -1
	for y in range(used.position.y + roundi(used.size.y * 0.70), used.end.y):
		for x in range(used.position.x, used.end.x):
			var c := image.get_pixel(x, y)
			if not _shoe_color(c): continue
			# Broom outlines share the shoe's brown, but are thin. Require a
			# filled patch above the candidate sole so sweeping does not anchor
			# the character to the moving broom and lift both boots off ground.
			var filled := 0
			for dy in range(-4,1):
				for dx in range(-2,3):
					var point := Vector2i(x+dx,y+dy)
					if Rect2i(Vector2i.ZERO,image.get_size()).has_point(point) and _shoe_color(image.get_pixelv(point)): filled+=1
			if filled>=18: feet_y = maxi(feet_y, y)
	assert(feet_y > used.position.y, "Staff shoes must provide a measurable ground anchor")
	return Vector2(head.get_center().x, feet_y + 1)

static func _shoe_color(c: Color) -> bool:
	return c.a>0.6 and c.r<0.42 and c.r>c.g*1.12 and c.g>c.b*1.10

static func row_scale(kind: String, row: int) -> float:
	var key := "%s/%d" % [kind, row]
	if not _scales.has(key):
		var heights: Array[float] = []
		for column in (8 if kind == "walk" else 4):
			var image := painting(kind, row, column)
			heights.append(anchor(image).y - image.get_used_rect().position.y)
		heights.sort()
		_scales[key] = HEIGHT / heights[heights.size() / 2]
	return _scales[key]

static func metadata() -> Dictionary:
	var rows: Dictionary = {}
	for kind: String in SOURCES:
		rows[kind] = []
		for region in regions(kind): rows[kind].append([region.position.x, region.position.y, region.size.x, region.size.y])
	var hashes: Dictionary = {}
	for path: String in SOURCES.values(): hashes[path] = FileAccess.get_sha256(path)
	for path in ["res://assets/staff/janitor_art.gd", "res://assets/staff/janitor_skin.gd"]: hashes[path] = FileAccess.get_sha256(path)
	return {"version": 1, "sources": hashes, "regions": rows, "root": [ROOT.x, ROOT.y], "canvas": [CANVAS.x, CANVAS.y],
		"runtime_scale": SCALE, "walk_keys": 8, "phase_slots": 16, "clean_keys": 4, "clean_period": 1.2, "facings": DIRS.keys()}

static func load_frames() -> SpriteFrames:
	if not FileAccess.file_exists(REGISTRATION):
		push_error("Janitor art must be baked/imported by the coordinator: tools/bake_staff.gd -- --bake")
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRATION))
	if not data is Dictionary or data.get("version") != 1 or not data.get("sources") is Dictionary: return null
	for path: String in data.sources:
		if FileAccess.get_sha256(path) != data.sources[path]:
			push_error("Janitor paintings/registration are stale: " + path)
			return null
	var result := SpriteFrames.new()
	result.remove_animation("default")
	for facing: String in DIRS:
		for kind in ["walk", "idle", "clean"]:
			var animation := "%s_%s" % [kind, facing]
			result.add_animation(animation)
			for index in (16 if kind == "walk" else (4 if kind == "clean" else 1)):
				var suffix := "idle" if kind == "idle" else "%02d" % index
				var path := OUTPUT.path_join("%s-%s-%s.png" % [kind, facing, suffix])
				if not ResourceLoader.exists(path):
					push_error("Missing isolated staff frame. Bake and import staff art: " + path)
					return null
				var texture := load(path) as Texture2D
				if texture == null:
					push_error("Import the baked janitor PNG before starting the world: " + path)
					return null
				var image := texture.get_image()
				image.generate_mipmaps()
				result.add_frame(animation, ImageTexture.create_from_image(image))
	return result
