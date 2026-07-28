extends RefCounted
## PlayerMotionDebug: Kind vector / speed split for ramp, flat, air.

const _PlayerMotionDebug := preload("res://scripts/player_motion_debug.gd")
const _MotionVectors := preload("res://scripts/motion_vectors.gd")


func run() -> bool:
	return (
		_ramp_momentum_includes_vertical()
		and _flat_momentum_is_planar()
		and _airborne_actual_includes_vert()
	)


func _ramp_momentum_includes_vertical() -> bool:
	# RIGHT pipe, theta=PI/4, along=+100 → toward lip, horiz and vert both nonzero.
	var surface := {"theta": PI * 0.25, "side": 1}
	var world = _PlayerMotionDebug.motion_world(
		_MotionVectors.Kind.MOMENTUM,
		0.0, 0.0, 0.0,
		Vector2.ZERO,
		100.0,
		true,
		surface,
		Vector2.ZERO,
		880.0,
		400.0,
	)
	if absf(world.y) < 1.0:
		push_error("ramp MOMENTUM world must include vertical, got %s" % world)
		return false
	if absf(world.z) > 0.001:
		push_error("ramp MOMENTUM world Z should be 0, got %s" % world)
		return false
	var screen = _PlayerMotionDebug.motion_screen(
		_MotionVectors.Kind.MOMENTUM,
		0.0, 0.0, 0.0,
		Vector2.ZERO,
		100.0,
		true,
		surface,
		Vector2.ZERO,
		880.0,
		400.0,
	)
	if absf(screen.y) < 1.0:
		push_error("ramp MOMENTUM screen must include vertical, got %s" % screen)
		return false
	var speed = _PlayerMotionDebug.motion_speed(
		_MotionVectors.Kind.MOMENTUM,
		0.0, 0.0, 0.0,
		Vector2.ZERO,
		100.0,
		true,
		false,
		Vector2.ZERO,
		880.0,
		400.0,
		0.0,
		0.0,
	)
	if absf(speed - 100.0) > 0.001:
		push_error("ramp MOMENTUM speed is |along|, got %s" % speed)
		return false
	return true


func _flat_momentum_is_planar() -> bool:
	var vel := Vector2(200.0, 50.0)
	var world = _PlayerMotionDebug.motion_world(
		_MotionVectors.Kind.MOMENTUM,
		0.0, 0.0, 99.0,
		vel,
		0.0,
		false,
		{},
		Vector2.ZERO,
		880.0,
		400.0,
	)
	if absf(world.y) > 0.001:
		push_error("flat MOMENTUM must be planar (Y=0), got %s" % world)
		return false
	if absf(world.x + 200.0) > 0.001 or absf(world.z - 50.0) > 0.001:
		push_error("flat MOMENTUM axes mismatch: %s" % world)
		return false
	var screen = _PlayerMotionDebug.motion_screen(
		_MotionVectors.Kind.MOMENTUM,
		0.0, 0.0, 99.0,
		vel,
		0.0,
		false,
		{},
		Vector2.ZERO,
		880.0,
		400.0,
	)
	if absf(screen.x - 200.0) > 0.001 or absf(screen.y + 50.0) > 0.001:
		push_error("flat MOMENTUM screen mismatch: %s" % screen)
		return false
	return true


func _airborne_actual_includes_vert() -> bool:
	var world = _PlayerMotionDebug.motion_world(
		_MotionVectors.Kind.ACTUAL,
		30.0,
		10.0,
		80.0,
		Vector2.ZERO,
		0.0,
		false,
		{},
		Vector2.ZERO,
		880.0,
		400.0,
	)
	if absf(world.y - 80.0) > 0.001:
		push_error("airborne ACTUAL must include vert, got %s" % world)
		return false
	var speed = _PlayerMotionDebug.motion_speed(
		_MotionVectors.Kind.ACTUAL,
		30.0,
		10.0,
		80.0,
		Vector2.ZERO,
		0.0,
		false,
		true,
		Vector2.ZERO,
		880.0,
		400.0,
		0.0,
		0.0,
	)
	var expect := Vector3(30.0, 80.0, 10.0).length()
	if absf(speed - expect) > 0.001:
		push_error("ACTUAL speed mismatch: %s want %s" % [speed, expect])
		return false
	return true
