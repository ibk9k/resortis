extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: --script tools/inspect_atlas.gd -- <png> <columns> <rows>")
		quit(1)
		return
	var image := Image.load_from_file(args[0])
	if image == null:
		quit(1)
		return
	var cols := int(args[1])
	var rows := int(args[2])
	var size := image.get_size()
	var cell := Vector2i(size.x / cols, size.y / rows)
	var bounds: Array = []
	for y in rows:
		for x in cols:
			var min_p := cell
			var max_p := Vector2i(-1, -1)
			var empty := 0
			for py in cell.y:
				for px in cell.x:
					if image.get_pixel(x * cell.x + px, y * cell.y + py).a > 0.05:
						min_p = min_p.min(Vector2i(px, py))
						max_p = max_p.max(Vector2i(px, py))
					else:
						empty += 1
			bounds.append({"cell": [x, y], "min": [min_p.x, min_p.y], "max": [max_p.x, max_p.y], "transparent_fraction": float(empty) / float(cell.x * cell.y)})
	print(JSON.stringify({"size": [size.x, size.y], "has_alpha": image.detect_alpha(), "corner": str(image.get_pixel(0, 0)), "bounds": bounds}))
	quit()
