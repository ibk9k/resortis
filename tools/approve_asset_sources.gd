extends SceneTree
## Run only after inspecting the generated catalogue, animation and game views.
func _initialize() -> void:
	if not "--reviewed" in OS.get_cmdline_user_args():
		push_error("Review rendered evidence before recording source hashes; pass --reviewed after that review.")
		quit(1)
		return
	var sources: Dictionary = {}
	for folder in ["res://assets/atlases","res://assets/characters/frames-v2","res://assets/structures","res://assets/interiors","res://assets/facility-staff/masters","res://assets/facility-staff/frames","res://assets/staffed-venues/masters","res://assets/staffed-venues/frames"]:
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
	for path in ["res://data/coastal_map.json", "res://scripts/simulation/arrival_geometry.gd", "res://scripts/simulation/arrival_traffic.gd", "res://scripts/world/arrival_court.gd", "res://scripts/world/arrival_vehicle.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://assets/shaders/ground.gdshader", "res://scripts/world/coastal_terrain.gd", "res://tools/bake_terrain_wang.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for folder in ["res://assets/staff/masters", "res://assets/staff/illustrated"]:
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".png"):
				var path: String = folder.path_join(name)
				sources[path] = FileAccess.get_sha256(path)
	for path in ["res://assets/staff/janitor_art.gd", "res://assets/staff/janitor_skin.gd", "res://assets/staff/registration.json", "res://tools/bake_staff.gd", "res://scripts/world/cleanliness_view.gd", "res://scripts/world/resort_population_view.gd", "res://scripts/ui/resort_management_ui.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://mockups/facilities/concept_models.gd", "res://scripts/content/resort_services.gd", "res://tools/bake_structure_models.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/world/facility_ambience.gd", "res://assets/shaders/pool_motion.gdshader", "res://tools/bake_assets.gd", "res://scripts/content/facility_staff.gd", "res://tools/bake_illustrated_attendants.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	for path in ["res://scripts/content/staffed_venue_art.gd", "res://tools/bake_staffed_venues.gd", "res://assets/staffed-venues/workstations.json", "res://assets/staffed-venues/baked.json"]:
		sources[path] = FileAccess.get_sha256(path)
	for facing in 2:
		for part in 5:
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
	for name in ["save-slots-review.png","save-slots-confirm-review.png","vertical-walk-review.png","janitor-sharpness-before-after.png"]:
		evidence.append("artifacts/"+name)
	for section in ["statement", "receipts", "prices"]:
		evidence.append("artifacts/economy-%s-review.png" % section)
	evidence.append("artifacts/challenges-board-review.png")
	evidence.append("artifacts/challenges-statue-review.png")
	evidence.append("artifacts/cleaner-motion-review.png")
	evidence.append("artifacts/janitor-v2-motion-review.png")
	evidence.append("artifacts/bed-alignment-stool-v2.png")
	evidence.append("artifacts/bed-alignment-stool-animation.png")
	evidence.append("artifacts/living-resort-furniture-check-closeup.png")
	evidence.append("artifacts/bed-alignment-contact-final.png")
	evidence.append("artifacts/living-resort-seat-contact-closeup.png")
	evidence.append("artifacts/living-resort-lounger-contact-closeup.png")
	evidence.append("artifacts/bed-alignment-contact-motion.png")
	for name in ["bed-alignment-seating-unclipped.png", "bed-alignment-seating-unclipped-motion.png", "living-resort-unclipped-closeup.png"]:
		evidence.append("artifacts/" + name)
	evidence.append("artifacts/worker-4-staff-preview/frame-00.png")
	for name in ["car", "shuttle", "shuttle-turn", "reception", "road-edge"]:
		evidence.append("artifacts/arrival-court-%s.png" % name)
	evidence.append("artifacts/expansion-overview.png")
	evidence.append("artifacts/expansion-playable.png")
	evidence.append("artifacts/ambience-facilities.png")
	evidence.append("artifacts/illustrated-staff-review.png")
	evidence.append("artifacts/staffed-venues-in-game.gif")
	evidence.append("artifacts/ice-cream-vendor-in-game.gif")
	for kind: String in ResortServices.EXPANSION:
		evidence.append("artifacts/expansion-%s.png" % kind)
	file.store_string(JSON.stringify({"schema":1,"reviewer":"implementation assistant","reviewed":Time.get_date_string_from_system(),"evidence":evidence,"sources":sources},"\t"))
	file.close()
	print("REVIEWED_ASSET_SOURCES ",sources.size())
	quit()
