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
	# Floor poly may cover pipe cells — if feet are already in a pipe band, ride it.
	if _mount_pipe_at(state, state.position.x, state.position.y, state.tangent_velocity.x):
		_update_facing_pipe(state, model.pipes[state.surface_id])
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
	# Invisible border + space walls: slide / stop, never leave the park.
	var contained := _contain_ground_xz(state, next)
	if not bool(contained.get("ok", false)):
		_update_facing(state)
		return
	next = contained.pos
	# Entering a pipe footprint from floor → mount the ride surface (no stick under arc).
	if _mount_pipe_at(state, next.x, next.y, state.tangent_velocity.x):
		_update_facing_pipe(state, model.pipes[state.surface_id])
		return
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
	# Ride-off into air (holes / unsupported edges — void floor catches falls).
	_enter_air(state, Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0))


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
	var cope: CopingEdge = model.copings.get(pipe.coping_id)
	# Wall climb (u>1): continuous vertical face from geometric coping → deck top.
	if state.u > 1.0 + 0.0001 and cope != null \
			and cope.coping_class == SimKinds.CopingClass.WALL_EXTENSION:
		_step_wall_extension(
			state, pipe, cope, wish, delta, accel, max_speed, max_speed_z,
			brake, friction, ramp_friction, ollie, ollie_accel
		)
		return
	# Already perched on OPEN coping with leftover along: hang-launch before control/gravity eat it.
	if state.u >= 0.999 and state.u <= 1.0 + 0.0001 and state.tangent_velocity.x > 1.0:
		if cope != null and (
			cope.coping_class == SimKinds.CopingClass.OPEN
			or cope.coping_class == SimKinds.CopingClass.SHARED_SPINE
		):
			_launch_from_coping(state, pipe, state.position.y)
			return
	var crossings := 0
	var remaining := delta
	while remaining > 1e-6 and crossings < SimTolerances.MAX_EDGE_CROSSINGS:
		crossings += 1
		# +along = toward coping. Map world wish X by outward so left/right pipes match.
		var along_wish := wish.x * pipe.outward_sign()
		var arc_u := minf(state.u, 1.0)
		var th := arc_u * PI * 0.5
		# Gravity pulls toward lip (negative along); GRAVITY is negative.
		var g_along := SimTolerances.GRAVITY * sin(th)
		state.tangent_velocity.x = _integrate_axis(
			state.tangent_velocity.x, along_wish, max_speed, accel, brake, ramp_friction, remaining
		)
		state.tangent_velocity.x += g_along * remaining
		state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
		_apply_ollie_pipe(state, pipe, wish, remaining, max_speed, ollie, ollie_accel)
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

		# WALL_EXTENSION: past geometric coping → climb vertical wall (u 1→2).
		if new_theta > PI * 0.5 and cope != null \
				and cope.coping_class == SimKinds.CopingClass.WALL_EXTENSION:
			var excess_arc := (new_theta - PI * 0.5) * radius
			var h_geom := pipe.height_at_theta(new_z, PI * 0.5)
			var h_eff := float(cope.sample_at_z(new_z).height)
			var span := maxf(h_eff - h_geom, 0.001)
			var h_wall := h_geom + excess_arc
			state.position = Vector3(pipe.coping_x_at(new_z), new_z, minf(h_wall, h_eff))
			state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
			if h_wall >= h_eff - 0.001:
				state.u = 2.0
				_mount_wall_top(state, pipe, cope, new_z)
				remaining = 0.0
				break
			state.u = 1.0 + (state.position.z - h_geom) / span
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
		# Hit gate (SUPPORT_SEAM / OPEN at u=1, or WALL_TOP at u=2).
		var te: TopologyEdge = edge.edge
		var edge_cope: CopingEdge = model.copings.get(te.coping_id)
		if te.kind == SimKinds.EdgeKind.WALL_TOP and edge_cope != null:
			_mount_wall_top(state, pipe, edge_cope, new_z)
			remaining = 0.0
			break
		state.u = 1.0
		state.position = Vector3(
			pipe.x_at_theta(new_z, PI * 0.5),
			new_z,
			pipe.height_at_theta(new_z, PI * 0.5)
		)
		if edge_cope != null and edge_cope.coping_class == SimKinds.CopingClass.SUPPORT_SEAM:
			var dest_id := te.to_surface_id
			if model.patches.has(dest_id):
				var patch: SupportPatch = model.patches[dest_id]
				var out := pipe.outward_sign()
				var onto := state.position.x + out * SimTolerances.CAPSULE_RADIUS
				state.surface_id = dest_id
				state.position = Vector3(onto, new_z, patch.height)
				state.u = 0.0
				state.v = 0.0
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


## Vertical wall face from geometric pipe coping up to deck-top effective coping.
func _step_wall_extension(
	state: SimState,
	pipe: PipeSurface,
	cope: CopingEdge,
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
	var z := state.position.y
	var h_geom := pipe.height_at_theta(z, PI * 0.5)
	var h_eff := float(cope.sample_at_z(z).height)
	var span := maxf(h_eff - h_geom, 0.001)
	# +along = up the wall. Gravity pulls down fully on a vertical face.
	var along_wish := wish.x * pipe.outward_sign()
	state.tangent_velocity.x = _integrate_axis(
		state.tangent_velocity.x, along_wish, max_speed, accel, brake, ramp_friction, delta
	)
	state.tangent_velocity.x += SimTolerances.GRAVITY * delta
	state.tangent_velocity.y = _integrate_depth(wish.y, max_speed_z)
	_apply_ollie_pipe(state, pipe, wish, delta, max_speed, ollie, ollie_accel)
	var old_u := state.u
	var new_z := clampf(z + state.tangent_velocity.y * delta, pipe.z_min, pipe.z_max)
	var new_h := state.position.z + state.tangent_velocity.x * delta
	# Dropped back onto the quarter-pipe arc.
	if new_h <= h_geom + 0.001:
		state.u = 1.0
		state.position = Vector3(pipe.x_at_theta(new_z, PI * 0.5), new_z, h_geom)
		state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
		_update_facing_pipe(state, pipe)
		return
	# Reached deck-top effective coping.
	if new_h >= h_eff - 0.001:
		state.u = 2.0
		state.position = Vector3(pipe.coping_x_at(new_z), new_z, h_eff)
		_mount_wall_top(state, pipe, cope, new_z)
		return
	state.position = Vector3(pipe.coping_x_at(new_z), new_z, new_h)
	state.u = 1.0 + (new_h - h_geom) / span
	state.v = clampf((new_z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	var edge := query.crossed_edge(pipe.id, old_u, state.u)
	if not edge.is_empty():
		_mount_wall_top(state, pipe, cope, new_z)
		return
	_update_facing_pipe(state, pipe)


## Mount abutting deck/floor at WALL_EXTENSION / SUPPORT effective coping.
func _mount_wall_top(state: SimState, pipe: PipeSurface, cope: CopingEdge, z: float) -> void:
	var dest_id := cope.support_patch_id
	if not model.patches.has(dest_id):
		# No pad — hang at effective coping.
		state.u = 1.0
		state.position = Vector3(
			pipe.coping_x_at(z), z, float(cope.sample_at_z(z).height)
		)
		if state.tangent_velocity.x > 1.0:
			_enter_air(
				state,
				Vector3(0.0, state.tangent_velocity.y, state.tangent_velocity.x),
				pipe.id
			)
		else:
			state.tangent_velocity.x = minf(state.tangent_velocity.x, 0.0)
		return
	var patch: SupportPatch = model.patches[dest_id]
	var out := pipe.outward_sign()
	var onto := pipe.coping_x_at(z) + out * SimTolerances.CAPSULE_RADIUS
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = dest_id
	state.position = Vector3(onto, z, patch.height)
	state.u = 0.0
	state.v = 0.0
	# Climb speed → outward onto the deck.
	state.tangent_velocity = Vector2(
		out * absf(state.tangent_velocity.x), state.tangent_velocity.y
	)
	state.velocity = Vector3.ZERO
	state.clear_hang()


## Rising into OPEN / SHARED / wall-top hang: X locked to coping.
## Do not hang-launch at geometric lip of WALL_EXTENSION — climb first.
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


## Snap grounded feet onto their surface; if buried in foreign solid, remount it.
func _ensure_surface_contact(state: SimState) -> void:
	# Wall-climb pose is off the quarter-pipe project band — do not remount.
	if model.pipes.has(state.surface_id) and state.u > 1.0 + 0.0001:
		return
	if model.pipes.has(state.surface_id):
		var pipe: PipeSurface = model.pipes[state.surface_id]
		var proj := pipe.project(state.position.x, state.position.y, state.position.z)
		if bool(proj.get("ok", false)):
			state.position = proj.point
			state.u = float(proj.u)
			state.v = float(proj.v)
	elif model.patches.has(state.surface_id):
		var patch: SupportPatch = model.patches[state.surface_id]
		state.position.z = patch.height
	# Foreign solid still covering feet (deck under floor wrap, etc.).
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind == "pipe":
		# Don't steal onto a stacked/foreign pipe while riding our own arc.
		if model.pipes.has(state.surface_id):
			return
		_mount_pipe_at(state, state.position.x, state.position.y, state.tangent_velocity.x)
	elif kind == "deck":
		_rescue_deck_top(state)


## Snap grounded floor motion onto a pipe ride surface covering (x,z).
## Prevents skating the floor poly under an embedded pipe (stick / clip).
func _mount_pipe_at(state: SimState, x: float, z: float, world_vx: float) -> bool:
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
	return false


## If feet are inside a deck's solid volume, snap to the ride top.
func _rescue_deck_top(state: SimState) -> bool:
	var hit := query.blocker_at(state.position)
	if str(hit.get("kind", "")) != "deck":
		return false
	var deck_id := str(hit.get("surface_id", ""))
	if not model.patches.has(deck_id):
		return false
	var deck: SupportPatch = model.patches[deck_id]
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = deck.id
	state.u = 0.0
	state.v = 0.0
	state.position.z = deck.height
	state.velocity = Vector3.ZERO
	state.clear_hang()
	return true


## Keep grounded XZ inside world + playable cells. Axis-slide when blocked.
## Returns {ok:bool, pos:Vector3}. ok=false means stay put (into-wall speed cleared).
## Pipe bodies are not rejected here — `_mount_pipe_at` claims those XZ samples.
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
		if not hit.is_empty() and str(hit.get("kind", "")) != "pipe":
			# Bounds / space / wall-extension stay solid on the ground.
			continue
		# Trim velocity components that were rejected by clamping / slide.
		if absf(c.x - proposed.x) > 0.001:
			state.tangent_velocity.x = 0.0
		if absf(c.y - proposed.y) > 0.001:
			state.tangent_velocity.y = 0.0
		return {"ok": true, "pos": c}
	state.tangent_velocity.x = 0.0
	state.tangent_velocity.y = 0.0
	return {"ok": false}


func _update_facing(state: SimState) -> void:
	if absf(state.tangent_velocity.x) > 1.0:
		state.facing = "r" if state.tangent_velocity.x > 0.0 else "l"


func _update_facing_pipe(state: SimState, pipe: PipeSurface) -> void:
	# Facing follows world X, not along-arc sign.
	var world_vx := state.tangent_velocity.x * pipe.outward_sign()
	if absf(world_vx) > 1.0:
		state.facing = "r" if world_vx > 0.0 else "l"


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
	if not ollie or ollie_accel <= 0.0:
		return
	var face := 1.0 if state.facing == "r" else -1.0
	if wish.x * face < -0.15:
		return
	# world_vx = along * outward → along_target = face * outward * max_speed
	var along_target := face * pipe.outward_sign() * max_speed
	state.tangent_velocity.x = move_toward(
		state.tangent_velocity.x, along_target, ollie_accel * delta
	)
