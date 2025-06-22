extends CharacterBody2D

class_name DepthBoundedCharacter

@export var default_min_depth: float = 50.0
@export var default_max_depth: float = 400.0
@export var default_min_x: float = -1000.0
@export var default_max_x: float = 1000.0

var min_depth: float
var max_depth: float
var min_x: float
var max_x: float

func _ready():
	min_depth = default_min_depth
	max_depth = default_max_depth
	min_x = default_min_x
	max_x = default_max_x

func set_depth_bounds(min_val: float, max_val: float) -> void:
	min_depth = min_val
	max_depth = max_val

func set_horizontal_bounds(min_val: float, max_val: float) -> void:
	min_x = min_val
	max_x = max_val

func set_bounds(min_depth_val: float, max_depth_val: float, min_x_val: float, max_x_val: float) -> void:
	min_depth = min_depth_val
	max_depth = max_depth_val
	min_x = min_x_val
	max_x = max_x_val
