class_name CabinInterior
extends RefCounted
## Measured source-space fixtures, converted through the shared grid registration.
## Masks partition the original pixels exactly; the source atlas stays intact.

const FIXTURES := [
	[
		{"name": "Bed", "ground": Vector2(1.0, 1.0), "polygon": [Vector2(126,231),Vector2(197,218),Vector2(285,272),Vector2(320,325),Vector2(309,366),Vector2(262,387),Vector2(199,370),Vector2(137,339)]},
		{"name": "Desk", "ground": Vector2(2.7, 0.9), "polygon": [Vector2(387,276),Vector2(454,270),Vector2(475,300),Vector2(469,351),Vector2(413,377),Vector2(386,349)]},
		{"name": "FrontEdge", "ground": Vector2(1.9, 1.9), "polygon": [Vector2(46,322),Vector2(194,404),Vector2(192,441),Vector2(282,491),Vector2(447,401),Vector2(495,366),Vector2(495,350),Vector2(421,382),Vector2(407,409),Vector2(286,465),Vector2(217,430),Vector2(212,387),Vector2(48,310)]},
		{"name": "Stairs", "ground": Vector2(1.8, 1.8), "polygon": [Vector2(323,422),Vector2(406,379),Vector2(417,379),Vector2(419,389),Vector2(440,395),Vector2(440,412),Vector2(340,464),Vector2(323,457)]}
	],
	[
		{"name": "Bed", "ground": Vector2(1.0, 1.0), "polygon": [Vector2(815,220),Vector2(883,231),Vector2(936,285),Vector2(916,342),Vector2(850,380),Vector2(781,369),Vector2(738,344),Vector2(743,292)]},
		{"name": "Desk", "ground": Vector2(0.8, 2.7), "polygon": [Vector2(578,278),Vector2(632,264),Vector2(670,282),Vector2(670,340),Vector2(619,364),Vector2(580,339)]},
		{"name": "FrontEdge", "ground": Vector2(1.9, 1.9), "polygon": [Vector2(558,322),Vector2(609,346),Vector2(624,345),Vector2(624,397),Vector2(768,470),Vector2(788,440),Vector2(808,419),Vector2(811,388),Vector2(1009,314),Vector2(1009,354),Vector2(810,490),Vector2(765,480),Vector2(614,410),Vector2(613,382),Vector2(558,353)]},
		{"name": "Stairs", "ground": Vector2(1.8, 1.8), "polygon": [Vector2(635,379),Vector2(640,379),Vector2(725,423),Vector2(725,457),Vector2(711,463),Vector2(625,413),Vector2(625,394),Vector2(635,390)]}
	]
]
const AISLES := [
	[Vector2(374,404),Vector2(350,377),Vector2(353,345),Vector2(331,327)],
	[Vector2(679,408),Vector2(687,378),Vector2(703,348),Vector2(719,327)]
]
static var cached: Dictionary = {}

static func layers(orientation: int, assets: ResortAssets) -> Array:
	if cached.has(orientation):
		return cached[orientation]
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registration/cabin-layers.json"))
	assert(metadata is Dictionary and metadata.get("source") == FileAccess.get_sha256("res://assets/atlases/buildings-v2.png") and metadata.get("authoring") == FileAccess.get_sha256("res://scripts/content/cabin_interior.gd"), "Cabin layers are stale. Run tools/bake_cabin_layers.gd and reimport.")
	var result: Array = []
	for index in FIXTURES[orientation].size() + 1:
		var part_name: String = "FloorAndRearWalls" if index == 0 else FIXTURES[orientation][index-1].name
		var ground: Vector2 = Vector2(0.5, 0.5) if index == 0 else FIXTURES[orientation][index-1].ground
		var path := "res://assets/interiors/cabin-%d-%d.png" % [orientation,index]
		assert(ResourceLoader.exists(path), "Missing cabin layer: " + path)
		result.append({"name": part_name, "ground": ground, "texture": load(path) as Texture2D})
	cached[orientation] = result
	return result

static func generate_layers(orientation: int, assets: ResortAssets) -> Array:
	var source := assets.image_for("cabin", orientation)
	var region: Rect2 = ResortAssets.REGIONS.buildings[orientation]
	var images: Array[Image] = []
	for i in FIXTURES[orientation].size() + 1:
		images.append(Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8))
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x, y)
			if pixel.a == 0.0: continue
			var part := 0
			var point := Vector2(x + 0.5, y + 0.5) + region.position
			for index in FIXTURES[orientation].size():
				if Geometry2D.is_point_in_polygon(point, PackedVector2Array(FIXTURES[orientation][index].polygon)):
					part = index + 1
			images[part].set_pixel(x, y, pixel)
	var result: Array = [{"name": "FloorAndRearWalls", "ground": Vector2(0.5, 0.5), "texture": ImageTexture.create_from_image(images[0])}]
	for index in FIXTURES[orientation].size():
		var fixture: Dictionary = FIXTURES[orientation][index]
		result.append({"name": fixture.name, "ground": fixture.ground, "texture": ImageTexture.create_from_image(images[index + 1])})
	return result

static func aisle(record: Dictionary, assets: ResortAssets) -> Array[Vector2]:
	var facing: int = record.orientation
	var region: Rect2 = ResortAssets.REGIONS.buildings[facing]
	var transform := GroundRegistration.art_transform("cabin", facing, Vector2i(4,4), region, region.size, 256, assets.image_for("cabin", facing))
	var points: Array[Vector2] = []
	for source_point: Vector2 in AISLES[facing]:
		points.append(record.position + IsometricGrid.unproject(transform * (source_point - region.position)))
	return points
