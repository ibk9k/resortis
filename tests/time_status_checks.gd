extends SceneTree

var failures: Array[String] = []

func expect(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var resort := (load("res://scenes/world/coastal_resort.tscn") as PackedScene).instantiate() as CoastalResort
	resort.save_path = "res://artifacts/test-time-layout.json"
	root.add_child(resort)
	await process_frame
	resort.set_process(false)
	resort.hud.set_living_status(0.0, 0, false)
	expect(resort.hud.motion_label.text.begins_with("Day 1 · 00:00"), "The first day starts at midnight")
	resort.hud.set_living_status(90.0, 0, false)
	expect(resort.hud.motion_label.text.begins_with("Day 1 · 12:00"), "Half a simulation day is noon")
	resort.hud.set_living_status(179.99, 0, false)
	expect(resort.hud.motion_label.text.begins_with("Day 1 · 23:59"), "The clock stays on day one before the boundary")
	resort.hud.set_living_status(180.0, 0, true)
	expect(resort.hud.motion_label.text.begins_with("Day 2 · 00:00") and "Paused" in resort.hud.motion_label.text, "The next day and paused state remain visible")
	resort._on_action("pause")
	var before := float(resort.living.simulation.get("clock"))
	resort._process(0.1)
	resort._refresh_management()
	expect(is_equal_approx(float(resort.living.simulation.get("clock")), before) and "Paused" in resort.hud.motion_label.text, "Pausing holds the simulation clock displayed in the top bar")
	resort._on_action("speed_4")
	resort._process(0.1)
	expect(float(resort.living.simulation.get("clock")) > before, "Resuming at four times speed advances resort time")
	print("TIME_STATUS_CHECKS failures=", failures.size())
	resort.queue_free()
	quit(0 if failures.is_empty() else 1)
