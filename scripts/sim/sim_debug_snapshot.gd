class_name SimDebugSnapshot
extends RefCounted
## Read-only debug capture for HUD / traces.


var mode: String = ""
var surface_id: String = ""
var coping_class: String = ""
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var u: float = 0.0
var v: float = 0.0
var reject: String = ""
var maneuver: Dictionary = {}
var candidates: Array = []


func capture(state: SimState, model: ParkModel, query: SurfaceQuery) -> void:
	mode = "grounded" if state.is_grounded() else "airborne"
	surface_id = state.surface_id
	position = state.position
	velocity = state.velocity if state.is_airborne() else Vector3(
		state.tangent_velocity.x, state.tangent_velocity.y, 0.0
	)
	u = state.u
	v = state.v
	reject = state.last_reject
	maneuver = state.maneuver.to_dict() if state.has_maneuver() else {}
	coping_class = ""
	if model != null and model.pipes.has(state.surface_id):
		var pipe: PipeSurface = model.pipes[state.surface_id]
		var cope: CopingEdge = model.copings.get(pipe.coping_id)
		if cope:
			coping_class = cope.class_name_str()
	candidates.clear()
	if query != null and model != null:
		# Facing half-plane, opposite-facing lips only. Same-facing / own lip are
		# remount targets, not acid/spine.
		var face_dir := -1.0 if state.facing == "l" else 1.0
		var skip_side := (
			SimKinds.PipeSide.LEFT if state.facing == "l" else SimKinds.PipeSide.RIGHT
		)
		var skip_cope := _self_coping_id(state, model)
		for c in query.copings_in_direction(
			position.x, position.y, position.z, face_dir
		):
			if int(c.side) == skip_side:
				continue
			if not skip_cope.is_empty() and str(c.coping_id) == skip_cope:
				continue
			# Spine/acid only from above the target lip.
			if position.z <= float(c.height) + SimTolerances.CONTACT_EPS:
				continue
			candidates.append({
				"id": c.coping_id,
				"dist": c.distance,
				"class": SimKinds.coping_class_name(int(c.class)),
				"side": "left" if int(c.side) == SimKinds.PipeSide.LEFT else "right",
			})


## Coping owned by the current / launch slope — not a transfer target.
func _self_coping_id(state: SimState, model: ParkModel) -> String:
	for sid in [state.surface_id, state.air_launch_surface_id]:
		if sid.is_empty():
			continue
		if model.pipes.has(sid):
			return str((model.pipes[sid] as PipeSurface).coping_id)
		if model.ramps.has(sid):
			return str((model.ramps[sid] as RampSurface).coping_id)
		if model.walls.has(sid):
			return str((model.walls[sid] as WallSurface).source_coping_id)
	if state.is_hanging() and not state.hang_edge_id.is_empty():
		var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
		if edge != null and not edge.coping_id.is_empty():
			return edge.coping_id
	return ""


func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"surface_id": surface_id,
		"coping_class": coping_class,
		"position": position,
		"velocity": velocity,
		"u": u,
		"v": v,
		"reject": reject,
		"maneuver": maneuver,
		"candidates": candidates,
	}
