extends SceneTree
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var only_volleyball := "--volleyball-only" in OS.get_cmdline_user_args()
	var contacts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/illustrated-guests.json")).contacts if only_volleyball else {}
	for variant: String in ["female","male"]:
		if only_volleyball: continue
		var folder := "res://assets/characters/illustrated/%s/walk" % variant
		DirAccess.make_dir_recursive_absolute(folder)
		for facing: String in HolidayGuestModel.DIRECTIONS:
			var skin := IllustratedGuestSkin.new()
			skin.configure(variant,facing)
			viewport.add_child(skin)
			for index in 17:
				skin.pose(float(index)/16,index<16)
				await process_frame
				await RenderingServer.frame_post_draw
				var suffix := "%02d" % index if index<16 else "idle"
				viewport.get_texture().get_image().save_png(folder.path_join("%s_%s.png" % [facing,suffix]))
			print("ILLUSTRATED_WALK ",variant," ",facing)
			skin.free()
	viewport.size = GuestActivityPose.CANVAS
	for variant: String in ["female","male"]:
		var folder := "res://assets/characters/illustrated/%s/activities" % variant
		DirAccess.make_dir_recursive_absolute(folder)
		if not only_volleyball: contacts[variant]={}
		for activity: String in GuestActivityPose.FRAMES:
			if only_volleyball and activity!="volleyball": continue
			contacts[variant][activity]={}
			for facing: String in IllustratedGuestSkin.FACINGS[activity]:
				var skin := IllustratedGuestSkin.new()
				skin.configure(variant,facing,activity)
				if activity=="volleyball" and skin.frames.size()!=6:
					push_error("Complete volleyball drawings are unavailable; refusing an empty bake")
					quit(1)
					return
				viewport.add_child(skin)
				var hand_points: Array = []
				for index in int(GuestActivityPose.FRAMES[activity]):
					skin.pose(float(index)/GuestActivityPose.FRAMES[activity],false)
					hand_points.append([skin.contact.x,skin.contact.y])
					await process_frame
					await RenderingServer.frame_post_draw
					viewport.get_texture().get_image().save_png(folder.path_join("%s-%s-%02d.png" % [activity,facing,index]))
				contacts[variant][activity][facing]=hand_points
				skin.free()
			print("ILLUSTRATED_ACTIVITY ",variant," ",activity)
	var sources: Dictionary = {}
	for path in ["res://scripts/actors/illustrated_guest_skin.gd","res://scripts/actors/holiday_guest_model.gd","res://scripts/actors/guest_activity_pose.gd"]:
		sources[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/actors/volleyball_hit_art.gd","res://assets/characters/illustrated-masters/guest-volleyball-v2.png"]:
		sources[path]=FileAccess.get_sha256(path)
	for file in ["guest-pair-v1.png","female-turnaround-v1.png","male-turnaround-v1.png","guest-activities-v1.png","female-walk-v3.png","male-walk-v3.png"]:
		var path: String = "res://assets/characters/illustrated-masters/"+file
		sources[path]=FileAccess.get_sha256(path)
	var file := FileAccess.open("res://assets/registration/illustrated-guests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"sources":sources,"facings":IllustratedGuestSkin.FACINGS,"contacts":contacts},"\t"))
	file.close()
	print("ILLUSTRATED_GUESTS_BAKED")
	quit()
