class_name GuestAppearance
extends RefCounted
## Native model art, kept separate from the gait. Smooth profiles, sewn clothing,
## painted-size facial features and a woven hat replace placeholder primitives.
static var palette: Dictionary = {}
static func material(hex: String) -> StandardMaterial3D:
 if not palette.has(hex):
  var m := StandardMaterial3D.new()
  m.albedo_color = Color(hex)
  m.roughness = 0.92
  if hex in ["e3a577","dfa171","e1a171","593b2b","62422d","e66a59","359fa6","c9a26c"]:
   var line := ShaderMaterial.new()
   var shader := Shader.new()
   shader.code = "shader_type spatial; render_mode unshaded,cull_front; void vertex(){VERTEX+=NORMAL*0.006;} void fragment(){ALBEDO=vec3(0.12,0.065,0.04);}"
   line.shader = shader
   m.next_pass = line
  palette[hex] = m
 return palette[hex]
static func put(parent: Node3D, mesh: Mesh, at: Vector3, hex: String) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.mesh = mesh
 node.position = at
 node.material_override = material(hex)
 parent.add_child(node)
 return node
static func ball(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
 var mesh := SphereMesh.new()
 mesh.radial_segments = 32
 mesh.rings = 16
 var node := put(parent,mesh,at,hex)
 node.scale = size
 return node
static func box(parent: Node3D, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
 var shape := BoxMesh.new()
 shape.size = size
 return put(parent,shape,at,hex)
static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, hex: String) -> MeshInstance3D:
 var mesh := CapsuleMesh.new()
 mesh.radius = radius
 mesh.height = maxf(a.distance_to(b)+radius*2,radius*2)
 mesh.radial_segments = 16
 mesh.rings = 4
 var node := put(parent,mesh,(a+b)*0.5,hex)
 node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
 return node
static func profile(parent: Node3D, rings: Array, hex: String, sides: int = 48) -> MeshInstance3D:
 # Each ring is Vector4(y, x radius, z radius, forward offset).
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for row in rings.size()-1:
  for col in sides:
   var points: Array[Vector3] = []
   for pair in [[row,col],[row+1,col],[row+1,col+1],[row,col+1]]:
    var r: Vector4 = rings[pair[0]]
    var a := float(pair[1])*TAU/sides
    points.append(Vector3(sin(a)*r.y,r.x,cos(a)*r.z+r.w))
   var order := [0,1,2,0,2,3] if rings[row+1].x >= rings[row].x else [0,2,1,0,3,2]
   for index in order: st.add_vertex(points[index])
 st.generate_normals()
 var mesh := st.commit()
 return put(parent,mesh,Vector3.ZERO,hex)
static func ring(parent: Node3D, radius: Vector2, y: float, tube: float, hex: String, center: Vector3 = Vector3.ZERO) -> void:
 for i in 48:
  var a := TAU*i/48
  var b := TAU*(i+1)/48
  rod(parent,center+Vector3(sin(a)*radius.x,y,cos(a)*radius.y),center+Vector3(sin(b)*radius.x,y,cos(b)*radius.y),tube,hex)
static func head(parent: Node3D, male: bool = false) -> void:
 profile(parent,[Vector4(1.365,0.035,0.045,0.035),Vector4(1.405,0.130,0.110,0.040),Vector4(1.465,0.205,0.158,0.035),Vector4(1.55,0.245,0.186,0.025),Vector4(1.65,0.244,0.193,0.015),Vector4(1.74,0.208,0.170,0),Vector4(1.80,0.100,0.085,0),Vector4(1.815,0.001,0.001,0)],"e3a577")
 # Eye whites, amber iris, pupil, catchlight and a dark upper eyelid. Features
 # are deliberately large enough to survive the ~50-pixel gameplay silhouette.
 for side: int in [-1,1]:
  var x := side*0.102
  ball(parent,Vector3(x,1.621,0.198),Vector3(0.084,0.103,0.040),"fff2d5")
  ball(parent,Vector3(x+0.004,1.617,0.221),Vector3(0.052,0.072,0.020),"7c4930")
  ball(parent,Vector3(x+0.004,1.618,0.232),Vector3(0.029,0.047,0.010),"302a2a")
  ball(parent,Vector3(x-0.009,1.638,0.240),Vector3(0.017,0.020,0.007),"fffaf0")
  rod(parent,Vector3(x-0.037,1.657,0.217),Vector3(x+0.030,1.662,0.214),0.006,"613d31")
  rod(parent,Vector3(x-0.033,1.697,0.197),Vector3(x+0.028,1.705,0.197),0.008,"754733")
  ball(parent,Vector3(side*0.158,1.535,0.183),Vector3(0.070,0.034,0.015),"d88769")
  # Ears with a warm inner surface and a tiny gold stud.
  ball(parent,Vector3(side*0.240,1.565,0.005),Vector3(0.063,0.105,0.065),"d79770")
  ball(parent,Vector3(side*0.263,1.562,0.022),Vector3(0.022,0.054,0.035),"bc785d")
  if not male: ball(parent,Vector3(side*0.257,1.520,0.035),Vector3.ONE*0.022,"e8c46d")
 # Soft bridge and button tip rather than a pointed primitive nose.
 ball(parent,Vector3(0,1.575,0.211),Vector3(0.045,0.075,0.040),"e5ac80")
 ball(parent,Vector3(0,1.548,0.232),Vector3(0.055,0.034,0.042),"edb98d")
 rod(parent,Vector3(-0.031,1.485,0.197),Vector3(0,1.478,0.208),0.007,"a95d51")
 rod(parent,Vector3(0,1.478,0.208),Vector3(0.032,1.490,0.196),0.007,"a95d51")
 ball(parent,Vector3(0,1.469,0.204),Vector3(0.043,0.016,0.009),"e6a18a")
 # Freckles use warm tones instead of high contrast black dots.
 for side: int in [-1,1]:
  for i in 3:
   ball(parent,Vector3(side*(0.123+i*0.018),1.552+(i%2)*0.012,0.198-i*0.009),Vector3.ONE*0.008,"b67455")
 if male:
  _short_hair(parent)
 else:
  _hair(parent)
  var hat := Node3D.new()
  hat.name = "SunHat"
  parent.add_child(hat)
  _hat(hat)

static func _short_hair(parent: Node3D) -> void:
 # A fitted cap with sculpted swept locks, open ears and a readable side part.
 profile(parent,[Vector4(1.70,0.239,0.195,-0.017),Vector4(1.78,0.218,0.179,-0.020),Vector4(1.84,0.150,0.124,-0.020),Vector4(1.87,0.001,0.001,-0.020)],"3c3028")
 for side in [-1,1]:
  ball(parent,Vector3(side*0.232,1.66,-0.035),Vector3(0.048,0.19,0.27),"49352a")
  rod(parent,Vector3(side*0.231,1.67,0.07),Vector3(side*0.235,1.58,0.03),0.013,"4d382b")
 for i in 6:
  var lock := ball(parent,Vector3(-0.15+i*0.058,1.77+i*0.008,0.139-i*0.006),Vector3(0.105,0.13,0.115),"62452e" if i%2 else "745137")
  lock.rotation.z = -0.38
 for side in [-1,1]:
  rod(parent,Vector3(side*0.155,1.72,0.188),Vector3(side*0.065,1.724,0.203),0.011,"4b3528")
 # Soft jaw shading rather than a painted beard mask.
 profile(parent,[Vector4(1.382,0.045,0.053,0.035),Vector4(1.410,0.122,0.106,0.042),Vector4(1.439,0.159,0.130,0.038)],"b17a59",32)
static func _hair(parent: Node3D) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var sides := 64
 var rows := 16
 for row in rows:
  for col in sides:
   var points: Array[Vector3] = []
   for pair in [[row,col],[row+1,col],[row+1,col+1],[row,col+1]]:
    var a := float(pair[1])*TAU/sides
    var front := pow(maxf(cos(a),0),4)
    var hem := lerpf(1.385,1.722,front)+0.008*sin(a*7)
    var end := acos(clampf((hem-1.60)/0.25,-1,1))
    var latitude := end*float(pair[0])/rows
    points.append(Vector3(sin(a)*sin(latitude)*0.274,1.60+cos(latitude)*0.25,cos(a)*sin(latitude)*0.225-0.015))
   for index in [0,1,2,0,2,3]: st.add_vertex(points[index])
 st.generate_normals()
 put(parent,st.commit(),Vector3.ZERO,"593b2b")
 # Sculpted side-swept fringe, broad curved locks instead of dangling sausages.
 for i in 5:
  var fringe := ball(parent,Vector3(-0.15+i*0.062,1.740-i*0.010,0.180+i*0.003),Vector3(0.115,0.102,0.060),"69472f" if i%2 else "785235")
  fringe.rotation.z = -0.35
 for side: int in [-1,1]:
  var lock := ball(parent,Vector3(side*0.239,1.520,-0.015),Vector3(0.080,0.285,0.125),"62422d")
  lock.rotation.z = side*0.08
  for strand in 3:
   rod(parent,Vector3(side*(0.240+strand*0.006),1.62,-0.005-strand*0.025),Vector3(side*(0.242+strand*0.005),1.43,-0.025-strand*0.025),0.003,"8a603e")
 # Back hair sheen follows the cap surface, not a flat decal.
 for i in 13:
  var a := PI*0.5+float(i)*PI/12
  var last := Vector3.ZERO
  for j in 9:
   var latitude := 0.75+float(j)*1.55/8
   var point := Vector3(sin(a)*sin(latitude)*0.276,1.60+cos(latitude)*0.25,cos(a)*sin(latitude)*0.228-0.015)
   if j>0: rod(parent,last,point,0.0025,"805736" if i%2 else "705033")
   last = point
static func _hat(parent: Node3D) -> void:
 profile(parent,[Vector4(2.025,0.001,0.001,0),Vector4(2.023,0.11,0.11,0),Vector4(2.006,0.180,0.180,0),Vector4(1.97,0.205,0.205,0),Vector4(1.86,0.223,0.223,0),Vector4(1.84,0.275,0.275,0),Vector4(1.81,0.350,0.350,0),Vector4(1.795,0.365,0.365,0),Vector4(1.782,0.350,0.350,0),Vector4(1.813,0.267,0.267,0),Vector4(1.825,0.220,0.220,0)],"c9a26c")
 # Closely woven straw, staggered stitching and a rolled brim edge.
 for i in 9:
  var radius := 0.233+i*0.014
  ring(parent,Vector2.ONE*radius,1.84-(radius-0.233)*0.34,0.0025,"e3c18a" if i%2 else "b78d57")
 ring(parent,Vector2.ONE*0.360,1.797,0.006,"b18850")
 for i in 48:
  var a := TAU*i/48
  rod(parent,Vector3(sin(a)*0.245,1.837,cos(a)*0.245),Vector3(sin(a)*0.348,1.802,cos(a)*0.348),0.0015,"d4b17b")
 for i in 8:
  var y := 1.89+i*0.015
  var radius := 0.221-(y-1.89)*0.17
  ring(parent,Vector2.ONE*radius,y,0.0025,"e0bc80" if i%2 else "b58c56")
 for i in 6:
  var radius := 0.025+i*0.028
  ring(parent,Vector2.ONE*radius,2.026-0.019*pow(radius/0.18,2),0.002,"dfbd83")
 profile(parent,[Vector4(1.86,0.225,0.225,0),Vector4(1.91,0.216,0.216,0)],"226f9f")
 ring(parent,Vector2.ONE*0.225,1.863,0.002,"60b1cf")
 ring(parent,Vector2.ONE*0.217,1.908,0.002,"71b8cf")
 for sign_value: int in [-1,1]:
  var bow := ball(parent,Vector3(-0.218,1.88,sign_value*0.055),Vector3(0.070,0.040,0.110),"318ab2")
  bow.rotation.y = sign_value*0.25
 ball(parent,Vector3(-0.247,1.884,0),Vector3(0.040,0.048,0.040),"64b7cf")
static func clothes(parent: Node3D) -> void:
 ball(parent,Vector3(0,1.17,0),Vector3(0.37,0.43,0.25),"e3a577")
 ball(parent,Vector3(0,1.345,0),Vector3(0.135,0.18,0.13),"e1a171")
 profile(parent,[Vector4(0.965,0.167,0.118,0),Vector4(1.04,0.173,0.123,0),Vector4(1.16,0.189,0.130,0),Vector4(1.25,0.177,0.119,0)],"e66a59")
 # Narrow shoulder straps and a shaped neckline; garment edge and seams read
 # as clothing instead of a single painted cylinder.
 for side: int in [-1,1]:
  rod(parent,Vector3(side*0.130,1.23,0.099),Vector3(side*0.148,1.315,0.027),0.022,"e66c59")
  rod(parent,Vector3(side*0.148,1.315,0.027),Vector3(side*0.130,1.25,-0.091),0.022,"e66c59")
  ball(parent,Vector3(side*0.185,1.258,0),Vector3(0.128,0.15,0.15),"e1a171")
  rod(parent,Vector3(side*0.142,0.998,0.071),Vector3(side*0.155,1.205,0.080),0.003,"bc5048")
 rod(parent,Vector3(-0.13,1.25,0.105),Vector3(0,1.235,0.124),0.004,"f59a7e")
 rod(parent,Vector3(0,1.235,0.124),Vector3(0.13,1.25,0.105),0.004,"f59a7e")
 ring(parent,Vector2(0.168,0.120),0.975,0.004,"eb816b")
 # High-waisted shorts with rounded openings, rolled hems, stitched pockets,
 # a waist button and belt loops. No thin cardboard box flaps at the crotch.
 profile(parent,[Vector4(0.91,0.185,0.130,0),Vector4(0.99,0.174,0.125,0),Vector4(1.004,0.170,0.123,0)],"258d98")
 for side: int in [-1,1]:
  var leg := Node3D.new()
  leg.name = "ShortLeg_%d" % side
  parent.add_child(leg)
  leg.position.x = side*0.092
  profile(leg,[Vector4(0.775,0.092,0.122,0),Vector4(0.88,0.098,0.129,0),Vector4(0.94,0.096,0.127,0)],"359fa6")
  ring(leg,Vector2(0.094,0.124),0.792,0.008,"66bdba")
  rod(parent,Vector3(side*0.157,0.964,0.066),Vector3(side*0.126,0.895,0.110),0.003,"8ad3c6")
  rod(parent,Vector3(side*0.126,0.895,0.110),Vector3(side*0.082,0.884,0.125),0.003,"8ad3c6")
  rod(parent,Vector3(side*0.134,0.965,-0.079),Vector3(side*0.133,0.900,-0.090),0.003,"70c3bd")
  rod(parent,Vector3(side*0.133,0.900,-0.090),Vector3(side*0.060,0.890,-0.123),0.003,"70c3bd")
  rod(parent,Vector3(side*0.063,0.980,0.117),Vector3(side*0.065,1.002,0.119),0.006,"64bab5")
 ball(parent,Vector3(0,0.983,0.130),Vector3(0.018,0.018,0.010),"dcc794")
 # Small daisy pin, a single readable accent rather than fine noisy decoration.
 for i in 5:
  var a := TAU*i/5
  ball(parent,Vector3(0.091+cos(a)*0.015,1.18+sin(a)*0.015,0.117),Vector3(0.021,0.021,0.010),"f7e7c6")
 ball(parent,Vector3(0.091,1.18,0.125),Vector3.ONE*0.012,"f4ca65")

static func male_clothes(parent: Node3D) -> void:
 ball(parent,Vector3(0,1.345,0),Vector3(0.15,0.18,0.14),"e1a171")
 profile(parent,[Vector4(0.96,0.184,0.127,0),Vector4(1.09,0.203,0.137,0),Vector4(1.25,0.215,0.137,0),Vector4(1.30,0.158,0.10,0)],"4287ac")
 for side in [-1,1]:
  var sleeve := ball(parent,Vector3(side*0.208,1.25,0),Vector3(0.18,0.19,0.22),"4c94b7")
  sleeve.rotation.z = side*0.18
  var collar := box(parent,Vector3(side*0.057,1.305,0.082),Vector3(0.10,0.09,0.035),"a7d6db")
  collar.rotation.z = side*0.38
  rod(parent,Vector3(side*0.167,1.00,0.077),Vector3(side*0.195,1.19,0.078),0.003,"286081")
  var leg := Node3D.new()
  leg.name = "ShortLeg_%d" % side
  leg.position.x = side*0.092
  parent.add_child(leg)
  profile(leg,[Vector4(0.76,0.097,0.126,0),Vector4(0.87,0.103,0.135,0),Vector4(0.95,0.100,0.130,0)],"d4bd88")
  ring(leg,Vector2(0.097,0.126),0.778,0.007,"f2d9a3")
 profile(parent,[Vector4(0.92,0.192,0.134,0),Vector4(1.00,0.180,0.127,0)],"b49a67")
 for i in 4: ball(parent,Vector3(0,1.06+i*0.055,0.138),Vector3.ONE*0.012,"eee3bd")
 rod(parent,Vector3(0,1.02,0.14),Vector3(0,1.28,0.14),0.003,"245b7b")
 for side in [-1,1]:
  rod(parent,Vector3(side*0.16,0.96,0.09),Vector3(side*0.10,0.87,0.13),0.004,"8d7852")
 box(parent,Vector3(-0.11,1.19,0.135),Vector3(0.074,0.07,0.012),"70b1c5")
