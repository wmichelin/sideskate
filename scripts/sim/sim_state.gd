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
## Presentation-facing stays on the takeoff side during a sagittal hang turn.
## At hang exit it catches up to authoritative `facing` without a visual pop.
var visual_facing: String = "r"
## Centered local-Y facing turn (radians). 0 when settled; hangs lerp 0→±π.
var facing_yaw: float = 0.0
var maneuver = null ## ManeuverPlan or null
## Non-empty while air-out is anchored to a compiled OPEN edge.
var hang_edge_id: String = ""
## Launch edge for this hang bout (unchanged by depth retarget). Lock-X and
## apex facing use this even when hang_edge_id retargets across a gap.
var hang_launch_edge_id: String = ""
## Max height reached this airborne bout (hang / free / fly-out). Used so deck
## lands require a real arc above the pad, not a lip/apex skim.
var air_peak_height: float = -INF
## Surface left when this air bout began (ollie / ride-off). Same-pad returns
## skip the tall DECK_LAND_MIN_ABOVE skim gate so short ollies remount.
var air_launch_surface_id: String = ""
## Free air after fly-out / deck-out: presentation must stand upright (no carried
## pipe/ramp lean). Cleared on hang, land, or a lean-keeping launch (ollie).
var free_air_upright: bool = false
## Once per hang: face into the source pipe after apex (+ delay).
var hang_apex_facing_done: bool = false
## Elapsed time since hang apex; < 0 until apex is reached.
var hang_apex_timer: float = -1.0
## Local-Y turn endpoints for the hang apex turn (set when apex is reached).
var hang_apex_from_yaw: float = 0.0
var hang_apex_to_yaw: float = 0.0
var alive: bool = true
var tick: int = 0
## Debug: last rejection reasons.
var last_reject: String = ""


func is_grounded() -> bool:
	return mode == Mode.GROUNDED


func is_airborne() -> bool:
	return mode == Mode.AIRBORNE


func is_hanging() -> bool:
	return is_airborne() and not hang_edge_id.is_empty() and maneuver == null


func has_maneuver() -> bool:
	return maneuver != null


func set_facing_side(side: String) -> void:
	facing = "r" if side == "r" else "l"
	visual_facing = facing
	facing_yaw = 0.0


func clear_hang() -> void:
	hang_edge_id = ""
	hang_launch_edge_id = ""
	hang_apex_facing_done = false
	hang_apex_timer = -1.0
	facing_yaw = 0.0
	visual_facing = facing


func begin_hang(edge_id: String) -> void:
	hang_edge_id = edge_id
	hang_launch_edge_id = edge_id
	hang_apex_facing_done = false
	hang_apex_timer = -1.0
	facing_yaw = 0.0
	visual_facing = facing
	hang_apex_from_yaw = 0.0
	hang_apex_to_yaw = 0.0
	free_air_upright = false
	note_air_height(position.z)


func note_air_height(height: float) -> void:
	air_peak_height = maxf(air_peak_height, height)


func clear_air_peak() -> void:
	air_peak_height = -INF
	air_launch_surface_id = ""
	free_air_upright = false


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
		"visual_facing": visual_facing,
		"facing_yaw": facing_yaw,
		"alive": alive,
		"tick": tick,
		"has_maneuver": has_maneuver(),
		"hang_edge_id": hang_edge_id,
		"last_reject": last_reject,
	}


func state_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var s := "%d|%s|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%s|%s|%.4f|%s|%d" % [
		mode, surface_id, u, v,
		position.x, position.y, position.z,
		velocity.x, velocity.y, velocity.z,
		facing, visual_facing, facing_yaw, hang_edge_id, tick,
	]
	ctx.update(s.to_utf8_buffer())
	return ctx.finish().hex_encode()
