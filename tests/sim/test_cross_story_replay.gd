extends RefCounted
## Deterministic L0 pipe -> wall -> air-out -> source wall replay.


func run() -> bool:
	return (
		_run_cycle("res://tests/levels/sim/sim_cross_story.ssk", "", NAN)
		and _run_cycle("res://debug_levels/layered_demo.ssk", "pipe_1_L0_S1", 1800.0)
	)


func _run_cycle(path: String, source_id: String, preferred_z: float) -> bool:
	var a := PlayerSim.new()
	var b := PlayerSim.new()
	if not a.setup_from_path(path) or not b.setup_from_path(path):
		push_error("cross-story replay setup: %s" % path)
		return false
	var wall := _choose_wall(a.model, source_id, preferred_z)
	if wall == null:
		push_error("cross-story replay missing wall: %s" % path)
		return false
	var source: PipeSurface = a.model.pipes[wall.source_pipe_id]
	var z := (wall.z_min + wall.z_max) * 0.5 if is_nan(preferred_z) else clampf(
		preferred_z, wall.z_min + 1.0, wall.z_max - 1.0
	)
	_seed_climb(a, source, z)
	var source_b: PipeSurface = b.model.pipes[source.id]
	_seed_climb(b, source_b, z)
	var events: PackedStringArray = PackedStringArray()
	var last_key := ""
	var saw_wall := false
	var saw_hang := false
	var returned_wall := false
	var previous_height := a.state.position.z
	var previous_fall_speed := 0.0
	for _tick in range(240):
		var wish := Vector2(source.outward_sign(), 0.0) if not saw_hang else Vector2.ZERO
		a.set_input(wish, false, false)
		b.set_input(wish, false, false)
		a.tick()
		b.tick()
		if not a.state.alive or not b.state.alive:
			push_error("cross-story replay invariant killed state: %s" % path)
			return false
		if a.state.state_hash() != b.state.state_hash():
			push_error("cross-story replay diverged at tick %d" % a.state.tick)
			return false
		if absf(a.state.position.z - previous_height) > 50.0:
			push_error(
				"cross-story replay teleported %.1f at tick %d"
				% [a.state.position.z - previous_height, a.state.tick]
			)
			return false
		previous_height = a.state.position.z
		if a.model.walls.has(a.state.surface_id):
			saw_wall = true
		if a.state.is_hanging():
			saw_hang = true
			if a.state.velocity.z < 0.0:
				var fall_speed := absf(a.state.velocity.z)
				if fall_speed + 0.01 < previous_fall_speed:
					push_error("cross-story replay fall speed was not monotonic")
					return false
				previous_fall_speed = fall_speed
		if not wall.upper_partner_pipe_id.is_empty() \
				and a.state.surface_id == wall.upper_partner_pipe_id:
			push_error("cross-story replay auto-transferred to upper pipe")
			return false
		var key := "%d:%s:%s" % [
			a.state.mode,
			a.state.surface_id,
			a.state.hang_edge_id,
		]
		if key != last_key:
			var speed := a.state.velocity.z if a.state.is_airborne() else a.state.tangent_velocity.x
			events.append(
				"t%d surface=%s edge=%s speed=%.2f"
				% [a.state.tick, a.state.surface_id, a.state.hang_edge_id, speed]
			)
			last_key = key
		if saw_hang and a.state.is_grounded() and a.state.surface_id == wall.id:
			returned_wall = true
			# One more grounded step proves the anchor is not a sticky top loop.
			a.set_input(Vector2.ZERO, false, false)
			b.set_input(Vector2.ZERO, false, false)
			a.tick()
			b.tick()
			if a.state.surface_id != wall.id or a.state.u >= 0.999:
				push_error("cross-story replay stuck at wall top")
				return false
			break
	if not saw_wall or not saw_hang or not returned_wall:
		push_error(
			"cross-story replay incomplete wall=%s hang=%s return=%s"
			% [saw_wall, saw_hang, returned_wall]
		)
		return false
	if a.trace.final_hash() != b.trace.final_hash():
		push_error("cross-story replay trace hash mismatch")
		return false
	print("CROSS_STORY_REPLAY %s %s" % [path.get_file(), " | ".join(events)])
	return true


func _choose_wall(model: ParkModel, source_id: String, preferred_z: float) -> WallSurface:
	for id in model.all_wall_ids():
		var wall: WallSurface = model.walls[id]
		if not source_id.is_empty() and wall.source_pipe_id != source_id:
			continue
		if not is_nan(preferred_z) and not wall.contains_z(preferred_z):
			continue
		return wall
	return null


func _seed_climb(sim: PlayerSim, pipe: PipeSurface, z: float) -> void:
	var theta := 0.9 * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 0.9
	sim.state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	sim.state.position = Vector3(
		pipe.x_at_theta(z, theta),
		z,
		pipe.height_at_theta(z, theta)
	)
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.maneuver = null
	sim.state.clear_hang()
