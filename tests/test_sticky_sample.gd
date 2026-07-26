extends RefCounted
## RampLevel.sample sticky prefer at shared coping; PipeMath opposite detect.


func run() -> bool:
	if not _pipe_math_opposite():
		return false
	return _sticky_prefer()


func _pipe_math_opposite() -> bool:
	# Shared coping at 200: LEFT lip 300 r100, RIGHT lip 100 r100
	if not PipeMath.opposite_coping_near(
		QuarterPipe.PipeSide.LEFT, 300.0, 100.0,
		QuarterPipe.PipeSide.RIGHT, 100.0, 100.0
	):
		push_error("opposite_coping_near should be true for shared coping")
		return false
	if PipeMath.opposite_coping_near(
		QuarterPipe.PipeSide.LEFT, 300.0, 100.0,
		QuarterPipe.PipeSide.LEFT, 400.0, 100.0
	):
		push_error("same-side pipes are not opposite")
		return false
	if absf(PipeMath.coping_x(QuarterPipe.PipeSide.LEFT, 300.0, 100.0) - 200.0) > 0.01:
		push_error("LEFT coping_x wrong")
		return false
	if absf(PipeMath.coping_x(QuarterPipe.PipeSide.RIGHT, 100.0, 100.0) - 200.0) > 0.01:
		push_error("RIGHT coping_x wrong")
		return false
	if absf(PipeMath.coping_sign(QuarterPipe.PipeSide.LEFT) + 1.0) > 0.01:
		push_error("LEFT coping_sign want -1")
		return false
	if PipeMath.zone_name(QuarterPipe.PipeSide.RIGHT) != "right_pipe":
		push_error("zone_name RIGHT")
		return false
	return true


func _sticky_prefer() -> bool:
	var level := RampLevel.new()
	var left := QuarterPipe.new()
	left.side = QuarterPipe.PipeSide.LEFT
	left.lip_x = 300.0
	left.radius = 100.0
	left.z_min = 0.0
	left.z_max = 100.0
	var right := QuarterPipe.new()
	right.side = QuarterPipe.PipeSide.RIGHT
	right.lip_x = 100.0
	right.radius = 100.0
	right.z_min = 0.0
	right.z_max = 100.0
	# First-hit order: left before right
	level.pipes = [left, right]

	var ok := _check_sticky(level, left, right)
	_free_level(level)
	return ok


func _check_sticky(level: RampLevel, left: QuarterPipe, right: QuarterPipe) -> bool:
	var coping_x := 200.0
	var z := 50.0
	var first: Dictionary = level.sample(coping_x, z)
	if not first.get("active", false):
		push_error("coping sample should hit a pipe")
		return false
	if int(first.side) != QuarterPipe.PipeSide.LEFT:
		push_error("without prefer, first-hit should be LEFT (array order); got side=%s" % first.side)
		return false

	var sticky_right: Dictionary = level.sample(
		coping_x, z, QuarterPipe.PipeSide.RIGHT, right.lip_x
	)
	if not sticky_right.get("active", false):
		push_error("prefer RIGHT should hit")
		return false
	if int(sticky_right.side) != QuarterPipe.PipeSide.RIGHT:
		push_error("prefer RIGHT returned side=%s" % sticky_right.side)
		return false
	if absf(float(sticky_right.lip_x) - right.lip_x) > 0.05:
		push_error("prefer RIGHT lip mismatch")
		return false

	var sticky_left: Dictionary = level.sample(
		coping_x, z, QuarterPipe.PipeSide.LEFT, left.lip_x
	)
	if int(sticky_left.side) != QuarterPipe.PipeSide.LEFT:
		push_error("prefer LEFT returned side=%s" % sticky_left.side)
		return false

	return true


func _free_level(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
