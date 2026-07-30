class_name ManeuverPlanner
extends RefCounted
## Build immutable fly-out plans.
## Spine / acid transfers intentionally removed — reimplement against the
## single-owner air contact stream.


var model: ParkModel
var query: SurfaceQuery


func _init(m: ParkModel = null, q: SurfaceQuery = null) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)


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
	# Must not tunnel through another pipe body at this height.
	var ahead_x := float(samp.coping_x) + out * model.cell_w
	var clear := query.sweep_capsule(
		pos, Vector3(ahead_x, pos.y, pos.z)
	)
	if not clear.is_empty() and str(clear.get("kind", "")) in ["wall", "pipe"]:
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


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
