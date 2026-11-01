class_name HolidayGuestModel
extends Node3D
## One connected, volumetric character in every direction. +Z is the face.
## Limb lengths remain fixed; grounded stance feet and two-bone knees are solved
## in model space before rendering. No independently rotated flat body cutouts.
const DIRECTIONS := ["s","sw","w","nw","n","ne","e","se"]
const ANGLES := {"s":45.0,"sw":0.0,"w":-45.0,"nw":-90.0,"n":-135.0,"ne":180.0,"e":135.0,"se":90.0}
const POSES := 16
const LEG_LENGTH := 0.40
var body: Node3D
var limbs: Array[Dictionary] = []
var joints: Dictionary = {}
var animation_player: AnimationPlayer
@export var variant := "female"
var activity_props: Node3D
func _ready() -> void:
 if limbs.is_empty():
  for child in get_children(): child.free()
  build()
func build() -> void:
 name = "HolidayGuestModel"
 var p := GuestAppearance
 body = Node3D.new()
 body.name = "Body"
 add_child(body)
 if variant == "male": GuestAppearance.male_clothes(body)
 else: GuestAppearance.clothes(body)
 GuestAppearance.head(body, variant == "male")
 for side in [-1,1]:
  var leg := {"side":side,"thigh":_segment(0.084,"e3a577"),"calf":_segment(0.066,"dfa171"),"knee":p.ball(self,Vector3.ZERO,Vector3.ONE*0.145,"e3a577"),"shoe":Node3D.new()}
  add_child(leg.shoe)
  p.ball(leg.shoe,Vector3(0,0.035,0.04),Vector3(0.145,0.08,0.26),"68442c")
  p.ball(leg.shoe,Vector3(0,0.065,0.05),Vector3(0.12,0.055,0.22),"d69c6c")
  p.box(leg.shoe,Vector3(0,0.09,0.065),Vector3(0.13,0.025,0.038),"7f4c2c")
  p.box(leg.shoe,Vector3(0,0.084,-0.02),Vector3(0.13,0.025,0.03),"905833")
  limbs.append(leg)
 for side in [-1,1]:
  var arm := {"side":side,"upper":_segment(0.059,"e3a577"),"fore":_segment(0.048,"dfa171"),"elbow":p.ball(self,Vector3.ZERO,Vector3.ONE*0.10,"e3a577"),"hand":p.ball(self,Vector3.ZERO,Vector3(0.095,0.12,0.080),"e3a577")}
  limbs.append(arm)
 animation_player = AnimationPlayer.new()
 animation_player.name = "AnimationPlayer"
 add_child(animation_player)
 var library := AnimationLibrary.new()
 var walk := Animation.new()
 walk.length = 1.0
 walk.loop_mode = Animation.LOOP_LINEAR
 var track := walk.add_track(Animation.TYPE_METHOD)
 walk.track_set_path(track,NodePath("."))
 for i in POSES:
  walk.track_insert_key(track,float(i)/POSES,{"method":"pose","args":[float(i)/POSES,true]})
 library.add_animation("walk",walk)
 animation_player.add_animation_library("",library)
 pose(0,false)
func _segment(radius: float, color: String) -> MeshInstance3D:
 # Open ends overlap the spherical anatomical joints. A tapered muscle profile
 # avoids the flat cylinder caps and bracelet-like grooves of the placeholder.
 return GuestAppearance.profile(self,[Vector4(-0.5,radius*0.76,radius*0.80,0),Vector4(-0.35,radius*0.84,radius*0.88,0),Vector4(-0.05,radius*0.97,radius,0),Vector4(0.22,radius,radius,0),Vector4(0.40,radius*0.93,radius*0.94,0),Vector4(0.5,radius*0.85,radius*0.88,0)],color,32)
func _between(mesh: MeshInstance3D, a: Vector3,b: Vector3) -> void:
 mesh.position = (a+b)*0.5
 mesh.scale.y = a.distance_to(b)
 mesh.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
func pose(phase: float, walking: bool = true) -> void:
 body.transform = Transform3D.IDENTITY
 var hat := body.get_node_or_null("SunHat")
 if hat != null: hat.show()
 if activity_props != null: activity_props.hide()
 for side in [-1,1]:
  var shorts := body.get_node_or_null("ShortLeg_%d" % side) as Node3D
  if shorts != null: shorts.transform = Transform3D(Basis.IDENTITY, Vector3(side*0.092,0,0))
 var head := body.get_node_or_null("FaceAndHair") as Node3D
 if head != null:
  head.rotation.z = 0.035*sin(phase*TAU) if walking else 0.0
  for side in [-1,1]:
   head.get_node("Eye_%d" % side).show()
   head.get_node("ClosedEye_%d" % side).hide()
 var bag := body.get_node_or_null("DayBag") as Node3D
 if bag != null: bag.show()
 # Set pelvis height from the planted leg's reach. A fixed low pelvis made
 # every pose crouch even though the two-bone connections were correct.
 var furthest_stance := 0.0
 if walking:
  for shift in [0.0,0.5]:
   var stance := fposmod(phase+shift,1.0)
   if stance<0.6: furthest_stance = maxf(furthest_stance,absf(lerpf(0.23,-0.23,stance/0.6)))
 var hip_height := 0.095+sqrt(0.79*0.79-furthest_stance*furthest_stance-0.01*0.01)
 var bob := hip_height-0.84
 body.position.y = bob
 joints.clear()
 for index in 2:
  var leg: Dictionary = limbs[index]
  var side: int = leg.side
  var t := fposmod(phase+(0.5 if side==1 else 0.0),1.0)
  # Stance occupies 60% of the cycle. Backward foot motion compensates forward
  # travel; the swing returns the foot with clearance, never crossed in X.
  var z := lerpf(0.23,-0.23,t/0.6) if t < 0.6 else lerpf(-0.23,0.23,(t-0.6)/0.4)
  var lift := 0.10*sin((t-0.6)/0.4*PI) if t >= 0.6 else 0.0
  if not walking: z = 0; lift = 0
  var hip := Vector3(side*0.095,0.84+bob,0)
  var ankle := Vector3(side*0.105,0.095+lift,z)
  var delta := ankle-hip
  var reach := delta.length()
  var mid := (hip+ankle)*0.5
  var bend := Vector3.FORWARD.cross(delta).cross(delta).normalized()
  if bend.z < 0: bend = -bend
  var knee := mid+bend*sqrt(maxf(LEG_LENGTH*LEG_LENGTH-reach*reach*0.25,0))
  _between(leg.thigh,hip,knee)
  _between(leg.calf,knee,ankle)
  leg.knee.position = knee
  leg.shoe.position = ankle-Vector3(0,0.095,0)
  leg.shoe.rotation.x = -0.12*sin((t-0.6)/0.4*PI) if walking and t>=0.6 else 0.0
  joints["left_foot" if side==-1 else "right_foot"] = ankle
  joints["left_knee" if side==-1 else "right_knee"] = knee
 for index in 2:
  var arm: Dictionary = limbs[index+2]
  var side: int = arm.side
  var swing := sin(phase*TAU)*side*0.45 if walking else 0.0
  var shoulder := Vector3(side*0.195,1.27+bob,0)
  var elbow := shoulder+Vector3(side*0.025,-cos(swing)*0.24,sin(swing)*0.24)
  var hand := elbow+Vector3(0,-cos(swing-0.15)*0.22,sin(swing-0.15)*0.22)
  _between(arm.upper,shoulder,elbow)
  _between(arm.fore,elbow,hand)
  arm.elbow.position = elbow
  arm.hand.position = hand
func face(direction: String) -> void:
 rotation.y = deg_to_rad(ANGLES[direction])

func activity_pose(activity: String, phase: float) -> void:
 pose(0, false)
 GuestActivityPose.apply(self, activity, phase)
