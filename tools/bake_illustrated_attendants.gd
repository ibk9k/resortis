extends SceneTree
## Register complete painted frames on the shared foot origin and pack them
## into guarded atlases. No rigging, pose deformation, or project save access.
const MASTER_DIRECTORY := "res://assets/facility-staff/masters"
const TARGET_HEIGHT := {"cafe": 49.0, "ice_cream": 49.0, "restaurant": 51.0,
	"reception": 48.0, "gear": 49.0, "yoga": 49.0}

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	DirAccess.make_dir_recursive_absolute(FacilityStaff.POSE_DIRECTORY)
	var failures: Array[String] = []
	for kind: String in FacilityStaff.KINDS:
		if not _bake_sheet(kind): failures.append(kind)
	print("ILLUSTRATED_ATTENDANTS_BAKED ", FacilityStaff.KINDS.size() - failures.size(), " roles; failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _bake_sheet(kind: String) -> bool:
	var path := "%s/%s.png" % [MASTER_DIRECTORY, kind]
	var source := Image.load_from_file(ProjectSettings.globalize_path(path))
	if source == null or source.is_empty() or source.detect_alpha() == Image.ALPHA_NONE:
		push_error("Expected a transparent painted master: " + path)
		return false
	source.convert(Image.FORMAT_RGBA8)
	var poses := AlphaRegions.components(source, 2200)
	if poses.size() != FacilityStaff.KEY_COUNT:
		push_error("%s needs six separate complete silhouettes; found %d: %s" % [kind, poses.size(), poses])
		return false
	poses.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().y < b.get_center().y)
	var first: Array[Rect2i] = poses.slice(0, 3)
	var second: Array[Rect2i] = poses.slice(3)
	for row in [first, second]:
		row.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().x < b.get_center().x)
	poses = first + second
	var canvas := FacilityStaff.CANVAS * FacilityStaff.TEXTURE_SCALE
	var atlas := Image.create_empty(canvas.x * poses.size(), canvas.y, false, Image.FORMAT_RGBA8)
	for index in poses.size():
		var rect := poses[index].intersection(Rect2i(Vector2i.ZERO, source.get_size()))
		var frame := source.get_region(rect)
		# The second transition drawing raises the same arm as the first.
		# Mirror that complete painting to lead into the opposite-side stretch.
		if kind == "yoga" and index == 4: frame.flip_x()
		var bounds := frame.get_used_rect()
		var foot := _foot_center(frame, bounds)
		var reference_height := float(poses[0].size.y - 4) if kind == "yoga" else float(bounds.size.y)
		var scale_factor := float(TARGET_HEIGHT[kind]) * FacilityStaff.TEXTURE_SCALE / reference_height
		var resized := Vector2i((Vector2(frame.get_size()) * scale_factor).round())
		frame.resize(resized.x, resized.y, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((FacilityStaff.ROOT * FacilityStaff.TEXTURE_SCALE - foot * scale_factor).round())
		var guard := Rect2i(Vector2i(2, 2), canvas - Vector2i(4, 4))
		if not guard.encloses(Rect2i(at, resized)):
			push_error("Insufficient frame margin for %s key %d: %s" % [kind, index, Rect2i(at, resized)])
			return false
		atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, resized), at + Vector2i(index * canvas.x, 0))
	var result := atlas.save_png("%s/%s.png" % [FacilityStaff.POSE_DIRECTORY, kind])
	return result == OK

func _foot_center(frame: Image, bounds: Rect2i) -> Vector2:
	var min_x := bounds.end.x
	var max_x := bounds.position.x
	var y_floor := bounds.end.y
	var band := maxi(2, roundi(bounds.size.y * 0.075))
	for y in range(y_floor - band, y_floor):
		for x in range(bounds.position.x, bounds.end.x):
			if frame.get_pixel(x, y).a < 0.3: continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
	return Vector2((min_x + max_x) * 0.5, y_floor - 1)
