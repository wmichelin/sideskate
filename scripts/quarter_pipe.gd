class_name QuarterPipe
extends Node
## Interactable quarter-pipe surface on the left or right edge of the plaza.
##
## Logical profile — true quarter circle (θ = 0 at the lip, θ = PI/2 at coping):
##   x_offset from lip into the pipe = radius * sin(θ)
##   height = base_height + radius * (1 - cos(θ))
## Radius = glyph-run width (N × cell_x), so `((((` is 4× as tall as `(`.
## Draw code (`RampLevel.pipe_screen_point_for`) re-rounds the profile in screen
## space so perspective cannot squash it into an ellipse.
## Given x: θ = asin(clamp(x_offset / radius))

enum PipeSide { LEFT, RIGHT }

@export var side: PipeSide = PipeSide.LEFT
## X where the pipe meets its base flat (layer floor).
@export var lip_x: float = 180.0
@export var radius: float = 150.0
## Height span of the transition. -1 = same as radius (circular / 45° ramp).
@export var rise: float = -1.0
## Absolute logical height of the pipe's base flat (layer height).
@export var base_height: float = 0.0
## Source layer index from the .ssk (`layer N`).
@export var layer: int = 0
@export var z_min: float = 0.0
@export var z_max: float = 100.0
## "pipe" (quarter circle) or "ramp" (straight incline).
@export var kind: String = "pipe"


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


func is_ramp() -> bool:
	return kind == "ramp"


func effective_rise() -> float:
	return rise if rise > 0.0 else radius


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
	var ry := effective_rise()
	var theta: float
	var height: float
	var normal_x: float
	var normal_y: float
	if is_ramp():
		theta = ratio * PI * 0.5
		height = base_height + ry * ratio
		var nlen := sqrt(ry * ry + radius * radius)
		normal_x = (ry / nlen) if side == PipeSide.LEFT else -(ry / nlen)
		normal_y = radius / nlen
	else:
		theta = asin(ratio)
		height = base_height + ry * (1.0 - cos(theta))
		# Scaled quarter-circle frame (matches PipeSurface when rise == radius).
		var n_x := ry * cos(theta)
		var n_h := radius * sin(theta)
		var nlen2 := sqrt(n_x * n_x + n_h * n_h)
		if nlen2 > 0.0001:
			n_x /= nlen2
			n_h /= nlen2
		normal_x = n_x if side == PipeSide.LEFT else -n_x
		normal_y = n_h

	var zone := (
		PipeMath.ramp_zone_name(side) if is_ramp() else PipeMath.zone_name(side)
	)
	return {
		"active": true,
		"zone": zone,
		"height": height,
		"angle": rad_to_deg(theta),
		"theta": theta,
		"normal_x": normal_x,
		"normal_y": normal_y,
		"t_along_pipe": ratio,
		"lip_x": lip_x,
		"side": side,
		"base_height": base_height,
		"radius": radius,
		"rise": ry,
		"layer": layer,
		"z_min": z_min,
		"z_max": z_max,
		"kind": kind,
	}
