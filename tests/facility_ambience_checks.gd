extends SceneTree
## Real packed assets and a fresh starter. Use --capture-ambience with a GPU
## to review environmental effects at several points in their loops.

const WORLD = preload("res://scenes/world/coastal_resort.tscn")
const REVIEW_KINDS := ["cafe", "ice_cream", "restaurant", "reception", "pool", "gear", "gym", "sauna", "yoga"]
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--fresh" not in OS.get_cmdline_user_args():
		push_error("Pass --fresh to isolate the ambience test from player saves.")
		quit(2)
		return
	for kind: String in FacilityAmbience.KINDS:
		var count: int = ResortCatalog.definition(kind).frames.size()
		for facing in count:
			var label := kind if count == 1 else "%s_%d" % [kind, facing]
			var packed := load("res://scenes/assets/%s.tscn" % label) as PackedScene
			var asset := packed.instantiate() as PlacedResortObject
			root.add_child(asset)
			var effect := asset.get_node_or_null("Ambience") as FacilityAmbience
			expect(effect != null and effect.facility_kind == kind and effect.automatic_clock, "Packed loop: " + label)
			var venue := effect.get_node_or_null("OccupiedVenue") as AnimatedSprite2D if effect != null else null
			expect((venue != null) == (kind in FacilityStaff.KINDS), "Only staffed venues have a complete occupied loop: " + label)
			if venue != null:
				expect(not asset.get_node("Art").visible and venue.get_parent() == effect, "The complete animation is the visible building: " + label)
				var attendant := venue
				var before := attendant.frame
				effect.present(1.1)
				expect(attendant.frame != before, "Staff work without an admitted guest: " + label)
				var frames := attendant.sprite_frames
				var keys := {}
				for index in frames.get_frame_count("work"):
					var pose := frames.get_frame_texture("work", index) as AtlasTexture
					keys[pose.region.position] = true
				expect(keys.size() == FacilityStaff.KEY_COUNT, "Each staffed venue includes all painted keys: " + label)
			if effect != null and kind == "pool":
				expect(effect.get_node_or_null("Surface") != null and effect.get_node_or_null("Waterfall") != null, "Pool has separate masked surface and waterfall")
				var another := packed.instantiate()
				root.add_child(another)
				expect(effect.get_node("Surface").material != another.get_node("Ambience/Surface").material, "Packed pools own separate clock uniforms")
				another.free()
			asset.free()
	var resort := WORLD.instantiate() as CoastalResort
	root.add_child(resort)
	resort.set_process(false)
	var effects := resort.facility_ambience
	expect(effects.size() >= FacilityAmbience.KINDS.size(), "Fresh world builds the effects")
	expect(effects.all(func(effect: FacilityAmbience) -> bool: return not effect.is_processing()), "World uses only the resort clock")
	var pool: FacilityAmbience
	for effect in effects:
		if effect.facility_kind == "pool": pool = effect; break
	expect(pool != null, "Pool is present in the starter")
	if pool != null:
		var before := pool.elapsed
		resort._process(0.1)
		expect(is_equal_approx(pool.elapsed, before + 0.1), "1x clock drives ambient motion")
		resort.paused = true
		resort._process(0.1)
		expect(is_equal_approx(pool.elapsed, before + 0.1), "Pause freezes ambient motion")
		resort.paused = false
		resort.scene_speed = 4.0
		resort._process(0.1)
		expect(is_equal_approx(pool.elapsed, before + 0.5), "4x clock drives the same loop")
	if "--capture-ambience" in OS.get_cmdline_user_args():
		await _capture(resort)
	if "--capture-staff" in OS.get_cmdline_user_args():
		await _capture(resort, true)
	print("FACILITY_AMBIENCE_CHECKS %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _capture(resort: CoastalResort, staff := false) -> void:
	resort.hud.hide()
	# The clock is advanced by the fixture with only arriving guests, so the
	# rendered loops are proven independently of any admission.
	var tile := Vector2i(480, 300)
	var kinds := FacilityStaff.KINDS if staff else REVIEW_KINDS
	var rows := ceili(kinds.size() / 3.0)
	var frames: Array[Image] = []
	var frame_count := 30 if staff else 18
	for frame in frame_count:
		frames.append(Image.create_empty(tile.x * 3, tile.y * rows, false, Image.FORMAT_RGBA8))
	for index in kinds.size():
		var kind: String = kinds[index]
		var object: PlacedResortObject
		for candidate in resort.placed:
			if candidate.kind == kind: object = candidate; break
		if object == null:
			expect(false, "Missing review object " + kind)
			continue
		var bounds := object.sprite.get_global_transform() * object.sprite.get_rect()
		resort.camera.position = bounds.get_center()
		var zoom := minf(410.0 / bounds.size.x, 257.0 / bounds.size.y)
		if staff:
			var focus := StaffedVenueArt.point(kind, "focus")
			resort.camera.position = object.ambience.to_global(object.ambience.plot_origin + focus)
			zoom = 1.8
		resort.camera.zoom = Vector2.ONE * zoom
		resort.camera.force_update_scroll()
		var first: Image
		var changed := false
		for frame in frame_count:
			object.ambience.present(0.12 + frame * (0.16 if staff else 0.22))
			await process_frame
			await RenderingServer.frame_post_draw
			var view := root.get_texture().get_image()
			var sample := view.get_region(Rect2i((view.get_size() - tile) / 2, tile))
			if first == null:
				first = sample
			elif first.get_data() != sample.get_data():
				changed = true
			frames[frame].blit_rect(sample, Rect2i(Vector2i.ZERO, tile), tile * Vector2i(index % 3, index / 3))
		expect(changed, "Rendered pixels move at an empty " + kind)
	var folder := "res://artifacts/illustrated-staff-motion" if staff else "res://artifacts/ambience-motion"
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in frames.size():
		frames[frame].save_png(folder.path_join("%02d.png" % frame))
	var still := "illustrated-staff-review.png" if staff else "ambience-facilities.png"
	expect(frames[3].save_png("res://artifacts/" + still) == OK, "Rendered empty-facility review")
