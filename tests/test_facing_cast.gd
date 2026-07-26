extends RefCounted
## Facing-cast heights follow same-layer pipe glyphs; holes fall to lower pipe arcs.


func run() -> bool:
	var text := FileAccess.get_file_as_string("res://levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		return false

	var level := RampLevel.new()
	level.spec = spec
	level.cell_size_x = spec.cell_w
	level.cell_size_z = spec.cell_h
	level.pipes.clear()
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.layer = int(pd.get("layer", 0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		level.pipes.append(qp)

	var l1_left: QuarterPipe = null
	var l0_right: QuarterPipe = null
	for p in level.pipes:
		if int(p.side) == 0 and int(p.layer) == 1:
			l1_left = p
		if int(p.side) == 1 and int(p.layer) == 0:
			l0_right = p
	if l1_left == null or l0_right == null:
		push_error("need L1 left + L0 right")
		_free(level)
		return false

	var z: float = (l1_left.z_min + l1_left.z_max) * 0.5
	var prefer := float(l1_left.base_height)

	# Mid-arc on L1 left — not L0 floor under the pipe.
	var mid_x: float = (l1_left.x_min() + l1_left.x_max()) * 0.5
	var l1_hit: Dictionary = l1_left.query_surface(mid_x, z)
	if not l1_hit.get("active", false):
		push_error("mid_x should be on L1 left")
		_free(level)
		return false
	var got := level.cast_surface_height(mid_x, z, prefer)
	if absf(got - float(l1_hit.height)) > 1.0:
		push_error("cast mid L1 left want %.1f got %.1f" % [float(l1_hit.height), got])
		_free(level)
		return false

	# Lip low, coping high on L1 left.
	var lip_x: float = l1_left.lip_x - 1.0
	var cope_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius) + 1.0
	var h_lip := level.cast_surface_height(lip_x, z, prefer)
	var h_cope := level.cast_surface_height(cope_x, z, prefer)
	if h_cope < h_lip + 20.0:
		push_error("cast should climb L1 left (lip=%.1f cope=%.1f)" % [h_lip, h_cope])
		_free(level)
		return false

	# Hole west of L1 left → L0 right pipe arc (not height 0).
	var hole_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius) - spec.cell_w * 0.6
	var hole_cell := spec.cell_at(hole_x, z)
	var g_hole: Dictionary = spec.glyph_at_prefer_h(hole_cell.x, hole_cell.y, prefer)
	if str(g_hole.get("glyph", "")) != ".":
		push_error("expected L1 hole west of coping, got %s" % g_hole)
		_free(level)
		return false
	var through: Dictionary = level.cast_surface_at(hole_x, z, prefer)
	var l0_hit: Dictionary = l0_right.query_surface(hole_x, z)
	if not l0_hit.get("active", false):
		push_error("hole_x should sit on L0 right pipe")
		_free(level)
		return false
	if absf(float(through.get("height", -1.0)) - float(l0_hit.height)) > 2.0:
		push_error(
			"hole fallthrough must follow L0 right arc want %.1f got %s"
			% [float(l0_hit.height), through]
		)
		_free(level)
		return false

	# Coping cell flagged on L1 left outermost pipe column.
	var cope_cell_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
	# Nudge into pipe so cell_at lands on the coping column.
	var cope_sample_x: float = cope_cell_x + 1.0
	var cope_info: Dictionary = level.cast_surface_at(cope_sample_x, z, prefer)
	if not bool(cope_info.get("is_coping", false)):
		push_error("L1 left coping cell should set is_coping, got %s" % cope_info)
		_free(level)
		return false

	_free(level)
	return true


func _free(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
