class_name PseudoDepthBody
extends Node
## Converts logical (X, Z) beat-em-up coordinates into screen placement.
##
## Logical space:
##   X = screen-horizontal world units (1:1 with pixels in this prototype)
##   Z = depth in a bounded lane band [z_min, z_max]
##       Z = z_min  → nearest to camera (bottom of lane, largest)
##       Z = z_max  → farthest from camera (top of lane, smallest)
##
## Screen mapping (Godot Y grows downward):
##   t = (Z - z_min) / (z_max - z_min)          # 0 near → 1 far
##   screen_y = lerp(near_screen_y, far_screen_y, t)
##   scale     = lerp(near_scale, far_scale, t)
##   z_index   = round(lerp(near_z_index, far_z_index, t))
##
## Shadow uses the surface contact position (X, screen_y - surface_height)
## and ignores jump height_offset so jumps can lift the body later.

@export_group("Lane Band")
@export var z_min: float = 0.0
@export var z_max: float = 100.0
## Screen Y of the near edge of the lane (closer to bottom of viewport).
@export var near_screen_y: float = 560.0
## Screen Y of the far edge of the lane (higher on screen).
@export var far_screen_y: float = 300.0

@export_group("Scale")
@export var near_scale: float = 1.0
@export var far_scale: float = 0.55

@export_group("Draw Order")
## Near sprites should draw in front of far ones.
@export var near_z_index: int = 100
@export var far_z_index: int = 10

@export_group("Targets")
@export var visual_path: NodePath = NodePath("../Body")
@export var shadow_path: NodePath = NodePath("../Shadow")
## Extra downward offset for the shadow under the feet (screen pixels at near scale).
@export var shadow_ground_nudge: float = 8.0

## Logical horizontal position (world/screen X).
var logical_x: float = 0.0
## Logical depth in the lane band.
var logical_z: float = 0.0
## Height of the supporting surface (pipe/flat). Shadow follows this.
var surface_height: float = 0.0
## Extra jump height in screen pixels (body only — shadow ignores this).
var height_offset: float = 0.0

var _visual: Node2D
var _shadow: Node2D


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_shadow = get_node_or_null(shadow_path) as Node2D
	# Parent scripts set logical_x/z then call apply() — do not apply defaults here
	# or we overwrite the parent's spawn position (children _ready before parents).


func depth_t() -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


## Ground contact Y on screen for the current Z (shadow + feet on flat plaza).
func ground_screen_y() -> float:
	return lerpf(near_screen_y, far_screen_y, depth_t())


func visual_scale() -> float:
	return lerpf(near_scale, far_scale, depth_t())


func draw_z_index() -> int:
	return int(round(lerpf(float(near_z_index), float(far_z_index), depth_t())))


## Optional movement feel: same logical speed reads faster when closer
## because we scale screen-space travel by the current visual scale.
func depth_speed_multiplier() -> float:
	return visual_scale()


func clamp_z(z: float) -> float:
	return clampf(z, z_min, z_max)


## Push logical X/Z (+ surface/jump height) into Node2D transforms.
func apply() -> void:
	logical_z = clamp_z(logical_z)
	var parent := get_parent() as Node2D
	if parent == null:
		return

	var t := depth_t()
	var ground_y := ground_screen_y()
	var s := visual_scale()
	var z_i := draw_z_index()

	# Root sits on the plaza ground line for this depth; height is applied on children.
	parent.position = Vector2(logical_x, ground_y)
	parent.z_index = z_i

	if _visual:
		# Surface raises body+shadow; jump height raises body only.
		_visual.position = Vector2(0.0, -(surface_height + height_offset) * s)
		_visual.scale = Vector2(s, s)
		_visual.z_index = 1

	if _shadow:
		# Shadow pinned to surface contact (not jump height).
		_shadow.position = Vector2(0.0, shadow_ground_nudge * s - surface_height * s)
		_shadow.scale = Vector2(s, s * 0.45)
		_shadow.z_index = 0
		_shadow.modulate.a = lerpf(0.55, 0.28, t)


func debug_snapshot() -> Dictionary:
	return {
		"x": logical_x,
		"z": logical_z,
		"t": depth_t(),
		"scale": visual_scale(),
		"screen_y": ground_screen_y(),
		"z_index": draw_z_index(),
		"surface_height": surface_height,
		"height": height_offset,
	}
