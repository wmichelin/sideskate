class_name PseudoDepthBody
extends Node
## Converts logical (X, Z) beat-em-up coordinates into screen placement.
##
## When a RampLevel projector is set, screen X/Y and surface height use the same
## perspective math as the quarter-pipe visuals (inset + geometry scale by depth).
## Sprite scale still uses near_scale→far_scale independently.

@export_group("Lane Band")
@export var z_min: float = 0.0
@export var z_max: float = 100.0
@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0

@export_group("Scale")
@export var near_scale: float = 1.0
@export var far_scale: float = 0.55

@export_group("Draw Order")
@export var near_z_index: int = 100
@export var far_z_index: int = 10

@export_group("Targets")
@export var visual_path: NodePath = NodePath("../Body")
@export var shadow_path: NodePath = NodePath("../Shadow")
@export var shadow_ground_nudge: float = 8.0
## Optional — when set, feet track RampLevel perspective (pipes + plaza).
@export var level_path: NodePath = NodePath("../../RampLevel")

var logical_x: float = 0.0
var logical_z: float = 0.0
var surface_height: float = 0.0
var height_offset: float = 0.0

var _visual: Node2D
var _shadow: Node2D
var _level: RampLevel


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_shadow = get_node_or_null(shadow_path) as Node2D
	_level = get_node_or_null(level_path) as RampLevel


func depth_t() -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


func ground_screen_y() -> float:
	if _level:
		return _level.ground_screen_y(logical_z)
	return lerpf(near_screen_y, far_screen_y, depth_t())


func visual_scale() -> float:
	return lerpf(near_scale, far_scale, depth_t())


func draw_z_index() -> int:
	return int(round(lerpf(float(near_z_index), float(far_z_index), depth_t())))


func depth_speed_multiplier() -> float:
	return visual_scale()


func clamp_z(z: float) -> float:
	return clampf(z, z_min, z_max)


func apply() -> void:
	logical_z = clamp_z(logical_z)
	var parent := get_parent() as Node2D
	if parent == null:
		return

	var t := depth_t()
	var s := visual_scale()
	var z_i := draw_z_index()

	var screen_x := logical_x
	var ground_y := ground_screen_y()
	var surface_screen_h := surface_height * s

	if _level:
		var p: Dictionary = _level.project(logical_x, logical_z, surface_height)
		screen_x = float(p.screen_x)
		ground_y = float(p.ground_y)
		surface_screen_h = float(p.surface_screen_h)

	parent.position = Vector2(screen_x, ground_y)
	parent.z_index = z_i

	if _visual:
		_visual.position = Vector2(0.0, -(surface_screen_h + height_offset * s))
		_visual.scale = Vector2(s, s)
		_visual.z_index = 1

	if _shadow:
		_shadow.position = Vector2(0.0, shadow_ground_nudge * s - surface_screen_h)
		_shadow.scale = Vector2(s, s * 0.45)
		_shadow.z_index = 0
		_shadow.modulate.a = lerpf(0.55, 0.28, t)


func debug_snapshot() -> Dictionary:
	var screen_x := logical_x
	var surface_screen_h := surface_height * visual_scale()
	if _level:
		var p: Dictionary = _level.project(logical_x, logical_z, surface_height)
		screen_x = float(p.screen_x)
		surface_screen_h = float(p.surface_screen_h)
	return {
		"x": logical_x,
		"z": logical_z,
		"t": depth_t(),
		"scale": visual_scale(),
		"screen_x": screen_x,
		"screen_y": ground_screen_y(),
		"surface_screen_h": surface_screen_h,
		"z_index": draw_z_index(),
		"surface_height": surface_height,
		"height": height_offset,
	}
