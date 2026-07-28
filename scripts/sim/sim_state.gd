class_name SimState
extends RefCounted
## Single authoritative simulation state.


enum Mode {
	GROUNDED = 0,
	AIRBORNE = 1,
}

var mode: int = Mode.GROUNDED
var surface_id: String = ""
var u: float = 0.0
var v: float = 0.0
## Grounded: UV speeds (u=along-surface, v=along-Z). Airborne unused.
var tangent_velocity: Vector2 = Vector2.ZERO
## World pose always valid for presentation: Vector3(x, z, height).
var position: Vector3 = Vector3.ZERO
## Airborne world velocity Vector3(vx, vz, vh).
var velocity: Vector3 = Vector3.ZERO
var facing: String = "r"
var maneuver = null ## ManeuverPlan or null
## Non-empty while hang-airing above a pipe coping (X locked until fly-out/spine/acid/land).
var hang_pipe_id: String = ""
var alive: bool = true
var tick: int = 0
## Debug: last rejection reasons.
var last_reject: String = ""


func is_grounded() -> bool:
	return mode == Mode.GROUNDED


func is_airborne() -> bool:
	return mode == Mode.AIRBORNE


func is_hanging() -> bool:
	return is_airborne() and not hang_pipe_id.is_empty() and maneuver == null


func has_maneuver() -> bool:
	return maneuver != null


func clear_hang() -> void:
	hang_pipe_id = ""


func to_dict() -> Dictionary:
	return {
		"mode": mode,
		"surface_id": surface_id,
		"u": u,
		"v": v,
		"tangent_velocity": tangent_velocity,
		"position": position,
		"velocity": velocity,
		"facing": facing,
		"alive": alive,
		"tick": tick,
		"has_maneuver": has_maneuver(),
		"hang_pipe_id": hang_pipe_id,
		"last_reject": last_reject,
	}


func state_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var s := "%d|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%s|%s|%d" % [
		mode, surface_id, u, v,
		position.x, position.y, position.z,
		velocity.x, velocity.y, velocity.z,
		facing, hang_pipe_id, tick,
	]
	ctx.update(s.to_utf8_buffer())
	return ctx.finish().hex_encode()
