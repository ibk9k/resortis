class_name StructureModels
extends Node3D
## All physical vertices, including feet, poles and trim, stay in the catalogue
## XZ reservation. Height is independent of the floor; posts cannot lean.
const FacilityModels = preload("res://mockups/facilities/concept_models.gd")

var kind := "bench"
func build(id: String) -> void:
 kind = id
 name = id.to_pascal_case()+"Model"
 match id:
  "bench": _bench()
  "hedge": _planter()
  "volleyball": _court()
  "dolphin_statue": _dolphin_statue()
  _:
   if id in ResortServices.EXPANSION:
    var model := FacilityModels.new()
    model.build(id)
    var size := ResortCatalog.footprint(id)
    model.position = Vector3(size.x - 1, 0.0, size.y - 1) * 0.5
    add_child(model)

func _dolphin_statue() -> void:
 var p := ModelPrimitives
 p.box(self, Vector3(0.5, 0.08, 0), Vector3(1.73, 0.16, 0.86), "345950")
 p.box(self, Vector3(0.5, 0.24, 0), Vector3(1.48, 0.25, 0.68), "4b7668")
 p.box(self, Vector3(0.5, 0.39, 0), Vector3(1.56, 0.08, 0.76), "7aa18a")
 p.box(self, Vector3(0.5, 0.26, 0.349), Vector3(0.44, 0.14, 0.026), "b97d3c")
 for x in [0.33, 0.67]:
  p.ball(self, Vector3(x, 0.26, 0.367), Vector3.ONE * 0.036, "f3c879")
 var swell := p.ball(self, Vector3(0.17, 0.67, 0), Vector3(0.60, 0.65, 0.56), "3d8071")
 swell.rotation.z = -0.36
 p.ball(self, Vector3(-0.01, 0.85, 0), Vector3(0.36, 0.68, 0.39), "62a38e").rotation.z = 0.54
 p.ball(self, Vector3(-0.19, 1.03, 0), Vector3(0.19, 0.30, 0.28), "83bd9c")
 var body := p.ball(self, Vector3(0.49, 1.40, 0), Vector3(1.17, 0.48, 0.47), "be8246")
 body.rotation.z = 0.57
 p.ball(self, Vector3(0.85, 1.61, 0), Vector3(0.59, 0.43, 0.41), "cc9353").rotation.z = 0.28
 p.ball(self, Vector3(0.65, 1.30, 0), Vector3(0.77, 0.20, 0.36), "e0aa66").rotation.z = 0.57
 p.ball(self, Vector3(1.12, 1.56, 0), Vector3(0.44, 0.145, 0.235), "d09b5c").rotation.z = 0.08
 p.ball(self, Vector3(0.07, 1.10, 0), Vector3(0.57, 0.22, 0.24), "ae713b").rotation.z = 0.54
 p.ball(self, Vector3(0.40, 1.68, 0), Vector3(0.17, 0.45, 0.13), "a76838").rotation.z = 0.53
 for side in [-1, 1]:
  p.ball(self, Vector3(-0.13, 1.02, side * 0.20), Vector3(0.24, 0.10, 0.44), "b77a42").rotation.y = side * 0.50
  p.ball(self, Vector3(0.57, 1.28, side * 0.20), Vector3(0.49, 0.12, 0.23), "9f6234").rotation.z = 0.39
  p.ball(self, Vector3(0.97, 1.65, side * 0.184), Vector3.ONE * 0.065, "553322")
func _bench() -> void:
 var p := ModelPrimitives
 # Two tiles long along +X, one deep along +Z, with inset feet and arms.
 for x in [-0.28,1.28]:
  for z in [-0.28,0.28]:
   p.box(self,Vector3(x,0.23,z),Vector3(0.11,0.46,0.11),"55301e")
   p.box(self,Vector3(x,0.035,z),Vector3(0.15,0.07,0.15),"30291f")
  p.box(self,Vector3(x,0.70,-0.28),Vector3(0.10,1.1,0.10),"80421f")
  p.box(self,Vector3(x,0.78,0),Vector3(0.14,0.09,0.81),"bb732b")
 p.box(self,Vector3(0.5,0.43,0),Vector3(1.85,0.13,0.83),"613717")
 for i in 11:
  var x := -0.32+i*0.164
  p.box(self,Vector3(x,0.48,0),Vector3(0.154,0.045,0.80),"bc782f" if i%3 else "a45a24")
  p.box(self,Vector3(x,0.88,-0.32),Vector3(0.145,0.66,0.06),"b57835" if i%3 else "955023")
 p.box(self,Vector3(0.5,1.23,-0.32),Vector3(1.88,0.09,0.13),"d18b3c")
 p.box(self,Vector3(0.5,0.54,0.01),Vector3(1.60,0.13,0.67),"1265a3")
 p.box(self,Vector3(0.5,0.61,0.01),Vector3(1.56,0.045,0.65),"338bcb")
 for x in [-0.07,1.07]:
  var pillow := p.box(self,Vector3(x,0.85,-0.17),Vector3(0.36,0.40,0.16),"e7e6d8")
  pillow.rotation.x = -0.12
  p.box(self,Vector3(x,0.86,-0.075),Vector3(0.29,0.32,0.018),"246caa")
  for s in [-1,1]:
   p.rod(self,Vector3(x-0.10,0.76,-0.06),Vector3(x+0.10,0.96,-0.06),0.012,"a5d9e1")
   p.rod(self,Vector3(x-0.10,0.96,-0.06),Vector3(x+0.10,0.76,-0.06),0.012,"a5d9e1")
func _planter() -> void:
 var p := ModelPrimitives
 # An open cedar trough: recessed soil, framed plank faces, inset feet and a
 # continuous rim. Every leaf and petal also stays in the 2 x 1 reservation.
 for x in [-0.30,1.30]:
  for z in [-0.29,0.29]: p.box(self,Vector3(x,0.08,z),Vector3(0.18,0.16,0.17),"513624")
 p.box(self,Vector3(0.5,0.17,0),Vector3(1.80,0.09,0.72),"634125")
 for row in 4:
  var y := 0.24+row*0.115
  for z in [-0.37,0.37]:
   p.box(self,Vector3(0.5,y,z),Vector3(1.80,0.106,0.07),["ad713a","bc8246","a86a35","c38b4c"][row])
   for grain in 3:
    p.rod(self,Vector3(-0.28+grain*0.11,y-0.024+grain*0.022,z+signf(z)*0.037),Vector3(1.20-grain*0.10,y-0.017+grain*0.020,z+signf(z)*0.037),0.003,"8e5a30")
  for x in [-0.39,1.39]: p.box(self,Vector3(x,y,0),Vector3(0.07,0.106,0.73),"a66b36" if row%2 else "bf8447")
 for z in [-0.395,0.395]:
  p.box(self,Vector3(0.5,0.68,z),Vector3(1.93,0.095,0.13),"d6a161")
  p.box(self,Vector3(0.5,0.725,z),Vector3(1.91,0.015,0.12),"e0b176")
 for x in [-0.40,1.40]:
  p.box(self,Vector3(x,0.68,0),Vector3(0.13,0.095,0.68),"ca9656")
  for z in [-0.37,0.37]:
   p.box(self,Vector3(x,0.43,z),Vector3(0.10,0.52,0.105),"6c5032")
   for y in [0.25,0.58]:
    p.ball(self,Vector3(x,y,z+signf(z)*0.057),Vector3.ONE*0.028,"b2b19b")
 p.box(self,Vector3(0.5,0.61,0),Vector3(1.69,0.035,0.60),"3e3024")
 var random := RandomNumberGenerator.new()
 random.seed = 419
 for i in 36:
  var x := random.randf_range(-0.22,1.22)
  var z := random.randf_range(-0.21,0.21)
  var y := random.randf_range(0.78,1.10)
  var tip := Vector3(x,y,z)
  p.rod(self,Vector3(x,0.62,z),tip,0.009,"3e7032")
  for side in [-1,1]:
   var leaf := p.ball(self,tip+Vector3(side*0.065,-0.06,0),Vector3(0.19,0.07,0.11),["3d7b37","528c3b","6c9f45"][i%3])
   leaf.rotation.z = side*0.42
   leaf.rotation.y = random.randf_range(-0.7,0.7)
 if true:
  for i in 13:
   var x := -0.12+float(i%7)*0.20
   var z := -0.17 if i<7 else 0.18
   var y := 1.04+0.13*sin(float(i)*1.7)
   var blossom := Node3D.new()
   blossom.position = Vector3(x,y,z)
   blossom.rotation_degrees = Vector3(-25 if i%2 else 24,i*63.0,14*sin(i))
   add_child(blossom)
   p.rod(self,Vector3(x,0.63,z),blossom.position,0.011,"3f7432")
   for petal in 5:
    var angle := petal*TAU/5
    var node := p.ball(blossom,Vector3(cos(angle)*0.066,0,sin(angle)*0.066),Vector3(0.105,0.035,0.075),["e56a8e","ed8ba4","f5cd5e"][i%3])
    node.rotation.y = -angle
   p.ball(blossom,Vector3(0,0.025,0),Vector3(0.05,0.04,0.05),"e4aa35")
func _court() -> void:
 var p := ModelPrimitives
 var markings := Node3D.new()
 markings.name = "Markings"
 add_child(markings)
 var net := Node3D.new()
 net.name = "Net"
 add_child(net)
 # The existing textured beach is the court surface. Only its markings and
 # equipment are sprites, avoiding a flat slab of differently colored sand.
 for z in [-0.22,4.22]:
  p.box(markings,Vector3(3.5,0.018,z),Vector3(7.45,0.012,0.035),"fff4da")
 for x in [-0.22,7.22,3.5]:
  p.box(markings,Vector3(x,0.018,2),Vector3(0.035,0.012,4.47),"fff4da")
 # The net is an actual vertical plane: height on world Y, width along Z.
 for z in [-0.25,4.25]:
  p.cylinder(net,Vector3(3.5,0.92,z),0.065,1.84,"a86d31")
  p.cylinder(net,Vector3(3.5,1.86,z),0.075,0.10,"1f72b2")
  p.cylinder(net,Vector3(3.5,0.04,z),0.11,0.08,"585752")
 for y in range(7):
  var height := 0.70+y*0.17
  p.rod(net,Vector3(3.5,height,-0.25),Vector3(3.5,height,4.25),0.012,"263d47")
 for i in 32:
  var z := -0.25+i*4.50/31
  p.rod(net,Vector3(3.5,0.70,z),Vector3(3.5,1.72,z),0.009,"283d42")
 p.rod(net,Vector3(3.5,1.76,-0.25),Vector3(3.5,1.76,4.25),0.035,"2678ba")
