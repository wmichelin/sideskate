class_name ManeuverPlan
extends RefCounted
## Immutable accepted aerial maneuver: fly-out unlock or transfer X-lerp.


enum Kind {
	FLY_OUT = 0,
	TRANSFER = 1,
}

var kind: int = Kind.FLY_OUT
var source_coping_id: String = ""
var dest_coping_id: String = ""
var dest_pipe_id: String = ""
var start_position: Vector3 = Vector3.ZERO
var start_velocity: Vector3 = Vector3.ZERO
var land_time: float = 0.0
var elapsed: float = 0.0
var z_start: float = 0.0
var z_end: float = 0.0
var land_height: float = 0.0
var land_x: float = 0.0
var travel_sign: float = 1.0
var land_along: float = 0.0
## Facing frozen for the duration of a transfer lerp ("l" / "r").
var hold_facing: String = ""
## Destination lip lean (radians) — presentation lerps carry tilt toward this.
var tilt_end: float = 0.0
## Live 0…1 pull progress (updated each transfer tick; presentation reads this).
## Always starts at 0 — never pre-seeded to upright / mid-X.
var progress: float = 0.0
## Seconds from accept to ballistic apex (0 if already falling).
var rise_time: float = 0.0
## Progress value where lean is upright (ballistic apex, or 0.5 if already falling).
var apex_frac: float = 0.5


func kind_name() -> String:
	match kind:
		Kind.FLY_OUT:
			return "fly_out"
		Kind.TRANSFER:
			return "transfer"
		_:
			return "maneuver"


func is_complete() -> bool:
	return elapsed >= land_time - 0.0001


## Time-phased progress 0→1 over land_time. Lateral X is an output — never an
## input. Lip touch forces 1. Do not start mid-range (that snaps lean/X).
## NOTE: never use CONTACT_EPS here — that constant is spatial (~1.5), not time.
func transfer_progress_at_elapsed(t: float) -> float:
	var span := maxf(land_time, 0.0001)
	return clampf(maxf(t, 0.0) / span, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"source_coping_id": source_coping_id,
		"dest_coping_id": dest_coping_id,
		"dest_pipe_id": dest_pipe_id,
		"land_time": land_time,
		"elapsed": elapsed,
		"progress": progress,
		"rise_time": rise_time,
		"apex_frac": apex_frac,
		"land_x": land_x,
		"land_height": land_height,
		"land_along": land_along,
		"travel_sign": travel_sign,
	}
