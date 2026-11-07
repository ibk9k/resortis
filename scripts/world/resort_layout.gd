class_name ResortLayout
extends RefCounted
## Editable map state and validation. All presentation tools use these rules.

const INLAND_START := -22
const WALKABLE_END := 48
const MAP_SIZE := Vector2i(44, WALKABLE_END - INLAND_START)
const MAP_BOUNDS := Rect2i(0, INLAND_START, MAP_SIZE.x, MAP_SIZE.y)
const POINT_BOUNDS := Rect2(-0.5, INLAND_START - 0.5, MAP_SIZE.x, MAP_SIZE.y)
const BACKDROP_REAR_EDGE := -64.5
const BEACH_START := 21
const WET_SAND_START := 38
const WATER_START := 40
const PIER_START := 36
const ARRIVAL := Vector2i(39, 19)
const SCHEMA := 4
const SAVE_PATH := "user://coastal-layout.json"

var objects: Array[Dictionary] = []
var paths: Dictionary = {}
var next_id := 1
var revision := 0
var guest_stay: Dictionary = {}
var live_resort: Dictionary = {}
var prices: Dictionary = {}
# The playable world supplies the public approach. Standalone layout fixtures
# can still exercise lodging without a vehicle timetable.
var public_arrivals := false

func price(service: String) -> int:
	return prices.get(service, ResortEconomy.DEFAULT_PRICES[service])

func terrain(cell: Vector2i) -> String:
	if cell.y >= WATER_START:
		return "water"
	if cell.y >= WET_SAND_START:
		return "wet_sand"
	if cell.y >= BEACH_START:
		return "sand"
	return "grass"

func contains(cell: Vector2i) -> bool:
	return MAP_BOUNDS.has_point(cell)

func is_path(cell: Vector2i) -> bool:
	return paths.has(cell)

func seed_default() -> void:
	guest_stay = {}
	live_resort = {}
	prices.clear()
	objects.clear()
	paths.clear()
	next_id = 1
	_path_rect(Rect2i(3, 19, 38, 2))
	_path_rect(Rect2i(21, 4, 2, 16))
	_path_rect(Rect2i(6, 10, 34, 2))
	_path_rect(Rect2i(6, 17, 34, 1))
	_path_rect(Rect2i(39, 10, 2, 10))
	for cell in [Vector2i(9, 9), Vector2i(16, 9), Vector2i(9, 16), Vector2i(16, 16)]:
		paths[cell] = true
	# Both authored cabin facings have real path connections. Their entrances
	# are on different sides of the footprint, not one shared guessed tile.
	for cabin in [Vector2i(7, 5), Vector2i(14, 5), Vector2i(7, 12), Vector2i(14, 12)]:
		_path_rect(Rect2i(cabin + Vector2i(4, 2), Vector2i(1, 3)))
	_seed("cabin", Vector2(7, 5), 0)
	_seed("cabin", Vector2(14, 5), 1)
	_seed("cabin", Vector2(7, 12), 1)
	_seed("cabin", Vector2(14, 12), 0)
	_seed("reception", Vector2(24, 13))
	_seed("cafe", Vector2(32, 13))
	_seed("pool", Vector2(28, 4))
	for x in [7, 12, 17]:
		_seed("sunbeds", Vector2(x, 23))
	_seed("sunbeds", Vector2(12, 31))
	_seed("sunbeds", Vector2(20, 31))
	_seed("volleyball", Vector2(28, 26))
	_seed("pier", Vector2(4, PIER_START))
	# Deliberate landscape rhythm; gaps retain clear views into the furnished rooms.
	for p in [Vector2(4, 4), Vector2(12, 4), Vector2(20, 4), Vector2(25, 4), Vector2(38, 4), Vector2(4, 11), Vector2(12, 11), Vector2(19, 12), Vector2(24, 9), Vector2(38, 12), Vector2(4, 17), Vector2(12, 17), Vector2(19, 17), Vector2(24, 18), Vector2(31, 18), Vector2(38, 18), Vector2(3, 23), Vector2(23, 23), Vector2(39, 25)]:
		# Some large canopy objects sit just beside the path, never on it.
		if not is_path(Vector2i(p)):
			_seed("palm", p)
	for x in [5, 11, 18, 26, 30, 36]:
		_seed("flowers", Vector2(x, 18))
	for x in [5, 11, 18, 24, 30, 37]:
		_seed("lantern", Vector2(x + 0.5, 21))
	for p in [Vector2(5, 8), Vector2(12, 8), Vector2(19, 8), Vector2(5, 15), Vector2(12, 15), Vector2(19, 15), Vector2(26, 8), Vector2(37, 8)]:
		_seed("hedge", p)
	for p in [Vector2(9, 21), Vector2(20, 21), Vector2(33, 21)]:
		_seed("bench", p)
	for p in [Vector2(6, 18), Vector2(20, 18), Vector2(33, 18), Vector2(40, 21)]:
		if not is_path(Vector2i(p)):
			_seed("bin", p)
	for p in [Vector2(1, 37), Vector2(41, 38), Vector2(40, 36), Vector2(2, 38)]:
		_seed("rocks", p)
	for p in [Vector2(7, 31), Vector2(25, 33), Vector2(39, 34)]:
		_seed("palm", p)
	for p in [Vector2(1, 7), Vector2(2, 15), Vector2(42, 6), Vector2(42, 16), Vector2(24, 1), Vector2(9, 1)]:
		_seed("small_palm", p)
	revision += 1

func _path_rect(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			paths[Vector2i(x, y)] = true

func _seed(kind: String, position: Vector2, orientation: int = 0) -> void:
	objects.append({"id": next_id, "kind": kind, "position": position, "orientation": orientation})
	next_id += 1

func snapped_position(kind: String, position: Vector2) -> Vector2:
	var step := 0.5 if ResortCatalog.is_decoration(kind) else 1.0
	return position.snapped(Vector2.ONE * step)

func object_rect(record: Dictionary) -> Rect2:
	return Rect2(record.position - Vector2(0.5, 0.5), Vector2(ResortCatalog.footprint(record.kind, record.orientation)))

func validate(kind: String, position: Vector2, orientation: int = 0, ignore_id: int = -1) -> Dictionary:
	var def := ResortCatalog.definition(kind)
	if def.is_empty():
		return {"ok": false, "reason": "Unknown object."}
	if not is_finite(position.x) or not is_finite(position.y) or snapped_position(kind, position) != position:
		return {"ok": false, "reason": "Align the object to its placement grid."}
	var size := ResortCatalog.footprint(kind, orientation)
	if orientation < 0 or orientation >= def.frames.size():
		return {"ok": false, "reason": "Choose an authored view for this object."}
	if kind == "pier" and not is_equal_approx(position.y, float(PIER_START)):
		return {"ok": false, "reason": "Anchor the pier at the shoreline, extending out to sea."}
	var proposed := Rect2(position - Vector2(0.5, 0.5), Vector2(size))
	var first := Vector2i(position.floor())
	var last := Vector2i((position + Vector2(size) - Vector2(0.001, 0.001)).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			var cell := Vector2i(x, y)
			if not contains(cell):
				return {"ok": false, "reason": "Keep the whole footprint inside the resort."}
			if not terrain(cell) in def.terrain:
				var reason := "Place this on dry beach sand." if def.category == "Beach" else "Place this on inland grass."
				return {"ok": false, "reason": reason}
			if is_path(cell):
				return {"ok": false, "reason": "Leave the path clear."}
	for record in objects:
		if record.id != ignore_id and proposed.intersects(object_rect(record)):
			return {"ok": false, "reason": "Another object occupies this space."}
	if def.get("access", false):
		var door := Vector2i(position) + ResortCatalog.entrance(kind, orientation)
		if not _entrance_is_accessible(door, ignore_id):
			return {"ok": false, "reason": "Connect the front entrance to a path or open beach."}
	# Decorative placements must not cover another building's access tile.
	for record in objects:
		if record.id == ignore_id:
			continue
		var other := ResortCatalog.definition(record.kind)
		if other.get("access", false):
			var doorway := Vector2(record.position) + Vector2(ResortCatalog.entrance(record.kind, record.orientation))
			if proposed.has_point(doorway):
				return {"ok": false, "reason": "Keep the neighbouring entrance open."}
	return {"ok": true, "reason": "Ready to place · click to confirm"}

func _entrance_is_accessible(door: Vector2i, ignore_id: int) -> bool:
	if not contains(door):
		return false
	if not is_path(door) and terrain(door) != "sand":
		return false
	for record in objects:
		if record.id != ignore_id and object_rect(record).has_point(Vector2(door)):
			return false
	var graph := navigation(ignore_id)
	return not graph.is_point_solid(ARRIVAL) and not graph.get_id_path(ARRIVAL, door).is_empty()

func place(kind: String, position: Vector2, orientation: int = 0) -> Dictionary:
	var result := validate(kind, position, orientation)
	if not result.ok:
		return result
	_seed(kind, position, orientation)
	revision += 1
	result["id"] = next_id - 1
	return result

func move_object(id: int, position: Vector2, orientation: int) -> Dictionary:
	var record := find_object(id)
	if record.is_empty():
		return {"ok": false, "reason": "Object no longer exists."}
	var result := validate(record.kind, position, orientation, id)
	if result.ok:
		record.position = position
		record.orientation = orientation
		revision += 1
	return result

func remove_object(id: int) -> void:
	for i in objects.size():
		if objects[i].id == id:
			objects.remove_at(i)
			revision += 1
			return

func find_object(id: int) -> Dictionary:
	for record in objects:
		if record.id == id:
			return record
	return {}

func set_path(cell: Vector2i, enabled: bool) -> Dictionary:
	if not contains(cell) or terrain(cell) not in ["grass", "sand"]:
		return {"ok": false, "reason": "Paths belong on grass or dry sand."}
	for record in objects:
		if object_rect(record).has_point(Vector2(cell)):
			return {"ok": false, "reason": "Move the object before laying a path here."}
	if enabled:
		paths[cell] = true
	else:
		if cell == ARRIVAL:
			return {"ok": false, "reason": "Keep the resort's arrival path open."}
		# Keep existing facility access attached while editing the first map.
		for record in objects:
			var def := ResortCatalog.definition(record.kind)
			if def.get("access", false) and Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation) == cell:
				return {"ok": false, "reason": "This tile serves a facility entrance."}
		var existed := is_path(cell)
		paths.erase(cell)
		for record in objects:
			var def := ResortCatalog.definition(record.kind)
			if def.get("access", false):
				var entrance := Vector2i(record.position) + ResortCatalog.entrance(record.kind, record.orientation)
				if not _entrance_is_accessible(entrance, -1):
					if existed: paths[cell] = true
					return {"ok": false, "reason": "This would disconnect a facility from the resort."}
	revision += 1
	return {"ok": true, "reason": "Path updated."}

func navigation(ignore_id: int = -1, allow_diagonal := false) -> AStarGrid2D:
	var graph := AStarGrid2D.new()
	graph.region = MAP_BOUNDS
	graph.cell_size = Vector2.ONE
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES if allow_diagonal else AStarGrid2D.DIAGONAL_MODE_NEVER
	graph.update()
	for x in MAP_SIZE.x:
		for y in range(INLAND_START, WALKABLE_END):
			var cell := Vector2i(x, y)
			graph.set_point_solid(cell, not (is_path(cell) or terrain(cell) == "sand"))
	for record in objects:
		if record.id == ignore_id:
			continue
		var rect := object_rect(record)
		for x in range(maxi(0, int(floor(rect.position.x + 0.5))), mini(MAP_SIZE.x, int(ceil(rect.end.x + 0.5)))):
			for y in range(maxi(INLAND_START, int(floor(rect.position.y + 0.5))), mini(WALKABLE_END, int(ceil(rect.end.y + 0.5)))):
				graph.set_point_solid(Vector2i(x, y), not ResortCatalog.definition(record.kind).get("walkable", false))
	return graph

func save_layout(path: String = SAVE_PATH) -> Error:
	var placed: Array = []
	for record in objects:
		placed.append({"id": record.id, "kind": record.kind, "position": [record.position.x, record.position.y], "orientation": record.orientation})
	var path_cells: Array = []
	for cell in paths:
		path_cells.append([cell.x, cell.y])
	var data := {"schema": SCHEMA, "objects": placed, "paths": path_cells, "next_id": next_id, "guest_stay": guest_stay,"live_resort":live_resort}
	if not prices.is_empty(): data["prices"] = prices
	var temp_path := "%s.%d-%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var verified := ResortLayout.new()
	var result := verified.load_layout(temp_path)
	if result == OK:
		# A corrupt primary must not replace the last good backup.
		if verified.load_layout(path) == OK:
			var backup_temp := temp_path + ".bak.tmp"
			result = DirAccess.copy_absolute(path, backup_temp)
			if result == OK:
				result = DirAccess.rename_absolute(backup_temp, path + ".bak")
			if FileAccess.file_exists(backup_temp):
				DirAccess.remove_absolute(backup_temp)
		if result == OK:
			result = DirAccess.rename_absolute(temp_path, path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	return result

func load_layout(path: String = SAVE_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return ERR_FILE_UNRECOGNIZED
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return ERR_FILE_UNRECOGNIZED
	var raw_schema: Variant=parsed.get("schema",-1)
	if not LivingResortRuntime._integer(raw_schema): return ERR_FILE_UNRECOGNIZED
	var file_schema := int(raw_schema)
	if file_schema not in [1, 2, 3, SCHEMA]:
		return ERR_FILE_UNRECOGNIZED
	# Decode into a temporary layout so a broken file cannot replace the visible map.
	var candidate := ResortLayout.new()
	var saved_prices: Variant = parsed.get("prices", {})
	if not saved_prices is Dictionary: return ERR_INVALID_DATA
	for key: Variant in saved_prices:
		if not ResortEconomy.DEFAULT_PRICES.has(key) or not ResortEconomy.valid_price(saved_prices[key]): return ERR_INVALID_DATA
		candidate.prices[key] = int(saved_prices[key])
	var used_ids: Dictionary = {}
	if not parsed.get("paths",[]) is Array or not parsed.get("objects",[]) is Array: return ERR_INVALID_DATA
	for cell in parsed.get("paths", []):
		if not cell is Array or cell.size() != 2:
			return ERR_INVALID_DATA
		if not LivingResortRuntime._integer(cell[0]) or not LivingResortRuntime._integer(cell[1]): return ERR_INVALID_DATA
		var point := Vector2i(int(cell[0]), int(cell[1]))
		if not candidate.contains(point) or candidate.terrain(point) not in ["grass", "sand"]:
			return ERR_INVALID_DATA
		candidate.paths[point] = true
	for entry in parsed.get("objects", []):
		if not entry is Dictionary or not ResortCatalog.DEFINITIONS.has(entry.get("kind", "")):
			return ERR_INVALID_DATA
		var xy: Variant = entry.get("position", [])
		if not xy is Array or xy.size() != 2: return ERR_INVALID_DATA
		if not (xy[0] is int or xy[0] is float) or not (xy[1] is int or xy[1] is float) or not is_finite(float(xy[0])) or not is_finite(float(xy[1])):
			return ERR_INVALID_DATA
		if not LivingResortRuntime._integer(entry.get("id")) or not LivingResortRuntime._integer(entry.get("orientation",0)): return ERR_INVALID_DATA
		var id := int(entry.get("id", -1))
		if id < 1 or used_ids.has(id):
			return ERR_INVALID_DATA
		used_ids[id] = true
		var pos := Vector2(float(xy[0]), float(xy[1]))
		var orientation := int(entry.get("orientation", 0))
		if orientation < 0 or orientation >= ResortCatalog.definition(entry.kind).frames.size():
			return ERR_INVALID_DATA
		# v1 assigned the +Y entrance to BOTH cabin images. Preserve the old
		# layout and paths by selecting the image whose actual doorway is +Y.
		if file_schema == 1 and entry.kind == "cabin":
			orientation = 1
		var validation := candidate.validate(entry.kind, pos, orientation)
		if not validation.ok:
			return ERR_INVALID_DATA
		candidate.objects.append({"id": id, "kind": entry.kind, "position": pos, "orientation": orientation})
		candidate.next_id = maxi(candidate.next_id, id + 1)
	var saved_stay: Variant = parsed.get("guest_stay", {})
	if not saved_stay is Dictionary:
		return ERR_INVALID_DATA
	if not saved_stay.is_empty():
		var check := GuestStay.new()
		check.configure(candidate, null)
		if not check.restore(saved_stay): return ERR_INVALID_DATA
	var saved_resort: Variant=parsed.get("live_resort",{})
	if not saved_resort is Dictionary: return ERR_INVALID_DATA
	if saved_resort.is_empty():
		for record in candidate.objects:
			if record.kind == ResortChallenges.STATUE: return ERR_INVALID_DATA
	if not saved_resort.is_empty():
		var check := LivingResortRuntime.new()
		if not check.configure(candidate,null) or not check.restore(saved_resort): return ERR_INVALID_DATA
	elif not saved_stay.is_empty():
		# Validate the complete migration before committing the map. GuestStay's
		# historical decoder alone permits numeric coercions the new model rejects.
		var check := LivingResortRuntime.new()
		if not check.configure(candidate,null) or not check.import_legacy(saved_stay): return ERR_INVALID_DATA
	objects = candidate.objects
	paths = candidate.paths
	next_id = candidate.next_id
	guest_stay = saved_stay.duplicate(true)
	live_resort = saved_resort.duplicate(true)
	prices = candidate.prices
	revision += 1
	return OK
