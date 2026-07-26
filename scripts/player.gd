extends Node2D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## Air over any zone. Coping exit locks X (gravity applies); acid drop locks X only.
## Ride-off a higher surface → free air (keep height + gravity). All sim on physics ticks.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")

@export var max_speed_x: float = 880.0

@export var max_speed_z: float = 335.0
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
## Physics-time duration for acid-drop horizontal settle to coping.
@export var acid_drop_x_duration: float = 0.15
## God-mode vertical speed (logical units/s) for j/k. Debug only.
@export var god_vert_speed: float = 320.0
## Along-arc speed drain while on a pipe (logical u/s²). Debug slider writes this.
@export var ramp_friction: float = 0.0
## Pipe-exit X-lock fly-out: unlock into free air this far above coping (logical).
## Intent must point toward that pipe's side. Debug slider writes this.
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
var _level: RampLevel
var last_surface: Dictionary = {}

var _airborne: bool = false
## Absolute logical feet height while airborne.
var air_abs_height: float = 0.0
## Vertical velocity while airborne (logic units/s); used for gravity.
var air_vel_y: float = 0.0
## Zone underneath while airborne (left_pipe / right_pipe / deck / flat).
var air_over: String = ""
var _air_x_locked: bool = false
var _air_side: int = QuarterPipe.PipeSide.RIGHT
var _air_lip_x: float = 0.0
var _air_coping_x: float = 0.0
var _air_radius: float = 150.0
## Last behind-sign used for transfer probes when unlocked.
var _transfer_behind_sign: float = 1.0

var _transfer_x_active: bool = false
var _transfer_x_from: float = 0.0
var _transfer_x_to: float = 0.0
var _transfer_x_t: float = 0.0
## One transfer per aerial; replenished on any surface contact.
var _transfer_available: bool = true
## One acid drop per aerial; replenished on any surface contact.
var _acid_drop_available: bool = true
## X-locked via acid drop: pin to coping; gravity continues (same as coping lock).
var _acid_drop_lock: bool = false
## Once per locked aerial: facing flip (or stick override) at vertical apex.
var _apex_facing_done: bool = false
## Measured actual velocity from position deltas (not stick intent).
var _actual_vel_x: float = 0.0
var _actual_vel_z: float = 0.0
var _vert_vel: float = 0.0
## Last non-zero measured vertical rate (for apex: vert==0 but still "rising").
var _last_nonzero_vert_vel: float = 0.0
var _prev_logical_x: float = 0.0
var _prev_logical_z: float = 0.0
var _prev_feet_h: float = 0.0
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
	depth.apply()


func _feet_height() -> float:
	if _airborne:
		return air_abs_height
	return depth.surface_height


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


func _apply_motion(delta: float, speed_mul: float) -> void:
	if _airborne:
		_update_air_over_underfoot()
		_step_transfer_x(delta)

		if _air_x_locked:
			# Don't pin X while a transfer/acid-drop lerp is carrying us to coping.
			if not _transfer_x_active:
				depth.logical_x = _air_coping_x
			depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)

			# God mode over a coping lock: keep X pin, free height via j/k.
			if DebugTools.god_mode:
				air_vel_y = 0.0
				return

			# Horiz-locked air (pipe exit or acid drop): gravity always applies.
			var prev_air_vy := air_vel_y
			_integrate_air_gravity(delta)
			_try_apex_facing_flip(prev_air_vy)
			# Intent toward pipe side + height above coping → unlock; keep air_vel_y
			# so free air continues on a parabola. Gravity already ran this tick.
			if _try_fly_out_from_pipe_lock():
				if not _transfer_x_active:
					depth.logical_x += _velocity.x * speed_mul * delta
				return
			var floor_h := _underlying_surface_height()
			# Only land when falling onto the surface — never snap height upward.
			if air_vel_y <= 0.0 and air_abs_height <= floor_h + 0.05:
				air_abs_height = floor_h
				var was_acid := _acid_drop_lock
				var pin_x := _air_coping_x
				var side_sign := _coping_sign(_air_side)
				var land_vy := air_vel_y
				_clear_air()
				# Pipe-exit lock: falling vert at the lip fully converts back into along-arc.
				if not was_acid:
					if land_vy < 0.0:
						_ramp_along = land_vy * side_sign
						_velocity.x = _ramp_along
						_on_ramp = true
						_ramp_side = _air_side
						_ramp_lip_x = _air_lip_x
					if _ramp_along * side_sign < -1.0:
						_move_along_pipe_or_flat(_ramp_along * speed_mul, delta)
					else:
						depth.logical_x = pin_x
			return

		# Unlocked air (rode off / transfer / fly-out / over any zone): free XZ + gravity.
		# Position lerp owns X while active — don't also integrate velocity.x.
		if not _transfer_x_active:
			depth.logical_x += _velocity.x * speed_mul * delta
		depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)
		if _air_over_uses_gravity():
			_integrate_air_gravity(delta)
		var floor_h := _underlying_surface_height()
		if air_abs_height <= floor_h + 0.05:
			air_abs_height = floor_h
			_clear_air()
		return

	var prev_support_h := depth.surface_height
	depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)

	var hit: Dictionary = _sample_underfoot()
	if _is_pipe_hit(hit):
		# If sticky pipe lost us onto an opposite neighbor at shared coping, launch
		# instead of flipping walls mid-ride.
		if _on_ramp and _is_opposite_pipe_swap(hit):
			var up_speed: float = maxf(_velocity.x * _coping_sign(_ramp_side), 0.0)
			_enter_air_from_pipe({
				"side": _ramp_side,
				"lip_x": _ramp_lip_x,
				"radius": _sticky_pipe_radius(),
			}, up_speed)
			return
		if not _on_ramp:
			_ramp_along = _velocity.x
			_on_ramp = true
		_ramp_side = int(hit.get("side", _ramp_side))
		_ramp_lip_x = float(hit.get("lip_x", _ramp_lip_x))
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
				_project_ramp_velocity(float(after.get("theta", 0.0)))
			elif _is_pipe_hit(after) and _is_opposite_pipe_swap(after):
				var up_speed2: float = maxf(_ramp_along * _coping_sign(_ramp_side), 0.0)
				_enter_air_from_pipe({
					"side": _ramp_side,
					"lip_x": _ramp_lip_x,
					"radius": _sticky_pipe_radius(),
				}, up_speed2)
			else:
				_leave_ramp_to_flat()
		return

	if _on_ramp:
		_leave_ramp_to_flat()
	var arc_speed := _velocity.x * speed_mul
	var next_x: float = depth.logical_x + arc_speed * delta
	var cross := _coping_cross_hit(depth.logical_x, next_x)
	if not cross.is_empty():
		var side: int = int(cross.side)
		var up_speed: float = maxf(arc_speed * _coping_sign(side), 0.0)
		_enter_air_from_pipe(cross, up_speed)
		return
	depth.logical_x = next_x
	_try_ride_off_air(prev_support_h)


func _step_transfer_x(delta: float) -> void:
	if not _transfer_x_active:
		return
	_transfer_x_t += delta
	var duration := transfer_x_duration
	if _acid_drop_lock:
		duration = acid_drop_x_duration
	var u := 1.0
	if duration > 0.0001:
		u = clampf(_transfer_x_t / duration, 0.0, 1.0)
	depth.logical_x = lerpf(_transfer_x_from, _transfer_x_to, u)
	if u >= 1.0:
		_transfer_x_active = false
		depth.logical_x = _transfer_x_to


func _update_air_over_underfoot() -> void:
	if _level == null:
		return
	# Keep transfer target zone until X settle finishes.
	if _transfer_x_active:
		return
	# Locked on a pipe coping: don't re-sample. Adjacent opposite pipes often share
	# the coping X, and sample() would flip us back to the neighbor.
	if _air_x_locked:
		return
	var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z)
	var zone := str(under.get("zone", "flat"))
	if zone == "oob":
		zone = "flat"
	air_over = zone
	if _is_pipe_hit(under):
		_air_side = int(under.get("side", _air_side))
		_air_lip_x = float(under.get("lip_x", _air_lip_x))
		_air_radius = _pipe_radius_for_hit(under)
		_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
		_transfer_behind_sign = _coping_sign(_air_side)
	# Never auto-lock X from sampling — only pipe-coping entry locks.


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
		var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z) if _level else {}
		var zone := str(under.get("zone", "flat"))
		if zone == "oob":
			zone = "flat"
		var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
		if _is_pipe_hit(under):
			target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
			target["lip_x"] = float(under.get("lip_x", depth.logical_x))
			target["radius"] = _pipe_radius_for_hit(under)
		_begin_air_over(target, depth.surface_height, false)
		air_vel_y = 0.0
	air_abs_height += v * god_vert_speed * delta
	air_vel_y = 0.0
	var floor_h := _underlying_surface_height()
	if air_abs_height <= floor_h + 0.05:
		air_abs_height = floor_h
		_clear_air()


func _underlying_surface_height() -> float:
	# Pipe-exit X-lock may use coping radius; acid drop / free air sample real surface.
	var sampled := 0.0
	if _level != null:
		var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z)
		if under.get("active", true) or str(under.get("zone", "")) != "oob":
			sampled = float(under.get("height", 0.0))
	return _AerialMath.landing_support_height(
		_air_x_locked, _acid_drop_lock, air_over, _air_radius, sampled
	)


## Leave a higher support surface into free air (keep height, apply gravity).
func _try_ride_off_air(prev_support_h: float) -> void:
	if _airborne or _level == null:
		return
	var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z)
	var new_h := 0.0
	if under.get("active", true) or str(under.get("zone", "")) != "oob":
		new_h = float(under.get("height", 0.0))
	if new_h >= prev_support_h - ride_off_height_eps:
		return
	var zone := str(under.get("zone", "flat"))
	if zone == "oob":
		zone = "flat"
	var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
	if _is_pipe_hit(under):
		target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
		target["lip_x"] = float(under.get("lip_x", depth.logical_x))
		target["radius"] = _pipe_radius_for_hit(under)
	_begin_air_over(target, prev_support_h, false)


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


func _sample_underfoot() -> Dictionary:
	if _level == null:
		return {}
	if _on_ramp:
		return _level.sample(depth.logical_x, depth.logical_z, _ramp_side, _ramp_lip_x)
	return _level.sample(depth.logical_x, depth.logical_z)


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
		}, up_speed)
		return

	if new_theta <= 0.0:
		depth.logical_x = lip - sign * absf(new_theta) * radius
		_leave_ramp_to_flat()
		return

	var x_off: float = radius * sin(new_theta)
	if side == QuarterPipe.PipeSide.LEFT:
		depth.logical_x = lip - x_off
	else:
		depth.logical_x = lip + x_off


func _move_along_pipe_or_flat(arc_speed: float, delta: float) -> void:
	var hit: Dictionary = {
		"active": true,
		"zone": _pipe_zone_name(_air_side),
		"side": _air_side,
		"lip_x": _air_lip_x,
		"theta": PI * 0.5,
		"t_along_pipe": 1.0,
		"radius": _air_radius,
	}
	_move_along_pipe(hit, arc_speed, delta)


func _apply_surface() -> void:
	if _level == null:
		last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		depth.surface_height = 0.0
		depth.height_offset = 0.0
		_clear_air()
		_refresh_head_debug()
		return

	last_surface = _sample_underfoot()
	var zone := str(last_surface.get("zone", "flat"))

	if _airborne:
		last_surface = last_surface.duplicate()
		last_surface["zone"] = "air"
		last_surface["air_over"] = air_over
		last_surface["height"] = air_abs_height
		depth.surface_height = air_abs_height
		depth.height_offset = 0.0
	else:
		depth.height_offset = 0.0
		if not last_surface.get("active", true) and zone == "oob":
			depth.surface_height = 0.0
		else:
			depth.surface_height = float(last_surface.get("height", 0.0))

	_refresh_head_debug()


func _coping_cross_hit(from_x: float, to_x: float) -> Dictionary:
	if _level == null or is_equal_approx(from_x, to_x):
		return {}
	for pipe in _level.pipes:
		if depth.logical_z < pipe.z_min - 0.001 or depth.logical_z > pipe.z_max + 0.001:
			continue
		var sign: float = _coping_sign(pipe.side)
		var from_off: float = (from_x - pipe.lip_x) * sign
		var to_off: float = (to_x - pipe.lip_x) * sign
		if from_off < pipe.radius - 0.001 and to_off >= pipe.radius - 0.001:
			return {
				"side": pipe.side,
				"lip_x": pipe.lip_x,
				"radius": pipe.radius,
			}
	return {}


## Pipe-only entry path (today). Future entries should call _begin_air_over.
## `up_speed` is along-arc speed fully converted to vertical at the lip (θ = π/2).
func _enter_air_from_pipe(hit: Dictionary, up_speed: float = 0.0) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", _pipe_radius_for_hit(hit)))
	var coping := _coping_x_for(side, lip, radius)
	_begin_air_over({
		"zone": _pipe_zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"lock_x": true,
		"anchor_x": coping,
	}, radius, true)
	# Fully convert remaining along-speed into vertical; horiz is gone at θ = π/2.
	air_vel_y = maxf(up_speed, 0.0)
	_ramp_along = 0.0
	_velocity.x = 0.0
	_on_ramp = false


## Unlock pipe-exit X-lock into free air when above coping and intent points
## toward that pipe's side. Preserves `air_abs_height` / `air_vel_y` (parabolic).
func _try_fly_out_from_pipe_lock() -> bool:
	if not _AerialMath.should_fly_out_pipe_lock(
		_air_x_locked,
		_acid_drop_lock,
		_air_side,
		air_abs_height,
		_air_radius,
		fly_out_above_coping,
		_velocity.x,
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
	_apex_facing_done = false
	if target.has("side"):
		_air_side = int(target.side)
		_transfer_behind_sign = _coping_sign(_air_side)
	if target.has("lip_x"):
		_air_lip_x = float(target.lip_x)
	if target.has("radius"):
		_air_radius = float(target.radius)
	if _air_x_locked:
		_air_coping_x = float(target.get("anchor_x", _coping_x_for(_air_side, _air_lip_x, _air_radius)))
		if snap_x:
			depth.logical_x = _air_coping_x
		air_abs_height = maxf(abs_height, _air_radius)
	else:
		air_abs_height = abs_height
	depth.height_offset = 0.0


func _clear_air() -> void:
	_airborne = false
	air_abs_height = 0.0
	air_vel_y = 0.0
	air_over = ""
	_air_x_locked = false
	_acid_drop_lock = false
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
	_air_coping_x = coping
	air_over = _pipe_zone_name(side)
	_transfer_behind_sign = _coping_sign(side)
	# Do not touch air_abs_height or air_vel_y — only horizontal lock + existing gravity.

	_transfer_x_from = depth.logical_x
	_transfer_x_to = coping
	_transfer_x_t = 0.0
	_transfer_x_active = absf(coping - depth.logical_x) > 0.05
	if not _transfer_x_active:
		depth.logical_x = coping

	_acid_drop_available = false


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
		probe_x, depth.logical_z, exclude_side, exclude_lip
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
			"lock_x": false,
			"anchor_x": coping,
		}
		anchor_x = coping
	elif zone == "deck":
		target = {"zone": "deck", "lock_x": false, "anchor_x": probe_x}
	else:
		target = {"zone": "flat", "lock_x": false, "anchor_x": probe_x}

	_begin_air_over(target, keep_h, false)
	_transfer_available = false

	# Locked pipe air spent stick X on height — release it as free-air horizontal.
	if was_locked:
		_velocity.x = behind * maxf(absf(_velocity.x), transfer_release_min)
		_transfer_x_active = false
		return

	_transfer_x_from = from_x
	_transfer_x_to = anchor_x
	_transfer_x_t = 0.0
	_transfer_x_active = absf(anchor_x - from_x) > 0.05
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
		if over != "":
			zone = "air (over %s)" % over
		else:
			zone = "air"
	return "%s\nhd %s" % [zone, facing_h]


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


## Screen-local velocity for the head debug arrow (+X right, -Y up).
## Uses measured position rates, not stick intent (_velocity).
func debug_velocity_screen() -> Vector2:
	# +logical Z (farther) → up on screen; +vertical (rising) → up on screen.
	return Vector2(_actual_vel_x, -_actual_vel_z - _vert_vel)


func debug_velocity_speed() -> float:
	return Vector3(_actual_vel_x, _vert_vel, _actual_vel_z).length()


## Stick-intent velocity (integrated every tick). On a ramp, orange shows the
## remaining horizontal remnant (`along * cosθ`); green actual includes vertical.
func debug_intent_screen() -> Vector2:
	if _on_ramp:
		# Show horiz remnant + converted vertical so the split is visible.
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
	return Vector2(_velocity.x, -_velocity.y)


func debug_intent_speed() -> float:
	return _velocity.length()


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
