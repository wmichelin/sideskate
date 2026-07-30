class_name GroundSolver
extends RefCounted
## Constrained grounded integration on analytical surfaces.


var model: ParkModel
var query: SurfaceQuery


func _init(m: ParkModel = null, q: SurfaceQuery = null) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)


func spawn_state() -> SimState:
	var st := SimState.new()
	st.set_facing_side(model.spawn_facing if model != null else "r")
	st.position = Vector3(model.spawn_x, model.spawn_z, model.spawn_height)
	# Prefer the support at the IDL spawn height (story), not a lower pad that
	# shares the same XZ footprint.
	var top := _spawn_support(model.spawn_x, model.spawn_z, model.spawn_height)
	if top.is_empty():
		st.mode = SimState.Mode.AIRBORNE
		st.velocity = Vector3.ZERO
		return st
	st.mode = SimState.Mode.GROUNDED
	st.surface_id = str(top.surface_id)
	st.position.z = float(top.height)
	if int(top.kind) == SimKinds.SurfaceKind.PIPE \
			or int(top.kind) == SimKinds.SurfaceKind.RAMP:
		var proj: Dictionary = top.proj
		st.u = float(proj.u)
		st.v = float(proj.v)
		st.position = proj.point
	else:
		st.u = 0.0
		st.v = 0.0
	if top.get("lethal", false):
		st.alive = false
	return st


func _spawn_support(x: float, z: float, spawn_h: float) -> Dictionary:
	var all := query.supports_below(x, z, spawn_h + SimTolerances.CONTACT_EPS * 4.0)
	if all.is_empty():
		# Fallback: anything under a high search ceiling.
		all = query.supports_below(x, z, spawn_h + 5000.0)
	if all.is_empty():
		return {}
	# Exact / near spawn-height match first.
	for s in all:
		if absf(float(s.height) - spawn_h) <= SimTolerances.SEAM_EPS:
			return s
	# Otherwise the highest support at or below the spawn search ceiling.
	return all[0]


func step(
	state: SimState,
	wish: Vector2,
	delta: float,
	accel: float,
	max_speed: float,
	max_speed_z: float = 400.0,
	brake: float = 1250.0,
	friction: float = 0.0,
	ramp_friction: float = 0.0,
	ollie: bool = false,
	ollie_accel: float = 650.0,
) -> void:
	if not state.is_grounded() or not state.alive:
		return
	assert(delta > 0.0)
	# Feet must sit on the analytical surface — never remain buried in solids.
	_ensure_surface_contact(state)
	if not state.is_grounded() or not state.alive:
		return
	if model.pipes.has(state.surface_id):
		_step_pipe(
			state, wish, delta, accel, max_speed, max_speed_z,
			brake, friction, ramp_friction, ollie, ollie_accel
		)
	elif model.ramps.has(state.surface_id):
		_step_ramp(
			state, wish, delta, accel, max_speed, max_speed_z,
			brake, friction, ramp_friction, ollie, ollie_accel
		)
	elif model.walls.has(state.surface_id):
		_step_wall(
			state, wish, delta, accel, max_speed, max_speed_z,
			brake, ramp_friction, ollie, ollie_accel
		)
	elif model.patches.has(state.surface_id):
		_step_patch(
			state, wish, delta, accel, max_speed, max_speed_z,
			brake, friction, ollie, ollie_accel
		)
	else:
		push_error("GroundSolver: unknown surface %s" % state.surface_id)
		state.mode = SimState.Mode.AIRBORNE


func _step_patch(
	state: SimState,
	wish: Vector2,
	delta: float,
	accel: float,
	max_speed: float,
	max_speed_z: float,
	brake: float,
	friction: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	var patch: SupportPatch = model.patches[state.surface_id]
	if patch.lethal:
		state.alive = false
		return
	var on_deck := int(patch.kind) == SimKinds.SurfaceKind.DECK
	# Floor under an embedded pipe/ramp mounts the slope. Decks never auto-stick
	# to a pipe/ramp — ride-off falls (acid drop is the transfer button).
	if not on_deck:
		if _mount_slope_at(state, state.position.x, state.position.y, state.tangent_velocity.x):
			_update_facing_slope(state, state.surface_id)
			return
	# Stuck under a deck volume (floor wrap / clip) → only legal pose is the top.
	if _rescue_deck_top(state):
		_update_facing(state)
		return
	state.tangent_velocity.x = _integrate_axis(
		state.tangent_velocity.x, wish.x, max_speed, accel, brake, friction, delta
	)
	# Depth has no momentum: stick drives Z velocity; release snaps to 0.
	state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
	_apply_ollie_world_x(state, wish, delta, max_speed, ollie, ollie_accel)
	var next := state.position + Vector3(
		state.tangent_velocity.x * delta,
		state.tangent_velocity.y * delta,
		0.0
	)
	next.z = patch.height
	# World/space: axis-slide. Deck/pipe/wall: remount onto ride surface — never pin.
	var contained := _contain_ground_xz(state, next)
	if bool(contained.get("remounted", false)):
		if model.pipes.has(state.surface_id) or model.ramps.has(state.surface_id):
			_update_facing_slope(state, state.surface_id)
		else:
			_update_facing(state)
		return
	if not bool(contained.get("ok", false)):
		_update_facing(state)
		return
	next = contained.pos
	# Entering a pipe/ramp footprint from floor → mount. From deck → fall (acid only).
	if not on_deck:
		if _mount_slope_at(state, next.x, next.y, state.tangent_velocity.x):
			_update_facing_slope(state, state.surface_id)
			return
	if patch.contains_xz(next.x, next.y):
		state.position = next
		_update_facing(state)
		return
	# Left patch — try seam to neighboring support or air.
	var top := query.top_support(next.x, next.y, patch.height + SimTolerances.CONTACT_EPS)
	if not top.is_empty() and absf(float(top.height) - patch.height) <= SimTolerances.SEAM_EPS:
		# Deck → pipe/ramp at matching lip height is not a seam; acid drop only.
		if on_deck and _is_slope_kind(int(top.kind)):
			_enter_air(state, Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0))
			return
		state.surface_id = str(top.surface_id)
		state.position = Vector3(next.x, next.y, float(top.height))
		if _is_slope_kind(int(top.kind)):
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			# World X → along-arc: +along = toward coping = outward.
			state.tangent_velocity.x = state.tangent_velocity.x * _slope_outward(state.surface_id)
		if top.get("lethal", false):
			state.alive = false
		_update_facing(state)
		return
	# World rim: stay on this patch — never fall out of the level into the void.
	if _stay_grounded_at_world_rim(state, patch, next):
		_update_facing(state)
		return
	# Ride-off into air (holes / unsupported interior edges / deck→pipe).
	_enter_air(state, Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0))


## Keep grounded feet on a patch when clamped against the park AABB rim.
## Map-edge decks/floors are walls, not air leave → void.
func _stay_grounded_at_world_rim(state: SimState, patch: SupportPatch, next: Vector3) -> bool:
	var at_rim := (
		next.x <= 0.001
		or next.x >= model.width - 0.001
		or next.y <= 0.001
		or next.y >= model.depth - 0.001
	)
	if not at_rim:
		return false
	var inset := 0.05
	var x := next.x
	var z := next.y
	if patch.x_max - patch.x_min > inset * 2.0:
		x = clampf(next.x, patch.x_min + inset, patch.x_max - inset)
	else:
		x = (patch.x_min + patch.x_max) * 0.5
	if patch.z_max - patch.z_min > inset * 2.0:
		z = clampf(next.y, patch.z_min + inset, patch.z_max - inset)
	else:
		z = (patch.z_min + patch.z_max) * 0.5
	if not patch.contains_xz(x, z):
		x = clampf(state.position.x, patch.x_min + inset, patch.x_max - inset)
		z = clampf(state.position.y, patch.z_min + inset, patch.z_max - inset)
		if not patch.contains_xz(x, z):
			return false
	if absf(x - next.x) > 0.001:
		state.tangent_velocity.x = 0.0
	if absf(z - next.y) > 0.001:
		state.tangent_velocity.y = 0.0
	state.position = Vector3(x, z, patch.height)
	return true


func _step_pipe(
	state: SimState,
	wish: Vector2,
	delta: float,
	accel: float,
	max_speed: float,
	max_speed_z: float,
	brake: float,
	friction: float,
	ramp_friction: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	var pipe: PipeSurface = model.pipes[state.surface_id]
	# +along = toward coping. Map world wish X by outward so both sides match.
	var along_wish := wish.x * pipe.outward_sign()
	var th := clampf(state.u, 0.0, 1.0) * PI * 0.5
	var g_along := SimTolerances.GRAVITY * sin(th)
	state.tangent_velocity.x = _integrate_axis(
		state.tangent_velocity.x, along_wish, max_speed, accel, brake, ramp_friction, delta
	)
	state.tangent_velocity.x += g_along * delta
	state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
	_apply_ollie_pipe(state, pipe, wish, delta, max_speed, ollie, ollie_accel)
	var sample := pipe.sample_at_z(state.position.y)
	var radius := float(sample.radius)
	if radius <= 0.001:
		return
	var new_theta := th + state.tangent_velocity.x * delta / radius
	var raw_z := state.position.y + state.tangent_velocity.y * delta
	var new_z := _clamp_park_depth(raw_z)
	if _pipe_z_out_of_span(pipe, new_z):
		if _leave_pipe_at_z_end(state, pipe, new_z):
			return
		new_z = _clamp_world_depth(pipe, new_z)
		state.tangent_velocity.y = 0.0
	if new_theta <= 0.0:
		_leave_pipe_at_lip(state, pipe, new_z)
		return
	if new_theta < PI * 0.5:
		state.u = new_theta / (PI * 0.5)
		state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
		state.position = Vector3(
			pipe.x_at_theta(new_z, new_theta),
			new_z,
			pipe.height_at_theta(new_z, new_theta)
		)
		_update_facing_pipe(state, pipe)
		return
	state.u = 1.0
	state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	state.position = Vector3(
		pipe.x_at_theta(new_z, PI * 0.5),
		new_z,
		pipe.height_at_theta(new_z, PI * 0.5)
	)
	var edge := query.edge_at(pipe.id, new_z, "coping")
	if edge == null:
		push_error("GroundSolver: missing coping edge for %s at z=%.2f" % [pipe.id, new_z])
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)
		return
	if model.walls.has(edge.to_surface_id):
		var wall: WallSurface = model.walls[edge.to_surface_id]
		var excess := maxf((new_theta - PI * 0.5) * radius, 0.0)
		_enter_wall_from_pipe(state, wall, new_z, excess)
		return
	if model.patches.has(edge.to_surface_id):
		_mount_patch_from_edge(state, pipe, model.patches[edge.to_surface_id], new_z)
		return
	if state.tangent_velocity.x > 1.0:
		_launch_from_edge(state, edge, new_z)
	else:
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)


func _step_ramp(
	state: SimState,
	wish: Vector2,
	delta: float,
	accel: float,
	max_speed: float,
	max_speed_z: float,
	brake: float,
	friction: float,
	ramp_friction: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	var ramp: RampSurface = model.ramps[state.surface_id]
	var along_wish := wish.x * ramp.outward_sign()
	# Constant 45° incline (rise == run width).
	var g_along := SimTolerances.GRAVITY * (1.0 / sqrt(2.0))
	state.tangent_velocity.x = _integrate_axis(
		state.tangent_velocity.x, along_wish, max_speed, accel, brake, ramp_friction, delta
	)
	state.tangent_velocity.x += g_along * delta
	state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
	_apply_ollie_slope(state, ramp.outward_sign(), wish, delta, max_speed, ollie, ollie_accel)
	var sample := ramp.sample_at_z(state.position.y)
	var radius := float(sample.radius)
	if radius <= 0.001:
		return
	var incline := ramp.incline_length(state.position.y)
	var u := clampf(state.u, 0.0, 1.0)
	var new_u := u + state.tangent_velocity.x * delta / maxf(incline, 0.001)
	var raw_z := state.position.y + state.tangent_velocity.y * delta
	var new_z := _clamp_park_depth(raw_z)
	if _slope_z_out_of_span(ramp, new_z):
		if _leave_slope_at_z_end(state, ramp, new_z):
			return
		new_z = _clamp_world_depth_slope(ramp, new_z)
		state.tangent_velocity.y = 0.0
	if new_u <= 0.0:
		_leave_slope_at_lip(state, ramp, new_z)
		return
	if new_u < 1.0:
		var th := new_u * PI * 0.5
		state.u = new_u
		state.v = clampf((new_z - ramp.z_min) / maxf(ramp.z_max - ramp.z_min, 0.001), 0.0, 1.0)
		state.position = Vector3(
			ramp.x_at_theta(new_z, th),
			new_z,
			ramp.height_at_theta(new_z, th)
		)
		_update_facing_slope(state, ramp.id)
		return
	state.u = 1.0
	state.v = clampf((new_z - ramp.z_min) / maxf(ramp.z_max - ramp.z_min, 0.001), 0.0, 1.0)
	state.position = Vector3(
		ramp.x_at_theta(new_z, PI * 0.5),
		new_z,
		ramp.height_at_theta(new_z, PI * 0.5)
	)
	var edge := query.edge_at(ramp.id, new_z, "coping")
	if edge == null:
		push_error("GroundSolver: missing coping edge for %s at z=%.2f" % [ramp.id, new_z])
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)
		return
	# Peak leave is always free-air along the incline tangent — never seam onto
	# an abutting deck/floor (that felt like sticky mounting) and never hang.
	if state.tangent_velocity.x > 1.0:
		_launch_from_ramp_peak(state, ramp, new_z)
	else:
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)


func _launch_from_ramp_peak(state: SimState, ramp: RampSurface, z: float) -> void:
	var along := state.tangent_velocity.x
	var inv := 1.0 / sqrt(2.0)
	var world_vx := along * ramp.outward_sign() * inv
	var world_vh := along * inv
	var world_vz := state.tangent_velocity.y
	# Nudge past the coping so feet clear the peak before ballistic flight.
	var peak_x := ramp.coping_x_at(z) + ramp.outward_sign() * SimTolerances.CAPSULE_RADIUS
	state.position = Vector3(peak_x, z, ramp.height_at_theta(z, PI * 0.5))
	_enter_air(state, Vector3(world_vx, world_vz, world_vh), "")


func _enter_wall_from_pipe(
	state: SimState, wall: WallSurface, z: float, excess_height: float
) -> void:
	var sample := wall.sample_at_z(z)
	var bottom := float(sample.bottom_height)
	var top := float(sample.top_height)
	var height := bottom + excess_height
	state.surface_id = wall.id
	state.v = clampf((z - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001), 0.0, 1.0)
	if height >= top - 0.001:
		state.u = 1.0
		state.position = wall.position_at(z, 1.0)
		_cross_wall_top(state, wall, z)
		return
	state.u = wall.u_at_height(z, height)
	state.position = wall.position_at(z, state.u)


func _step_wall(
	state: SimState,
	wish: Vector2,
	delta: float,
	accel: float,
	max_speed: float,
	max_speed_z: float,
	brake: float,
	ramp_friction: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	var wall: WallSurface = model.walls[state.surface_id]
	var source: PipeSurface = model.pipes[wall.source_pipe_id]
	var along_wish := wish.x * source.outward_sign()
	state.tangent_velocity.x = _integrate_axis(
		state.tangent_velocity.x, along_wish, max_speed, accel, brake, ramp_friction, delta
	)
	state.tangent_velocity.x += SimTolerances.GRAVITY * delta
	state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
	_apply_ollie_pipe(state, source, wish, delta, max_speed, ollie, ollie_accel)
	var new_z := _clamp_park_depth(state.position.y + state.tangent_velocity.y * delta)
	if not wall.contains_z(new_z):
		var source_edge := query.edge_at(source.id, new_z, "coping")
		if source_edge != null and model.walls.has(source_edge.to_surface_id):
			wall = model.walls[source_edge.to_surface_id]
			state.surface_id = wall.id
		else:
			# Consume the Z crossing before entering air. Leaving the position on
			# the old wall face remounts it next tick and pumps vertical speed.
			state.position = Vector3(state.position.x, new_z, state.position.z)
			_enter_air(
				state,
				Vector3(0.0, state.tangent_velocity.y, state.tangent_velocity.x)
			)
			return
	var sample := wall.sample_at_z(new_z)
	var bottom := float(sample.bottom_height)
	var top := float(sample.top_height)
	var new_height := state.position.z + state.tangent_velocity.x * delta
	if new_height <= bottom:
		var radius := float(source.sample_at_z(new_z).radius)
		var overshoot := bottom - new_height
		var theta := maxf(PI * 0.5 - overshoot / maxf(radius, 0.001), 0.0)
		state.surface_id = source.id
		state.u = theta / (PI * 0.5)
		state.v = clampf((new_z - source.z_min) / maxf(source.z_max - source.z_min, 0.001), 0.0, 1.0)
		state.position = Vector3(
			source.x_at_theta(new_z, theta),
			new_z,
			source.height_at_theta(new_z, theta)
		)
		_update_facing_pipe(state, source)
		return
	if new_height >= top:
		state.u = 1.0
		state.v = clampf((new_z - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001), 0.0, 1.0)
		state.position = wall.position_at(new_z, 1.0)
		_cross_wall_top(state, wall, new_z)
		return
	state.u = wall.u_at_height(new_z, new_height)
	state.v = clampf((new_z - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001), 0.0, 1.0)
	state.position = wall.position_at(new_z, state.u)
	_update_facing_pipe(state, source)


func _cross_wall_top(state: SimState, wall: WallSurface, z: float) -> void:
	var edge := query.edge_at(wall.id, z, "top")
	if edge == null:
		push_error("GroundSolver: missing wall top edge for %s" % wall.id)
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)
		return
	if model.patches.has(edge.to_surface_id):
		var source: PipeSurface = model.pipes[wall.source_pipe_id]
		_mount_patch_from_edge(state, source, model.patches[edge.to_surface_id], z)
		return
	if state.tangent_velocity.x > 1.0:
		_launch_from_edge(state, edge, z)
	else:
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)


func _mount_patch_from_edge(
	state: SimState, source, patch: SupportPatch, z: float
) -> void:
	var out := float(source.outward_sign())
	var anchor_x := float(source.coping_x_at(z))
	state.surface_id = patch.id
	state.position = Vector3(anchor_x + out * SimTolerances.CAPSULE_RADIUS, z, patch.height)
	state.u = 0.0
	state.v = 0.0
	state.tangent_velocity = Vector2(
		out * absf(state.tangent_velocity.x), state.tangent_velocity.y
	)
	state.velocity = Vector3.ZERO
	state.clear_hang()


func _launch_from_edge(state: SimState, edge: TopologyEdge, z: float) -> void:
	var anchor := query.edge_anchor_sample(edge, z)
	if anchor.is_empty():
		push_error("GroundSolver: invalid air-out edge %s" % edge.id)
		return
	var world_vh := state.tangent_velocity.x
	var world_vz := state.tangent_velocity.y
	state.position = Vector3(float(anchor.x), z, float(anchor.height))
	_enter_air(state, Vector3(0.0, world_vz, world_vh), edge.id)


## Exit pipe/ramp at the lip onto abutting floor/deck, or free-air if unsupported.
func _leave_pipe_at_lip(state: SimState, pipe: PipeSurface, z: float) -> void:
	_leave_slope_at_lip(state, pipe, z)


func _leave_slope_at_lip(state: SimState, surf, z: float) -> void:
	var lip_x := float(surf.x_at_theta(z, 0.0))
	var lip_h := float(surf.height_at_theta(z, 0.0))
	var outward := float(surf.outward_sign())
	var inward := -outward
	var onto_x := lip_x + inward * maxf(SimTolerances.CONTACT_EPS, 1.0)
	var world_vx := state.tangent_velocity.x * outward
	var world_vz := state.tangent_velocity.y
	var top := query.top_support(onto_x, z, lip_h + SimTolerances.CONTACT_EPS)
	if not top.is_empty() and absf(float(top.height) - lip_h) <= SimTolerances.SEAM_EPS:
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = str(top.surface_id)
		state.u = 0.0
		state.v = 0.0
		state.position = Vector3(onto_x, z, float(top.height))
		state.tangent_velocity = Vector2(world_vx, world_vz)
		if _is_slope_kind(int(top.kind)):
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			state.tangent_velocity.x = world_vx * _slope_outward(state.surface_id)
		if top.get("lethal", false):
			state.alive = false
		return
	state.position = Vector3(onto_x, z, lip_h)
	_enter_air(state, Vector3(world_vx, world_vz, 0.0))


func try_mount_surface(state: SimState, x: float, z: float, h: float) -> bool:
	var top := query.top_support(x, z, h)
	if top.is_empty():
		return false
	if absf(float(top.height) - h) > SimTolerances.CONTACT_EPS:
		return false
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = str(top.surface_id)
	state.maneuver = null
	state.position = Vector3(x, z, float(top.height))
	if _is_slope_kind(int(top.kind)):
		var proj: Dictionary = top.proj
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
	if top.get("lethal", false):
		state.alive = false
	return true


func _enter_air(state: SimState, world_vel: Vector3, hang_edge_id: String = "") -> void:
	state.mode = SimState.Mode.AIRBORNE
	state.surface_id = ""
	state.velocity = world_vel
	state.maneuver = null
	state.tangent_velocity = Vector2.ZERO
	state.air_peak_height = state.position.z
	if hang_edge_id.is_empty():
		state.clear_hang()
	else:
		state.begin_hang(hang_edge_id)


## Keep pipe depth inside both the pipe loft and the park AABB (inset from faces).
func _clamp_world_depth(pipe: PipeSurface, z: float) -> float:
	return _clamp_world_depth_slope(pipe, z)


func _clamp_world_depth_slope(surf, z: float) -> float:
	var z_eps := 0.05
	var world_lo := z_eps
	var world_hi := maxf(model.depth - z_eps, z_eps)
	var lo := maxf(float(surf.z_min), world_lo)
	var hi := minf(float(surf.z_max), world_hi)
	if hi < lo:
		return clampf(z, world_lo, world_hi)
	return clampf(z, lo, hi)


func _clamp_park_depth(z: float) -> float:
	var z_eps := 0.05
	return clampf(z, z_eps, maxf(model.depth - z_eps, z_eps))


func _pipe_z_out_of_span(pipe: PipeSurface, z: float) -> bool:
	return _slope_z_out_of_span(pipe, z)


func _slope_z_out_of_span(surf, z: float) -> bool:
	return z < float(surf.z_min) - 0.001 or z > float(surf.z_max) + 0.001


## Ride off a pipe's near/far end into a same-height support or free air (holes).
## Returns true when the skater left the pipe.
func _leave_pipe_at_z_end(state: SimState, pipe: PipeSurface, proposed_z: float) -> bool:
	return _leave_slope_at_z_end(state, pipe, proposed_z)


func _leave_slope_at_z_end(state: SimState, surf, proposed_z: float) -> bool:
	var theta := clampf(state.u, 0.0, 1.0) * PI * 0.5
	var end_z := clampf(proposed_z, float(surf.z_min), float(surf.z_max))
	var x := float(surf.x_at_theta(end_z, theta))
	var h := float(surf.height_at_theta(end_z, theta))
	var outward := float(surf.outward_sign())
	var world_vx := state.tangent_velocity.x * outward
	var world_vz := state.tangent_velocity.y
	var top := query.top_support(x, proposed_z, h + SimTolerances.CONTACT_EPS)
	if not top.is_empty() and absf(float(top.height) - h) <= SimTolerances.SEAM_EPS:
		state.surface_id = str(top.surface_id)
		state.position = Vector3(x, proposed_z, float(top.height))
		if _is_slope_kind(int(top.kind)):
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			state.tangent_velocity.x = world_vx * _slope_outward(state.surface_id)
		else:
			state.u = 0.0
			state.v = 0.0
			state.tangent_velocity = Vector2(world_vx, world_vz)
		if top.get("lethal", false):
			state.alive = false
		_update_facing(state)
		return true
	if not model.is_traversable_xz(x, proposed_z):
		return false
	# Step past endcap wall thickness so leave-into-air is not immediately bounced.
	var past_z := proposed_z
	var thick := SimTolerances.CAPSULE_RADIUS + 1.0
	if proposed_z > float(surf.z_max):
		past_z = float(surf.z_max) + thick
	elif proposed_z < float(surf.z_min):
		past_z = float(surf.z_min) - thick
	past_z = _clamp_park_depth(past_z)
	var probe := Vector3(x, past_z, h)
	var hit := query.blocker_at(probe)
	if not hit.is_empty() and str(hit.get("kind", "")) in ["pipe", "ramp"]:
		pass
	_enter_air(state, Vector3(world_vx, world_vz, 0.0))
	state.position = probe
	return true


## Snap grounded feet onto their surface; if buried in foreign solid, remount it.
func _ensure_surface_contact(state: SimState) -> void:
	if model.pipes.has(state.surface_id):
		var pipe: PipeSurface = model.pipes[state.surface_id]
		var proj := pipe.project(state.position.x, state.position.y, state.position.z)
		if bool(proj.get("ok", false)):
			state.position = proj.point
			state.u = float(proj.u)
			state.v = float(proj.v)
	elif model.ramps.has(state.surface_id):
		var ramp: RampSurface = model.ramps[state.surface_id]
		var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
		if bool(rproj.get("ok", false)):
			state.position = rproj.point
			state.u = float(rproj.u)
			state.v = float(rproj.v)
	elif model.walls.has(state.surface_id):
		var wall: WallSurface = model.walls[state.surface_id]
		state.position = wall.position_at(state.position.y, state.u)
		state.v = clampf(
			(state.position.y - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001),
			0.0,
			1.0
		)
	elif model.patches.has(state.surface_id):
		var patch: SupportPatch = model.patches[state.surface_id]
		state.position.z = patch.height
	# Foreign solid still covering feet (deck under floor wrap, etc.).
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind == "pipe" or kind == "ramp":
		# Don't steal onto a stacked/foreign slope while riding our own.
		if model.pipes.has(state.surface_id) or model.ramps.has(state.surface_id):
			return
		# Deck → pipe/ramp is acid drop only — fall, don't auto-stick.
		if model.patches.has(state.surface_id):
			var cur: SupportPatch = model.patches[state.surface_id]
			if int(cur.kind) == SimKinds.SurfaceKind.DECK:
				return
		_mount_slope_at(state, state.position.x, state.position.y, state.tangent_velocity.x)
	elif kind == "deck":
		# Grounded wall/pipe/ramp owns the climb — never deck-rescue through an
		# overhanging pad that shares the wall-face X.
		if model.walls.has(state.surface_id) \
				or model.pipes.has(state.surface_id) \
				or model.ramps.has(state.surface_id):
			return
		_rescue_deck_top(state)
	elif kind == "wall":
		# Own explicit wall is already the grounded contact owner.
		if _wall_hit_is_own_pipe(state, hit):
			return
		_mount_wall_from_hit(state, hit, state.position)


## Snap grounded floor motion onto a pipe/ramp ride surface covering (x,z).
func _mount_pipe_at(state: SimState, x: float, z: float, world_vx: float) -> bool:
	return _mount_slope_at(state, x, z, world_vx)


func _mount_slope_at(state: SimState, x: float, z: float, world_vx: float) -> bool:
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		if not pipe.contains_xz(x, z):
			continue
		var proj := pipe.project(x, z, state.position.z)
		if not bool(proj.get("ok", false)):
			continue
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity.x = world_vx * pipe.outward_sign()
		state.velocity = Vector3.ZERO
		state.clear_hang()
		return true
	for ramp_id in model.ramps.keys():
		var ramp: RampSurface = model.ramps[ramp_id]
		if not ramp.contains_xz(x, z):
			continue
		var rproj := ramp.project(x, z, state.position.z)
		if not bool(rproj.get("ok", false)):
			continue
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = ramp.id
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity.x = world_vx * ramp.outward_sign()
		state.velocity = Vector3.ZERO
		state.clear_hang()
		return true
	return false


func _is_slope_kind(kind: int) -> bool:
	return kind == SimKinds.SurfaceKind.PIPE or kind == SimKinds.SurfaceKind.RAMP


func _slope_outward(surface_id: String) -> float:
	if model.pipes.has(surface_id):
		return model.pipes[surface_id].outward_sign()
	if model.ramps.has(surface_id):
		return model.ramps[surface_id].outward_sign()
	return 1.0


## If feet are inside a deck's solid volume, snap to the ride top.
## Preserves grounded tangent (world XZ) so you keep sliding on the deck.
func _rescue_deck_top(state: SimState) -> bool:
	var hit := query.blocker_at(state.position)
	if str(hit.get("kind", "")) != "deck":
		return false
	return _mount_deck_from_hit(state, hit, state.position)


func _mount_deck_from_hit(state: SimState, hit: Dictionary, at: Vector3) -> bool:
	var deck_id := str(hit.get("surface_id", ""))
	if not model.patches.has(deck_id):
		return false
	var deck: SupportPatch = model.patches[deck_id]
	var px := clampf(at.x, deck.x_min, deck.x_max)
	var pz := clampf(at.y, deck.z_min, deck.z_max)
	if deck.contains_xz(at.x, at.y):
		px = at.x
		pz = at.y
	# Preserve world XZ motion onto the deck top.
	var world_vx := state.tangent_velocity.x
	var world_vz := state.tangent_velocity.y
	if model.pipes.has(state.surface_id) or model.ramps.has(state.surface_id):
		world_vx = state.tangent_velocity.x * _slope_outward(state.surface_id)
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = deck.id
	state.u = 0.0
	state.v = 0.0
	state.position = Vector3(px, pz, deck.height)
	state.tangent_velocity = Vector2(world_vx, world_vz)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	return true


## Floor-backed wall contact mounts its compiled top support. Cross-story walls
## have no auto destination; the opposite pipe remains maneuver-only.
## Hang air-out always remounts the wall face — never a top deck/floor pad.
func _mount_wall_from_hit(state: SimState, hit: Dictionary, at: Vector3) -> bool:
	var wall_id := str(hit.get("surface_id", ""))
	var wall: WallSurface = model.walls.get(wall_id)
	if wall == null:
		return false
	var hang_wall_face := state.is_hanging() or wall.top_support_id.is_empty()
	if hang_wall_face:
		var projection := wall.project(at.x, at.y, at.z)
		if not bool(projection.get("ok", false)):
			return false
		var along := state.velocity.z if state.is_airborne() else state.tangent_velocity.x
		var depth_speed := state.velocity.y if state.is_airborne() else state.tangent_velocity.y
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = wall.id
		state.u = float(projection.u)
		state.v = float(projection.v)
		state.position = projection.point
		state.tangent_velocity = Vector2(along, depth_speed)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		return true
	var patch: SupportPatch = model.patches.get(wall.top_support_id)
	if patch == null:
		return false
	var cope: CopingEdge = model.copings[wall.source_coping_id]
	var samp := wall.sample_at_z(at.y)
	var world_vx := state.tangent_velocity.x
	var world_vz := state.tangent_velocity.y
	if model.pipes.has(state.surface_id) or model.ramps.has(state.surface_id):
		world_vx = state.tangent_velocity.x * _slope_outward(state.surface_id)
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = patch.id
	state.u = 0.0
	state.v = 0.0
	state.position = Vector3(
		float(samp.x) + cope.outward_sign * SimTolerances.CAPSULE_RADIUS,
		at.y,
		patch.height
	)
	state.tangent_velocity = Vector2(world_vx, world_vz)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	return true


## Deck / pipe / ramp / wall solid → remount ride surface. Returns true when handled.
func _resolve_solid_contact(state: SimState, hit: Dictionary, at: Vector3) -> bool:
	var kind := str(hit.get("kind", ""))
	if kind == "deck":
		return _mount_deck_from_hit(state, hit, at)
	if kind == "pipe" or kind == "ramp":
		# Deck never auto-mounts a pipe/ramp (acid drop only).
		if model.patches.has(state.surface_id):
			var cur: SupportPatch = model.patches[state.surface_id]
			if int(cur.kind) == SimKinds.SurfaceKind.DECK:
				_enter_air(state, Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0))
				return true
		var world_vx := state.tangent_velocity.x
		if model.pipes.has(state.surface_id) or model.ramps.has(state.surface_id):
			world_vx = state.tangent_velocity.x * _slope_outward(state.surface_id)
		# Place probe then mount.
		var prev := state.position
		state.position = Vector3(at.x, at.y, at.z)
		if _mount_slope_at(state, at.x, at.y, world_vx):
			return true
		state.position = prev
		return false
	if kind == "wall":
		# Floor / foreign contact remounts; own pipe climbs instead.
		if _wall_hit_is_own_pipe(state, hit):
			return false
		return _mount_wall_from_hit(state, hit, at)
	return false


func _wall_hit_is_own_pipe(state: SimState, hit: Dictionary) -> bool:
	var wall: WallSurface = model.walls.get(str(hit.get("surface_id", "")))
	if wall == null:
		return false
	return state.surface_id == wall.id or state.surface_id == wall.source_pipe_id


## Keep grounded XZ inside world + playable cells. Axis-slide on borders/space.
## Deck / pipe / wall contact remounts onto the covering ride surface — never pin.
## Returns {ok:bool, pos:Vector3, remounted?:bool}.
func _contain_ground_xz(state: SimState, proposed: Vector3) -> Dictionary:
	var trials: Array = [
		proposed,
		Vector3(proposed.x, state.position.y, proposed.z),
		Vector3(state.position.x, proposed.y, proposed.z),
	]
	for trial in trials:
		var c: Vector3 = trial
		var clamped := model.clamp_xz(c.x, c.y)
		c.x = clamped.x
		c.y = clamped.y
		if not model.is_traversable_xz(c.x, c.y):
			continue
		var hit := query.blocker_at(Vector3(c.x, c.y, c.z))
		if hit.is_empty():
			if absf(c.x - proposed.x) > 0.001:
				state.tangent_velocity.x = 0.0
			if absf(c.y - proposed.y) > 0.001:
				state.tangent_velocity.y = 0.0
			return {"ok": true, "pos": c}
		var kind := str(hit.get("kind", ""))
		if kind == "bounds" or kind == "feature_wall":
			# World border / unplayable space / feature endcaps & open sides —
			# try other axis slide (never remount onto the wall face).
			continue
		# Deck / pipe / wall: remount instead of freezing.
		if _resolve_solid_contact(state, hit, Vector3(c.x, c.y, c.z)):
			return {"ok": true, "remounted": true, "pos": state.position}
		# Remount failed — try sliding the other axis.
		continue
	# Only true borders left: stop into-wall speed, stay put.
	state.tangent_velocity.x = 0.0
	state.tangent_velocity.y = 0.0
	return {"ok": false}


func _update_facing(state: SimState) -> void:
	if absf(state.tangent_velocity.x) > 1.0:
		state.set_facing_side("r" if state.tangent_velocity.x > 0.0 else "l")


func _update_facing_pipe(state: SimState, pipe: PipeSurface) -> void:
	_update_facing_slope(state, pipe.id)


func _update_facing_slope(state: SimState, surface_id: String) -> void:
	# Facing follows world X, not along-arc sign.
	var world_vx := state.tangent_velocity.x * _slope_outward(surface_id)
	if absf(world_vx) > 1.0:
		state.set_facing_side("r" if world_vx > 0.0 else "l")


## Per-axis grounded control: coast (friction), brake only when stick opposes vel, else accel.
func _integrate_axis(
	v: float,
	wish_n: float,
	max_spd: float,
	accel: float,
	brake: float,
	friction: float,
	delta: float,
) -> float:
	if absf(wish_n) < 0.15:
		return move_toward(v, 0.0, maxf(friction, 0.0) * delta)
	# Stick pointed away from current velocity on this axis → brake to 0 (no reverse yet).
	if wish_n * v < 0.0:
		return move_toward(v, 0.0, maxf(brake, 0.0) * delta)
	return move_toward(v, clampf(wish_n, -1.0, 1.0) * max_spd, maxf(accel, 0.0) * delta)


## Depth (logical Z): zero momentum — velocity is stick × max, release snaps to 0.
func _integrate_depth(wish_n: float, max_spd: float) -> float:
	if absf(wish_n) < 0.15:
		return 0.0
	return clampf(wish_n, -1.0, 1.0) * max_spd


## Mild forward thrust toward max_speed in facing direction (world X on flats).
func _apply_ollie_world_x(
	state: SimState,
	wish: Vector2,
	delta: float,
	max_speed: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	if not ollie or ollie_accel <= 0.0:
		return
	var face := 1.0 if state.facing == "r" else -1.0
	# Skip while stick brakes opposite facing.
	if wish.x * face < -0.15:
		return
	state.tangent_velocity.x = move_toward(
		state.tangent_velocity.x, face * max_speed, ollie_accel * delta
	)


## Ollie on pipe: accelerate along-arc so world X matches facing.
func _apply_ollie_pipe(
	state: SimState,
	pipe: PipeSurface,
	wish: Vector2,
	delta: float,
	max_speed: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	_apply_ollie_slope(state, pipe.outward_sign(), wish, delta, max_speed, ollie, ollie_accel)


func _apply_ollie_slope(
	state: SimState,
	outward: float,
	wish: Vector2,
	delta: float,
	max_speed: float,
	ollie: bool,
	ollie_accel: float,
) -> void:
	if not ollie or ollie_accel <= 0.0:
		return
	var face := 1.0 if state.facing == "r" else -1.0
	if wish.x * face < -0.15:
		return
	# world_vx = along * outward → along_target = face * outward * max_speed
	var along_target := face * outward * max_speed
	state.tangent_velocity.x = move_toward(
		state.tangent_velocity.x, along_target, ollie_accel * delta
	)
