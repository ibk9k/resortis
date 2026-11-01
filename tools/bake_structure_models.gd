extends SceneTree
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
 DirAccess.make_dir_recursive_absolute("res://assets/structures")
 var viewport := SubViewport.new()
 viewport.size = Vector2i(768,640)
 viewport.transparent_bg = true
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 ModelPrimitives.camera(viewport,32.0*sqrt(2.0),Vector3.ZERO)
 var records: Dictionary = {}
 for kind: String in GroundRegistration.MODELED:
  var model := StructureModels.new()
  model.build(kind)
  viewport.add_child(model)
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  var image := viewport.get_texture().get_image()
  var rect := image.get_used_rect().grow(3).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
  var cropped := image.get_region(rect)
  var file := "res://assets/structures/%s-v1.png" % kind
  cropped.save_png(file)
  var origin := Vector2(384,320)-Vector2(rect.position)
  records[kind] = {"file":file.trim_prefix("res://"),"origin":[origin.x,origin.y],"source":"scripts/content/structure_models.gd","density":32.0*sqrt(2.0)}
  if kind == "volleyball":
   for layer in ["Net","Markings"]:
    model.get_node("Net").visible = layer == "Net"
    model.get_node("Markings").visible = layer == "Markings"
    await process_frame
    await RenderingServer.frame_post_draw
    viewport.get_texture().get_image().get_region(rect).save_png("res://assets/structures/volleyball-%s-v1.png" % layer.to_lower())
  model.free()
 var data := FileAccess.open("res://assets/registration/structures.json",FileAccess.WRITE)
 data.store_string(JSON.stringify(records,"\t"))
 print("STRUCTURE_MODELS_BAKED ",records.size())
 quit()
