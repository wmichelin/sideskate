class_name RampLevel
extends Node2D
## Owns the plaza flat + left/right quarter pipes. Single surface sampler + perspective projector.

@export var lip_left: float = 180.0
@export var lip_right: float = 1100.0
@export var pipe_radius: float = 150.0
@export var z_min: float = 0.0
@export var z_max: float = 100.0

@export_group("Perspective")
@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0
## How far lips converge toward center at max depth (screen px).
@export var perspective_inset: float = 80.0
## Geometry size at far depth relative to near (pipe radius/height & X offsets).
@export var far_geometry_scale: float = 0.72

@onready var left_pipe: QuarterPipe = $LeftPipe
@onready var right_pipe: QuarterPipe = $RightPipe


func _ready() -> void:
	_sync_pipes()


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


func depth_t(logical_z: float) -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


func geometry_scale_at(logical_z: float) -> float:
	return lerpf(1.0, far_geometry_scale, depth_t(logical_z))


func inset_at(logical_z: float) -> float:
	return lerpf(0.0, perspective_inset, depth_t(logical_z))


func ground_screen_y(logical_z: float) -> float:
	return lerpf(near_screen_y, far_screen_y, depth_t(logical_z))


## Playable X bounds: outer pipe tops (logical / near-plane space).
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


## Project logical near-plane (x, z, surface_height) onto screen pixels.
## Must match RampVisual pipe/plaza drawing exactly.
func project(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	var t := depth_t(logical_z)
	var inset := inset_at(logical_z)
	var gscale := geometry_scale_at(logical_z)
	var ground_y := ground_screen_y(logical_z)

	var screen_x: float
	if logical_x <= lip_left:
		# Left pipe / left of lip: offset outward from inset lip, scaled by depth.
		var x_off := lip_left - logical_x
		screen_x = (lip_left + inset) - x_off * gscale
	elif logical_x >= lip_right:
		var x_off := logical_x - lip_right
		screen_x = (lip_right - inset) + x_off * gscale
	else:
		# Flat plaza: remap between inset lip screens.
		var flat_w := lip_right - lip_left
		var u := 0.0 if flat_w <= 0.0001 else (logical_x - lip_left) / flat_w
		screen_x = lerpf(lip_left + inset, lip_right - inset, u)

	var surface_screen_h := surface_height * gscale
	return {
		"t": t,
		"screen_x": screen_x,
		"ground_y": ground_y,
		"surface_screen_h": surface_screen_h,
		"geometry_scale": gscale,
		"inset": inset,
	}


## Screen point on a pipe arc (for visuals). u: 0=lip … 1=coping.
func pipe_screen_point(is_left: bool, logical_z: float, u: float) -> Vector2:
	var theta := clampf(u, 0.0, 1.0) * PI * 0.5
	var x_off := pipe_radius * sin(theta)
	var height := pipe_radius * (1.0 - cos(theta))
	var logical_x: float
	if is_left:
		logical_x = lip_left - x_off
	else:
		logical_x = lip_right + x_off
	var p := project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)
