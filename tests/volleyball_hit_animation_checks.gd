extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var assets := ResortAssets.new()
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/illustrated-guests.json"))
	for variant in ["female","male"]:
		for facing in ["se","nw"]:
			var animation: String="volleyball_"+facing
			var library := assets.activity_frames(variant)
			var hit := library.get_frame_texture(animation,0).get_image()
			var load_pose := library.get_frame_texture(animation,13).get_image()
			for index in 16:
				var frame := library.get_frame_texture(animation,index).get_image()
				if AlphaRegions.components(frame,32).size()!=1: failures.append(variant+"/"+facing+" contains stray neighbouring artwork in frame "+str(index))
				var bounds := frame.get_used_rect()
				if absf(bounds.end.y-GuestActivityPose.ROOT.y)>4: failures.append(variant+"/"+facing+" has floating feet in frame "+str(index))
				if bounds.position.x<3 or bounds.position.y<3 or bounds.end.x>frame.get_width()-3 or bounds.end.y>frame.get_height()-3: failures.append(variant+"/"+facing+" clips its complete drawing")
			var union_pixels := 0
			var changed := 0
			for y in hit.get_height():
				for x in hit.get_width():
					var a := hit.get_pixel(x,y).a>0.5
					var b := load_pose.get_pixel(x,y).a>0.5
					if a or b: union_pixels+=1
					if a!=b: changed+=1
			var points: Array=metadata.contacts[variant].volleyball[facing]
			var hand_travel := Vector2(points[0][0],points[0][1]).distance_to(Vector2(points[13][0],points[13][1]))
			if hand_travel*ResortAssets.GUEST_SCALE<5: failures.append(variant+"/"+facing+" needs a visible arm extension of at least five game pixels")
			if float(changed)/maxi(1,union_pixels)<0.12: failures.append(variant+"/"+facing+" still looks like one stationary pose")
			if abs(hit.get_used_rect().size.y-load_pose.get_used_rect().size.y)*ResortAssets.GUEST_SCALE<2: failures.append(variant+"/"+facing+" needs a readable knee bend and rise")
	var record := {"id":1,"kind":"volleyball","position":Vector2.ZERO,"orientation":0}
	var left := GuestActivitySlots.slot(record,"volleyball",0,assets)
	var right := GuestActivitySlots.slot(record,"volleyball",1,assets)
	for variant in ["female","male"]:
		for role in 2:
			var actor := ResortWalker.new()
			actor.variant=variant
			actor.configure(1,Vector2i.ZERO,AStarGrid2D.new(),[],assets)
			root.add_child(actor)
			actor.present_activity(left if role==0 else right,0)
			var ball := VolleyBallView.new()
			root.add_child(ball)
			ball.present_rally(left,right,float(role)*2.0,variant,variant)
			var pixel := Vector2i((actor.sprite.to_local(ball.position+ball.ball_offset)-actor.sprite.offset).floor())
			var image := actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation,actor.sprite.frame).get_image()
			if not Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel) or image.get_pixelv(pixel).a<0.7: failures.append(variant+" ball misses the actual rendered hit in court slot "+str(role))
			actor.free()
			ball.free()
	print("VOLLEYBALL_HIT_ANIMATION_CHECKS ",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
