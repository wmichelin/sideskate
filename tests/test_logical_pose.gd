extends RefCounted
## LogicalPose render-frame lerp helpers.


func run() -> bool:
	return _lerp_midpoint() and _lerp_flags()


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
