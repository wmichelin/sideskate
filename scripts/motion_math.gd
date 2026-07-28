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


## Integrate MOMENTUM for one physics tick.
## mode: "acid" | "spine" | "pipe_lock" | "free"
## Returns { "velocity": Vector2, "debug_accel": Vector2 }.
static func integrate_control_velocity(
	velocity: Vector2,
	input: Vector2,
	delta: float,
	mode: String,
	max_speed_x: float,
	max_speed_z: float,
	acceleration: float,
	friction: float,
	brake: float,
	ollie_accel: float,
	holding_ollie: bool,
	facing_h: String,
	coping_out_sign: float,
	acid_travel_x: float = 0.0,
) -> Dictionary:
	var before := velocity
	var v := velocity
	if mode == "acid" or mode == "spine":
		v.y = input.y * max_speed_z
		if mode == "acid" and absf(acid_travel_x) >= 1.0 and v.x * signf(acid_travel_x) < 0.0:
			v.x = 0.0
		v.x = clampf(v.x, -absf(max_speed_x), absf(max_speed_x))
		return _accel_out(before, v, delta)
	if mode == "pipe_lock":
		v.y = input.y * max_speed_z
		if v.x * coping_out_sign < 0.0:
			v.x = 0.0
		v.x = clampf(v.x, -absf(max_speed_x), absf(max_speed_x))
		return _accel_out(before, v, delta)

	var step := acceleration * delta
	var friction_step := friction * delta
	var brake_step := brake * delta
	v.x = integrate_axis_no_reverse(
		v.x,
		input.x * max_speed_x,
		step,
		friction_step,
		brake_step,
		holding_ollie and input.x == 0.0,
	)
	v.y = input.y * max_speed_z
	if holding_ollie:
		var face := 1.0 if facing_h == "r" else -1.0
		var stick_opposes := absf(input.x) >= 0.15 and input.x * face < 0.0
		if not stick_opposes:
			v.x = move_toward(v.x, face * max_speed_x, ollie_accel * delta)
	v.x = clampf(v.x, -absf(max_speed_x), absf(max_speed_x))
	return _accel_out(before, v, delta)


static func _accel_out(before: Vector2, after: Vector2, delta: float) -> Dictionary:
	var accel := Vector2.ZERO
	if delta > 0.0001:
		accel = (after - before) / delta
	return {"velocity": after, "debug_accel": accel}