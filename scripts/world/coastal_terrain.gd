class_name CoastalTerrain
extends Node2D

var layout: ResortLayout
var surface: ShaderMaterial
var path_node: Polygon2D
var show_grid := false
var elapsed := 0.0
var calm_water := false
var materials: Array[ShaderMaterial] = []

func build(source: ResortLayout) -> void:
	layout = source
	for child in get_children():
		child.free()
	materials.clear()
	var texture := load("res://assets/atlases/terrain-v1.png") as Texture2D
	_patch("InlandLawn", Rect2(-64, -64, 192, 85), Vector2.ZERO, Color(0.81, 0.92, 0.76), texture)
	_patch("BroadDryBeach", Rect2(-64, 21, 192, 19), Vector2(0.5, 0), Color(1.0, 0.97, 0.88), texture)
	_patch("WetSand", Rect2(-64, 37.7, 192, 3), Vector2(0.5, 0), Color(0.71, 0.81, 0.78), texture)
	var ocean := Polygon2D.new()
	ocean.name = "AnimatedShoreAndOcean"
	ocean.polygon = IsometricGrid.footprint_polygon(Vector2(-64, 37), Vector2i(192, 100))
	surface = ShaderMaterial.new()
	surface.shader = load("res://assets/shaders/surf.gdshader")
	surface.set_shader_parameter("terrain_atlas", texture)
	ocean.material = surface
	add_child(ocean)
	path_node = Polygon2D.new()
	path_node.name = "StonePaths"
	var points := PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	for cell in layout.paths:
		var index := points.size()
		points.append_array(IsometricGrid.footprint_polygon(Vector2(cell), Vector2i.ONE))
		faces.append(PackedInt32Array([index, index + 1, index + 2, index + 3]))
	path_node.polygon = points
	path_node.polygons = faces
	path_node.material = _material(Vector2(0, 0.5), Color(0.95, 0.98, 0.91), texture)
	add_child(path_node)
	queue_redraw()

func _patch(label: String, rect: Rect2, quadrant: Vector2, tint: Color, texture: Texture2D) -> void:
	var patch := Polygon2D.new()
	patch.name = label
	var p := rect.position - Vector2(0.5, 0.5)
	patch.polygon = PackedVector2Array([IsometricGrid.project(p), IsometricGrid.project(p + Vector2(rect.size.x, 0)), IsometricGrid.project(p + rect.size), IsometricGrid.project(p + Vector2(0, rect.size.y))])
	patch.material = _material(quadrant, tint, texture)
	add_child(patch)

func _material(quadrant: Vector2, tint: Color, texture: Texture2D) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://assets/shaders/ground.gdshader")
	result.set_shader_parameter("terrain_atlas", texture)
	result.set_shader_parameter("quadrant", quadrant)
	result.set_shader_parameter("material_tint", tint)
	materials.append(result)
	return result

func advance(delta: float) -> void:
	elapsed += delta
	if surface != null:
		surface.set_shader_parameter("elapsed", elapsed)
		surface.set_shader_parameter("motion", 0.0 if calm_water else 1.0)

func _draw() -> void:
	if layout == null or not show_grid:
		return
	for x in range(0, ResortLayout.MAP_SIZE.x + 1):
		draw_line(IsometricGrid.project(Vector2(x - 0.5, -0.5)), IsometricGrid.project(Vector2(x - 0.5, 39.5)), Color(0.10, 0.24, 0.18, 0.20), 1.0)
	for y in range(0, 41):
		draw_line(IsometricGrid.project(Vector2(-0.5, y - 0.5)), IsometricGrid.project(Vector2(43.5, y - 0.5)), Color(0.10, 0.24, 0.18, 0.20), 1.0)
	var boundary := IsometricGrid.footprint_polygon(Vector2.ZERO, Vector2i(44, 40))
	boundary.append(boundary[0])
	draw_polyline(boundary, Color(0.96, 0.88, 0.64, 0.70), 2.0)
