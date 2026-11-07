extends SceneTree

var failures: Array[String] = []
var resort: CoastalResort
var simulation: ResortSimulation
var view: ResortPopulationView

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_verify_court_clearances()
	var scene := load("res://scenes/world/coastal_resort.tscn") as PackedScene
	resort = scene.instantiate()
	resort.save_path = "res://artifacts/test-arrival-traffic.json"
	root.add_child(resort)
	resort.set_process(false)
	resort.autosave_enabled = false
	simulation = resort.living.simulation
	view = resort.population_view
	var car := simulation.party(1)
	var bay := int(car.arrival_bay)
	var first := int(car.member_ids[0])
	var drive_in := ArrivalTraffic.arrival_seconds(bay)
	_expect(view.vehicles.has(1) and not view.actors[first].visible, "First party starts inside its car")
	var road_start: Vector2 = view.vehicles[1].position
	_expect(is_equal_approx(IsometricGrid.unproject(road_start).y, ResortLayout.BACKDROP_REAR_EDGE) and is_equal_approx(ArrivalGeometry.ROAD.position.y, ResortLayout.BACKDROP_REAR_EDGE), "Vehicles enter at the road and terrain's shared edge")
	_advance_to(drive_in * 0.11)
	await _capture("road-edge")
	_advance_to(drive_in * 0.48)
	_expect(view.vehicles[1].position.distance_to(road_start) > 80.0, "Car drives in from the road")
	_expect(simulation.bookings.booking(1).is_empty(), "Guests in traffic do not reserve a cabin")
	_verify_restore()
	_advance_to(ArrivalTraffic.walk_start(bay, 0) + 0.40)
	_expect(view.actors[first].visible and view.actors[first].logical_position.x > ResortLayout.MAP_SIZE.x, "First passenger steps out into the parking court")
	_expect(IsometricGrid.unproject(view.vehicles[1].position).distance_to(ArrivalTraffic.bay(bay)) < 0.02, "Car is stopped in its assigned bay")
	await _capture("car")
	_advance_to(ArrivalTraffic.walk_end(bay, 1) + 1.0)
	_expect(view.actors[first].visible and view.actors[first].logical_position.x < ResortLayout.MAP_SIZE.x, "Guests continue walking inside the resort")
	_expect(simulation.bookings.booking(1).is_empty(), "Crossing the gate does not bypass reception")
	_verify_restore()
	for i in 100:
		if car.has("desk_started"): break
		_advance_to(simulation.clock + 0.25)
	_expect(car.has("desk_started") and simulation.bookings.booking(1).is_empty(), "The party waits for check-in at the desk")
	if car.has("desk_started"):
		var lead: GuestMotion = simulation.person(first).motion
		var desk := resort.layout.find_object(5)
		_expect(lead.position.is_equal_approx(desk.position + Vector2(ResortCatalog.entrance("reception"))), "Lead guest reaches the authored reception entrance")
		await _capture("reception")
		_advance_to(float(car.desk_started) + ArrivalTraffic.SERVICE_SECONDS + 0.35)
		_expect(not simulation.bookings.booking(1).is_empty(), "Reception releases a real reservation after check-in")
	_expect(view.vehicles.has(1), "Car stays parked after check-in")
	while simulation.party(4).is_empty() and simulation.clock < 225.0:
		_advance_to(simulation.clock + 0.25)
	var shuttle := simulation.party(4)
	_expect(not shuttle.is_empty() and shuttle.get("arrival_bay") == ArrivalTraffic.BUS, "A later party arrives by shuttle")
	if not shuttle.is_empty():
		var bus_first := int(shuttle.member_ids[0])
		var bus_age := ArrivalTraffic.walk_start(ArrivalTraffic.BUS, 0) + 0.7
		_advance_to(float(shuttle.created_at) + bus_age)
		_expect(view.vehicles.has(4) and view.actors[bus_first].visible, "Shuttle pulls in and passengers disembark")
		await _capture("shuttle")
		_advance_to(float(shuttle.created_at) + ArrivalTraffic.arrival_seconds(ArrivalTraffic.BUS) + ArrivalTraffic.BUS_DWELL + 2.25)
		await _capture("shuttle-turn")
		var shuttle_clear := ArrivalTraffic.arrival_seconds(ArrivalTraffic.BUS) + ArrivalTraffic.BUS_DWELL + ArrivalTraffic.exit_seconds(ArrivalTraffic.BUS)
		_advance_to(float(shuttle.created_at) + shuttle_clear + 0.3)
		_expect(not view.vehicles.has(4), "Shuttle leaves the layby after drop-off")
	_verify_restore()
	while not car.has("return_walk_at") and simulation.clock < 700.0:
		_advance_to(simulation.clock + 1.0)
	_expect(car.has("return_walk_at"), "Checkout schedules the parked car's departure")
	if car.has("return_walk_at"):
		_advance_to(float(car.return_walk_at) + 1.0)
		_expect(view.actors[first].visible, "Departed party walks back through the gate toward its parked car")
		_verify_restore()
		_advance_to(float(car.return_walk_at) + ArrivalTraffic.clear_seconds(bay) + 0.5)
		_expect(not view.vehicles.has(1), "Car reverses out and clears the road after checkout")
	print("ARRIVAL_TRAFFIC_CHECKS ", JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

func _verify_court_clearances() -> void:
	const Court = preload("res://scripts/simulation/arrival_geometry.gd")
	_expect(is_equal_approx(Court.MEDIAN - Court.WEST_EDGE, Court.EAST_EDGE - Court.MEDIAN), "The marked lanes have equal widths")
	var sand_edge := ResortLayout.BEACH_START - 0.5
	for walk: Rect2 in [Court.FRONT_WALK, Court.GATE_WALK, Court.MAIN_CROSSING, Court.EXIT_CROSSING]:
		_expect(walk.end.y < sand_edge, "The public sidewalk and both crossings end before the beach")
	_expect(is_equal_approx(Court.EXIT_CROSSING.position.x, Court.ROAD_EAST)
		and is_equal_approx(Court.EXIT_CROSSING.end.x, Court.LOT_WEST)
		and is_equal_approx(Court.EXIT_CROSSING.end.y, Court.FRONT_WALK.position.y), "The exit crossing fills the sidewalk gap and joins the front sidewalk")
	var pavement: Array[Rect2] = [Court.ROAD, Court.LOT, Court.ENTRY_APRON, Court.EXIT_APRON]
	var bus_bay := Court.bus_pavement()
	var car_half := Vector2(ArrivalVehicle.CAR_FRONT, ArrivalVehicle.CAR_HALF_WIDTH + 0.023) * ArrivalVehicle.CAR_SCALE
	for index in range(ArrivalTraffic.BUS, ArrivalTraffic.BAY_COUNT):
		var shuttle := index == ArrivalTraffic.BUS
		var half_size := Vector2(ArrivalVehicle.SHUTTLE_FRONT, ArrivalVehicle.SHUTTLE_HALF_WIDTH + 0.023) * ArrivalVehicle.SHUTTLE_SCALE if shuttle else car_half
		var routes := [ArrivalTraffic.arrival_route(index), ArrivalTraffic.exit_route(index)]
		if not shuttle: routes.append(ArrivalTraffic.backout_route(index))
		for route: PackedVector2Array in routes:
			var length := ArrivalTraffic.length(route)
			for step in range(1, ceili(length / 0.10)):
				var distance := minf(length, step * 0.10)
				var point := ArrivalTraffic.sample(route, distance)
				var ahead := ArrivalTraffic.sample(route, minf(length, distance + 0.13))
				var behind := ArrivalTraffic.sample(route, maxf(0.0, distance - 0.13))
				var heading := (ahead - behind).angle()
				var off_pavement := false
				var footprint := _vehicle_footprint(point, half_size, heading)
				for tire in footprint:
					if Geometry2D.is_point_in_polygon(tire, bus_bay): continue
					var on_surface := false
					for surface in pavement:
						if surface.grow(0.012).has_point(tire):
							on_surface = true
							break
					if not on_surface:
						off_pavement = true
						break
				if off_pavement:
					_expect(false, "Vehicle %d leaves pavement on route %d near %s" % [index, routes.find(route), point])
					break
				for parked in ArrivalTraffic.BAY_COUNT:
					var stall := Court.stall_center(parked)
					if parked == index or point.distance_squared_to(stall) > 9.0: continue
					var parked_car := _vehicle_footprint(stall, car_half, 0.0)
					if not Geometry2D.intersect_polygons(footprint, parked_car).is_empty():
						_expect(false, "Vehicle %d overlaps a parked car in bay %d on route %d near %s" % [index, parked, routes.find(route), point])
						return

func _vehicle_footprint(point: Vector2, half_size: Vector2, heading: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
		result.append(point + (half_size * corner).rotated(heading))
	return result

func _advance_to(target: float) -> void:
	resort.living.advance(maxf(0.0, target - simulation.clock) + 0.0001)
	view.refresh()

func _verify_restore() -> void:
	var snapshot := resort.living.capture()
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var candidate := LivingResortRuntime.new()
	_expect(candidate.configure(resort.layout, resort.assets) and candidate.restore(decoded), "Transport state survives JSON snapshot restore at %.1fs" % simulation.clock)
	if not decoded.simulation.parties.is_empty():
		decoded.simulation.parties[0].arrival_bay = ArrivalTraffic.BAY_COUNT
		_expect(not candidate.restore(decoded), "Out-of-range parking claims are rejected")

func _capture(tag: String) -> void:
	if not "--render" in OS.get_cmdline_user_args(): return
	root.size = Vector2i(1440, 900)
	resort.arrivals_view()
	if tag == "road-edge":
		resort.camera.position = IsometricGrid.project(Vector2(47, ResortLayout.BACKDROP_REAR_EDGE + 7.0))
	resort._refresh_management()
	resort.lighting.color = Color.WHITE
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/arrival-court-%s.png" % tag
	_expect(root.get_texture().get_image().save_png(path) == OK, "Save %s render" % tag)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
