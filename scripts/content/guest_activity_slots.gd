class_name GuestActivitySlots
extends RefCounted
## Surface fixtures measured in the ORIGINAL source image. Every anchor uses
## GroundRegistration; lift is the source-space distance to the supporting floor.
static func slot(record: Dictionary, activity: String, role: int, assets: ResortAssets) -> Dictionary:
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
	if activity=="sleeping":
		var pillow: Vector2=([Vector2(166,271),Vector2(200,253)] if record.orientation==0 else [Vector2(890,271),Vector2(856,253)])[role]
		result["head_offset"]=transform*(pillow-region.position)-ground
	return result

static func approach(record: Dictionary, activity: String, role: int, assets: ResortAssets) -> Array[Vector2]:
	var door: Vector2 = record.position+Vector2(ResortCatalog.entrance(record.kind,record.orientation))
	var target: Vector2 = slot(record,activity,role,assets).position
	var points: Array[Vector2] = [door]
	if activity == "volleyball":
		# Walk AROUND the far post, never through the net.
		points.append(record.position+Vector2(4,4.7))
		points.append(record.position+Vector2(1.8 if role==0 else 5.2,4.7))
	points.append(target)
	return points
