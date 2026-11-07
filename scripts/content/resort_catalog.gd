class_name ResortCatalog
extends RefCounted
## Static, shared art and placement definitions. Never stores placed state.

const DEFINITIONS := {
	"gym": {"name": "Indoor fitness studio", "category": "Leisure", "size": Vector2i(8, 6), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(4, 6), "description": "A cutaway studio with treadmill workouts and free weights.", "access": true},
	"sauna": {"name": "Cedar sauna", "category": "Leisure", "size": Vector2i(6, 4), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(3, 4), "description": "A warm cedar room with tiered benches and a stone heater.", "access": true},
	"ice_cream": {"name": "Ice cream cart", "category": "Resort", "size": Vector2i(3, 2), "terrain": ["grass", "sand"], "atlas": "modeled", "frames": [0], "door": Vector2i(1, 2), "description": "A mint-green cart serving a quick treat.", "access": true},
	"restaurant": {"name": "Seaside bistro", "category": "Resort", "size": Vector2i(10, 8), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(5, 8), "description": "A terracotta terrace serving full meals at seated tables.", "access": true},
	"yoga": {"name": "Yoga pavilion", "category": "Leisure", "size": Vector2i(6, 4), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(3, 4), "description": "A shaded deck for a quiet stretch and some recovery.", "access": true},
	"massage": {"name": "Massage cabana", "category": "Leisure", "size": Vector2i(5, 4), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(2, 4), "description": "A linen-screened cabana with two treatment tables.", "access": true},
	"gear": {"name": "Beach gear kiosk", "category": "Beach", "size": Vector2i(4, 3), "terrain": ["grass", "sand"], "atlas": "modeled", "frames": [0], "door": Vector2i(2, 3), "description": "Rent a surfboard or pick up a beach towel.", "access": true},
	"pickleball": {"name": "Pickleball court", "category": "Leisure", "size": Vector2i(11, 6), "terrain": ["grass"], "atlas": "modeled", "frames": [0], "door": Vector2i(5, 6), "description": "Two guests play across the net on a full outdoor court.", "access": true},
	"cabin": {"name": "Garden cabin", "category": "Stay", "size": Vector2i(4, 4), "terrain": ["grass"], "atlas": "buildings", "frames": [0, 1], "door": Vector2i(4, 2), "doors": [Vector2i(4, 2), Vector2i(2, 4)], "description": "A furnished retreat with its own bathroom. Each facing has its own entrance.", "access": true},
	"reception": {"name": "Reception", "category": "Resort", "size": Vector2i(5, 4), "terrain": ["grass"], "atlas": "buildings", "frames": [2], "door": Vector2i(2, 4), "description": "The arrival point, opening onto the garden paths.", "access": true},
	"cafe": {"name": "Coastal café", "category": "Resort", "size": Vector2i(4, 4), "terrain": ["grass"], "atlas": "buildings", "frames": [3], "door": Vector2i(2, 4), "description": "Food and drinks in a compact timber pavilion.", "access": true},
	"pool": {"name": "Garden pool", "category": "Leisure", "size": Vector2i(8, 6), "terrain": ["grass"], "atlas": "pool", "frames": [0], "door": Vector2i(4, 6), "description": "A sheltered pool with a waterfall and room for a deck.", "access": true},
	"sunbeds": {"name": "Sunbathing", "category": "Beach", "size": Vector2i(3, 3), "terrain": ["sand"], "atlas": "buildings", "frames": [5], "door": Vector2i(1, 3), "description": "Paired striped loungers beneath a beach umbrella.", "access": true},
	"volleyball": {"name": "Beach volleyball", "category": "Beach", "size": Vector2i(8, 5), "terrain": ["sand"], "atlas": "beach", "frames": [0], "door": Vector2i(4, 5), "description": "A full court, with generous room between the promenade and surf. Activity simulation comes later.", "access": true},
	"pier": {"name": "Fishing pier", "category": "Beach", "size": Vector2i(2, 9), "terrain": ["sand", "wet_sand", "water"], "atlas": "beach", "frames": [1], "door": Vector2i(1, -1), "description": "A timber pier extending from the beach into the shallows. Fishing activity comes later.", "access": true, "walkable": true},
	"palm": {"name": "Coconut palm", "category": "Garden", "size": Vector2i(1, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [0], "width": 128.0, "description": "A tall, leafy canopy. Decorations use half-tile snapping."},
	"small_palm": {"name": "Ornamental palm", "category": "Garden", "size": Vector2i(1, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [1], "width": 95.0, "description": "A smaller palm for garden and beach planting."},
	"hedge": {"name": "Flowering hedge", "category": "Garden", "size": Vector2i(2, 1), "terrain": ["grass"], "atlas": "props", "frames": [2], "width": 110.0, "description": "Timber-edged tropical flowers frame a path."},
	"flowers": {"name": "Hibiscus bed", "category": "Garden", "size": Vector2i(1, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [3], "width": 89.0, "description": "A compact pocket of pink and yellow flowers."},
	"bench": {"name": "Garden bench", "category": "Garden", "size": Vector2i(2, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [4], "width": 94.0, "description": "A place to rest beside the promenade."},
	"lantern": {"name": "Lantern post", "category": "Garden", "size": Vector2i(1, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [5], "width": 35.0, "description": "Warm light along the garden paths."},
	"bin": {"name": "Waste bin", "category": "Garden", "size": Vector2i(1, 1), "terrain": ["grass", "sand"], "atlas": "props", "frames": [6], "width": 29.0, "description": "A practical detail for the working resort."},
	"rocks": {"name": "Coastal rocks", "category": "Garden", "size": Vector2i(2, 1), "terrain": ["grass", "sand", "wet_sand"], "atlas": "props", "frames": [7], "width": 109.0, "description": "Low weathered rocks soften the coastline."},
	"dolphin_statue": {"name": "Bronze dolphin statue", "category": "Garden", "size": Vector2i(2, 1), "terrain": ["grass", "sand"], "frames": [0], "description": "A leaping bronze dolphin on a sea-green plinth. Earned on the Challenges board."}
}

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {})

static func is_decoration(id: String) -> bool:
	return definition(id).get("category", "") == "Garden"

static func entrance(id: String, orientation: int = 0) -> Vector2i:
	var def := definition(id)
	if def.has("doors"):
		return def.doors[orientation]
	return def.get("door", Vector2i.ZERO)

static func footprint(id: String, orientation: int = 0) -> Vector2i:
	var value: Vector2i = definition(id).get("size", Vector2i.ONE)
	# Cabin views share a square footprint. More rectangular views can be authored later.
	if orientation % 2 == 1 and definition(id).get("frames", []).size() > 1:
		return Vector2i(value.y, value.x)
	return value
