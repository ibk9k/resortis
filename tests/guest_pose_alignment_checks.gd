extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var assets := ResortAssets.new()
	var old_placement_misses := 0
	for facing in 2:
		var record := {"id":1,"kind":"cabin","position":Vector2.ZERO,"orientation":facing}
		var texture := assets.texture_for("cabin",facing) as AtlasTexture
		var transform := GroundRegistration.art_transform("cabin",facing,Vector2i(4,4),texture.region,texture.region.size,256,assets.image_for("cabin",facing))
		for role in 2:
			# Pillow centres independently measured on the original building atlas.
			var pillow: Vector2=([Vector2(166,271),Vector2(200,253)] if facing==0 else [Vector2(890,271),Vector2(856,253)])[role]
			# Aim slightly toward the headboard while keeping the head on the pillow.
			var target: Vector2=transform*(pillow-texture.region.position)+Vector2(-2 if facing==0 else 2,-1)
			for variant in ["female","male"]:
				var actor := ResortWalker.new()
				actor.variant=variant
				actor.configure(1,Vector2i.ZERO,AStarGrid2D.new(),[],assets)
				root.add_child(actor)
				actor.present_activity(GuestActivitySlots.slot(record,"sleeping",role,assets),0)
				var frame := actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation,0).get_image()
				# Measure the rendered head silhouette, rather than trusting a new
				# registration constant. The crop excludes the torso and sandals.
				var box := Rect2i(110,230,180,175) if variant=="female" else Rect2i(85,210,165,160)
				if facing==1: box.position.x=640-box.end.x
				var total := 0.0
				var centroid := Vector2.ZERO
				for y in range(box.position.y,box.end.y):
					for x in range(box.position.x,box.end.x):
						var alpha := frame.get_pixel(x,y).a
						total+=alpha
						centroid+=Vector2(x,y)*alpha
				centroid/=maxf(1,total)
				var actual: Vector2=actor.sprite.to_global(centroid+actor.sprite.offset)
				var previous: Vector2=actual-Vector2(-2 if facing==0 else 2,-1)
				if previous.distance_to(target)>1.8: old_placement_misses+=1
				if actual.distance_to(target)>1.8:
					failures.append("%s cabin%d slot%d head misses pillow by %.2f pixels" % [variant,facing,role,actual.distance_to(target)])
				actor.free()
	if old_placement_misses == 0:
		failures.append("Earlier low bed placement must fail the head alignment check")
	print("GUEST_POSE_ALIGNMENT_CHECKS ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
