extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _label(text: String, at: Vector2, size: int = 24) -> void:
 var label := Label.new()
 label.text = text
 label.position = at
 label.add_theme_font_size_override("font_size",size)
 root.add_child(label)
func _sprite(texture: Texture2D, at: Vector2, factor: float) -> void:
 var sprite := Sprite2D.new()
 sprite.texture = texture
 sprite.centered = false
 sprite.offset = -ResortAssets.GUEST_ROOT
 sprite.position = at
 sprite.scale = Vector2.ONE*factor
 sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
 root.add_child(sprite)
func _run() -> void:
 var bg := Polygon2D.new()
 bg.polygon = PackedVector2Array([Vector2.ZERO,Vector2(1600,0),Vector2(1600,1000),Vector2(0,1000)])
 bg.color = Color("243e39")
 root.add_child(bg)
 _label("Illustrated guests · complete painted frames",Vector2(42,25),32)
 var old := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://artifacts/npc-before.png")))
 var library := ResortAssets.new()
 _label("Before",Vector2(90,95))
 _label("Revised",Vector2(440,95))
 _sprite(old,Vector2(185,610),1.10)
 _sprite(library.walk_frames.get_frame_texture("sw_idle",0),Vector2(550,610),1.10)
 _label("50 px game scale",Vector2(850,130),22)
 _label("150 px close view",Vector2(1100,130),22)
 for index in 2:
  var factor := ResortAssets.GUEST_SCALE*(1 if index==0 else 3)
  for i in 2:
   _sprite(library.walk_frames.get_frame_texture("se_idle" if i==0 else "sw_idle",0),Vector2(920+index*300,340+i*230),factor)
 _label("Eight authored views",Vector2(45,690),24)
 for index in 8:
  var direction: String = HolidayGuestModel.DIRECTIONS[index]
  _sprite(library.walk_frames.get_frame_texture(direction+"_idle",0),Vector2(100+index*178,930),0.43)
  _label(direction.to_upper(),Vector2(90+index*178,950),18)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/npc-appearance-review.png")
 print("NPC_APPEARANCE_CAPTURE")
 quit()
