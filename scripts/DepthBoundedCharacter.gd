extends CharacterBody2D

class_name DepthBoundedCharacter

@export var default_min_depth: float = 50.0
@export var default_max_depth: float = 400.0

var min_depth: float
var max_depth: float

func _ready():
        min_depth = default_min_depth
        max_depth = default_max_depth

func set_depth_bounds(min_val: float, max_val: float) -> void:
        min_depth = min_val
        max_depth = max_val
