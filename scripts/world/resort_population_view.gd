class_name ResortPopulationView
extends Node2D
## Rendering follows live simulation identities; there is no decorative crowd.
var runtime: LivingResortRuntime
var assets: ResortAssets
var actors: Dictionary={}
var balls: Dictionary={}
var arrival_notice: PanelContainer
var vehicles: Dictionary = {}

func configure(model: LivingResortRuntime, library: ResortAssets) -> void:
	runtime=model
	assets=library
	y_sort_enabled=true
	refresh()

func refresh() -> void:
	_refresh_vehicles()
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
		_present_passenger(actor, person)
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

func _present_passenger(actor: ResortWalker, person: Dictionary) -> void:
	if person.state not in ["arriving", "departed"]: return
	var simulation := runtime.simulation as ResortSimulation
	var group := simulation.party(int(person.party_id))
	if not group.has("arrival_bay"): return
	var bay: int = group.arrival_bay
	var role: int = person.role
	var route := ArrivalTraffic.pedestrian_route(bay, role)
	var length := ArrivalTraffic.length(route)
	var walk_speed := length / ArrivalTraffic.walk_seconds(bay, role)
	var distance := 0.0
	var returning: bool = person.state == "departed"
	if returning:
		if bay == ArrivalTraffic.BUS: return
		var start := float(group.get("return_walk_at", simulation.clock)) + role * 0.65
		var elapsed := simulation.clock - start
		if elapsed < 0.0:
			actor.visible = true
			return
		distance = elapsed * walk_speed
		if distance >= length: return
		route.reverse()
	else:
		var age := simulation.clock - float(group.created_at)
		var start := ArrivalTraffic.walk_start(bay, role)
		if age < start:
			var vehicle := vehicles.get(int(group.id)) as ArrivalVehicle
			if vehicle != null: actor.position = vehicle.position
			actor.visible = false
			return
		distance = (age - start) * walk_speed
		if distance >= length: return
	var point := ArrivalTraffic.sample(route, distance)
	var next := ArrivalTraffic.sample(route, minf(length, distance + 0.075))
	actor.visible = true
	actor.present(point, distance, (next - point).normalized(), true)

func _refresh_vehicles() -> void:
	var simulation := runtime.simulation as ResortSimulation
	var visible := {}
	for group in simulation.parties:
		if not group.has("arrival_bay"): continue
		var bay: int = group.arrival_bay
		var id: int = group.id
		var inbound := ArrivalTraffic.arrival_route(bay)
		var drive_in := ArrivalTraffic.arrival_seconds(bay)
		var age := simulation.clock - float(group.created_at)
		var path := inbound
		var drive_time := minf(age, drive_in)
		var duration := drive_in
		var reverse := false
		var door := 0.0
		if bay == ArrivalTraffic.BUS:
			var leave := drive_in + ArrivalTraffic.BUS_DWELL
			if age > leave:
				path = ArrivalTraffic.exit_route(bay)
				duration = ArrivalTraffic.exit_seconds(bay)
				drive_time = age - leave
				if drive_time >= duration: continue
			else:
				door = _door_amount(age - drive_in, ArrivalTraffic.BUS_DWELL)
		elif group.state == "departed":
			var boarding := ArrivalTraffic.boarding_seconds(bay)
			var away := simulation.clock - float(group.get("return_walk_at", simulation.departure_time(group)))
			var out := away - boarding
			if out >= 0.0:
				path = ArrivalTraffic.backout_route(bay)
				var backing_time := ArrivalTraffic.backout_seconds(bay)
				if out < backing_time:
					reverse = true
					duration = backing_time
					drive_time = out
				else:
					path = ArrivalTraffic.exit_route(bay)
					duration = ArrivalTraffic.exit_seconds(bay)
					drive_time = out - backing_time
					if drive_time >= duration: continue
			else:
				door = _door_amount(away - boarding + 3.0, 3.0)
		else:
			door = _door_amount(age - drive_in, 2.8)
		visible[id] = true
		if not vehicles.has(id):
			var vehicle := ArrivalVehicle.new()
			vehicle.name = "ArrivalVehicle_%d" % id
			vehicle.configure(id, bay)
			add_child(vehicle)
			vehicles[id] = vehicle
		var vehicle: ArrivalVehicle = vehicles[id]
		var length := ArrivalTraffic.length(path)
		var phase := clampf(drive_time / duration, 0.0, 1.0)
		var distance := length * (phase - sin(TAU * phase) * 0.105)
		var route_point := ArrivalTraffic.sample(path, distance)
		var position_on_path := ArrivalTraffic.roadside_point(route_point)
		var leading := ArrivalTraffic.roadside_point(ArrivalTraffic.sample(path, minf(length, distance + 0.13)))
		var trailing := ArrivalTraffic.roadside_point(ArrivalTraffic.sample(path, maxf(0.0, distance - 0.13)))
		var heading := (leading - trailing).normalized()
		var edge_distance := absf(position_on_path.y - route_point.y - (ArrivalTraffic.roadside_point(path[0]).y - path[0].y))
		var roll := distance + edge_distance
		vehicle.present(position_on_path, -heading if reverse else heading, -roll if reverse else roll, door)
	for id in vehicles.keys():
		if visible.has(id): continue
		vehicles[id].free()
		vehicles.erase(id)

func _door_amount(elapsed: float, duration: float) -> float:
	return smoothstep(0.0, 0.55, elapsed) * (1.0 - smoothstep(duration - 0.65, duration, elapsed))

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
		var deadline := float(group.created_at) + ResortSimulation.ROOM_WAIT
		if group.has("desk_started"):
			deadline = float(group.desk_started) + ArrivalTraffic.SERVICE_SECONDS + ResortSimulation.ROOM_WAIT
		departure = minf(departure, deadline)
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
