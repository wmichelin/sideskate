extends RefCounted
## Rising through an owned wall face is a corridor; free-air penetration is not.


func run() -> bool:
	return _wall_ollie_corridor() and _ramp_fixture_checkpoint_is_clear()


func _wall_ollie_corridor() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(
		FileAccess.get_file_as_string("res://tests/levels/sim/sim_l0_air_out_l1_deck.ssk"),
		"wall_ollie_corridor",
	):
		return _fail("wall fixture setup failed")
	var wall: WallSurface = sim.model.walls[sim.model.all_wall_ids()[0]]
	var pipe: PipeSurface = sim.model.pipes[wall.source_pipe_id]
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.92
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.position = Vector3(
		pipe.x_at_theta(z, u * PI * 0.5), z, pipe.height_at_theta(z, u * PI * 0.5)
	)
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.ollie_accel = 0.0
	sim.ollie_height_pipe = 120.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_charge = 1.0
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var checked_corridor := false
	var remounted := false
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			return _fail("owned wall ollie began a fall")
		var blocker := sim.query.blocker_at(sim.state.position)
		if sim.state.is_airborne() and str(blocker.get("kind", "")) == "wall":
			if not sim.state.is_hanging() or sim.state.velocity.z <= 0.0:
				return _fail("wall contact did not belong to a rising hang")
			if not sim.air._air_invariant_blocker(sim.state).is_empty():
				return _fail("diagnostic reported the permitted wall corridor")
			if not checked_corridor:
				var invalid := SimState.new()
				invalid.mode = SimState.Mode.AIRBORNE
				invalid.position = sim.state.position
				invalid.velocity = sim.state.velocity
				if sim.air._air_invariant_blocker(invalid).is_empty():
					return _fail("diagnostic hid free-air wall penetration")
				invalid.begin_hang(sim.state.hang_edge_id)
				invalid.velocity = Vector3(100.0, 0.0, sim.state.velocity.z)
				if sim.air._air_invariant_blocker(invalid).is_empty():
					return _fail("diagnostic hid lateral motion through the wall")
				invalid.velocity = Vector3(0.0, 0.0, -100.0)
				if sim.air._air_invariant_blocker(invalid).is_empty():
					return _fail("diagnostic hid descending unmounted wall contact")
			checked_corridor = true
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id and sim.state.surface_id != pipe.id:
				return _fail("wall ollie remounted a foreign owner")
			remounted = true
			break
	if not checked_corridor or not remounted:
		return _fail("did not observe the wall corridor and source remount")
	return true


func _ramp_fixture_checkpoint_is_clear() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(
		FileAccess.get_file_as_string("res://tests/levels/sim/sim_ramp_deck.ssk"),
		"ramp_fixture_checkpoint",
	):
		return _fail("ramp fixture setup failed")
	if sim.checkpoint_surface_id.is_empty() \
			or not sim.query.blocker_at(sim.checkpoint_position).is_empty():
		return _fail("ramp fixture seeded a checkpoint inside a solid")
	sim.respawn()
	if not sim.state.is_grounded() or not sim.query.blocker_at(sim.state.position).is_empty():
		return _fail("ramp fixture restored an invalid checkpoint")
	return true


func _fail(message: String) -> bool:
	push_error("sim invariants: %s" % message)
	return false
