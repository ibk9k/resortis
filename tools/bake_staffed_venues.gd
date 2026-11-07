extends SceneTree
## Bake the complete occupied facility for each pose. The station's measured
## opening and foreground outlines come from the new painting. Every key uses
## the same unchanged building pixels, root, palette, and measured contacts.
const ROOT := StaffedVenueArt.DIRECTORY
const DENSITY := StaffedVenueArt.DENSITY

func _initialize() -> void:
	_bake.call_deferred()

func _bake() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/workstations.json"))
	if not source is Dictionary:
		push_error("Missing authored workstation measurements.")
		quit(1)
		return
	var baked := {}
	DirAccess.make_dir_recursive_absolute(ROOT + "/frames")
	for kind: String in FacilityStaff.KINDS:
		var data: Dictionary = _bake_one(kind, source[kind])
		if data.is_empty():
			quit(1)
			return
		baked[kind] = data
	var file := FileAccess.open(ROOT + "/baked.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(baked, "	"))
	print("STAFFED_VENUES_BAKED ", baked.size())
	quit()

func _bake_one(kind: String, design: Dictionary) -> Dictionary:
	var master_path := ROOT.path_join("masters/%s.png" % kind)
	var master := Image.load_from_file(ProjectSettings.globalize_path(master_path))
	var poses := Image.load_from_file(ProjectSettings.globalize_path(FacilityStaff.POSE_DIRECTORY.path_join(kind + ".png")))
	if master == null or poses == null or master.detect_alpha() == Image.ALPHA_NONE:
		push_error("Missing transparent building art or staff poses for " + kind)
		return {}
	master.convert(Image.FORMAT_RGBA8)
	poses.convert(Image.FORMAT_RGBA8)
	var crop := _paint_bounds(master)
	var size := ResortCatalog.footprint(kind)
	var registration := _register(master, _points(design.floor), size)
	var origin := registration * Vector2(crop.position)
	var pixels_per_source := registration.x.x * DENSITY
	var base := master.get_region(crop)
	var canvas := Vector2i((Vector2(crop.size) * pixels_per_source).round())
	base.resize(canvas.x, canvas.y, Image.INTERPOLATE_LANCZOS)
	var atlas := Image.create_empty(canvas.x * StaffedVenueArt.COLUMNS, canvas.y * 2, false, Image.FORMAT_RGBA8)
	var allowed := _points(design.get("opening", []), Vector2(crop.position), pixels_per_source)
	var worktop := _points(design.get("worktop", []), Vector2(crop.position), pixels_per_source)
	var foreground := []
	for shape: Array in design.get("foreground", []):
		foreground.append(_points(shape, Vector2(crop.position), pixels_per_source))
	var foot_source := Vector2(design.foot[0], design.foot[1])
	var foot := Vector2i(((foot_source - Vector2(crop.position)) * pixels_per_source).round())
	var tile := FacilityStaff.CANVAS * FacilityStaff.TEXTURE_SCALE
	var staff_size := FacilityStaff.CANVAS * DENSITY
	var staff_origin := foot - Vector2i(FacilityStaff.ROOT * DENSITY)
	if kind == "yoga": _paint_contact_shadow(base, foot)
	var changed := {}
	for key in FacilityStaff.KEY_COUNT:
		var art := base.duplicate() as Image
		var pose := poses.get_region(Rect2i(Vector2i(key * tile.x, 0), tile))
		pose.resize(staff_size.x, staff_size.y, Image.INTERPOLATE_LANCZOS)
		var bounds := pose.get_used_rect()
		var opaque := 0
		var visible := 0
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var color := pose.get_pixel(x, y)
				if color.a < 0.025: continue
				if color.a > 0.25: opaque += 1
				var point := staff_origin + Vector2i(x, y)
				if not Rect2i(Vector2i.ZERO, canvas).has_point(point): continue
				var sample := Vector2(point) + Vector2(0.5, 0.5)
				if not allowed.is_empty() and not Geometry2D.is_point_in_polygon(sample, allowed):
					if worktop.is_empty() or not Geometry2D.is_point_in_polygon(sample, worktop): continue
				if _covered(sample, foreground): continue
				var behind := art.get_pixelv(point)
				art.set_pixelv(point, behind.blend(color))
				if color.a > 0.25: visible += 1
		if visible < 225:
			push_error("%s pose %d has only %d visible pixels at its station" % [kind, key, visible])
			return {}
		if kind == "ice_cream" and (visible < opaque * 0.44 or visible > opaque * 0.78):
			push_error("Ice cream vendor pose %d has %d/%d visible pixels. Check the waist-high counter and serving clearance." % [key, visible, opaque])
			return {}
		changed[hash(art.get_data())] = true
		var at := Vector2i(key % StaffedVenueArt.COLUMNS, key / StaffedVenueArt.COLUMNS) * canvas
		atlas.blit_rect(art, Rect2i(Vector2i.ZERO, canvas), at)
	if changed.size() != FacilityStaff.KEY_COUNT:
		push_error("Pose keys became identical behind the workstation: " + kind)
		return {}
	if atlas.save_png(ROOT.path_join("frames/%s.png" % kind)) != OK: return {}
	var fixtures := []
	for point in _points(design.get("fixtures", [])):
		var world := registration * point
		fixtures.append([world.x, world.y])
	var floor_points := []
	for point in _points(design.floor):
		var world := registration * point
		floor_points.append([world.x, world.y])
	var effects := {}
	for name: String in design.get("effects", {}):
		var point: Array = design.effects[name]
		var world := registration * Vector2(point[0], point[1])
		effects[name] = [world.x, world.y]
	return {"origin": [origin.x, origin.y], "canvas": [canvas.x, canvas.y],
		"floor": floor_points, "fixtures": fixtures, "effects": effects, "master_sha256": FileAccess.get_sha256(master_path)}

func _covered(point: Vector2, outlines: Array) -> bool:
	for outline: PackedVector2Array in outlines:
		if Geometry2D.is_point_in_polygon(point, outline): return true
	return false

func _paint_bounds(image: Image) -> Rect2i:
	var first := image.get_size()
	var last := Vector2i.ZERO
	var used := image.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a < 0.085: continue
			first = first.min(Vector2i(x, y))
			last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE).grow(3).intersection(Rect2i(Vector2i.ZERO, image.get_size()))

func _paint_contact_shadow(art: Image, foot: Vector2i) -> void:
	var radius := Vector2i(15, 3) * DENSITY
	for y in range(-radius.y, radius.y + 1):
		for x in range(-radius.x, radius.x + 1):
			var weight := 1.0 - Vector2(float(x) / radius.x, float(y) / radius.y).length_squared()
			if weight <= 0.0: continue
			var sample := foot + Vector2i(x, y)
			if not Rect2i(Vector2i.ZERO, art.get_size()).has_point(sample): continue
			var pixel := art.get_pixelv(sample)
			if pixel.a > 0.95: art.set_pixelv(sample, pixel.blend(Color(0.25, 0.13, 0.06, weight * 0.29)))

func _points(list: Array, offset := Vector2.ZERO, scale_factor := 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Array in list:
		points.append((Vector2(point[0], point[1]) - offset) * scale_factor)
	return points

func _register(image: Image, floor: PackedVector2Array, size: Vector2i) -> Transform2D:
	var bounds := Rect2(IsometricGrid.unproject(floor[0]), Vector2.ZERO)
	for point in floor:
		bounds = bounds.expand(IsometricGrid.unproject(point))
	var factor := minf(size.x / bounds.size.x, size.y / bounds.size.y) * 0.94
	var center := IsometricGrid.project(bounds.get_center())
	var used := image.get_used_rect()
	# Fit the complete opaque structure into the same reserved volume as the
	# original. Height is free and the building stays uniformly scaled.
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a < 0.18: continue
			var delta := Vector2(x + 0.5, y + 0.5) - center
			var point := IsometricGrid.unproject(delta)
			if point.x > 0.0: factor = minf(factor, size.x * 0.48 / point.x)
			if point.y > 0.0: factor = minf(factor, size.y * 0.48 / point.y)
			if absf(delta.x) > 0.0: factor = minf(factor, (size.x + size.y) * 15.4 / absf(delta.x))
	var origin := GroundRegistration.sort_offset(size) - center * factor
	return Transform2D(Vector2(factor, 0.0), Vector2(0.0, factor), origin)
