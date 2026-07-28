class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder + shadow from LogicalPose / PseudoDepthBody.

@export var depth_path: NodePath = NodePath("../../RampLevel/../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../../Player")

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
	box.size = Vector3(18, 40, 14)
	_body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.25, 0.45, 1.0)
	_body.material_override = mat
	add_child(_body)

	_shadow = MeshInstance3D.new()
	_shadow.name = "AirShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 14.0
	disc.bottom_radius = 14.0
	disc.height = 1.0
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
	global_position = WorldSpace.logical_to_world(pose.logical_x, pose.logical_z, pose.feet_height)
	# 2D tilt is Y-down clockwise-positive; 3D Z-roll is Y-up — negate to match pipe lean.
	rotation = Vector3(0.0, 0.0, -pose.surface_tilt)
	# Facing +logical X is screen-right after WorldSpace X mirror; keep mesh facing that way.
	var face := signf(pose.facing_h) if pose.facing_h != 0.0 else 1.0
	scale = Vector3(-face, 1.0, 1.0)
	if _shadow:
		if pose.airborne:
			_shadow.visible = true
			_shadow.global_position = WorldSpace.logical_to_world(
				pose.logical_x, pose.logical_z, pose.support_height + 0.5
			)
			_shadow.rotation = Vector3.ZERO
			_shadow.scale = Vector3.ONE
		else:
			_shadow.visible = false


func _physics_process(_delta: float) -> void:
	if _depth == null:
		_resolve_refs()
	if _depth == null:
		return
	var pose := LogicalPose.new()
	var facing := 1.0
	if _player != null:
		var fh = _player.get("facing_h")
		if typeof(fh) == TYPE_STRING:
			facing = 1.0 if str(fh) == "r" else -1.0
		elif typeof(fh) == TYPE_FLOAT or typeof(fh) == TYPE_INT:
			facing = float(fh)
	pose.copy_from_depth(_depth, facing, 0)
	apply_pose(pose)
