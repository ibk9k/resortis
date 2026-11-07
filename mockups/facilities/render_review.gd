extends SceneTree
## Standalone art review. This script never instantiates the playable resort.

const Models = preload("res://mockups/facilities/concept_models.gd")
const OUTPUT := "res://artifacts/facility-review/"
const MODEL_DIR := "res://mockups/facilities/models/"
const CORE := ["gym", "sauna", "ice_cream", "restaurant"]
const EXTRAS := ["yoga", "massage", "gear", "splash", "pickleball"]
const BG := Color("102c27")
const PANEL := Color("193c34")
const INK := Color("fff0d0")
const GOLD := Color("efba77")
const MUTE := Color("bdd5c4")
const EXPANSION := Rect2i(0,-22,44,22)
var renders: Dictionary = {}
var issues: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(MODEL_DIR)
	_check_plots()
	var viewport := _viewport(Vector2i(960,768))
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	ModelPrimitives.camera(viewport, 32.0 * sqrt(2.0), Vector3.ZERO)
	for key: String in CORE + EXTRAS:
		var model := Models.new()
		model.build(key)
		var size: Vector2i = Models.CONCEPTS[key].size
		_check_bounds(model, Transform3D.IDENTITY, Vector2(size) * 0.5, key)
		if not issues.is_empty(): break
		# Strip the procedural builder from the packed scene. Its named native
		# mesh nodes and materials can be edited directly in the Godot editor.
		model.set_script(null)
		_set_owner(model, model)
		var scene := PackedScene.new()
		var path := MODEL_DIR + key + ".tscn"
		if scene.pack(model) != OK or ResourceSaver.save(scene, path) != OK:
			issues.append("Could not save " + path)
			model.free()
			break
		viewport.add_child(model)
		await _frame()
		var bitmap := viewport.get_texture().get_image()
		var crop := bitmap.get_used_rect()
		if crop.size.x < 12 or crop.size.y < 12 or crop.position.x < 3 or crop.position.y < 3 or crop.end.x > viewport.size.x-3 or crop.end.y > viewport.size.y-3:
			issues.append("Model is empty or clipped in the render: " + key)
			model.free()
			break
		renders[key] = {"texture":ImageTexture.create_from_image(bitmap.get_region(crop)), "offset":Vector2(crop.position) - Vector2(viewport.size)*0.5}
		model.free()
	viewport.free()
	if issues.is_empty():
		_pack_study()
		await _sheet(false)
		await _sheet(true)
		await _site()
	print("FACILITY_REVIEW ", JSON.stringify({"models":renders.size(),"issues":issues,"output":OUTPUT}))
	quit(0 if issues.is_empty() else 1)

func _pack_study() -> void:
	var study := Node3D.new()
	study.name = "InlandTestPlot"
	var base := ModelPrimitives.box(study, Vector3(22,-0.16,-11), Vector3(44,0.30,22), "507b49")
	base.name = "ExpansionGround"
	base.owner = study
	var paths := Node3D.new()
	paths.name = "Promenades"
	study.add_child(paths)
	paths.owner = study
	for y in [-21.0,-13.0,-7.0,-0.30]:
		ModelPrimitives.box(paths, Vector3(22,0,y), Vector3(41,0.012,0.60), "c5af8c")
	for x in [2.0,25.0,26.0,42.0]:
		ModelPrimitives.box(paths, Vector3(x,0.012,-10.66), Vector3(0.92,0.012,20.80), "c5af8c")
	_set_owner(paths, study)
	var facilities := Node3D.new()
	facilities.name = "Facilities"
	study.add_child(facilities)
	facilities.owner = study
	for key: String in CORE + EXTRAS:
		var model_scene := load(MODEL_DIR + key + ".tscn") as PackedScene
		var model := model_scene.instantiate() as Node3D
		var center: Vector2 = Models.CONCEPTS[key].center
		model.position = Vector3(center.x,0,center.y)
		facilities.add_child(model)
		model.owner = study
	var rig := _viewport(Vector2i(1600,900))
	ModelPrimitives.camera(rig, 29.0, Vector3(22,0,-11))
	for child in rig.get_children():
		rig.remove_child(child)
		study.add_child(child)
		child.owner = study
	rig.free()
	var scene := PackedScene.new()
	if scene.pack(study) != OK or ResourceSaver.save(scene, "res://mockups/facilities/inland_test_plot.tscn") != OK:
		issues.append("Could not save the editable inland test plot")
	study.free()

func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner(child, owner)

func _check_bounds(node: Node3D, parent: Transform3D, limit: Vector2, key: String) -> void:
	var current := parent * node.transform
	if node is MeshInstance3D:
		var box: AABB = current * node.get_aabb()
		if box.position.x < -limit.x or box.end.x > limit.x or box.position.z < -limit.y or box.end.z > limit.y:
			issues.append("%s mesh exceeds %s footprint: %s" % [key, limit*2.0, box])
	for child in node.get_children():
		if child is Node3D: _check_bounds(child, current, limit, key)

func _check_plots() -> void:
	var lots: Dictionary = {}
	var outer := Rect2(Vector2(EXPANSION.position), Vector2(EXPANSION.size))
	for key: String in CORE + EXTRAS:
		var data: Dictionary = Models.CONCEPTS[key]
		var size := Vector2(data.size)
		var lot := Rect2(data.center - size*0.5, size)
		if not outer.encloses(lot): issues.append("Plot is outside the expansion: " + key)
		for other in lots:
			if lot.intersects(lots[other]): issues.append("Overlapping plots: %s and %s" % [key, other])
		lots[key] = lot

func _sheet(extras: bool) -> void:
	var viewport := _viewport(Vector2i(1640,1120))
	var page := Node2D.new()
	viewport.add_child(page)
	_block(page, Rect2(Vector2.ZERO,Vector2(viewport.size)),BG,0)
	_text(page, Vector2(44,30), "RESORTIS  /  CONCEPT REVIEW", 18, GOLD)
	_text(page, Vector2(44,61), "Pavilions and recreation" if extras else "Four distinct resort facilities", 43, INK)
	_text(page, Vector2(47,116), "The court and revised optional concepts" if extras else "Second design pass · Cutaway interiors and revised proportions", 19, MUTE)
	if extras:
		_card(page,"yoga",Rect2(44,174,502,402),6)
		_card(page,"massage",Rect2(569,174,502,402),7)
		_card(page,"gear",Rect2(1094,174,502,402),8)
		_card(page,"splash",Rect2(44,600,502,438),9)
		_card(page,"pickleball",Rect2(569,600,1027,438),10)
	else:
		_card(page,"gym",Rect2(44,174,765,400),1)
		_card(page,"sauna",Rect2(832,174,764,400),2)
		_card(page,"ice_cream",Rect2(44,597,570,440),3)
		_card(page,"restaurant",Rect2(637,597,959,440),5)
	_text(page, Vector2(47,viewport.size.y-48), "DESIGN MOCKUPS   •   Geometry and placement for review", 16, MUTE)
	await _frame()
	_save(viewport, "facility-extras.png" if extras else "facility-models.png")
	viewport.free()

func _card(page: Node2D, key: String, rect: Rect2, number: int) -> void:
	var data: Dictionary = Models.CONCEPTS[key]
	_block(page, rect, PANEL, 11)
	_block(page, Rect2(rect.position + Vector2(17,17), Vector2(41,38)), GOLD, 6)
	_text(page, rect.position+Vector2(24,23), "%02d" % number, 19, BG)
	_text(page, rect.position+Vector2(72,16), data.name, 27, INK)
	_text(page, rect.position+Vector2(73,53), data.note, 17, MUTE)
	var size: Vector2i = data.size
	var badge := "%d × %d" % [size.x,size.y]
	_text(page, rect.position + Vector2(rect.size.x-90,24), badge, 19, GOLD)
	var art := Sprite2D.new()
	art.texture = renders[key].texture
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var art_area := Rect2(rect.position+Vector2(20,91), rect.size-Vector2(40,108))
	var image_size := art.texture.get_size()
	var zoom := minf(art_area.size.x/image_size.x,art_area.size.y/image_size.y)
	art.scale = Vector2.ONE * zoom
	art.position = art_area.get_center()
	page.add_child(art)
	if key == "restaurant":
		var guest := Sprite2D.new()
		guest.texture = load("res://assets/characters/illustrated/male/walk/se_idle.png")
		guest.centered = false
		guest.offset = -ResortAssets.GUEST_ROOT
		guest.scale = Vector2.ONE * zoom * ResortAssets.GUEST_SCALE
		# A standard guest on the clear front aisle, registered to the deck.
		var point := IsometricGrid.project(Vector2(0,3.36)) - Vector2(0,0.26 * 32.0 * sqrt(1.5))
		var origin: Vector2 = renders[key].offset
		guest.position = art.position + (point - origin - image_size*0.5) * zoom
		page.add_child(guest)
		_text(page,rect.position+Vector2(rect.size.x-162,rect.size.y-37),"Guest for scale",16,MUTE)

func _site() -> void:
	var viewport := _viewport(Vector2i(1740,1130))
	var page := Node2D.new()
	viewport.add_child(page)
	_block(page, Rect2(Vector2.ZERO,Vector2(viewport.size)),BG,0)
	var map := Node2D.new()
	map.position = Vector2(641,309)
	map.scale = Vector2.ONE * 0.47
	page.add_child(map)
	var layout := ResortLayout.new()
	if layout.load_layout("res://data/coastal_map.json") != OK:
		issues.append("Could not load the authored resort map for the mockup")
		viewport.free()
		return
	for x in range(2,43):
		for y in [-21,-13,-7,0]: layout.paths[Vector2i(x,y)] = true
	for y in range(-21,3):
		for x in [2,25,26,42]: layout.paths[Vector2i(x,y)] = true
	for y in range(2,6):
		for x in range(21,27): layout.paths[Vector2i(x,y)] = true
	var terrain := CoastalTerrain.new()
	map.add_child(terrain)
	terrain.build(layout)
	terrain.add_child(ArrivalCourt.new())
	var area := IsometricGrid.footprint_polygon(Vector2(EXPANSION.position) + Vector2(0.5,0.5), EXPANSION.size)
	var tint := Polygon2D.new()
	tint.polygon = area
	tint.color = Color(0.18,0.42,0.23,0.14)
	map.add_child(tint)
	var border := Line2D.new()
	border.points = area
	border.closed = true
	border.width = 4.3
	border.default_color = Color("f3ce91")
	map.add_child(border)
	var objects := Node2D.new()
	objects.y_sort_enabled = true
	map.add_child(objects)
	var assets := ResortAssets.new()
	for record in layout.objects:
		var object := PlacedResortObject.new()
		object.configure(record,assets)
		objects.add_child(object)
	for x in [1,14,24,42]:
		for y in [-20,-14,-8]:
			var palm := PlacedResortObject.new()
			palm.configure({"id":8000+x*30-y,"kind":"small_palm","position":Vector2(x,y),"orientation":0},assets)
			objects.add_child(palm)
	var gate := ArrivalCourt.new()
	gate.part = 1
	gate.position = IsometricGrid.project(ArrivalGeometry.GATE)
	objects.add_child(gate)
	for key: String in CORE + EXTRAS:
		var data: Dictionary = Models.CONCEPTS[key]
		var center: Vector2 = data.center
		var art_anchor := Node2D.new()
		art_anchor.position = IsometricGrid.project(center + Vector2(data.size)*0.5)
		objects.add_child(art_anchor)
		var art := Sprite2D.new()
		art.centered = false
		art.texture = renders[key].texture
		art.position = IsometricGrid.project(center) - art_anchor.position + renders[key].offset
		art_anchor.add_child(art)
	for key: String in CORE + EXTRAS:
		var data: Dictionary = Models.CONCEPTS[key]
		var front: Vector2 = data.center + Vector2(0,float(data.size.y)*0.5)
		var at := map.to_global(IsometricGrid.project(front)) + Vector2(-12,1)
		var index := _number((CORE + EXTRAS).find(key))
		_block(page,Rect2(at,Vector2(27,23)),GOLD,5)
		_text(page, at+Vector2(4,1), "%02d" % index, 15, BG)
	var reserve := map.to_global(IsometricGrid.project(Vector2(34,-15)))
	_block(page,Rect2(reserve-Vector2(70,15),Vector2(156,30)),Color("204939"),5)
	_text(page,reserve-Vector2(61,11),"Open test land",17,INK)
	_block(page,Rect2(0,0,1740,102),BG,0)
	_text(page,Vector2(40,13),"RESORTIS   /   SITE STUDY",17,GOLD)
	_text(page,Vector2(40,37),"An inland test district",42,INK)
	_text(page,Vector2(960,36),"44 × 48 → 44 × 70 tiles   •   22 additional inland rows",24,INK)
	_text(page,Vector2(962,70),"Gold boundary marks the proposed test land",17,MUTE)
	_block(page,Rect2(0,981,1740,149),BG,0)
	for i in (CORE + EXTRAS).size():
		var at := Vector2(44+float(i%5)*337,1004+floorf(float(i)/5.0)*55)
		var data: Dictionary = Models.CONCEPTS[(CORE+EXTRAS)[i]]
		_block(page,Rect2(at,Vector2(33,28)),GOLD,5)
		_text(page,at+Vector2(6,2),"%02d" % _number(i),16,BG)
		_text(page,at+Vector2(46,0),data.name,19,INK)
		_text(page,at+Vector2(47,25),"%d × %d tiles" % [data.size.x,data.size.y],14,MUTE)
	await _frame()
	_save(viewport,"expansion-site.png")
	viewport.free()

func _number(index: int) -> int:
	# Keep the familiar review numbers after retiring concept 04.
	return index+1 if index<3 else index+2

func _text(parent: Node, at: Vector2, value: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)

func _block(parent: Node, rect: Rect2, color: Color, radius: int) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)

func _save(viewport: SubViewport, filename: String) -> void:
	if viewport.get_texture().get_image().save_png(OUTPUT+filename) != OK:
		issues.append("Could not write " + filename)
