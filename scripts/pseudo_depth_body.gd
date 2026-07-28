class_name PseudoDepthBody
extends Node
## Derived logical pose snapshot for helpers / presenters.
##
## CharacterBody3D (Player) is motion authority. This node stores logical X/Z/height
## mirrors used by skate policy helpers and LogicalPosePresenter3D. Prefer writing
## through Player swept commits; treat fields here as a compatibility adapter.
##
## Optional Canvas2D Body/Shadow paths remain for legacy 2D debug scenes.

const _PerspectiveMath := preload("res://scripts/perspective_math.gd")

@export_group("Lane Band")
@export var z_min: float = 0.0
@export var z_max: float = 100.0
@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0

@export_group("Scale")
## Fallback only when no RampLevel is bound. With a level, scale matches `far_geometry_scale`.
@export var near_scale: float = 1.0
@export var far_scale: float = 0.72

@export_group("Draw Order")
@export var near_z_index: int = 100
@export var far_z_index: int = 10

@export_group("Targets")
@export var visual_path: NodePath = NodePath("../Body")
@export var shadow_path: NodePath = NodePath("../Shadow")
@export var shadow_ground_nudge: float = 8.0
## Optional — when set, feet track RampLevel perspective (pipes + plaza).
@export var level_path: NodePath = NodePath("../../RampLevel")

@export_group("Air Shadow")
## Logical half-width of the circular ground shadow at support (matches slim body ~14).
@export var air_shadow_radius: float = 14.0
## Height above support (logical) at which shadow width hits `air_shadow_min_scale`.
@export var air_shadow_ref_height: float = 200.0
@export var air_shadow_min_scale: float = 0.5
## Vertical squash so the circle reads as a ground ellipse in pseudo-3D.
@export var shadow_y_squash: float = 0.45

var logical_x: float = 0.0
var logical_z: float = 0.0
## Feet absolute height (grounded support, or air_abs_height while airborne).
var surface_height: float = 0.0
var height_offset: float = 0.0
## Body rotation (radians). Set by Player so local-up follows pipe surface normal.
var surface_tilt: float = 0.0
## True while airborne — shadow pins to support_height instead of feet height.
var airborne: bool = false
## Underfoot surface height while airborne (shadow rests here).
var support_height: float = 0.0

var _visual: Node2D
var _shadow: Node2D
var _level: RampLevel


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_shadow = get_node_or_null(shadow_path) as Node2D
	_level = get_node_or_null(level_path) as RampLevel
	_ensure_shadow_circle()
	if _shadow:
		_shadow.visible = false


func depth_t() -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


func ground_screen_y() -> float:
	if _level:
		return _level.ground_screen_y(logical_z)
	# Absolute px/Z (same idea as RampLevel); default reference span = 100.
	var per_z := (near_screen_y - far_screen_y) / 100.0
	return near_screen_y - (logical_z - z_min) * per_z


func visual_scale() -> float:
	# Match level geometry scale when a projector is available.
	if _level:
		return _level.geometry_scale_at(logical_z)
	return lerpf(near_scale, far_scale, depth_t())


func draw_z_index() -> int:
	return int(round(lerpf(float(near_z_index), float(far_z_index), depth_t())))


func depth_speed_multiplier() -> float:
	return visual_scale()


func clamp_z(z: float) -> float:
	return clampf(z, z_min, z_max)


func apply() -> void:
	logical_z = clamp_z(logical_z)
	var t := depth_t()
	var s := visual_scale()
	var z_i := draw_z_index()

	var screen_x := logical_x
	var ground_y := ground_screen_y()
	var surface_screen_h := surface_height * s

	# Always refresh perspective / projection — sim parents may be plain Node
	# (3D presenter reads logical pose; Canvas2D Body/Shadow are optional).
	if _level:
		_level.set_perspective_origin(logical_x, logical_z)
		var p: Dictionary = _level.project_surface(logical_x, logical_z, surface_height)
		screen_x = float(p.screen_x)
		ground_y = float(p.ground_y)
		surface_screen_h = float(p.surface_screen_h)

	var parent := get_parent() as Node2D
	if parent != null:
		parent.position = Vector2(screen_x, ground_y)
		parent.z_index = z_i

	if _visual:
		_visual.position = Vector2(0.0, -(surface_screen_h + height_offset * s))
		_visual.scale = Vector2(s, s)
		# Player sets surface_tilt so Body local-up follows the pipe normal.
		_visual.rotation = surface_tilt
		_visual.z_index = 1

	if _shadow:
		if airborne:
			_shadow.visible = true
			_apply_air_shadow(s, t)
		else:
			_shadow.visible = false
			# Restore tree-relative sort under Body while grounded.
			_shadow.z_as_relative = true
			_shadow.z_index = -1


func _apply_air_shadow(geom_scale: float, depth_t_val: float) -> void:
	_ensure_shadow_circle()
	var support_screen_h := support_height * geom_scale
	if _level:
		var sp: Dictionary = _level.project_surface(logical_x, logical_z, support_height)
		support_screen_h = float(sp.surface_screen_h)

	# Pin to underfoot support — never floats with air feet.
	_shadow.position = Vector2(0.0, shadow_ground_nudge * geom_scale - support_screen_h)
	# Absolute above RampVisual Near (200): coplanar Near deck tops would otherwise
	# composite over the skater and hide the shadow during spine transfers.
	_shadow.z_as_relative = false
	_shadow.z_index = 210

	var width_mul := _PerspectiveMath.air_shadow_width_scale(
		surface_height - support_height,
		air_shadow_ref_height,
		air_shadow_min_scale
	)
	# Relative width: perspective scale × height falloff; Y squash for ground ellipse.
	_shadow.scale = Vector2(
		geom_scale * width_mul,
		geom_scale * shadow_y_squash * width_mul
	)
	_shadow.modulate.a = lerpf(0.55, 0.28, depth_t_val)
	# Slightly softer as it shrinks high up.
	_shadow.modulate.a *= lerpf(1.0, 0.7, 1.0 - width_mul)


func _ensure_shadow_circle() -> void:
	if _shadow == null or not (_shadow is Polygon2D):
		return
	var poly := _shadow as Polygon2D
	if poly.polygon.size() >= 12:
		return
	poly.polygon = _unit_circle_poly(air_shadow_radius, 20)


static func _unit_circle_poly(radius: float, verts: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(verts, 8)
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func debug_snapshot() -> Dictionary:
	var screen_x := logical_x
	var surface_screen_h := surface_height * visual_scale()
	if _level:
		var p: Dictionary = _level.project_surface(logical_x, logical_z, surface_height)
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
		"airborne": airborne,
		"support_height": support_height,
	}
