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
	st.facing = model.spawn_facing if model != null else "r"
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
	if int(top.kind) == SimKinds.SurfaceKind.PIPE:
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


func step(state: SimState, wish: Vector2, delta: float, accel: float, max_speed: float) -> void:
	if not state.is_grounded() or not state.alive:
		return
	assert(delta > 0.0)
	if model.pipes.has(state.surface_id):
		_step_pipe(state, wish, delta, accel, max_speed)
	elif model.patches.has(state.surface_id):
		_step_patch(state, wish, delta, accel, max_speed)
	else:
		push_error("GroundSolver: unknown surface %s" % state.surface_id)
		state.mode = SimState.Mode.AIRBORNE


func _step_patch(state: SimState, wish: Vector2, delta: float, accel: float, max_speed: float) -> void:
	var patch: SupportPatch = model.patches[state.surface_id]
	# Wish in XZ.
	var w := wish
	if w.length() > 1.0:
		w = w.normalized()
	var target := w * max_speed
	state.tangent_velocity.x = move_toward(state.tangent_velocity.x, target.x, accel * delta)
	state.tangent_velocity.y = move_toward(state.tangent_velocity.y, target.y, accel * delta)
	var next := state.position + Vector3(
		state.tangent_velocity.x * delta,
		state.tangent_velocity.y * delta,
		0.0
	)
	next.z = patch.height
	if patch.contains_xz(next.x, next.y):
		state.position = next
		_update_facing(state)
		return
	# Left patch — try seam to neighboring support or air.
	var top := query.top_support(next.x, next.y, patch.height + SimTolerances.CONTACT_EPS)
	if not top.is_empty() and absf(float(top.height) - patch.height) <= SimTolerances.SEAM_EPS:
		state.surface_id = str(top.surface_id)
		state.position = Vector3(next.x, next.y, float(top.height))
		if int(top.kind) == SimKinds.SurfaceKind.PIPE:
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			# World X → along-arc: +along = toward coping = outward.
			var pipe: PipeSurface = model.pipes[state.surface_id]
			state.tangent_velocity.x = state.tangent_velocity.x * pipe.outward_sign()
		if top.get("lethal", false):
			state.alive = false
		_update_facing(state)
		return
	# Ride-off into air.
	_enter_air(state, Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0))


func _step_pipe(state: SimState, wish: Vector2, delta: float, accel: float, max_speed: float) -> void:
	var pipe: PipeSurface = model.pipes[state.surface_id]
	# Already perched on OPEN coping with leftover along: hang-launch before control/gravity eat it.
	if state.u >= 0.999 and state.tangent_velocity.x > 1.0:
		var perch: CopingEdge = model.copings.get(pipe.coping_id)
		if perch != null and (
			perch.coping_class == SimKinds.CopingClass.OPEN
			or perch.coping_class == SimKinds.CopingClass.SHARED_SPINE
		):
			_launch_from_coping(state, pipe, state.position.y)
			return
	var crossings := 0
	var remaining := delta
	while remaining > 1e-6 and crossings < SimTolerances.MAX_EDGE_CROSSINGS:
		crossings += 1
		# +along = toward coping. Map world wish X by outward so left/right pipes match.
		var along_wish := wish.x * pipe.outward_sign()
		var target_along := clampf(along_wish, -1.0, 1.0) * max_speed
		var target_z := clampf(wish.y, -1.0, 1.0) * max_speed
		var th := state.u * PI * 0.5
		# Gravity pulls toward lip (negative along); GRAVITY is negative.
		var g_along := SimTolerances.GRAVITY * sin(th)
		state.tangent_velocity.x = move_toward(
			state.tangent_velocity.x, target_along, accel * remaining
		)
		state.tangent_velocity.x += g_along * remaining
		state.tangent_velocity.y = move_toward(
			state.tangent_velocity.y, target_z, accel * remaining
		)
		var s := pipe.sample_at_z(state.position.y)
		var radius := float(s.radius)
		if radius <= 0.001:
			break
		var d_theta := (state.tangent_velocity.x * remaining) / radius
		var old_u := state.u
		var new_theta := th + d_theta
		var new_z := state.position.y + state.tangent_velocity.y * remaining
		new_z = clampf(new_z, pipe.z_min, pipe.z_max)

		# Lip exit: rolled past θ=0 onto the flat bowl floor.
		if new_theta <= 0.0:
			_leave_pipe_at_lip(state, pipe, new_z)
			remaining = 0.0
			break

		new_theta = minf(new_theta, PI * 0.5)
		var new_u := new_theta / (PI * 0.5)
		var edge := query.crossed_edge(pipe.id, old_u, new_u)
		if edge.is_empty():
			state.u = new_u
			state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
			state.position = Vector3(
				pipe.x_at_theta(new_z, new_theta),
				new_z,
				pipe.height_at_theta(new_z, new_theta)
			)
			remaining = 0.0
			break
		# Hit coping gate.
		var te: TopologyEdge = edge.edge
		var cope: CopingEdge = model.copings.get(te.coping_id)
		state.u = 1.0
		state.position = Vector3(
			pipe.x_at_theta(new_z, PI * 0.5),
			new_z,
			pipe.height_at_theta(new_z, PI * 0.5)
		)
		if cope != null and (
			cope.coping_class == SimKinds.CopingClass.SUPPORT_SEAM
			or cope.coping_class == SimKinds.CopingClass.WALL_EXTENSION
		):
			var dest_id := te.to_surface_id
			if model.patches.has(dest_id):
				var patch: SupportPatch = model.patches[dest_id]
				var out := pipe.outward_sign()
				var onto := state.position.x + out * SimTolerances.CAPSULE_RADIUS
				state.surface_id = dest_id
				state.position = Vector3(onto, new_z, patch.height)
				state.u = 0.0
				state.v = 0.0
				# Along → world X (outward positive along).
				state.tangent_velocity = Vector2(
					out * absf(state.tangent_velocity.x), state.tangent_velocity.y
				)
				remaining = 0.0
				break
		# OPEN / SHARED_SPINE: launch into air when rising into coping; else hang.
		if state.tangent_velocity.x > 1.0:
			_launch_from_coping(state, pipe, new_z)
			remaining = 0.0
			break
		state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)
		remaining = 0.0
	if crossings >= SimTolerances.MAX_EDGE_CROSSINGS:
		push_error("GroundSolver: edge crossing bound exceeded on %s" % pipe.id)
	if state.is_grounded() and model.pipes.has(state.surface_id):
		_update_facing_pipe(state, pipe)


## Rising into OPEN coping → hang air (X locked to coping) with along → vertical.
func _launch_from_coping(state: SimState, pipe: PipeSurface, z: float) -> void:
	var along := state.tangent_velocity.x
	var th := PI * 0.5
	# Hang remnant: no world X; vh = along·sinθ ≈ along at coping.
	var world_vh := along * sin(th)
	var world_vz := state.tangent_velocity.y
	state.u = 1.0
	state.position = Vector3(
		pipe.x_at_theta(z, th),
		z,
		pipe.height_at_theta(z, th)
	)
	_enter_air(state, Vector3(0.0, world_vz, world_vh), pipe.id)


## Exit pipe at the lip onto abutting floor/deck, or free-air if unsupported.
func _leave_pipe_at_lip(state: SimState, pipe: PipeSurface, z: float) -> void:
	var lip_x := pipe.x_at_theta(z, 0.0)
	var lip_h := pipe.height_at_theta(z, 0.0)
	# Place slightly into the bowl flat (inward from lip).
	var inward := -pipe.outward_sign()
	var onto_x := lip_x + inward * maxf(SimTolerances.CONTACT_EPS, 1.0)
	# Along → world X at θ≈0: vx = along * outward_sign.
	var world_vx := state.tangent_velocity.x * pipe.outward_sign()
	var world_vz := state.tangent_velocity.y
	var top := query.top_support(onto_x, z, lip_h + SimTolerances.CONTACT_EPS)
	if not top.is_empty() and absf(float(top.height) - lip_h) <= SimTolerances.SEAM_EPS:
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = str(top.surface_id)
		state.u = 0.0
		state.v = 0.0
		state.position = Vector3(onto_x, z, float(top.height))
		state.tangent_velocity = Vector2(world_vx, world_vz)
		if int(top.kind) == SimKinds.SurfaceKind.PIPE:
			# Landed on a different pipe footprint — project.
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			var other: PipeSurface = model.pipes[state.surface_id]
			state.tangent_velocity.x = world_vx * other.outward_sign()
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
	if int(top.kind) == SimKinds.SurfaceKind.PIPE:
		var proj: Dictionary = top.proj
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
	if top.get("lethal", false):
		state.alive = false
	return true


func _enter_air(state: SimState, world_vel: Vector3, hang_pipe_id: String = "") -> void:
	state.mode = SimState.Mode.AIRBORNE
	state.surface_id = ""
	state.velocity = world_vel
	state.maneuver = null
	state.tangent_velocity = Vector2.ZERO
	state.hang_pipe_id = hang_pipe_id


func _update_facing(state: SimState) -> void:
	if absf(state.tangent_velocity.x) > 1.0:
		state.facing = "r" if state.tangent_velocity.x > 0.0 else "l"


func _update_facing_pipe(state: SimState, pipe: PipeSurface) -> void:
	# Facing follows world X, not along-arc sign.
	var world_vx := state.tangent_velocity.x * pipe.outward_sign()
	if absf(world_vx) > 1.0:
		state.facing = "r" if world_vx > 0.0 else "l"
