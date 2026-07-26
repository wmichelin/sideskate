extends Node2D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## Air can be over any zone; enter air currently only from pipes. All sim on physics ticks.

@export var max_speed_x: float = 520.0
@export var max_speed_z: float = 260.0
@export var acceleration: float = 2200.0
@export var friction: float = 2400.0
@export var depth_speed_feel: bool = true
@export var level_path: NodePath = NodePath("../RampLevel")
## How far past the coping to probe for transfer targets.
@export var transfer_probe: float = 8.0
## Physics-time duration for transfer horizontal settle.
@export var transfer_x_duration: float = 0.15
## Gravity while air over deck/flat (m/s²). Debug slider writes this.
@export var gravity_ms2: float = -9.8
## Convert m/s² into logical units/s².
@export var logic_per_meter: float = 100.0
## Cap how high above a pipe coping you can climb with input.
@export var pipe_air_max_extra: float = 2.0

@onready var depth: PseudoDepthBody = $PseudoDepthBody
@onready var _head_debug_label: Label = $Body/HeadDebug/Label

var _velocity: Vector2 = Vector2.ZERO
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


func _ready() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	call_deferred("_spawn_from_level")


func _spawn_from_level() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level and _level.spec:
		depth.logical_x = _level.spec.spawn_x
		depth.logical_z = _level.spec.spawn_z
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	else:
		depth.logical_x = 640.0
		depth.logical_z = 40.0
	_clear_air()
	_apply_surface()
	depth.apply()


func _physics_process(delta: float) -> void:
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel

	if Input.is_action_just_pressed("transfer"):
		_try_transfer()

	var input := _read_move_input()
	_integrate_velocity(input, delta)

	var speed_mul := depth.depth_speed_multiplier() if depth_speed_feel else 1.0
	_apply_motion(delta, speed_mul)

	if _level:
		depth.logical_x = clampf(depth.logical_x, _level.x_min(), _level.x_max())
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	else:
		depth.logical_x = clampf(depth.logical_x, 80.0, 1200.0)

	_apply_surface()
	depth.apply()


func _apply_motion(delta: float, speed_mul: float) -> void:
	if _airborne:
		_update_air_over_underfoot()
		_step_transfer_x(delta)

		if _air_x_locked:
			depth.logical_x = _air_coping_x
			depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)
			var toward: float = _velocity.x * speed_mul * _coping_sign(_air_side)
			var coping_h := _air_radius
			var max_h := coping_h + maxf(_air_radius * pipe_air_max_extra, 1.0)
			air_abs_height = clampf(air_abs_height + toward * delta, coping_h, max_h)
			air_vel_y = 0.0
			if air_abs_height <= coping_h + 0.001 and toward <= 1.0:
				_clear_air()
				if toward < -1.0:
					_move_along_pipe_or_flat(toward * delta)
				else:
					depth.logical_x = _air_coping_x
			return

		# Unlocked air (deck / flat underneath): free XZ + gravity.
		depth.logical_x += _velocity.x * speed_mul * delta
		depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)
		if _air_over_uses_gravity():
			air_vel_y += gravity_ms2 * logic_per_meter * delta
			air_abs_height += air_vel_y * delta
		var floor_h := _underlying_surface_height()
		if air_abs_height <= floor_h + 0.05:
			air_abs_height = floor_h
			_clear_air()
		return

	depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)
	var arc_speed := _velocity.x * speed_mul

	var hit: Dictionary = _level.sample(depth.logical_x, depth.logical_z) if _level else {}
	if _is_pipe_hit(hit):
		_move_along_pipe(hit, arc_speed * delta)
		return

	var next_x: float = depth.logical_x + arc_speed * delta
	var cross := _coping_cross_hit(depth.logical_x, next_x)
	if not cross.is_empty():
		var overshoot: float = (next_x - _coping_x_for(
			int(cross.side), float(cross.lip_x), float(cross.radius)
		)) * _coping_sign(int(cross.side))
		_enter_air_from_pipe(cross, maxf(overshoot, 0.0))
		return
	depth.logical_x = next_x


func _step_transfer_x(delta: float) -> void:
	if not _transfer_x_active:
		return
	_transfer_x_t += delta
	var u := 1.0
	if transfer_x_duration > 0.0001:
		u = clampf(_transfer_x_t / transfer_x_duration, 0.0, 1.0)
	depth.logical_x = lerpf(_transfer_x_from, _transfer_x_to, u)
	if u >= 1.0:
		_transfer_x_active = false
		depth.logical_x = _transfer_x_to


func _update_air_over_underfoot() -> void:
	if _level == null:
		return
	# Keep transfer target zone until X settle finishes (coping sample would re-lock).
	if _transfer_x_active:
		return
	var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z)
	var zone := str(under.get("zone", "flat"))
	if zone == "oob":
		zone = "flat"
	if _is_pipe_hit(under):
		air_over = zone
		_air_side = int(under.get("side", _air_side))
		_air_lip_x = float(under.get("lip_x", _air_lip_x))
		_air_radius = _pipe_radius_for_hit(under)
		_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
		_air_x_locked = true
		_transfer_behind_sign = _coping_sign(_air_side)
	elif zone == "deck" or zone == "flat":
		air_over = zone
		_air_x_locked = false
	else:
		air_over = zone
		_air_x_locked = false


func _air_over_uses_gravity() -> bool:
	return air_over == "deck" or air_over == "flat"


func _underlying_surface_height() -> float:
	if air_over == "left_pipe" or air_over == "right_pipe":
		return _air_radius
	if air_over == "deck" and _level:
		var under: Dictionary = _level.sample(depth.logical_x, depth.logical_z)
		if str(under.get("zone", "")) == "deck":
			return float(under.get("height", 0.0))
	return 0.0


## Advance along the quarter-pipe arc. Past θ=PI/2 enters air at coping.
func _move_along_pipe(hit: Dictionary, signed_dx: float) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = _pipe_radius_for_hit(hit)
	if radius <= 0.0001:
		return
	var sign: float = _coping_sign(side)
	var toward_arc: float = signed_dx * sign
	var theta: float = float(hit.get("theta", 0.0))
	var d_theta: float = toward_arc / radius
	var new_theta: float = theta + d_theta

	if new_theta >= PI * 0.5:
		var extra: float = (new_theta - PI * 0.5) * radius
		_enter_air_from_pipe({
			"side": side,
			"lip_x": lip,
			"radius": radius,
		}, extra)
		return

	if new_theta <= 0.0:
		depth.logical_x = lip - sign * absf(new_theta) * radius
		return

	var x_off: float = radius * sin(new_theta)
	if side == QuarterPipe.PipeSide.LEFT:
		depth.logical_x = lip - x_off
	else:
		depth.logical_x = lip + x_off


func _move_along_pipe_or_flat(signed_toward_arc: float) -> void:
	var hit: Dictionary = {
		"active": true,
		"zone": _pipe_zone_name(_air_side),
		"side": _air_side,
		"lip_x": _air_lip_x,
		"theta": PI * 0.5,
		"t_along_pipe": 1.0,
		"radius": _air_radius,
	}
	_move_along_pipe(hit, signed_toward_arc * _coping_sign(_air_side))


func _apply_surface() -> void:
	if _level == null:
		last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		depth.surface_height = 0.0
		depth.height_offset = 0.0
		_clear_air()
		_refresh_head_debug()
		return

	last_surface = _level.sample(depth.logical_x, depth.logical_z)
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
func _enter_air_from_pipe(hit: Dictionary, extra_height: float = 0.0) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", _pipe_radius_for_hit(hit)))
	var coping := _coping_x_for(side, lip, radius)
	var abs_h := radius + maxf(extra_height, 0.0)
	_begin_air_over({
		"zone": _pipe_zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"lock_x": true,
		"anchor_x": coping,
	}, abs_h)


func _begin_air_over(target: Dictionary, abs_height: float) -> void:
	_airborne = true
	air_vel_y = 0.0
	air_over = str(target.get("zone", "flat"))
	_air_x_locked = bool(target.get("lock_x", false))
	if target.has("side"):
		_air_side = int(target.side)
		_transfer_behind_sign = _coping_sign(_air_side)
	if target.has("lip_x"):
		_air_lip_x = float(target.lip_x)
	if target.has("radius"):
		_air_radius = float(target.radius)
	if _air_x_locked:
		_air_coping_x = float(target.get("anchor_x", _coping_x_for(_air_side, _air_lip_x, _air_radius)))
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
	_transfer_x_active = false
	depth.height_offset = 0.0


func _try_transfer() -> void:
	if not _airborne or _level == null:
		return
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
	var zone := str(hit.get("zone", "flat"))
	var keep_h := air_abs_height
	var anchor_x := probe_x
	var target := {"zone": zone, "lock_x": false, "anchor_x": probe_x}

	if _is_pipe_hit(hit):
		var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
		var lip: float = float(hit.get("lip_x", probe_x))
		var radius: float = _pipe_radius_for_hit(hit)
		var coping := _coping_x_for(side, lip, radius)
		target = {
			"zone": _pipe_zone_name(side),
			"side": side,
			"lip_x": lip,
			"radius": radius,
			"lock_x": true,
			"anchor_x": coping,
		}
		anchor_x = coping
	elif zone == "deck":
		target = {"zone": "deck", "lock_x": false, "anchor_x": probe_x}
	else:
		target = {"zone": "flat", "lock_x": false, "anchor_x": probe_x}

	_begin_air_over(target, keep_h)
	_start_transfer_x_lerp(anchor_x)


func _start_transfer_x_lerp(to_x: float) -> void:
	_transfer_x_from = depth.logical_x
	_transfer_x_to = to_x
	_transfer_x_t = 0.0
	_transfer_x_active = absf(to_x - depth.logical_x) > 0.05


func _coping_x_for(side: int, lip_x: float, radius: float) -> float:
	if side == QuarterPipe.PipeSide.LEFT:
		return lip_x - radius
	return lip_x + radius


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
	return -1.0 if side == QuarterPipe.PipeSide.LEFT else 1.0


func _pipe_zone_name(side: int) -> String:
	return "left_pipe" if side == QuarterPipe.PipeSide.LEFT else "right_pipe"


func zone_debug_label() -> String:
	var zone := str(last_surface.get("zone", "flat"))
	if zone == "air":
		var over := air_over
		if over == "" and last_surface.has("air_over"):
			over = str(last_surface.air_over)
		if over != "":
			return "air (over %s)" % over
		return "air"
	return zone


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
	var target := Vector2(input.x * max_speed_x, input.y * max_speed_z)
	if input != Vector2.ZERO:
		_velocity = _velocity.move_toward(target, acceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, friction * delta)
