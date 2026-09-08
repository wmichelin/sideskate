extends RefCounted
## MotionVectors: named INPUT / MOMENTUM / ACTUAL triad.


const PLAYER := preload("res://scripts/player.gd")


func cases() -> Array:
	return ["names_and_units", "input_axis_limits", "flat_and_air_rates", "grind_rate",
		"pipe_rates", "ramp_rates", "lofted_pipe_rates", "lofted_ramp_rates", "wall_rate"]


func run() -> bool:
	var ok := true
	for test in cases():
		ok = bool(call(test)) and ok
	return ok


func names_and_units() -> bool:
	if MotionVectors.kind_name(MotionVectors.Kind.ACTUAL) != "actual":
		push_error("ACTUAL name")
		return false
	if MotionVectors.kind_name(MotionVectors.Kind.MOMENTUM) != "momentum":
		push_error("MOMENTUM name")
		return false
	if MotionVectors.kind_name(MotionVectors.Kind.INPUT) != "input":
		push_error("INPUT name")
		return false
	if not MotionVectors.is_planar(MotionVectors.Kind.INPUT):
		push_error("INPUT must be planar (X/Z only)")
		return false
	if MotionVectors.is_planar(MotionVectors.Kind.ACTUAL):
		push_error("ACTUAL may include height — not planar")
		return false
	if MotionVectors.is_planar(MotionVectors.Kind.MOMENTUM):
		push_error("MOMENTUM may include ramp vertical — not planar")
		return false
	# Stable enum ordinals — scene exports and save data depend on these.
	if int(MotionVectors.Kind.ACTUAL) != 0:
		push_error("ACTUAL ordinal must stay 0")
		return false
	if int(MotionVectors.Kind.MOMENTUM) != 1:
		push_error("MOMENTUM ordinal must stay 1")
		return false
	if int(MotionVectors.Kind.INPUT) != 2:
		push_error("INPUT ordinal must stay 2")
		return false
	return true


func _player_for(text: String):
	var player = PLAYER.new()
	player._sim = PlayerSim.new()
	if not player._sim.setup_from_text(text, "motion_vectors"):
		push_error("Motion fixture did not compile")
	return player


func _world(v: Vector3) -> Vector3:
	return WorldSpace.logical_velocity_to_world(v.x, v.y, v.z)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
	return ok


func _rates_equal(player, expected: Vector3, tolerance: float = 0.0001) -> bool:
	var before: String = player._sim.gameplay_hash()
	var momentum: Vector3 = player.motion_world(MotionVectors.Kind.MOMENTUM)
	var actual: Vector3 = player.motion_world(MotionVectors.Kind.ACTUAL)
	var ok := _check(momentum.distance_to(expected) <= tolerance and actual.distance_to(expected) <= tolerance,
		"World motion must match the integrated surface law: actual=%s expected=%s" % [actual, expected])
	ok = _check(player._sim.gameplay_hash() == before, "Motion readers must not mutate gameplay state") and ok
	return ok


func input_axis_limits() -> bool:
	var player = _player_for(FileAccess.get_file_as_string("res://tests/levels/runtime/flat.ssk"))
	player.max_speed_x = 880.0
	player.max_speed_z = 400.0
	player._last_wish = Vector2(0.5, -0.75)
	var expected := Vector3(-4.4, 0.0, -3.0)
	var ok := _check(player.motion_world(MotionVectors.Kind.INPUT).is_equal_approx(expected),
		"Input depth must use its own configured maximum speed")
	player.free()
	return ok


func flat_and_air_rates() -> bool:
	var player = _player_for(FileAccess.get_file_as_string("res://tests/levels/runtime/flat.ssk"))
	var sim: PlayerSim = player._sim
	sim.state.tangent_velocity = Vector2(-100, 40)
	var before := sim.state.position
	sim.set_input(Vector2(0, 0.2), false, false)
	sim.tick()
	var ok := _rates_equal(player, _world((sim.state.position - before) / SimTolerances.FIXED_DT), 0.001)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.velocity = Vector3(-200, 40, 120)
	ok = _rates_equal(player, Vector3(2.0, 1.2, 0.4)) and ok
	player.free()
	return ok


func grind_rate() -> bool:
	var player = _player_for(FileAccess.get_file_as_string("res://tests/levels/runtime/rail.ssk"))
	var sim: PlayerSim = player._sim
	var rail: RailSurface = sim.model.rails[sim.model.all_rail_ids()[0]]
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3((rail.x_min + rail.x_max) * 0.5, rail.z, rail.top_height + 10)
	sim.state.velocity = Vector3(-100, 0, -40)
	sim.set_input(Vector2.ZERO, false, false, false, false, false, false, true)
	sim.tick()
	var ok := _check(sim.state.is_grinding(), "Motion fixture must mount a rail")
	var before := sim.state.position
	sim.tick()
	ok = _rates_equal(player, _world((sim.state.position - before) / SimTolerances.FIXED_DT), 0.001) and ok
	ok = _check(player.motion_world(MotionVectors.Kind.ACTUAL).x > 0.9,
		"Grind velocity must retain signed rail speed despite zero tangent_velocity") and ok
	player.free()
	return ok


func pipe_rates() -> bool:
	return _slope_rates(false, false, 47.0) and _slope_rates(false, false, 80.0)


func ramp_rates() -> bool:
	return _slope_rates(true, false, 47.0) and _slope_rates(true, false, 80.0)


func lofted_pipe_rates() -> bool:
	return _slope_rates(false, true, 80.0)


func lofted_ramp_rates() -> bool:
	return _slope_rates(true, true, 80.0)


func _slope_rates(ramp: bool, lofted: bool, rise: float) -> bool:
	var rows := PackedStringArray()
	for count in [3, 3, 3, 3, 3]:
		rows.append("====" + ("<" if ramp else "(").repeat(count)
			+ "=".repeat(18 - count * 2) + (">" if ramp else ")").repeat(count) + "====")
	rows[2] = rows[2].left(13) + "@" + rows[2].substr(14)
	var text := "ssk 2\nstep_height %s\n---\nlayer 0\nheight 0\n%s\n" % [rise, "\n".join(rows)]
	var player = _player_for(text)
	var sim: PlayerSim = player._sim
	var surfaces: Dictionary = sim.model.ramps if ramp else sim.model.pipes
	var ok := _check(surfaces.size() == 2, "Motion fixture must provide both slope directions")
	for surface in surfaces.values():
		if lofted:
			# Exercise the supported sampled-surface law directly; the current
			# glyph compiler splits changing run widths into separate surfaces.
			for sample in surface.samples:
				var z_sample := float(sample.z)
				sample.lip_x += z_sample * 0.1
				sample.radius += z_sample * 0.15
				sample.rise += z_sample * 0.2
				sample.base_height += z_sample * 0.1
			surface.rebuild_bounds()
		for speed in [-100.0, 100.0]:
			var state := SimState.new()
			state.mode = SimState.Mode.GROUNDED
			state.surface_id = surface.id
			state.u = 0.4
			state.v = 0.25
			var z := 60.0
			state.position = Vector3(surface.x_at_theta(z, state.u * PI * 0.5), z,
				surface.height_at_theta(z, state.u * PI * 0.5))
			state.tangent_velocity = Vector2(speed, 40)
			sim.state = state
			var before := state.position
			sim.set_input(Vector2(0, 0.2), false, false)
			sim.tick()
			ok = _check(sim.state.is_grounded() and sim.state.surface_id == surface.id,
				"Measured motion must stay on its chosen surface") and ok
			var measured := _world((sim.state.position - before) / SimTolerances.FIXED_DT)
			ok = _check(measured.z > 0.5, "Slope motion must exercise nonzero depth drift") and ok
			# Curved paths use endpoint instantaneous rate versus a one-tick secant.
			ok = _rates_equal(player, measured, 0.025) and ok
	player.free()
	return ok


func wall_rate() -> bool:
	var player = _player_for(FileAccess.get_file_as_string("res://tests/levels/sim/sim_wall_extension.ssk"))
	var sim: PlayerSim = player._sim
	var wall: WallSurface = sim.model.walls.values()[0]
	sim.state = SimState.new()
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall.id
	sim.state.u = 0.5
	sim.state.position = wall.position_at((wall.z_min + wall.z_max) * 0.5, 0.5)
	sim.state.tangent_velocity = Vector2(100, 40)
	var before := sim.state.position
	sim.set_input(Vector2(0, 0.2), false, false)
	sim.tick()
	var ok := _check(sim.state.surface_id == wall.id, "Motion fixture must stay on wall")
	ok = _rates_equal(player, _world((sim.state.position - before) / SimTolerances.FIXED_DT), 0.001) and ok
	ok = _check(player.motion_world(MotionVectors.Kind.ACTUAL).y > 0.5,
		"Climbing wall motion must point upward") and ok
	player.free()
	return ok
