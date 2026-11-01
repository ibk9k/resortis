extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var assets := ResortAssets.new()
 # Validate the complete registered ground envelope, not a transform mapping
 # three selected points onto three selected output points (a tautology).
 for kind: String in ResortCatalog.DEFINITIONS:
  for orientation in ResortCatalog.definition(kind).frames.size():
   if not GroundRegistration.has_registration(kind,orientation):
    failures.append("Missing full envelope: "+kind)
    continue
   var item := PlacedResortObject.new()
   item.configure({"id":1,"kind":kind,"position":Vector2.ZERO,"orientation":orientation},assets)
   root.add_child(item)
   var texture := item.sprite.texture as AtlasTexture
   if texture:
    var size := ResortCatalog.footprint(kind,orientation)
    for point in GroundRegistration.source_floor(kind,orientation):
     var ground := IsometricGrid.unproject(item.sprite.to_global(point-texture.region.position))
     if ground.x < -0.5 or ground.y < -0.5 or ground.x > size.x-0.5 or ground.y > size.y-0.5:
      failures.append("Base spills outside reservation: "+kind)
   if not kind in GroundRegistration.CANOPIES:
    var size := ResortCatalog.footprint(kind,orientation)
    var image := item.sprite.texture.get_image()
    var spilled := false
    for y in image.get_height():
     for x in image.get_width():
      if image.get_pixel(x,y).a < 0.20: continue
      var drawn := item.sprite.to_global(Vector2(x+0.5,y+0.5))
      var logical := IsometricGrid.unproject(drawn)
      if drawn.x < -size.y*32-0.5 or drawn.x > size.x*32+0.5 or logical.x > size.x-0.5+0.03 or logical.y > size.y-0.5+0.03:
       spilled = true
       break
     if spilled: break
    if spilled: failures.append("Visible structure leaves reserved vertical volume: "+kind)
   item.free()
 var graph := AStarGrid2D.new()
 graph.region = Rect2i(0,0,12,12)
 graph.update()
 var poses: Array = []
 for hz in [30,120]:
  var walker := ResortWalker.new()
  walker.configure(1,Vector2i(1,1),graph,[Vector2i(10,1)],assets)
  root.add_child(walker)
  walker.wait_time = 0
  walker.route = [Vector2i(1,1),Vector2i(10,1)]
  walker.route_index = 1
  for n in hz: walker.advance(1.0/hz)
  poses.append({"position":walker.logical_position,"frame":walker.sprite.frame,"distance":walker.walked_distance,"progress":walker.sprite.frame_progress})
  walker.free()
 if poses[0].frame != poses[1].frame or absf(poses[0].progress-poses[1].progress)>0.001 or poses[0].position.distance_to(poses[1].position)>0.0001:
  failures.append("Pose/movement changes with render FPS")
 if poses[0].distance < 0.5: failures.append("Actor did not move")
 if ResortCatalog.entrance("cabin",0)==ResortCatalog.entrance("cabin",1): failures.append("Cabin doors disagree with facing")
 for animation in assets.walk_frames.get_animation_names():
  for index in assets.walk_frames.get_frame_count(animation):
   var texture := assets.walk_frames.get_frame_texture(animation,index)
   if texture is AtlasTexture: failures.append("Shared character atlas can bleed")
   var image := texture.get_image()
   var rect := image.get_used_rect()
   if rect.position.x<4 or rect.position.y<4 or rect.end.x>image.get_width()-4 or rect.end.y>image.get_height()-4:
    failures.append("Pose clips frame guard: %s %d"%[animation,index])
   if AlphaRegions.components(image,32).size()!=1:
    failures.append("Disconnected silhouette: %s %d"%[animation,index])
 var model := HolidayGuestModel.new()
 model.build()
 for frame in 64:
  model.pose(float(frame)/64)
  for index in 2:
   var leg: Dictionary = model.limbs[index]
   if absf(leg.thigh.scale.y-0.40)>0.001 or absf(leg.calf.scale.y-0.40)>0.001:
    failures.append("Model leg length changes during gait")
  model.pose(float(frame)/64)
  var left: Vector3 = model.joints.left_foot
  var right: Vector3 = model.joints.right_foot
  if left.x>=right.x: failures.append("Feet cross through each other")
  if minf(left.y,right.y)>0.096: failures.append("Both feet airborne during walking")
 model.pose(0)
 var lead: float = model.joints.left_foot.z-model.joints.right_foot.z
 model.pose(0.5)
 if signf(lead)==signf(model.joints.left_foot.z-model.joints.right_foot.z): failures.append("Half-cycle repeats lead leg")
 for direction in HolidayGuestModel.DIRECTIONS:
  model.face(direction)
  if assets.walk_frames.get_frame_count(direction)!=16: failures.append("Missing angle: "+direction)
 for index in 8:
  var dir := Vector2.from_angle(index*PI/4)
  var actual := ResortWalker.facing_for(dir)
  if actual != ["e","se","s","sw","w","nw","n","ne"][index]: failures.append("Wrong actor facing")
 model.free()
 print("ASSET_ALIGNMENT_CHECKS ",JSON.stringify(failures))
 quit(0 if failures.is_empty() else 1)
