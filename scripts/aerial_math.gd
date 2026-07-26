class_name AerialMath
extends RefCounted
## Pure aerial action helpers (transfer / spine-transfer / acid-drop routing + selection).
## Pipe entries are duck-typed: QuarterPipe nodes or {side, lip_x, radius, z_min, z_max}.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")

const ACTION_TRANSFER := "transfer"
const ACTION_ACID_DROP := "acid_drop"
## Max deck cells between opposite copings for spine transfer (inclusive).
## 3+ cells → normal free-air transfer instead.
const SPINE_GAP_MAX_CELLS := 2


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


## Falling vert at top coping → along-arc drop-in (`land_vy * coping_sign`).
## Rising / rest → 0 (no outward kick from landing).
static func drop_in_along_from_land_vy(land_vy: float, side: int) -> float:
	if land_vy >= 0.0:
		return 0.0
	return land_vy * _PipeMath.coping_sign(side)


## Along-arc seed when landing locked on a pipe coping (pipe-exit, acid, spine).
## Converts falling vert into drop-in; keeps approach speed when already faster
## into the pipe. Outward approach alone does not seed along-arc.
static func merge_drop_in_along(approach_x: float, land_vy: float, side: int) -> float:
	var sign := _PipeMath.coping_sign(side)
	var from_fall := drop_in_along_from_land_vy(land_vy, side)
	# In signed space, into-pipe is negative. Take the stronger into-pipe speed.
	return minf(approach_x * sign, from_fall * sign) * sign


## X settle duration for locking onto an opposite coping (acid / spine).
## Continuous in height: `base + per_height * height_above_coping`.
## If `duration_max` > 0, soft-cap (still continuous below the cap).
static func lock_x_duration_for_height(
	height_above_coping: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float = 0.0,
) -> float:
	var d := (
		maxf(duration_base, 0.0)
		+ maxf(duration_per_height, 0.0) * maxf(height_above_coping, 0.0)
	)
	if duration_max > 0.0:
		d = minf(d, duration_max)
	return d


## Cubic smoothstep on 0…1 (ease in/out for X settle).
static func smoothstep01(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)



## Pipe-exit X-lock → free air (parabolic fly-out) when still rising, height clears
## coping+extra, and INPUT X points toward that pipe's side (right → +X, left → −X).
## See MotionVectors.Kind.INPUT. Falling (`air_vel_y` ≤ 0) never flies out.
## Acid-drop lock never flies out this way. `above_coping` is logical height above
## coping (`air_radius`); 0 means unlock as soon as at/above coping.
static func should_fly_out_pipe_lock(
	air_x_locked: bool,
	acid_drop_lock: bool,
	air_side: int,
	air_abs_height: float,
	air_radius: float,
	above_coping: float,
	input_x: float,
	air_vel_y: float,
	input_eps: float = 0.15,
) -> bool:
	if not air_x_locked or acid_drop_lock:
		return false
	# Rising only — ignore while falling or at apex rest.
	if air_vel_y <= 0.0:
		return false
	if air_abs_height + 0.001 < air_radius + maxf(above_coping, 0.0):
		return false
	var out := _PipeMath.coping_sign(air_side)
	return input_x * out > input_eps


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


## Deck-cell count for a coping gap (for docs/tests).
static func spine_gap_cells(dist: float, cell_w: float) -> int:
	var cw := maxf(cell_w, 0.001)
	return int(round(maxf(dist, 0.0) / cw))


## Opposite pipe for spine transfer: behind RIGHT → LEFT; behind LEFT → RIGHT.
static func spine_want_side(behind_sign: float) -> int:
	return 0 if behind_sign > 0.0 else 1  # LEFT / RIGHT


## Nearest opposite-facing TOP coping behind us within 0..SPINE_GAP_MAX_CELLS.
## Gap is measured in logical X (deck glyphs × cell_w). Returns {} if none /
## gap too wide (caller should use normal transfer).
static func find_spine_transfer_target(
	pipes: Array,
	from_x: float,
	logical_z: float,
	behind_sign: float,
	exclude_side: int,
	exclude_lip_x: float,
	cell_w: float,
	eps: float = 0.05,
) -> Dictionary:
	if absf(behind_sign) < 0.001:
		return {}
	var behind := signf(behind_sign)
	var want_side := spine_want_side(behind)
	var max_dist := float(SPINE_GAP_MAX_CELLS) * maxf(cell_w, 0.001) + eps
	var best: Dictionary = {}
	var best_dist := INF
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if int(pipe.side) == exclude_side and absf(float(pipe.lip_x) - exclude_lip_x) < 0.05:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var side: int = int(pipe.side)
		var lip: float = float(pipe.lip_x)
		var radius: float = float(pipe.radius)
		var top_coping: float = _PipeMath.coping_x(side, lip, radius)
		var dist: float = (top_coping - from_x) * behind
		# Shared coping (dist ~ 0) through 2-deck spine; reject 3+ decks.
		if dist < -eps or dist > max_dist:
			continue
		if dist < best_dist:
			best_dist = dist
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
