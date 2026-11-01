extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
 resort.legacy_stay_fixture=true
 resort.save_path="res://artifacts/test-npc-capture.json"
 root.add_child(resort)
 resort.set_process(false)
 var guest: ResortWalker = resort.walkers[0]
 guest.logical_position = Vector2(19,32)
 guest.position = IsometricGrid.project(guest.logical_position)
 guest.sprite.animation = "sw_idle"
 var partner: ResortWalker = resort.walkers[1]
 partner.present(Vector2(18,32),0,Vector2(1,0),false)
 resort.camera.position = (guest.position+partner.position)*0.5+Vector2(0,-22)
 resort.camera.zoom = Vector2.ONE*2.5
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 var capture := root.get_texture().get_image()
 var center := root.size/2
 capture.get_region(Rect2i(center-Vector2i(230,160),Vector2i(460,320))).save_png("res://artifacts/npc-in-game.png")
 print("NPC_GAME_CAPTURE")
 quit()
