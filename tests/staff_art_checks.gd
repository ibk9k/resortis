extends SceneTree
## Source-only checks need no import/bake. --baked checks coordinator outputs.
const Art = preload("res://assets/staff/janitor_art.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var metadata := Art.metadata()
	expect(metadata.regions.walk.size() == 40 and metadata.regions.clean.size() == 20, "Staff masters contain forty complete walks and twenty complete sweeps")
	for kind: String in Art.SOURCES:
		var source := Art.source(kind)
		expect(source.detect_alpha() != Image.ALPHA_NONE and source.get_pixel(0, 0).a <= 0.01 and source.get_pixel(source.get_width() - 1, source.get_height() - 1).a <= 0.01, "Staff %s master has genuine transparent background" % kind)
		for row in 5:
			var hashes: Dictionary = {}
			var heights: Array[float] = []
			var columns := 8 if kind == "walk" else 4
			for col in columns:
				var image := Art.painting(kind, row, col)
				var anchor := Art.anchor(image)
				var used := image.get_used_rect()
				var components := AlphaRegions.components(image, 100)
				expect(components.size() == 1, "Complete connected %s painting %d/%d includes body and tool" % [kind, row, col])
				expect(anchor.x > 0 and anchor.x < image.get_width() and anchor.y >= used.position.y + used.size.y * 0.75, "Ground anchor follows the shoes in %s %d/%d" % [kind, row, col])
				var rectangle := Rect2(Art.ROOT - anchor * Art.row_scale(kind, row), Vector2(image.get_size()) * Art.row_scale(kind, row))
				expect(Rect2(Vector2(2, 2), Vector2(Art.CANVAS) - Vector2(4, 4)).encloses(rectangle), "Uniformly registered %s painting %d/%d fits guarded canvas" % [kind, row, col])
				hashes[hash(image.get_data())] = true
				heights.append((anchor.y - used.position.y) * Art.row_scale(kind, row))
			expect(hashes.size() >= (7 if kind == "walk" else 3), "Each %s facing has distinct authored complete poses" % kind)
			heights.sort()
			expect(heights[-1] - heights[0] < Art.HEIGHT * 0.08, "Registered %s anatomy has stable body scale across a cycle" % kind)
	if "--baked" in OS.get_cmdline_user_args(): _baked()
	print("STAFF_ART_CHECKS ", checks, " checks; ", failures.size(), " failures; ", "baked outputs" if "--baked" in OS.get_cmdline_user_args() else "source-only; runtime import/render acceptance remains with coordinator")
	quit(0 if failures.is_empty() else 1)

func _baked() -> void:
	var frames := Art.load_frames()
	expect(frames != null, "Current staff registration and all runtime frames load")
	if frames == null: return
	for facing: String in Art.DIRS:
		for kind in ["walk", "idle", "clean"]:
			var animation := "%s_%s" % [kind, facing]
			var count := 16 if kind == "walk" else (4 if kind == "clean" else 1)
			expect(frames.has_animation(animation) and frames.get_frame_count(animation) == count, "Staff runtime has complete " + animation)
			var hashes: Dictionary = {}
			for index in count:
				var image := frames.get_frame_texture(animation, index).get_image()
				expect(image.get_size() == Art.CANVAS, "Runtime staff has common guarded canvas")
				var used := image.get_used_rect()
				expect(used.position.x > 2 and used.position.y > 2 and used.end.x < Art.CANVAS.x - 2 and used.end.y < Art.CANVAS.y - 2, "Runtime staff never clips its guard")
				hashes[hash(image.get_data())] = true
				if kind == "walk" and index % 2 == 1:
					expect(image.get_data() == frames.get_frame_texture(animation, index - 1).get_image().get_data(), "Each authored walking key holds exactly two distance slots")
			if kind == "walk": expect(hashes.size() == 8, "Eight authored keys survive in sixteen runtime slots")
	# Independent pixel-space fixture: these sweeps leave the near boot clear of
	# the broom. A broom-tip anchor lifted it about ten baked pixels above ROOT.
	# Check the rendered boot against the fixed ground contract, not Art.anchor.
	for facing in ["s","e"]:
		for index in [0,2]:
			var image := frames.get_frame_texture("clean_"+facing,index).get_image()
			var sole := -1
			for y in range(int(Art.ROOT.y)-20,int(Art.ROOT.y)+6):
				for x in range(int(Art.ROOT.x)-24,int(Art.ROOT.x)-1):
					if image.get_pixel(x,y).a>0.8: sole=maxi(sole,y)
			expect(absi(sole-int(Art.ROOT.y))<=4,"Sweeping boot stays on the registered ground: %s/%d" % [facing,index])
	for facing in ["s", "n"]:
		var left_contact := _sole_center_x(frames.get_frame_texture("walk_" + facing, 2).get_image())
		var right_contact := _sole_center_x(frames.get_frame_texture("walk_" + facing, 10).get_image())
		expect(left_contact < Art.ROOT.x - 2 and right_contact > Art.ROOT.x + 5,
			"Opposite half-cycles put a different boot on the ground when facing " + facing)

func _sole_center_x(image: Image) -> float:
	var samples: Array[int] = []
	for y in range(int(Art.ROOT.y) - 5, int(Art.ROOT.y) + 1):
		for x in range(56, 200):
			if Art._shoe_color(image.get_pixel(x, y)): samples.append(x)
	if samples.is_empty(): return INF
	samples.sort()
	return float(samples[samples.size() / 2])
