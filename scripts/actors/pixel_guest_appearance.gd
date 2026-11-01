class_name PixelGuestAppearance
extends RefCounted
## Broad pixel clusters, simple faces and blue/cream clothing from user references.
static func build(parent: Node3D, male: bool) -> void:
 var p := GuestAppearance
 var wardrobe := parent
 var head := Node3D.new()
 head.name = "FaceAndHair"
 wardrobe.add_child(head)
 parent = head
 p.ball(parent,Vector3(0,1.60,0.02),Vector3(0.57,0.62,0.44),"e3a577")
 for side in [-1,1]:
  p.ball(parent,Vector3(side*0.285,1.55,0.01),Vector3(0.07,0.10,0.07),"dfa171")
  var eye := p.ball(parent,Vector3(side*0.10,1.63,0.259),Vector3(0.065,0.080,0.024),"392c27")
  eye.name = "Eye_%d" % side
  p.ball(parent,Vector3(side*0.10-0.012,1.65,0.274),Vector3.ONE*0.022,"fff1d5")
  p.ball(parent,Vector3(side*0.205,1.51,0.185),Vector3(0.14,0.12,0.10),"e3a577")
  p.ball(parent,Vector3(side*0.205,1.52,0.240),Vector3(0.07,0.035,0.015),"dc8c73")
  var lid := p.rod(parent,Vector3(side*0.10-0.034,1.62,0.275),Vector3(side*0.10+0.034,1.625,0.275),0.009,"593b2b")
  lid.name = "ClosedEye_%d" % side
  lid.hide()
 p.ball(parent,Vector3(0,1.54,0.263),Vector3(0.05,0.05,0.04),"dfa171")
 p.rod(parent,Vector3(-0.05,1.46,0.23),Vector3(0,1.445,0.25),0.010,"a36343")
 p.rod(parent,Vector3(0,1.445,0.25),Vector3(0.05,1.46,0.23),0.010,"a36343")
 if male:
  p.profile(parent,[Vector4(1.77,0.295,0.23,-0.02),Vector4(1.89,0.26,0.20,-0.02),Vector4(1.98,0.13,0.10,-0.02),Vector4(1.99,0.001,0.001,-0.02)],"3b302a")
  for side in [-1,1]: p.ball(parent,Vector3(side*0.267,1.72,-0.03),Vector3(0.09,0.25,0.28),"49352a")
  for i in 5:
   var lock := p.ball(parent,Vector3(-0.19+i*0.085,1.83+i*0.012,0.18-i*0.005),Vector3(0.17,0.16,0.14),"62452e" if i%2 else "49352a")
   lock.rotation.z = -0.4
  for side in [-1,1]: p.box(parent,Vector3(side*0.10,1.63,0.265),Vector3(0.15,0.075,0.035),"302c27")
  p.rod(parent,Vector3(-0.15,1.62,0.22),Vector3(0.15,1.62,0.22),0.014,"453627")
 else:
  p.profile(parent,[Vector4(1.77,0.30,0.23,-0.02),Vector4(1.89,0.25,0.20,-0.02),Vector4(1.98,0.12,0.105,-0.02),Vector4(1.99,0.001,0.001,-0.02)],"593b2b")
  for side in [-1,1]:
   var hair := p.ball(parent,Vector3(side*0.29,1.47,-0.015),Vector3(0.17,0.56,0.27),"62422d")
   hair.rotation.z = side*0.12
   p.ball(parent,Vector3(side*0.29,1.235,-0.015),Vector3(0.18,0.17,0.22),"593b2b")
   p.rod(parent,Vector3(side*0.26,1.66,0.075),Vector3(side*0.27,1.29,0.06),0.019,"8a603e")
  p.ball(parent,Vector3(0,1.50,-0.15),Vector3(0.52,0.65,0.22),"593b2b")
  for i in 4:
   var fringe := p.ball(parent,Vector3(-0.20+i*0.11,1.82-i*0.024,0.20),Vector3(0.19,0.18,0.09),"805333" if i%2 else "69472f")
   fringe.rotation.z = -0.3
  p.ball(parent,Vector3(-0.30,1.36,0.11),Vector3(0.11,0.065,0.035),"db7867")
 for child in head.get_children(): child.position.y -= 1.38
 head.position.y = 1.38
 parent = wardrobe
 p.ball(parent,Vector3(0,1.345,0),Vector3(0.14,0.18,0.13),"e1a171")
 p.profile(parent,[Vector4(0.96,0.22,0.155,0.015),Vector4(1.06,0.27,0.18,0.015),Vector4(1.17,0.265,0.17,0.005),Vector4(1.27,0.235,0.14,0)],"fff1d5")
 for side in [-1,1]:
  p.rod(parent,Vector3(side*0.16,1.24,0.10),Vector3(side*0.22,1.31,0),0.030,"fff1d5")
  p.ball(parent,Vector3(side*0.235,1.258,0),Vector3(0.16,0.17,0.17),"e3a577")
  var leg := Node3D.new()
  leg.name = "ShortLeg_%d" % side
  leg.position.x = side*0.12
  parent.add_child(leg)
  p.profile(leg,[Vector4(0.77,0.12,0.145,0),Vector4(0.90,0.13,0.16,0),Vector4(0.96,0.12,0.15,0)],"359fa6" if not male else "386c9b")
  p.ring(leg,Vector2(0.122,0.148),0.79,0.010,"71b8c4")
 p.profile(parent,[Vector4(0.92,0.24,0.16,0),Vector4(1.0,0.225,0.155,0)],"258d98" if not male else "386c9b")
 for side in [-1,1]:
  p.rod(parent,Vector3(side*0.20,0.96,0.10),Vector3(side*0.14,0.87,0.16),0.006,"9ccbd0")
  p.rod(parent,Vector3(side*0.14,0.87,0.16),Vector3(side*0.08,0.87,0.16),0.005,"9ccbd0")
 p.ring(parent,Vector2(0.234,0.160),0.99,0.009,"e7c491")
 if male:
  var bag := Node3D.new()
  bag.name = "DayBag"
  parent.add_child(bag)
  p.ball(bag,Vector3(0,1.10,-0.20),Vector3(0.35,0.36,0.18),"b86c36")
  for side in [-1,1]: p.rod(bag,Vector3(side*0.15,1.0,0.15),Vector3(side*0.20,1.31,-0.05),0.018,"d79b51")
  p.box(parent,Vector3(-0.12,1.18,0.174),Vector3(0.10,0.07,0.016),"6c9cbc")
 else:
  p.box(parent,Vector3(0,1.22,0.15),Vector3(0.13,0.05,0.02),"72bbc4")
  p.ball(parent,Vector3(0,1.22,0.165),Vector3.ONE*0.035,"e6ad69")
