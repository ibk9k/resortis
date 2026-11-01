extends SceneTree
## GPU regression for the reported detached-leg symptom beside sunbeds. A
## legacy-depth control must fail while the corrected ground-depth view passes.
var failures: Array[String] = []
var library: ResortAssets

func _initialize() -> void:
	_run.call_deferred()

func _viewport(point: Vector2, furniture: bool, legacy: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world := Node2D.new()
	world.position = Vector2(180,90)
	world.y_sort_enabled = true
	viewport.add_child(world)
	if furniture:
		var object := PlacedResortObject.new()
		object.configure({"id":1,"kind":"sunbeds","position":Vector2.ZERO,"orientation":0},library)
		if legacy:
			# Preserve visible pixels; change only the depth key back to the old
			# front-corner rule, proving the test detects that exact occlusion bug.
			var old := IsometricGrid.front_anchor(Vector2.ZERO, Vector2i(3,3))
			var shift := old - object.position
			object.position += shift
			for child in object.get_children():
				if child is Sprite2D: child.position -= shift
		world.add_child(object)
	var guest := AnimatedSprite2D.new()
	guest.sprite_frames = library.walk_frames
	guest.animation = "sw"
	guest.frame = 0
	guest.centered = false
	guest.offset = -ResortAssets.GUEST_ROOT
	guest.scale = Vector2.ONE * ResortAssets.GUEST_SCALE
	guest.position = IsometricGrid.project(point)
	world.add_child(guest)
	root.add_child(viewport)
	return viewport

func _run() -> void:
	library = ResortAssets.new()
	var sets: Array = []
	for point in [Vector2(0,3),Vector2(0.5,3),Vector2(1,3),Vector2(2,3),Vector2(3,0),Vector2(3,0.5),Vector2(3,1),Vector2(3,2)]:
		sets.append([_viewport(point,false,false),_viewport(point,true,false),_viewport(point,true,true)])
	for n in 4: await process_frame
	await RenderingServer.frame_post_draw
	var old_hidden := 0
	var new_hidden := 0
	for group in sets:
		var solo: Image = group[0].get_texture().get_image()
		var current: Image = group[1].get_texture().get_image()
		var old: Image = group[2].get_texture().get_image()
		for y in solo.get_height():
			for x in solo.get_width():
				var expected := solo.get_pixel(x,y)
				if expected.a < 0.98: continue
				if _difference(expected,current.get_pixel(x,y)) > 0.04: new_hidden += 1
				if _difference(expected,old.get_pixel(x,y)) > 0.04: old_hidden += 1
	if new_hidden > 0:
		failures.append("Front-of-furniture guests lose %d opaque body pixels" % new_hidden)
	if old_hidden < 5:
		failures.append("Legacy control did not reproduce the clipping symptom")
	# Native rendered evidence from the same setup, no mock screenshots.
	var before: Image = sets[1][2].get_texture().get_image()
	var after: Image = sets[1][1].get_texture().get_image()
	before.save_png("res://artifacts/sunbed-occlusion-before.png")
	after.save_png("res://artifacts/sunbed-occlusion-after.png")
	print("GUEST_OCCLUSION_CHECKS ",JSON.stringify({"legacy_hidden_pixels":old_hidden,"corrected_hidden_pixels":new_hidden,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _difference(a: Color,b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
