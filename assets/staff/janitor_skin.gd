extends Node2D
## Bake/review only. The whole illustrated character changes pose as one image.
const Art = preload("res://assets/staff/janitor_art.gd")
var picture := Sprite2D.new()
var facing := "se"
var kind := "walk"
var row := 1
var mirrored := false
var _textures: Dictionary = {}

func configure(direction: String, action: String = "walk") -> void:
	facing = direction
	kind = action
	row = Art.DIRS[facing][0]
	mirrored = Art.DIRS[facing][1]
	picture.centered = false
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(picture)
	pose(0.0)

func pose(phase: float) -> void:
	var source_kind := "walk" if kind == "walk" else "clean"
	var column := 1 if kind == "idle" else posmod(floori(phase * (8 if kind == "walk" else 4)) + (4 if mirrored and kind == "walk" else 0), 8 if kind == "walk" else 4)
	var image := Art.painting(source_kind, row, column)
	var key := "%s/%d" % [source_kind, column]
	if not _textures.has(key):
		var sampled := image.duplicate() as Image
		sampled.generate_mipmaps()
		_textures[key] = ImageTexture.create_from_image(sampled)
	picture.texture = _textures[key]
	var factor := Art.row_scale(source_kind, row)
	picture.scale = Vector2(-factor if mirrored else factor, factor)
	picture.position = Art.ROOT - Art.anchor(image) * picture.scale
