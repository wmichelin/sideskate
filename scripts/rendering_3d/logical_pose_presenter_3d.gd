class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder from LogicalPose / PseudoDepthBody.
## Simulation stays on physics ticks; visible pose interpolates on render frames.
## Fall: kinematic tip from sim feet + fall_lean_sign (no RigidBody tunneling).

@export var depth_path: NodePath = NodePath("../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../Player")
## Placeholder skater size in meters. Root origin is the feet / ground contact.
@export var body_size: Vector3 = Vector3(0.18, 0.40, 0.14)

var _body: MeshInstance3D
var _facing_mark: MeshInstance3D
var _fall_tip: MeshInstance3D
var _depth: PseudoDepthBody
var _player: Node
var _was_falling: bool = false
var _body_mat: StandardMaterial3D


func _ready() -> void:
	_build_meshes()
	_resolve_refs()
	call_deferred("_reparent_fall_tip")


func _reparent_fall_tip() -> void:
	if _fall_tip == null or not is_inside_tree():
		return
	if _fall_tip.get_parent() != self:
		return
	var world := get_parent()
	if world == null:
		return
	var keep: Transform3D = _fall_tip.global_transform
	remove_child(_fall_tip)
	world.add_child(_fall_tip)
	_fall_tip.global_transform = keep


func _build_meshes() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.92, 0.25, 0.45, 1.0)

	_body = MeshInstance3D.new()
	_body.name = "SkaterBody"
	var box := BoxMesh.new()
	box.size = body_size
	_body.mesh = box
	# BoxMesh is centered on its origin; lift so the bottom edge sits on the feet.
	_body.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	_body.material_override = _body_mat
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

	_fall_tip = MeshInstance3D.new()
	_fall_tip.name = "FallTip"
	var fall_box_mesh := BoxMesh.new()
	fall_box_mesh.size = body_size
	_fall_tip.mesh = fall_box_mesh
	_fall_tip.material_override = _body_mat
	_fall_tip.visible = false
	# World-space sibling so tip pose is independent of the upright body root.
	add_child(_fall_tip)


## Flat triangle in the XZ plane pointing +X (tip), extruded slightly in Y.
func _make_facing_triangle(length: float, width: float, thickness: float) -> ArrayMesh:
	var tip := Vector3(length, 0.0, 0.0)
	var a := Vector3(0.0, 0.0, -width * 0.5)
	var b := Vector3(0.0, 0.0, width * 0.5)
	var y0 := -thickness * 0.5
	var y1 := thickness * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	_tri(verts, norms, tip + Vector3(0, y1, 0), a + Vector3(0, y1, 0), b + Vector3(0, y1, 0), Vector3.UP)
	_tri(verts, norms, tip + Vector3(0, y0, 0), b + Vector3(0, y0, 0), a + Vector3(0, y0, 0), Vector3.DOWN)
	_tri(verts, norms, tip + Vector3(0, y1, 0), tip + Vector3(0, y0, 0), a + Vector3(0, y0, 0), Vector3(0, 0, -1))
	_tri(verts, norms, tip + Vector3(0, y1, 0), a + Vector3(0, y0, 0), a + Vector3(0, y1, 0), Vector3(0, 0, -1))
	_tri(verts, norms, tip + Vector3(0, y1, 0), b + Vector3(0, y1, 0), tip + Vector3(0, y0, 0), Vector3(0, 0, 1))
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
	var world_position := WorldSpace.logical_to_world(
		pose.logical_x, pose.logical_z, pose.feet_height
	)
	var falling := (
		_player != null and _player.has_method("is_falling") and bool(_player.call("is_falling"))
	)
	var body_yaw := pose.facing_yaw + pose.depth_turn_yaw
	var tilt := pose.surface_tilt
	var face := signf(pose.facing_h) if pose.facing_h != 0.0 else 1.0

	if falling:
		if _body:
			_body.visible = false
		rotation = Vector3.ZERO
		if is_inside_tree():
			global_position = world_position
		else:
			position = world_position
		scale = Vector3.ONE
		_pose_fall_tip(world_position, body_yaw, face, tilt)
		return

	if _fall_tip != null:
		_fall_tip.visible = false
	if _body:
		_body.visible = true
	rotation = Vector3(0.0, 0.0, tilt)

	if is_inside_tree():
		global_position = world_position
	else:
		position = world_position
	scale = Vector3.ONE

	var body_pos := Vector3(0.0, body_size.y * 0.5, 0.0)
	var body_basis_yaw := Vector3(0.0, body_yaw, 0.0)
	var body_scl := Vector3(-face, 1.0, 1.0)
	if _body and _body.visible:
		_body.scale = body_scl
		_body.position = body_pos
		_body.rotation = body_basis_yaw
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _facing_mark != null:
			_facing_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pose_fall_tip(feet_world: Vector3, body_yaw: float, face: float, tilt: float) -> void:
	if _fall_tip == null:
		return
	var lean := 1.0
	if _player != null and _player.has_method("fall_lean_sign"):
		lean = float(_player.call("fall_lean_sign"))
	var anim := 1.0
	if _player != null and _player.has_method("fall_anim_frac"):
		anim = float(_player.call("fall_anim_frac"))
	var yaw := body_yaw + (PI if face < 0.0 else 0.0)
	var tip_ang := tilt + lean * deg_to_rad(55.0) * clampf(anim, 0.0, 1.0)
	var basis := Basis.from_euler(Vector3(0.0, yaw, tip_ang))
	var center := feet_world + basis * Vector3(0.0, body_size.y * 0.5, 0.0)
	var xf := Transform3D(basis, center)
	if _fall_tip.is_inside_tree():
		_fall_tip.global_transform = xf
	else:
		_fall_tip.transform = xf
	_fall_tip.visible = true


func _build_live_pose() -> LogicalPose:
	var pose := LogicalPose.new()
	var facing := 1.0
	var yaw := 0.0
	if _player != null:
		var fh = _player.get("visual_facing_h")
		if typeof(fh) == TYPE_STRING:
			facing = 1.0 if str(fh) == "r" else -1.0
		elif typeof(fh) == TYPE_FLOAT or typeof(fh) == TYPE_INT:
			facing = float(fh)
		var fy = _player.get("facing_yaw")
		if typeof(fy) == TYPE_FLOAT or typeof(fy) == TYPE_INT:
			yaw = float(fy)
	if _depth != null:
		pose.copy_from_depth(_depth, facing, 0)
	pose.facing_yaw = yaw
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


func _physics_process(_delta: float) -> void:
	if _depth == null or _player == null:
		_resolve_refs()
	var falling := (
		_player != null and _player.has_method("is_falling") and bool(_player.call("is_falling"))
	)
	if falling == _was_falling:
		return
	if not falling and _fall_tip != null:
		_fall_tip.visible = false
		if _body:
			_body.visible = true
	_was_falling = falling
