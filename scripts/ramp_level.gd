class_name RampLevel
extends Node2D
## Owns the plaza flat + left/right quarter pipes. Single surface sampler for the player.

@export var lip_left: float = 180.0
@export var lip_right: float = 1100.0
@export var pipe_radius: float = 150.0
@export var z_min: float = 0.0
@export var z_max: float = 100.0

@onready var left_pipe: QuarterPipe = $LeftPipe
@onready var right_pipe: QuarterPipe = $RightPipe


func _ready() -> void:
	_sync_pipes()
	queue_redraw()


func _sync_pipes() -> void:
	if left_pipe:
		left_pipe.side = QuarterPipe.PipeSide.LEFT
		left_pipe.lip_x = lip_left
		left_pipe.radius = pipe_radius
		left_pipe.z_min = z_min
		left_pipe.z_max = z_max
	if right_pipe:
		right_pipe.side = QuarterPipe.PipeSide.RIGHT
		right_pipe.lip_x = lip_right
		right_pipe.radius = pipe_radius
		right_pipe.z_min = z_min
		right_pipe.z_max = z_max


## Playable X bounds: outer pipe tops.
func x_min() -> float:
	return lip_left - pipe_radius


func x_max() -> float:
	return lip_right + pipe_radius


func sample(logical_x: float, logical_z: float) -> Dictionary:
	_sync_pipes()
	var left := left_pipe.query_surface(logical_x, logical_z)
	if left.get("active", false):
		return left

	var right := right_pipe.query_surface(logical_x, logical_z)
	if right.get("active", false):
		return right

	return {
		"active": true,
		"zone": "flat",
		"height": 0.0,
		"angle": 0.0,
		"theta": 0.0,
		"normal_x": 0.0,
		"normal_y": 1.0,
		"t_along_pipe": 0.0,
	}
