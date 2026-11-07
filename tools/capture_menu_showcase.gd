extends SceneTree
## Capture the isolated showcase at 60 fps with Godot's movie writer.

const Resort := preload("res://scenes/world/coastal_resort.tscn")
const OUTPUT := "res://artifacts/menu-production"
const FPS := 60
const LEG_FRAMES := FPS * 7
const OVERLAP_FRAMES := 90
# Camera position (x, y) and zoom. The spline wraps through the coast,
# inland venues, promenade and pier with the same velocity at the seam.
const ROUTE: Array[Vector3] = [
	Vector3(40, 477, 0.68),
	Vector3(355, 120, 0.80),
	Vector3(420, -145, 0.93),
	Vector3(760, -107, 0.95),
	Vector3(936, 210, 1.04),
	Vector3(270, 520, 0.98),
	Vector3(-390, 630, 0.88),
	Vector3(-980, 675, 0.88),
	Vector3(-545, 724, 0.73),
]

func _initialize() -> void:
	record.call_deferred()

func record() -> void:
	if not "--fresh" in OS.get_cmdline_user_args():
		push_error("Pass --fresh to isolate the showcase from saves.")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(OUTPUT) != OK:
		push_error("Could not create the showcase capture directory.")
		quit(1)
		return
	var resort := Resort.instantiate() as CoastalResort
	resort.starting_layout = ResortLayout.new()
	if resort.starting_layout.load_layout("res://data/menu_showcase.json") != OK:
		push_error("Showcase layout failed validation.")
		quit(1)
		return
	root.snap_2d_transforms_to_pixel = false
	root.snap_2d_vertices_to_pixel = false
	resort.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(resort)
	resort.set_process(false)
	resort.hud.hide()
	resort.management.hide()
	resort.scene_speed = 1.0
	resort.living.cleanliness.hire()
	for step in 1520:
		resort._process(0.05)
	for frame in ROUTE.size() * LEG_FRAMES + OVERLAP_FRAMES:
		var leg := floori(float(frame) / LEG_FRAMES) % ROUTE.size()
		var t := float(frame % LEG_FRAMES) / LEG_FRAMES
		var pose := ROUTE[leg].cubic_interpolate(
			ROUTE[(leg + 1) % ROUTE.size()], ROUTE[posmod(leg - 1, ROUTE.size())],
			ROUTE[(leg + 2) % ROUTE.size()], t)
		resort.camera.position = Vector2(pose.x, pose.y)
		resort.camera.zoom = Vector2.ONE * pose.z
		resort.camera.force_update_scroll()
		resort._process(1.0 / FPS)
		await RenderingServer.frame_post_draw
		if frame == OVERLAP_FRAMES:
			var error := root.get_texture().get_image().save_jpg(OUTPUT.path_join("tour-poster.jpg"), 0.95)
			if error != OK:
				push_error("Could not save the showcase poster.")
				quit(1)
				return
		if (frame + 1) % LEG_FRAMES == 0:
			print("Showcase leg %d of %d captured." % [leg + 1, ROUTE.size()])
	quit()
