class_name GuestActivitySlots
extends RefCounted
## Surface fixtures measured in the ORIGINAL source image. Every anchor uses
## GroundRegistration; lift is the source-space distance to the supporting floor.
static func slot(record: Dictionary, activity: String, role: int, assets: ResortAssets) -> Dictionary:
	if record.kind in ResortServices.EXPANSION:
		return _modeled_slot(record, activity, role)
	if activity == "volleyball":
		return {"position":record.position+Vector2(1.8 if role==0 else 5.2,2),"offset":0.0,"facing":"se" if role==0 else "nw","pose":activity}
	var point := Vector2.ZERO
	var lift := 0.0
	var facing := "ne"
	if activity in ["sitting","eating"]:
		point = Vector2(183,815) if role==0 else Vector2(242,848)
		lift = 44.0
	elif activity == "lying":
		point = Vector2(1198,801) if role==0 else Vector2(1350,852)
		lift = 25.0
		facing = "sw"
	else:
		if record.orientation == 0:
			point = (Vector2(217,300) if role==0 else Vector2(246,282)) if activity=="sleeping" else (Vector2(219,332) if role==0 else Vector2(249,314))
			facing = "se"
		else:
			point = (Vector2(844,300) if role==0 else Vector2(814,283)) if activity=="sleeping" else (Vector2(845,330) if role==0 else Vector2(815,313))
			facing = "sw"
		lift = 39.0
	var texture := assets.texture_for(record.kind, record.orientation) as AtlasTexture
	var region := texture.region
	var transform := GroundRegistration.art_transform(record.kind,record.orientation,ResortCatalog.footprint(record.kind,record.orientation),region,region.size,256,assets.image_for(record.kind,record.orientation))
	var height := lift*absf(transform.y.y)
	var surface := transform*(point-region.position)
	var ground := surface+Vector2(0,height)
	var hip_height := 0.19 if activity in ["lying","sleeping"] else 0.59
	var result := {"position":record.position+IsometricGrid.unproject(ground),"offset":-height+hip_height*220*cos(PI/6)*ResortAssets.GUEST_SCALE,"facing":facing,"pose":activity}
	if activity in ["sitting", "eating"]:
		var seat: Vector2 = [Vector2(173, 803), Vector2(233, 832)][role]
		result["seat_offset"] = transform * (seat - region.position) - ground
		_align_staffed_fixture(record, role, result)
	if activity=="sleeping":
		var pillow: Vector2=([Vector2(166,271),Vector2(200,253)] if record.orientation==0 else [Vector2(890,271),Vector2(856,253)])[role]
		result["head_offset"]=transform*(pillow-region.position)-ground
	return result

static func approach(record: Dictionary, activity: String, role: int, assets: ResortAssets) -> Array[Vector2]:
	var door: Vector2 = record.position+Vector2(ResortCatalog.entrance(record.kind,record.orientation))
	var target: Vector2 = slot(record,activity,role,assets).position
	var points: Array[Vector2] = [door]
	if record.kind in ResortServices.EXPANSION:
		var center := _model_center(record)
		var size := ResortCatalog.footprint(record.kind)
		var aisle := {
			"gym": 0.48, "sauna": 1.40, "restaurant": 3.40,
			"yoga": 1.48, "massage": 1.37, "gear": 1.05, "pickleball": 2.68,
		}
		if aisle.has(record.kind):
			if record.kind == "restaurant" and role >= 2: aisle.restaurant = 0.74
			if record.kind == "yoga" and role >= 3: aisle.yoga = 0.08
			points.append(center + Vector2(door.x - center.x, size.y * 0.5 - 0.14))
			points.append(center + Vector2(door.x - center.x, aisle[record.kind]))
			points.append(Vector2(target.x, center.y + float(aisle[record.kind])))
	if activity == "volleyball":
		if record.kind == "volleyball":
			# Walk around the far post, keeping the net clear.
			points.append(record.position+Vector2(4,4.7))
			points.append(record.position+Vector2(1.8 if role==0 else 5.2,4.7))
	points.append(target)
	return points

static func _model_center(record: Dictionary) -> Vector2:
	return record.position + Vector2(ResortCatalog.footprint(record.kind) - Vector2i.ONE) * 0.5

static func _modeled_slot(record: Dictionary, pose: String, role: int) -> Dictionary:
	# X/Z are mesh-local, relative to the registered footprint center.
	# Elevation uses the same orthographic projection as the model bake.
	var anchor := Vector2.ZERO
	var height := 0.0
	var facing := "ne"
	match String(record.kind):
		"gym":
			anchor = Vector2(-2.62 + 1.23 * role, -1.00)
			height = 0.516
		"sauna":
			anchor = Vector2(-1.52 if role == 0 else -0.40, -0.63)
			height = 0.71
		"ice_cream":
			anchor = Vector2(-0.47 if role == 0 else 0.47, 0.93)
		"restaurant":
			anchor = Vector2(-2.38 if role % 2 == 0 else 2.38, 2.942 if role < 2 else 0.402)
			height = ResortServices.BISTRO_DECK + 0.527 * ResortServices.BISTRO_VERTICAL_SCALE
		"yoga":
			anchor = Vector2([-1.65, 1.65, 0.0][role % 3], 0.81 if role < 3 else -0.65)
			height = 0.288
		"massage":
			anchor = Vector2(-0.98 if role == 0 else 0.98, 0.29)
			height = 0.96
			facing = "sw"
		"gear":
			anchor = Vector2(-0.60 if role == 0 else 0.62, 0.99)
			height = 0.245
		"pickleball":
			anchor = Vector2(-2.94 if role == 0 else 2.94, 0.03)
			height = 0.21
			facing = "se" if role == 0 else "nw"
	var offset := -height * 32.0 * sqrt(1.5)
	var result := {"position": _model_center(record) + anchor, "offset": offset, "pose": pose, "facing": facing}
	if record.kind == "pickleball":
		result["paddle"] = true
	if record.kind in ["restaurant", "sauna"]:
		result["seat_offset"] = Vector2(0, offset)
	if record.kind == "massage":
		result["offset"] += 5.0
	if record.kind in FacilityStaff.KINDS:
		_align_staffed_fixture(record, role, result)
	return result

static func _align_staffed_fixture(record: Dictionary, role: int, slot_data: Dictionary) -> void:
	# Keep the logical slot and approach stable for saves in progress. The
	# complete pose contacts the new painted stool, mat, or counter surface.
	var contact := StaffedVenueArt.fixture(record.kind, role)
	if not contact.is_finite(): return
	var delta := contact - IsometricGrid.project(slot_data.position - record.position)
	if slot_data.has("seat_offset"):
		slot_data["seat_offset"] = delta
	else:
		slot_data["render_offset"] = delta
