extends DepthBoundedCharacter

class_name Player

# Export variables for easy tweaking in the editor
@export var jump_velocity: float = 300.0
@export var gravity: float = -800.0

# Skateboard physics variables
@export var kick_force: float = 150.0  # Force applied when kicking
@export var friction: float = 25.0  # Friction that slows down movement
@export var max_speed: float = 1000.0  # Maximum skateboard speed

# Faked Y-axis variables for 2.5D depth simulation
@export var depth_speed: float = 150.0  # Speed for up/down movement

var fake_y: float = 0.0  # Simulated Y position for jumping
var depth_position: float = 0.0  # Position along the "depth" axis
var jump_speed: float = 0.0  # Current jump velocity

# Skateboard momentum
var skateboard_velocity: float = 0.0  # Horizontal momentum from skateboarding
var facing_direction: int = 1  # 1 for right, -1 for left
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
	
	# Kick logic - apply rightward acceleration
	if Input.is_action_just_pressed("kick"):
		_perform_kick()
	
	# Revert logic - instantly reverse momentum
	if Input.is_action_just_pressed("revert"):
		_perform_revert()

	# Handle faked gravity for jumping
	if fake_y >= 0 or jump_speed < 0:
		jump_speed += gravity * delta
		fake_y += jump_speed * delta
		
		# Land on ground
		if fake_y <= 0:
			fake_y = 0
			jump_speed = 0

	# Apply friction to skateboard velocity
	if skateboard_velocity > 0:
		skateboard_velocity = max(0, skateboard_velocity - friction * delta)
	elif skateboard_velocity < 0:
		skateboard_velocity = min(0, skateboard_velocity + friction * delta)
	
	# Set horizontal velocity from skateboard momentum
	velocity.x = skateboard_velocity
	
	# Get input for depth movement
	var depth_input = Input.get_axis("up", "down")

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

func _perform_kick():
	# Apply acceleration in the direction the character is facing
	skateboard_velocity += kick_force * facing_direction
	# Clamp to maximum speed in both directions
	skateboard_velocity = clamp(skateboard_velocity, -max_speed, max_speed)
	print("Kick! Direction: ", facing_direction, " Velocity: ", skateboard_velocity)

func _perform_revert():
	# Reverse facing direction and momentum
	facing_direction *= -1
	skateboard_velocity = -skateboard_velocity
	print("Revert! Now facing: ", "right" if facing_direction == 1 else "left", " Velocity: ", skateboard_velocity) 
