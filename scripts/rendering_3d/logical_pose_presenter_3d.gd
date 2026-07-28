class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder + shadow from LogicalPose / PseudoDepthBody.
## Simulation stays on physics ticks; visible pose interpolates on render frames.

@export var depth_path: NodePath = NodePath("../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../Player")
## Placeholder skater size in meters. Root origin is the feet / ground contact.
@export var body_size: Vector3 = Vector3(0.18, 0.40, 0.14)

var _body: MeshInstance3D
var _facing_mark: MeshInstance3D
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

	# Small triangle on the body +X side; body scale flip maps that to facing.
	_facing_mark = MeshInstance3D.new()
	_facing_mark.name = "FacingMark"
	_facing_mark.mesh = _make_facing_triangle(0.07, 0.09, 0.04)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.98, 0.85, 0.2, 1.0)
	fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_facing_mark.material_override = fmat
	_facing_mark.position = Vector3(body_size.x * 0.5 + 0.01, 0.0, 0.0)
	_body.add_child(_facing_mark)

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


## Flat triangle in the XZ plane pointing +X (tip), extruded slightly in Y.
func _make_facing_triangle(length: float, width: float, thickness: float) -> ArrayMesh:
	var tip := Vector3(length, 0.0, 0.0)
	var a := Vector3(0.0, 0.0, -width * 0.5)
	var b := Vector3(0.0, 0.0, width * 0.5)
	var y0 := -thickness * 0.5
	var y1 := thickness * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	# Top face (up)
	_tri(verts, norms, tip + Vector3(0, y1, 0), a + Vector3(0, y1, 0), b + Vector3(0, y1, 0), Vector3.UP)
	# Bottom face
	_tri(verts, norms, tip + Vector3(0, y0, 0), b + Vector3(0, y0, 0), a + Vector3(0, y0, 0), Vector3.DOWN)
	# Side faces
	_tri(verts, norms, tip + Vector3(0, y1, 0), tip + Vector3(0, y0, 0), a + Vector3(0, y0, 0), Vector3(0, 0, -1))
	_tri(verts, norms, tip + Vector3(0, y1, 0), a + Vector3(0, y0, 0), a + Vector3(0, y1, 0), Vector3(0, 0, -1))
	_tri(verts, norms, tip + Vector3(0, y1, 0), b + Vector3(0, y1, 0), b + Vector3(0, y0, 0), Vector3(0, 0, 1))
	_tri(verts, norms, tip + Vector3(0, y1, 0), b + Vector3(0, y0, 0), tip + Vector3(0, y0, 0), Vector3(0, 0, 1))
	_tri(verts, norms, a + Vector3(0, y1, 0), a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), Vector3(-1, 0, 0))
	_tri(verts, norms, a + Vector3(0, y1, 0), b + Vector3(0, y0, 0), b + Vector3(0, y1, 0), Vector3(-1, 0, 0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _tri(
	verts: PackedVector3Array,
	norms: PackedVector3Array,
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	n: Vector3,
) -> void:
	verts.append(p0)
	verts.append(p1)
	verts.append(p2)
	norms.append(n)
	norms.append(n)
	norms.append(n)


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
