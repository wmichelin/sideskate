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
		# Opposite-facing lips within cast range (either X side). Same-facing
		# lips are remount/bounce, not acid/spine. Both-ways range keeps a
		# stacked L1 target after you cross a shared L0 cope X.
		var skip_side := (
			SimKinds.PipeSide.LEFT if state.facing == "l" else SimKinds.PipeSide.RIGHT
		)
		for c in query.copings_in_direction(position.x, position.y, position.z, 0.0):
			if int(c.side) == skip_side:
				continue
			candidates.append({
				"id": c.coping_id,
				"dist": c.distance,
				"class": SimKinds.coping_class_name(int(c.class)),
				"side": "left" if int(c.side) == SimKinds.PipeSide.LEFT else "right",
			})


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
