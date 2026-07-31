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
	if query != null:
		# Ahead of travel (world X), not facing — apex hang turn must not flip
		# the candidate while horizontal motion still points across the gap.
		var travel_x := _travel_world_x(state, model)
		if absf(travel_x) > 1.0:
			# Same-facing lips are remount/bounce targets, not acid/spine.
			var skip_side := (
				SimKinds.PipeSide.LEFT if state.facing == "l" else SimKinds.PipeSide.RIGHT
			)
			for c in query.copings_in_direction(
				position.x, position.y, position.z, signf(travel_x)
			):
				if int(c.side) == skip_side:
					continue
				candidates.append({
					"id": c.coping_id,
					"dist": c.distance,
					"class": SimKinds.coping_class_name(int(c.class)),
					"side": "left" if int(c.side) == SimKinds.PipeSide.LEFT else "right",
				})


## World-X speed used for transfer facing casts (pipes/ramps map along-arc → X).
func _travel_world_x(state: SimState, model: ParkModel) -> float:
	if state.is_airborne():
		return state.velocity.x
	if model != null:
		if model.pipes.has(state.surface_id):
			var pipe: PipeSurface = model.pipes[state.surface_id]
			var proj := pipe.project(state.position.x, state.position.y, state.position.z)
			if bool(proj.get("ok", false)):
				return float((proj.tangent_along as Vector3).x) * state.tangent_velocity.x
		if model.ramps.has(state.surface_id):
			var ramp: RampSurface = model.ramps[state.surface_id]
			var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
			if bool(rproj.get("ok", false)):
				return float((rproj.tangent_along as Vector3).x) * state.tangent_velocity.x
	return state.tangent_velocity.x


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
