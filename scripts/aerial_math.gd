class_name AerialMath
extends RefCounted
## Pure aerial action helpers (transfer / acid-drop routing + selection).
## Pipe entries are duck-typed: QuarterPipe nodes or {side, lip_x, radius, z_min, z_max}.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")

const ACTION_TRANSFER := "transfer"
const ACTION_ACID_DROP := "acid_drop"


## Same-button routing: rising/apex → transfer; falling/rest-after-down → acid drop.
static func choose_air_action(
	vert_vel: float, last_nonzero_vert_vel: float, rest_eps: float = 0.5
) -> String:
	if _MotionMath.transfer_vert_ok(vert_vel, last_nonzero_vert_vel, rest_eps):
		return ACTION_TRANSFER
	return ACTION_ACID_DROP


## Prefer measured horizontal velocity; fall back to Momentum X.
static func resolve_horiz_vel(
	actual_vx: float, momentum_vx: float, actual_eps: float = 8.0, dead_eps: float = 1.0
) -> float:
	var hx := actual_vx
	if absf(hx) < actual_eps:
		hx = momentum_vx
	if absf(hx) < dead_eps:
		return 0.0
	return hx


## Opposite wall for acid drop: vel right → LEFT pipe; vel left → RIGHT pipe.
static func acid_drop_want_side(horiz_vel: float) -> int:
	return 0 if horiz_vel > 0.0 else 1  # QuarterPipe.PipeSide.LEFT / RIGHT


## Landing floor while airborne. Pipe-exit X-lock may use coping radius; acid-drop
## lock and free air must use the sampled underfoot height (no upward snap).
static func landing_support_height(
	air_x_locked: bool,
	acid_drop_lock: bool,
	air_over: String,
	air_radius: float,
	sampled_height: float,
) -> float:
	if air_x_locked and not acid_drop_lock and (
		air_over == "left_pipe" or air_over == "right_pipe"
	):
		return air_radius
	return sampled_height


## Pipe-exit X-lock → free air (parabolic fly-out) when height clears coping+extra
## and Momentum X points toward that pipe's side (right pipe → +X, left → −X).
## See MotionVectors.Kind.MOMENTUM. Acid-drop lock never flies out this way.
## `above_coping` is logical height above the coping floor (`air_radius`);
## 0 means unlock as soon as at/above coping.
static func should_fly_out_pipe_lock(
	air_x_locked: bool,
	acid_drop_lock: bool,
	air_side: int,
	air_abs_height: float,
	air_radius: float,
	above_coping: float,
	momentum_vx: float,
	momentum_eps: float = 1.0,
) -> bool:
	if not air_x_locked or acid_drop_lock:
		return false
	if air_abs_height + 0.001 < air_radius + maxf(above_coping, 0.0):
		return false
	var out := _PipeMath.coping_sign(air_side)
	return momentum_vx * out > momentum_eps


## True when `x` is the top coping (lip ± radius), not the lip / flat edge.
static func is_top_coping(
	side: int, lip_x: float, radius: float, x: float, eps: float = 0.05
) -> bool:
	return absf(x - _PipeMath.coping_x(side, lip_x, radius)) <= eps


## Nearest opposite-facing TOP coping near horizontal velocity.
## Buffer/max_ahead are logical X units. Returns {} if none.
static func find_acid_drop_target(
	pipes: Array,
	logical_x: float,
	logical_z: float,
	horiz_vel: float,
	buffer: float,
	max_ahead: float,
) -> Dictionary:
	if absf(horiz_vel) < 1.0:
		return {}
	var facing := signf(horiz_vel)
	var want_side := acid_drop_want_side(horiz_vel)
	var best: Dictionary = {}
	var best_ahead := INF
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var side: int = int(pipe.side)
		var lip: float = float(pipe.lip_x)
		var radius: float = float(pipe.radius)
		# Top coping only — never the lip.
		var top_coping: float = _PipeMath.coping_x(side, lip, radius)
		var ahead: float = (top_coping - logical_x) * facing
		if ahead < -buffer:
			continue
		if ahead > max_ahead:
			continue
		if ahead < best_ahead:
			best_ahead = ahead
			best = {
				"active": true,
				"zone": _PipeMath.zone_name(side),
				"side": side,
				"lip_x": lip,
				"radius": radius,
				"top_coping": top_coping,
			}
	return best


## Nearest other pipe whose coping lies behind us (spine / back-to-back).
static func find_pipe_behind(
	pipes: Array,
	from_x: float,
	logical_z: float,
	behind: float,
	exclude_side: int,
	exclude_lip_x: float,
) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for pipe in pipes:
		if int(pipe.side) == exclude_side and absf(float(pipe.lip_x) - exclude_lip_x) < 0.05:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var side: int = int(pipe.side)
		var lip: float = float(pipe.lip_x)
		var radius: float = float(pipe.radius)
		var coping: float = _PipeMath.coping_x(side, lip, radius)
		var dist: float = (coping - from_x) * behind
		# Allow shared coping (dist ~ 0) and nearby opposite transitions.
		if dist < -0.05 or dist > maxf(radius * 2.0, 200.0):
			continue
		var score: float = absf(dist)
		if score < best_dist:
			best_dist = score
			best = {
				"active": true,
				"zone": _PipeMath.zone_name(side),
				"side": side,
				"lip_x": lip,
				"radius": radius,
			}
	return best
