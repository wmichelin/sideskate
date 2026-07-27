class_name MotionMath
extends RefCounted
## Pure motion / air-routing helpers (no scene state).


static func normalize_facing(raw: String) -> String:
	var f := raw.strip_edges().to_lower()
	if f == "l" or f == "left":
		return "l"
	return "r"


## Facing from measured ACTUAL planar velocity. Empty = do not change facing.
## Requires X-dominant motion (`|vx| > |vz|`) above `speed_eps` — never MOMENTUM.
static func facing_from_actual_vel(
	actual_vx: float, actual_vz: float, speed_eps: float = 8.0
) -> String:
	if absf(actual_vx) < speed_eps:
		return ""
	if absf(actual_vx) <= absf(actual_vz):
		return ""
	return "r" if actual_vx > 0.0 else "l"


## Rising, or at apex after a rise (vert≈0 but last non-zero was up).
static func transfer_vert_ok(
	vert_vel: float, last_nonzero_vert_vel: float, rest_eps: float = 0.5
) -> bool:
	if vert_vel > 0.0:
		return true
	return absf(vert_vel) <= rest_eps and last_nonzero_vert_vel > 0.0


## Move `current` toward `want`. Opposite stick uses `brake_step` (no reverse until
## stopped). Coast uses `friction_step`. Acceleration never decelerates.
static func integrate_axis_no_reverse(
	current: float,
	want: float,
	accel_step: float,
	friction_step: float,
	brake_step: float,
	skip_friction: bool,
) -> float:
	if want == 0.0:
		if skip_friction:
			return current
		return move_toward(current, 0.0, friction_step)
	if current != 0.0 and want * current < 0.0:
		return move_toward(current, 0.0, brake_step)
	return move_toward(current, want, accel_step)


## When measured motion is at rest, clear integrated momentum so reverse isn’t
## fighting leftover control speed (e.g. jammed on a boundary). Never while
## gravity is driving air — horizontal remnant must survive apex / free fall.
static func should_clear_momentum_at_rest(
	gravity_applies: bool, actual_speed: float, rest_eps: float = 1.0
) -> bool:
	if gravity_applies:
		return false
	return actual_speed <= rest_eps
