extends Node2D
## Static depth reference object — places itself via PseudoDepthBody.

@export var start_x: float = 400.0
@export var start_z: float = 50.0

@onready var depth: PseudoDepthBody = $PseudoDepthBody


func _ready() -> void:
	depth.logical_x = start_x
	depth.logical_z = start_z
	depth.apply()
