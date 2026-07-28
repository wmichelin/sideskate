class_name AerialSettle
extends RefCounted
## Transfer-X + body-tilt interpolation for acid/spine settles.
## Pure state machine — Player owns scene pose and feeds height/travel each step.


var x_active: bool = false
var x_from: float = 0.0
var x_to: float = 0.0
var x_u: float = 0.0
var x_dur: float = 0.15
var x_ease: bool = false

var tilt_active: bool = false
var tilt_from: float = 0.0
var tilt_to: float = 0.0
var tilt_u: float = 0.0
var tilt_dur: float = 0.15
var tilt_ease: bool = false


func reset() -> void:
	x_active = false
	x_from = 0.0
	x_to = 0.0
	x_u = 0.0
	x_dur = 0.15
	x_ease = false
	tilt_active = false
	tilt_from = 0.0
	tilt_to = 0.0
	tilt_u = 0.0
	tilt_dur = 0.15
	tilt_ease = false


## Begin horizontal settle. Returns whether X lerp is active (false if already there).
func begin_x(
	from_x: float,
	to_x: float,
	height_scaled: bool,
	height_above: float,
	fixed_duration: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float,
) -> bool:
	x_from = from_x
	x_to = to_x
	x_u = 0.0
	x_ease = height_scaled
	if height_scaled:
		x_dur = maxf(
			AerialMath.lock_x_duration_for_height(
				height_above, duration_base, duration_per_height, duration_max
			),
			0.0001,
		)
	else:
		x_dur = fixed_duration
	x_active = absf(to_x - from_x) > 0.05
	return x_active


func begin_tilt(
	from_tilt: float,
	to_tilt: float,
	height_scaled: bool,
	height_above: float,
	fixed_duration: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float,
) -> bool:
	tilt_from = from_tilt
	tilt_to = to_tilt
	tilt_u = 0.0
	tilt_ease = height_scaled
	tilt_dur = fixed_duration
	if height_scaled:
		tilt_dur = maxf(
			AerialMath.lock_x_duration_for_height(
				height_above, duration_base, duration_per_height, duration_max
			),
			0.0001,
		)
	if absf(tilt_to - tilt_from) <= 0.02:
		tilt_active = false
		return false
	tilt_active = true
	return true


## Advance X settle. Returns next logical X (caller assigns). Finished → x_active false.
func step_x(
	delta: float,
	current_x: float,
	height_above: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float,
	acid_lock: bool,
	acid_travel_x: float,
) -> float:
	if not x_active:
		return current_x
	var duration := maxf(x_dur, 0.0001)
	if x_ease:
		var target := maxf(
			AerialMath.lock_x_duration_for_height(
				height_above, duration_base, duration_per_height, duration_max
			),
			0.0001,
		)
		# Snap shorter (catch-up); ease longer only (cuts height-noise jitter).
		if target < x_dur:
			x_dur = target
		else:
			var k := 1.0 - exp(-10.0 * delta)
			x_dur = lerpf(x_dur, target, k)
		duration = maxf(x_dur, 0.0001)
	x_u = clampf(x_u + delta / duration, 0.0, 1.0)
	var w := AerialMath.smoothstep01(x_u) if x_ease else x_u
	var next_x := lerpf(x_from, x_to, w)
	if acid_lock and absf(acid_travel_x) >= 1.0:
		next_x = AerialMath.acid_clamp_x_step(current_x, next_x, x_to, acid_travel_x)
	if x_u >= 1.0:
		x_active = false
		if acid_lock and absf(acid_travel_x) >= 1.0:
			next_x = AerialMath.acid_clamp_x_step(next_x, x_to, x_to, acid_travel_x)
		else:
			next_x = x_to
	return next_x


## Advance tilt settle. Returns next body tilt radians.
func step_tilt(
	delta: float,
	current_tilt: float,
	height_above: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float,
) -> float:
	if not tilt_active:
		return current_tilt
	var duration := maxf(tilt_dur, 0.0001)
	if tilt_ease:
		var target := maxf(
			AerialMath.lock_x_duration_for_height(
				height_above, duration_base, duration_per_height, duration_max
			),
			0.0001,
		)
		if target < tilt_dur:
			tilt_dur = target
		else:
			var k := 1.0 - exp(-10.0 * delta)
			tilt_dur = lerpf(tilt_dur, target, k)
		duration = maxf(tilt_dur, 0.0001)
	tilt_u = clampf(tilt_u + delta / duration, 0.0, 1.0)
	var w := AerialMath.smoothstep01(tilt_u) if tilt_ease else tilt_u
	var next := lerpf(tilt_from, tilt_to, w)
	if tilt_u >= 1.0:
		tilt_active = false
		next = tilt_to
	return next
