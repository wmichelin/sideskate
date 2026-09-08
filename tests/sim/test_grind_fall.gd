extends RefCounted
## Balance failure preserves signed rail speed through the existing fall bout.


func run() -> bool:
	return _balance_failure(100.0) and _balance_failure(-100.0)


func _balance_failure(speed: float) -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(
		FileAccess.get_file_as_string("res://tests/levels/sim/sim_grind_fall.ssk"),
		"sim_grind_fall",
	):
		return _fail(speed, "fixture setup failed")
	var checkpoint_id := sim.checkpoint_surface_id
	var checkpoint_position := sim.checkpoint_position
	var rail: RailSurface = sim.model.rails[sim.model.all_rail_ids()[0]]
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3(
		(rail.x_min + rail.x_max) * 0.5, rail.z, rail.top_height + 10.0
	)
	sim.state.velocity = Vector3(speed, 0.0, -40.0)
	sim.set_input(Vector2.ZERO, false, false, false, false, false, false, true)
	sim.tick()
	if not sim.state.is_grinding() or not is_equal_approx(sim.state.grind_along, speed):
		return _fail(speed, "air approach did not mount with its forward speed")
	for _i in range(90):
		sim.set_input(Vector2.ONE * signf(speed), false, false)
		sim.tick()
		if sim.state.falling:
			break
	if not sim.state.falling or not sim.state.is_airborne():
		return _fail(speed, "balance failure did not enter an airborne fall")
	if not is_equal_approx(sim.state.velocity.x, speed):
		return _fail(speed, "fall entry discarded forward speed: %s" % sim.state.velocity.x)
	if not is_equal_approx(sim.state.fall_start_vx, speed):
		return _fail(speed, "fall envelope captured the wrong speed: %s" % sim.state.fall_start_vx)
	var saw_half_speed := false
	var saw_stopped := false
	var recovered := false
	for _i in range(180):
		var elapsed := sim.state.fall_elapsed
		var expected := speed * (1.0 - clampf(elapsed / sim.fall_stop_duration, 0.0, 1.0))
		# Held movement/grind must neither interrupt the fall nor remount the rail.
		sim.set_input(Vector2.ONE, false, false, false, false, false, false, true)
		sim.tick()
		if sim.state.is_grinding():
			return _fail(speed, "remounted during fall recovery")
		if not sim.state.falling:
			if elapsed + SimTolerances.FIXED_DT < sim.fall_duration - 0.0001:
				return _fail(speed, "recovered before the fall duration")
			recovered = true
			break
		var actual := (
			sim.state.velocity.x if sim.state.is_airborne() else sim.state.tangent_velocity.x
		)
		if absf(actual - expected) > 0.01:
			return _fail(speed, "stop envelope at %.3fs: got %.3f expected %.3f" % [elapsed, actual, expected])
		if absf(elapsed - sim.fall_stop_duration * 0.5) < 0.0001:
			saw_half_speed = true
		if elapsed >= sim.fall_stop_duration and absf(actual) < 0.01:
			saw_stopped = true
	if not recovered or not saw_half_speed or not saw_stopped:
		return _fail(speed, "did not observe timed slowdown, stop and recovery")
	if not sim.state.is_grounded() or sim.state.surface_id != checkpoint_id:
		return _fail(speed, "did not restore the floor checkpoint")
	if sim.state.position.distance_to(checkpoint_position) > 0.01:
		return _fail(speed, "restored the wrong checkpoint position")
	if not sim.query.blocker_at(sim.state.position).is_empty() or not sim.state.position.is_finite():
		return _fail(speed, "restored an invalid checkpoint pose")
	sim.set_input(Vector2.RIGHT, false, false)
	sim.tick()
	if sim.state.falling or sim.state.tangent_velocity.x <= 0.0:
		return _fail(speed, "movement control did not resume after recovery")
	return true


func _fail(speed: float, message: String) -> bool:
	push_error("grind fall (%s): %s" % [speed, message])
	return false
