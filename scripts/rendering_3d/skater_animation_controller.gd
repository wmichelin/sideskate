class_name SkaterAnimationController
extends RefCounted
## Presentation only. Physics observations select clips; animation never moves
## the gameplay root or board. All clip clocks advance on fixed physics ticks.

const RIDE := &"ride_idle"
const CHARGE := &"ollie_charge"
const OLLIE := &"ollie_pop"
const AIR := &"airborne"
const LAND := &"landing"
const GRIND := &"grind"
const FALL := &"fall"
const REQUIRED := [RIDE, CHARGE, OLLIE, AIR, LAND, GRIND, FALL]

var pose_name: StringName = &""
var elapsed: float = 0.0
var _player: AnimationPlayer
var _was_airborne: bool = false


func configure(player: AnimationPlayer) -> bool:
	for clip in REQUIRED:
		if not player.has_animation(clip):
			push_error("Skater is missing gameplay animation: " + str(clip))
			return false
	_player = player
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in REQUIRED:
		var animation := _player.get_animation(clip)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in [RIDE, GRIND, FALL] else Animation.LOOP_NONE
	reset()
	return true


func reset() -> void:
	pose_name = &""
	_was_airborne = false
	_transition(RIDE, 0.0)
	if _player != null:
		_player.advance(0.0)


func tick(delta: float, airborne: bool, falling: bool, charge: float,
		popped: bool, grinding: bool, vertical_velocity: float) -> void:
	if _player == null:
		return
	if falling:
		_transition(FALL, 0.06)
	elif popped:
		# A successful sim pop wins over charge and any prior landing blend.
		_transition(OLLIE, 0.035)
	elif airborne:
		if pose_name != OLLIE or elapsed >= _length(OLLIE) or vertical_velocity <= 0.0:
			_transition(AIR, 0.08)
	elif _was_airborne:
		_transition(LAND, 0.04)
	elif charge > 0.0:
		_transition(CHARGE, 0.07)
	elif grinding:
		_transition(GRIND, 0.12)
	elif pose_name != LAND or elapsed >= _length(LAND):
		_transition(RIDE, 0.12)
	_was_airborne = airborne and not falling
	elapsed += maxf(delta, 0.0)
	if pose_name == CHARGE:
		# Scrub the crouch from actual charge, including holding at full charge.
		_player.advance(maxf(delta, 0.0))
		_player.seek(clampf(charge, 0.0, 1.0) * _length(CHARGE), true)
		_player.advance(0.0)
	elif pose_name == AIR:
		# Descending speed opens the tucked pose for contact. Rising air-outs
		# stay tucked; a short ollie cannot run an arbitrary airborne loop.
		_player.advance(maxf(delta, 0.0))
		_player.seek(clampf(-vertical_velocity / 650.0, 0.0, 1.0) * _length(AIR), true)
		_player.advance(0.0)
	else:
		_player.advance(maxf(delta, 0.0))


func _length(clip: StringName) -> float:
	return _player.get_animation(clip).length


func _transition(clip: StringName, blend: float) -> void:
	if _player == null or pose_name == clip:
		return
	pose_name = clip
	elapsed = 0.0
	_player.play(clip, blend)
