class_name AlphaRegions
extends RefCounted
## Import-time alpha topology inspection. Runtime actors use baked textures.
static func components(image: Image, minimum_pixels := 1000) -> Array[Rect2i]:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var result: Array[Rect2i] = []
	for y in height:
		for x in width:
			var start := y * width + x
			if visited[start] or image.get_pixel(x,y).a < 0.25: continue
			var queue := PackedInt32Array([start])
			visited[start] = 1
			var head := 0
			var min_p := Vector2i(x,y)
			var max_p := min_p
			while head < queue.size():
				var index := queue[head]
				head += 1
				var point := Vector2i(index % width,index / width)
				min_p = min_p.min(point)
				max_p = max_p.max(point)
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i = point + offset
					if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height: continue
					var next_index := next.y * width + next.x
					if not visited[next_index] and image.get_pixelv(next).a >= 0.25:
						visited[next_index] = 1
						queue.append(next_index)
			if queue.size() >= minimum_pixels:
				result.append(Rect2i(min_p,max_p-min_p+Vector2i.ONE).grow(2))
	return result
