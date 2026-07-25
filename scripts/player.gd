extends Node2D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.

@export var max_speed_x: float = 520.0
@export var max_speed_z: float = 260.0
@export var acceleration: float = 2200.0
@export var friction: float = 2400.0
@export var depth_speed_feel: bool = true
@export var level_path: NodePath = NodePath("../RampLevel")

@onready var depth: PseudoDepthBody = $PseudoDepthBody

var _velocity: Vector2 = Vector2.ZERO
var _level: RampLevel
var last_surface: Dictionary = {}


func _ready() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	# Wait one frame so RampLevel can load .ssk in its _ready first.
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
	_apply_surface()
	depth.apply()


func _physics_process(delta: float) -> void:
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel

	var input := _read_move_input()
	_integrate_velocity(input, delta)

	var speed_mul := depth.depth_speed_multiplier() if depth_speed_feel else 1.0
	depth.logical_x += _velocity.x * speed_mul * delta
	depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)

	if _level:
		depth.logical_x = clampf(depth.logical_x, _level.x_min(), _level.x_max())
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	else:
		depth.logical_x = clampf(depth.logical_x, 80.0, 1200.0)

	_apply_surface()
	depth.apply()


func _apply_surface() -> void:
	if _level == null:
		last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		depth.surface_height = 0.0
		return
	last_surface = _level.sample(depth.logical_x, depth.logical_z)
	if not last_surface.get("active", true) and last_surface.get("zone", "") == "oob":
		# Soft: stay at last height 0 if OOB
		depth.surface_height = 0.0
	else:
		depth.surface_height = float(last_surface.get("height", 0.0))


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
