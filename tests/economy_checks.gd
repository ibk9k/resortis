extends SceneTree

const SCENE := preload("res://scenes/world/coastal_resort.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _advance(resort: CoastalResort, seconds: float) -> void:
	for tick in int(seconds * 4.0):
		resort.living.advance(0.25)
	resort._refresh_management()

func _apply_price(resort: CoastalResort, service: String, price: int) -> void:
	var suffix := service.capitalize()
	var field := resort.management.root.find_child("Price" + suffix, true, false) as SpinBox
	var apply := resort.management.root.find_child("Apply" + suffix, true, false) as Button
	field.value = price
	apply.pressed.emit()

func _run() -> void:
	var resort := SCENE.instantiate() as CoastalResort
	resort.save_path = "res://artifacts/test-economy-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	root.add_child(resort)
	resort.set_process(false)
	var opening := ResortEconomy.OPENING_CASH
	expect(resort.living.cash() == opening and resort.hud.cash_label.text == "Cash $%d" % opening,
		"Starting balance appears on the game HUD")
	expect(ResortEconomy.COSTS.size() == ResortCatalog.DEFINITIONS.size() + 1, "Every catalogue item and path has a schedule")
	for kind: String in ResortCatalog.DEFINITIONS:
		var priced := ResortEconomy.purchase(kind) == 0 if kind == ResortChallenges.STATUE else ResortEconomy.purchase(kind) > 0
		expect(ResortEconomy.COSTS.has(kind) and priced, "Purchase schedule for " + kind)

	var palm := Vector2(1, 1)
	resort.start_build("small_palm")
	resort._commit_build_at(palm)
	var bought_id := resort.layout.next_id - 1
	var palm_cost := ResortEconomy.purchase("small_palm")
	expect(resort.layout.find_object(bought_id).position == palm and resort.living.cash() == opening - palm_cost,
		"Buying a decoration places it and debits its price once")
	expect(resort.hud.cash_label.text == "Cash $%d" % (opening - palm_cost), "Purchase immediately updates the HUD")
	var count: int = resort.living.ledger.receipt_count()
	resort._commit_build_at(palm)
	expect(resort.living.ledger.receipt_count() == count, "Blocked placement creates no receipt")
	resort.selected_id = bought_id
	resort._on_action("move")
	resort._commit_build_at(Vector2(2, 1))
	expect(resort.layout.find_object(bought_id).position == Vector2(2, 1) and resort.living.ledger.receipt_count() == count,
		"Moving an existing decoration is free")
	resort._on_action("undo")
	resort._on_action("undo")
	expect(resort.layout.find_object(bought_id).is_empty() and resort.living.cash() == opening, "Undoing the purchase records a full refund")
	resort._on_action("redo")
	expect(resort.layout.find_object(bought_id).position == palm and resort.living.cash() == opening - palm_cost, "Redo buys the same item again")
	resort.selected_id = bought_id
	resort._on_action("remove")
	expect(resort.living.cash() == opening - palm_cost, "Bulldozing creates no sale proceeds")

	var path_cell := Vector2i(0, 0)
	resort._on_action("path")
	resort._apply_path_at(path_cell)
	resort._apply_path_at(path_cell)
	expect(resort.layout.is_path(path_cell) and resort.living.cash() == opening - palm_cost - ResortEconomy.purchase("path"),
		"Laying the same tile twice costs one path receipt")
	resort._on_action("undo")
	expect(not resort.layout.is_path(path_cell) and resort.living.cash() == opening - palm_cost, "Undoing a path purchase refunds its price")

	_apply_price(resort, "room", 73)
	_apply_price(resort, "meal", 14)
	_apply_price(resort, "sunbathe", 9)
	_apply_price(resort, "volleyball", 11)
	resort._management_action("hire_janitor", -1)
	_advance(resort, 60.0)
	var original: Dictionary = resort.living.simulation.party(1)
	expect(original.rate == 73 and original.room_spent == 73, "A new booking pays the advertised nightly rate")
	_apply_price(resort, "room", 51)
	expect(original.rate == 73, "Changing the room price leaves the booking's agreed rate intact")
	var batched := LivingResortRuntime.new()
	expect(batched.configure(resort.layout, null) and batched.restore(JSON.parse_string(JSON.stringify(resort.living.capture()))),
		"A custom-price resort restores before the next billing boundary")
	_advance(resort, 185.0)
	batched.advance(185.0)
	expect(batched.ledger.capture().journal_hash == resort.living.ledger.capture().journal_hash,
		"Passing a billing boundary in a batch preserves the order and identity of every receipt")
	var operations := resort.living.inspect().operations as Dictionary
	var upkeep := 0
	for record in resort.layout.objects:
		upkeep += ResortEconomy.upkeep(record.kind)
	expect(operations.upkeep_total == upkeep and operations.wages_total == 30, "First completed day posts upkeep and wages once")
	expect(operations.net_total == operations.income_total - operations.expenses_total
		and operations.cash == opening + operations.net_total
		and resort.hud.cash_label.text == "Cash $%d" % operations.cash, "Statement, receipts and HUD cash reconcile")
	expect(original.paid_nights > 1 and original.room_spent == int(original.paid_nights) * 73, "Repeat nightly payments still use the booked rate")
	var custom_activity := false
	for event: Dictionary in resort.living.ledger.capture().events:
		if event.kind in ["meal", "sunbathe", "volleyball"]:
			custom_activity = custom_activity or (event.get("unit_price", 0) == resort.layout.price(event.kind) and event.amount == event.unit_price)
	expect(custom_activity, "An admitted guest paid a configured activity price")
	var journal_hash: String = resort.living.ledger.capture().journal_hash
	_apply_price(resort, "meal", 13)
	expect(resort.living.ledger.capture().journal_hash == journal_hash, "Changing a price leaves historical receipts intact")
	expect(resort._write_snapshot(resort.save_path) == OK, "The complete resort with costs and prices writes a valid file")
	var saved := ResortLayout.new()
	expect(saved.load_layout(resort.save_path) == OK and saved.price("room") == 51 and saved.price("meal") == 13,
		"Reload preserves the current advertised prices")
	var restored := LivingResortRuntime.new()
	expect(restored.configure(saved, null) and restored.restore(saved.live_resort) and restored.cash() == operations.cash,
		"Reload preserves net cash and the full receipt journal")
	restored.advance(0.25)
	expect(restored.inspect().operations.upkeep_total == upkeep, "Reload does not repeat the last upkeep")
	var invalid_path := resort.save_path.get_basename() + "-invalid.json"
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resort.save_path))
	invalid.prices.room = 0
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(invalid))
	invalid_file.close()
	expect(saved.load_layout(invalid_path) != OK and saved.price("room") == 51,
		"A malformed saved rate cannot replace the open map or prices")

	var legacy := ResortLayout.new()
	expect(legacy.load_layout("res://tests/fixtures/occupied-facility-queue.json") == OK
		and legacy.price("meal") == 12, "Existing live saves open with default prices")

	if "--review-economy" in OS.get_cmdline_user_args():
		resort._on_action("operations")
		for section in ["Statement", "Receipts", "Prices"]:
			resort.management.call("_show_finance_view", section)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/economy-%s-review.png" % section.to_lower())

	while resort.living.record_construction("pool"): pass
	while resort.living.record_construction("path"): pass
	var balance := resort.living.cash()
	var last_receipt: int = resort.living.ledger.receipt_count()
	resort._on_action("path")
	resort._apply_path_at(Vector2i(0, 1))
	expect(balance < ResortEconomy.purchase("path") and not resort.layout.is_path(Vector2i(0, 1))
		and resort.living.ledger.receipt_count() == last_receipt, "Insufficient cash blocks the real path tool without altering the map or journal")
	var current := resort.living.inspect().operations as Dictionary
	expect(current.receipt_pages > 1 and resort.living.inspect(-1, false, 1).operations.receipts[0].id != current.receipts[0].id,
		"Older journal entries are accessible through receipt pages")
	resort.free()
	print("ECONOMY_CHECKS ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
