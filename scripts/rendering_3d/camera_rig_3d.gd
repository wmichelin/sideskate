class_name CameraRig3D
extends Node3D
## Fixed oblique Camera3D following the logical skater pose.

@export var target_path: NodePath = NodePath("../PlayerVisual")
@export var distance: float = 900.0
@export var height: float = 480.0
@export var pitch_deg: float = -42.0
@export var fov_deg: float = 50.0
@export var look_ahead: float = 80.0
@export var screen_y_bias: float = 0.08
@export var follow_smooth: float = 14.0

var _cam: Camera3D
var _target: Node3D
var _manual_origin: Vector3 = Vector3.ZERO
var use_manual_origin: bool = false


func _ready() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.current = true
	_cam.fov = fov_deg
	add_child(_cam)
	_target = get_node_or_null(target_path) as Node3D
	_apply_local_offset()


func set_follow_world(origin: Vector3) -> void:
	use_manual_origin = true
	_manual_origin = origin


func clear_manual_origin() -> void:
	use_manual_origin = false


func _physics_process(delta: float) -> void:
	_cam.fov = fov_deg
	_apply_local_offset()
	var focus := _focus_point()
	var desired := focus + _offset_world()
	global_position = global_position.lerp(desired, clampf(follow_smooth * delta, 0.0, 1.0))
	var look_at_pt := focus + Vector3(0.0, screen_y_bias * height, look_ahead)
	_cam.look_at(look_at_pt, Vector3.UP)


func _focus_point() -> Vector3:
	if use_manual_origin:
		return _manual_origin
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		return _target.global_position
	return Vector3.ZERO


func _offset_world() -> Vector3:
	# Behind (−Z) and above (+Y); pitch applied via look_at, not offset alone.
	return Vector3(0.0, height, -distance)


func _apply_local_offset() -> void:
	_cam.position = Vector3.ZERO
	_cam.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)


func calibration_error_px(level: RampLevel, samples: Array) -> float:
	## Max |2D project screen − Camera3D.unproject| over sample dicts {x,z,h}.
	if level == null or _cam == null:
		return INF
	var worst := 0.0
	var vp := get_viewport().get_visible_rect().size
	for s in samples:
		var x := float(s.get("x", 0.0))
		var z := float(s.get("z", 0.0))
		var h := float(s.get("h", 0.0))
		var p2: Dictionary = level.project_surface(x, z, h)
		var screen_2d := Vector2(float(p2.screen_x), float(p2.ground_y) - float(p2.surface_screen_h))
		var world := WorldSpace.logical_to_world(x, z, h)
		var screen_3d: Vector2 = _cam.unproject_position(world)
		# Normalize both into viewport pixel space roughly.
		var err := screen_2d.distance_to(screen_3d)
		worst = maxf(worst, err)
	return worst
