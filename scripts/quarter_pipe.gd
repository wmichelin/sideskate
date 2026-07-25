class_name QuarterPipe
extends Node
## Interactable quarter-pipe surface on the left or right edge of the plaza.
##
## Logical profile (height up from flat):
##   θ = 0 at the lip (meets flat), θ = PI/2 at the vertical top
##   x_offset from lip into the pipe = radius * sin(θ)
##   height                   = radius * (1 - cos(θ))
## Given x: θ = asin(clamp(x_offset / radius)), height = radius * (1 - cos(θ))

enum PipeSide { LEFT, RIGHT }

@export var side: PipeSide = PipeSide.LEFT
## X where the pipe meets the flat floor.
@export var lip_x: float = 180.0
@export var radius: float = 150.0
@export var z_min: float = 0.0
@export var z_max: float = 100.0


func x_min() -> float:
	if side == PipeSide.LEFT:
		return lip_x - radius
	return lip_x


func x_max() -> float:
	if side == PipeSide.LEFT:
		return lip_x
	return lip_x + radius


func contains_x(logical_x: float) -> bool:
	return logical_x >= x_min() - 0.001 and logical_x <= x_max() + 0.001


func contains_z(logical_z: float) -> bool:
	return logical_z >= z_min - 0.001 and logical_z <= z_max + 0.001


## Returns surface sample, or { active: false } if outside this pipe.
func query_surface(logical_x: float, logical_z: float) -> Dictionary:
	if not contains_z(logical_z) or not contains_x(logical_x):
		return {"active": false}

	var x_offset: float
	if side == PipeSide.LEFT:
		x_offset = lip_x - logical_x
	else:
		x_offset = logical_x - lip_x

	x_offset = clampf(x_offset, 0.0, radius)
	var ratio := 0.0 if radius <= 0.0001 else clampf(x_offset / radius, 0.0, 1.0)
	var theta := asin(ratio)
	var height := radius * (1.0 - cos(theta))
	# Unit normal pointing toward the plaza / open air (away from the wall).
	var normal_x := cos(theta) if side == PipeSide.LEFT else -cos(theta)
	var normal_y := sin(theta)  # "up" in logical height space

	return {
		"active": true,
		"zone": "left_pipe" if side == PipeSide.LEFT else "right_pipe",
		"height": height,
		"angle": rad_to_deg(theta),
		"theta": theta,
		"normal_x": normal_x,
		"normal_y": normal_y,
		"t_along_pipe": ratio,
		"lip_x": lip_x,
		"side": side,
	}
