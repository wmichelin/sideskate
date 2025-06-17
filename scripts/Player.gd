extends CharacterBody2D

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

signal jumped()

func _ready():
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
		# Clamp depth to reasonable bounds
		depth_position = clamp(depth_position, 0, 400)
	
	# Update actual position
	var y_pos = depth_position - fake_y
	position.y = y_pos  # Subtract fake_y for jump effect
	
	# Move horizontally
	move_and_slide()
	
	# Update visual depth sorting (objects lower on screen appear in front)
	z_index = int(depth_position) 
