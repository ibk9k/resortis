extends RefCounted
## File locations and recovery order for one launcher or editor save location.

const MANUAL_COUNT := 6
const AUTOSAVE_SECONDS := 60.0

var legacy_path: String

static func launch_path(default_path: String = ResortLayout.SAVE_PATH) -> String:
	return "res://artifacts/coastal-layout.json" if "--workspace-data" in OS.get_cmdline_user_args() else default_path

func _init(path: String) -> void:
	legacy_path = path

func path_for(slot: int) -> String:
	if slot == -1:
		return legacy_path
	var directory := legacy_path.get_basename() + "-saves"
	return directory.path_join("autosave.json" if slot == 0 else "slot-%d.json" % slot)

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(MANUAL_COUNT + 1):
		result.append(_entry(slot, "Autosave" if slot == 0 else "Slot %d" % slot))
	var legacy := _entry(-1, "Previous save")
	if legacy.exists:
		result.append(legacy)
	return result

func startup_slots() -> Array[Dictionary]:
	var result := entries().filter(func(entry: Dictionary) -> bool: return entry.exists and entry.slot >= 0)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.modified == b.modified:
			return a.slot > b.slot
		return a.modified > b.modified
	)
	result.append(_entry(-1, "Previous save"))
	return result

func load_slot(slot: int, candidate: ResortLayout) -> Dictionary:
	var path := path_for(slot)
	if candidate.load_layout(path) == OK:
		return {"ok": true, "backup": false}
	if candidate.load_layout(path + ".bak") == OK:
		return {"ok": true, "backup": true}
	return {"ok": false}

func _entry(slot: int, label: String) -> Dictionary:
	var path := path_for(slot)
	var has_primary := FileAccess.file_exists(path)
	var exists := has_primary or FileAccess.file_exists(path + ".bak")
	var modified := FileAccess.get_modified_time(path if has_primary else path + ".bak") if exists else 0
	return {"slot": slot, "label": label, "exists": exists, "modified": modified, "backup_only": exists and not has_primary}
