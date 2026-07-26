extends RefCounted
## RampLevel.sample sticky prefer at shared coping; PipeMath opposite detect.


func run() -> bool:
	if not _pipe_math_opposite():
		return false
	if not _sticky_prefer():
		return false
	if not _sticky_layered_base():
		return false
	return _solid_floor_blocks_pipe()


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


func _sticky_layered_base() -> bool:
	# Same side+lip on two stories: sticky prefer_base must stay on the upper pipe.
	var level := RampLevel.new()
	var low := QuarterPipe.new()
	low.side = QuarterPipe.PipeSide.LEFT
	low.lip_x = 300.0
	low.radius = 100.0
	low.base_height = 0.0
	low.z_min = 0.0
	low.z_max = 100.0
	var high := QuarterPipe.new()
	high.side = QuarterPipe.PipeSide.LEFT
	high.lip_x = 300.0
	high.radius = 100.0
	high.base_height = 100.0
	high.z_min = 0.0
	high.z_max = 100.0
	level.pipes = [low, high]

	var coping_x := 200.0
	var z := 50.0
	var sticky_high: Dictionary = level.sample(
		coping_x, z, QuarterPipe.PipeSide.LEFT, high.lip_x, 150.0, 100.0
	)
	if not sticky_high.get("active", false):
		push_error("layered sticky high should hit")
		_free_level(level)
		return false
	if absf(float(sticky_high.get("base_height", -1.0)) - 100.0) > 0.05:
		push_error("layered sticky want base 100 got %s" % sticky_high)
		_free_level(level)
		return false

	var sticky_low: Dictionary = level.sample(
		coping_x, z, QuarterPipe.PipeSide.LEFT, low.lip_x, 50.0, 0.0
	)
	if absf(float(sticky_low.get("base_height", -1.0)) - 0.0) > 0.05:
		push_error("layered sticky low want base 0 got %s" % sticky_low)
		_free_level(level)
		return false

	var by_h: Dictionary = level.sample(
		coping_x, z, QuarterPipe.PipeSide.LEFT, high.lip_x, 150.0
	)
	if absf(float(by_h.get("base_height", -1.0)) - 100.0) > 0.05:
		push_error("prefer_h sticky should pick upper pipe, got %s" % by_h)
		_free_level(level)
		return false

	_free_level(level)
	return true


func _solid_floor_blocks_pipe() -> bool:
	# Falling from above an `=` at 188 must land on the floor, not the pipe below.
	# Hole cells (mask 0) must not be filled by ring outline polys.
	var level := RampLevel.new()
	var pipe := QuarterPipe.new()
	pipe.side = QuarterPipe.PipeSide.LEFT
	pipe.lip_x = 300.0
	pipe.radius = 100.0
	pipe.base_height = 0.0
	pipe.z_min = 0.0
	pipe.z_max = 100.0
	level.pipes = [pipe]
	var spec := LevelSpec.new()
	spec.grid_w = 4
	spec.grid_h = 1
	spec.cell_w = 100.0
	spec.cell_h = 100.0
	# Cols 0-1 solid at 188, cols 2-3 hole — coping X=200 is col 2 (hole).
	var mask := PackedByteArray([1, 1, 0, 0])
	spec.story_floor_masks = [{"height": 188.0, "mask": mask, "layer": 1}]
	# Deliberately wrong ring poly that would fill the hole if sampled via outline.
	spec.floors = [{
		"poly": PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(400.0, 0.0),
			Vector2(400.0, 100.0), Vector2(0.0, 100.0),
		]),
		"height": 188.0,
	}]
	level.spec = spec

	var hole_x := 250.0  # col 2
	var z := 50.0
	var over_hole: Dictionary = level.sample(hole_x, z, -1, NAN, 220.0)
	if str(over_hole.get("zone", "")) == "flat" and absf(float(over_hole.get("height", -1.0)) - 188.0) < 0.05:
		push_error("hole cell must not sample as solid floor 188: %s" % over_hole)
		_free_level(level)
		return false

	var solid_x := 50.0  # col 0
	var over_solid: Dictionary = level.sample(solid_x, z, -1, NAN, 220.0)
	# No pipe at x=50; expect flat 188.
	if str(over_solid.get("zone", "")) != "flat" or absf(float(over_solid.get("height", -1.0)) - 188.0) > 0.05:
		push_error("solid cell want flat 188, got %s" % over_solid)
		_free_level(level)
		return false

	var coping_x := 200.0
	var from_air: Dictionary = level.sample(coping_x, z, -1, NAN, 220.0)
	# Coping is over hole mask → pipe, not phantom floor.
	if str(from_air.get("zone", "")) != "left_pipe":
		push_error("coping over hole should be pipe, got %s" % from_air)
		_free_level(level)
		return false

	# Solid over pipe X: put mask under coping and confirm floor blocks pipe.
	spec.story_floor_masks = [{"height": 188.0, "mask": PackedByteArray([1, 1, 1, 1]), "layer": 1}]
	var blocked: Dictionary = level.sample(coping_x, z, -1, NAN, 220.0)
	if str(blocked.get("zone", "")) != "flat" or absf(float(blocked.get("height", -1.0)) - 188.0) > 0.05:
		push_error("solid over pipe want flat 188, got %s" % blocked)
		_free_level(level)
		return false

	var under: Dictionary = level.sample(coping_x, z, -1, NAN, 100.0)
	if str(under.get("zone", "")) != "left_pipe":
		push_error("under solid floor at mid-pipe should be pipe, got %s" % under)
		_free_level(level)
		return false

	_free_level(level)
	return true


func _free_level(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
