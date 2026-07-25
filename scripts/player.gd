extends Node2D
## 8-way mover on logical X/Z with accel/friction. Depth visuals via PseudoDepthBody.

@export var max_speed: float = 260.0
@export var acceleration: float = 1600.0
@export var friction: float = 1800.0
## When on, logical speed is scaled by visual scale so near movement reads faster.
@export var depth_speed_feel: bool = true

@onready var depth: PseudoDepthBody = $PseudoDepthBody

var _velocity: Vector2 = Vector2.ZERO  # x = logical X speed, y = logical Z speed


func _ready() -> void:
	depth.logical_x = 200.0
	depth.logical_z = 40.0
	depth.apply()


func _physics_process(delta: float) -> void:
	var input := _read_move_input()
	_integrate_velocity(input, delta)

	var speed_mul := depth.depth_speed_multiplier() if depth_speed_feel else 1.0
	depth.logical_x += _velocity.x * speed_mul * delta
	depth.logical_z = depth.clamp_z(depth.logical_z + _velocity.y * speed_mul * delta)

	# Soft clamp X to a wide playfield so the player stays on the test stage.
	depth.logical_x = clampf(depth.logical_x, 80.0, 1200.0)
	depth.apply()


func _read_move_input() -> Vector2:
	# X: left/right. Z: up = farther (+Z), down = nearer (-Z).
	var x := Input.get_axis("move_left", "move_right")
	var z := Input.get_axis("move_down", "move_up")
	var v := Vector2(x, z)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _integrate_velocity(input: Vector2, delta: float) -> void:
	if input != Vector2.ZERO:
		_velocity = _velocity.move_toward(input * max_speed, acceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, friction * delta)
