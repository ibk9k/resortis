extends SceneTree
## Companion walk and independent activity states; accepted female gait stays in frames-v2.
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
 var sample := "--sample" in OS.get_cmdline_user_args()
 var viewport := SubViewport.new()
 viewport.size = Vector2i(384,512)
 viewport.transparent_bg = true
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var camera := ModelPrimitives.camera(viewport,220.0,Vector3(0,184.0/(220.0*cos(PI/6)),0))
 for child in viewport.get_children():
  if child is DirectionalLight3D: child.shadow_enabled = false
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-20,145,0)
 fill.light_energy = 0.30
 viewport.add_child(fill)
 var records: Array = []
 for variant: String in ["male"]:
  var model := HolidayGuestModel.new()
  model.variant = variant
  model.build()
  viewport.add_child(model)
  var folder := "res://assets/characters/guests-v3/%s/walk" % variant
  DirAccess.make_dir_recursive_absolute(folder)
  for facing: String in (["se"] if sample else HolidayGuestModel.DIRECTIONS):
   model.face(facing)
   for index in 17:
    model.pose(float(index)/16,index<16)
    await process_frame
    await RenderingServer.frame_post_draw
    var image := viewport.get_texture().get_image()
    image.resize(384,512,Image.INTERPOLATE_NEAREST)
    var suffix := "%02d" % index if index<16 else "idle"
    var file := folder.path_join("%s_%s.png" % [facing,suffix])
    image.save_png(file)
    if variant == "female":
     var left: Vector3 = model.joints.left_foot
     var right: Vector3 = model.joints.right_foot
     records.append({"direction":facing,"frame":index,"left_foot":[left.x,left.y,left.z],"right_foot":[right.x,right.y,right.z],"file":file.trim_prefix("res://")})
    if sample: break
   print("PIXEL_WALK_BAKED ",variant," ",facing)
   if sample: break
  model.free()
 viewport.size = Vector2i(640,640)
 camera.size = viewport.size.y/220.0
 var target := Vector3(0,160.0/(220.0*cos(PI/6)),0)
 camera.position = target+Vector3(10,8.1649658,10)
 camera.look_at(target)
 await process_frame
 assert(camera.unproject_position(Vector3.ZERO).distance_to(GuestActivityPose.ROOT) < 0.1)
 var guards := 0
 var count := 0
 for variant: String in ["female","male"]:
  var folder := "res://assets/characters/guests-v3/%s/activities" % variant
  DirAccess.make_dir_recursive_absolute(folder)
  var model := HolidayGuestModel.new()
  model.variant = variant
  model.build()
  viewport.add_child(model)
  for activity: String in GuestActivityPose.FRAMES:
   for facing: String in (["se"] if sample else HolidayGuestModel.DIRECTIONS):
    model.face(facing)
    for index in int(GuestActivityPose.FRAMES[activity]):
     model.activity_pose(activity,float(index)/GuestActivityPose.FRAMES[activity])
     await process_frame
     await RenderingServer.frame_post_draw
     var image := viewport.get_texture().get_image()
     if not Rect2i(8,8,624,624).encloses(image.get_used_rect()): guards += 1
     image.resize(640,640,Image.INTERPOLATE_NEAREST)
     image.save_png(folder.path_join("%s-%s-%02d.png" % [activity,facing,index]))
     count += 1
     if sample: break
    if sample: break
   print("ACTIVITY_BAKED ",variant," ",activity)
  model.free()
 if not sample:
  var hashes: Dictionary = {}
  for path in ["res://scripts/actors/holiday_guest_model.gd","res://scripts/actors/guest_appearance.gd","res://scripts/actors/guest_activity_pose.gd"]: hashes[path] = FileAccess.get_sha256(path)
  var file := FileAccess.open("res://assets/registration/activity-frames.json",FileAccess.WRITE)
  file.store_string(JSON.stringify({"schema":1,"root":[320,480],"canvas":[640,640],"sources":hashes,"frames":GuestActivityPose.FRAMES,"count":count},"\t"))
  file.close()
 print("GUEST_ACTIVITIES_BAKED ",count," frames; clipped guards=",guards)
 quit(0 if guards==0 else 1)
