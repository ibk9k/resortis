extends Node3D
## Editable concept geometry. Footprints are centered on the model's origin.
const P = preload("res://scripts/content/model_primitives.gd")
const WOOD := "a86230"
const DARK := "573827"
const CEDAR := "ca8749"
const CREAM := "f9dfaf"
const TEAL := "288981"
const BLUE := "246fa0"

const CONCEPTS := {
	"gym": {"name":"Indoor fitness studio", "size":Vector2i(8,6), "center":Vector2(8.5,-3.5), "note":"Cutaway gym with cardio, free weights and rubber flooring"},
	"sauna": {"name":"Cedar sauna", "size":Vector2i(6,4), "center":Vector2(13.5,-10), "note":"Cutaway sauna with tiered seating and a stone heater"},
	"ice_cream": {"name":"Ice cream cart", "size":Vector2i(3,2), "center":Vector2(22.9,-3.5), "note":"Retro mint cart with a cone sign and a curved canopy"},
	"restaurant": {"name":"Seaside bistro", "size":Vector2i(10,8), "center":Vector2(33.5,-4.75), "note":"Terracotta terrace, full-size chairs and an open kitchen"},
	"yoga": {"name":"Yoga pavilion", "size":Vector2i(6,4), "center":Vector2(6,-10), "note":"Timber pergola, reed shade and six mat positions"},
	"massage": {"name":"Massage cabana", "size":Vector2i(5,4), "center":Vector2(20.5,-10), "note":"Two treatment tables behind a linen privacy screen"},
	"gear": {"name":"Beach gear kiosk", "size":Vector2i(4,3), "center":Vector2(16,-3.5), "note":"A thatched hut with a board rack and towel counter"},
	"splash": {"name":"Kids' splash garden", "size":Vector2i(7,6), "center":Vector2(19.5,-16.5), "note":"Round mosaic pad, jets and shaded seating"},
	"pickleball": {"name":"Pickleball court", "size":Vector2i(11,6), "center":Vector2(7.5,-16.5), "note":"Striped court with net and a shaded sideline"}
}

func build(kind: String) -> void:
	name = kind.to_pascal_case()
	match kind:
		"gym": _gym()
		"sauna": _sauna()
		"ice_cream": _ice_cream()
		"restaurant": _restaurant()
		"yoga": _yoga()
		"massage": _massage()
		"gear": _gear()
		"splash": _splash()
		"pickleball": _pickleball()

func _box(x: float, y: float, z: float, w: float, h: float, d: float, tint: String) -> MeshInstance3D:
	return P.box(self, Vector3(x,y,z), Vector3(w,h,d), tint)

func _round(x: float, y: float, z: float, radius: float, height: float, tint: String) -> MeshInstance3D:
	return P.cylinder(self, Vector3(x,y,z), radius, height, tint)

func _deck(w: float, d: float) -> void:
	_box(0,0.10,0,w,0.20,d,DARK)
	var count := ceili(w / 0.28)
	for i in count:
		var pitch := w / count
		_box(-w*0.5 + pitch*(i+0.5),0.218,0,pitch-0.013,0.055,d-0.03,[CEDAR,"b6743d","d99653","bc7c43"][i%4])
	_box(0,0.095,d*0.5+0.08,1.40,0.19,0.25,WOOD)
	_box(0,0.034,d*0.5+0.22,1.55,0.068,0.23,CEDAR)

func _post(x: float, z: float, h: float, base := 0.23) -> void:
	_box(x,base+h*0.5,z,0.17,h,0.17,WOOD)
	_box(x,base+0.10,z,0.24,0.20,0.24,DARK)
	_box(x,base+h-0.12,z,0.23,0.10,0.23,CEDAR)

func _slat_wall(x: float, z: float, width: float, height: float, base: float, tint := WOOD) -> void:
	for i in ceili(width / 0.22):
		var pitch := width / ceili(width / 0.22)
		_box(x-width*0.5 + pitch*(i+0.5),base+height*0.5,z,pitch-0.016,height,0.12,tint if i%4 else CEDAR)
	_box(x,base+height-0.045,z+0.03,width,0.10,0.15,DARK)

func _roof(x: float, z: float, w: float, d: float, height: float, palette: Array) -> void:
	var pitch := 0.37
	var slope := d*0.5 / cos(pitch)
	var count := ceili(w / 0.22)
	for i in count:
		var at := x - w*0.5 + (i+0.5)*w/count
		for side in [-1.0,1.0]:
			_box(at,height-0.09,z+side*d*0.25,w/count+0.006,0.14,slope,palette[i%palette.size()]).rotation.x = side*pitch
	for side in [-1.0,1.0]:
		_box(x,height-0.09-tan(pitch)*d*0.25,z+side*d*0.5,w,0.12,0.10,DARK)
	var ridge := height-0.04+tan(pitch)*d*0.25
	P.rod(self, Vector3(x-w*0.49,ridge,z), Vector3(x+w*0.49,ridge,z), 0.095, CEDAR)

func _plant(x: float, z: float, y := 0.23, accent := "f89b80") -> void:
	P.cylinder(self, Vector3(x,y+0.13,z), 0.18,0.26,"ad623c",0.24)
	_round(x,y+0.25,z,0.24,0.055,"df9660")
	_round(x,y+0.286,z,0.197,0.027,"543921")
	for i in 7:
		var a := float(i)*TAU/7.0
		var start := Vector3(x,y+0.28,z)
		var end := start+Vector3(cos(a)*0.29,0.31+float(i%3)*0.10,sin(a)*0.29)
		P.rod(self,start,end,0.024,"56863f")
		var leaf := P.ball(self,start.lerp(end,0.78),Vector3(0.31,0.065,0.12),["478337","5f9e45","7db451"][i%3])
		leaf.rotation.y = -a
		leaf.rotation.z = 0.42*cos(a)
		if i%2==0: P.ball(self,end,Vector3(0.11,0.071,0.10),accent)

func _bench(x: float, z: float, w: float, tint: String, base := 0.23) -> void:
	for offset in [-w*0.35,w*0.35]:
		_box(x+offset,base+0.16,z,0.12,0.32,0.35,DARK)
		_box(x+offset,base+0.43,z-0.19,0.09,0.56,0.09,WOOD)
	_box(x,base+0.34,z,w,0.10,0.44,tint)
	_box(x,base+0.60,z-0.19,w,0.18,0.09,tint)

func _lamp(x: float, y: float, z: float) -> void:
	_box(x,y,z,0.17,0.22,0.17,"efb55f")
	_box(x,y+0.126,z,0.21,0.064,0.21,DARK)
	_box(x,y-0.115,z,0.19,0.055,0.19,WOOD)

func _gym() -> void:
	_box(0,0.115,0,7.61,0.23,5.56,"8f988f")
	_box(0,0.235,0,7.57,0.032,5.52,"304448")
	for row in 7:
		for col in 10:
			_box(-3.37+col*0.75,0.254,-2.34+row*0.78,0.737,0.026,0.766,["415559","485d60","43575a"][(row+col)%3])
	_box(0,1.56,-2.67,7.47,2.66,0.17,"c3c9b4")
	_box(-3.69,1.56,-0.17,0.17,2.66,4.88,"aebcae")
	_box(0,2.83,-2.44,7.49,0.17,0.57,"526d68")
	_box(-3.55,2.83,-0.15,0.41,0.17,5.15,"526d68")
	_box(0,0.36,-2.53,7.40,0.18,0.08,"71837d")
	for x in [-2.86,-1.49,-0.12]:
		_box(x,1.88,-2.555,1.17,1.28,0.08,"556f70")
		_box(x,1.88,-2.497,1.02,1.12,0.028,"7fa9aa")
		_box(x,2.05,-2.47,0.025,0.83,0.022,"e0e9d4")
		_box(x,1.38,-2.45,1.16,0.075,0.075,"f2e7cc")
	for z in [-1.72,-0.17,1.38]:
		_box(-3.586,1.79,z,0.08,1.36,1.24,"678b8b")
		_box(-3.529,1.79,z,0.03,1.17,1.08,"b3d2c6")
		_box(-3.493,1.79,z,0.025,1.16,0.054,"728e84")
	for x in [-2.62,-1.39,-0.16]:
		_box(x,0.385,-1.19,0.70,0.22,1.53,"233b44")
		_box(x,0.502,-1.19,0.51,0.027,1.23,"657b78")
		for side in [-0.28,0.28]:
			P.rod(self,Vector3(x+side,0.49,-1.78),Vector3(x+side,1.41,-1.67),0.038,"b9c3b5")
		_box(x,1.43,-1.67,0.61,0.16,0.22,"354e58")
		_box(x,1.52,-1.63,0.36,0.035,0.13,"85d0bd")
	_box(2.32,1.18,-2.50,1.68,1.42,0.048,"b6d2cd")
	_box(2.31,0.57,-2.11,1.85,0.60,0.57,"344b51")
	_box(2.31,0.88,-2.11,1.89,0.07,0.63,"6b8380")
	for i in 6:
		var x := 1.62 + i*0.275
		P.rod(self,Vector3(x-0.095,0.97,-2.07),Vector3(x+0.095,0.97,-2.07),0.023,"c2c9bc")
		for side in [-0.086,0.086]:
			_round(x+side,0.98,-2.07,0.06+0.007*i,0.050,"293e48").rotation.z = PI/2.0
	for x in [1.38,3.05]:
		_box(x,0.94,-0.81,0.075,1.34,0.09,"476572")
		_box(x,0.32,-0.50,0.15,0.10,0.71,"344f60")
		_round(x,1.39,-0.82,0.19,0.075,"374e55").rotation.z = PI/2.0
	P.rod(self,Vector3(1.13,1.39,-0.82),Vector3(3.29,1.39,-0.82),0.033,"c7cdc4")
	_box(2.20,0.73,-0.23,0.53,0.13,1.39,"293e48")
	for z in [-0.73,0.26]: _box(2.20,0.49,z,0.17,0.44,0.18,"607477")
	for x in [-2.38,-1.22,-0.06]:
		_box(x,0.278,1.31,0.81,0.028,1.46,"759d94")
		_round(x,0.33,0.76,0.06,0.75,"acc9a9").rotation.z = PI/2.0
	_box(0,0.14,2.705,7.61,0.28,0.15,"d4c8a9")
	_box(0,0.069,2.856,1.92,0.138,0.19,"e0d3b0")
	_box(3.66,0.50,1.44,0.17,0.51,2.47,"c3c9b4")
	for z in [0.40,2.48]:
		_box(3.66,1.14,z,0.11,0.88,0.12,"526d68")
	_box(3.66,1.53,1.44,0.10,0.085,2.17,"526d68")
	_plant(3.18,2.04,0.27,"ebad7e")

func _sauna() -> void:
	_box(0,0.105,0,5.71,0.21,3.70,"4d5d5b")
	for i in 23:
		_box(-2.70+i*0.240,0.22,0,0.224,0.052,3.58,["ac734a","bf8855","a76d43"][i%3])
	_slat_wall(-0.55,-1.68,4.50,2.20,0.25,"965c38")
	for z in [-1.46,-1.25,-1.04,-0.83,-0.62,-0.41,-0.20,0.01,0.22,0.43,0.64,0.85,1.06,1.27]:
		_box(-2.74,1.35,z,0.17,2.20,0.196,"ba8150")
	_box(-0.54,2.51,-1.51,4.63,0.16,0.48,"754b37")
	_box(-2.63,2.51,-0.04,0.46,0.16,3.15,"754b37")
	_box(-0.68,1.75,-1.577,3.28,0.065,0.035,"f6cc7e")
	for tier in 2:
		var y := 0.66 + tier*0.43
		var z := -0.66 - tier*0.57
		_box(-0.74,y-0.21,z,3.54,0.42,0.66,"875334")
		for slat in 5:
			_box(-0.74,y,z-0.28+slat*0.14,3.57,0.10,0.129,["d29d69","c68d58"][slat%2])
	_box(-2.17,0.55,0.41,0.83,0.52,1.61,"935e3c")
	for i in 5:
		_box(-2.52+i*0.17,0.83,0.41,0.146,0.10,1.64,"d39b65")
	_box(0.88,0.33,0.57,1.00,0.17,1.03,"716a5b")
	_round(0.88,0.67,0.57,0.39,0.57,"535b59")
	_round(0.88,0.98,0.57,0.43,0.12,"717976")
	for i in 7:
		var a := float(i)*TAU/7.0
		P.ball(self,Vector3(0.88+cos(a)*0.23,1.09,0.57+sin(a)*0.23),Vector3(0.24,0.19,0.20),["848a7e","707973","9a9c87"][i%3])
	_round(-1.63,0.36,1.19,0.17,0.23,"b78255")
	_round(-1.63,0.49,1.19,0.175,0.04,"d4a06c")
	P.rod(self,Vector3(-1.67,0.43,1.22),Vector3(-1.42,0.79,1.29),0.025,"d2a370")
	for z in [-1.50,1.47]:
		_box(1.55,1.30,z,0.17,2.11,0.17,"8e5e3d")
	_box(1.55,2.37,0,0.15,0.16,3.10,"ab7549")
	_box(-1.72,0.39,1.70,2.02,0.29,0.16,"a2714c")
	_round(2.18,0.44,-0.05,0.52,0.45,"687b77")
	_round(2.18,0.68,-0.05,0.54,0.080,"a8af9b")
	_round(2.18,0.725,-0.05,0.46,0.021,"6ab2bd")
	_plant(2.25,1.10,0.25,"c6ac73")

func _ice_cream() -> void:
	_box(0,0.51,0.04,1.88,0.59,0.94,"6d9f8d")
	_box(0,0.73,0.04,1.91,0.19,0.96,"b0d3b7")
	_box(0,0.31,0.04,1.86,0.10,0.95,"4e7b6f")
	_box(0,0.852,0.04,2.01,0.078,1.03,"f6deb4")
	_box(0,0.53,0.526,1.47,0.30,0.034,"cfdec2")
	_box(0,0.53,0.549,1.23,0.22,0.022,"7da795")
	for x in [-0.72,0.72]:
		for z in [-0.43,0.51]:
			_round(x,0.235,z,0.223,0.083,"424f49").rotation.x = PI/2.0
			_round(x,0.235,z+signf(z)*0.058,0.099,0.034,"dab58a").rotation.x = PI/2.0
			var post_x: float = 0.98 if x > 0.0 and z > 0.0 else x
			_box(post_x,1.405,z*0.86,0.062,1.10,0.062,"a77b57")
	for i in 6:
		var x := -0.75+i*0.30
		_box(x,0.925,0.043,0.252,0.095,0.40,"9b9f88")
		_box(x,0.98,0.043,0.192,0.028,0.32,["e7a0a2","f2d196","a5bd83","b17f5b","f3e1b8","d9b2bf"][i])
	for i in 8:
		var x := -0.91+i*0.26
		_box(x,1.993,-0.08,0.254,0.075,1.06,"f8dfb4")
		P.ball(self,Vector3(x,1.967,0.42),Vector3(0.27,0.13,0.11),"d9977e")
	P.cylinder(self,Vector3(0.62,2.26,0.02),0.036,0.36,"c49160",0.175)
	P.ball(self,Vector3(0.62,2.51,0.02),Vector3(0.38,0.33,0.36),"e7a3ac")
	P.ball(self,Vector3(0.69,2.65,0.02),Vector3(0.25,0.22,0.25),"f4d9ab")
	P.rod(self,Vector3(-0.94,0.64,-0.17),Vector3(-1.30,0.64,-0.17),0.029,"725841")
	P.rod(self,Vector3(-0.94,0.64,0.27),Vector3(-1.30,0.64,0.27),0.029,"725841")

func _restaurant() -> void:
	_box(0,0.116,0,9.57,0.232,7.24,"937051")
	for x in 13:
		for z in 10:
			_box(-4.42+x*0.736,0.243,-3.25+z*0.72,0.715,0.036,0.700,["c8815a","cf8a64","b77353","d29b73"][(x+z*3)%4])
	_box(0,0.098,3.73,1.86,0.196,0.29,"d5a37c")
	_box(0,0.046,3.885,2.05,0.092,0.19,"b67c57")
	var terrace_count := get_child_count()
	_box(0,1.38,-3.39,9.12,2.24,0.18,"e7c8a1")
	_box(0,0.45,-3.265,9.04,0.34,0.075,"bc8463")
	_box(0,2.47,-3.34,9.16,0.13,0.26,"ae7252")
	for x in [-4.23,4.23]:
		_box(x,1.48,-2.35,0.30,2.44,0.31,"efd4ae")
		_box(x,0.43,-2.35,0.45,0.32,0.44,"bc8463")
		_lamp(x,2.18,-2.16)
	_roof(0,-2.85,9.26,1.43,2.96,["ab593f","b56447","ad5c42","ba6b4c"])
	var worktop_start := get_child_count()
	_box(0,0.68,-2.16,7.20,0.85,0.91,"646e76")
	for i in 6:
		var x := -2.98+i*1.19
		_box(x,0.69,-1.686,1.10,0.67,0.04,"828a87")
		_box(x,0.84,-1.652,0.32,0.033,0.033,"d1b08a")
	_box(0,1.17,-2.16,7.31,0.13,1.02,"eddeb7")
	_box(-1.05,1.25,-2.33,1.23,0.076,0.63,"4d5756")
	for x in [-1.44,-1.05,-0.66]:
		_round(x,1.31,-2.33,0.115,0.048,"272e30")
	_round(-1.44,1.40,-2.33,0.17,0.108,"8e6959")
	_box(2.05,1.249,-2.12,1.04,0.067,0.56,"adb3a9")
	P.rod(self,Vector3(2.04,1.24,-2.29),Vector3(2.04,1.54,-2.29),0.025,"d8d4bd")
	P.rod(self,Vector3(2.04,1.53,-2.29),Vector3(2.04,1.53,-2.10),0.025,"d8d4bd")
	_box(0.55,1.267,-2.08,0.83,0.042,0.44,"a8734d")
	for x in [0.38,0.58,0.79]:
		_round(x,1.302,-2.01,0.059,0.06,"cf7655")
	# Open a staff aisle behind the counter inside the existing plot.
	for child in get_children().slice(worktop_start):
		(child as Node3D).position.z += 0.24
	for x in [-2.38,2.38]:
		for z in [-0.52,2.02]:
			_dining_table(x,z,z<0.0)
	_plant(-4.25,2.81,0.26,"d96f58")
	_plant(4.25,2.81,0.26,"d96f58")
	# Scale the furnishings vertically about the terrace, keeping the seats and aisles full width.
	var furniture := Node3D.new()
	furniture.name = "Furniture"
	var furnishings := get_children().slice(terrace_count)
	add_child(furniture)
	for child in furnishings:
		child.reparent(furniture, false)
	furniture.scale.y = ResortServices.BISTRO_VERTICAL_SCALE
	furniture.position.y = ResortServices.BISTRO_DECK * (1.0 - furniture.scale.y)

func _dining_table(x: float, z: float, shaded: bool) -> void:
	# The seat is 0.60 × 0.64. The table is 1.34 across, with its
	# undersurface about 0.22 above the cushion for knee clearance.
	_round(x,0.287,z,0.26,0.065,"6f5b4a")
	_round(x,0.638,z,0.10,0.70,"71594b")
	_round(x,1.077,z,0.67,0.13,"9d684d")
	_round(x,1.152,z,0.632,0.040,"debea0")
	for dx in [-0.34,0.34]:
		_round(x+dx,1.18,z,0.124,0.024,"fbebc9")
	_round(x,1.222,z-0.18,0.080,0.125,"52787b")
	_dining_chair(x-0.91,z,PI/2.0)
	_dining_chair(x+0.91,z,-PI/2.0)
	_dining_chair(x,z+0.91,PI)
	if shaded: _umbrella(x,z,1.17,1.05,2.75,"506779",false)

func _dining_chair(x: float, z: float, yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "DiningChair"
	chair.position = Vector3(x,0.26,z)
	chair.rotation.y = yaw
	add_child(chair)
	P.box(chair,Vector3(0,0.435,0),Vector3(0.60,0.09,0.64),"9e6e4f")
	P.box(chair,Vector3(0,0.497,-0.012),Vector3(0.56,0.060,0.58),"738d93")
	for dx in [-0.238,0.238]:
		for dz in [-0.243,0.243]:
			P.box(chair,Vector3(dx,0.225,dz),Vector3(0.065,0.45,0.065),"79543e")
		P.box(chair,Vector3(dx,0.68,-0.27),Vector3(0.067,0.52,0.064),"8e664b")
	P.box(chair,Vector3(0,0.893,-0.27),Vector3(0.58,0.092,0.072),"ac7956")
	P.box(chair,Vector3(0,0.715,-0.269),Vector3(0.48,0.095,0.044),"b88a64")

func _umbrella(x: float, z: float, base: float, radius: float, top: float, tint: String, striped := true) -> void:
	_round(x,base+0.042,z,0.16,0.08,"b4a485")
	_round(x,(top+base)*0.5,z,0.042,top-base,WOOD)
	var canopy := SurfaceTool.new()
	canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
	var colored := StandardMaterial3D.new()
	colored.albedo_color = Color(tint)
	colored.roughness = 0.9
	colored.cull_mode = BaseMaterial3D.CULL_DISABLED
	var light := colored.duplicate() as StandardMaterial3D
	light.albedo_color = Color(CREAM)
	for i in 10:
		var a := TAU*i/10.0
		var b := TAU*(i+1)/10.0
		var peak := Vector3(x,top+0.24,z)
		var one := Vector3(x+cos(a)*radius,top,z+sin(a)*radius)
		var two := Vector3(x+cos(b)*radius,top,z+sin(b)*radius)
		canopy.set_material(colored if i%2 or not striped else light)
		for v in [peak,two,one]:
			canopy.add_vertex(v)
		canopy.generate_normals()
		var wing := canopy.commit()
		var node := MeshInstance3D.new()
		node.mesh = wing
		add_child(node)
		canopy.clear()
		canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
		P.rod(self,one,two,0.019,tint)
	_round(x,top+0.26,z,0.066,0.10,CEDAR)

func _yoga() -> void:
	_deck(5.53,3.27)
	_box(0.86,0.253,1.43,0.84,0.014,0.32,"b48251")
	for x in [-2.51,2.51]:
		for z in [-1.43,-0.06]: _post(x,z,2.29)
		_box(x,2.54,-0.71,0.17,0.15,1.65,"916546")
	for z in [-1.43,-0.06]: _box(0,2.54,z,5.34,0.16,0.15,"a77b50")
	for i in 12:
		_box(-2.51+i*0.455,2.68,-0.71,0.086,0.10,1.74,"c49a66")
	_box(0,2.752,-0.88,4.86,0.036,1.09,"a89e73")
	for x in [-2.49,2.49]:
		P.rod(self,Vector3(x,2.03,-0.06),Vector3(x,2.47,-0.54),0.043,"946a49")
	_slat_wall(0,-1.44,5.13,0.62,0.23)
	for row in 2:
		for col in 3:
			var x := -1.65+col*1.65
			var z := -0.65+row*1.46
			var tint: String = ["5f9487","91a078","778a91"][col]
			_box(x,0.271,z,0.72,0.033,1.23,tint)
			_box(x,0.28,z+0.51,0.68,0.026,0.061,CREAM)
			_round(x,0.322,z-0.48,0.072,0.64,tint).rotation.z = PI/2.0
	for x in [-2.43,2.42]: _plant(x,1.19)

func _massage() -> void:
	_deck(4.50,3.25)
	_box(0,1.24,-1.44,4.28,2.03,0.17,"cba996")
	_box(0,0.41,-1.333,4.20,0.33,0.11,"aa846f")
	for x in [-2.02,0.0,2.02]:
		_box(x,1.41,-1.43,0.18,2.35,0.17,"b38b75")
		_box(x,1.40,-0.12,0.18,2.34,0.17,"b38b75")
		_lamp(x,2.18,-0.03)
	_box(0,2.61,-0.80,4.40,0.11,1.56,"8f655e").rotation.x = 0.06
	_box(0,2.524,-0.025,4.42,0.20,0.070,"a57168")
	for x in [-1.94,1.94]:
		for i in 4:
			_box(x+signf(x)*i*0.063,1.64,-0.085,0.080,1.67-i*0.065,0.049,"e8d3ba")
		_box(x,1.16,-0.046,0.24,0.070,0.052,"a07163")
	for x in [-0.98,0.98]:
		for side in [-0.61,0.61]:
			_box(x,0.53,0.28+side,0.44,0.60,0.105,"815b47")
		_box(x,0.49,0.28,0.11,0.14,1.27,"9d775f")
		_box(x,0.86,0.28,0.72,0.13,1.65,CREAM)
		_box(x,0.94,0.39,0.70,0.038,1.12,"ba8595")
		_box(x,0.94,-0.37,0.58,0.055,0.29,"f8e8c0")
	for i in 8:
		_box(0.0+sin(i*2.3)*0.038,1.27,-1.21+i*0.14,0.075,1.73,0.152,"ebd5bd")
	_plant(-1.81,1.23,0.23,"e989a3")
	_plant(1.81,1.23,0.23,"e989a3")

func _gear() -> void:
	_deck(3.55,2.26)
	_slat_wall(0,-1.01,3.31,1.77,0.23)
	for x in [-1.55,1.55]:
		_post(x,-0.92,2.18)
		_post(x if x < 0.0 else 1.69,0.48,2.04)
	_roof(0,-0.28,3.62,1.78,2.54,["bca065","b89a63","b99c64"])
	for i in 25:
		var x := -1.75+i*0.146
		_box(x,2.38,0.62,0.095,0.108,0.10,"a18456")
	_box(0.58,0.66,0.23,1.56,0.87,0.62,TEAL)
	_box(0.58,1.13,0.23,1.64,0.10,0.71,CEDAR)
	for i in 3:
		var board := P.ball(self,Vector3(-1.13+i*0.32,0.89,-0.14),Vector3(0.28,1.22,0.085),["e3ba65","62b5a9","e78f67"][i])
		board.rotation.x = -0.12
		_box(-1.13+i*0.32,0.87,-0.08,0.17,0.045,0.023,CREAM)
	for i in 4:
		_box(0.23+i*0.23,1.21,0.27,0.19,0.09,0.29,CREAM if i%2 else "74b5c6")
	_round(1.13,1.28,0.19,0.144,0.16,"c9ad75")
	_plant(1.37,0.80,0.23,"f2b46d")

func _splash() -> void:
	_round(0,0.075,0.22,3.02,0.15,"beaa83").scale.z = 0.75
	_round(0,0.17,0.22,2.95,0.042,"ead8ad").scale.z = 0.74
	_round(0,0.203,0.22,2.49,0.026,"5d9ca2").scale.z = 0.72
	for i in 32:
		var a := float(i)*TAU/32.0
		_box(cos(a)*2.32,0.223,0.22+sin(a)*1.67,0.24,0.014,0.19,["bbdbcc","8ec2bd","d7e2ce"][i%3]).rotation.y = -a
	for i in 20:
		var a := float(i)*TAU/20.0
		_box(cos(a)*1.28,0.223,0.22+sin(a)*0.93,0.13,0.014,0.11,"9ac6bc").rotation.y = -a
	for i in 8:
		var angle := i*TAU/8.0
		var point := Vector3(cos(angle)*1.89,0.23,sin(angle)*1.12)
		_round(point.x,0.244,point.z,0.112,0.045,"617b78")
		for bead in 5:
			var f := bead/5.0
			P.ball(self,point+Vector3(-cos(angle)*f*0.68,0.12+sin(f*PI)*0.65,-sin(angle)*f*0.47),Vector3.ONE*(0.087-f*0.040),"b5ebdf")
	for x in [-0.66,0.66]:
		_round(x,0.70,0,0.115,1.0,TEAL)
		P.cylinder(self,Vector3(x,1.23,0),0.45,0.19,"e6936e" if x>0 else "f5c768",0.19)
		for i in 8:
			var angle := i*TAU/8.0
			P.ball(self,Vector3(x+cos(angle)*0.43,0.96,sin(angle)*0.43),Vector3(0.055,0.25,0.055),"a1dfd9")
	_box(0,0.103,-2.30,2.53,0.205,1.06,"ead8ad")
	_bench(0,-2.32,2.18,"a7a587",0.20)
	_umbrella(0,-2.13,0.20,0.63,1.72,"6c9f9b",false)
	for x in [-2.72,2.72]:
		for z in [-1.64,1.66]: _plant(x,z,0.02,"ecb269")

func _pickleball() -> void:
	_box(0,0.075,0,10.70,0.15,5.72,"8b9e68")
	_box(0,0.158,0,10.58,0.04,5.58,"8fba74")
	_box(0,0.190,0.03,8.84,0.036,4.24,"518fa3")
	_box(0,0.215,0.03,2.97,0.021,4.19,"70b6b3")
	for z in [-2.06,2.11]: _box(0,0.238,z,8.81,0.019,0.047,CREAM)
	for x in [-4.38,-1.49,1.49,4.38]: _box(x,0.238,0.03,0.045,0.019,4.18,CREAM)
	for x in [-2.94,2.94]: _box(x,0.238,0.03,2.84,0.018,0.047,CREAM)
	for z in [-2.24,2.30]: _round(0,0.71,z,0.072,1.05,"48605a")
	for i in 30:
		var z := -2.19+i*0.151
		_box(0,0.84,z,0.022,0.60,0.022,"54716c")
	for i in 6:
		_box(0,0.57+i*0.104,0.03,0.023,0.021,4.48,"54716c")
	_box(0,1.16,0.03,0.052,0.052,4.59,CREAM)
	_bench(3.08,-2.44,1.36,CEDAR,0.18)
	_umbrella(3.77,-2.23,0.18,0.43,1.62,BLUE)
	_plant(-4.84,-2.33,0.18)
	_plant(4.84,2.32,0.18)
