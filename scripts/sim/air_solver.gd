class_name AirSolver
extends RefCounted
## Ballistic free air + maneuver execution.


var model: ParkModel
var query: SurfaceQuery
var planner: ManeuverPlanner
var ground: GroundSolver


func _init(
	m: ParkModel = null,
	q: SurfaceQuery = null,
	p: ManeuverPlanner = null,
	g: GroundSolver = null,
) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)
	planner = p if p != null else ManeuverPlanner.new(m, query)
	ground = g if g != null else GroundSolver.new(m, query)


func step(state: SimState, wish: Vector2, delta: float) -> void:
	if not state.is_airborne() or not state.alive:
		return
	if state.has_maneuver():
		_step_maneuver(state, delta)
		return
	_step_free(state, wish, delta)


func _step_free(state: SimState, wish: Vector2, delta: float) -> void:
	var w := wish
	if w.length() > 1.0:
		w = w.normalized()
	if state.is_hanging():
		# Pipe hang: X locked to source coping only; height free; depth stick-kinematic.
		state.velocity.x = 0.0
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * 200.0
	else:
		# Free air: X is ballistic (no friction). Stick only steers when held;
		# release conserves vx. Depth stick-kinematic; height = gravity only.
		if absf(w.x) >= 0.15:
			state.velocity.x = move_toward(state.velocity.x, w.x * 400.0, 800.0 * delta)
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * 200.0
	state.velocity.z += SimTolerances.GRAVITY * delta
	var from := state.position
	if state.is_hanging() and model.pipes.has(state.hang_pipe_id):
		var hang_pipe: PipeSurface = model.pipes[state.hang_pipe_id]
		from.x = hang_pipe.coping_x_at(from.y)
		state.position.x = from.x
	var to := from + Vector3(state.velocity.x, state.velocity.y, state.velocity.z) * delta
	if state.is_hanging() and model.pipes.has(state.hang_pipe_id):
		var hang_pipe2: PipeSurface = model.pipes[state.hang_pipe_id]
		to.x = hang_pipe2.coping_x_at(to.y)
	var hit := query.sweep_capsule(from, to)
	if not hit.is_empty():
		var t := float(hit.get("t", 1.0))
		state.position = from.lerp(to, maxf(t - 0.01, 0.0))
		# Pipe/deck/wall hits snap onto the ride surface — never leave you stuck inside.
		if _snap_onto_solid(state, hit):
			return
		_resolve_bounds_hit(state, hit, from)
		_try_land(state, from.z)
		# If still buried after a bounds bounce, snap to any support under feet.
		if not query.blocker_at(state.position).is_empty():
			_try_land(state, from.z)
			_snap_buried_to_surface(state)
		return
	state.position = to
	_try_land(state, from.z)
	_snap_buried_to_surface(state)


## Snap airborne contact with pipe / deck / wall onto that ride surface.
## Returns true when the skater is now grounded on the hit geometry.
func _snap_onto_solid(state: SimState, hit: Dictionary) -> bool:
	var kind := str(hit.get("kind", ""))
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	if kind == "pipe":
		# Rising through a stacked pipe body (layered climb / hang) must not remount.
		if state.velocity.z > SimTolerances.CONTACT_EPS * 10.0 and state.is_hanging():
			return false
		if state.velocity.z > 80.0:
			return false
		var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
		if pipe == null:
			return false
		var proj := pipe.project(state.position.x, state.position.y, state.position.z)
		if not bool(proj.get("ok", false)):
			# Use hit point XZ if the pre-hit pose is just outside the band.
			var pt: Vector3 = hit.get("point", state.position)
			proj = pipe.project(pt.x, pt.y, pt.z)
		if not bool(proj.get("ok", false)):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		return true
	if kind == "deck":
		var deck_id := str(hit.get("surface_id", ""))
		if not model.patches.has(deck_id):
			return false
		var deck: SupportPatch = model.patches[deck_id]
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = deck.id
		state.u = 0.0
		state.v = 0.0
		var px := clampf(state.position.x, deck.x_min, deck.x_max)
		var pz := clampf(state.position.y, deck.z_min, deck.z_max)
		if deck.contains_xz(state.position.x, state.position.y):
			px = state.position.x
			pz = state.position.y
		state.position = Vector3(px, pz, deck.height)
		state.tangent_velocity = Vector2(state.velocity.x, vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		return true
	if kind == "wall":
		var cid := str(hit.get("coping_id", ""))
		var cope: CopingEdge = model.copings.get(cid)
		if cope == null:
			return false
		var samp := cope.sample_at_z(state.position.y)
		if model.patches.has(cope.support_patch_id):
			var pad: SupportPatch = model.patches[cope.support_patch_id]
			state.mode = SimState.Mode.GROUNDED
			state.surface_id = pad.id
			state.u = 0.0
			state.v = 0.0
			var out := cope.outward_sign
			state.position = Vector3(
				float(samp.coping_x) + out * SimTolerances.CAPSULE_RADIUS,
				state.position.y,
				pad.height
			)
			state.tangent_velocity = Vector2(out * maxf(impact, 80.0), vz)
			state.velocity = Vector3.ZERO
			state.clear_hang()
			return true
		# No pad — perch at effective coping then hang if rising.
		state.position = Vector3(float(samp.coping_x), state.position.y, float(samp.height))
		state.velocity = Vector3(0.0, vz, maxf(state.velocity.z, 0.0))
		return false
	return false


## Bounds / space only — stop into-wall motion; never crash.
func _resolve_bounds_hit(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var axis := str(hit.get("axis", ""))
	if axis == "x":
		state.velocity.x = 0.0
	elif axis == "z":
		state.velocity.y = 0.0
	else:
		state.velocity.x = 0.0
		state.velocity.y = 0.0
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y
	state.position.z = maxf(state.position.z, SimTolerances.VOID_FLOOR)
	_depenetrate(state, from)


## If feet are inside solid after a move/land, snap onto the covering surface.
func _snap_buried_to_surface(state: SimState) -> void:
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	_snap_onto_solid(state, hit)


## Walk back toward `from` until the capsule is outside solids.
func _depenetrate(state: SimState, from: Vector3) -> void:
	if query.blocker_at(state.position).is_empty():
		return
	for _i in range(12):
		if query.blocker_at(state.position).is_empty():
			return
		state.position = state.position.lerp(from, 0.35)
	if not query.blocker_at(state.position).is_empty():
		state.position = from


func _step_maneuver(state: SimState, delta: float) -> void:
	var plan: ManeuverPlan = state.maneuver
	if plan.kind == ManeuverPlan.Kind.FLY_OUT:
		# Instant unlock into free air.
		state.velocity = plan.start_velocity
		state.maneuver = null
		state.clear_hang()
		_step_free(state, Vector2.ZERO, delta)
		return
	plan.elapsed = minf(plan.elapsed + delta, plan.land_time)
	var t := plan.elapsed
	state.position = Vector3(plan.sample_x(t), plan.sample_z(t), plan.sample_height(t))
	# Approximate velocity for landing merge.
	var dt := 0.001
	var t1 := minf(t + dt, plan.land_time)
	state.velocity = Vector3(
		(plan.sample_x(t1) - plan.sample_x(t)) / dt,
		(plan.sample_z(t1) - plan.sample_z(t)) / dt,
		(plan.sample_height(t1) - plan.sample_height(t)) / dt,
	)
	if plan.is_complete():
		_land_maneuver(state, plan)


func _land_maneuver(state: SimState, plan: ManeuverPlan) -> void:
	var pipe: PipeSurface = model.pipes.get(plan.dest_pipe_id)
	if pipe == null:
		state.maneuver = null
		_try_land(state)
		return
	var z := state.position.y
	var x := pipe.x_at_theta(z, PI * 0.5)
	var h := pipe.height_at_theta(z, PI * 0.5)
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = pipe.id
	state.u = 1.0
	state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	state.position = Vector3(x, z, h)
	# Merge descending impact into along-arc into the bowl (negative u direction).
	var along := plan.land_along
	if absf(along) < 1.0:
		along = -plan.travel_sign * maxf(absf(state.velocity.z), 80.0)
	state.tangent_velocity = Vector2(along, state.velocity.y)
	state.velocity = Vector3.ZERO
	state.maneuver = null
	state.clear_hang()


func _try_land(state: SimState, from_height: float = NAN) -> void:
	if state.velocity.z > 0.0:
		return ## still rising
	# Search ceiling must be the pre-step height so a tunnel below the pad still
	# sees the surface we crossed this tick (supports_below ignores pads above feet).
	var search_h := state.position.z + SimTolerances.CONTACT_EPS
	if not is_nan(from_height):
		search_h = maxf(search_h, from_height + SimTolerances.CONTACT_EPS)
	var candidates := query.supports_below(state.position.x, state.position.y, search_h)
	var top := _pick_ordinary_land(state, candidates)
	if top.is_empty():
		return
	var sh := float(top.height)
	# Still above the pad — not a landing this tick.
	if state.position.z > sh + SimTolerances.CONTACT_EPS:
		return
	# Require a descending crossing (or already penetrating) of this pad.
	if not is_nan(from_height) and from_height < sh - SimTolerances.CONTACT_EPS:
		return
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = str(top.surface_id)
	state.position.z = sh
	if int(top.kind) == SimKinds.SurfaceKind.PIPE:
		var pipe: PipeSurface = model.pipes.get(state.surface_id)
		# Air-out onto same-facing pipe (exit or X-aligned other): snap lip, into bowl.
		if state.is_hanging() and pipe != null:
			var z := state.position.y
			state.u = 1.0
			state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
			state.position = Vector3(
				pipe.x_at_theta(z, PI * 0.5),
				z,
				pipe.height_at_theta(z, PI * 0.5)
			)
			state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		else:
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			# Drop-in: negative along always rides into the bowl (toward lip).
			state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	else:
		state.tangent_velocity = Vector2(state.velocity.x, state.velocity.y)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	if top.get("lethal", false):
		state.alive = false
	# Land must never leave feet inside the solid volume.
	_snap_buried_to_surface(state)


## Ordinary aerial land filter: never opposite-facing pipes (spine only).
## Air-out may land same-facing pipes with coping X on the lock (any height).
func _pick_ordinary_land(state: SimState, candidates: Array) -> Dictionary:
	var hang_side := -1
	var lock_x := state.position.x
	if state.is_hanging() and model.pipes.has(state.hang_pipe_id):
		var hp: PipeSurface = model.pipes[state.hang_pipe_id]
		hang_side = hp.side
		lock_x = hp.coping_x_at(state.position.y)
	# Air-out: prefer same-facing X-aligned pipe over abutting deck at the lip.
	if hang_side >= 0:
		for c in candidates:
			if int(c.kind) != SimKinds.SurfaceKind.PIPE:
				continue
			var pipe: PipeSurface = c.get("pipe")
			if pipe == null or pipe.side != hang_side:
				continue
			var cx := pipe.coping_x_at(state.position.y)
			if is_nan(cx) or absf(cx - lock_x) > SimTolerances.ALIGN_EPS:
				continue
			return c
		for c in candidates:
			if int(c.kind) != SimKinds.SurfaceKind.PIPE:
				return c
		return {}
	for c in candidates:
		if int(c.kind) != SimKinds.SurfaceKind.PIPE:
			return c
		var pipe2: PipeSurface = c.get("pipe")
		if pipe2 == null:
			continue
		# Free air: pipe land only if travel matches pipe outward (same-facing as travel).
		var vx := state.velocity.x
		if absf(vx) < 1.0:
			continue ## no clear travel — skip pipes, prefer flats below
		var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
		if pipe2.side != want:
			continue
		return c
	return {}
