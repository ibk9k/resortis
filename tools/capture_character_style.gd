extends SceneTree
func _initialize() -> void: _capture.call_deferred()
func label(text: String, at: Vector2, size: int) -> void:
 var node := Label.new()
 node.text = text
 node.position = at
 node.add_theme_font_size_override("font_size",size)
 node.add_theme_color_override("font_color",Color("254237"))
 root.add_child(node)
func sprite(path: String, at: Vector2, factor: float) -> void:
 var node := Sprite2D.new()
 node.texture = ImageTexture.create_from_image(Image.load_from_file(path))
 node.centered = false
 node.offset = -Vector2(192,440)
 node.position = at
 node.scale = Vector2.ONE*factor
 node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 root.add_child(node)
func _capture() -> void:
 root.size = Vector2i(1100,760)
 root.content_scale_size = Vector2i(1100,760)
 var background := ColorRect.new()
 background.color = Color("ead5ae")
 background.size = Vector2(1100,760)
 root.add_child(background)
 label("Character direction · rounder, softer illustrated sprites",Vector2(35,24),27)
 var sources := ["res://assets/characters/frames-v2/se_idle.png","res://assets/characters/pixel/female/walk/se_00.png","res://assets/characters/pixel/male/walk/se_00.png"]
 for index in 3:
  var x := 190+index*345
  label(["Previous character","Revised female","New male"][index],Vector2(x-110,85),22)
  sprite(sources[index],Vector2(x,460),0.80)
  sprite(sources[index],Vector2(x-45,615),ResortAssets.GUEST_SCALE)
  sprite(sources[index],Vector2(x+65,635),ResortAssets.GUEST_SCALE*2)
  label("Game size        2× view",Vector2(x-110,658),17)
 label("Same rig for walking, sitting, eating, reclining and volleyball",Vector2(180,713),20)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/character-style-review.png")
 print("CHARACTER_STYLE_CAPTURE")
 quit()
