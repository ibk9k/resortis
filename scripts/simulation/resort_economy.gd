class_name ResortEconomy
extends RefCounted
## Initial playtest balance. Each entry is [purchase, daily upkeep].
const OPENING_CASH := 2500
const MAX_PRICE := 999
const DEFAULT_PRICES := {"room": 60, "meal": 12, "sunbathe": 8, "volleyball": 10,
	"gym": 14, "sauna": 16, "ice_cream": 6, "restaurant": 22, "yoga": 10, "massage": 24, "gear": 15, "pickleball": 12}
const COSTS := {
	"cabin": [360, 8], "reception": [280, 6], "cafe": [320, 8], "pool": [480, 12],
	"sunbeds": [100, 2], "volleyball": [240, 5], "pier": [270, 5],
	"palm": [35, 0], "small_palm": [25, 0], "hedge": [22, 0], "flowers": [15, 0],
	"bench": [28, 0], "lantern": [24, 1], "bin": [16, 0], "rocks": [18, 0],
	"gym": [590, 12], "sauna": [460, 9], "ice_cream": [180, 3], "restaurant": [790, 16],
	"yoga": [300, 5], "massage": [410, 8], "gear": [250, 5], "pickleball": [530, 7],
	"path": [5, 0], "dolphin_statue": [0, 0],
}

static func purchase(kind: String) -> int:
	return COSTS[kind][0]

static func upkeep(kind: String) -> int:
	return COSTS[kind][1]

static func item_name(kind: String) -> String:
	return "Stone path" if kind == "path" else str(ResortCatalog.definition(kind).get("name", kind))

static func valid_price(value: Variant) -> bool:
	return (value is int or value is float) and value >= 1 and value <= MAX_PRICE and value == floorf(value)

static func mark_custom_price(receipt: Dictionary) -> void:
	if receipt.amount != DEFAULT_PRICES[receipt.kind]:
		receipt["unit_price"] = receipt.amount

static func valid_guest_charge(receipt: Dictionary) -> bool:
	return DEFAULT_PRICES.has(receipt.kind) and valid_price(receipt.amount) and receipt.amount == receipt.get("unit_price", DEFAULT_PRICES[receipt.kind])
