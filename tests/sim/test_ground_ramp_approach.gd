extends RefCounted
## Reach both ramp faces from floor input, including a blocked outer-back hit.


func run() -> bool:
	for direction in [-1.0, 1.0]:
		if not _approach(direction, false) or not _approach(direction, true):
			return false
	return true


func _approach(direction: float, outer_back: bool) -> bool:
	var left := ">>>" if outer_back else "<<<"
	var right := "<<<" if outer_back else ">>>"
	var row := "====%s============%s=========" % [left, right]
	var spawn_row := "====%s=====@======%s=========" % [left, right]
	var level := "ssk 2\nname ramp_approach\n---\nlayer 0\nheight 0\n%s\n%s\n%s\n%s\n%s\n" % [
		row, row, spawn_row, row, row,
	]
	var sim := PlayerSim.new()
	if not sim.setup_from_text(level, "ramp_approach"):
		return _fail(direction, outer_back, "fixture setup failed")
	var checkpoint := sim.checkpoint_position
	var reached_ramp := false
	for _i in range(180):
		sim.set_input(Vector2(direction, 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			if not outer_back:
				return _fail(direction, outer_back, "front approach crashed")
			if not sim.query.blocker_at(sim.state.position).is_empty():
				return _fail(direction, outer_back, "back impact left feet inside the wall")
			return true
		if sim.state.is_grounded() and sim.model.ramps.has(sim.state.surface_id):
			if outer_back:
				return _fail(direction, outer_back, "back approach mounted through the solid")
			reached_ramp = true
		if reached_ramp and sim.state.is_airborne():
			if sim.state.is_hanging() or not sim.state.free_air_upright:
				return _fail(direction, outer_back, "ramp peak did not leave upright in free air")
			if sim.state.velocity.x * direction <= 0.0 or sim.state.velocity.z <= 0.0:
				return _fail(direction, outer_back, "ramp peak lost rising/outward speed")
			if (sim.state.position.x - checkpoint.x) * direction <= 0.0:
				return _fail(direction, outer_back, "approach did not move toward the ramp")
			return true
	return _fail(direction, outer_back, "input never reached the expected climb or fall")


func _fail(direction: float, outer_back: bool, message: String) -> bool:
	push_error("ramp approach (%s, back=%s): %s" % [direction, outer_back, message])
	return false
