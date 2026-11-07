class_name PlacedResortObject
extends Node2D

@export var object_id := -1
@export var kind := "cabin"
@export var grid_position := Vector2.ZERO
@export var orientation := 0

var sprite: Sprite2D
var data: Dictionary
var ambience: FacilityAmbience

func configure(record: Dictionary, assets: ResortAssets) -> void:
	data = record
	object_id = record.id
	kind = record.kind
	grid_position = record.position
	orientation = record.orientation
	name = "%s_%03d" % [kind.to_pascal_case(), object_id]
	var def := ResortCatalog.definition(kind)
	var footprint := ResortCatalog.footprint(kind, orientation)
	position = IsometricGrid.project(grid_position) + GroundRegistration.sort_offset(footprint)
	sprite = Sprite2D.new()
	sprite.name = "Art"
	var staffed := kind in FacilityStaff.KINDS
	sprite.texture = assets.display_texture_for(kind, orientation)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	if staffed:
		var factor := 1.0 / StaffedVenueArt.DENSITY
		sprite.transform = Transform2D(Vector2.RIGHT * factor, Vector2.DOWN * factor,
			StaffedVenueArt.origin(kind) - GroundRegistration.sort_offset(footprint))
		sprite.hide()
	elif sprite.texture != null:
		var size := sprite.texture.get_size()
		var target_width: float = def.get("width", (footprint.x + footprint.y) * 32.0)
		var region := Rect2(Vector2.ZERO, size)
		if sprite.texture is AtlasTexture:
			region = (sprite.texture as AtlasTexture).region
		sprite.transform = GroundRegistration.art_transform(kind, orientation, footprint, region, size, target_width, assets.image_for(kind,orientation))
		sprite.position -= GroundRegistration.sort_offset(footprint)
	add_child(sprite)
	if kind == "reception" and not staffed:
		var banner := ArrivalCourt.new()
		banner.name = "ReceptionBanner"
		banner.part = 3
		sprite.add_child(banner)
	if kind in ResortServices.EXPANSION:
		# The cutaway floors and furniture are the backdrop for guests using them.
		# Keep the art registration fixed while sorting from the rear of the plot.
		var lift := GroundRegistration.sort_offset(footprint).y + 16.0
		position.y -= lift
		sprite.position.y += lift
	if kind == "sunbeds":
		sprite.hide()
		for part in ["base","canopy"]:
			var layer := Sprite2D.new()
			layer.name = part.to_pascal_case()
			layer.texture = load("res://assets/interiors/sunbeds-%s.png" % part)
			layer.centered = false
			layer.texture_filter = sprite.texture_filter
			layer.transform = sprite.transform
			if part=="canopy": layer.z_index=2
			add_child(layer)
	if kind == "cabin":
		y_sort_enabled = true
		# A full backing prevents grass showing through seams between the layers.
		# Its sort position remains behind the separately sorted furniture.
		sprite.show()
		for part in CabinInterior.layers(orientation, assets):
			var anchor := Node2D.new()
			anchor.name = part.name
			anchor.position = IsometricGrid.project(part.ground) - GroundRegistration.sort_offset(footprint)
			add_child(anchor)
			var layer := Sprite2D.new()
			layer.name = "Art"
			layer.texture = part.texture
			layer.centered = false
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.transform = sprite.transform
			layer.position -= anchor.position
			anchor.add_child(layer)
	if kind == "volleyball":
		y_sort_enabled = true
		sprite.hide()
		for part in ["markings","net"]:
			var anchor := Node2D.new()
			anchor.name = part.to_pascal_case()
			anchor.position.y = -200 if part == "markings" else 0
			add_child(anchor)
			var layer := Sprite2D.new()
			layer.name = "Art"
			layer.centered = false
			layer.texture = load("res://assets/structures/volleyball-%s-v1.png" % part) as Texture2D
			assert(layer.texture != null,"Bake the separate court markings and net")
			layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			layer.transform = sprite.transform
			layer.position -= anchor.position
			anchor.add_child(layer)
	if kind in FacilityAmbience.KINDS and sprite.texture != null:
		var source_origin := Vector2.ZERO
		var source_art := sprite.texture
		if source_art is AtlasTexture:
			source_origin = source_art.region.position
			source_art = source_art.atlas
		var plot := IsometricGrid.project(grid_position) - position
		ambience = FacilityAmbience.new()
		ambience.configure(kind, orientation, sprite.transform * Transform2D(0.0, -source_origin),
			plot + GroundRegistration.sort_offset(footprint), plot, object_id, source_art)
		add_child(ambience)

func hit_test(world_point: Vector2) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var local := sprite.to_local(world_point)
	if not sprite.get_rect().has_point(local):
		return false
	var pixel := Vector2i(local - sprite.offset)
	var image := sprite.texture.get_image()
	return pixel.x >= 0 and pixel.y >= 0 and pixel.x < image.get_width() and pixel.y < image.get_height() and image.get_pixelv(pixel).a > 0.20
