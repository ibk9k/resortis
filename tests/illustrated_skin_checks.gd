extends SceneTree
var failures: Array[String]=[]
var checked := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var assets := ResortAssets.new()
	var rejected := Image.load_from_file(ProjectSettings.globalize_path("res://tests/fixtures/rejected-illustrated-leg.png"))
	var neutral := IllustratedGuestSkin.source("female-turnaround-v1.png").get_region(IllustratedGuestSkin.RECTS.female[1])
	if shape_error(rejected,neutral)<0.04: failures.append("Broken-leg negative control was not detected")
	for variant: String in ["female","male"]:
		var library := assets.people_frames(variant)
		for facing: String in HolidayGuestModel.DIRECTIONS:
			var art := IllustratedGuestSkin.new()
			art.configure(variant,facing)
			root.add_child(art)
			var hashes: Dictionary={}
			for frame in 16:
				var texture := library.get_frame_texture(facing,frame)
				var image := texture.get_image()
				var source := art.frames[posmod(frame/2+(4 if art.mirror else 0),8)].duplicate() as Image
				if art.mirror: source.flip_x()
				if shape_error(image,source)>0.04: failures.append("Warped painted anatomy: %s/%s/%d" % [variant,facing,frame])
				checked+=1
				if AlphaRegions.components(image,32).size()!=1: failures.append("Disconnected painted body: %s/%s/%d" % [variant,facing,frame])
				var bounds := image.get_used_rect()
				if bounds.position.x<3 or bounds.position.y<3 or bounds.end.x>image.get_width()-3 or bounds.end.y>image.get_height()-3: failures.append("Frame guard: %s/%s/%d" % [variant,facing,frame])
				hashes[hash(image.get_data())]=true
			if hashes.size()<8: failures.append("Missing distinct walk poses: "+variant+"/"+facing)
			art.free()
		for activity: String in IllustratedGuestSkin.FACINGS:
			for facing: String in IllustratedGuestSkin.FACINGS[activity]:
				var art := IllustratedGuestSkin.new()
				art.configure(variant,facing,activity)
				root.add_child(art)
				for frame in 16:
					var phase := frame/16.0
					for index in range(0,art.triangles.size(),3):
						var a := art.points[art.triangles[index]]
						var b := art.points[art.triangles[index+1]]
						var c := art.points[art.triangles[index+2]]
						var ta := art.deform(a,phase)
						var tb := art.deform(b,phase)
						var tc := art.deform(c,phase)
						if (b-a).cross(c-a)*(tb-ta).cross(tc-ta)<=0: failures.append("Folded activity art: "+activity)
						if ta.distance_to(tb)/a.distance_to(b)>1.35 or tb.distance_to(tc)/b.distance_to(c)>1.35 or tc.distance_to(ta)/c.distance_to(a)>1.35: failures.append("Stretched activity art: "+activity)
				art.free()
	print("ILLUSTRATED_ART_CHECKS ",checked," runtime walk frames, bounded activity gestures; failures=",failures)
	quit(0 if failures.is_empty() else 1)

func shape_error(rendered: Image, source: Image) -> float:
	var a := rendered.get_used_rect()
	var b := source.get_used_rect()
	var errors := 0
	for y in 128:
		for x in 64:
			var uv := Vector2((x+0.5)/64,(y+0.5)/128)
			var ca := rendered.get_pixelv(a.position+Vector2i(uv*Vector2(a.size))).a>0.25
			var cb := source.get_pixelv(b.position+Vector2i(uv*Vector2(b.size))).a>0.25
			if ca!=cb: errors+=1
	return errors/(128.0*64)+absf(float(a.size.x)/a.size.y-float(b.size.x)/b.size.y)
