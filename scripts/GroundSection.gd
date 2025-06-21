extends Node2D
class_name GroundSection 

# Signal emitted when a character enters this section
signal character_entered_section(section: GroundSection, character: Node2D)

# Scene references
@onready var background: ColorRect = $Background
@onready var area_detector: Area2D = $AreaDetector
@onready var collision_shape: CollisionShape2D = $AreaDetector/CollisionShape2D
var color = Color.DEEP_PINK

func get_vertical_bounds() -> Vector2:
        if background:
                var top_y = global_position.y
                var bottom_y = global_position.y + background.size.y
                return Vector2(top_y, bottom_y)
        return Vector2.ZERO

static func NewGroundSection(idx: int) -> GroundSection:
	var scene = preload("res://scenes/GroundSection.tscn")
	var section: GroundSection = scene.instantiate()
	section.color = colorChoices[idx % colorChoices.size()]	
	return section

func set_size(width: int, height: int) -> GroundSection:
	if background:
		background.size.x = width
		background.size.y = height
	if collision_shape and collision_shape.shape:
	   # Make collision area span full viewport height for X-only detection
		var viewport_height = get_viewport().get_visible_rect().size.y
		collision_shape.shape.size = Vector2(width, viewport_height * 2)
		collision_shape.position = Vector2(width / 2, 0)
	return self

func set_position_x(pos_x: int) -> GroundSection:
	position.x = pos_x
	return self

func _ready():
	# Set initial color
	if background:
		background.color = self.color

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

static var colorChoices: Array[Color] = [
	Color.CYAN,
	Color.DARK_MAGENTA,
	Color.DARK_OLIVE_GREEN,
]
