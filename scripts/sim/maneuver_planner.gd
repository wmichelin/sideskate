class_name ManeuverPlanner
extends RefCounted
## Build immutable fly-out and transfer (X-lerp to opposite lip) plans.


var model: ParkModel
var query: SurfaceQuery


func _init(m: ParkModel = null, q: SurfaceQuery = null) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)


## Transfer button: lerp world X onto the next opposite lip while holding facing.
func try_transfer(state: SimState) -> Dictionary:
	if state == null or not state.alive or state.has_maneuver():
		return _reject("busy")
	if not state.is_airborne() and not state.is_grounded():
		return _reject("bad state")
	var cands := query.transfer_candidates(state)
	if cands.is_empty():
		return _reject("no transfer target")
	var c: Dictionary = cands[0]
	var dest_id := str(c.coping_id)
	var cope: CopingEdge = model.copings.get(dest_id)
	if cope == null:
		return _reject("bad dest coping")
	var land_x := float(c.coping_x)
	var plan := ManeuverPlan.new()
	plan.kind = ManeuverPlan.Kind.TRANSFER
	plan.source_coping_id = query.self_coping_id_for_transfer(state)
	plan.dest_coping_id = dest_id
	plan.dest_pipe_id = cope.pipe_id
	plan.start_position = state.position
	plan.start_velocity = (
		state.velocity if state.is_airborne()
		else Vector3(state.tangent_velocity.x, state.tangent_velocity.y, 0.0)
	)
	plan.land_x = land_x
	# Touch height = hang lip (wall top / open cope), not raw geometric pipe lip.
	# Candidates already store hang height; re-sample so plan matches the gate.
	plan.land_height = query.transfer_hang_height(
		dest_id, state.position.y, float(c.height)
	)
	if state.position.z <= plan.land_height + SimTolerances.CONTACT_EPS:
		return _reject("below dest hang lip")
	plan.hold_facing = state.facing
	# Geometric dest lip lean (matches hang after re-anchor). Presentation
	# rolls start → upright at apex → dest (never the inverted half).
	plan.tilt_end = _lip_tilt_for_surface(cope.pipe_id)
	plan.travel_sign = signf(land_x - state.position.x)
	if plan.travel_sign == 0.0:
		plan.travel_sign = -1.0 if state.facing == "l" else 1.0
	# Carry climb |along| across clear_hang → dest hang remount. Without this,
	# dest remount falls to the 120 floor and the landing pipe feels like drag.
	plan.land_along = _transfer_carry_along(state)
	# Time-phased 0→1 from accept (never pre-seed mid progress — that snaps).
	# Upright lean at ballistic apex; if already falling, upright at mid pull.
	var g_abs := absf(SimTolerances.GRAVITY)
	var vz0 := plan.start_velocity.z
	plan.rise_time = vz0 / g_abs if vz0 > 0.0 else 0.0
	plan.land_time = _ballistic_time_to_height(
		plan.start_position.z,
		vz0,
		plan.land_height,
		SimTolerances.GRAVITY,
	)
	if plan.land_time <= 0.0001:
		return _reject("no ballistic path to dest hang lip")
	if plan.land_time + 0.0001 < plan.rise_time:
		# Rising past lip height; still need the fall after apex.
		var apex_h := plan.start_position.z + vz0 * vz0 / maxf(2.0 * g_abs, 0.001)
		plan.land_time = plan.rise_time + _ballistic_time_to_height(
			apex_h, 0.0, plan.land_height, SimTolerances.GRAVITY
		)
	if plan.rise_time > 0.0001 and plan.land_time > 0.0001:
		plan.apex_frac = clampf(plan.rise_time / plan.land_time, 0.0, 1.0)
	else:
		plan.apex_frac = 0.5
	plan.progress = 0.0
	return {"ok": true, "plan": plan}


## Takeoff |along| to restore on dest hang remount (hang stamp, else ground).
func _transfer_carry_along(state: SimState) -> float:
	if state == null:
		return 0.0
	if state.hang_launch_along > 0.001:
		return state.hang_launch_along
	if state.is_grounded():
		return absf(state.tangent_velocity.x)
	return 0.0


## Smallest t ≥ 0 where h0 + vz0·t + ½g·t² reaches h_land under constant g.
func _ballistic_time_to_height(h0: float, vz0: float, h_land: float, g: float) -> float:
	if h0 <= h_land + SimTolerances.CONTACT_EPS:
		return 0.0
	var a := 0.5 * g
	var b := vz0
	var c := h0 - h_land
	if absf(a) < 0.0001:
		if absf(b) < 0.0001:
			return 0.0
		var t_lin := -c / b
		return t_lin if t_lin >= 0.0 else 0.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return 0.0
	var root := sqrt(disc)
	var t0 := (-b - root) / (2.0 * a)
	var t1 := (-b + root) / (2.0 * a)
	var best := INF
	if t0 >= -0.0001:
		best = minf(best, maxf(t0, 0.0))
	if t1 >= -0.0001:
		best = minf(best, maxf(t1, 0.0))
	if best >= INF:
		return 0.0
	return best


## Pipe lip = ±90°; ramp peak = ±45°. Geometric lean −outward×θ (matches hang).
func _lip_tilt_for_surface(surface_id: String) -> float:
	if model.pipes.has(surface_id):
		var pipe: PipeSurface = model.pipes[surface_id]
		return -pipe.outward_sign() * (PI * 0.5)
	if model.ramps.has(surface_id):
		var ramp: RampSurface = model.ramps[surface_id]
		return -ramp.outward_sign() * (PI * 0.25)
	return 0.0


func try_fly_out(state: SimState, input_x: float, input_z: float) -> Dictionary:
	if not state.is_grounded() and not state.is_airborne():
		return _reject("bad state")
	# Fly-out from grounded pipe near open coping OR hang air over that pipe.
	var pipe: PipeSurface = null
	var cope: CopingEdge = null
	var anchor_edge: TopologyEdge = null
	var pos := state.position
	var vel_h := 0.0
	if state.is_grounded() and model.pipes.has(state.surface_id):
		pipe = model.pipes[state.surface_id]
		cope = model.copings.get(pipe.coping_id)
		if state.u < 0.98:
			return _reject("not at coping")
		anchor_edge = query.edge_at(pipe.id, pos.y, "coping")
		if anchor_edge == null or anchor_edge.kind != SimKinds.EdgeKind.OPEN_COPING:
			return _reject("coping is not open")
		vel_h = state.tangent_velocity.x ## along-arc
	elif state.is_grounded() and model.walls.has(state.surface_id):
		var wall: WallSurface = model.walls[state.surface_id]
		if state.u < 0.98:
			return _reject("still climbing wall")
		pipe = model.pipes[wall.source_pipe_id]
		cope = model.copings.get(pipe.coping_id)
		anchor_edge = query.edge_at(wall.id, pos.y, "top")
		if anchor_edge == null or anchor_edge.kind != SimKinds.EdgeKind.OPEN_COPING:
			return _reject("wall top is not open")
		# Height gate uses the wall-top / connected upper lip via the anchor.
		# Outward stick direction stays with the source pipe that climbed the
		# wall so held climb input can deck-out onto the rear pad.
		vel_h = state.tangent_velocity.x
	elif state.is_hanging():
		anchor_edge = model.edges.get(state.hang_edge_id)
		var anchor := query.edge_anchor_sample(anchor_edge, pos.y)
		pipe = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if pipe == null:
			return _reject("invalid air-out anchor")
		cope = model.copings.get(pipe.coping_id)
		vel_h = state.velocity.z
	elif state.is_airborne() and not state.has_maneuver():
		# Find nearest pipe coping under feet (non-hang free air — rare).
		var top := query.top_support(pos.x, pos.y, pos.z + SimTolerances.CONTACT_EPS)
		if top.is_empty() or int(top.kind) != SimKinds.SurfaceKind.PIPE:
			return _reject("no pipe under air")
		pipe = top.pipe as PipeSurface
		cope = model.copings.get(pipe.coping_id)
		vel_h = state.velocity.z
	else:
		return _reject("fly-out unavailable")
	if cope == null:
		return _reject("no coping")
	if vel_h <= 0.0 and state.velocity.z <= 0.0:
		# Need rising — for grounded use along toward coping (positive u speed).
		if state.is_grounded() and state.tangent_velocity.x <= 0.0:
			return _reject("not rising")
		if state.is_airborne() and state.velocity.z <= 0.0:
			return _reject("not rising")
	var out := pipe.outward_sign()
	if absf(input_x) <= 0.15:
		return _reject("no outward input")
	if absf(input_x) <= absf(input_z):
		return _reject("input not X-dominant")
	if input_x * out <= 0.15:
		return _reject("input not outward")
	if anchor_edge == null:
		anchor_edge = query.edge_at(pipe.id, pos.y, "coping")
	var anchor := query.edge_anchor_sample(anchor_edge, pos.y)
	if anchor.is_empty():
		return _reject("no open anchor")
	var samp := cope.sample_at_z(pos.y)
	var cope_h := float(anchor.height)
	var above := pos.z - cope_h
	if above < -SimTolerances.CONTACT_EPS:
		return _reject("below coping")
	if above > SimTolerances.FLY_OUT_ABOVE + 0.001:
		return _reject("above fly-out window")
	# Outward corridor: one cell playable ahead.
	var cell := model.cell_at(float(samp.coping_x), pos.y)
	var ahead_col := cell.x + (1 if out > 0.0 else -1)
	if not model.is_playable_cell(ahead_col, cell.y):
		return _reject("no outward playable cell")
	# Must not tunnel through a foreign pipe/wall at this height. The climb /
	# union wall on this coping is the fly-out plane itself (including the
	# geometric top band) — never treat it as a blocked corridor.
	var ahead_x := float(samp.coping_x) + out * model.cell_w
	var clear := query.sweep_capsule(
		pos, Vector3(ahead_x, pos.y, pos.z)
	)
	if not clear.is_empty() and str(clear.get("kind", "")) in ["wall", "pipe"]:
		var hit_sid := str(clear.get("surface_id", ""))
		if not _fly_out_hit_is_own_coping_wall(pipe, cope, hit_sid):
			return _reject("outward corridor blocked")
	var plan := ManeuverPlan.new()
	plan.kind = ManeuverPlan.Kind.FLY_OUT
	plan.source_coping_id = cope.id
	plan.start_position = pos
	# Unlock with outward X from climb/air speed so fly-out carries lateral
	# momentum into free air (stick still required to accept the unlock).
	var depth_v := state.velocity.y if state.is_airborne() else state.tangent_velocity.y
	var speed := maxf(absf(state.tangent_velocity.x), absf(state.velocity.length()))
	plan.start_velocity = Vector3(
		out * maxf(speed, 120.0),
		depth_v,
		maxf(vel_h, state.velocity.z)
	)
	plan.land_time = 0.0 ## immediate free-air unlock
	plan.travel_sign = out
	return {"ok": true, "plan": plan}


## Wall on this pipe's coping (source or upper-partner joint) — fly-out leave plane.
func _fly_out_hit_is_own_coping_wall(
	pipe: PipeSurface, cope: CopingEdge, hit_sid: String
) -> bool:
	if pipe == null or cope == null or hit_sid.is_empty() or model == null:
		return false
	if not model.walls.has(hit_sid):
		return false
	var wall: WallSurface = model.walls[hit_sid]
	if wall.source_coping_id == cope.id:
		return true
	if wall.source_pipe_id == pipe.id:
		return true
	if wall.upper_partner_pipe_id == pipe.id:
		return true
	return false


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
