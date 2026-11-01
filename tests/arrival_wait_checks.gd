extends SceneTree
## Exercise actual bookings and arrival turnover at a fully occupied resort.
var failures: Array[String] = []
func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var map := ResortLayout.new()
	expect(map.load_layout("res://data/coastal_map.json") == OK, "Load authored resort")
	var cabins := 0
	for record in map.objects.duplicate():
		if record.kind == "cabin":
			cabins += 1
			if cabins > 1: map.remove_object(record.id)
	var model := LivingResortRuntime.new()
	var assets := ResortAssets.new()
	expect(model.configure(map, assets), "Configure actual living resort")
	model.advance(50.0)
	model.simulation.set("arrivals_enabled", false)
	var waiters: Array[Dictionary] = []
	for guest: Dictionary in model.simulation.get("people"):
		if guest.state == "waiting_room": waiters.append(guest)
	expect(waiters.size() >= 2, "Actual full-cabin traffic reproduces several arrival waiters")
	for a in waiters.size():
		for b in range(a + 1, waiters.size()):
			var separation := (IsometricGrid.project(waiters[a].motion.position) - IsometricGrid.project(waiters[b].motion.position)).abs()
			expect(separation.x >= 42 or separation.y >= 60, "Waiting customers have distinct visible body space")
	var view := ResortPopulationView.new()
	root.add_child(view)
	view.configure(model, assets)
	var notice := view.get_node_or_null("ArrivalWaitNotice") as PanelContainer
	expect(notice != null and notice.visible, "Visible world notice explains the stationary arrival queue")
	if notice != null:
		var label := notice.get_node("Text") as Label
		expect(label.text.contains("Cabins full") and label.text.contains("leaves in"), "Notice gives full-cabin reason and bounded waiting time")
	var balances := {}
	for guest in waiters: balances[guest.party_id] = model.simulation.call("party", guest.party_id).budget
	model.advance(35.0)
	view.refresh()
	for guest in waiters:
		expect(guest.state == "departed", "Each unbooked waiting guest walks out within its deadline")
		var group: Dictionary = model.simulation.call("party", guest.party_id)
		expect(group.budget == balances[guest.party_id] and group.room_spent == 0 and group.activity_spent == 0, "Unaccommodated parties leave without charges")
	if notice != null: expect(not notice.visible, "Arrival notice clears after the queue leaves")
	view.free()
	print("ARRIVAL_WAIT_CHECKS failures=", failures.size(), " waiters=", waiters.size())
	quit(0 if failures.is_empty() else 1)
