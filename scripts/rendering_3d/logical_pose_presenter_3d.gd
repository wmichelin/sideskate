class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder + shadow from LogicalPose / PseudoDepthBody.
## Simulation stays on physics ticks; visible pose interpolates on render frames.

@export var depth_path: NodePath = NodePath("../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../Player")
## Placeholder skater size in meters. Root origin is the feet / ground contact.
@export var body_size: Vector3 = Vector3(0.18, 0.40, 0.14)

var _body: MeshInstance3D
var _shadow: MeshInstance3D
var _depth: PseudoDepthBody
var _player: Node


func _ready() -> void:
	_build_meshes()
	_resolve_refs()


func _build_meshes() -> void:
	_body = MeshInstance3D.new()
	_body.name = "SkaterBody"
	var box := BoxMesh.new()
	box.size = body_size
	_body.mesh = box
	# BoxMesh is centered on its origin; lift so the bottom edge sits on the feet.
	_body.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.25, 0.45, 1.0)
	_body.material_override = mat
	add_child(_body)

	_shadow = MeshInstance3D.new()
	_shadow.name = "AirShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.14
	disc.bottom_radius = 0.14
	disc.height = 0.01
	disc.radial_segments = 16
	_shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = sm
	_shadow.visible = false
	add_child(_shadow)


func _resolve_refs() -> void:
	_depth = get_node_or_null(depth_path) as PseudoDepthBody
	_player = get_node_or_null(player_path)


func apply_pose(pose: LogicalPose) -> void:
	# Root = feet contact. Body mesh is offset up by half-height so its bottom
	# stays on the surface even when body_size.y changes; tilt pivots at the feet.
	global_position = WorldSpace.logical_to_world(pose.logical_x, pose.logical_z, pose.feet_height)
	scale = Vector3.ONE
	# World X = −logical X mirrors the park vs 2D. CanvasItem tilt leans correctly
	# on screen in 2D; after the mirror the same signed tilt must be applied as
	# +Z roll (not negated) so the skater still leans into the pipe wall.
	rotation = Vector3(0.0, 0.0, pose.surface_tilt)
	var face := signf(pose.facing_h) if pose.facing_h != 0.0 else 1.0
	if _body:
		# Facing +logical X is screen-right after WorldSpace X mirror.
		_body.scale = Vector3(-face, 1.0, 1.0)
		_body.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	if _shadow:
		if pose.airborne:
			_shadow.visible = true
			_shadow.global_position = WorldSpace.logical_to_world(
				pose.logical_x, pose.logical_z, pose.support_height
			) + Vector3(0.0, 0.005, 0.0)
			_shadow.rotation = Vector3.ZERO
			_shadow.scale = Vector3.ONE
		else:
			_shadow.visible = false


func _build_live_pose() -> LogicalPose:
	var pose := LogicalPose.new()
	var facing := 1.0
	if _player != null:
		var fh = _player.get("facing_h")
		if typeof(fh) == TYPE_STRING:
			facing = 1.0 if str(fh) == "r" else -1.0
		elif typeof(fh) == TYPE_FLOAT or typeof(fh) == TYPE_INT:
			facing = float(fh)
	if _depth != null:
		pose.copy_from_depth(_depth, facing, 0)
	return pose


func _interpolated_pose() -> LogicalPose:
	if _player != null and bool(_player.get("_pose_snap_ready")):
		var prev = _player.get("_pose_prev")
		var curr = _player.get("_pose_curr")
		if prev != null and curr != null:
			var frac := Engine.get_physics_interpolation_fraction()
			return LogicalPose.lerp_poses(prev, curr, frac)
	return _build_live_pose()


func _process(_delta: float) -> void:
	if _depth == null or _player == null:
		_resolve_refs()
	apply_pose(_interpolated_pose())
