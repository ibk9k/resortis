extends SceneTree

const SCENE := preload("res://scenes/world/coastal_resort.tscn")
const TIMED := ResortChallenges.TIMED
const STATUE := ResortChallenges.STATUE
const RALLY := ResortChallenges.STATUE_CHALLENGE
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _state(board: ResortChallenges, id: String, clock: float, ledger: RefCounted) -> String:
	for row in board.inspect(clock, ledger):
		if row.id == id: return row.state
	return ""

func _timed() -> void:
	var board := ResortChallenges.new()
	var ledger := OperatingLedger.new()
	ledger.record({"id": "before", "kind": "sunbathe", "time": 10.0, "amount": 8})
	expect(board.start(10.0, ledger) and not board.start(10.0, ledger), "A live attempt cannot restart")
	ledger.record({"id": "first-attempt", "kind": "sunbathe", "time": 140.0, "amount": 8})
	ledger.record({"id": "late", "kind": "sunbathe", "time": 190.01, "amount": 8})
	expect(_state(board, TIMED, 191.0, ledger) == "expired" and not board.claim(TIMED, 191.0, ledger),
		"Payments from before the attempt or after its deadline do not count")
	expect(board.start(200.0, ledger), "An expired challenge can be retried")
	ledger.record({"id": "retry-one", "kind": "sunbathe", "time": 360.0, "amount": 8})
	var restored := ResortChallenges.new()
	expect(restored.restore(JSON.parse_string(JSON.stringify(board.capture())), 360.0, ledger)
		and _state(restored, TIMED, 360.0, ledger) == "timed", "A live attempt keeps its start and progress on reload")
	ledger.record({"id": "retry-two", "kind": "sunbathe", "time": 380.0, "amount": 8})
	expect(_state(restored, TIMED, 400.0, ledger) == "complete", "An admission at the deadline counts and the reward waits for the player")
	expect(restored.claim(TIMED, 400.0, ledger) and not restored.claim(TIMED, 400.0, ledger) and not restored.start(400.0, ledger),
		"A successful attempt can pay only once")
	expect(ledger.inspect(400.0).reward_income == 180 and ledger.inspect(400.0).activity_income == 40,
		"Challenge cash is recorded separately from guest income")

func _button_for(resort: CoastalResort, id: String) -> Button:
	return resort.management.root.find_child("Challenge" + id.to_pascal_case(), true, false)

func _run() -> void:
	_timed()
	var resort := SCENE.instantiate() as CoastalResort
	resort.save_path = "res://artifacts/test-challenges-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(resort)
	resort.set_process(false)
	resort.hud.show_category("Garden")
	expect(not resort.hud.build_buttons.has(STATUE), "The statue starts locked in Garden")
	resort.start_build(STATUE)
	expect(resort.mode != "build", "The placement tool enforces the unlock")
	var popup: PopupMenu = resort.hud.tools.management.get_popup()
	popup.id_pressed.emit(4)
	expect(resort.management.get("_section") == "challenges", "Manage opens the challenge board")
	var start := _button_for(resort, TIMED)
	expect(start.visible and start.text == "Start challenge", "The timer waits for an explicit start")
	start.pressed.emit()
	expect(resort.dirty and _state(resort.living.challenges, TIMED, 0.0, resort.living.ledger) == "timed",
		"Starting the timed challenge is saved player state")
	# The starter's real population books, pays, and plays on the normal map.
	for tick in 1440:
		resort.living.advance(0.25)
	resort._refresh_management()
	var first := _button_for(resort, "first_nights")
	var cafe := _button_for(resort, "busy_cafe")
	var statue_button := _button_for(resort, RALLY)
	expect(first.visible and cafe.visible and statue_button.visible, "The natural starter earns the three untimed rewards (%s)" % JSON.stringify(resort.living.challenges.inspect(360.0, resort.living.ledger)))
	expect(_state(resort.living.challenges, TIMED, 360.0, resort.living.ledger) == "complete",
		"The starter can meet the timed goal through ordinary guest visits")
	var balance := resort.living.cash()
	first.pressed.emit()
	resort._challenge_action("claim", "first_nights")
	expect(resort.living.cash() == balance + 160 and resort.living.ledger.inspect(360.0).reward_income == 160,
		"Claiming cash updates the HUD ledger once")
	expect(resort.hud.cash_label.text == "Cash $%d" % (balance + 160), "The reward immediately reaches the top bar")
	statue_button.pressed.emit()
	expect(resort.living.challenges.statue_unlocked() and resort.hud.build_buttons.has(STATUE),
		"Claiming the rally reward unlocks the actual Garden decoration")
	statue_button.pressed.emit()
	expect(resort.mode == "build" and resort.build_kind == STATUE, "Place statue opens the real placement tool")
	var location := Vector2(27, 34)
	var object_id := resort.layout.next_id
	resort._commit_build_at(location)
	var record := resort.layout.find_object(object_id)
	expect(record.get("kind") == STATUE and resort.living.cash() == balance + 160,
		"The statue uses a real footprint and places for free")
	resort._on_action("undo")
	expect(resort.layout.find_object(object_id).is_empty() and resort.living.challenges.statue_unlocked(),
		"Undo removes the placement while retaining the earned reward")
	resort._on_action("redo")
	expect(resort.layout.find_object(object_id).get("kind") == STATUE, "Redo restores the placed decoration")

	expect(resort._write_snapshot(resort.save_path) == OK, "A resort with a claimed reward and placed statue saves")
	var saved := ResortLayout.new()
	expect(saved.load_layout(resort.save_path) == OK and saved.find_object(object_id).get("kind") == STATUE, "The statue survives a real file round-trip")
	var restored := LivingResortRuntime.new()
	expect(restored.configure(saved, null) and restored.restore(saved.live_resort) and restored.challenges.statue_unlocked(),
		"Reload preserves challenge progress and the unlock")
	expect(not restored.challenges.claim("first_nights", 360.0, restored.ledger), "Reload cannot duplicate a cash reward")
	var invalid: Dictionary = restored.capture()
	invalid.challenges.claims.erase("first_nights")
	expect(not restored.restore(invalid), "An unpaired cash reward receipt invalidates the save")
	invalid = restored.capture()
	invalid.challenges.claims.erase(RALLY)
	expect(not restored.restore(invalid) and restored.challenges.statue_unlocked(), "A forged unlock leaves the open resort intact")

	if "--review-challenges" in OS.get_cmdline_user_args():
		resort._on_action("challenges")
		resort.camera.zoom = Vector2.ONE * 1.12
		resort.camera.position = IsometricGrid.project(location) + Vector2(120, 0)
		resort.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/challenges-board-review.png")
		resort.management.close()
		resort.camera.zoom = Vector2.ONE * 1.78
		resort.camera.position = IsometricGrid.project(location) - Vector2(0, 20)
		resort.camera.force_update_scroll()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/challenges-statue-review.png")

	resort.free()
	print("CHALLENGE_CHECKS ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
