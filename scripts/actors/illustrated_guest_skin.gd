class_name IllustratedGuestSkin
extends Node2D
const VolleyArt = preload("res://scripts/actors/volleyball_hit_art.gd")
## Bake-only presentation. Walking uses complete guided paintings: overlapping
## legs are never separated, stretched, rotated or reconstructed from cutouts.
const FACINGS := {"sitting":["ne"],"eating":["ne"],"lying":["sw"],"sleeping":["se","sw"],"volleyball":["se","nw"]}
const DIRS := {"s":[0,false],"se":[1,false],"e":[2,false],"ne":[3,false],"n":[4,false],"nw":[3,true],"w":[2,true],"sw":[1,true]}
const RECTS := {
	"female":[Rect2i(107,14,392,763),Rect2i(590,12,331,766),Rect2i(1089,19,350,752),Rect2i(1559,15,365,750)],
	"male":[Rect2i(85,15,397,781),Rect2i(583,14,327,783),Rect2i(1040,14,335,775),Rect2i(1468,10,385,771)]
}
const MASTER := {"female":Rect2i(262,94,428,877),"male":Rect2i(914,44,429,934)}
const ACTIVITIES := {
	"female":[Rect2i(51,24,301,447),Rect2i(378,37,420,446),Rect2i(794,53,401,430),Rect2i(1216,14,278,476)],
	"male":[Rect2i(48,500,313,467),Rect2i(376,523,396,459),Rect2i(790,522,429,464),Rect2i(1237,500,270,499)]
}
static var images: Dictionary = {}
static var walk_regions: Dictionary = {}
var variant := "female"
var facing := "se"
var activity := "walk"
var picture: Sprite2D
var surface: MeshInstance2D
var frames: Array[Image] = []
var image: Image
var idle: Image
var scale_factor := 1.0
var root_point := Vector2.ZERO
var origin := Vector2.ZERO
var pivot := Vector2.ZERO
var mirror := false
var contact := Vector2.ZERO
var hand := Vector2.ZERO
var shape_size := Vector2.ZERO
var points := PackedVector2Array()
var triangles := PackedInt32Array()
var pose_angle := 0.0

static func source(name: String) -> Image:
	if not images.has(name): images[name]=Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/illustrated-masters/"+name))
	return images[name]

static func regions(identity: String) -> Array[Rect2i]:
	if walk_regions.has(identity): return walk_regions[identity]
	var sheet := source(identity+"-walk-v3.png")
	var width := sheet.get_width()
	var height := sheet.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var bodies: Array[Rect2i]=[]
	for y in height:
		for x in width:
			var start := y*width+x
			if visited[start] or sheet.get_pixel(x,y).a<0.2: continue
			var queue := PackedInt32Array([start])
			visited[start]=1
			var bounds := Rect2i(x,y,1,1)
			var head := 0
			while head<queue.size():
				var index := queue[head]
				head+=1
				var pixel := Vector2i(index%width,index/width)
				bounds=bounds.expand(pixel)
				for neighbour in [pixel+Vector2i.LEFT,pixel+Vector2i.RIGHT,pixel+Vector2i.UP,pixel+Vector2i.DOWN]:
					if neighbour.x<0 or neighbour.y<0 or neighbour.x>=width or neighbour.y>=height: continue
					var next: int=neighbour.y*width+neighbour.x
					if visited[next] or sheet.get_pixelv(neighbour).a<0.2: continue
					visited[next]=1
					queue.append(next)
			if queue.size()>1000: bodies.append(bounds.grow(2).intersection(Rect2i(0,0,width,height)))
	assert(bodies.size()==40,"Illustrated walk sheet must contain 40 complete, separate bodies: "+identity+" "+str(bodies.size()))
	bodies.sort_custom(func(a: Rect2i,b: Rect2i) -> bool: return a.get_center().y<b.get_center().y)
	var result: Array[Rect2i]=[]
	for row in 5:
		var group: Array[Rect2i]=bodies.slice(row*8,row*8+8)
		group.sort_custom(func(a: Rect2i,b: Rect2i) -> bool: return a.get_center().x<b.get_center().x)
		result.append_array(group)
	walk_regions[identity]=result
	return result

func configure(identity: String, direction: String, kind: String="walk") -> void:
	variant=identity
	facing=direction
	activity=kind
	mirror=DIRS[facing][1] if kind=="walk" else kind=="sleeping" and facing=="sw"
	if kind=="volleyball": mirror=(variant=="female" and facing=="nw") or (variant=="male" and facing=="se")
	root_point=ResortAssets.GUEST_ROOT if kind=="walk" else GuestActivityPose.ROOT
	if kind=="volleyball":
		frames=VolleyArt.poses(variant)
		scale_factor=VolleyArt.factor(frames)
		mirror=facing=="nw"
		picture=Sprite2D.new()
		picture.centered=false
		picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(picture)
	elif kind=="walk":
		var sheet := source(variant+"-walk-v3.png")
		var heights: Array[int]=[]
		for col in 8:
			var row: int=DIRS[facing][0]
			var frame := sheet.get_region(regions(variant)[row*8+col])
			frames.append(frame)
			heights.append(frame.get_used_rect().size.y)
		heights.sort()
		scale_factor=400.0/heights[4]
		var canonical: String=facing if not mirror else {"sw":"se","w":"e","nw":"ne"}[facing]
		var index: int={"s":0,"se":-1,"e":1,"ne":2,"n":3}[canonical]
		idle=source("guest-pair-v1.png").get_region(MASTER[variant]) if index==-1 else source(variant+"-turnaround-v1.png").get_region(RECTS[variant][index])
		picture=Sprite2D.new()
		picture.centered=false
		picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(picture)
	else:
		var index: int={"sitting":0,"eating":0,"lying":1,"sleeping":2,"volleyball":3}[kind]
		image=source("guest-activities-v1.png").get_region(ACTIVITIES[variant][index])
		shape_size=image.get_size()
		scale_factor=400.0/maxf(shape_size.x,shape_size.y)
		pivot=(Vector2(0.42,0.68) if variant=="female" else Vector2(0.48,0.74))*shape_size
		var height := 0.59
		if kind in ["lying","sleeping"]:
			if kind=="lying": pivot=(Vector2(0.55,0.57) if variant=="female" else Vector2(0.57,0.60))*shape_size
			else: pivot=(Vector2(0.51,0.60) if variant=="female" else Vector2(0.53,0.64))*shape_size
			height=0.19
			pose_angle=deg_to_rad(12 if kind=="lying" else -12)
		if kind=="volleyball":
			pivot=Vector2(0.5,0.98)*shape_size
			height=0
		hand=(Vector2(0.71,0.40) if kind in ["sitting","eating"] else Vector2(0.75,0.60))*shape_size
		if variant=="male": hand=(Vector2(0.70,0.36) if kind in ["sitting","eating"] else Vector2(0.28,0.60))*shape_size
		origin=root_point-pivot*scale_factor-Vector2(0,height*220*cos(PI/6))
		surface=MeshInstance2D.new()
		surface.texture=ImageTexture.create_from_image(image)
		surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(surface)
		var cols := ceili(shape_size.x/8)+1
		var rows := ceili(shape_size.y/8)+1
		for y in rows:
			for x in cols: points.append(Vector2(minf(x*8,shape_size.x),minf(y*8,shape_size.y)))
		for y in rows-1:
			for x in cols-1:
				var a := y*cols+x
				triangles.append_array(PackedInt32Array([a,a+cols,a+1,a+1,a+cols,a+cols+1]))
	pose(0,false)

func deform(point: Vector2, phase: float) -> Vector2:
	var breath := Vector2(0,sin(phase*TAU))
	if activity in ["sitting","lying","sleeping"]: return point+breath
	# Bounded wrist gesture: the displacement gradient stays below .3.
	var radius := shape_size.y*0.16
	var influence := exp(-point.distance_squared_to(hand)/(2*radius*radius))
	var delta := Vector2.ZERO
	if activity=="eating": delta=Vector2(-0.045,-0.04)*shape_size*(0.5-0.5*cos(phase*TAU))
	if activity=="volleyball": delta=Vector2(0,-0.025)*shape_size*pow(0.5+0.5*cos(phase*TAU),3)
	return point+breath+delta*influence

func pose(phase: float, walking: bool=true) -> void:
	if activity=="volleyball":
		var key: int=VolleyArt.KEYS[posmod(floori(phase*16),16)]
		var frame := frames[key]
		var anchor: Vector2=VolleyArt.foot(frame)
		picture.texture=ImageTexture.create_from_image(frame)
		picture.scale=Vector2(-scale_factor if mirror else scale_factor,scale_factor)
		picture.position=root_point-anchor*picture.scale
		contact=root_point+(VolleyArt.hand(frame,key)-anchor)*picture.scale
		return
	if activity=="walk":
		var index := posmod(floori(phase*8)+(4 if mirror else 0),8)
		var frame := frames[index] if walking else idle
		var used := frame.get_used_rect()
		var factor := scale_factor if walking else 400.0/used.size.y
		# Register the hat instead of shifting the torso with the swinging feet.
		var head := Rect2i()
		for y in range(used.position.y,used.position.y+roundi(used.size.y*0.30)):
			for x in range(used.position.x,used.end.x):
				if frame.get_pixel(x,y).a>0.5:
					head=head.expand(Vector2i(x,y)) if head.has_area() else Rect2i(x,y,1,1)
		var anchor := Vector2(head.get_center().x,used.end.y)
		picture.texture=ImageTexture.create_from_image(frame)
		picture.scale=Vector2(-factor if mirror else factor,factor)
		picture.position=root_point-anchor*picture.scale
		return
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for point in points:
		var result := deform(point,phase)
		result=origin+(pivot+(result-pivot).rotated(pose_angle))*scale_factor
		if mirror: result.x=root_point.x*2-result.x
		vertices.append(Vector3(result.x,result.y,0))
		uvs.append(point/shape_size)
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=triangles
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	surface.mesh=mesh
	contact=origin+deform(hand,phase)*scale_factor
	if mirror: contact.x=root_point.x*2-contact.x
