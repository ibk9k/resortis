extends SceneTree
## A vector anatomy guide for image generation, never a runtime character asset.
func _initialize() -> void:
	var left_feet := [Vector2(150,445),Vector2(165,430),Vector2(190,420),Vector2(230,435),Vector2(250,470),Vector2(225,465),Vector2(200,460),Vector2(170,450)]
	var right_feet := [Vector2(250,470),Vector2(225,465),Vector2(200,460),Vector2(170,450),Vector2(150,445),Vector2(165,430),Vector2(190,420),Vector2(230,435)]
	for mirror in [false, true]:
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="1024" viewBox="0 0 1536 1024"><rect width="1536" height="1024" fill="#f4f4f0"/>'
		for phase in 8:
			var ox: int = (phase % 4) * 384
			var oy: int = (phase / 4) * 512
			svg += '<g transform="translate(%d %d)">' % [ox, oy]
			if mirror: svg += '<g transform="translate(384 0) scale(-1 1)">'
			svg += '<ellipse cx="192" cy="158" rx="51" ry="66" fill="#c6c7c4" stroke="#555" stroke-width="4"/><path d="M150 228 L230 228 L218 317 L165 317 Z" fill="#a8aaa6" stroke="#555" stroke-width="4"/>'
			var left: Vector2 = left_feet[phase]
			var right: Vector2 = right_feet[phase]
			var lk := (Vector2(174,310) + left) * 0.5 + Vector2(15, -4)
			var rk := (Vector2(210,310) + right) * 0.5 + Vector2(15, -4)
			svg += '<path d="M174 310 L%f %f L%f %f" fill="none" stroke="#e87724" stroke-width="20" stroke-linecap="round"/>' % [lk.x,lk.y,left.x,left.y]
			svg += '<path d="M210 310 L%f %f L%f %f" fill="none" stroke="#287dc5" stroke-width="20" stroke-linecap="round"/>' % [rk.x,rk.y,right.x,right.y]
			var swing := cos(TAU * float(phase) / 8.0)
			svg += '<path d="M151 239 L%f 287 L%f 338" fill="none" stroke="#e87724" stroke-width="15" stroke-linecap="round"/>' % [140 + swing * 13,137 + swing * 32]
			svg += '<path d="M232 239 L%f 285 L%f 334" fill="none" stroke="#287dc5" stroke-width="15" stroke-linecap="round"/>' % [242 - swing * 13,247 - swing * 32]
			svg += '<ellipse cx="%f" cy="%f" rx="21" ry="10" fill="#e87724"/><ellipse cx="%f" cy="%f" rx="21" ry="10" fill="#287dc5"/>' % [left.x,left.y,right.x,right.y]
			if mirror: svg += '</g>'
			svg += '<text x="24" y="38" font-size="26" fill="#222">%d</text></g>' % [phase+1]
		svg += '</svg>'
		var image := Image.new()
		image.load_svg_from_string(svg)
		image.save_png("res://docs/assets/walk-pose-guide-%s.png" % ("left" if mirror else "right"))
	print("POSE_GUIDES_CREATED")
	quit()
