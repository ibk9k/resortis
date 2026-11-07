class_name ResortServices
extends RefCounted

const EXPANSION := ["gym", "sauna", "ice_cream", "restaurant", "yoga", "massage", "gear", "pickleball"]
const KINDS := {
	"meal": "cafe", "sunbathe": "sunbeds", "volleyball": "volleyball",
	"gym": "gym", "sauna": "sauna", "ice_cream": "ice_cream", "restaurant": "restaurant",
	"yoga": "yoga", "massage": "massage", "gear": "gear", "pickleball": "pickleball",
}
const POSES := {
	"meal": "eating", "sunbathe": "lying", "volleyball": "volleyball",
	"gym": "treadmill", "sauna": "sitting", "ice_cream": "standing", "restaurant": "eating",
	"yoga": "standing", "massage": "lying", "gear": "standing", "pickleball": "volleyball",
}
const FOOD := ["meal", "restaurant", "ice_cream"]
const RECOVERY := ["sauna", "yoga", "massage"]
const PAIRED := ["volleyball", "pickleball"]
const BISTRO_VERTICAL_SCALE := 0.82
const BISTRO_DECK := 0.26
const CAPACITIES := {"gym": 3, "restaurant": 4, "yoga": 6}
const MAX_CAPACITY := 6
const VISITS := {
	"gym": [20.0, "Training on a treadmill."],
	"sauna": [18.0, "Warming up on a cedar bench."],
	"ice_cream": [9.0, "Enjoying a scoop from the ice cream cart."],
	"yoga": [18.0, "Taking a quiet stretch break on the yoga deck."],
	"massage": [20.0, "Resting on a treatment table."],
	"gear": [12.0, "Picking up beach gear at the surf kiosk."],
}

static func capacity(activity: String) -> int:
	return CAPACITIES.get(activity, 2)

static func label(service: String) -> String:
	match service:
		"room": return "Cabin night"
		"meal": return "Café meal"
		"sunbathe": return "Sunbed"
		_: return String(ResortCatalog.definition(service).get("name", service.capitalize()))
