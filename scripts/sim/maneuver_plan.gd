class_name ManeuverPlan
extends RefCounted
## Immutable accepted aerial maneuver. Currently fly-out unlock only;
## spine / acid plan kinds removed pending reimplementation.


enum Kind {
	FLY_OUT = 0,
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


func kind_name() -> String:
	match kind:
		Kind.FLY_OUT:
			return "fly_out"
		_:
			return "maneuver"


func is_complete() -> bool:
	return elapsed >= land_time - 0.0001


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"source_coping_id": source_coping_id,
		"dest_coping_id": dest_coping_id,
		"dest_pipe_id": dest_pipe_id,
		"land_time": land_time,
		"elapsed": elapsed,
		"land_x": land_x,
		"land_height": land_height,
		"travel_sign": travel_sign,
	}
