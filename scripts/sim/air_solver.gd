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
		# Free air: X is ballistic (no friction). Stick steers without bleeding
		# existing speed — aligned wish below |vx| conserves; opposite can brake.
		if absf(w.x) >= 0.15:
			var target := w.x * 400.0
			var vx := state.velocity.x
			if w.x * vx < 0.0:
				state.velocity.x = move_toward(vx, target, 800.0 * delta)
			elif absf(vx) < absf(target):
				state.velocity.x = move_toward(vx, target, 800.0 * delta)
			# else: same direction, already faster than wish cap — keep ballistic vx
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * 200.0
	state.velocity.z += SimTolerances.GRAVITY * delta
	var from := state.position
	if state.is_hanging():
		var from_anchor := _hang_anchor(state, from.y)
		if from_anchor.is_empty():
			state.clear_hang()
		else:
			from.x = float(from_anchor.x)
			state.position.x = from.x
	var to := from + Vector3(state.velocity.x, state.velocity.y, state.velocity.z) * delta
	to.y = clampf(to.y, 0.05, maxf(model.depth - 0.05, 0.05))
	if state.is_hanging():
		var to_anchor := _hang_anchor(state, to.y)
		if not to_anchor.is_empty():
			to.x = float(to_anchor.x)
	var hit := query.sweep_capsule(from, to)
	var anchor_t := _anchor_crossing_time(state, from, to)
	if anchor_t <= float(hit.get("t", INF)) + 0.0001:
		state.position = from.lerp(to, anchor_t)
		if _try_return_to_anchor(state, from.z):
			return
	if not hit.is_empty():
		var t := float(hit.get("t", 1.0))
		state.position = from.lerp(to, maxf(t - 0.01, 0.0))
		var kind := str(hit.get("kind", ""))
		if kind == "pipe" or kind == "deck" or kind == "wall":
			if _snap_onto_solid(state, hit):
				return
			# Compiled outward-deck edge is action-only: ordinary air passes through.
			if kind == "pipe" and _pipe_contact_is_action_only(state, hit):
				state.position = to
				_try_land(state, from.z)
				state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
				return
			_bounce_off_solid(state, hit, from)
			_try_land(state, from.z)
		else:
			_resolve_bounds_hit(state, hit, from)
			_try_land(state, from.z)
		state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
		return
	state.position = to
	_try_land(state, from.z)
	# Depth walls sit on the park faces — keep feet inside even if a sweep skimmed.
	state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))


func _hang_anchor(state: SimState, z: float) -> Dictionary:
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	return query.edge_anchor_sample(edge, z)


func _anchor_crossing_time(state: SimState, from: Vector3, to: Vector3) -> float:
	if not state.is_hanging() or to.z >= from.z:
		return INF
	var anchor := _hang_anchor(state, to.y)
	if anchor.is_empty():
		return INF
	var height := float(anchor.height)
	if from.z < height - SimTolerances.CONTACT_EPS \
			or to.z > height + SimTolerances.CONTACT_EPS:
		return INF
	return clampf((from.z - height) / maxf(from.z - to.z, 0.0001), 0.0, 1.0)


## Snap airborne contact with pipe / deck / wall onto that ride surface.
## Returns true when the skater is now grounded on the hit geometry.
## Pipe snaps follow ordinary-land facing rules — never auto spine/acid onto an
## opposite-facing pipe (those need the transfer button).
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
		var proj := _pipe_proj_for_air_hit(state, pipe, hit)
		# Lower-story pipe bodies can wrap under upper lips — prefer a same-side
		# pipe whose surface matches the contact height.
		if not proj.is_empty():
			var dh0 := absf(float(proj.point.z) - state.position.z)
			var max_dh0 := maxf(float(proj.get("radius", 40.0)), 40.0)
			if dh0 > max_dh0:
				proj = {}
		if proj.is_empty():
			return false
		if not _pipe_snap_allowed(state, pipe, proj):
			# Leave position at the contact; bounce handler will depenetrate.
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
		if ground == null:
			return false
		var wall: WallSurface = model.walls.get(str(hit.get("surface_id", "")))
		# A free-air approach may land the compiled upper ramp. An anchored
		# air-out never takes this path; it returns to the source wall.
		if not state.is_hanging() and wall != null \
				and not wall.upper_partner_pipe_id.is_empty():
			var partner: PipeSurface = model.pipes.get(wall.upper_partner_pipe_id)
			var into_partner := partner != null and (
				(partner.side == SimKinds.PipeSide.LEFT and state.velocity.x > 0.0)
				or (partner.side == SimKinds.PipeSide.RIGHT and state.velocity.x < 0.0)
			)
			if into_partner:
				var z := state.position.y
				var projection := partner.project(
					partner.coping_x_at(z), z, partner.height_at_theta(z, PI * 0.5)
				)
				if bool(projection.get("ok", false)) \
						and _pipe_snap_allowed(state, partner, projection):
					state.mode = SimState.Mode.GROUNDED
					state.surface_id = partner.id
					state.u = float(projection.u)
					state.v = float(projection.v)
					state.position = projection.point
					state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
					state.velocity = Vector3.ZERO
					state.clear_hang()
					return true
		var at: Vector3 = hit.get("projection", hit.get("point", state.position))
		return ground._mount_wall_from_hit(state, hit, at)
	return false


## Project the deterministic pipe feature selected by the solid query.
func _pipe_proj_for_air_hit(state: SimState, pipe: PipeSurface, hit: Dictionary = {}) -> Dictionary:
	var proj := pipe.project(state.position.x, state.position.y, state.position.z)
	if bool(proj.get("ok", false)):
		return proj
	if not hit.is_empty():
		var pt: Vector3 = hit.get("point", state.position)
		proj = pipe.project(pt.x, pt.y, pt.z)
		if bool(proj.get("ok", false)):
			return proj
	return {}


## A deck-backed OPEN span is compiled as action-only. Ordinary contact from its
## outward side passes through; an accepted acid plan is the sole mount path.
func _pipe_contact_is_action_only(state: SimState, hit: Dictionary) -> bool:
	var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
	if pipe == null:
		return false
	var cope: CopingEdge = model.copings.get(pipe.coping_id)
	var span: CopingSpan = cope.span_at_z(state.position.y) if cope != null else null
	if span == null or span.outward_deck_id.is_empty():
		return false
	var cx := pipe.coping_x_at(state.position.y)
	var out := pipe.outward_sign()
	return not is_nan(cx) and (state.position.x - cx) * out >= -SimTolerances.CAPSULE_RADIUS


## True when mounting this pipe would be an ordinary land (not a spine/acid steal).
func _pipe_snap_allowed(state: SimState, pipe: PipeSurface, proj: Dictionary) -> bool:
	if state.is_hanging():
		var anchor := _hang_anchor(state, state.position.y)
		var source: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if source != null and pipe.side != source.side:
			return false
	else:
		var cx := pipe.coping_x_at(state.position.y)
		var out := pipe.outward_sign()
		var from_outward := not is_nan(cx) and (state.position.x - cx) * out >= -SimTolerances.CAPSULE_RADIUS
		var cope: CopingEdge = model.copings.get(pipe.coping_id)
		var span: CopingSpan = cope.span_at_z(state.position.y) if cope != null else null
		if from_outward and span != null and not span.outward_deck_id.is_empty():
			return false
		if not from_outward:
			var vx := state.velocity.x
			if absf(vx) < 1.0:
				return false
			var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
			if pipe.side != want:
				return false
	var cand := {
		"surface_id": pipe.id,
		"kind": SimKinds.SurfaceKind.PIPE,
		"height": float(proj.point.z),
		"lethal": false,
		"pipe": pipe,
		"proj": proj,
	}
	return not _pick_ordinary_land(state, [cand]).is_empty()


## Rejected pipe/deck/wall contact: push out and kill only into-solid speed.
## Must not zero all velocity (that froze inbound landings on layered right pipes).
func _bounce_off_solid(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var kind := str(hit.get("kind", ""))
	if kind == "pipe":
		var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
		if pipe != null:
			var proj := _pipe_proj_for_air_hit(state, pipe, hit)
			if not proj.is_empty():
				# Sit just above the ride surface; keep horizontal travel for a real land.
				state.position.z = maxf(
					state.position.z, float(proj.point.z) + SimTolerances.CONTACT_EPS
				)
				# Kill only downward into the surface; keep vx so try_land / next tick can settle.
				if state.velocity.z < 0.0:
					state.velocity.z = 0.0
				_depenetrate(state, from)
				return
	# Deck / wall / fallback: walk back along the motion, stop into-wall axes.
	if state.velocity.z < 0.0:
		state.velocity.z = 0.0
	_depenetrate(state, from)
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y


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
	if state.is_hanging() and _try_return_to_anchor(state, from_height):
		return
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


## Descending through the same compiled air-out edge returns to its source
## surface. Opposite-facing pipes are never considered here.
func _try_return_to_anchor(state: SimState, from_height: float) -> bool:
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge == null or not edge.contains_z(state.position.y):
		return false
	var anchor := query.edge_anchor_sample(edge, state.position.y)
	if anchor.is_empty():
		return false
	var height := float(anchor.height)
	if state.position.z > height + SimTolerances.CONTACT_EPS:
		return false
	if not is_nan(from_height) and from_height < height - SimTolerances.CONTACT_EPS:
		return false
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = edge.from_surface_id
	state.u = 1.0
	state.position = Vector3(float(anchor.x), state.position.y, height)
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		state.v = clampf(
			(state.position.y - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001),
			0.0,
			1.0
		)
	elif model.pipes.has(edge.from_surface_id):
		var pipe: PipeSurface = model.pipes[edge.from_surface_id]
		state.v = clampf(
			(state.position.y - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001),
			0.0,
			1.0
		)
	state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	return true


## Ordinary aerial land filter: never opposite-facing pipes (spine only).
## Air-out may land same-facing pipes with coping X on the lock (any height).
func _pick_ordinary_land(state: SimState, candidates: Array) -> Dictionary:
	var hang_side := -1
	var lock_x := state.position.x
	if state.is_hanging():
		var anchor := _hang_anchor(state, state.position.y)
		var hp: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if hp != null:
			hang_side = hp.side
			lock_x = float(anchor.x)
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
		for c2 in candidates:
			if int(c2.kind) != SimKinds.SurfaceKind.PIPE:
				return c2
		return {}
	for c in candidates:
		if int(c.kind) != SimKinds.SurfaceKind.PIPE:
			return c
		var pipe2: PipeSurface = c.get("pipe")
		if pipe2 == null:
			continue
		# Free air: drop-in from outward side, or same-facing travel from the bowl.
		# Deck-backed OPEN from outward needs acid — skip ordinary land.
		var cx2 := pipe2.coping_x_at(state.position.y)
		var out2 := pipe2.outward_sign()
		var from_outward := (
			not is_nan(cx2)
			and (state.position.x - cx2) * out2 >= -SimTolerances.CAPSULE_RADIUS
		)
		if from_outward:
			var cope: CopingEdge = model.copings.get(pipe2.coping_id)
			var span: CopingSpan = cope.span_at_z(state.position.y) if cope != null else null
			if span != null and not span.outward_deck_id.is_empty():
				continue
		if not from_outward:
			var vx := state.velocity.x
			if absf(vx) < 1.0:
				continue ## no clear travel — skip pipes, prefer flats below
			var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
			if pipe2.side != want:
				continue
		return c
	return {}
