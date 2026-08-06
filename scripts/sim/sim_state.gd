class_name SimState
extends RefCounted
## Single authoritative simulation state.


enum Mode {
	GROUNDED = 0,
	AIRBORNE = 1,
	GRINDING = 2,
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
## |along| at air-out leave (vertical seed). Remount restores this so depth
## travel / apex cannot slow the return into the bowl.
var hang_launch_along: float = 0.0
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
## Fall bout — not a motion mode. Input lock + planar stop + side lean.
var falling: bool = false
var fall_elapsed: float = 0.0
## +1 facing r, −1 facing l — presentation lean sign at fall enter.
var fall_lean_sign: float = 1.0
## When true, begin_fall keeps fall_lean_sign (crash stamped approach/away side).
var fall_lean_locked: bool = false
## Captured planar speeds at fall enter (air: world vx/vy; ground: tangent).
var fall_start_vx: float = 0.0
var fall_start_vy: float = 0.0
## Solvers stamp this; PlayerSim calls begin_fall() after the step.
var request_fall: bool = false
## Pipe id to eject outside of on lip-top crash (cleared after eject).
var fall_eject_pipe_id: String = ""
## Presentation FallBox clamps — logical support / optional impact half-spaces.
var fall_support_point: Vector3 = Vector3.ZERO
var fall_support_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
var fall_impact_point: Vector3 = Vector3.ZERO
var fall_impact_normal: Vector3 = Vector3.ZERO
var fall_has_impact_plane: bool = false
## Air-bout yaw from bout zero (rad). Presentation composes with facing_yaw.
var spin_yaw: float = 0.0
## Discrete facing at bout zero — live flips derived from spin_yaw half-turns.
var spin_takeoff_facing: String = "r"
## One-shot: presentation board tracker ignores spin clear (no reverse / unwind).
var spin_handoff: bool = false
## After spun land: lerp contact yaw → nearest N×π (board co-rotates).
var spin_settling: bool = false
var spin_settle_from: float = 0.0
var spin_settle_to: float = 0.0
var spin_settle_elapsed: float = 0.0
## After settle hits N×π: hold one tick so board sees it, then handoff-clear.
var spin_pending_rebase: bool = false
## Momentum sign for facing fix after settle (0 = skip).
var spin_land_momentum_x: float = 0.0
## Grind lock: along-X rail ride.
var grind_rail_id: String = ""
var grind_along: float = 0.0
var grind_balance: float = 0.0


## Lock presentation flop to `sign` (usually wall approach / away-from-impact).
func stamp_fall_lean(sign: float) -> void:
	var s := signf(sign)
	if absf(s) < 0.001:
		return
	fall_lean_sign = s
	fall_lean_locked = true


func is_grounded() -> bool:
	return mode == Mode.GROUNDED


func is_airborne() -> bool:
	return mode == Mode.AIRBORNE


func is_grinding() -> bool:
	return mode == Mode.GRINDING


func clear_grind() -> void:
	grind_rail_id = ""
	grind_along = 0.0
	grind_balance = 0.0


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
	hang_launch_along = 0.0
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
	# hang_launch_along is stamped by GroundSolver._enter_air / callers; depth
	# retarget begin_hang must not wipe a stored takeoff along.


func note_air_height(height: float) -> void:
	air_peak_height = maxf(air_peak_height, height)


func clear_air_peak() -> void:
	air_peak_height = -INF
	air_launch_surface_id = ""
	free_air_upright = false


## New air bout: zero spin; remember takeoff facing for live half-turn flips.
func reset_air_spin() -> void:
	if absf(spin_yaw) > 0.0001 or spin_settling or spin_pending_rebase:
		spin_handoff = true
	spin_yaw = 0.0
	spin_takeoff_facing = facing
	_clear_spin_land_settle()


## Abort land settle (fall / death). Leaves mid-angle for presentation.
func cancel_spin_land_settle() -> void:
	_clear_spin_land_settle()


## After successful land classify: lerp contact → nearest N×π (co-rotate board).
## `momentum_x` applied for facing fix once settle reaches the snap.
func begin_spin_land_settle(nearest: float, momentum_x: float) -> void:
	spin_settle_from = spin_yaw
	spin_settle_to = nearest
	spin_settle_elapsed = 0.0
	spin_land_momentum_x = momentum_x
	spin_pending_rebase = false
	# Gameplay facing from the snap target immediately (visual yaw still lerps).
	var saved_yaw := spin_yaw
	spin_yaw = nearest
	var face := facing_from_spin_yaw()
	spin_yaw = saved_yaw
	facing = face
	visual_facing = face
	facing_yaw = 0.0
	if absf(spin_settle_from - spin_settle_to) < 0.0001:
		spin_yaw = spin_settle_to
		spin_settling = false
		_apply_spin_land_momentum_fix()
		spin_pending_rebase = true
		return
	spin_settling = true


## Advance land settle / deferred rebase. Call every physics tick while alive.
func step_spin_land_settle(delta: float) -> void:
	if spin_settling:
		var dur := maxf(SimTolerances.SPIN_LAND_SETTLE, 0.0)
		spin_settle_elapsed += maxf(delta, 0.0)
		if dur <= 0.0001:
			spin_yaw = spin_settle_to
		else:
			var t := clampf(spin_settle_elapsed / dur, 0.0, 1.0)
			spin_yaw = lerpf(spin_settle_from, spin_settle_to, t)
			if t < 1.0 - 0.0001:
				return
			spin_yaw = spin_settle_to
		spin_settling = false
		_apply_spin_land_momentum_fix()
		# Hold exact N×π for this pose capture so board receives residual.
		spin_pending_rebase = true
		return
	if spin_pending_rebase:
		spin_pending_rebase = false
		commit_spin_land_snap()


## After spun land snap: rebase spin_yaw to 0 without unwinding the trick
## (board/body keep the snapped orientation via spin_handoff).
func commit_spin_land_snap() -> void:
	spin_takeoff_facing = facing
	if absf(spin_yaw) < 0.0001:
		return
	spin_handoff = true
	spin_yaw = 0.0


func _apply_spin_land_momentum_fix() -> void:
	if absf(spin_land_momentum_x) <= 1.0:
		return
	var mom_face := "r" if spin_land_momentum_x > 0.0 else "l"
	if facing != mom_face:
		facing = mom_face
		visual_facing = mom_face


func _clear_spin_land_settle() -> void:
	spin_settling = false
	spin_settle_from = 0.0
	spin_settle_to = 0.0
	spin_settle_elapsed = 0.0
	spin_pending_rebase = false
	spin_land_momentum_x = 0.0


## Facing after `n` half-turns (π) from takeoff. Odd n flips l↔r.
static func facing_after_half_turns(takeoff: String, half_turns: int) -> String:
	var base := "r" if takeoff == "r" else "l"
	if (abs(half_turns) % 2) == 1:
		return "l" if base == "r" else "r"
	return base


## Live/snapped facing from continuous spin_yaw vs bout takeoff.
func facing_from_spin_yaw() -> String:
	var n := int(floor((absf(spin_yaw) + 0.000001) / PI))
	return facing_after_half_turns(spin_takeoff_facing, n)


func is_falling() -> bool:
	return falling


func clear_fall() -> void:
	falling = false
	fall_elapsed = 0.0
	fall_lean_sign = 1.0
	fall_lean_locked = false
	fall_start_vx = 0.0
	fall_start_vy = 0.0
	request_fall = false
	fall_eject_pipe_id = ""
	clear_fall_planes()


func stamp_fall_planes(
	support_point: Vector3, support_normal: Vector3,
	impact_point: Vector3 = Vector3.ZERO, impact_normal: Vector3 = Vector3.ZERO
) -> void:
	fall_support_point = support_point
	fall_support_normal = support_normal.normalized()
	if fall_support_normal.length_squared() < 0.0001:
		fall_support_normal = Vector3(0.0, 0.0, 1.0)
	fall_impact_point = impact_point
	fall_impact_normal = impact_normal.normalized()
	fall_has_impact_plane = fall_impact_normal.length_squared() >= 0.0001


func clear_fall_planes() -> void:
	fall_support_point = Vector3.ZERO
	fall_support_normal = Vector3(0.0, 0.0, 1.0)
	fall_impact_point = Vector3.ZERO
	fall_impact_normal = Vector3.ZERO
	fall_has_impact_plane = false


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
