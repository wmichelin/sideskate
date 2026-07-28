class_name ManeuverPlan
extends RefCounted
## Immutable accepted aerial maneuver (spine or acid).


enum Kind {
	SPINE = 0,
	ACID = 1,
	FLY_OUT = 2,
}

var kind: int = Kind.SPINE
var source_coping_id: String = ""
var dest_coping_id: String = ""
var dest_pipe_id: String = ""
var start_position: Vector3 = Vector3.ZERO
var start_velocity: Vector3 = Vector3.ZERO
var land_time: float = 0.0
var elapsed: float = 0.0
## Quintic X(t) coeffs for horizontal: x(t) = a0+a1t+a2t^2+a3t^3+a4t^4+a5t^5
var x_coeffs: PackedFloat32Array = PackedFloat32Array()
var z_start: float = 0.0
var z_end: float = 0.0
var land_height: float = 0.0
var land_x: float = 0.0
var travel_sign: float = 1.0
var land_along: float = 0.0 ## expected pipe along speed on land


func kind_name() -> String:
	match kind:
		Kind.SPINE:
			return "spine"
		Kind.ACID:
			return "acid"
		Kind.FLY_OUT:
			return "fly_out"
		_:
			return "maneuver"


func is_complete() -> bool:
	return elapsed >= land_time - 0.0001


func sample_x(t: float) -> float:
	var u := clampf(t, 0.0, land_time)
	if x_coeffs.size() < 6:
		return lerpf(start_position.x, land_x, u / maxf(land_time, 0.001))
	var x := 0.0
	var p := 1.0
	for i in range(6):
		x += x_coeffs[i] * p
		p *= u
	return x


func sample_z(t: float) -> float:
	var u := clampf(t / maxf(land_time, 0.001), 0.0, 1.0)
	return lerpf(z_start, z_end, u)


func sample_height(t: float) -> float:
	# Ballistic vertical from start: h = h0 + v0 t + 0.5 g t^2
	var u := clampf(t, 0.0, land_time)
	return start_position.z + start_velocity.z * u + 0.5 * SimTolerances.GRAVITY * u * u


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
