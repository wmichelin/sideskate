extends RefCounted
## GroundMotion: sticky / mount / flat-path / coping-cross without a live Player.

const _GroundMotion := preload("res://scripts/ground_motion.gd")


func run() -> bool:
	return (
		_sticky_matrix()
		and _fresh_coping_reject()
		and _mount_gates()
		and _post_move()
		and _flat_path()
		and _coping_cross_picks_highest()
	)


func _pipe(side: int, lip: float, base: float, radius: float = 100.0) -> Dictionary:
	return {
		"zone": "left_pipe" if side == 0 else "right_pipe",
		"active": true,
		"side": side,
		"lip_x": lip,
		"base_height": base,
		"radius": radius,
		"height": base + radius,
		"theta": 0.4,
		"z_min": 0.0,
		"z_max": 200.0,
	}


func _sticky_matrix() -> bool:
	var cur = _pipe(0, 300.0, 141.0)
	var foreign = _pipe(1, 300.0, 0.0)
	var skip = _GroundMotion.decide_sticky(false, true, cur, cur, -100.0, 0)
	if str(skip.action) != "skip":
		push_error("off-ramp sticky must skip")
		return false
	var ride = _GroundMotion.decide_sticky(true, true, cur, cur, -100.0, 0)
	if str(ride.action) != "ride":
		push_error("own active must ride")
		return false
	var launch = _GroundMotion.decide_sticky(true, false, foreign, cur, -100.0, 0)
	if str(launch.action) != "launch":
		push_error("foreign underfoot must launch")
		return false
	var leave = _GroundMotion.decide_sticky(true, false, {}, cur, 0.0, 0)
	if str(leave.action) != "leave":
		push_error("inactive own with no toward must leave")
		return false
	return true


func _fresh_coping_reject() -> bool:
	var top = _pipe(0, 300.0, 0.0)
	top["theta"] = PI * 0.5
	if not _GroundMotion.is_rejected_fresh_coping(false, top):
		push_error("θ=π/2 fresh must reject")
		return false
	if _GroundMotion.is_rejected_fresh_coping(true, top):
		push_error("already on ramp must not reject fresh coping")
		return false
	return true


func _mount_gates() -> bool:
	var pipe = _pipe(0, 300.0, 0.0)
	pipe["theta"] = PI * 0.5
	var m = _GroundMotion.decide_mount(pipe, 0.0, false, false, 0.5)
	if bool(m.allow_pipe) or not bool(m.rejected_fresh_coping):
		push_error("fresh coping mount must refuse: %s" % m)
		return false
	pipe["theta"] = 0.3
	var ok = _GroundMotion.decide_mount(pipe, 0.0, false, false, 0.5)
	if not bool(ok.allow_pipe):
		push_error("mid-arc fresh mount must allow")
		return false
	var pad = _GroundMotion.decide_mount(pipe, 0.0, false, true, 0.5)
	if bool(pad.allow_pipe):
		push_error("solid pad must block fresh mount")
		return false
	return true


func _post_move() -> bool:
	var cur = _pipe(1, 400.0, 0.0)
	cur["theta"] = 0.8
	var ride = _GroundMotion.decide_post_move(true, cur, cur, cur, -120.0, 1)
	if str(ride.action) != "ride" or absf(float(ride.theta) - 0.8) > 0.01:
		push_error("post-move ride failed: %s" % ride)
		return false
	var foreign = _pipe(0, 400.0, 141.0)
	var launch = _GroundMotion.decide_post_move(false, {}, foreign, cur, 80.0, 1)
	if str(launch.action) != "launch":
		push_error("post-move foreign must launch")
		return false
	return true


func _flat_path() -> bool:
	var hit = _pipe(0, 300.0, 0.0)
	var cross = {
		"side": 0,
		"lip_x": 300.0,
		"radius": 100.0,
		"base_height": 0.0,
		"z_min": 0.0,
		"z_max": 200.0,
	}
	var off = _GroundMotion.decide_flat_path(hit, cross, false, true, -200.0)
	if str(off.action) != "ride_off":
		push_error("rejected coping must ride_off")
		return false
	var launch = _GroundMotion.decide_flat_path(hit, cross, false, false, -200.0)
	if str(launch.action) != "coping_launch" or float(launch.up_speed) < 1.0:
		push_error("same-pipe cross must coping_launch: %s" % launch)
		return false
	var pad = _GroundMotion.decide_flat_path(hit, cross, true, false, -200.0)
	if str(pad.action) != "commit":
		push_error("solid pad must commit flat")
		return false
	return true


func _coping_cross_picks_highest() -> bool:
	var low = {
		"side": 1,
		"lip_x": 200.0,
		"radius": 100.0,
		"base_height": 0.0,
		"z_min": 0.0,
		"z_max": 200.0,
	}
	var high = {
		"side": 1,
		"lip_x": 200.0,
		"radius": 100.0,
		"base_height": 141.0,
		"z_min": 0.0,
		"z_max": 200.0,
	}
	# Right pipe: coping at lip+radius=300; cross from inside (250) past radius.
	var cross = _GroundMotion.find_coping_cross([low, high], 100.0, 250.0, 310.0, 141.0)
	if cross.is_empty() or absf(float(cross.base_height) - 141.0) > 0.01:
		push_error("cross must pick highest base, got %s" % cross)
		return false
	var none = _GroundMotion.find_coping_cross([low], 100.0, 250.0, 260.0, 0.0)
	if not none.is_empty():
		push_error("no radius cross must be empty")
		return false
	return true
