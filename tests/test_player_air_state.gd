extends RefCounted
## PlayerAirState / PlayerSurface / MotionMath.integrate_control_velocity.

const _Air := preload("res://scripts/player_air_state.gd")
const _Surf := preload("res://scripts/player_surface.gd")


func run() -> bool:
	return _clear_and_begin() and _facing_exclude() and _tilt() and _surface() and _integrate()


func _clear_and_begin() -> bool:
	var c = _Air.clear_patch()
	if bool(c.airborne) or not bool(c.reset_settle):
		push_error("clear_patch bad")
		return false
	var begin = _Air.begin_air_over_patch(
		{"zone": "left_pipe", "side": 0, "lip_x": 300.0, "radius": 100.0, "lock_x": true, "anchor_x": 200.0, "base_height": 0.0},
		50.0,
		true,
		0,
	)
	if not bool(begin.air_x_locked) or absf(float(begin.logical_x) - 200.0) > 0.01:
		push_error("begin lock pin failed: %s" % begin)
		return false
	return true


func _facing_exclude() -> bool:
	var ex = _Air.facing_exclude(1, 400.0, 0.0, 100.0, false, "flat", 0, 0.0, NAN, NAN, false, 0, 0.0, NAN, NAN)
	if int(ex.side) != 1:
		push_error("exit exclude must win")
		return false
	return true


func _tilt() -> bool:
	var locked = _Air.body_tilt_target_radians(true, 1, true, false, {}, 1)
	if absf(locked - (-PI * 0.5)) > 0.01:
		push_error("locked tilt want -π/2")
		return false
	return true


func _surface() -> bool:
	var air = _Surf.decorate_air_surface({"zone": "flat"}, "left_pipe", 1, 220.0)
	if str(air.zone) != "air" or absf(float(air.height) - 220.0) > 0.01:
		push_error("decorate air failed")
		return false
	if not _Surf.should_follow_sample_height(true, 10.0, 100.0, 0.5):
		push_error("on_ramp must follow")
		return false
	return true


func _integrate() -> bool:
	var free = MotionMath.integrate_control_velocity(
		Vector2(100.0, 0.0), Vector2(1.0, 0.0), 1.0 / 60.0, "free",
		880.0, 400.0, 3250.0, 0.0, 1250.0, 650.0, false, "r", 1.0, 0.0
	)
	if float(free.velocity.x) <= 100.0:
		push_error("free accel should increase vx")
		return false
	var acid = MotionMath.integrate_control_velocity(
		Vector2(-50.0, 0.0), Vector2.ZERO, 1.0 / 60.0, "acid",
		880.0, 400.0, 3250.0, 0.0, 1250.0, 650.0, false, "r", 1.0, 1.0
	)
	if absf(float(acid.velocity.x)) > 0.01:
		push_error("acid must zero reverse travel")
		return false
	return true
