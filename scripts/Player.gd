extends DepthBoundedCharacter

class_name Player

# Export variables for easy tweaking in the editor
@export var move_speed: float = 200.0
@export var jump_velocity: float = 300.0
@export var gravity: float = -800.0

# Faked Y-axis variables for 2.5D depth simulation
@export var depth_speed: float = 150.0  # Speed for up/down movement

var fake_y: float = 0.0  # Simulated Y position for jumping
var depth_position: float = 0.0  # Position along the "depth" axis
var jump_speed: float = 0.0  # Current jump velocity
# Camera reference
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal jumped()

func _ready():
		super()
		# Set initial depth position
		depth_position = position.y


func _physics_process(delta):
	# Handle jumping input
	if Input.is_action_just_pressed("jump") and fake_y <= 0:
		jump_speed = jump_velocity
		jumped.emit()

	# Handle faked gravity for jumping
	if fake_y >= 0 or jump_speed < 0:
		jump_speed += gravity * delta
		fake_y += jump_speed * delta
		
		# Land on ground
		if fake_y <= 0:
			fake_y = 0
			jump_speed = 0

	# Get input for horizontal and depth movement
	var horizontal_input = Input.get_axis("left", "right")
	var depth_input = Input.get_axis("up", "down")
	
	# Horizontal movement (X-axis)
	if horizontal_input != 0:
		velocity.x = horizontal_input * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5)

	# Depth movement (simulated via Y position)
	if depth_input != 0:
		depth_position += depth_input * depth_speed * delta

	# Update actual position
	var y_pos = depth_position - fake_y
	position.y = y_pos  # Subtract fake_y for jump effect
	
	# Move horizontally
	move_and_slide()
	
	# Get collision shape bounds in world space
	var shape_size = collision_shape.shape.size * scale
	var shape_global_pos = global_position + collision_shape.position * scale
	
	# Calculate collision shape boundaries
	var collision_left = shape_global_pos.x - shape_size.x / 2
	var collision_right = shape_global_pos.x + shape_size.x / 2
	var collision_top = shape_global_pos.y - shape_size.y / 2 
	var collision_bottom = shape_global_pos.y + shape_size.y / 2
	
	# Strict boundary enforcement - collision shape cannot extend beyond bounds
	if collision_left < min_x:
		position.x = min_x + shape_size.x / 2 - collision_shape.position.x * scale.x
	elif collision_right > max_x:
		position.x = max_x - shape_size.x / 2 - collision_shape.position.x * scale.x
		
	if collision_top < min_depth:
		depth_position = min_depth + shape_size.y / 2 - collision_shape.position.y * scale.y
	elif collision_bottom > max_depth:
		depth_position = max_depth - shape_size.y / 2 - collision_shape.position.y * scale.y
	
	# Update visual depth sorting (objects lower on screen appear in front)
	z_index = int(depth_position) 
