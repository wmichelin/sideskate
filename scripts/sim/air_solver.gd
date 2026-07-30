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
		_step_maneuver(state, wish, delta)
		return
	_step_free(state, wish, delta)


func _step_free(state: SimState, wish: Vector2, delta: float) -> void:
	state.note_air_height(state.position.z)
	var w := wish
	if state.is_hanging():
		# Pipe hang: X locked to source coping only; height free; depth stick-kinematic.
		state.velocity.x = 0.0
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * 200.0
	else:
		# Free air: X is ballistic (no friction). Stick steers without bleeding
		# existing speed — aligned wish below |vx| conserves; opposite can brake.
		# Release conserves vx (fly-out climb seed keeps coasting).
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
	if state.is_hanging():
		_update_hang_apex_facing(state, delta, w)
	var from := state.position
	if state.is_hanging():
		var from_anchor := _hang_anchor(state, from.y)
		if from_anchor.is_empty():
			# Only clear if the launch edge itself is gone — leaving Z span keeps hang.
			state.clear_hang()
		else:
			from.x = float(from_anchor.x)
			state.position.x = from.x
	# Already inside a solid (slope ollie drilled in): remount or push out before
	# integrating — sweep only samples the segment after `from`.
	var embedded := query.blocker_at(from)
	if not embedded.is_empty():
		var ek := str(embedded.get("kind", ""))
		if ek == "pipe" or ek == "ramp" or ek == "deck" or ek == "wall":
			if _snap_onto_solid(state, embedded, from.z):
				return
			_bounce_off_solid(state, embedded, from)
			from = state.position
	var to := from + Vector3(state.velocity.x, state.velocity.y, state.velocity.z) * delta
	to.x = clampf(to.x, 0.05, maxf(model.width - 0.05, 0.05))
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
		if kind == "pipe" or kind == "ramp" or kind == "deck" or kind == "wall":
			if _snap_onto_solid(state, hit, from.z):
				return
			# Compiled outward-deck edge is action-only: ordinary air passes through.
			if kind == "pipe" and _pipe_contact_is_action_only(state, hit):
				state.position = to
				_try_land(state, from.z)
				_ensure_air_outside_slopes(state)
				state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
				return
			# Hang / rising / skim: pass through decks. Descending free-air that only
			# fails the tall skim gate must NOT teleport through the pad (short ollie
			# fall-through) — bounce and try a same-pad remount instead.
			if kind == "deck" and not _deck_descending_cross_ok(state, hit, from.z):
				if state.is_hanging() or state.velocity.z >= -SimTolerances.CONTACT_EPS:
					state.position = to
					_try_land(state, from.z)
					_ensure_air_outside_slopes(state)
					state.position.y = clampf(
						state.position.y, 0.05, maxf(model.depth - 0.05, 0.05)
					)
					return
				_bounce_off_solid(state, hit, from)
				_try_land(state, from.z)
				_ensure_air_outside_slopes(state)
				state.position.y = clampf(
					state.position.y, 0.05, maxf(model.depth - 0.05, 0.05)
				)
				return
			# Wall faces are one-sided. Leaving a deck across its backing wall is
			# an ordinary ride-off, not an automatic wall/acid mount.
			if kind == "wall" and _wall_contact_is_outward_exit(state, hit):
				state.position = to
				_try_land(state, from.z)
				_ensure_air_outside_slopes(state)
				state.position.y = clampf(
					state.position.y, 0.05, maxf(model.depth - 0.05, 0.05)
				)
				return
			_bounce_off_solid(state, hit, from)
			_try_land(state, from.z)
		elif kind == "feature_wall":
			# Outer backs still allow ordinary air land onto the slope; endcaps /
			# deck sides stop like world borders.
			if str(hit.get("reason", "")) == "slope outer back":
				if _try_land_through_slope_back(state, hit, from.z):
					return
			_resolve_bounds_hit(state, hit, from)
			_try_land(state, from.z)
		else:
			# bounds: stop into-normal motion.
			_resolve_bounds_hit(state, hit, from)
			_try_land(state, from.z)
		_ensure_air_outside_slopes(state)
		state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
		return
	state.position = to
	_try_land(state, from.z)
	_ensure_air_outside_slopes(state)
	# Depth walls sit on the park faces — keep feet inside even if a sweep skimmed.
	state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))


func _hang_launch_edge(state: SimState) -> TopologyEdge:
	if not state.hang_launch_edge_id.is_empty():
		var launch: TopologyEdge = model.edges.get(state.hang_launch_edge_id)
		if launch != null:
			return launch
	return model.edges.get(state.hang_edge_id) as TopologyEdge


func _hang_launch_pipe(state: SimState) -> PipeSurface:
	var edge := _hang_launch_edge(state)
	if edge == null:
		return null
	if model.pipes.has(edge.from_surface_id):
		return model.pipes[edge.from_surface_id] as PipeSurface
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		return model.pipes.get(wall.source_pipe_id) as PipeSurface
	return null


func _hang_lock_x(state: SimState) -> float:
	var launch := _hang_launch_edge(state)
	if launch == null:
		return state.position.x
	var pipe := _hang_launch_pipe(state)
	if pipe != null:
		var z_ref := clampf(state.position.y, pipe.z_min, pipe.z_max - 0.001)
		var cx := pipe.coping_x_at(z_ref)
		return state.position.x if is_nan(cx) else cx
	var sample := query.edge_anchor_sample(
		launch, clampf(state.position.y, launch.z_min, launch.z_max - 0.001)
	)
	return float(sample.x) if not sample.is_empty() else state.position.x


## Hang may leave the launch edge's Z span. Prefer a same-side OPEN coping whose
## lock X matches; otherwise keep a synthetic X-lock. Leaving Z does **not**
## clear hang — only fly-out / spine / acid / land / remount does.
func _hang_anchor(state: SimState, z: float) -> Dictionary:
	if not state.is_hanging():
		return {}
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge != null:
		var sample := query.edge_anchor_sample(edge, z)
		if not sample.is_empty():
			return sample
	var launch_pipe := _hang_launch_pipe(state)
	if launch_pipe == null:
		return {}
	var lock_x := _hang_lock_x(state)
	var cont := _hang_continuation_edge(z, launch_pipe.side, lock_x)
	if cont != null:
		state.hang_edge_id = cont.id
		var retargeted := query.edge_anchor_sample(cont, z)
		if not retargeted.is_empty():
			return retargeted
	# Gap: no coping at this depth — hold launch lock X and lip height.
	var z_ref := clampf(z, launch_pipe.z_min, launch_pipe.z_max - 0.001)
	return {
		"x": lock_x,
		"height": launch_pipe.height_at_theta(z_ref, PI * 0.5),
		"outward_sign": launch_pipe.outward_sign(),
		"source_pipe_id": launch_pipe.id,
		"source_surface_id": launch_pipe.id,
		"gap": true,
	}


func _hang_continuation_edge(z: float, side: int, lock_x: float) -> TopologyEdge:
	for eid in model.all_edge_ids():
		var edge: TopologyEdge = model.edges[eid]
		if edge == null or edge.kind != SimKinds.EdgeKind.OPEN_COPING:
			continue
		if not edge.contains_z(z):
			continue
		var sample := query.edge_anchor_sample(edge, z)
		if sample.is_empty():
			continue
		var pipe: PipeSurface = model.pipes.get(str(sample.get("source_pipe_id", "")))
		if pipe == null or pipe.side != side:
			continue
		if absf(float(sample.x) - lock_x) > SimTolerances.ALIGN_EPS:
			continue
		return edge
	return null


## Once per air-out: after vertical apex, turn around the body's local Y axis
## into the source pipe over APEX_FACING_DELAY (0 = instant).
func _update_hang_apex_facing(state: SimState, delta: float, wish: Vector2) -> void:
	if state.hang_apex_facing_done:
		return
	var launch := _hang_launch_edge(state)
	# Off the launch edge Z span: keep takeoff orientation (depth transfer).
	if launch == null or not launch.contains_z(state.position.y):
		state.hang_apex_facing_done = true
		state.hang_apex_timer = -1.0
		state.facing_yaw = 0.0
		return
	# Depth stick held: freeze takeoff lean; apex may still fire if they release
	# while remaining on the launch span.
	if absf(wish.y) >= 0.15:
		state.hang_apex_timer = -1.0
		state.facing_yaw = 0.0
		return
	var anchor := query.edge_anchor_sample(launch, state.position.y)
	var pipe: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
	if pipe == null:
		return
	# Into the bowl: opposite the pipe's outward (coping) direction.
	var into := "l" if pipe.outward_sign() > 0.0 else "r"
	if state.hang_apex_timer < 0.0:
		if state.velocity.z > 0.0:
			return
		state.hang_apex_timer = 0.0
		# Signed ±π around local Y into the bowl. Must not use
		# lerp_angle:  ±π are the same angle so it always picks one spin.
		state.hang_apex_from_yaw = 0.0
		state.hang_apex_to_yaw = PI * pipe.outward_sign()
		state.facing_yaw = 0.0
	else:
		state.hang_apex_timer += delta
	var delay := maxf(SimTolerances.APEX_FACING_DELAY, 0.0)
	var t := 1.0 if delay <= 0.0 else clampf(state.hang_apex_timer / delay, 0.0, 1.0)
	state.facing_yaw = lerpf(state.hang_apex_from_yaw, state.hang_apex_to_yaw, t)
	if t < 1.0:
		return
	state.hang_apex_facing_done = true
	# Gameplay faces into the bowl now, but presentation keeps the takeoff-facing
	# reflection until hang exit. R(±π) × old-facing is visually equivalent to
	# R(0) × new-facing, so clear_hang can hand off without a pop.
	state.facing = into
	state.facing_yaw = state.hang_apex_to_yaw


func _anchor_crossing_time(state: SimState, from: Vector3, to: Vector3) -> float:
	if not state.is_hanging() or to.z >= from.z:
		return INF
	var anchor := _hang_anchor(state, to.y)
	# Synthetic gap locks have no remount surface — don't treat lip height as a
	# return crossing while depth-transferring over void / lava.
	if anchor.is_empty() or bool(anchor.get("gap", false)):
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
func _snap_onto_solid(state: SimState, hit: Dictionary, from_height: float = NAN) -> bool:
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
		state.clear_air_peak()
		return true
	if kind == "ramp":
		# Ordinary same-facing land / bounce — never hang from ramp peaks.
		if state.velocity.z > 80.0:
			return false
		var ramp: RampSurface = model.ramps.get(str(hit.get("surface_id", "")))
		if ramp == null:
			return false
		var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
		if not bool(rproj.get("ok", false)):
			var rpt: Vector3 = hit.get("projection", state.position)
			rproj = ramp.project(rpt.x, rpt.y, rpt.z)
		if not bool(rproj.get("ok", false)):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = ramp.id
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if kind == "deck":
		if not _deck_descending_cross_ok(state, hit, from_height):
			return false
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
		state.clear_air_peak()
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
					state.clear_air_peak()
					return true
		# Ordinary free air never acquires wall ownership. Walls are entered from
		# their source pipe seam or by returning through an anchored air-out.
		if not state.is_hanging():
			return false
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
## outward coping corridor may pass through for deck→bowl drops; deep body under
## the arc is solid (ollie / lateral flight must clear peak or collide).
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
	if is_nan(cx) or (state.position.x - cx) * out < -SimTolerances.CAPSULE_RADIUS:
		return false
	# Only the coping seam — mid-arc body stays collidable.
	return absf(state.position.x - cx) <= SimTolerances.CAPSULE_RADIUS * 2.0


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
			# Rising / lateral entry still needs clear travel facing. Descending
			# remounts (short ollie, low |vx|) must not reject the contact surface.
			if state.velocity.z > 0.0:
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
				# Sit on the ride surface along the normal — Z-only lift still leaves
				# peak-ward X under a rising slope.
				var n: Vector3 = proj.normal
				var pt: Vector3 = proj.point
				if n.length_squared() > 0.0001:
					state.position = pt + n.normalized() * SimTolerances.CONTACT_EPS
					state.velocity = _reject_into_normal(state.velocity, n)
				else:
					state.position.z = maxf(
						state.position.z, float(pt.z) + SimTolerances.CONTACT_EPS
					)
					if state.velocity.z < 0.0:
						state.velocity.z = 0.0
				# Do not lerp back toward `from` — it is often still inside the solid
				# and would re-bury a clean normal projection.
				_push_out_of_solids(state, n if n.length_squared() > 0.0001 else Vector3.UP)
				return
	if kind == "ramp":
		var ramp: RampSurface = model.ramps.get(str(hit.get("surface_id", "")))
		if ramp != null:
			var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
			if not bool(rproj.get("ok", false)):
				var rpt: Vector3 = hit.get("projection", state.position)
				rproj = ramp.project(rpt.x, rpt.y, rpt.z)
			if bool(rproj.get("ok", false)):
				var rn: Vector3 = rproj.normal
				var rpt2: Vector3 = rproj.point
				if rn.length_squared() > 0.0001:
					state.position = rpt2 + rn.normalized() * SimTolerances.CONTACT_EPS
					state.velocity = _reject_into_normal(state.velocity, rn)
				else:
					state.position.z = maxf(
						state.position.z, float(rpt2.z) + SimTolerances.CONTACT_EPS
					)
					if state.velocity.z < 0.0:
						state.velocity.z = 0.0
				_push_out_of_solids(state, rn if rn.length_squared() > 0.0001 else Vector3.UP)
				return
	if kind == "wall":
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(normal.x) > 0.001 and state.velocity.x * normal.x < 0.0:
			state.velocity.x = 0.0
		# A vertical face never consumes falling speed.
		_depenetrate(state, from)
		return
	# Deck / fallback: walk back along the motion. Hang and rising contacts must
	# not consume height (rear-deck trip / mid fly-out stall).
	if not state.is_hanging() and state.velocity.z < 0.0:
		state.velocity.z = 0.0
	_depenetrate(state, from)
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y


## Drop velocity into a surface normal so free-air never keeps drilling underground.
func _reject_into_normal(world: Vector3, normal: Vector3) -> Vector3:
	if normal.length_squared() < 0.0001:
		return world
	var n := normal.normalized()
	var vn := world.dot(n)
	if vn < 0.0:
		return world - n * vn
	return world


## If still inside a solid after a normal projection, step along `hint_n` (not
## back toward an embedded `from`).
func _push_out_of_solids(state: SimState, hint_n: Vector3) -> void:
	if query.blocker_at(state.position).is_empty():
		return
	var step := hint_n.normalized() * SimTolerances.CONTACT_EPS
	if step.length_squared() < 0.0001:
		step = Vector3(0.0, 0.0, SimTolerances.CONTACT_EPS)
	for _i in range(16):
		if query.blocker_at(state.position).is_empty():
			return
		state.position += step
	# Last resort: project onto whatever solid owns the feet.
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind == "pipe" or kind == "ramp":
		var sid := str(hit.get("surface_id", ""))
		var surf = model.pipes.get(sid)
		if surf == null:
			surf = model.ramps.get(sid)
		if surf != null:
			var proj: Dictionary = surf.project(
				state.position.x, state.position.y, state.position.z
			)
			if bool(proj.get("ok", false)):
				var n2: Vector3 = proj.normal
				state.position = (
					proj.point + n2.normalized() * SimTolerances.CONTACT_EPS
				)
				state.velocity = _reject_into_normal(state.velocity, n2)


func _wall_contact_is_outward_exit(state: SimState, hit: Dictionary) -> bool:
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	return absf(normal.x) > 0.001 and state.velocity.x * normal.x > 0.0


## Air crossing a slope outer-back face may still ordinary-land onto that slope.
func _try_land_through_slope_back(state: SimState, hit: Dictionary, from_height: float) -> bool:
	# Only descending approaches — rising fly-outs / hangs must clear the back.
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return false
	if state.is_hanging():
		return false
	var sid := str(hit.get("surface_id", ""))
	var z := state.position.y
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	if model.pipes.has(sid):
		var pipe: PipeSurface = model.pipes[sid]
		var inward_x := pipe.coping_x_at(z) - pipe.outward_sign() * SimTolerances.CONTACT_EPS
		var proj := pipe.project(inward_x, z, state.position.z)
		if not bool(proj.get("ok", false)):
			return false
		if not _pipe_snap_allowed(state, pipe, proj):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if model.ramps.has(sid):
		var ramp: RampSurface = model.ramps[sid]
		var rin := ramp.coping_x_at(z) - ramp.outward_sign() * SimTolerances.CONTACT_EPS
		var rproj := ramp.project(rin, z, state.position.z)
		if not bool(rproj.get("ok", false)):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = ramp.id
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	return false


## Bounds / space / feature walls — stop into-wall motion; never crash.
func _resolve_bounds_hit(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var axis := str(hit.get("axis", ""))
	var kind := str(hit.get("kind", ""))
	if axis == "x":
		state.velocity.x = 0.0
	elif axis == "z":
		state.velocity.y = 0.0
	else:
		state.velocity.x = 0.0
		state.velocity.y = 0.0
	if kind == "feature_wall":
		# Push back along the motion; do not snap to park AABB faces.
		_depenetrate(state, from)
		var clamped_fw := model.clamp_xz(state.position.x, state.position.y)
		state.position.x = clamped_fw.x
		state.position.y = clamped_fw.y
		state.position.z = maxf(state.position.z, SimTolerances.VOID_FLOOR)
		return
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y
	if axis == "x":
		var inset := 0.05
		state.position.x = (
			inset if float(hit.get("sign", 0.0)) < 0.0
			else maxf(model.width - inset, inset)
		)
	state.position.z = maxf(state.position.z, SimTolerances.VOID_FLOOR)
	_depenetrate(state, from)


## Walk back toward `from` until the capsule is outside solids.
## Never snap to an embedded `from` — that re-buries slope bounces.
func _depenetrate(state: SimState, from: Vector3) -> void:
	if query.blocker_at(state.position).is_empty():
		return
	if query.blocker_at(from).is_empty():
		for _i in range(12):
			if query.blocker_at(state.position).is_empty():
				return
			state.position = state.position.lerp(from, 0.35)
		if query.blocker_at(state.position).is_empty():
			return
		state.position = from
		return
	_push_out_of_solids(state, Vector3(0.0, 0.0, 1.0))


## Free-air must not remain under a pipe/ramp ride surface (chord cuts / stick drill).
func _ensure_air_outside_slopes(state: SimState) -> void:
	if not state.is_airborne():
		return
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind != "pipe" and kind != "ramp":
		return
	if _snap_onto_solid(state, hit, state.position.z):
		return
	_bounce_off_solid(state, hit, state.position)


func _step_maneuver(state: SimState, wish: Vector2, delta: float) -> void:
	var plan: ManeuverPlan = state.maneuver
	if plan.kind == ManeuverPlan.Kind.FLY_OUT:
		# Unlock into free air with the plan's outward seed; stick may steer after.
		state.velocity = plan.start_velocity
		state.maneuver = null
		state.clear_hang()
		state.note_air_height(state.position.z)
		_step_free(state, wish, delta)
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
	state.clear_air_peak()


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
	# Decks: must be descending onto the pad, and this air bout must have peaked
	# well above it — lip/apex skims (peak ≈ pad) must not sticky-mount.
	# Same-pad ollie returns only need to have cleared the pad (CONTACT_EPS).
	if int(top.kind) == SimKinds.SurfaceKind.DECK:
		if state.velocity.z >= -SimTolerances.CONTACT_EPS:
			return
		if is_nan(from_height) or from_height <= sh + SimTolerances.CONTACT_EPS:
			return
		if state.air_peak_height <= sh + _deck_land_min_above(state, str(top.surface_id)):
			return
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	var was_hanging := state.is_hanging()
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = str(top.surface_id)
	state.position.z = sh
	if int(top.kind) == SimKinds.SurfaceKind.PIPE:
		var pipe: PipeSurface = model.pipes.get(state.surface_id)
		# Air-out onto same-facing pipe (exit or X-aligned other): snap lip, into bowl.
		if was_hanging and pipe != null:
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
	elif int(top.kind) == SimKinds.SurfaceKind.RAMP:
		var rproj: Dictionary = top.proj
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	else:
		# Flat land from hang: drop X-lock / lip lean; coast with world XZ.
		state.u = 0.0
		state.v = 0.0
		state.tangent_velocity = Vector2(state.velocity.x, state.velocity.y)
		state.facing_yaw = 0.0
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	if top.get("lethal", false):
		state.alive = false


## True when free air may ground on this deck hit: not hang, clearly descending
## across the ride top, and this air bout peaked well above the pad.
func _deck_descending_cross_ok(state: SimState, hit: Dictionary, from_height: float) -> bool:
	if state.is_hanging():
		return false
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return false
	var deck: SupportPatch = model.patches.get(str(hit.get("surface_id", "")))
	if deck == null or int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return false
	if is_nan(from_height) or from_height <= deck.height + SimTolerances.CONTACT_EPS:
		return false
	if state.air_peak_height <= deck.height + _deck_land_min_above(state, deck.id):
		return false
	return true


## Lip skims need a tall peak gate; same-pad ollie returns only need to clear CONTACT_EPS.
func _deck_land_min_above(state: SimState, deck_id: String) -> float:
	if not deck_id.is_empty() and state.air_launch_surface_id == deck_id:
		return SimTolerances.CONTACT_EPS
	return SimTolerances.DECK_LAND_MIN_ABOVE


## Descending through the current hang edge (launch or depth-retargeted) returns
## to its source surface. Opposite-facing pipes are never considered here.
func _try_return_to_anchor(state: SimState, from_height: float) -> bool:
	# May retarget hang_edge_id onto a colinear same-side OPEN edge at this Z.
	var anchor := _hang_anchor(state, state.position.y)
	if anchor.is_empty() or bool(anchor.get("gap", false)):
		return false
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge == null or not edge.contains_z(state.position.y):
		return false
	var height := float(anchor.height)
	if state.position.z > height + SimTolerances.CONTACT_EPS:
		return false
	# Classic remount: descending crossing of the lip this tick.
	var crossed := is_nan(from_height) or from_height >= height - SimTolerances.CONTACT_EPS
	# Depth-transfer recovery: entered a far span already below the lip while
	# still hanging — remount without requiring a fresh above→below crossing.
	var retargeted := (
		not state.hang_launch_edge_id.is_empty()
		and state.hang_edge_id != state.hang_launch_edge_id
	)
	if not crossed and not retargeted:
		return false
	if not crossed and state.velocity.z > 0.0:
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
	state.clear_air_peak()
	return true


## Air-out prefers same-facing X-aligned pipes (remount). If none are available
## at this XZ (outside the pipe / gap), land the nearest flat solid and clear hang.
func _pick_ordinary_land(state: SimState, candidates: Array) -> Dictionary:
	var hang_side := -1
	var lock_x := state.position.x
	if state.is_hanging():
		var anchor := _hang_anchor(state, state.position.y)
		var hp: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if hp != null:
			hang_side = hp.side
			lock_x = float(anchor.x)
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
		# No remountable pipe under the lock — accept floor / deck / lava / void.
		# Pipe bodies that failed the facing/X gate stay excluded.
		for c in candidates:
			if int(c.kind) == SimKinds.SurfaceKind.PIPE:
				continue
			return c
		return {}
	for c in candidates:
		if int(c.kind) == SimKinds.SurfaceKind.RAMP:
			return c
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
		if not from_outward and state.velocity.z > 0.0:
			var vx := state.velocity.x
			if absf(vx) < 1.0:
				continue ## no clear travel — skip pipes, prefer flats below
			var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
			if pipe2.side != want:
				continue
		return c
	return {}
