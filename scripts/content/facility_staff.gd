class_name FacilityStaff
extends RefCounted
## These six fixed workstations share the illustrated guest scale. Each key
## contains the whole drawing, including the hands and their work props.
const KINDS := ["cafe", "ice_cream", "restaurant", "reception", "gear", "yoga"]
const KEY_COUNT := 6
const CANVAS := Vector2i(88, 76)
const ROOT := Vector2(44, 64)
const TEXTURE_SCALE := 4
const POSE_DIRECTORY := "res://assets/facility-staff/frames"
const SEQUENCES := {
	"cafe": [[0, 0.65], [1, 0.32], [2, 0.30], [3, 0.35], [2, 0.28], [3, 0.30], [4, 0.70], [5, 0.42]],
	"ice_cream": [[0, 0.64], [1, 0.40], [2, 0.46], [3, 0.54], [4, 0.74], [5, 0.52]],
	"restaurant": [[0, 0.52], [1, 0.30], [2, 0.34], [1, 0.28], [2, 0.36], [3, 0.34], [4, 0.44], [5, 0.58]],
	"reception": [[0, 0.66], [1, 0.42], [2, 0.43], [3, 0.45], [4, 0.80], [5, 0.51]],
	"gear": [[0, 0.68], [1, 0.38], [2, 0.36], [3, 0.45], [4, 0.45], [5, 0.68], [3, 0.33], [2, 0.25]],
	"yoga": [[0, 0.56], [1, 0.44], [2, 0.92], [1, 0.44], [3, 0.60], [4, 0.44], [5, 0.92], [4, 0.44]],
}
static func pose_at(kind: String, elapsed: float) -> int:
	var sequence: Array = SEQUENCES[kind]
	var period := 0.0
	for entry: Array in sequence: period += float(entry[1])
	var within := fposmod(elapsed, period)
	for index in sequence.size():
		within -= float(sequence[index][1])
		if within < 0.0: return index
	return 0
