extends RefCounted
## LogicalPose render-frame lerp helpers.


func run() -> bool:
	return _lerp_midpoint() and _lerp_flags() and _centered_y_turn_presentation()


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
		return false
	var pose := LogicalPose.new()
	pose.surface_tilt = PI * 0.5
	pose.facing_h = -1.0
	pose.facing_yaw = -PI * 0.5
	pose.depth_turn_yaw = 0.2
	presenter.apply_pose(pose)
	if absf(presenter.rotation.z - pose.surface_tilt) > 0.01:
		push_error("Y-turn presentation: turn incorrectly changed feet pivot")
		return false
	if absf(body.rotation.y - (pose.facing_yaw + pose.depth_turn_yaw)) > 0.01:
		push_error("Y-turn presentation: apex and depth turns must share local Y")
		return false
	if absf(body.position.y - presenter.body_size.y * 0.5) > 0.001:
		push_error("Y-turn presentation: body center moved during turn")
		return false
	presenter.free()
	return true
