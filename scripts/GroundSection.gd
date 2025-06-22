extends Node2D
class_name GroundSection 

# Signals emitted when a character enters/exits this section
signal character_entered_section(section: GroundSection, character: Node2D)
signal character_exited_section(section: GroundSection, character: Node2D)

# Scene references
@onready var background: ColorRect = $Background
@onready var area_detector: Area2D = $AreaDetector
@onready var collision_shape: CollisionShape2D = $AreaDetector/AreaCollisionShape2D
var color = Color.DEEP_PINK
var section_height: float = 0.0

func get_vertical_bounds() -> Vector2:
		var top_y = global_position.y
		var bottom_y = global_position.y + section_height
		return Vector2(top_y, bottom_y)

func get_horizontal_bounds() -> Vector2:
		var left_x = global_position.x
		var right_x = global_position.x + (background.size.x if background else 500.0)
		return Vector2(left_x, right_x)

func get_all_bounds() -> Dictionary:
		var v_bounds = get_vertical_bounds()
		var h_bounds = get_horizontal_bounds()
		return {
			"min_depth": v_bounds.x,
			"max_depth": v_bounds.y,
			"min_x": h_bounds.x,
			"max_x": h_bounds.y
		}

static func NewGroundSection(idx: int) -> GroundSection:
	var scene = preload("res://scenes/GroundSection.tscn")
	var section: GroundSection = scene.instantiate()
	section.color = colorChoices[idx % colorChoices.size()]	
	return section

func set_size(width: int, height: int) -> GroundSection:
	section_height = height
	if background:
		background.size.x = width
		background.size.y = height
	if collision_shape and collision_shape.shape:
		# Set area detection collision area to match the background size and position
		collision_shape.shape.size = Vector2(width, height)
		collision_shape.position = Vector2(width / 2, height / 2)
	return self

func set_position_x(pos_x: int) -> GroundSection:
	position.x = pos_x
	return self

func update_collision_shape():
	# Update collision shape to match current background dimensions
	if background:
		var width = background.size.x
		var height = background.size.y
		if collision_shape and collision_shape.shape:
			collision_shape.shape.size = Vector2(width, height)
			collision_shape.position = Vector2(width / 2, height / 2)

func _ready():
		# Set initial color
	if background:
			background.color = self.color
			if section_height == 0.0:
					section_height = background.size.y

	# Connect Area2D signals
	if area_detector:
		area_detector.body_entered.connect(_on_character_entered)
		area_detector.body_exited.connect(_on_character_exited)
		print("Connected area detection signals for GroundSection")

func _on_character_entered(body: Node2D):
	if body.is_in_group("Characters") and background:
		character_entered_section.emit(self, body)

func _on_character_exited(body: Node2D):
	print("Character exited: ", body.name)
	if body.is_in_group("Characters") and background:
		background.color = self.color
		# Emit signal so GroundController can update bounds
		character_exited_section.emit(self, body)

static var colorChoices: Array[Color] = [
	Color(0.9, 0.85, 0.95, 1.0),  # Soft lavender
	Color(0.85, 0.95, 0.9, 1.0),  # Mint green  
	Color(0.95, 0.9, 0.85, 1.0),  # Warm peach
]
