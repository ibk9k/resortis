extends SceneTree

var failures: Array[String] = []
var assets: ResortAssets

func _initialize() -> void:
	_run.call_deferred()

func _check_lounger_centering() -> void:
	var record := {"id": 1, "kind": "sunbeds", "position": Vector2.ZERO, "orientation": 0}
	var texture := assets.texture_for("sunbeds", 0) as AtlasTexture
	var transform := GroundRegistration.art_transform("sunbeds", 0, Vector2i(3,3), texture.region, texture.region.size, 256, assets.image_for("sunbeds", 0))
	for role in 2:
		for variant in ["female", "male"]:
			var guest := ResortWalker.new()
			guest.variant = variant
			guest.configure(1, Vector2i.ZERO, AStarGrid2D.new(), [], assets)
			root.add_child(guest)
			for phase in [0.0, 1.0, 2.0, 3.0]:
				guest.present_activity(GuestActivitySlots.slot(record, "lying", role, assets), phase)
				var hip := Vector2(310, 435) if variant == "female" else Vector2(300, 420)
				var actual: Vector2 = transform.affine_inverse() * guest.sprite.to_global(hip + guest.sprite.offset) + texture.region.position
				var foot_center := Vector2(1152 + 152 * role, 815 + 51 * role)
				var head_center := Vector2(1212 + 152 * role, 773 + 51 * role)
				var axis := (head_center - foot_center).normalized()
				var sideways_error := absf((actual - foot_center).cross(axis))
				if sideways_error > 4.0:
					failures.append("%s guest is off the lounger centerline in slot %d at phase %.1f" % [variant, role, phase])
				if variant == "female" and phase == 0.0:
					var former: Vector2 = transform.affine_inverse() * (guest.sprite.to_global(hip + guest.sprite.offset) + Vector2(2.5, 2.5)) + texture.region.position
					if absf((former - foot_center).cross(axis)) <= 4.0:
						failures.append("Earlier off-center lounger pose was not detected")
			guest.free()

func _check_seat_contact() -> void:
	var record := {"id": 1, "kind": "cafe", "position": Vector2.ZERO, "orientation": 0}
	for role in 2:
		var target := StaffedVenueArt.fixture("cafe", role)
		for variant in ["female", "male"]:
			var guest := ResortWalker.new()
			guest.variant = variant
			guest.configure(1, Vector2i.ZERO, AStarGrid2D.new(), [], assets)
			root.add_child(guest)
			for activity in ["sitting", "eating"]:
				for time in [0.0, 0.9]:
					guest.present_activity(GuestActivitySlots.slot(record, activity, role, assets), time)
					if guest.sprite.material != null:
						failures.append("%s guest has a clipping material in seat %d" % [variant, role])
					var contact := Vector2(310, 403) if variant == "female" else Vector2(300, 374)
					var actual: Vector2 = guest.sprite.to_global(contact + guest.sprite.offset)
					if actual.distance_to(target) > 0.5:
						failures.append("%s guest is not seated on stool %d during %s" % [variant, role, activity])
					var slot: Dictionary = GuestActivitySlots.slot(record, activity, role, assets)
					var old_shift := Vector2(-3 if variant == "female" else -1, 0)
					var old_contact: Vector2 = IsometricGrid.project(slot.position) + Vector2(0, slot.offset) + old_shift + (contact - GuestActivityPose.ROOT) * ResortAssets.GUEST_SCALE
					if old_contact.distance_to(target) < 4.0:
						failures.append("Earlier low stool pose was not detected")
			guest.free()

func _run() -> void:
	assets = ResortAssets.new()
	_check_lounger_centering()
	_check_seat_contact()
	print("FURNITURE_POSE_CHECKS ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
