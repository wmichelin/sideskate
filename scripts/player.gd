extends Node2D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## Air over any zone. Coping exit locks X (gravity applies); acid drop locks X only.
## Ride-off a higher surface → free air (keep height + gravity). All sim on physics ticks.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")
const _MotionVectors := preload("res://scripts/motion_vectors.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")

@export var max_speed_x: float = 880.0

@export var max_speed_z: float = 400.0
@export var acceleration: float = 3250.0
## Coast rate when no input (logical u/s²). Debug slider writes this.
@export var friction: float = 0.0
## Opposite-stick brake rate (logical u/s²). Much stronger than friction. Debug slider writes this.
@export var brake: float = 1250.0
## THPS-style forward accel while holding ollie (logical units/s²). Debug slider writes this.
@export var ollie_accel: float = 650.0
@export var depth_speed_feel: bool = true
@export var level_path: NodePath = NodePath("../RampLevel")
## How far past the coping to probe for transfer targets.
@export var transfer_probe: float = 8.0
## Physics-time duration for transfer horizontal settle.
@export var transfer_x_duration: float = 0.15
## Min free-air |vx| when releasing locked pipe air via transfer.
@export var transfer_release_min: float = 260.0
## Gravity while in unlocked air (m/s²). Debug slider writes this.
@export var gravity_ms2: float = -19.0
## Convert m/s² into logical units/s².
@export var logic_per_meter: float = 100.0
## Feet must drop at least this far below prior support to ride off into air.
@export var ride_off_height_eps: float = 0.5
## How far behind facing a top coping may still be acid-dropped (logical X, not screen px).
@export var acid_drop_buffer: float = 44.0
## Max distance ahead (logical X) to a top coping for acid drop — prevents cross-plaza lerps.
@export var acid_drop_max_ahead: float = 120.0
## Acid/spine X settle seconds at coping (height-above = 0).
@export var acid_drop_x_duration: float = 0.18
## Extra settle seconds per logical unit of height above coping.
@export var acid_drop_x_duration_per_height: float = 0.002
## Soft cap on acid/spine settle (0 = uncapped).
@export var acid_drop_x_duration_max: float = 0.9
## God-mode vertical speed (logical units/s) for j/k. Debug only.
@export var god_vert_speed: float = 320.0
## Along-arc speed drain while on a pipe (logical u/s²). Debug slider writes this.
@export var ramp_friction: float = 0.0
## Pipe-exit X-lock fly-out: unlock into free air this far above coping (logical).
## INPUT must point toward that pipe's side. Debug slider writes this.
@export var fly_out_above_coping: float = 40.0

@onready var depth: PseudoDepthBody = $PseudoDepthBody
@onready var _head_debug_label: Label = $Body/HeadDebug/Label
@onready var _face_nose: Polygon2D = $Body/FaceNose

var _velocity: Vector2 = Vector2.ZERO
## Last physics-tick control acceleration (d(_velocity)/dt from integrate).
var _debug_accel: Vector2 = Vector2.ZERO
## Along-arc speed while on a pipe (world-X signed). Stick integrates against this;
## `_velocity.x` is the remaining horizontal component `along * cos(θ)` after projection.
var _ramp_along: float = 0.0
var _on_ramp: bool = false
## Sticky pipe identity while riding — adjacent opposite pipes share coping X.
var _ramp_side: int = QuarterPipe.PipeSide.RIGHT
var _ramp_lip_x: float = 0.0
var _ramp_base_height: float = 0.0
var _level: RampLevel
var last_surface: Dictionary = {}

var _airborne: bool = false
## Absolute logical feet height while airborne.
var air_abs_height: float = 0.0
## Vertical velocity while airborne (logic units/s); used for gravity.
var air_vel_y: float = 0.0
## Zone underneath while airborne (left_pipe / right_pipe / deck / flat).
var air_over: String = ""
## Layer index for current air_over surface (-1 unknown).
var _air_over_layer: int = -1
var _air_x_locked: bool = false
var _air_side: int = QuarterPipe.PipeSide.RIGHT
var _air_lip_x: float = 0.0
var _air_coping_x: float = 0.0
var _air_radius: float = 150.0
var _air_base_height: float = 0.0
## Last behind-sign used for transfer probes when unlocked.
var _transfer_behind_sign: float = 1.0

var _transfer_x_active: bool = false
var _transfer_x_from: float = 0.0
var _transfer_x_to: float = 0.0
## Progress 0…1 for the active X settle (advanced by delta / live duration).
var _transfer_x_u: float = 0.0
## Fixed duration when not height-scaled (free-air transfer).
var _transfer_x_dur: float = 0.15
## Height-scaled settle (acid / spine): duration = f(live height above coping).
var _transfer_x_ease: bool = false
## One transfer per aerial; replenished on any surface contact.
var _transfer_available: bool = true
## One acid drop per aerial; replenished on any surface contact.
var _acid_drop_available: bool = true
## X-locked via acid drop: pin to coping; gravity continues (same as coping lock).
var _acid_drop_lock: bool = false
## Spine transfer: X-lock to opposite coping; land converts vert → along-arc (drop-in).
var _spine_transfer_lock: bool = false
## Once per locked aerial: facing flip (or stick override) at vertical apex.
var _apex_facing_done: bool = false
## Measured actual velocity from position deltas (not stick / momentum).
var _actual_vel_x: float = 0.0
var _actual_vel_z: float = 0.0
var _vert_vel: float = 0.0
## Last non-zero measured vertical rate (for apex: vert==0 but still "rising").
var _last_nonzero_vert_vel: float = 0.0
var _prev_logical_x: float = 0.0
var _prev_logical_z: float = 0.0
var _prev_feet_h: float = 0.0
## Last physics-tick stick input (X = horiz, Y = depth Z). Debug input arrow.
var _last_input: Vector2 = Vector2.ZERO
## Horizontal facing: "l" or "r". Spawn default from level (usually r).
var facing_h: String = "r"


func _ready() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	var head_dbg := get_node_or_null("Body/HeadDebug")
	if head_dbg:
		head_dbg.add_to_group("debug_tools")
		if not DebugTools.is_available():
			head_dbg.queue_free()
			_head_debug_label = null
	call_deferred("_spawn_from_level")


func _spawn_from_level() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level and not _level.rebuilt.is_connected(_on_level_rebuilt):
		_level.rebuilt.connect(_on_level_rebuilt)
	_apply_spawn_from_level()


func _on_level_rebuilt() -> void:
	_apply_spawn_from_level()


func _apply_spawn_from_level() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level and _level.spec:
		depth.logical_x = _level.spec.spawn_x
		depth.logical_z = _level.spec.spawn_z
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
		facing_h = _normalize_facing(_level.spec.spawn_facing)
	else:
		depth.logical_x = 640.0
		depth.logical_z = 40.0
		facing_h = "r"
	_velocity = Vector2.ZERO
	_ramp_along = 0.0
	_clear_air()
	_apply_surface()
	_prev_logical_x = depth.logical_x
	_prev_logical_z = depth.logical_z
	_prev_feet_h = _feet_height()
	_actual_vel_x = 0.0
	_actual_vel_z = 0.0
	_vert_vel = 0.0
	_last_nonzero_vert_vel = 0.0
	_refresh_head_debug()
	_update_face_nose()
	depth.apply()


func _physics_process(delta: float) -> void:
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel

	if DebugTools.is_available() and Input.is_action_just_pressed("god_mode_toggle"):
		DebugTools.toggle_god_mode()
		if DebugTools.god_mode:
			air_vel_y = 0.0

	if Input.is_action_just_pressed("transfer"):
		_try_air_action()

	var input := _read_move_input()
	_last_input = input
	# Stick must accelerate along-arc speed, not the post-projection horizontal remnant.
	if _on_ramp:
		_velocity.x = _ramp_along
	_update_facing_h(input)
	_update_face_nose()
	_integrate_velocity(input, delta)
	if _on_ramp:
		_ramp_along = _velocity.x

	var speed_mul := depth.depth_speed_multiplier() if depth_speed_feel else 1.0
	_apply_motion(delta, speed_mul)
	_step_god_vertical(delta)

	if _level:
		depth.logical_x = clampf(depth.logical_x, _level.x_min(), _level.x_max())
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	else:
		depth.logical_x = clampf(depth.logical_x, 80.0, 1200.0)

	_apply_surface()
	_update_actual_velocity(delta)
	_clear_momentum_if_at_rest()
	depth.apply()


func _feet_height() -> float:
	if _airborne:
		return air_abs_height
	return depth.surface_height


func _air_coping_floor() -> float:
	return _air_base_height + _air_radius


## Keep moves inside layer-0 playable footprint (hard boundary). Always commits.
func _commit_xz(next_x: float, next_z: float) -> bool:
	var z := depth.clamp_z(next_z)
	var x := next_x
	if _level and _level.spec:
		var clamped: Vector2 = _level.spec.clamp_to_playable(x, z)
		x = clamped.x
		z = depth.clamp_z(clamped.y)
	depth.logical_x = x
	depth.logical_z = z
	return true


## Snap current pose into playable bounds (coping pin / transfer / pipe move).
func _clamp_pose_playable() -> void:
	if _level == null or _level.spec == null:
		return
	var clamped: Vector2 = _level.spec.clamp_to_playable(depth.logical_x, depth.logical_z)
	depth.logical_x = clamped.x
	depth.logical_z = depth.clamp_z(clamped.y)


func _update_actual_velocity(delta: float) -> void:
	var h := _feet_height()
	if delta > 0.0001:
		_actual_vel_x = (depth.logical_x - _prev_logical_x) / delta
		_actual_vel_z = (depth.logical_z - _prev_logical_z) / delta
		_vert_vel = (h - _prev_feet_h) / delta
	else:
		_actual_vel_x = 0.0
		_actual_vel_z = 0.0
		_vert_vel = 0.0
	if absf(_vert_vel) > 0.5:
		_last_nonzero_vert_vel = _vert_vel
	_prev_logical_x = depth.logical_x
	_prev_logical_z = depth.logical_z
	_prev_feet_h = h


## Drop integrated momentum when ACTUAL speed is ~0 (unless air gravity applies).
func _clear_momentum_if_at_rest() -> void:
	var gravity_applies := _airborne and _air_over_uses_gravity()
	var actual_speed := Vector3(_actual_vel_x, _vert_vel, _actual_vel_z).length()
	if not _MotionMath.should_clear_momentum_at_rest(gravity_applies, actual_speed):
		return
	_velocity = Vector2.ZERO
	_ramp_along = 0.0


func _apply_motion(delta: float, speed_mul: float) -> void:
	if _airborne:
		_clamp_pose_playable()
		_step_transfer_x(delta)

		if _air_x_locked:
			# Don't pin X while a transfer/acid-drop lerp is carrying us to coping.
			if not _transfer_x_active:
				depth.logical_x = _air_coping_x
			_clamp_pose_playable()
			_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)

			# God mode over a coping lock: keep X pin, free height via j/k.
			if DebugTools.god_mode:
				_resolve_and_apply_air_contact(air_abs_height)
				air_vel_y = 0.0
				return

			var prev_air_vy := air_vel_y
			var h_before := air_abs_height
			# Contact after XZ commit — label and collision share this resolve.
			var contact: Dictionary = _resolve_and_apply_air_contact(h_before)
			_integrate_air_gravity(delta)
			_try_apex_facing_flip(prev_air_vy)
			# Fly-out unlocks X but must still run landing this tick.
			if _try_fly_out_from_pipe_lock():
				if not _transfer_x_active:
					_commit_xz(
						depth.logical_x + _velocity.x * speed_mul * delta,
						depth.logical_z
					)
				# Re-resolve after X nudge so contact matches new column.
				contact = _resolve_and_apply_air_contact(h_before)
			_try_land_from_air_contact(contact, h_before, delta, speed_mul)
			return

		# Unlocked air: free XZ then contact → gravity → land from same contact.
		if not _transfer_x_active:
			_commit_xz(
				depth.logical_x + _velocity.x * speed_mul * delta,
				depth.logical_z + _velocity.y * speed_mul * delta
			)
		else:
			_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)
		if _air_over_uses_gravity():
			var h_before_free := air_abs_height
			var contact_free: Dictionary = _resolve_and_apply_air_contact(h_before_free)
			_integrate_air_gravity(delta)
			_try_land_from_air_contact(contact_free, h_before_free, delta, speed_mul)
		else:
			_resolve_and_apply_air_contact(air_abs_height)
		return

	var prev_support_h := depth.surface_height
	_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)

	var hit: Dictionary = _sample_underfoot()
	var solid_pad := _solid_pad_underfoot(prev_support_h)
	var allow_pipe := _ContactMath.should_mount_pipe(
		hit, prev_support_h, _on_ramp, solid_pad, ride_off_height_eps
	)
	if allow_pipe:
		# If sticky pipe lost us onto an opposite neighbor at shared coping, launch
		# instead of flipping walls mid-ride.
		if _on_ramp and _is_opposite_pipe_swap(hit):
			var up_speed: float = maxf(_velocity.x * _coping_sign(_ramp_side), 0.0)
			_enter_air_from_pipe({
				"side": _ramp_side,
				"lip_x": _ramp_lip_x,
				"radius": _sticky_pipe_radius(),
				"base_height": _ramp_base_height,
			}, up_speed)
			return
		if not _on_ramp:
			_ramp_along = _velocity.x
			_on_ramp = true
		_ramp_side = int(hit.get("side", _ramp_side))
		_ramp_lip_x = float(hit.get("lip_x", _ramp_lip_x))
		_ramp_base_height = float(hit.get("base_height", _ramp_base_height))
		_apply_ramp_friction(delta)
		_ramp_along = _velocity.x
		var arc_speed := _ramp_along * speed_mul
		_move_along_pipe(hit, arc_speed, delta)
		# Re-sample after move so θ matches feet; project along → horiz remnant.
		if _on_ramp and not _airborne:
			var after: Dictionary = _sample_underfoot()
			if _is_pipe_hit(after) and not _is_opposite_pipe_swap(after):
				_ramp_side = int(after.get("side", _ramp_side))
				_ramp_lip_x = float(after.get("lip_x", _ramp_lip_x))
				_ramp_base_height = float(after.get("base_height", _ramp_base_height))
				_project_ramp_velocity(float(after.get("theta", 0.0)))
			elif _is_pipe_hit(after) and _is_opposite_pipe_swap(after):
				var up_speed2: float = maxf(_ramp_along * _coping_sign(_ramp_side), 0.0)
				_enter_air_from_pipe({
					"side": _ramp_side,
					"lip_x": _ramp_lip_x,
					"radius": _sticky_pipe_radius(),
					"base_height": _ramp_base_height,
				}, up_speed2)
			else:
				_leave_ramp_to_flat()
		return

	if _on_ramp:
		_leave_ramp_to_flat()
	var arc_speed := _velocity.x * speed_mul
	var next_x: float = depth.logical_x + arc_speed * delta
	var cross := _coping_cross_hit(depth.logical_x, next_x)
	if (
		not cross.is_empty()
		and not solid_pad
		and _ContactMath.should_coping_launch(hit, cross)
	):
		var side: int = int(cross.side)
		var up_speed: float = maxf(arc_speed * _coping_sign(side), 0.0)
		_enter_air_from_pipe(cross, up_speed)
		return
	_commit_xz(next_x, depth.logical_z)
	_try_ride_off_air(prev_support_h)


func _step_transfer_x(delta: float) -> void:
	if not _transfer_x_active:
		return
	var duration := maxf(_transfer_x_dur, 0.0001)
	if _transfer_x_ease:
		var above := maxf(air_abs_height - _air_coping_floor(), 0.0)
		duration = maxf(
			_AerialMath.lock_x_duration_for_height(
				above,
				acid_drop_x_duration,
				acid_drop_x_duration_per_height,
				acid_drop_x_duration_max,
			),
			0.0001,
		)
	_transfer_x_u = clampf(_transfer_x_u + delta / duration, 0.0, 1.0)
	var w := _AerialMath.smoothstep01(_transfer_x_u) if _transfer_x_ease else _transfer_x_u
	depth.logical_x = lerpf(_transfer_x_from, _transfer_x_to, w)
	if _transfer_x_u >= 1.0:
		_transfer_x_active = false
		depth.logical_x = _transfer_x_to
	_clamp_pose_playable()


## Start horizontal settle onto `to_x`. Acid/spine: live duration from height above
## coping (`base + rate * h`) + smoothstep. Free transfer: fixed duration, linear.
func _begin_transfer_x_lerp(to_x: float, height_scaled: bool, _coping_radius: float = 0.0) -> void:
	_transfer_x_from = depth.logical_x
	_transfer_x_to = to_x
	_transfer_x_u = 0.0
	_transfer_x_ease = height_scaled
	_transfer_x_dur = transfer_x_duration
	_transfer_x_active = absf(to_x - depth.logical_x) > 0.05
	if not _transfer_x_active:
		depth.logical_x = to_x


## Resolve air contact at current XZ and write air_over / layer / sticky ids from it.
## prefer_h is feet height before this tick's gravity (label = collision source).
func _resolve_and_apply_air_contact(prefer_h: float) -> Dictionary:
	if _level == null:
		return _ContactMath.make_air_contact("oob", -1, 0.0, false, {})
	var sticky_side := -1
	var sticky_lip := NAN
	var sticky_base := NAN
	# Keep sticky pipe while airborne over a pipe (locked or free) so footprint
	# stays solid even if feet dip below the arc.
	if air_over == "left_pipe" or air_over == "right_pipe":
		sticky_side = _air_side
		sticky_lip = _air_lip_x
		sticky_base = _air_base_height
	elif _air_x_locked:
		sticky_side = _air_side
		sticky_lip = _air_lip_x
		sticky_base = _air_base_height
	var contact: Dictionary = _level.resolve_air_contact(
		depth.logical_x, depth.logical_z, prefer_h, sticky_side, sticky_lip, sticky_base
	)
	# Pipe-exit lock: drop when leaving coping column (acid/spine keep lock).
	if _air_x_locked and not _acid_drop_lock and not _spine_transfer_lock:
		if not _is_aligned_with_air_coping():
			_air_x_locked = false
		# Higher stacked same-side pipe underfoot: retarget lock.
		var hit: Dictionary = contact.get("hit", {})
		if (
			_air_x_locked
			and _ContactMath.is_pipe(hit)
			and int(hit.get("side", -1)) == _air_side
			and float(hit.get("base_height", 0.0)) > _air_base_height + 0.5
		):
			_adopt_air_pipe_from_hit(hit, true)
			contact = _level.resolve_air_contact(
				depth.logical_x,
				depth.logical_z,
				prefer_h,
				_air_side,
				_air_lip_x,
				_air_base_height,
			)

	air_over = str(contact.get("zone", "flat"))
	_air_over_layer = int(contact.get("layer", -1))
	var chit: Dictionary = contact.get("hit", {})
	if _ContactMath.is_pipe(chit):
		_air_side = int(chit.get("side", _air_side))
		_air_lip_x = float(chit.get("lip_x", _air_lip_x))
		_air_radius = _pipe_radius_for_hit(chit)
		_air_base_height = float(chit.get("base_height", _air_base_height))
		_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
		_transfer_behind_sign = _coping_sign(_air_side)
	elif air_over == "flat" or air_over == "deck":
		_air_base_height = float(contact.get("height", chit.get("base_height", 0.0)))
	elif air_over == "hole":
		_air_base_height = float(contact.get("height", 0.0))
	return contact


## True when logical X is still on the locked pipe's top coping column.
func _is_aligned_with_air_coping() -> bool:
	var eps := maxf(_air_radius * 0.05, 2.0)
	return absf(depth.logical_x - _air_coping_x) <= eps


## Apply pipe identity from a sample hit. `keep_lock` pins X to that pipe's coping.
func _adopt_air_pipe_from_hit(under: Dictionary, keep_lock: bool) -> void:
	air_over = _pipe_zone_name(int(under.get("side", _air_side)))
	_air_side = int(under.get("side", _air_side))
	_air_lip_x = float(under.get("lip_x", _air_lip_x))
	_air_radius = _pipe_radius_for_hit(under)
	_air_base_height = float(under.get("base_height", _air_base_height))
	_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
	_transfer_behind_sign = _coping_sign(_air_side)
	if under.has("layer"):
		_air_over_layer = int(under.get("layer", -1))
	else:
		_air_over_layer = _layer_index_for_base(_air_base_height)
	if keep_lock:
		_air_x_locked = true
		if not _transfer_x_active:
			depth.logical_x = _air_coping_x
		_clamp_pose_playable()


func _air_over_uses_gravity() -> bool:
	# All air modes use gravity except god mode (vertical via j/k).
	return not DebugTools.god_mode


func _integrate_air_gravity(delta: float) -> void:
	if DebugTools.god_mode:
		air_vel_y = 0.0
		return
	air_vel_y += gravity_ms2 * logic_per_meter * delta
	air_abs_height += air_vel_y * delta


## Debug god mode: j/k change height; take off from ground with k.
func _step_god_vertical(delta: float) -> void:
	if not DebugTools.is_available() or not DebugTools.god_mode:
		return
	var v := Input.get_axis("god_down", "god_up")
	if is_zero_approx(v):
		return
	if not _airborne:
		if v <= 0.0:
			return
		var under: Dictionary = (
			_level.sample(depth.logical_x, depth.logical_z, -1, NAN, depth.surface_height)
			if _level else {}
		)
		var zone := str(under.get("zone", "flat"))
		if zone == "oob":
			zone = "flat"
		var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
		if _is_pipe_hit(under):
			target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
			target["lip_x"] = float(under.get("lip_x", depth.logical_x))
			target["radius"] = _pipe_radius_for_hit(under)
			target["base_height"] = float(under.get("base_height", 0.0))
			target["layer"] = int(under.get("layer", -1))
		_begin_air_over(target, depth.surface_height, false)
		air_vel_y = 0.0
	var h_before_god := air_abs_height
	air_abs_height += v * god_vert_speed * delta
	air_vel_y = 0.0
	if v < 0.0:
		air_vel_y = -0.01
		var contact: Dictionary = _resolve_and_apply_air_contact(h_before_god)
		_try_land_from_air_contact(contact, h_before_god, delta, 1.0)
		air_vel_y = 0.0


func _underlying_surface_height() -> float:
	if _level == null:
		return 0.0
	var contact: Dictionary = _level.resolve_air_contact(
		depth.logical_x,
		depth.logical_z,
		air_abs_height,
		_air_side if (air_over == "left_pipe" or air_over == "right_pipe") else -1,
		_air_lip_x if (air_over == "left_pipe" or air_over == "right_pipe") else NAN,
		_air_base_height if (air_over == "left_pipe" or air_over == "right_pipe") else NAN,
	)
	if _ContactMath.is_air_contact_solid(contact):
		return float(contact.get("height", 0.0))
	# Hole / oob: shadow on next solid below via sample.
	var resolved: Dictionary = _level.sample_sweep(
		depth.logical_x, depth.logical_z, air_abs_height, air_abs_height
	)
	return float(resolved.get("height", 0.0))


## Land using the same air contact that drives the label. Solid contact is hard —
## never tunnel through. Hole skips this story; may catch a lower solid in the sweep.
func _try_land_from_air_contact(
	contact: Dictionary, h_before: float, delta: float, speed_mul: float
) -> bool:
	if air_vel_y > 0.0:
		return false
	if _level == null:
		return false
	var h1 := air_abs_height
	var land_hit: Dictionary = {}
	var floor_h := 0.0

	if _ContactMath.should_land_on_air_contact(contact, h_before, h1):
		land_hit = contact.get("hit", {})
		floor_h = float(contact.get("height", 0.0))
	else:
		# Hole / still above: optionally catch a lower solid crossed this tick.
		if _ContactMath.is_air_contact_solid(contact) and h1 > float(contact.get("height", 0.0)) + 0.05:
			return false
		var resolved: Dictionary = _level.sample_sweep(
			depth.logical_x, depth.logical_z, h_before, h1
		)
		land_hit = resolved.get("hit", {})
		if land_hit.is_empty() or (
			not land_hit.get("active", true) and str(land_hit.get("zone", "")) == "oob"
		):
			return false
		floor_h = float(resolved.get("height", 0.0))
		# Don't land on a surface above the hole story we're falling through without crossing.
		if str(contact.get("zone", "")) == "hole":
			var hole_h := float(contact.get("height", 0.0))
			# Only accept surfaces strictly below this story's height.
			if floor_h >= hole_h - 0.05:
				# Re-resolve lower: exclude by picking below hole.
				var lower: Dictionary = _level.sample(
					depth.logical_x, depth.logical_z, -1, NAN, hole_h - 2.0
				)
				if lower.is_empty() or (
					not lower.get("active", true) and str(lower.get("zone", "")) == "oob"
				):
					return false
				var lh := float(lower.get("height", 0.0))
				if lh >= hole_h - 0.05:
					return false
				if h1 > lh + 0.05:
					return false
				if not _ContactMath.height_in_sweep(lh, h_before, h1) and h_before < lh - 0.05:
					return false
				land_hit = lower
				floor_h = lh
			elif h1 > floor_h + 0.05:
				return false
			elif h_before < floor_h - 0.05 and not bool(resolved.get("crossed_solid", false)):
				if not _ContactMath.height_in_sweep(floor_h, h_before, h1):
					return false
		else:
			if h1 > floor_h + 0.05:
				return false
			if h_before < floor_h - 0.05 and not bool(resolved.get("crossed_solid", false)):
				if not _ContactMath.height_in_sweep(floor_h, h_before, h1):
					return false

	if land_hit.is_empty():
		return false

	air_abs_height = floor_h
	var pin_x := depth.logical_x
	if _air_x_locked and _is_aligned_with_air_coping():
		pin_x = _air_coping_x
	var was_locked := _air_x_locked
	var land_vy := air_vel_y
	var approach_x := _velocity.x
	_clear_air()

	if _ContactMath.is_solid(land_hit):
		depth.surface_height = floor_h
		depth.logical_x = pin_x
		_velocity.x = approach_x
		_on_ramp = false
		return true

	if _ContactMath.is_pipe(land_hit):
		var land_side := int(land_hit.get("side", QuarterPipe.PipeSide.RIGHT))
		var land_lip := float(land_hit.get("lip_x", depth.logical_x))
		var land_base := float(land_hit.get("base_height", 0.0))
		var side_sign := _coping_sign(land_side)
		var along := approach_x
		if was_locked or land_vy < -1.0:
			along = _AerialMath.merge_drop_in_along(approach_x, land_vy, land_side)
		_ramp_along = along
		_velocity.x = along
		_on_ramp = true
		_ramp_side = land_side
		_ramp_lip_x = land_lip
		_ramp_base_height = land_base
		depth.surface_height = floor_h
		if along * side_sign < -1.0 or absf(along) > 1.0:
			_move_along_pipe(land_hit, along * speed_mul, delta)
		else:
			depth.logical_x = pin_x if was_locked else depth.logical_x
		return true

	depth.surface_height = floor_h
	depth.logical_x = pin_x
	return true


## Leave a higher support surface into free air (keep height, apply gravity).
func _try_ride_off_air(prev_support_h: float) -> void:
	if _airborne or _level == null:
		return
	var under: Dictionary = _level.sample(
		depth.logical_x, depth.logical_z, -1, NAN, prev_support_h
	)
	var zone := str(under.get("zone", "flat"))
	# Hole / empty: no support on this story. Never treat as standing surface.
	var has_support: bool = (
		bool(under.get("active", true))
		and zone != "hole"
		and zone != "oob"
	)
	var new_h := 0.0
	if has_support:
		new_h = float(under.get("height", 0.0))
	if new_h >= prev_support_h - ride_off_height_eps:
		return
	if zone == "oob" or zone == "hole":
		zone = "flat"
	var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
	if _is_pipe_hit(under) and has_support:
		target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
		target["lip_x"] = float(under.get("lip_x", depth.logical_x))
		target["radius"] = _pipe_radius_for_hit(under)
		target["base_height"] = float(under.get("base_height", 0.0))
		target["layer"] = int(under.get("layer", -1))
	_begin_air_over(target, prev_support_h, false)


## True when feet are on a solid floor/deck pad (not a hole). Blocks fake
## pipe-exit pops when an upper story sits at layer-0 coping height.
func _solid_pad_underfoot(feet_h: float) -> bool:
	if _level == null or _level.spec == null:
		return false
	var eps := ride_off_height_eps + 1.5
	for h in _level.spec.floor_heights_at(depth.logical_x, depth.logical_z):
		if absf(float(h) - feet_h) <= eps:
			return true
	var p := Vector2(depth.logical_x, depth.logical_z)
	for deck in _level.spec.decks:
		if absf(float(deck.get("height", 0.0)) - feet_h) > eps:
			continue
		if LevelSpec.point_in_poly(p, deck.poly):
			return true
	return false


## Only stand on / mount surfaces within ride_off_height_eps of feet.
func _can_mount_surface(hit: Dictionary, feet_h: float) -> bool:
	var h := float(hit.get("height", 0.0))
	return h >= feet_h - ride_off_height_eps


func _sample_underfoot() -> Dictionary:
	if _level == null:
		return {}
	var prefer_h := _feet_height()
	if _on_ramp:
		return _level.sample(
			depth.logical_x, depth.logical_z,
			_ramp_side, _ramp_lip_x, prefer_h, _ramp_base_height
		)
	return _level.sample(depth.logical_x, depth.logical_z, -1, NAN, prefer_h)


## Advance along the quarter-pipe arc. Past θ=PI/2 enters air at coping.
func _apply_ramp_friction(delta: float) -> void:
	if ramp_friction <= 0.0 or delta <= 0.0:
		return
	_ramp_along = move_toward(_ramp_along, 0.0, ramp_friction * delta)
	_velocity.x = _ramp_along


## Split along-arc speed into remaining horizontal (`along * cosθ`). Vertical is
## carried by surface height while grounded; at the lip it becomes `air_vel_y`.
func _project_ramp_velocity(theta: float) -> void:
	var c := cos(clampf(theta, 0.0, PI * 0.5))
	_velocity.x = _ramp_along * c


func _is_opposite_pipe_swap(hit: Dictionary) -> bool:
	if not _on_ramp or not _is_pipe_hit(hit):
		return false
	var hit_side := int(hit.get("side", _ramp_side))
	var their_lip := float(hit.get("lip_x", _ramp_lip_x))
	var their_r := _pipe_radius_for_hit(hit)
	return _PipeMath.opposite_coping_near(
		_ramp_side, _ramp_lip_x, _sticky_pipe_radius(),
		hit_side, their_lip, their_r,
		1.0
	)


func _sticky_pipe_radius() -> float:
	return _pipe_radius_for_hit({
		"side": _ramp_side,
		"lip_x": _ramp_lip_x,
	})


func _leave_ramp_to_flat() -> void:
	# Back on flat: full along-speed is horizontal again.
	_velocity.x = _ramp_along
	_on_ramp = false


func _move_along_pipe(hit: Dictionary, arc_speed: float, delta: float) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = _pipe_radius_for_hit(hit)
	if radius <= 0.0001:
		return
	var sign: float = _coping_sign(side)
	var signed_dx: float = arc_speed * delta
	var toward_arc: float = signed_dx * sign
	var theta: float = float(hit.get("theta", 0.0))
	var d_theta: float = toward_arc / radius
	var new_theta: float = theta + d_theta

	if new_theta >= PI * 0.5:
		# At vertical lip: all along-arc speed becomes vertical. No positional overshoot.
		var up_speed: float = maxf(arc_speed * sign, 0.0)
		_enter_air_from_pipe({
			"side": side,
			"lip_x": lip,
			"radius": radius,
			"base_height": float(hit.get("base_height", _ramp_base_height)),
		}, up_speed)
		return

	if new_theta <= 0.0:
		depth.logical_x = lip - sign * absf(new_theta) * radius
		_clamp_pose_playable()
		_leave_ramp_to_flat()
		return

	var x_off: float = radius * sin(new_theta)
	if side == QuarterPipe.PipeSide.LEFT:
		depth.logical_x = lip - x_off
	else:
		depth.logical_x = lip + x_off
	_clamp_pose_playable()


func _move_along_pipe_or_flat(arc_speed: float, delta: float) -> void:
	var hit: Dictionary = {
		"active": true,
		"zone": _pipe_zone_name(_air_side),
		"side": _air_side,
		"lip_x": _air_lip_x,
		"theta": PI * 0.5,
		"t_along_pipe": 1.0,
		"radius": _air_radius,
		"base_height": _air_base_height,
	}
	_move_along_pipe(hit, arc_speed, delta)


func _apply_surface() -> void:
	if _level == null:
		last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		depth.surface_height = 0.0
		depth.height_offset = 0.0
		depth.airborne = false
		depth.support_height = 0.0
		_clear_air()
		_refresh_head_debug()
		return

	last_surface = _sample_underfoot()
	var zone := str(last_surface.get("zone", "flat"))
	# Safety: clamping + sample fallback should make this unreachable.
	if zone == "oob":
		_clamp_pose_playable()
		last_surface = _sample_underfoot()
		zone = str(last_surface.get("zone", "flat"))
		if zone == "oob":
			last_surface = last_surface.duplicate()
			last_surface["zone"] = "flat"
			last_surface["active"] = true
			zone = "flat"

	if _airborne:
		last_surface = last_surface.duplicate()
		last_surface["zone"] = "air"
		last_surface["air_over"] = air_over
		last_surface["air_over_layer"] = _air_over_layer
		last_surface["height"] = air_abs_height
		depth.surface_height = air_abs_height
		depth.height_offset = 0.0
		depth.airborne = true
		depth.support_height = _underlying_surface_height()
	else:
		depth.height_offset = 0.0
		depth.airborne = false
		if not last_surface.get("active", true) and (zone == "oob" or zone == "hole"):
			# No standing surface — ride off instead of freezing as grounded oob.
			_try_ride_off_air(depth.surface_height)
			if _airborne:
				last_surface = last_surface.duplicate()
				last_surface["zone"] = "air"
				last_surface["air_over"] = air_over
				last_surface["air_over_layer"] = _air_over_layer
				last_surface["height"] = air_abs_height
				depth.surface_height = air_abs_height
				depth.height_offset = 0.0
				depth.airborne = true
				depth.support_height = _underlying_surface_height()
				_refresh_head_debug()
				return
			depth.support_height = depth.surface_height
		else:
			var sample_h := float(last_surface.get("height", 0.0))
			# Follow continuous support (pipe arc / flats) even when height drops
			# faster than ride_off_eps per tick. Far-below stories are handled by
			# ride-off into air before this runs — don't freeze height on the way down.
			if _on_ramp or sample_h >= depth.surface_height - ride_off_height_eps:
				depth.surface_height = sample_h
			depth.support_height = depth.surface_height

	_refresh_head_debug()


func _coping_cross_hit(from_x: float, to_x: float) -> Dictionary:
	if _level == null or is_equal_approx(from_x, to_x):
		return {}
	var prefer_h := _feet_height()
	var best := {}
	var best_base := -INF
	for pipe in _level.pipes:
		if depth.logical_z < pipe.z_min - 0.001 or depth.logical_z > pipe.z_max + 0.001:
			continue
		# Don't cross onto a pipe story far above the feet.
		if pipe.base_height > prefer_h + 1.5:
			continue
		var sign: float = _coping_sign(pipe.side)
		var from_off: float = (from_x - pipe.lip_x) * sign
		var to_off: float = (to_x - pipe.lip_x) * sign
		if from_off < pipe.radius - 0.001 and to_off >= pipe.radius - 0.001:
			if pipe.base_height >= best_base:
				best_base = pipe.base_height
				best = {
					"side": pipe.side,
					"lip_x": pipe.lip_x,
					"radius": pipe.radius,
					"base_height": pipe.base_height,
				}
	return best


## Pipe-only entry path (today). Future entries should call _begin_air_over.
## `up_speed` is along-arc speed fully converted to vertical at the lip (θ = π/2).
func _enter_air_from_pipe(hit: Dictionary, up_speed: float = 0.0) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", _pipe_radius_for_hit(hit)))
	var base_h: float = float(hit.get("base_height", _ramp_base_height))
	var coping := _coping_x_for(side, lip, radius)
	var coping_floor := base_h + radius
	_begin_air_over({
		"zone": _pipe_zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"base_height": base_h,
		"layer": int(hit.get("layer", _layer_index_for_base(base_h))),
		"lock_x": true,
		"anchor_x": coping,
	}, coping_floor, true)
	# Fully convert remaining along-speed into vertical; horiz is gone at θ = π/2.
	air_vel_y = maxf(up_speed, 0.0)
	_ramp_along = 0.0
	_velocity.x = 0.0
	_on_ramp = false


## Unlock pipe-exit X-lock into free air when rising, above coping, and INPUT
## points toward that pipe's side (MotionVectors.Kind.INPUT). Preserves height / vy.
## Spine transfer stays locked (no fly-out) until drop-in.
func _try_fly_out_from_pipe_lock() -> bool:
	if _spine_transfer_lock:
		return false
	if not _AerialMath.should_fly_out_pipe_lock(
		_air_x_locked,
		_acid_drop_lock,
		_air_side,
		air_abs_height,
		_air_coping_floor(),
		fly_out_above_coping,
		_last_input.x,
		air_vel_y,
	):
		return false
	_air_x_locked = false
	return true


## Start airborne over a target. snap_x pins to anchor immediately (pipe enter);
## false keeps current X so a transfer lerp can carry us there.
func _begin_air_over(target: Dictionary, abs_height: float, snap_x: bool = true) -> void:
	_airborne = true
	air_vel_y = 0.0
	air_over = str(target.get("zone", "flat"))
	_air_x_locked = bool(target.get("lock_x", false))
	_acid_drop_lock = false
	_spine_transfer_lock = false
	_apex_facing_done = false
	if target.has("side"):
		_air_side = int(target.side)
		_transfer_behind_sign = _coping_sign(_air_side)
	if target.has("lip_x"):
		_air_lip_x = float(target.lip_x)
	if target.has("radius"):
		_air_radius = float(target.radius)
	_air_base_height = float(target.get("base_height", 0.0))
	if target.has("layer"):
		_air_over_layer = int(target.layer)
	else:
		_air_over_layer = _layer_index_for_base(_air_base_height)
	var coping_floor := _air_coping_floor()
	if _air_x_locked:
		_air_coping_x = float(target.get("anchor_x", _coping_x_for(_air_side, _air_lip_x, _air_radius)))
		if snap_x:
			depth.logical_x = _air_coping_x
		air_abs_height = maxf(abs_height, coping_floor)
	else:
		air_abs_height = abs_height
	depth.height_offset = 0.0


func _clear_air() -> void:
	_airborne = false
	air_abs_height = 0.0
	air_vel_y = 0.0
	air_over = ""
	_air_over_layer = -1
	_air_x_locked = false
	_acid_drop_lock = false
	_spine_transfer_lock = false
	_apex_facing_done = false
	_transfer_x_active = false
	_transfer_available = true
	_acid_drop_available = true
	_last_nonzero_vert_vel = 0.0
	depth.height_offset = 0.0


## Rising, or at apex after a rise (vert≈0 but last non-zero was up).
func _transfer_vert_ok() -> bool:
	return _MotionMath.transfer_vert_ok(_vert_vel, _last_nonzero_vert_vel)


## Same button: transfer while rising/apex, acid drop while falling.
func _try_air_action() -> void:
	if _AerialMath.choose_air_action(_vert_vel, _last_nonzero_vert_vel) == _AerialMath.ACTION_TRANSFER:
		if _try_spine_transfer():
			return
		_try_transfer()
	else:
		_try_acid_drop()


func _try_acid_drop() -> void:
	if not _airborne or _level == null or not _acid_drop_available:
		return
	# Not while rising or at a rising apex — that belongs to transfer.
	if _transfer_vert_ok():
		return
	var hit := _find_acid_drop_pipe()
	if hit.is_empty():
		return

	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", 150.0))
	# Explicit top coping — never lip_x (flat / bottom edge of the quarter-pipe).
	var coping: float = float(hit.get("top_coping", _coping_x_for(side, lip, radius)))

	_air_x_locked = true
	_acid_drop_lock = true
	_air_side = side
	_air_lip_x = lip
	_air_radius = radius
	_air_base_height = float(hit.get("base_height", 0.0))
	_air_coping_x = coping
	air_over = _pipe_zone_name(side)
	_air_over_layer = int(hit.get("layer", _layer_index_for_base(_air_base_height)))
	_transfer_behind_sign = _coping_sign(side)
	# Do not touch air_abs_height or air_vel_y — only horizontal lock + existing gravity.

	_begin_transfer_x_lerp(coping, true, radius)

	_acid_drop_available = false


## Spine transfer: rising P when an opposite pipe is 0–2 deck cells behind.
## Lock X to opposite top coping; keep height / air_vel_y; land uses the same
## drop-in merge as acid / pipe-exit. Spends both charges. Returns true if fired.
func _try_spine_transfer() -> bool:
	if not _airborne or _level == null or not _transfer_available:
		return false
	if not _transfer_vert_ok():
		return false
	var behind: float = _transfer_behind_sign
	if _air_x_locked:
		behind = _coping_sign(_air_side)
	elif behind == 0.0:
		return false
	var from_x: float = _air_coping_x if _air_x_locked else depth.logical_x
	var exclude_side := _air_side
	var exclude_lip := _air_lip_x
	var cell_w := _level.cell_size_x
	if _level.spec != null and _level.spec.cell_w > 0.0:
		cell_w = _level.spec.cell_w
	var hit := _AerialMath.find_spine_transfer_target(
		_level.pipes,
		from_x,
		depth.logical_z,
		behind,
		exclude_side,
		exclude_lip,
		cell_w,
	)
	if hit.is_empty():
		return false

	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", 150.0))
	var coping: float = float(hit.get("top_coping", _coping_x_for(side, lip, radius)))

	# X-lock like acid, but not acid_drop_lock (that samples floor / blocks fly-out
	# differently). Landing drop-in is shared for all locked pipe landings.
	_air_x_locked = true
	_acid_drop_lock = false
	_spine_transfer_lock = true
	_air_side = side
	_air_lip_x = lip
	_air_radius = radius
	_air_base_height = float(hit.get("base_height", 0.0))
	_air_coping_x = coping
	air_over = _pipe_zone_name(side)
	_air_over_layer = int(hit.get("layer", _layer_index_for_base(_air_base_height)))
	_transfer_behind_sign = _coping_sign(side)

	_begin_transfer_x_lerp(coping, true, radius)

	_transfer_available = false
	_acid_drop_available = false
	return true


## Nearest opposite-facing TOP coping near horizontal velocity.
## Moving right → left_pipe only; moving left → right_pipe only.
## Buffer/max_ahead are logical X units (same as depth.logical_x), not screen pixels.
func _find_acid_drop_pipe() -> Dictionary:
	if _level == null:
		return {}
	var hx := _AerialMath.resolve_horiz_vel(_actual_vel_x, _velocity.x)
	return _AerialMath.find_acid_drop_target(
		_level.pipes,
		depth.logical_x,
		depth.logical_z,
		hx,
		acid_drop_buffer,
		acid_drop_max_ahead
	)


func _try_transfer() -> void:
	if not _airborne or _level == null or not _transfer_available:
		return
	# Rising, or apex after rise (vert≈0 with last non-zero up).
	if not _transfer_vert_ok():
		return
	var was_locked := _air_x_locked
	var behind: float = _transfer_behind_sign
	if _air_x_locked:
		behind = _coping_sign(_air_side)
	elif behind == 0.0:
		return
	var probe_from_x: float = _air_coping_x if _air_x_locked else depth.logical_x
	var probe_x: float = probe_from_x + behind * transfer_probe
	var exclude_side := _air_side
	var exclude_lip := _air_lip_x
	var hit: Dictionary = _level.sample_transfer(
		probe_x, depth.logical_z, exclude_side, exclude_lip, air_abs_height
	)
	# Tight spine / gap: probe may land on flat between facing copings — pick the
	# nearest opposite pipe in the behind direction when no deck claimed the spot.
	if not _is_pipe_hit(hit) and str(hit.get("zone", "")) != "deck":
		var pipe_hit := _find_pipe_behind(probe_from_x, behind, exclude_side, exclude_lip)
		if not pipe_hit.is_empty():
			hit = pipe_hit
	var zone := str(hit.get("zone", "flat"))
	var keep_h := air_abs_height
	var from_x := depth.logical_x
	var anchor_x := probe_x
	var target := {"zone": zone, "lock_x": false, "anchor_x": probe_x}

	if _is_pipe_hit(hit):
		var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
		var lip: float = float(hit.get("lip_x", probe_x))
		var radius: float = _pipe_radius_for_hit(hit)
		var coping := _coping_x_for(side, lip, radius)
		# Transfer is not a pipe-coping exit — stay unlocked so gravity applies.
		target = {
			"zone": _pipe_zone_name(side),
			"side": side,
			"lip_x": lip,
			"radius": radius,
			"base_height": float(hit.get("base_height", 0.0)),
			"layer": int(hit.get("layer", -1)),
			"lock_x": false,
			"anchor_x": coping,
		}
		anchor_x = coping
	elif zone == "deck":
		target = {
			"zone": "deck",
			"lock_x": false,
			"anchor_x": probe_x,
			"layer": int(hit.get("layer", -1)),
			"base_height": float(hit.get("base_height", 0.0)),
		}
	else:
		target = {
			"zone": "flat",
			"lock_x": false,
			"anchor_x": probe_x,
			"layer": int(hit.get("layer", -1)),
			"base_height": float(hit.get("height", 0.0)),
		}

	_begin_air_over(target, keep_h, false)
	_transfer_available = false

	# Locked pipe air spent stick X on height — release it as free-air horizontal.
	if was_locked:
		_velocity.x = behind * maxf(absf(_velocity.x), transfer_release_min)
		_transfer_x_active = false
		return

	_begin_transfer_x_lerp(anchor_x, false)
	if not _transfer_x_active and _air_x_locked:
		depth.logical_x = _air_coping_x


## Nearest other pipe whose coping lies behind us (spine / back-to-back).
func _find_pipe_behind(
	from_x: float, behind: float, exclude_side: int, exclude_lip_x: float
) -> Dictionary:
	if _level == null:
		return {}
	return _AerialMath.find_pipe_behind(
		_level.pipes, from_x, depth.logical_z, behind, exclude_side, exclude_lip_x
	)


func _coping_x_for(side: int, lip_x: float, radius: float) -> float:
	return _PipeMath.coping_x(side, lip_x, radius)


func _pipe_radius_for_hit(hit: Dictionary) -> float:
	if hit.has("radius") and float(hit.radius) > 0.0:
		return float(hit.radius)
	var lip := float(hit.get("lip_x", 0.0))
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	if _level:
		for pipe in _level.pipes:
			if pipe.side == side and absf(pipe.lip_x - lip) < 0.05:
				return pipe.radius
	return 150.0


func _is_pipe_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	if not hit.get("active", true) and not hit.has("zone"):
		return false
	var zone := str(hit.get("zone", ""))
	return zone == "left_pipe" or zone == "right_pipe"


func _coping_sign(side: int) -> float:
	return _PipeMath.coping_sign(side)


func _pipe_zone_name(side: int) -> String:
	return _PipeMath.zone_name(side)


func zone_debug_label() -> String:
	var zone := str(last_surface.get("zone", "flat"))
	if zone == "air":
		var over := air_over
		if over == "" and last_surface.has("air_over"):
			over = str(last_surface.air_over)
		var layer := _air_over_layer
		if layer < 0 and last_surface.has("air_over_layer"):
			layer = int(last_surface.air_over_layer)
		if over != "":
			if layer >= 0:
				zone = "air (over %s L%d)" % [over, layer]
			else:
				zone = "air (over %s)" % over
		else:
			zone = "air"
	else:
		var layer_g := _layer_from_surface(last_surface)
		if layer_g >= 0:
			zone = "%s L%d" % [zone, layer_g]
	return "%s\nhd %s" % [zone, facing_h]


## Layer index for a grounded/air sample hit.
func _layer_from_surface(surf: Dictionary) -> int:
	if surf.has("layer") and int(surf.layer) >= 0:
		return int(surf.layer)
	if surf.has("base_height"):
		return _layer_index_for_base(float(surf.base_height))
	if surf.has("height"):
		return _layer_index_for_base(float(surf.height))
	return -1


## Map a story base_height to .ssk layer index when hits omit `layer`.
func _layer_index_for_base(base_h: float) -> int:
	if _level == null or _level.spec == null:
		return -1
	for L in _level.spec.layers:
		if absf(float(L.get("height", 0.0)) - base_h) <= 0.5:
			return int(L.get("index", -1))
	return -1


## Logical XZ for cell queries (targeting / highlight / HUD). While X-locked on
## a pipe coping, nudges X into the pipe — see LevelSpec.cell_at_for_pose.
func cell_sample_xz() -> Vector2:
	var x := depth.logical_x
	var z := depth.logical_z
	if _airborne and _air_x_locked and (air_over == "left_pipe" or air_over == "right_pipe"):
		x = _PipeMath.pose_x_for_cell_query(x, _air_side)
	return Vector2(x, z)


## Cell under feet for targeting / debug (uses LevelSpec when available).
func cell_under_feet() -> Vector2i:
	if _level == null or _level.spec == null:
		return Vector2i.ZERO
	return _level.spec.cell_at_for_pose(
		depth.logical_x,
		depth.logical_z,
		_airborne and _air_x_locked,
		air_over,
		_air_side,
	)


func _normalize_facing(raw: String) -> String:
	return _MotionMath.normalize_facing(raw)


func _update_facing_h(input: Vector2) -> void:
	# Facing follows along-speed on ramps (not the cos-projected remnant).
	var horiz := _ramp_along if _on_ramp else _velocity.x
	if absf(horiz) >= 8.0:
		facing_h = "r" if horiz > 0.0 else "l"
		return
	if absf(_actual_vel_x) >= 8.0:
		facing_h = "r" if _actual_vel_x > 0.0 else "l"
		return
	if absf(input.x) >= 0.15:
		facing_h = "r" if input.x > 0.0 else "l"


## At vertical apex while X-locked over a pipe: flip facing, unless stick
## holds a horizontal direction (then face that way). Once per aerial.
func _try_apex_facing_flip(prev_air_vy: float) -> void:
	if _apex_facing_done or not _air_x_locked:
		return
	if prev_air_vy <= 0.0 or air_vel_y > 0.0:
		return
	_apex_facing_done = true
	var ix := Input.get_axis("move_left", "move_right")
	if absf(ix) >= 0.15:
		facing_h = "r" if ix > 0.0 else "l"
	else:
		facing_h = "l" if facing_h == "r" else "r"
	_update_face_nose()


func _update_face_nose() -> void:
	if _face_nose == null:
		return
	# Sit on the facing side of the body silhouette.
	var side := 1.0 if facing_h == "r" else -1.0
	_face_nose.position = Vector2(22.0 * side, -40.0)


## Screen-local vector for a [MotionVectors.Kind] (+X right, -Y up on screen).
## Prefer this over kind-specific helpers when branching in gameplay/debug code.
func motion_screen(kind: _MotionVectors.Kind) -> Vector2:
	match kind:
		_MotionVectors.Kind.ACTUAL:
			# +logical Z (farther) → up; +vertical (rising) → up.
			return Vector2(_actual_vel_x, -_actual_vel_z - _vert_vel)
		_MotionVectors.Kind.MOMENTUM:
			if _on_ramp:
				# Horiz remnant + converted vertical so the split is visible.
				var th := 0.0
				if last_surface.has("theta"):
					th = float(last_surface.theta)
				var sign := 1.0
				if last_surface.has("side"):
					sign = _coping_sign(int(last_surface.side))
				var toward := _ramp_along * sign
				var horiz := _ramp_along * cos(clampf(th, 0.0, PI * 0.5))
				var vert := toward * sin(clampf(th, 0.0, PI * 0.5))
				return Vector2(horiz, -vert)
			# Flat: X + depth Z (_velocity.y is logical Z, not height).
			return Vector2(_velocity.x, -_velocity.y)
		_MotionVectors.Kind.INPUT:
			# Planar wish only — never height (player cannot steer Y).
			return Vector2(_last_input.x * max_speed_x, -_last_input.y * max_speed_z)
	return Vector2.ZERO


func motion_speed(kind: _MotionVectors.Kind) -> float:
	match kind:
		_MotionVectors.Kind.ACTUAL:
			return Vector3(_actual_vel_x, _vert_vel, _actual_vel_z).length()
		_MotionVectors.Kind.MOMENTUM:
			return _velocity.length()
		_MotionVectors.Kind.INPUT:
			return Vector2(_last_input.x * max_speed_x, _last_input.y * max_speed_z).length()
	return 0.0


## Instantaneous control acceleration from last integrate (u/s²).
func debug_accel_screen() -> Vector2:
	return Vector2(_debug_accel.x, -_debug_accel.y)


func debug_accel_mag() -> float:
	return _debug_accel.length()


func _refresh_head_debug() -> void:
	if _head_debug_label == null:
		return
	_head_debug_label.text = zone_debug_label()


func _read_move_input() -> Vector2:
	var x := Input.get_axis("move_left", "move_right")
	var z := Input.get_axis("move_down", "move_up")
	var v := Vector2(x, z)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _integrate_velocity(input: Vector2, delta: float) -> void:
	var before := _velocity
	var holding_ollie := Input.is_action_pressed("ollie")
	var step := acceleration * delta
	var friction_step := friction * delta
	var brake_step := brake * delta

	# Horizontal X: opposite stick brakes hard to zero (no reverse until stopped).
	_velocity.x = _integrate_axis_no_reverse(
		_velocity.x,
		input.x * max_speed_x,
		step,
		friction_step,
		brake_step,
		holding_ollie and input.x == 0.0,
	)

	# Depth Z: immediate — snap to stick (no accel / friction ramp).
	_velocity.y = input.y * max_speed_z

	# Hold ollie: mild forward thrust in facing direction (THPS charge feel).
	# Skip when stick is already braking opposite to motion.
	if holding_ollie:
		var face := 1.0 if facing_h == "r" else -1.0
		var stick_opposes := absf(input.x) >= 0.15 and input.x * face < 0.0
		if not stick_opposes:
			_velocity.x = move_toward(_velocity.x, face * max_speed_x, ollie_accel * delta)

	if delta > 0.0001:
		_debug_accel = (_velocity - before) / delta
	else:
		_debug_accel = Vector2.ZERO


## Move `current` toward `want`. Opposite stick uses `brake_step` (no reverse until
## stopped). Coast uses `friction_step`. Acceleration never decelerates.
func _integrate_axis_no_reverse(
	current: float,
	want: float,
	accel_step: float,
	friction_step: float,
	brake_step: float,
	skip_friction: bool,
) -> float:
	return _MotionMath.integrate_axis_no_reverse(
		current, want, accel_step, friction_step, brake_step, skip_friction
	)
