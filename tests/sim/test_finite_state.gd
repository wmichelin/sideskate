extends RefCounted
## Non-finite diagnostics must identify the field; -INF air-peak is intentional.


func expected_errors() -> Dictionary:
	return {"PlayerSim non-finite motion at tick 0:": PlayerSim.FINITE_STATE_FIELDS.size() * 2 + 4,
		"PlayerSim grind owner invariant at tick 0:": 1}


func run() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(FileAccess.get_file_as_string("res://tests/levels/sim/sim_rail_x.ssk"), "finite_state"):
		return false
	if not sim._assert_finite():
		return false
	for field in PlayerSim.FINITE_STATE_FIELDS:
		var previous: Variant = sim.state.get(field)
		for invalid in [NAN, INF]:
			var value: Variant = invalid
			if previous is Vector2:
				value = Vector2(invalid, 0.0)
			elif previous is Vector3:
				value = Vector3(0.0, invalid, 0.0)
			sim.state.set(field, value)
			if sim._assert_finite():
				return false
		sim.state.set(field, previous)
	sim.state.air_peak_height = INF
	if sim._assert_finite():
		return false
	sim.state.air_peak_height = -INF
	sim.last_wish = Vector2(NAN, 0.0)
	if sim._assert_finite():
		return false
	sim.last_wish = Vector2.ZERO
	sim.ollie_charge = INF
	if sim._assert_finite():
		return false
	sim.ollie_charge = 0.0
	sim.state.maneuver = ManeuverPlan.new()
	sim.state.maneuver.start_velocity = Vector3(0.0, 0.0, INF)
	if sim._assert_finite():
		return false
	sim.state.maneuver = null
	sim.state.mode = SimState.Mode.GRINDING
	sim.state.grind_rail_id = str(sim.model.rails.keys()[0])
	sim.state.surface_id = "invalid_owner"
	sim._assert_invariants("", false)
	sim.state.surface_id = sim.state.grind_rail_id
	sim._assert_invariants("", false)
	return sim._assert_finite()
