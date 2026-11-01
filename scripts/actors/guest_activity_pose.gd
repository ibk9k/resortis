class_name GuestActivityPose
extends RefCounted

const FRAMES := {"sitting":4, "eating":12, "lying":4, "sleeping":4, "volleyball":16}
const ROOT := Vector2(320,480)
const CANVAS := Vector2i(640,640)

static func knee(a: Vector3, b: Vector3, length: float, pole: Vector3, second: float = -1.0) -> Vector3:
	var axis := (b-a).normalized()
	var bend := (pole-axis*pole.dot(axis)).normalized()
	var other := length if second < 0 else second
	var along := (length*length-other*other+a.distance_squared_to(b))/(2.0*a.distance_to(b))
	return a+axis*along + bend*sqrt(maxf(0, length*length-along*along))

static func apply(model: HolidayGuestModel, activity: String, phase: float) -> void:
	var lying := activity in ["lying", "sleeping"]
	var volley := activity == "volleyball"
	var breathe := sin(phase*TAU)*0.006
	var hip := Vector3(0,0.59+breathe,0)
	var tilt := 0.0
	if lying:
		hip.y = 0.19+breathe
		tilt = -PI/2 + (0.16 if activity == "lying" else 0.0)
	if volley:
		hip.y = 0.78 + 0.07*(0.5-0.5*cos(phase*TAU))
		tilt = -0.10*sin(phase*TAU)
	var basis := Basis(Vector3.RIGHT, tilt)
	model.body.transform = Transform3D(basis, hip-basis*Vector3(0,0.84,0))
	var head := model.body.get_node_or_null("FaceAndHair") as Node3D
	if head != null: head.rotation.z = 0.045*sin(phase*TAU)
	var bag := model.body.get_node_or_null("DayBag") as Node3D
	if bag != null: bag.visible = not lying
	var hat := model.body.get_node_or_null("SunHat")
	if hat != null: hat.visible = activity != "sleeping"
	for index in 2:
		var leg: Dictionary = model.limbs[index]
		var side: int = leg.side
		var pelvis := hip + basis*Vector3(side*0.095,0,0)
		var ankle := Vector3(side*0.105,0.10,0.40)
		if lying: ankle = hip+Vector3(side*0.105,0.015,0.785)
		if volley: ankle = Vector3(side*0.17,0.095,side*0.12)
		var joint := knee(pelvis,ankle,HolidayGuestModel.LEG_LENGTH,Vector3(0,0,1))
		model._between(leg.thigh,pelvis,joint)
		model._between(leg.calf,joint,ankle)
		leg.knee.position = joint
		leg.shoe.position = ankle-Vector3(0,0.095,0)
		leg.shoe.rotation.x = -PI/2 if lying else 0.0
		model.joints["left_foot" if side==-1 else "right_foot"] = ankle
		model.joints["left_knee" if side==-1 else "right_knee"] = joint
		var shorts := model.body.get_node_or_null("ShortLeg_%d" % side) as Node3D
		if shorts != null:
			var local_basis := basis.inverse()*Basis(Quaternion(Vector3.DOWN,(joint-pelvis).normalized()))
			shorts.transform = Transform3D(local_basis,model.body.transform.affine_inverse()*pelvis-local_basis*Vector3(0,0.84,0))
	for index in 2:
		var arm: Dictionary = model.limbs[index+2]
		var side: int = arm.side
		var shoulder := model.body.transform*Vector3(side*0.195,1.27,0)
		var hand := Vector3(side*0.14,hip.y+0.04,0.30)
		if lying: hand = hip+Vector3(side*0.24,0.04,-0.10)
		if activity == "eating" and side == 1:
			var bite := pow(0.5-0.5*cos(phase*TAU),1.5)
			hand = Vector3(lerpf(0.13,0.03,bite),lerpf(hip.y+0.12,hip.y+0.64,bite),lerpf(0.35,0.33,bite))
		if volley:
			var hit := pow(0.5+0.5*cos(phase*TAU),3)
			hand = Vector3(side*0.06,hip.y+0.14+0.21*hit,0.35-0.04*hit)
		var reach := hand-shoulder
		if reach.length() > 0.455: hand = shoulder+reach.normalized()*0.455
		var elbow := knee(shoulder,hand,0.24,Vector3(side,0,-0.1),0.22)
		model._between(arm.upper,shoulder,elbow)
		model._between(arm.fore,elbow,hand)
		arm.elbow.position = elbow
		arm.hand.position = hand
		model.joints["left_hand" if side==-1 else "right_hand"] = hand
	if model.activity_props == null:
		model.activity_props = Node3D.new()
		model.activity_props.name = "MealProps"
		model.add_child(model.activity_props)
		var bowl := GuestAppearance.ball(model.activity_props, Vector3.ZERO, Vector3(0.20,0.05,0.16), "f5ead0")
		bowl.name = "Bowl"
		GuestAppearance.ball(bowl,Vector3(0,0.018,0),Vector3(0.15,0.025,0.11),"c58139")
		GuestAppearance.ball(bowl,Vector3(-0.035,0.028,0.01),Vector3(0.045,0.02,0.05),"5a973e")
		var spoon := Node3D.new()
		spoon.name = "Spoon"
		model.activity_props.add_child(spoon)
		GuestAppearance.rod(spoon,Vector3.ZERO,Vector3(0,-0.01,0.105),0.006,"d0d8d2")
		GuestAppearance.ball(spoon,Vector3(0,-0.012,0.12),Vector3(0.032,0.012,0.045),"f5e1a8")
	model.activity_props.visible = activity == "eating"
	if activity == "eating":
		model.activity_props.get_node("Bowl").position = model.joints.left_hand+Vector3(0.025,0.02,0.025)
		model.activity_props.get_node("Spoon").position = model.joints.right_hand
		model.activity_props.get_node("Spoon").rotation.y = PI
