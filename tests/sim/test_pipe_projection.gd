extends RefCounted
## Projection uses the tangent of the actual pipe position curve.


func run() -> bool:
	for side in [SimKinds.PipeSide.LEFT, SimKinds.PipeSide.RIGHT]:
		for rise in [120.0, 141.0]:
			if not _frame_matches_curve(side, rise):
				return false
	return _joint_crash_retains_approach(false) and _joint_crash_retains_approach(true)


func _frame_matches_curve(side: int, rise: float) -> bool:
	var pipe := PipeSurface.new()
	pipe.id = "pipe_frame"
	pipe.side = side
	pipe.z_min = 0.0
	pipe.z_max = 100.0
	pipe.samples = [{"z": 0.0, "lip_x": 200.0, "radius": 141.0, "rise": rise, "base_height": 0.0}]
	pipe.rebuild_bounds()
	var air := AirSolver.new()
	for u in [0.0, 0.1, 0.4, 0.9, 1.0]:
		var theta: float = u * PI * 0.5
		var point := _point(pipe, theta)
		var projected := pipe.project(point.x, point.y, point.z)
		var a := _point(pipe, maxf(theta - 0.0001, 0.0))
		var b := _point(pipe, minf(theta + 0.0001, PI * 0.5))
		var derivative := (b - a).normalized()
		if derivative.distance_to(projected.tangent_along) > 0.002:
			return _fail("side=%s rise=%s u=%s tangent=%s derivative=%s" % [
				side, rise, u, projected.tangent_along, derivative,
			])
		var normal: Vector3 = projected.normal
		if absf(normal.dot(derivative)) > 0.002 or absf(normal.length() - 1.0) > 0.001:
			return _fail("surface normal is not perpendicular to the curve")
		var velocity := Vector3(400.0 * pipe.outward_sign(), 0.0, -100.0)
		var along := air._slope_along_from_world_vel(pipe, velocity, point, "")
		if absf(along - velocity.dot(derivative)) > 0.5:
			return _fail("landing did not project world velocity onto the curve tangent")
		if u == 0.1 and along < 370.0:
			return _fail("near-floor landing reversed uphill momentum")
	return true


## A slope Reject can reverse vx along the downhill tangent before the fall
## starts. Clearing that fall must keep the original side of the stacked joint.
func _joint_crash_retains_approach(mirror: bool) -> bool:
	var lower := "......(((===" if not mirror else "===)))......"
	var upper := "=@=)))......" if not mirror else "......(((=@="
	var text := (
		"ssk 2\nname projection_joint\n---\nlayer 0\nheight 0\n%s\n%s\n"
		+ "---\nlayer 1\nheight 120\n%s\n%s\n"
	) % [lower, lower, upper.replace("@", "="), upper]
	var sim := PlayerSim.new()
	if not sim.setup_from_text(text):
		return _fail("joint fixture setup")
	var wall: WallSurface
	for id in sim.model.all_wall_ids():
		var candidate: WallSurface = sim.model.walls[id]
		if not candidate.upper_partner_pipe_id.is_empty():
			wall = candidate
			break
	if wall == null:
		return _fail("joint fixture has no upper partner")
	var z := (wall.z_min + wall.z_max) * 0.5
	var sample := wall.sample_at_z(z)
	var face := float(sample.x)
	var travel := -1.0 if mirror else 1.0
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	sim.state.air_launch_surface_id = sim.state.surface_id
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3(face - travel * 50.0, z, float(sample.top_height) - 30.0)
	sim.state.velocity = Vector3(travel * 300.0, 0.0, -100.0)
	sim.state.set_facing_side("l" if mirror else "r")
	sim.state.note_air_height(sim.state.position.z)
	var fell := false
	for _i in range(100):
		sim.set_input(Vector2(travel, 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			fell = true
			if not sim.state.fall_has_impact_plane \
					or sim.state.fall_impact_normal.x * travel >= 0.0:
				return _fail("slope crash lost the incoming approach side")
		if (sim.state.position.x - face) * travel > SimTolerances.CONTACT_EPS:
			return _fail("fall cleared across the joint wall")
	return fell or _fail("joint approach did not crash")


func _point(pipe: PipeSurface, theta: float) -> Vector3:
	return Vector3(pipe.x_at_theta(50.0, theta), 50.0, pipe.height_at_theta(50.0, theta))


func _fail(message: String) -> bool:
	push_error("pipe frame: %s" % message)
	return false
