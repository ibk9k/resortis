extends SceneTree

const SCENE := preload("res://scenes/world/coastal_resort.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _open_resort(path: String) -> CoastalResort:
	var resort := SCENE.instantiate() as CoastalResort
	resort.save_path = path
	root.add_child(resort)
	resort.set_process(false)
	resort.paused = true
	return resort

func _press(resort: CoastalResort, text: String) -> void:
	for node in resort.hud.save_content.find_children("*", "Button", true, false):
		if node.text == text:
			node.pressed.emit()
			return
	_expect(false, "Expected button: " + text)

func _clock(resort: CoastalResort) -> float:
	return resort.living.simulation.get("clock")

func _run() -> void:
	var path := "res://artifacts/test-save-slots-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var legacy := ResortLayout.new()
	legacy.seed_default()
	_expect(legacy.save_layout(path) == OK, "An existing legacy save is available")
	var legacy_hash := FileAccess.get_sha256(path)
	var resort := _open_resort(path)
	var slots := resort.save_slots
	var first := slots.path_for(1)
	var second := slots.path_for(2)
	var auto := slots.path_for(0)

	resort.living.advance(40.0)
	var first_clock := _clock(resort)
	var key := InputEventKey.new()
	key.keycode = KEY_S
	key.ctrl_pressed = true
	key.pressed = true
	resort._input(key)
	_expect(resort.hud.save_menu_open(), "Ctrl+S opens the save menu")
	var empty_load := resort.hud.save_content.find_child("LoadSlot2", true, false) as Button
	_expect(empty_load.disabled, "An empty manual slot cannot load")
	_press(resort, "Save")
	_expect(FileAccess.file_exists(first) and not FileAccess.file_exists(second), "Saving slot 1 writes its own file")
	var first_hash := FileAccess.get_sha256(first)
	for record in resort.layout.objects:
		if record.kind in ["palm", "small_palm"]:
			resort.selected_id = record.id
			break
	var removed_id := resort.selected_id
	_expect(removed_id > 0, "The starter map has a removable decoration")
	resort._on_action("remove")
	resort._management_action("hire_janitor", -1)
	resort.living.advance(150.0)
	var second_clock := _clock(resort)
	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("SaveSlot2", true, false).pressed.emit()
	_expect(FileAccess.file_exists(second) and FileAccess.get_sha256(first) == first_hash, "Saving slot 2 leaves slot 1 intact")

	resort.living.advance(20.0)
	var auto_clock := _clock(resort)
	resort.simulation_unsaved = true
	resort._process(59.0)
	_expect(not FileAccess.file_exists(auto), "Autosave waits for its full interval")
	resort._process(1.0)
	var recovery := ResortLayout.new()
	_expect(recovery.load_layout(auto) == OK and is_equal_approx(float(recovery.live_resort.simulation.clock), auto_clock),
		"Periodic autosave persists the current simulation clock")
	_expect(FileAccess.get_sha256(first) == first_hash and FileAccess.get_sha256(path) == legacy_hash,
		"Autosave preserves the manual and legacy files")

	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("LoadSlot1", true, false).pressed.emit()
	_expect(is_equal_approx(_clock(resort), auto_clock), "Load waits for confirmation")
	_press(resort, "Load resort")
	_expect(is_equal_approx(_clock(resort), first_clock), "Loading slot 1 restores its simulation")
	_expect(not resort.layout.find_object(removed_id).is_empty() and resort.undo_stack.is_empty(),
		"Loading slot 1 restores its layout and discards edits from the other resort's history")
	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("LoadSlot2", true, false).pressed.emit()
	_press(resort, "Load resort")
	_expect(is_equal_approx(_clock(resort), second_clock) and resort.living.inspect().cleanliness.staff.size() == 1,
		"Loading slot 2 restores its separate clock and staff")
	_expect(resort.layout.find_object(removed_id).is_empty(), "Slot 2 has its own layout edit")

	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("SaveSlot1", true, false).pressed.emit()
	_expect(FileAccess.get_sha256(first) == first_hash, "An occupied slot waits for overwrite confirmation")
	_press(resort, "Overwrite")
	_expect(FileAccess.get_sha256(first + ".bak") == first_hash, "Overwriting keeps the prior slot as a backup")
	_corrupt(first)
	_corrupt(second)
	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("LoadSlot2", true, false).pressed.emit()
	_press(resort, "Load resort")
	_expect(resort.hud.save_menu_open() and is_equal_approx(_clock(resort), second_clock),
		"A bad slot leaves the open resort in place")
	resort.hud.save_content.find_child("LoadSlot1", true, false).pressed.emit()
	_press(resort, "Load resort")
	_expect(is_equal_approx(_clock(resort), first_clock), "A corrupt primary can load its valid backup")
	resort.hud.tools.save.pressed.emit()
	resort.hud.save_content.find_child("SaveSlot1", true, false).pressed.emit()
	_press(resort, "Overwrite")
	_expect(FileAccess.get_sha256(first + ".bak") == first_hash, "Repairing a slot preserves its valid backup")
	_expect(resort.hud.tools.management.get_parent().find_children("ManagementMenu", "", false, false).size() == 1,
		"Reloading keeps one management menu")

	resort.free()
	DirAccess.remove_absolute(first)
	DirAccess.remove_absolute(first + ".bak")
	DirAccess.remove_absolute(second)
	resort = _open_resort(path)
	_expect(is_equal_approx(_clock(resort), auto_clock), "A new session resumes the available autosave")
	if "--review-saves" in OS.get_cmdline_user_args():
		resort.hud.tools.save.pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		var close := resort.hud.save_content.find_child("CloseSaves", true, false) as Button
		_expect(close.get_global_rect().end.y <= resort.hud.save_window.size.y, "The save menu footer fits with the legacy row visible")
		root.get_texture().get_image().save_png("res://artifacts/save-slots-review.png")
		resort.hud.save_content.find_child("LoadSlot0", true, false).pressed.emit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/save-slots-confirm-review.png")
	resort.free()
	print("SAVE_SLOT_CHECKS ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _corrupt(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("damaged")
	file.close()
