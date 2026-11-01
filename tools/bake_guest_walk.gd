extends SceneTree
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
 DirAccess.make_dir_recursive_absolute("res://assets/characters/frames-v2")
 var viewport := SubViewport.new()
 viewport.size = Vector2i(384,512)
 viewport.transparent_bg = true
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var camera := ModelPrimitives.camera(viewport,220.0,Vector3(0,184.0/(220.0*cos(PI/6)),0))
 # A face needs readable fill rather than hard hat/nose shadow cuts.
 for child in viewport.get_children():
  if child is DirectionalLight3D: child.shadow_enabled = false
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(-20,145,0)
 fill.light_energy = 0.30
 viewport.add_child(fill)
 var model := HolidayGuestModel.new()
 model.build()
 viewport.add_child(model)
 await process_frame
 assert(camera.unproject_position(Vector3.ZERO).distance_to(Vector2(192,440)) < 0.1,"Incorrect ground camera registration")
 var frames: Array = []
 for facing: String in HolidayGuestModel.DIRECTIONS:
  model.face(facing)
  for frame in HolidayGuestModel.POSES+1:
   model.pose(float(frame)/HolidayGuestModel.POSES,frame<HolidayGuestModel.POSES)
   await process_frame
   await RenderingServer.frame_post_draw
   var image := viewport.get_texture().get_image()
   var file := "res://assets/characters/frames-v2/%s_%02d.png" % [facing,frame] if frame<HolidayGuestModel.POSES else "res://assets/characters/frames-v2/%s_idle.png" % facing
   if "--sample" in OS.get_cmdline_user_args(): file = "res://artifacts/npc-sample.png"
   if image.save_png(file) != OK: quit(1); return
   var left: Vector3 = model.joints.left_foot
   var right: Vector3 = model.joints.right_foot
   frames.append({"direction":facing,"frame":frame,"left_foot":[left.x,left.y,left.z],"right_foot":[right.x,right.y,right.z],"file":file.trim_prefix("res://")})
   if "--sample" in OS.get_cmdline_user_args():
    print("GUEST_SAMPLE_BAKED ",file)
    quit()
    return
 model.face("sw")
 model.pose(0,false)
 _own(model,model)
 var packed := PackedScene.new()
 packed.pack(model)
 ResourceSaver.save(packed,"res://scenes/assets/holiday_guest_model.tscn")
 var manifest := FileAccess.open("res://assets/registration/guest-frames.json",FileAccess.WRITE)
 manifest.store_string(JSON.stringify({"schema":3,"source":"holiday_guest_model.gd","canvas":[384,512],"root":[192,440],"poses":HolidayGuestModel.POSES,"stride_distance":ResortWalker.STRIDE_DISTANCE,"frames":frames},"\t"))
 print("GUEST_MODEL_BAKED 128 volumetric walk frames, eight idles and editable model scene")
 quit()
func _own(node: Node, owner_node: Node) -> void:
 for child in node.get_children():
  child.owner = owner_node
  _own(child,owner_node)
