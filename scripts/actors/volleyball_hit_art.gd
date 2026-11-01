extends RefCounted
## Complete authored volleyball poses; uniform registration, never limb warps.
const SOURCE := "res://assets/characters/illustrated-masters/guest-volleyball-v2.png"
# Contact at 0/4s, follow-through/recovery, ready, crouch, drive, contact.
const KEYS := [3,4,5,0,0,0,0,0,0,0,0,0,0,1,2,3]
const HANDS := [Vector2(0.88,0.66),Vector2(0.67,0.68),Vector2(0.92,0.57),Vector2(0.95,0.44),Vector2(0.96,0.27),Vector2(0.72,0.61)]
static var _rows: Dictionary={}
static func poses(variant: String) -> Array[Image]:
	if _rows.is_empty():
		var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
		var regions := AlphaRegions.components(source,3000)
		assert(regions.size()==12,"Volleyball sheet must contain twelve separate complete bodies")
		regions.sort_custom(func(a: Rect2i,b: Rect2i) -> bool: return a.get_center().y<b.get_center().y)
		for row in 2:
			var group: Array[Rect2i]=regions.slice(row*6,row*6+6)
			group.sort_custom(func(a: Rect2i,b: Rect2i) -> bool: return a.get_center().x<b.get_center().x)
			var images: Array[Image]=[]
			for region in group: images.append(_drawing(source.get_region(region)))
			_rows["female" if row==0 else "male"]=images
	return _rows[variant]
static func _drawing(crop: Image) -> Image:
	# An arm's wide bounding rectangle can include a neighbouring sandal. Keep
	# the complete connected painting plus its original two-pixel alpha edge.
	var width := crop.get_width()
	var height := crop.get_height()
	var visited := PackedByteArray()
	visited.resize(width*height)
	var body := PackedInt32Array()
	for y in height:
		for x in width:
			var start := y*width+x
			if visited[start] or crop.get_pixel(x,y).a<0.25: continue
			var pixels := PackedInt32Array([start])
			visited[start]=1
			var head := 0
			while head<pixels.size():
				var index := pixels[head]
				head+=1
				var point := Vector2i(index%width,index/width)
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i=point+offset
					if next.x<0 or next.y<0 or next.x>=width or next.y>=height: continue
					var n := next.y*width+next.x
					if visited[n] or crop.get_pixelv(next).a<0.25: continue
					visited[n]=1
					pixels.append(n)
			if pixels.size()>body.size(): body=pixels
	var result := Image.create(width,height,false,Image.FORMAT_RGBA8)
	for index in body:
		var point := Vector2i(index%width,index/width)
		for dy in range(-2,3):
			for dx in range(-2,3):
				var target := point+Vector2i(dx,dy)
				if target.x>=0 and target.y>=0 and target.x<width and target.y<height: result.set_pixelv(target,crop.get_pixelv(target))
	return result
static func factor(images: Array[Image]) -> float:
	var tallest := 0
	for image in images: tallest=maxi(tallest,image.get_used_rect().size.y)
	return 400.0/tallest
static func foot(image: Image) -> Vector2:
	var used := image.get_used_rect()
	var left := image.get_width()
	var right := 0
	var floor_y := 0
	for y in range(used.position.y+roundi(used.size.y*0.82),used.end.y):
		for x in image.get_width():
			if image.get_pixel(x,y).a<0.75: continue
			left=mini(left,x)
			right=maxi(right,x)
			floor_y=maxi(floor_y,y)
	return Vector2((left+right)*0.5,floor_y)
static func hand(image: Image,key: int) -> Vector2:
	var used := image.get_used_rect()
	var target: Vector2=Vector2(used.position)+Vector2(used.size)*HANDS[key]
	if key==3:
		# Contact is on the actual joined forearms/fingers, not a guessed hip.
		var skin: Array[Vector2]=[]
		var furthest := 0.0
		for y in range(used.position.y+roundi(used.size.y*0.30),used.position.y+roundi(used.size.y*0.60)):
			for x in range(used.position.x+roundi(used.size.x*0.6),used.end.x):
				var color := image.get_pixel(x,y)
				if color.a>0.8 and color.r>0.50 and color.r>color.g*1.12 and color.g>color.b*1.12 and color.g<0.85:
					skin.append(Vector2(x,y))
					furthest=maxf(furthest,x)
		var sum := Vector2.ZERO
		var count := 0
		for point in skin:
			if point.x>=furthest-10:
				sum+=point
				count+=1
		if count>0: target=sum/count
	return target
