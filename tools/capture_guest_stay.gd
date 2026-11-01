extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
	resort.legacy_stay_fixture=true
	root.add_child(resort)
	await process_frame
	resort.set_process(false)
	var facing := 1 if "--southwest" in OS.get_cmdline_user_args() else 0
	for record in resort.layout.objects:
		if record.kind == "cabin": record.orientation = facing
	resort._refresh_layout()
	resort.stay = GuestStay.new()
	resort.stay.configure(resort.layout, resort.assets)
	for index in 6000:
		resort.stay.advance(0.05)
		if resort.stay.state == "resting": break
	resort._present_stay()
	resort._inspect_guest()
	resort.camera.zoom = Vector2.ONE * 1.8
	resort.camera.position = resort.stay_actor.position + Vector2(90, -30)
	resort.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/guest-check-in-%d.png" % facing)
	# Small contact sheet of approach, interior and departure for visual review.
	var sheet := Image.create(480 * 5, 360, false, Image.FORMAT_RGBA8)
	var cabin := resort.layout.find_object(resort.stay.cabin_id)
	var aisle := CabinInterior.aisle(cabin, resort.assets)
	var points: Array[Vector2] = [cabin.position + Vector2(ResortCatalog.entrance("cabin", facing)), aisle[0], aisle[1], aisle[2], aisle[3]]
	resort.hud.hide()
	var focus := IsometricGrid.project(cabin.position + Vector2(1.5,1.5))
	for index in points.size():
		resort.stay_actor.present(points[index], 0.25 * index, Vector2(-1, -1), false)
		resort.camera.position = focus + Vector2(0,-25)
		resort.camera.zoom = Vector2.ONE * 2.0
		resort.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		sheet.blit_rect(image, Rect2i(Vector2i(image.get_size()/2) - Vector2i(240,180), Vector2i(480,360)), Vector2i(index*480,0))
	sheet.save_png("res://artifacts/guest-entry-sequence-%d.png" % facing)
	print("GUEST_STAY_CAPTURE facing=", facing)
	quit()
