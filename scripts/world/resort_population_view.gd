class_name ResortPopulationView
extends Node2D
## Rendering follows live simulation identities; there is no decorative crowd.
var runtime: LivingResortRuntime
var assets: ResortAssets
var actors: Dictionary={}
var balls: Dictionary={}
var arrival_notice: PanelContainer

func configure(model: LivingResortRuntime, library: ResortAssets) -> void:
	runtime=model
	assets=library
	y_sort_enabled=true
	refresh()

func refresh() -> void:
	_refresh_arrival_notice()
	var seen: Dictionary={}
	var rallies: Dictionary={}
	for person: Dictionary in runtime.simulation.get("people"):
		var id := int(person.id)
		seen[id]=true
		if not actors.has(id):
			var actor := ResortWalker.new()
			actor.variant=person.profile.variant
			actor.configure(id,Vector2i(person.motion.position.round()),runtime.layout.navigation(),[],assets)
			actor.name="Guest_%d_%s" % [id,person.profile.name]
			add_child(actor)
			actors[id]=actor
		var actor: ResortWalker=actors[id]
		actor.visible=person.state!="departed"
		actor.present(person.motion.position,person.motion.distance,person.motion.direction,person.motion.moving)
		var slot: Dictionary=runtime.simulation.call("activity_slot",id)
		if not slot.is_empty():
			var time := float(person.get("activity_elapsed",0))
			if person.state=="volleyball":
				var ticket: Dictionary=runtime.facilities.call("ticket",id)
				var partner_id := int(ticket.get("partner_id",0))
				var partner: Dictionary=runtime.simulation.call("person",partner_id)
				if not partner.is_empty() and partner.state=="volleyball":
					time=minf(time,float(partner.get("activity_elapsed",0)))
					var key := "%d/%d" % [mini(id,partner_id),maxi(id,partner_id)]
					rallies[key]=[person,partner,time]
				if int(ticket.get("slot",0))==1: time+=2.0
			actor.present_activity(slot,time)
	for id: int in actors.keys():
		if not seen.has(id):
			actors[id].free()
			actors.erase(id)
	for key: String in rallies:
		if not balls.has(key):
			var ball := VolleyBallView.new()
			add_child(ball)
			balls[key]=ball
		var pair: Array=rallies[key]
		var a: Dictionary=pair[0]
		var b: Dictionary=pair[1]
		var ticket: Dictionary=runtime.facilities.call("ticket",int(a.id))
		if int(ticket.get("slot",0))==1:
			a=pair[1]
			b=pair[0]
		var left: Dictionary=runtime.simulation.call("activity_slot",int(a.id))
		var right: Dictionary=runtime.simulation.call("activity_slot",int(b.id))
		if not left.is_empty() and not right.is_empty():
			balls[key].present_rally(left,right,float(pair[2]),str(a.profile.variant),str(b.profile.variant))
	for key: String in balls.keys():
		if not rallies.has(key):
			balls[key].free()
			balls.erase(key)

func _refresh_arrival_notice() -> void:
	if arrival_notice == null:
		arrival_notice = PanelContainer.new()
		arrival_notice.name = "ArrivalWaitNotice"
		arrival_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arrival_notice.z_index = 500
		var background := StyleBoxFlat.new()
		background.bg_color = Color("fff2d5")
		background.border_color = Color("b87731")
		background.set_border_width_all(1)
		background.set_corner_radius_all(5)
		background.content_margin_left = 10
		background.content_margin_right = 10
		background.content_margin_top = 4
		background.content_margin_bottom = 4
		arrival_notice.add_theme_stylebox_override("panel", background)
		var label := Label.new()
		label.name = "Text"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("43311f"))
		label.add_theme_font_size_override("font_size", 12)
		arrival_notice.add_child(label)
		add_child(arrival_notice)
	var count := 0
	var anchor := Vector2.ZERO
	var departure := INF
	var simulation := runtime.simulation
	for guest: Dictionary in simulation.get("people"):
		if guest.state != "waiting_room": continue
		count += 1
		anchor += guest.motion.position
		var group: Dictionary = simulation.call("party", guest.party_id)
		departure = minf(departure, float(group.created_at) + ResortSimulation.ROOM_WAIT)
	arrival_notice.visible = count > 0
	if count == 0: return
	var total := 0
	var occupied := 0
	for record in runtime.layout.objects:
		if record.kind != "cabin": continue
		total += 1
		if simulation.bookings.protects(record.id): occupied += 1
	var reason := "Cabins full" if total > 0 and occupied == total else "No suitable cabin"
	var seconds := maxi(0, ceili(departure - float(simulation.get("clock"))))
	(arrival_notice.get_node("Text") as Label).text = "%s · %d waiting\nNext party leaves in %ds" % [reason, count, seconds]
	arrival_notice.reset_size()
	arrival_notice.position = IsometricGrid.project(anchor / count) - Vector2(arrival_notice.size.x / 2.0, 103)

func hit_test(point: Vector2) -> int:
	var ordered: Array=actors.values()
	ordered.sort_custom(func(a: ResortWalker,b: ResortWalker) -> bool: return a.position.y>b.position.y)
	for actor: ResortWalker in ordered:
		if actor.visible and actor.hit_test(point): return actor.actor_id
	return -1

func actor_position(id: int) -> Vector2:
	return actors[id].position if actors.has(id) else Vector2.ZERO
