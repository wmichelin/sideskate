class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder from LogicalPose / PseudoDepthBody.
## Simulation stays on physics ticks; visible pose interpolates on render frames.

@export var depth_path: NodePath = NodePath("../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../Player")
## Placeholder skater size in meters. Root origin is the feet / ground contact.
@export var body_size: Vector3 = Vector3(0.18, 0.40, 0.14)

var _body: MeshInstance3D
var _facing_mark: MeshInstance3D
## Invisible caster while fallen — sits slightly higher so CSM isn't coplanar/striped.
var _fall_shadow_proxy: MeshInstance3D
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

	_fall_shadow_proxy = MeshInstance3D.new()
	_fall_shadow_proxy.name = "FallShadowProxy"
	var pbox := BoxMesh.new()
	pbox.size = body_size
	_fall_shadow_proxy.mesh = pbox
	_fall_shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_fall_shadow_proxy.visible = false
	add_child(_fall_shadow_proxy)

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
	var world_position := WorldSpace.logical_to_world(
		pose.logical_x, pose.logical_z, pose.feet_height
	)
	var falling := (
		_player != null and _player.has_method("is_falling") and bool(_player.call("is_falling"))
	)
	var body_yaw := pose.facing_yaw + pose.depth_turn_yaw
	var tilt := pose.surface_tilt
	# Fall side-lean pivots at the feet into the ride plane — lift along the
	# *support* normal (ramp/pipe), not only world Y, or we bury into slopes.
	if falling:
		world_position += _lean_clearance_offset(tilt, body_yaw, pose.support_tilt)
	if is_inside_tree():
		global_position = world_position
	else:
		position = world_position
	scale = Vector3.ONE
	# Surface lean pivots at the feet. The apex facing change pivots separately
	# around the body center's local Y axis, keeping the skater's lean while
	# turning through depth.
	rotation = Vector3(0.0, 0.0, tilt)
	var face := signf(pose.facing_h) if pose.facing_h != 0.0 else 1.0
	var body_pos := Vector3(0.0, body_size.y * 0.5, 0.0)
	var body_basis_yaw := Vector3(0.0, body_yaw, 0.0)
	var body_scl := Vector3(-face, 1.0, 1.0)
	if _body:
		# Facing +logical X is screen-right after WorldSpace X mirror.
		_body.scale = body_scl
		_body.position = body_pos
		_body.rotation = body_basis_yaw
		# Visual sits on the floor; casting from that pose stripes. Proxy casts instead.
		_body.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if falling
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
		if _facing_mark != null:
			_facing_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _fall_shadow_proxy != null:
		if falling:
			# Extra along support normal so the cast clears the contact plane.
			const PROXY_EXTRA := 0.07
			var n := _support_normal(pose.support_tilt)
			# Proxy is a child of the tilted root — convert world normal delta to local.
			var local_extra := Vector3(
				n.x * cos(tilt) + n.y * sin(tilt),
				-n.x * sin(tilt) + n.y * cos(tilt),
				0.0
			) * PROXY_EXTRA
			_fall_shadow_proxy.position = body_pos + local_extra
			_fall_shadow_proxy.rotation = body_basis_yaw
			_fall_shadow_proxy.scale = body_scl
			_fall_shadow_proxy.visible = true
			_fall_shadow_proxy.cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			)
		else:
			_fall_shadow_proxy.visible = false
			_fall_shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Presentation up after a Z tilt of `support_tilt` — contact-plane normal.
func _support_normal(support_tilt: float) -> Vector3:
	return Vector3(-sin(support_tilt), cos(support_tilt), 0.0)


## Offset so a fall-tilted body AABB clears the support plane (floor / ramp / pipe).
func _lean_clearance_offset(fall_tilt: float, body_yaw: float, support_tilt: float) -> Vector3:
	var n := _support_normal(support_tilt)
	var hx := body_size.x * 0.5
	var hy := body_size.y * 0.5
	var hz := body_size.z * 0.5
	var cy := body_size.y * 0.5
	var yaw_c := cos(body_yaw)
	var yaw_s := sin(body_yaw)
	var s := sin(fall_tilt)
	var c := cos(fall_tilt)
	var min_d := INF
	for lx in [-hx, hx]:
		for ly in [-hy, hy]:
			for lz in [-hz, hz]:
				var rx: float = lx * yaw_c + lz * yaw_s
				var ry: float = ly + cy
				# Root fall tilt about Z, then measure against support normal.
				var wx: float = rx * c - ry * s
				var wy: float = rx * s + ry * c
				var d: float = wx * n.x + wy * n.y
				min_d = minf(min_d, d)
	var lift := maxf(0.0, -min_d) + 0.02
	return n * lift


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
