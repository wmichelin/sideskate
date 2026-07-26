extends Node2D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## On pipes, motion follows the arc (θ) so coping → air stays continuous.

@export var max_speed_x: float = 520.0
@export var max_speed_z: float = 260.0
@export var acceleration: float = 2200.0
@export var friction: float = 2400.0
@export var depth_speed_feel: bool = true
@export var level_path: NodePath = NodePath("../RampLevel")
## How far past the coping to probe for transfer targets.
@export var transfer_probe: float = 8.0
## θ on a destination pipe after transfer (under PI/2 so we don't instantly re-air).
@export var transfer_pipe_theta: float = 0.92

@onready var depth: PseudoDepthBody = $PseudoDepthBody
@onready var _head_debug_label: Label = $Body/HeadDebug/Label

var _velocity: Vector2 = Vector2.ZERO
var _level: RampLevel
var last_surface: Dictionary = {}

var air_height: float = 0.0
var _airborne: bool = false
## Zone we launched from while airborne (e.g. "left_pipe" / "right_pipe").
var air_over: String = ""
var _air_side: int = QuarterPipe.PipeSide.RIGHT
var _air_lip_x: float = 0.0
var _air_coping_x: float = 0.0
var _air_radius: float = 150.0


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
	depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)
	var arc_speed := _velocity.x * speed_mul

	if _airborne:
		var toward: float = arc_speed * _coping_sign(_air_side)
		air_height = clampf(air_height + toward * delta, 0.0, _air_max_height())
		depth.logical_x = _air_coping_x
		if air_height <= 0.001 and toward <= 1.0:
			_clear_air()
			# Hand off onto the coping arc; remaining toward-ramp speed rides down.
			if toward < -1.0:
				_move_along_pipe_or_flat(toward * delta, delta)
			else:
				depth.logical_x = _air_coping_x
		return

	# Prefer arc travel when already on a pipe.
	var hit: Dictionary = _level.sample(depth.logical_x, depth.logical_z) if _level else {}
	if _is_pipe_hit(hit):
		_move_along_pipe(hit, arc_speed * delta)
		return

	# Flat / deck: normal X, but catch a coping cross in one step.
	var next_x: float = depth.logical_x + arc_speed * delta
	var cross := _coping_cross_hit(depth.logical_x, next_x)
	if not cross.is_empty():
		_enter_air(cross)
		var overshoot: float = (next_x - _air_coping_x) * _coping_sign(_air_side)
		air_height = clampf(maxf(overshoot, 0.0), 0.0, _air_max_height())
		depth.logical_x = _air_coping_x
		return
	depth.logical_x = next_x


## Advance along the quarter-pipe arc. Past θ=PI/2 becomes air_height.
func _move_along_pipe(hit: Dictionary, signed_dx: float) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = _pipe_radius_for_hit(hit)
	if radius <= 0.0001:
		return
	var sign: float = _coping_sign(side)
	var toward_arc: float = signed_dx * sign  # + = toward coping
	var theta: float = float(hit.get("theta", 0.0))
	var d_theta: float = toward_arc / radius
	var new_theta: float = theta + d_theta

	if new_theta >= PI * 0.5:
		_enter_air({
			"side": side,
			"lip_x": lip,
			"radius": radius,
		})
		# Excess arc length past coping → continuous air lift.
		air_height = clampf((new_theta - PI * 0.5) * radius, 0.0, _air_max_height())
		depth.logical_x = _air_coping_x
		return

	if new_theta <= 0.0:
		# Leave onto flat past the lip.
		depth.logical_x = lip - sign * absf(new_theta) * radius
		return

	var x_off: float = radius * sin(new_theta)
	if side == QuarterPipe.PipeSide.LEFT:
		depth.logical_x = lip - x_off
	else:
		depth.logical_x = lip + x_off


func _move_along_pipe_or_flat(signed_toward_arc: float, _delta: float) -> void:
	# After leaving air at coping, take one arc step down the pipe.
	var hit: Dictionary = {
		"active": true,
		"zone": "left_pipe" if _air_side == QuarterPipe.PipeSide.LEFT else "right_pipe",
		"side": _air_side,
		"lip_x": _air_lip_x,
		"theta": PI * 0.5,
		"t_along_pipe": 1.0,
	}
	# signed_toward_arc is already toward-coping signed (+ up / - down).
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
		last_surface["height"] = _air_radius + air_height
		depth.surface_height = _air_radius + air_height
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


func _enter_air(hit: Dictionary) -> void:
	_airborne = true
	_air_side = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	_air_lip_x = float(hit.get("lip_x", depth.logical_x))
	_air_radius = float(hit.get("radius", _pipe_radius_for_hit(hit)))
	_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
	air_over = _pipe_zone_name(_air_side)
	air_height = 0.0
	depth.logical_x = _air_coping_x


func _clear_air() -> void:
	_airborne = false
	air_height = 0.0
	air_over = ""
	depth.height_offset = 0.0


## Snap out of air onto whatever is behind the current pipe coping.
func _try_transfer() -> void:
	if not _airborne or _level == null:
		return
	var behind: float = _coping_sign(_air_side)
	var probe_x: float = _air_coping_x + behind * transfer_probe
	var hit: Dictionary = _level.sample_transfer(
		probe_x, depth.logical_z, _air_side, _air_lip_x
	)
	var zone := str(hit.get("zone", "flat"))
	if zone == "deck":
		_land_on_deck(probe_x)
	elif _is_pipe_hit(hit):
		_land_on_pipe(hit)
	else:
		_land_on_flat(probe_x)


func _land_on_deck(probe_x: float) -> void:
	_clear_air()
	depth.logical_x = probe_x


func _land_on_flat(probe_x: float) -> void:
	_clear_air()
	depth.logical_x = probe_x


func _land_on_pipe(hit: Dictionary) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = _pipe_radius_for_hit(hit)
	var theta: float = clampf(transfer_pipe_theta, 0.05, PI * 0.5 - 0.05)
	var x_off: float = radius * sin(theta)
	_clear_air()
	if side == QuarterPipe.PipeSide.LEFT:
		depth.logical_x = lip - x_off
	else:
		depth.logical_x = lip + x_off


func _air_max_height() -> float:
	return maxf(_air_radius * 2.0, 1.0)


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
	if not hit.get("active", false):
		return false
	var zone := str(hit.get("zone", ""))
	return zone == "left_pipe" or zone == "right_pipe"


func _coping_sign(side: int) -> float:
	return -1.0 if side == QuarterPipe.PipeSide.LEFT else 1.0


func _pipe_zone_name(side: int) -> String:
	return "left_pipe" if side == QuarterPipe.PipeSide.LEFT else "right_pipe"


## Debug label for current zone, e.g. "air (over left_pipe)" or "deck".
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
