class_name CameraRig3D
extends Node3D
## Orbit Camera3D following the interpolated logical skater pose (render frames).

@export var target_path: NodePath = NodePath("../PlayerVisual")
## Radial distance from focus (zoom).
@export var distance: float = 310.0
## Elevation angle in degrees. 0 = horizon behind; positive = above looking down.
@export var pitch_deg: float = 48.5
## Orbit yaw in degrees around the focus (0 = behind, looking +Z into the park).
@export var yaw_deg: float = 0.0
@export var fov_deg: float = 90.0
@export var look_ahead: float = 80.0
@export var screen_y_bias: float = 0.08
## Direct follow — no extra physics-step lag; presenter already interpolates.
@export var follow_smooth: float = 0.0

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


func set_follow_world(origin: Vector3) -> void:
	use_manual_origin = true
	_manual_origin = origin


func clear_manual_origin() -> void:
	use_manual_origin = false


func _process(delta: float) -> void:
	_cam.fov = fov_deg
	var focus := _focus_point()
	var desired := focus + _orbit_offset()
	if follow_smooth > 0.0:
		global_position = global_position.lerp(desired, clampf(follow_smooth * delta, 0.0, 1.0))
	else:
		global_position = desired
	var yaw := deg_to_rad(yaw_deg)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var look_at_pt := focus + forward * look_ahead + Vector3(0.0, screen_y_bias * distance, 0.0)
	var to_focus := look_at_pt - _cam.global_position
	# Avoid look_at singularity when orbiting over the poles (±90° pitch).
	var up := Vector3.UP
	if absf(to_focus.normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	if to_focus.length_squared() > 0.0001:
		_cam.look_at(look_at_pt, up)


func _focus_point() -> Vector3:
	if use_manual_origin:
		return _manual_origin
	if _target == null:
		_target = get_node_or_null(target_path) as Node3D
	if _target != null:
		return _target.global_position
	return Vector3.ZERO


func _orbit_offset() -> Vector3:
	var yaw := deg_to_rad(yaw_deg)
	var pitch := deg_to_rad(pitch_deg)
	# Spherical offset: pitch rotates from −Z toward +Y; yaw spins around up.
	var offset := Vector3(0.0, 0.0, -distance)
	offset = offset.rotated(Vector3.RIGHT, pitch)
	offset = offset.rotated(Vector3.UP, yaw)
	return offset


func calibration_error_px(level: RampLevel, samples: Array) -> float:
	## Max |2D project screen − Camera3D.unproject| over sample dicts {x,z,h}.
	if level == null or _cam == null:
		return INF
	var worst := 0.0
	for s in samples:
		var x := float(s.get("x", 0.0))
		var z := float(s.get("z", 0.0))
		var h := float(s.get("h", 0.0))
		var p2: Dictionary = level.project_surface(x, z, h)
		var screen_2d := Vector2(float(p2.screen_x), float(p2.ground_y) - float(p2.surface_screen_h))
		var world := WorldSpace.logical_to_world(x, z, h)
		var screen_3d: Vector2 = _cam.unproject_position(world)
		var err := screen_2d.distance_to(screen_3d)
		worst = maxf(worst, err)
	return worst
