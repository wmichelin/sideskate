extends RefCounted
## MotionMath: facing, transfer-vert routing, brake-no-reverse.


func run() -> bool:
	if not _facing():
		return false
	if not _transfer_vert():
		return false
	return _integrate()


func _facing() -> bool:
	if MotionMath.normalize_facing("L") != "l":
		push_error("normalize_facing L")
		return false
	if MotionMath.normalize_facing("left") != "l":
		push_error("normalize_facing left")
		return false
	if MotionMath.normalize_facing("r") != "r":
		push_error("normalize_facing r")
		return false
	if MotionMath.normalize_facing("nope") != "r":
		push_error("normalize_facing default r")
		return false
	return true


func _transfer_vert() -> bool:
	if not MotionMath.transfer_vert_ok(10.0, 0.0):
		push_error("rising should transfer")
		return false
	if not MotionMath.transfer_vert_ok(0.0, 5.0):
		push_error("apex after rise should transfer")
		return false
	if MotionMath.transfer_vert_ok(-8.0, 5.0):
		push_error("falling should not transfer")
		return false
	if MotionMath.transfer_vert_ok(0.0, -3.0):
		push_error("rest after down should not transfer")
		return false
	return true


func _integrate() -> bool:
	# Coast with friction toward 0
	var coast := MotionMath.integrate_axis_no_reverse(100.0, 0.0, 50.0, 20.0, 200.0, false)
	if absf(coast - 80.0) > 0.01:
		push_error("coast friction want 80 got %s" % coast)
		return false
	# Skip friction keeps speed
	var hold := MotionMath.integrate_axis_no_reverse(100.0, 0.0, 50.0, 20.0, 200.0, true)
	if absf(hold - 100.0) > 0.01:
		push_error("skip_friction should hold")
		return false
	# Opposite want brakes toward 0, no reverse past 0 in one step when brake < |current|
	var braked := MotionMath.integrate_axis_no_reverse(100.0, -200.0, 50.0, 20.0, 40.0, false)
	if absf(braked - 60.0) > 0.01:
		push_error("brake want 60 got %s" % braked)
		return false
	# Brake to zero (not past)
	var to_zero := MotionMath.integrate_axis_no_reverse(30.0, -200.0, 50.0, 20.0, 40.0, false)
	if absf(to_zero) > 0.01:
		push_error("brake should stop at 0, got %s" % to_zero)
		return false
	# Same-direction accel
	var accel := MotionMath.integrate_axis_no_reverse(10.0, 100.0, 25.0, 20.0, 200.0, false)
	if absf(accel - 35.0) > 0.01:
		push_error("accel want 35 got %s" % accel)
		return false
	return true
