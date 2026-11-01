extends SceneTree
## Inspects alpha only; leaves original image files intact.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for path in args:
		var image := Image.load_from_file(path)
		var width := image.get_width()
		var height := image.get_height()
		var visited := PackedByteArray()
		visited.resize(width * height)
		var components: Array = []
		for y in height:
			for x in width:
				var start := y * width + x
				if visited[start] or image.get_pixel(x, y).a < 0.25:
					continue
				var queue := PackedInt32Array([start])
				visited[start] = 1
				var head := 0
				var min_p := Vector2i(x, y)
				var max_p := min_p
				while head < queue.size():
					var idx := queue[head]
					head += 1
					var p := Vector2i(idx % width, idx / width)
					min_p = min_p.min(p)
					max_p = max_p.max(p)
					for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var n: Vector2i = p + offset
						if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height:
							continue
						var ni := n.y * width + n.x
						if not visited[ni] and image.get_pixel(n.x, n.y).a >= 0.25:
							visited[ni] = 1
							queue.append(ni)
				if queue.size() > 1000:
					components.append({"min": [min_p.x, min_p.y], "max": [max_p.x, max_p.y], "pixels": queue.size()})
		print(JSON.stringify({"path": path, "size": [width, height], "components": components}))
	quit()
