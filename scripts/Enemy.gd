extends CharacterBody2D

class_name Enemy

# Basic enemy class - can be expanded with AI behavior later
@export var move_speed: float = 100.0
@export var gravity: float = 800.0

# Faked Y-axis variables for 2.5D depth simulation
var fake_y: float = 0.0
var depth_position: float = 0.0

func _ready():
	# Set initial depth position
	depth_position = position.y

func _physics_process(delta):
	# Handle faked gravity (for when enemy might jump or be knocked up)
	if fake_y > 0 or velocity.y < 0:
		velocity.y += gravity * delta
		fake_y += velocity.y * delta
		
		# Land on ground
		if fake_y <= 0:
			fake_y = 0
			velocity.y = 0
	
	# Update position with fake Y offset
	position.y = depth_position - fake_y
	
	# Move and slide to handle physics
	move_and_slide()
	
	# Update visual depth sorting
	z_index = int(depth_position) 
