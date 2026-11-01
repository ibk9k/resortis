class_name HolidayGuestRig
extends Node2D
## Authoring rig, baked to ordinary guarded PNGs for gameplay. Feet and knees
## come from one analytic walk model, rather than generated pose guesses.
var facing := "se"
var pieces: Array[Sprite2D] = []
var joints: Dictionary = {}

func configure(direction: String) -> void:
	facing = direction
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/guest-rig.json"))
	var entry: Dictionary = manifest.parts[direction]
	var atlas := load(entry.file) as Texture2D
	for i in 8:
		var values: Array = entry.regions[i]
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(values[0],values[1],values[2],values[3])
		var original_size := texture.region.size
		if i == 1:
			# The generated torso has overlap tabs below the shorts. The animated
			# thighs supply that skin; keeping both would draw static leg stumps.
			texture.region.size.y *= 0.88
		texture.filter_clip = true
		var piece := Sprite2D.new()
		piece.name = ["Head","Torso","LeftArm","RightArm","LeftThigh","RightThigh","LeftCalf","RightCalf"][i]
		piece.centered = false
		piece.texture = texture
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		piece.set_meta("uncropped_size",original_size)
		var image := texture.get_image()
		piece.set_meta("top_joint",_joint(image,0.10))
		piece.set_meta("lower_joint",_joint(image,0.72 if i in [6,7] else 0.90))
		piece.set_meta("neck_joint",_joint(image,0.96))
		add_child(piece)
		pieces.append(piece)
	set_pose(0.0)

func set_pose(phase: float,walking := true) -> void:
	var t := phase * TAU
	var moving_right := facing in ["se","ne"]
	var back_view := facing in ["ne","nw"]
	var forward := Vector2(0.894 if moving_right else -0.894,-0.447 if back_view else 0.447)
	var root := Vector2(192,455)
	var bob := (1.0-cos(t*2.0))*1.8 if walking else 0.0
	var left_hip := Vector2(177,362-bob)
	var right_hip := Vector2(207,362-bob)
	var stride := cos(t)*32.0 if walking else 0.0
	var left_lift := maxf(0.0,sin(t)) if walking else 0.0
	var right_lift := maxf(0.0,-sin(t)) if walking else 0.0
	var left_foot := root + Vector2(-10,-4) + forward * stride - Vector2(0,left_lift*22.0)
	var right_foot := root + Vector2(10,4) - forward * stride - Vector2(0,right_lift*22.0)
	var left_knee := _knee(left_hip,left_foot,moving_right,left_lift)
	var right_knee := _knee(right_hip,right_foot,moving_right,right_lift)
	joints = {"left_hip":left_hip,"right_hip":right_hip,"left_knee":left_knee,"right_knee":right_knee,"left_foot":left_foot,"right_foot":right_foot}
	var left_depth := 1 if left_foot.y > right_foot.y else 0
	var right_depth := 1-left_depth
	_bone(pieces[6],left_knee,left_foot,26.0,true)
	_bone(pieces[7],right_knee,right_foot,26.0,true)
	_bone(pieces[4],left_hip,left_knee,34.0,false)
	_bone(pieces[5],right_hip,right_knee,34.0,false)
	pieces[6].z_index = left_depth*2
	pieces[4].z_index = left_depth*2+1
	pieces[7].z_index = right_depth*2
	pieces[5].z_index = right_depth*2+1
	# Natural opposing arm swings. Attachment caps sit underneath the torso.
	var arm_swing := cos(t)*24.0 if walking else 0.0
	_bone(pieces[2],Vector2(166,263-bob),Vector2(165-arm_swing,349-bob),23.0,false)
	_bone(pieces[3],Vector2(219,263-bob),Vector2(220+arm_swing,349-bob),23.0,false)
	pieces[2].z_index = 5
	pieces[3].z_index = 7
	var torso := pieces[1]
	var torso_size := torso.texture.get_size()
	var original: Vector2 = torso.get_meta("uncropped_size")
	var torso_scale := 144.0/original.y
	torso.transform = Transform2D(Vector2(torso_scale,0),Vector2(0,torso_scale),Vector2(192-torso_size.x*torso_scale*0.5,231-bob))
	torso.z_index = 6
	var head := pieces[0]
	var head_size := head.texture.get_size()
	var head_scale := 180.0/head_size.y
	var neck: Vector2 = head.get_meta("neck_joint")
	head.transform = Transform2D(Vector2(head_scale,0),Vector2(0,head_scale),Vector2(192,247-bob)-neck*head_scale)
	head.z_index = 8

func _knee(hip: Vector2,ankle: Vector2,rightward: bool,lift: float) -> Vector2:
	# In the fixed isometric camera, projected limb length changes with depth.
	# A planted leg stays almost straight; only the swinging knee bends forward.
	var bend := 2.0+lift*20.0
	return hip.lerp(ankle,0.51)+Vector2(bend if rightward else -bend,-lift*4.0)

func _bone(piece: Sprite2D,start: Vector2,end: Vector2,_width: float,_calf: bool) -> void:
	var top: Vector2 = piece.get_meta("top_joint")
	var bottom: Vector2 = piece.get_meta("lower_joint")
	var direction := end-start
	var source_axis := bottom-top
	var rotation := direction.angle()-source_axis.angle()
	var scale := direction.length()/source_axis.length()
	var basis := Transform2D(rotation,Vector2.ONE*scale,0,Vector2.ZERO)
	basis.origin = start-basis.basis_xform(top)
	piece.transform = basis

func _joint(image: Image,fraction: float) -> Vector2:
	var y := clampi(roundi(image.get_height()*fraction),2,image.get_height()-3)
	var total := 0.0
	var count := 0
	for row in range(maxi(0,y-2),mini(image.get_height(),y+3)):
		for x in image.get_width():
			if image.get_pixel(x,row).a > 0.75:
				total += x
				count += 1
	return Vector2(total/maxf(count,1),y)
