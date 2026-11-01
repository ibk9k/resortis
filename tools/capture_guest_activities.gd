extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
	resort.legacy_stay_fixture=true
	resort.save_path="res://artifacts/test-activity-capture.json"
	root.add_child(resort)
	await process_frame
	resort.set_process(false)
	resort.stay = GuestStay.new()
	resort.stay.party_size = 2
	resort.stay.configure(resort.layout,resort.assets)
	resort.hud.hide()
	for phase in ["resting","sitting","eating","relaxing","playing_volleyball","overnight"]:
		for step in 14000:
			resort.stay.advance(0.05)
			if resort.stay.state==phase: break
		if resort.stay.state!=phase:
			push_error("Cannot reach activity "+phase+"; state="+resort.stay.state)
			quit(1)
			return
		resort.stay.advance(0.9)
		resort._present_stay()
		resort.camera.position = (resort.stay_actor.position+resort.companion_actor.position)*0.5+Vector2(0,-35)
		resort.camera.zoom = Vector2.ONE*2.6
		resort.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/activity-%s.png" % phase)
		if phase=="playing_volleyball":
			DirAccess.make_dir_recursive_absolute("res://artifacts/activity-preview")
			for frame in 16:
				resort.stay.advance(0.25)
				resort._present_stay()
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/activity-preview/frame-%02d.png" % frame)
		print("ACTIVITY_CAPTURE ",phase)
	for object in resort.placed:
		if object.kind=="hedge":
			resort.camera.position = object.position+Vector2(0,-15)
			break
	resort.camera.zoom = Vector2.ONE*3.0
	resort.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/planter-model-review.png")
	quit()
