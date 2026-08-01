extends RefCounted
## LogicalPose render-frame lerp helpers.

const _PlayerScript := preload("res://scripts/player.gd")


func run() -> bool:
	return (
		_lerp_midpoint()
		and _lerp_flags()
		and _centered_y_turn_presentation()
		and _board_yaw_tracker_rules()
		and _board_yaw_depth_turn_not_persisted()
		and _player_pose_snapshots_track_board_yaw()
		and _fall_box_stays_above_support_planes()
		and _board_fall_box_stays_above_support_planes()
		and _fall_box_stays_on_impact_approach_side()
		and _presenter_builds_dual_fall_bodies()
		and _fall_tracking_defaults_to_rider_fall()
		and _fall_camera_tracks_x_locks_yz()
	)


func _lerp_midpoint() -> bool:
	var a := LogicalPose.new()
	a.logical_x = 0.0
	a.logical_z = 10.0
	a.feet_height = 100.0
	a.support_height = 0.0
	a.surface_tilt = 0.0
	var b := LogicalPose.new()
	b.logical_x = 100.0
	b.logical_z = 30.0
	b.feet_height = 200.0
	b.support_height = 50.0
	b.surface_tilt = PI * 0.5
	b.depth_turn_yaw = 0.4
	a.board_yaw = 0.0
	b.board_yaw = PI
	var mid := LogicalPose.lerp_poses(a, b, 0.5)
	if absf(mid.logical_x - 50.0) > 0.01:
		push_error("lerp x: %s" % mid.logical_x)
		return false
	if absf(mid.feet_height - 150.0) > 0.01:
		push_error("lerp feet: %s" % mid.feet_height)
		return false
	if absf(mid.logical_z - 20.0) > 0.01:
		push_error("lerp z: %s" % mid.logical_z)
		return false
	if absf(mid.depth_turn_yaw - 0.2) > 0.01:
		push_error("lerp depth turn: %s" % mid.depth_turn_yaw)
		return false
	# lerp_angle(0, PI, 0.5) is ±PI/2 on Godot 4.7 (equal-length shortest paths).
	var half_turn := PI * 0.5
	if (
		absf(angle_difference(mid.board_yaw, half_turn)) > 0.01
		and absf(angle_difference(mid.board_yaw, -half_turn)) > 0.01
	):
		push_error("lerp board_yaw: %s" % mid.board_yaw)
		return false
	return true


func _lerp_flags() -> bool:
	var a := LogicalPose.new()
	a.airborne = false
	a.facing_h = -1.0
	a.active_layer = 0
	var b := LogicalPose.new()
	b.airborne = true
	b.facing_h = 1.0
	b.active_layer = 1
	var early := LogicalPose.lerp_poses(a, b, 0.49)
	if early.airborne or early.facing_h > 0.0 or early.active_layer != 0:
		push_error("u<0.5 must keep a flags")
		return false
	var late := LogicalPose.lerp_poses(a, b, 0.5)
	if not late.airborne or late.facing_h < 0.0 or late.active_layer != 1:
		push_error("u>=0.5 must take b flags")
		return false
	return true


func _centered_y_turn_presentation() -> bool:
	# Completed turn and canonical settled-facing are equivalent; interpolation
	# must not animate a second rotation during their handoff.
	var turned := LogicalPose.new()
	turned.facing_h = -1.0
	turned.facing_yaw = -PI
	var settled := LogicalPose.new()
	settled.facing_h = 1.0
	settled.facing_yaw = 0.0
	var handoff := LogicalPose.lerp_poses(turned, settled, 0.1)
	if handoff.facing_h < 0.0 or absf(handoff.facing_yaw) > 0.01:
		push_error("Y-turn handoff must canonicalize without a second turn")
		return false

	# Surface lean pivots at feet; local-Y turn pivots independently at body center.
	var presenter := LogicalPosePresenter3D.new()
	presenter._build_meshes()
	var body := presenter.get_node_or_null("SkaterBody") as MeshInstance3D
	if body == null:
		push_error("Y-turn presentation: missing body")
		presenter.free()
		return false
	var mat := (body.material_override as StandardMaterial3D)
	if mat == null or mat.albedo_color.r < 0.8 or mat.albedo_color.g < 0.3:
		push_error("rider must be orange placeholder")
		presenter.free()
		return false
	var pose := LogicalPose.new()
	pose.surface_tilt = PI * 0.5
	pose.facing_h = -1.0
	pose.facing_yaw = -PI * 0.5
	pose.depth_turn_yaw = 0.2
	presenter.apply_pose(pose)
	if absf(presenter.rotation.z - pose.surface_tilt) > 0.01:
		push_error("Y-turn presentation: turn incorrectly changed feet pivot")
		presenter.free()
		return false
	if absf(body.rotation.y - (pose.facing_yaw + pose.depth_turn_yaw)) > 0.01:
		push_error("Y-turn presentation: apex and depth turns must share local Y")
		presenter.free()
		return false
	var expect_body_y := (
		presenter.board_clearance + presenter.board_size.y + presenter.body_size.y * 0.5
	)
	if absf(body.position.y - expect_body_y) > 0.001:
		push_error("Y-turn presentation: body should stand on board top, got %s" % body.position.y)
		presenter.free()
		return false
	var board := presenter.get_node_or_null("Board") as Node3D
	if board == null:
		push_error("Y-turn presentation: missing Board")
		presenter.free()
		return false
	var board_bottom := board.position.y - presenter.board_size.y * 0.5
	if board_bottom < presenter.board_clearance - 0.0001:
		push_error(
			"Y-turn presentation: board bottom %s below clearance %s"
			% [board_bottom, presenter.board_clearance]
		)
		presenter.free()
		return false
	pose.board_yaw = 0.7
	presenter.apply_pose(pose)
	var expect_board_yaw := pose.board_yaw + pose.depth_turn_yaw
	if absf(board.rotation.y - expect_board_yaw) > 0.01:
		push_error("board yaw must be board_yaw+depth_turn, got %s" % board.rotation.y)
		presenter.free()
		return false
	# Facing scale must not flip the board node.
	if board.scale.x < 0.0:
		push_error("board must not use facing scale flip")
		presenter.free()
		return false
	presenter.free()
	return true


func _board_yaw_tracker_rules() -> bool:
	var t := BoardYawTracker.new()
	if absf(angle_difference(t.tick(1.0, 0.0, true), PI)) > 0.001:
		push_error("snap right should be PI")
		return false
	var left := BoardYawTracker.new()
	if absf(left.tick(-1.0, 0.0, true)) > 0.001:
		push_error("snap left should be 0")
		return false
	# Facing flip alone: no change
	var y0 := t.tick(-1.0, 0.0, false)
	if absf(angle_difference(y0, PI)) > 0.001:
		push_error("facing flip must not change board_yaw, got %s" % y0)
		return false
	# Apex co-rotation: facing_yaw 0 → -PI
	var y1 := t.tick(-1.0, -PI * 0.5, false)
	if absf(y1 - (PI * 0.5)) > 0.01:
		push_error("apex mid delta failed: %s" % y1)
		return false
	var y2 := t.tick(-1.0, -PI, false)
	if absf(y2) > 0.01:
		push_error("apex end delta failed: %s" % y2)
		return false
	# Handoff: facing_yaw -PI → 0 must not spin the board back
	var y3 := t.tick(1.0, 0.0, false)
	if absf(y3) > 0.01:
		push_error("handoff must keep board orientation, got %s" % y3)
		return false
	# Depth turn is NOT the tracker's job — ensure force_snap restore
	var y4 := t.tick(1.0, 0.0, true)
	if absf(angle_difference(y4, PI)) > 0.001:
		push_error("force_snap right failed: %s" % y4)
		return false
	return true


func _board_yaw_depth_turn_not_persisted() -> bool:
	var t := BoardYawTracker.new()
	t.tick(1.0, 0.0, true)
	var pose := LogicalPose.new()
	pose.board_yaw = t.yaw
	pose.depth_turn_yaw = 0.3
	# Presenter shows board_yaw + depth_turn_yaw; stored board_yaw stays tracker-owned.
	if absf(angle_difference(pose.board_yaw, PI)) > 0.001:
		push_error("depth turn must not bake into board_yaw")
		return false
	return true


func _player_pose_snapshots_track_board_yaw() -> bool:
	var player = _PlayerScript.new()
	player.depth = PseudoDepthBody.new()
	player._sim = PlayerSim.new()
	player._sim.state = SimState.new()
	player.visual_facing_h = "r"
	player.facing_yaw = 0.0
	player._capture_pose_snapshots()
	if absf(angle_difference(player._pose_curr.board_yaw, PI)) > 0.001:
		push_error("player board_yaw must snap right on first capture")
		player.depth.free()
		player.free()
		return false

	player.visual_facing_h = "l"
	player.facing_yaw = -PI * 0.5
	player._capture_pose_snapshots()
	if absf(player._pose_curr.board_yaw - (PI * 0.5)) > 0.01:
		push_error("player board_yaw must track apex yaw delta, got %s" % player._pose_curr.board_yaw)
		player.depth.free()
		player.free()
		return false

	player._sim.state.falling = true
	player._capture_pose_snapshots()
	player._sim.state.falling = false
	player.facing_yaw = 0.0
	player._capture_pose_snapshots()
	if absf(player._pose_curr.board_yaw) > 0.01:
		push_error("player board_yaw must snap to facing when fall bout ends, got %s" % player._pose_curr.board_yaw)
		player.depth.free()
		player.free()
		return false

	player.facing_yaw = -PI * 0.5
	player._capture_pose_snapshots()
	player.visual_facing_h = "r"
	player.facing_yaw = 0.0
	player._board_force_snap = true
	player._capture_pose_snapshots()
	if absf(angle_difference(player._pose_curr.board_yaw, PI)) > 0.01:
		push_error("player board_yaw one-shot restore snap failed, got %s" % player._pose_curr.board_yaw)
		player.depth.free()
		player.free()
		return false

	player.depth.free()
	player.free()
	return true


func _box_corners(xf: Transform3D, size: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out.append(xf * Vector3(
					sx * size.x * 0.5,
					sy * size.y * 0.5,
					sz * size.z * 0.5
				))
	return out


func _assert_box_on_plane(
	xf: Transform3D, size: Vector3, point: Vector3, normal: Vector3, label: String
) -> bool:
	for corner in _box_corners(xf, size):
		if normal.dot(corner - point) < -0.0001:
			push_error("%s: FallBox crossed plane at %s" % [label, corner])
			return false
	return true


func _fall_box_stays_above_support_planes() -> bool:
	var constraint := FallBoxConstraint.new()
	constraint.box_size = Vector3(0.18, 0.40, 0.14)
	var basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(55.0)))
	var xf := constraint.transform_for_planes(
		Vector3.ZERO, basis, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO
	)
	if not _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, Vector3.UP, "flat"):
		constraint.free()
		return false
	var tilt_n := Vector3(0.6, 0.0, 0.8).normalized()
	xf = constraint.transform_for_planes(
		Vector3.ZERO, basis, Vector3.ZERO, tilt_n, Vector3.ZERO, Vector3.ZERO
	)
	if not _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, tilt_n, "tilted"):
		constraint.free()
		return false
	constraint.free()
	return true


func _board_fall_box_stays_above_support_planes() -> bool:
	var constraint := FallBoxConstraint.new()
	constraint.box_size = Vector3(0.40, 0.05, 0.14)
	var basis := Basis.from_euler(Vector3(0.0, 0.4, deg_to_rad(35.0)))
	var xf := constraint.transform_for_planes(
		Vector3.ZERO, basis, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO
	)
	var ok := _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, Vector3.UP, "board flat")
	constraint.free()
	return ok


func _fall_box_stays_on_impact_approach_side() -> bool:
	var constraint := FallBoxConstraint.new()
	constraint.box_size = Vector3(0.18, 0.40, 0.14)
	var basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(55.0)))
	var impact_point := Vector3(-0.2, 0.0, 0.0)
	var impact_normal := Vector3(1.0, 0.0, 0.0)
	var xf := constraint.transform_for_planes(
		Vector3.ZERO, basis, Vector3.ZERO, Vector3.UP, impact_point, impact_normal
	)
	if not _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, Vector3.UP, "impact support"):
		constraint.free()
		return false
	if not _assert_box_on_plane(
		xf, constraint.box_size, impact_point, impact_normal, "impact approach"
	):
		constraint.free()
		return false
	constraint.free()
	return true


func _presenter_builds_dual_fall_bodies() -> bool:
	var presenter := LogicalPosePresenter3D.new()
	presenter._build_meshes()
	var rider := presenter.get_node_or_null("RiderFall") as FallBoxConstraint
	var board := presenter.get_node_or_null("BoardFall") as FallBoxConstraint
	if rider == null:
		push_error("presenter must build RiderFall")
		presenter.free()
		return false
	if board == null:
		push_error("presenter must build BoardFall")
		presenter.free()
		return false
	if presenter.get_node_or_null("FallBox") != null:
		push_error("presenter must not leave a FallBox node")
		presenter.free()
		return false
	if rider.box_size != presenter.body_size or absf(rider.mass - 4.0) > 0.001:
		push_error("RiderFall must keep body size and rider mass")
		presenter.free()
		return false
	if board.box_size != presenter.board_size or absf(board.mass - 1.0) > 0.001:
		push_error("BoardFall must use board size and board mass")
		presenter.free()
		return false
	if absf(board.linear_damp - 0.8) > 0.001 or absf(board.angular_damp - 0.4) > 0.001:
		push_error("BoardFall must use board damping")
		presenter.free()
		return false
	if rider.get_node_or_null("FallFacingMark") == null:
		push_error("RiderFall must keep facing mark")
		presenter.free()
		return false
	if board.get_node_or_null("FallFacingMark") != null:
		push_error("BoardFall must not have facing mark")
		presenter.free()
		return false
	presenter.free()
	return true


func _fall_tracking_defaults_to_rider_fall() -> bool:
	var cam := CameraRig3D.new()
	if cam.fall_box_path != NodePath("../RiderFall"):
		push_error("camera must track RiderFall by default, got %s" % cam.fall_box_path)
		cam.free()
		return false
	cam.free()
	var debug := PlayerDebug3D.new()
	if debug.fall_box_path != NodePath("../RiderFall"):
		push_error("debug must track RiderFall by default, got %s" % debug.fall_box_path)
		debug.free()
		return false
	debug.free()
	return true


## Fall bout: camera focus tracks X (FallBox), freezes Y/Z at bout start, then full follow.
func _fall_camera_tracks_x_locks_yz() -> bool:
	var cam := CameraRig3D.new()
	var start := Vector3(10.0, 2.0, 5.0)
	var mid := cam.focus_with_fall_lock(start, true)
	if mid != start:
		push_error("fall cam: first falling focus should match start %s vs %s" % [mid, start])
		cam.free()
		return false
	# FallBox X drifts while sim/PlayerVisual YZ would also move — only X tracks.
	var tumbled := Vector3(14.0, 0.4, 9.0)
	var locked := cam.focus_with_fall_lock(tumbled, true)
	if absf(locked.x - 14.0) > 0.001:
		push_error("fall cam: must track X, got %s" % locked)
		cam.free()
		return false
	if absf(locked.y - 2.0) > 0.001 or absf(locked.z - 5.0) > 0.001:
		push_error("fall cam: Y/Z must stay at fall start, got %s" % locked)
		cam.free()
		return false
	var after := Vector3(16.0, 1.1, 7.0)
	var resumed := cam.focus_with_fall_lock(after, false)
	if resumed != after:
		push_error("fall cam: after bout must full-follow %s vs %s" % [resumed, after])
		cam.free()
		return false
	# Second fall re-locks at the new start.
	var second := cam.focus_with_fall_lock(after, true)
	if second != after:
		push_error("fall cam: new bout should re-lock at %s got %s" % [after, second])
		cam.free()
		return false
	var second_move := cam.focus_with_fall_lock(Vector3(20.0, 0.0, 0.0), true)
	if absf(second_move.y - 1.1) > 0.001 or absf(second_move.z - 7.0) > 0.001:
		push_error("fall cam: second bout Y/Z lock failed %s" % second_move)
		cam.free()
		return false
	cam.free()
	return true
