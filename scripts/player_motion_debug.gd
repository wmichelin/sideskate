class_name PlayerMotionDebug
extends RefCounted
## Pure motion_world / motion_speed / motion_screen for Player debug arrows.
## Inputs are explicit so tests can cover Kind branches without a live Player.

const _MotionVectors := preload("res://scripts/motion_vectors.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


static func motion_screen(
	kind: _MotionVectors.Kind,
	actual_vel_x: float,
	actual_vel_z: float,
	vert_vel: float,
	velocity: Vector2,
	ramp_along: float,
	on_ramp: bool,
	last_surface: Dictionary,
	last_input: Vector2,
	max_speed_x: float,
	max_speed_z: float,
) -> Vector2:
	match kind:
		_MotionVectors.Kind.ACTUAL:
			# +logical Z (farther) → up; +vertical (rising) → up.
			return Vector2(actual_vel_x, -actual_vel_z - vert_vel)
		_MotionVectors.Kind.MOMENTUM:
			if on_ramp:
				var split := _ramp_momentum_split(ramp_along, last_surface)
				return Vector2(split.x, -split.y)
			# Flat: X + depth Z (velocity.y is logical Z, not height).
			return Vector2(velocity.x, -velocity.y)
		_MotionVectors.Kind.INPUT:
			# Planar wish only — never height (player cannot steer Y).
			return Vector2(last_input.x * max_speed_x, -last_input.y * max_speed_z)
	return Vector2.ZERO


static func motion_world(
	kind: _MotionVectors.Kind,
	actual_vel_x: float,
	actual_vel_z: float,
	vert_vel: float,
	velocity: Vector2,
	ramp_along: float,
	on_ramp: bool,
	last_surface: Dictionary,
	last_input: Vector2,
	max_speed_x: float,
	max_speed_z: float,
) -> Vector3:
	match kind:
		_MotionVectors.Kind.ACTUAL:
			return Vector3(-actual_vel_x, vert_vel, actual_vel_z)
		_MotionVectors.Kind.MOMENTUM:
			if on_ramp:
				var split := _ramp_momentum_split(ramp_along, last_surface)
				return Vector3(-split.x, split.y, 0.0)
			return Vector3(-velocity.x, 0.0, velocity.y)
		_MotionVectors.Kind.INPUT:
			return Vector3(-last_input.x * max_speed_x, 0.0, last_input.y * max_speed_z)
	return Vector3.ZERO


static func motion_speed(
	kind: _MotionVectors.Kind,
	actual_vel_x: float,
	actual_vel_z: float,
	vert_vel: float,
	velocity: Vector2,
	ramp_along: float,
	on_ramp: bool,
	airborne: bool,
	last_input: Vector2,
	max_speed_x: float,
	max_speed_z: float,
	air_vel_y: float,
	air_carry_speed: float,
) -> float:
	match kind:
		_MotionVectors.Kind.ACTUAL:
			return Vector3(actual_vel_x, vert_vel, actual_vel_z).length()
		_MotionVectors.Kind.MOMENTUM:
			# Along-arc is the control speed on a pipe; horiz remnant is only display split.
			if on_ramp:
				return absf(ramp_along)
			if airborne:
				return max(absf(velocity.x), absf(air_vel_y), air_carry_speed)
			return velocity.length()
		_MotionVectors.Kind.INPUT:
			return Vector2(last_input.x * max_speed_x, last_input.y * max_speed_z).length()
	return 0.0


## Horiz remnant (x) + converted vertical (y) from along-arc on a pipe.
static func _ramp_momentum_split(ramp_along: float, last_surface: Dictionary) -> Vector2:
	var th := 0.0
	if last_surface.has("theta"):
		th = float(last_surface.theta)
	var sign := 1.0
	if last_surface.has("side"):
		sign = _PipeMath.coping_sign(int(last_surface.side))
	var toward := ramp_along * sign
	var clamped := clampf(th, 0.0, PI * 0.5)
	var horiz := ramp_along * cos(clamped)
	var vert := toward * sin(clamped)
	return Vector2(horiz, vert)
