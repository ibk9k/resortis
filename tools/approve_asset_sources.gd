extends SceneTree
## Run only after inspecting the generated catalogue, animation and game views.
func _initialize() -> void:
	if not "--reviewed" in OS.get_cmdline_user_args():
		push_error("Review rendered evidence before recording source hashes; pass --reviewed after that review.")
		quit(1)
		return
	var sources: Dictionary = {}
	for folder in ["res://assets/atlases","res://assets/characters/frames-v2","res://assets/structures","res://assets/interiors"]:
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".png"):
				var path: String = folder.path_join(name)
				sources[path] = FileAccess.get_sha256(path)
	for direction in ["se","sw","ne","nw"]:
		var path := "res://assets/characters/guest-parts-%s-v1.png" % direction
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/content/ground_registration.gd","res://scripts/content/resort_catalog.gd","res://scripts/content/asset_library.gd","res://scripts/world/isometric_grid.gd","res://scripts/world/placed_object.gd","res://scripts/actors/holiday_guest_model.gd","res://scripts/content/structure_models.gd","res://scripts/content/model_primitives.gd","res://scripts/actors/resort_walker.gd","res://assets/registration/structures.json","res://assets/registration/guest-frames.json"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/actors/guest_appearance.gd","res://tools/bake_guest_walk.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	sources["res://scripts/actors/volleyball_hit_art.gd"]=FileAccess.get_sha256("res://scripts/actors/volleyball_hit_art.gd")
	for folder in ["res://assets/characters/illustrated-masters","res://assets/characters/illustrated/female/walk","res://assets/characters/illustrated/male/walk","res://assets/characters/illustrated/female/activities","res://assets/characters/illustrated/male/activities"]:
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".png"):
				var path: String=folder.path_join(name)
				sources[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/actors/illustrated_guest_skin.gd","res://tools/bake_illustrated_guests.gd","res://assets/registration/illustrated-guests.json","res://scripts/actors/guest_activity_pose.gd","res://scripts/content/guest_activity_slots.gd","res://scripts/simulation/guest_motion.gd","res://scripts/simulation/guest_stay.gd","res://scripts/world/volley_ball_view.gd","res://tools/bake_facility_layers.gd"]:
		sources[path]=FileAccess.get_sha256(path)
	for path in ["res://scripts/content/cabin_interior.gd", "res://assets/registration/cabin-layers.json", "res://scripts/world/coastal_resort.gd", "res://scripts/ui/resort_hud.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for folder in ["res://assets/staff/masters", "res://assets/staff/illustrated"]:
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".png"):
				var path: String = folder.path_join(name)
				sources[path] = FileAccess.get_sha256(path)
	for path in ["res://assets/staff/janitor_art.gd", "res://assets/staff/janitor_skin.gd", "res://assets/staff/registration.json", "res://tools/bake_staff.gd", "res://scripts/world/cleanliness_view.gd", "res://scripts/world/resort_population_view.gd", "res://scripts/ui/resort_management_ui.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for facing in 2:
		for part in 4:
			var path := "res://assets/interiors/cabin-%d-%d.png.import" % [facing,part]
			sources[path] = FileAccess.get_sha256(path)
	var file := FileAccess.open("res://assets/registration/reviewed-sources.json",FileAccess.WRITE)
	var evidence := ["artifacts/catalogue-registered.png","artifacts/guest-frames-registered.png","artifacts/sunbed-occlusion-before.png","artifacts/sunbed-occlusion-after.png","artifacts/coastal-resort-corrected.png","artifacts/npc-appearance-review.png","artifacts/npc-in-game.png","artifacts/walk-cycle-preview.png","artifacts/guest-check-in-0.png","artifacts/guest-check-in-1.png","artifacts/guest-entry-sequence-0.png","artifacts/guest-entry-sequence-1.png","artifacts/activity-sitting.png","artifacts/activity-eating.png","artifacts/activity-relaxing.png","artifacts/activity-resting.png","artifacts/volleyball-preview.png","artifacts/planter-model-review.png"]
	for name in ["staff-grounding-review.png","living-resort-cleaning-closeup.png","living-resort-meal-closeup.png","living-resort-queue-closeup.png","living-resort-sleeping-closeup.png","living-resort-split-overview.png","living-resort-worker6-crowd-1x-overview.png","living-resort-worker6-staff-motion-motion-04.png","living-resort-worker6-volley-motion-motion-20.png"]:
		evidence.append("artifacts/"+name)
	for name in ["bed-alignment-before.png","bed-alignment-after.png","bed-alignment-seating-review.png","living-resort-solo-fix-sleep-closeup.png","living-resort-solo-fix-volley-motion-08.png","volleyball-natural-preview.png"]:
		evidence.append("artifacts/"+name)
	for name in ["volleyball-hit-preview.png","volleyball-hit-compact-preview.png","living-resort-volleyball-hit-v2-motion-00.png","living-resort-volleyball-hit-v2-motion-13.png","living-resort-volleyball-hit-v2-motion-19.png","living-resort-volleyball-hit-v2-motion-22.png"]:
		evidence.append("artifacts/"+name)
	evidence.append("artifacts/arrival-wait-preview.png")
	file.store_string(JSON.stringify({"schema":1,"reviewer":"implementation assistant","reviewed":"2026-11-01","evidence":evidence,"sources":sources},"\t"))
	file.close()
	print("REVIEWED_ASSET_SOURCES ",sources.size())
	quit()
