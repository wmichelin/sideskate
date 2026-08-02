class_name LogicalPosePresenter3D
extends Node3D
## Drives a 3D skater placeholder from LogicalPose / PseudoDepthBody.
## Simulation stays on physics ticks; visible pose interpolates on render frames.
## Fall: presentation RigidBodies bounded by sim support/impact planes.

const CollisionLayersScript := preload("res://scripts/physics/collision_layers.gd")

@export var depth_path: NodePath = NodePath("../Player/PseudoDepthBody")
@export var player_path: NodePath = NodePath("../Player")
## Placeholder skater size in meters. Root origin is the feet / ground contact.
@export var body_size: Vector3 = Vector3(0.18, 0.40, 0.14)
@export var board_size: Vector3 = Vector3(0.40, 0.05, 0.14)
## Keep the board bottom this far above the feet/support plane (avoids floor Z-fight).
@export_range(0.0, 0.05, 0.001) var board_clearance: float = 0.012
## Optional skinned skater (GLB). When set, replaces the orange box while riding.
@export var skater_mesh: PackedScene
@export_group("Skater Look")
## Authored standing height of `skater_mesh` in meters (bind/export scale).
@export_range(0.1, 3.0, 0.01) var skater_height_m: float = 1.7
## Visual scale (1 = ~0.55 m on the board). Fall box still uses `body_size`.
@export_range(0.25, 3.0, 0.01) var skater_scale: float = 1.0
## Extra yaw so mesh forward matches board nose (+X).
@export_range(-PI, PI, 0.01) var skater_yaw_offset: float = -PI * 0.5
@export_group("Skater Ollie Anim")
## Clip name inside the skater GLB (FreeMoCap export defaults to `kickflip`).
@export var skater_ollie_anim: String = "kickflip"
## Playback rate for the ollie clip. Higher = faster (1 = authored, 4 = 4×).
@export_range(0.05, 12.0, 0.05) var skater_anim_speed: float = 2.5
## Stop and return to idle after this fraction of the clip (1 = full).
@export_range(0.05, 1.0, 0.01) var skater_anim_end_frac: float = 0.45

const _SKATER_BASE_DISPLAY_HEIGHT_M := 0.55

var _body: MeshInstance3D
var _facing_mark: MeshInstance3D
var _board: Node3D
var _skater: Node3D
var _skater_anim: AnimationPlayer
var _skater_anim_playing: bool = false
var _skater_anim_end_sec: float = 0.0
var _skater_on_fall: bool = false
var _rider_fall: FallBoxConstraint
var _board_fall: FallBoxConstraint
var _depth: PseudoDepthBody
var _player: Node
var _was_falling: bool = false
var _body_mat: StandardMaterial3D
var _board_fall_mat: StandardMaterial3D


func _ready() -> void:
	_build_meshes()
	_resolve_refs()
	call_deferred("_reparent_fall_bodies")


func _reparent_fall_bodies() -> void:
	if not is_inside_tree():
		return
	var world := get_parent()
	if world == null:
		return
	for body in _fall_bodies():
		if body.get_parent() != self:
			continue
		var keep: Transform3D = body.global_transform
		remove_child(body)
		world.add_child(body)
		body.global_transform = keep


func _fall_bodies() -> Array:
	var bodies: Array = []
	if _rider_fall != null:
		bodies.append(_rider_fall)
	if _board_fall != null:
		bodies.append(_board_fall)
	return bodies


func _build_meshes() -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(1.0, 0.45, 0.08, 1.0)

	_body = MeshInstance3D.new()
	_body.name = "SkaterBody"
	var box := BoxMesh.new()
	box.size = body_size
	_body.mesh = box
	# Stand on the board top (board floats board_clearance above support).
	_body.position = Vector3(0.0, board_clearance + board_size.y + body_size.y * 0.5, 0.0)
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

	_mount_skater_mesh()

	_board = Node3D.new()
	_board.name = "Board"
	# Board bottom stays board_clearance above the feet/support plane.
	_board.position = Vector3(0.0, board_clearance + board_size.y * 0.5, 0.0)
	add_child(_board)

	var board_half_size := Vector3(board_size.x * 0.5, board_size.y, board_size.z)
	var nose := MeshInstance3D.new()
	nose.name = "BoardNose"
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = board_half_size
	nose.mesh = nose_mesh
	nose.position = Vector3(board_size.x * 0.25, 0.0, 0.0)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.9, 0.12, 0.12, 1.0)
	nose.material_override = nose_mat
	_board.add_child(nose)

	var tail := MeshInstance3D.new()
	tail.name = "BoardTail"
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = board_half_size
	tail.mesh = tail_mesh
	tail.position = Vector3(-board_size.x * 0.25, 0.0, 0.0)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.15, 0.35, 0.95, 1.0)
	tail.material_override = tail_mat
	_board.add_child(tail)

	_board_fall_mat = StandardMaterial3D.new()
	_board_fall_mat.albedo_color = Color(0.09, 0.10, 0.12, 1.0)

	_rider_fall = _make_fall_body("RiderFall", body_size, 4.0, _body_mat, true)
	_board_fall = _make_fall_body("BoardFall", board_size, 1.0, _board_fall_mat, false)
	_board_fall.linear_damp = 0.8
	_board_fall.angular_damp = 0.4
	# World-space siblings so the moving pose root doesn't drag the rigid bodies.
	add_child(_rider_fall)
	add_child(_board_fall)


func _mount_skater_mesh() -> void:
	_skater = null
	if skater_mesh == null:
		return
	var inst := skater_mesh.instantiate()
	if not (inst is Node3D):
		inst.queue_free()
		return
	_skater = inst as Node3D
	_skater.name = "SkaterCharacter"
	# Feet at origin in the GLB — stand on the board top.
	_skater.position = Vector3(0.0, board_clearance + board_size.y, 0.0)
	var s := _skater_uniform_scale()
	_skater.scale = Vector3(s, s, s)
	_skater.rotation = Vector3(0.0, skater_yaw_offset, 0.0)
	add_child(_skater)
	_body.visible = false
	if _facing_mark != null:
		_facing_mark.visible = false
	_configure_skater_animation(_skater)
	_polish_skater_meshes(_skater)


func _skater_uniform_scale() -> float:
	return (_SKATER_BASE_DISPLAY_HEIGHT_M * skater_scale) / maxf(skater_height_m, 0.01)


func _polish_skater_meshes(root: Node) -> void:
	## Ensure imported surfaces cast shadows and read a bit cleaner in Forward+.
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for child in n.get_children():
			stack.append(child)


func _configure_skater_animation(root: Node) -> void:
	_skater_anim = null
	_skater_anim_playing = false
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(root, players)
	if players.is_empty():
		return
	_skater_anim = players[0]
	if not _skater_anim.animation_finished.is_connected(_on_skater_anim_finished):
		_skater_anim.animation_finished.connect(_on_skater_anim_finished)
	_hold_skater_idle()


func _skater_clip_name() -> String:
	if _skater_anim == null:
		return ""
	if _skater_anim.has_animation(skater_ollie_anim):
		return skater_ollie_anim
	var clips := _skater_anim.get_animation_list()
	return clips[0] if not clips.is_empty() else ""


func _hold_skater_idle() -> void:
	if _skater_anim == null:
		return
	var clip := _skater_clip_name()
	if clip.is_empty():
		return
	_skater_anim_playing = false
	_skater_anim_end_sec = 0.0
	_skater_anim.speed_scale = 1.0
	_skater_anim.play(clip)
	_skater_anim.seek(0.0, true)
	_skater_anim.pause()


func _play_skater_ollie() -> void:
	if _skater_anim == null:
		return
	var clip := _skater_clip_name()
	if clip.is_empty():
		return
	var anim := _skater_anim.get_animation(clip)
	var length := anim.length if anim != null else 0.0
	_skater_anim_end_sec = length * clampf(skater_anim_end_frac, 0.05, 1.0)
	_skater_anim_playing = true
	_skater_anim.speed_scale = maxf(skater_anim_speed, 0.01)
	_skater_anim.play(clip)
	_skater_anim.seek(0.0, true)


func _on_skater_anim_finished(_anim_name: StringName) -> void:
	if _skater_anim_playing:
		_hold_skater_idle()


func _update_skater_anim_cutoff() -> void:
	if not _skater_anim_playing or _skater_anim == null:
		return
	if _skater_anim_end_sec <= 0.0:
		return
	if _skater_anim.current_animation_position >= _skater_anim_end_sec - 0.0001:
		_hold_skater_idle()


func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, out)


func _make_fall_body(
	p_name: String, size: Vector3, mass_value: float, mat: Material, with_mark: bool
) -> FallBoxConstraint:
	var body := FallBoxConstraint.new()
	body.name = p_name
	body.box_size = size
	body.mass = mass_value
	body.linear_damp = 0.6
	body.angular_damp = 0.25
	body.continuous_cd = true
	body.collision_layer = CollisionLayersScript.bit(CollisionLayersScript.RAGDOLL)
	body.collision_mask = (
		CollisionLayersScript.bit(CollisionLayersScript.WORLD_RIDE)
		| CollisionLayersScript.bit(CollisionLayersScript.WORLD_WALL)
		| CollisionLayersScript.bit(CollisionLayersScript.PLAYABLE_BOUNDS)
	)
	body.freeze = true
	body.visible = false
	var fall_cs := CollisionShape3D.new()
	var fall_shape := BoxShape3D.new()
	fall_shape.size = size
	fall_cs.shape = fall_shape
	body.add_child(fall_cs)
	var fall_mesh := MeshInstance3D.new()
	fall_mesh.name = "FallMesh"
	var fall_box_mesh := BoxMesh.new()
	fall_box_mesh.size = size
	fall_mesh.mesh = fall_box_mesh
	fall_mesh.material_override = mat
	body.add_child(fall_mesh)
	if with_mark:
		var fall_mark := MeshInstance3D.new()
		fall_mark.name = "FallFacingMark"
		fall_mark.mesh = _make_facing_triangle(0.07, 0.09, 0.04)
		var fall_fmat := StandardMaterial3D.new()
		fall_fmat.albedo_color = Color(0.98, 0.85, 0.2, 1.0)
		fall_fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fall_mark.material_override = fall_fmat
		fall_mark.position = Vector3(size.x * 0.5 + 0.01, 0.0, 0.0)
		body.add_child(fall_mark)
	return body


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

	if falling and _rider_fall != null and not _rider_fall.freeze:
		_set_pose_meshes_visible(false)
		rotation = Vector3.ZERO
	else:
		_set_pose_meshes_visible(true)
		rotation = Vector3(0.0, 0.0, tilt)

	if is_inside_tree():
		global_position = world_position
	else:
		position = world_position
	scale = Vector3.ONE

	# Board above support plane; rider stands on the board top.
	var board_pos := Vector3(0.0, board_clearance + board_size.y * 0.5, 0.0)
	var body_pos := Vector3(0.0, board_clearance + board_size.y + body_size.y * 0.5, 0.0)
	var skater_pos := Vector3(0.0, board_clearance + board_size.y, 0.0)
	var body_basis_yaw := Vector3(0.0, body_yaw, 0.0)
	var body_scl := Vector3(-face, 1.0, 1.0)
	# Skinned mesh: yaw-turn to face (no X-mirror — that inverted the character).
	var skater_yaw := body_yaw + skater_yaw_offset + (PI if face < 0.0 else 0.0)
	var skater_uniform := _skater_uniform_scale()
	# While ragdolling, skater is parented to RiderFall — don't overwrite its transform.
	if _skater != null and _skater.visible and not _skater_on_fall:
		_skater.scale = Vector3(skater_uniform, skater_uniform, skater_uniform)
		_skater.position = skater_pos
		_skater.rotation = Vector3(0.0, skater_yaw, 0.0)
	elif _body and _body.visible and not _skater_on_fall:
		_body.scale = body_scl
		_body.position = body_pos
		_body.rotation = body_basis_yaw
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if _facing_mark != null:
			_facing_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _board and _board.visible:
		_board.scale = Vector3.ONE
		_board.position = board_pos
		_board.rotation = Vector3(0.0, pose.board_yaw + pose.depth_turn_yaw, 0.0)


func _set_pose_meshes_visible(is_visible: bool) -> void:
	# Skater stays visible on RiderFall during crash; only the ride pose root hides.
	if _skater != null and not _skater_on_fall:
		_skater.visible = is_visible
		if _body:
			_body.visible = false
	elif _body and not _skater_on_fall:
		_body.visible = is_visible
	if _board:
		_board.visible = is_visible


func _set_rider_fall_proxy_visible(is_visible: bool) -> void:
	if _rider_fall == null:
		return
	var fall_mesh := _rider_fall.get_node_or_null("FallMesh") as Node3D
	if fall_mesh != null:
		fall_mesh.visible = is_visible
	var fall_mark := _rider_fall.get_node_or_null("FallFacingMark") as Node3D
	if fall_mark != null:
		fall_mark.visible = is_visible


func _attach_skater_to_fall() -> void:
	if _skater == null or _rider_fall == null or _skater_on_fall:
		return
	_hold_skater_idle()
	var parent := _skater.get_parent()
	if parent != null:
		parent.remove_child(_skater)
	_rider_fall.add_child(_skater)
	var s := _skater_uniform_scale()
	_skater.scale = Vector3(s, s, s)
	# Feet at bottom of the fall box; yaw matches ride offset inside tumble basis.
	_skater.position = Vector3(0.0, -body_size.y * 0.5, 0.0)
	_skater.rotation = Vector3(0.0, skater_yaw_offset, 0.0)
	_skater.visible = true
	_skater_on_fall = true
	_set_rider_fall_proxy_visible(false)


func _detach_skater_from_fall() -> void:
	if _skater == null or not _skater_on_fall:
		return
	var parent := _skater.get_parent()
	if parent != null:
		parent.remove_child(_skater)
	add_child(_skater)
	_skater_on_fall = false
	_skater.visible = true
	_hold_skater_idle()
	_set_rider_fall_proxy_visible(true)


func _start_fall_bodies(pose: LogicalPose, feet_world: Vector3) -> void:
	if (
		_rider_fall == null
		or _board_fall == null
		or not _rider_fall.is_inside_tree()
		or not _board_fall.is_inside_tree()
	):
		return
	var lean := 1.0
	if _player != null and _player.has_method("fall_lean_sign"):
		lean = float(_player.call("fall_lean_sign"))
	if absf(lean) < 0.001:
		lean = 1.0
	var support: Dictionary = {"point": feet_world, "normal": Vector3.UP}
	var impact: Dictionary = {}
	if _player != null and _player.has_method("fall_support_plane_world"):
		support = _player.call("fall_support_plane_world")
	if _player != null and _player.has_method("fall_impact_plane_world"):
		impact = _player.call("fall_impact_plane_world")
	for body in _fall_bodies():
		body.configure_planes(support, impact)
	var body_yaw := pose.facing_yaw + pose.depth_turn_yaw
	var face := signf(pose.facing_h) if pose.facing_h != 0.0 else 1.0
	var tilt := pose.surface_tilt
	var yaw := body_yaw + (PI if face < 0.0 else 0.0)
	var tip := tilt + lean * deg_to_rad(55.0)
	var basis := Basis.from_euler(Vector3(0.0, yaw, tip))
	var support_point: Vector3 = support.get("point", feet_world)
	var support_normal: Vector3 = support.get("normal", Vector3.UP)
	var impact_point: Vector3 = impact.get("point", Vector3.ZERO)
	var impact_normal: Vector3 = impact.get("normal", Vector3.ZERO)
	# Rider stood on the board top while riding — start tumble from that contact.
	var rider_feet := feet_world + basis * Vector3(0.0, board_clearance + board_size.y, 0.0)
	_rider_fall.global_transform = _rider_fall.transform_for_planes(
		rider_feet, basis, support_point, support_normal, impact_point, impact_normal
	)
	var vel := Vector3.ZERO
	if _player != null and _player.has_method("motion_world"):
		vel = (_player.call("motion_world", MotionVectors.Kind.ACTUAL) as Vector3).limit_length(8.0)
	_rider_fall.linear_velocity = vel
	_rider_fall.angular_velocity = basis * Vector3(0.0, 0.0, -lean * 8.0)
	_rider_fall.freeze = false
	_rider_fall.sleeping = false
	_rider_fall.visible = true
	_rider_fall.apply_impulse(
		basis * Vector3(lean * 1.4, 0.0, 0.0),
		basis * Vector3(0.0, body_size.y * 0.35, 0.0)
	)

	var board_yaw := pose.board_yaw + pose.depth_turn_yaw
	var board_basis := Basis.from_euler(Vector3(0.0, board_yaw, tilt + lean * deg_to_rad(25.0)))
	# Board bottom above the support/feet plane (same clearance as riding).
	var board_feet := feet_world + board_basis * Vector3(0.0, board_clearance, 0.0)
	_board_fall.global_transform = _board_fall.transform_for_planes(
		board_feet, board_basis, support_point, support_normal, impact_point, impact_normal
	)
	_board_fall.linear_velocity = vel * 0.85
	_board_fall.angular_velocity = board_basis * Vector3(0.0, lean * 3.0, -lean * 2.0)
	_board_fall.freeze = false
	_board_fall.sleeping = false
	_board_fall.visible = true
	_board_fall.apply_impulse(board_basis * Vector3(-lean * 0.6, 0.25, 0.0), Vector3.ZERO)
	_attach_skater_to_fall()
	_set_pose_meshes_visible(false)
	# RiderFall stays visible so the skinned mesh (child) renders while tumbling.
	_rider_fall.visible = true


func _stop_fall_bodies() -> void:
	_detach_skater_from_fall()
	for body in _fall_bodies():
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		body.sleeping = true
		body.visible = false
		body.configure_planes({})
	_set_pose_meshes_visible(true)


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
	_update_skater_anim_cutoff()
	apply_pose(_interpolated_pose())


func _physics_process(_delta: float) -> void:
	if _depth == null or _player == null:
		_resolve_refs()
	if (
		_player != null
		and _player.has_method("consume_ollie_pop")
		and bool(_player.call("consume_ollie_pop"))
	):
		_play_skater_ollie()
	var falling := (
		_player != null and _player.has_method("is_falling") and bool(_player.call("is_falling"))
	)
	if falling:
		if not _was_falling:
			_hold_skater_idle()
			var pose := _interpolated_pose()
			var feet := WorldSpace.logical_to_world(
				pose.logical_x, pose.logical_z, pose.feet_height
			)
			_start_fall_bodies(pose, feet)
		else:
			_refresh_fall_body_planes()
	elif _was_falling:
		_stop_fall_bodies()
	_was_falling = falling


func _refresh_fall_body_planes() -> void:
	if _player == null:
		return
	var support: Dictionary = {"point": Vector3.ZERO, "normal": Vector3.UP}
	var impact: Dictionary = {}
	if _player.has_method("fall_support_plane_world"):
		support = _player.call("fall_support_plane_world")
	if _player.has_method("fall_impact_plane_world"):
		impact = _player.call("fall_impact_plane_world")
	for body in _fall_bodies():
		if not body.freeze:
			body.configure_planes(support, impact)
