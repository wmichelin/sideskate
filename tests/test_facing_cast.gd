extends RefCounted
## FacingCastMath: story-aware cast surfaces + cast_ahead for gameplay reuse.


func run() -> bool:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		return false

	var pipes: Array = []
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.layer = int(pd.get("layer", 0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		pipes.append(qp)

	var l1_left: QuarterPipe = null
	var l0_right: QuarterPipe = null
	for p in pipes:
		if int(p.side) == 0 and int(p.layer) == 1:
			l1_left = p
		if int(p.side) == 1 and int(p.layer) == 0:
			l0_right = p
	if l1_left == null or l0_right == null:
		push_error("need L1 left + L0 right")
		_free_pipes(pipes)
		return false

	var z: float = (l1_left.z_min + l1_left.z_max) * 0.5
	var prefer := float(l1_left.base_height)

	# Mid-arc on L1 left — not L0 floor under the pipe.
	var mid_x: float = (l1_left.x_min() + l1_left.x_max()) * 0.5
	var l1_hit: Dictionary = l1_left.query_surface(mid_x, z)
	if not l1_hit.get("active", false):
		push_error("mid_x should be on L1 left")
		_free_pipes(pipes)
		return false
	var got := FacingCastMath.resolve_height(spec, pipes, mid_x, z, prefer)
	if absf(got - float(l1_hit.height)) > 1.0:
		push_error("cast mid L1 left want %.1f got %.1f" % [float(l1_hit.height), got])
		_free_pipes(pipes)
		return false

	# Lip low, coping high on L1 left.
	var lip_x: float = l1_left.lip_x - 1.0
	var cope_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius) + 1.0
	var h_lip := FacingCastMath.resolve_height(spec, pipes, lip_x, z, prefer)
	var h_cope := FacingCastMath.resolve_height(spec, pipes, cope_x, z, prefer)
	if h_cope < h_lip + 20.0:
		push_error("cast should climb L1 left (lip=%.1f cope=%.1f)" % [h_lip, h_cope])
		_free_pipes(pipes)
		return false

	# Hole west of L1 left → L0 right pipe arc (not height 0).
	var hole_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius) - spec.cell_w * 0.6
	var hole_cell := spec.cell_at(hole_x, z)
	var g_hole: Dictionary = spec.glyph_at_prefer_h(hole_cell.x, hole_cell.y, prefer)
	if str(g_hole.get("glyph", "")) != ".":
		push_error("expected L1 hole west of coping, got %s" % g_hole)
		_free_pipes(pipes)
		return false
	var through: Dictionary = FacingCastMath.resolve_surface(spec, pipes, hole_x, z, prefer)
	var l0_hit: Dictionary = l0_right.query_surface(hole_x, z)
	if not l0_hit.get("active", false):
		push_error("hole_x should sit on L0 right pipe")
		_free_pipes(pipes)
		return false
	if absf(float(through.get("height", -1.0)) - float(l0_hit.height)) > 2.0:
		push_error(
			"hole fallthrough must follow L0 right arc want %.1f got %s"
			% [float(l0_hit.height), through]
		)
		_free_pipes(pipes)
		return false

	# Coping cell flagged on L1 left outermost pipe column.
	var cope_cell_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
	var cope_sample_x: float = cope_cell_x + 1.0
	var cope_info: Dictionary = FacingCastMath.resolve_surface(
		spec, pipes, cope_sample_x, z, prefer
	)
	if not bool(cope_info.get("is_coping", false)):
		push_error("L1 left coping cell should set is_coping, got %s" % cope_info)
		_free_pipes(pipes)
		return false

	# cast_ahead from L1 plaza facing left should hit L1 pipe then coping.
	var plaza_x: float = l1_left.lip_x + spec.cell_w * 2.0
	var origin := spec.cell_at(plaza_x, z)
	var hits: Array = FacingCastMath.cast_ahead(
		spec, pipes, origin.x, origin.y, "l", 8, z, prefer
	)
	if hits.is_empty():
		push_error("cast_ahead from plaza should return hits")
		_free_pipes(pipes)
		return false
	var first_pipe := false
	for h in hits:
		if str(h.get("zone", "")).ends_with("pipe") or str(h.get("zone", "")) == "left_pipe":
			first_pipe = true
			break
	if not first_pipe:
		# zone is "left_pipe" from query
		for h2 in hits:
			if int(h2.get("side", -1)) == 0 and int(h2.get("layer", -1)) == 1:
				first_pipe = true
				break
	if not first_pipe:
		push_error("cast_ahead should include L1 left pipe, got %s" % [hits])
		_free_pipes(pipes)
		return false
	var cope_hit: Dictionary = FacingCastMath.first_coping(hits)
	if cope_hit.is_empty():
		push_error("cast_ahead should find a coping cell from plaza left")
		_free_pipes(pipes)
		return false

	# first_coping_ahead excludes current L1 left → still finds that coping from plaza.
	var ahead: Dictionary = FacingCastMath.first_coping_ahead(
		spec, pipes, origin.x, origin.y, "l", 8, z, prefer, -1, NAN
	)
	if ahead.is_empty() or not bool(ahead.get("is_coping", false)):
		push_error("first_coping_ahead from plaza failed: %s" % ahead)
		_free_pipes(pipes)
		return false
	# Exclude L1 left identity — from on that pipe, looking left past coping into hole.
	var on_pipe := spec.cell_at(mid_x, z)
	var excluded: Dictionary = FacingCastMath.first_coping_ahead(
		spec, pipes, on_pipe.x, on_pipe.y, "l", 8, z, prefer,
		0, float(l1_left.lip_x)
	)
	# May be empty or L0 right under holes — must not be L1 left.
	if not excluded.is_empty():
		if int(excluded.get("side", -1)) == 0 and int(excluded.get("layer", -1)) == 1 \
				and absf(float(excluded.get("lip_x", -1)) - float(l1_left.lip_x)) < 0.05:
			push_error("exclude should skip current L1 left coping")
			_free_pipes(pipes)
			return false

	# RampLevel wrappers still match pure math.
	var level := RampLevel.new()
	level.spec = spec
	level.pipes = pipes
	var wrap := level.cast_surface_at(mid_x, z, prefer)
	var pure := FacingCastMath.resolve_surface(spec, pipes, mid_x, z, prefer)
	if absf(float(wrap.get("height", -1)) - float(pure.get("height", -2))) > 0.01:
		push_error("RampLevel wrapper diverged from FacingCastMath")
		level.pipes.clear()
		level.free()
		_free_pipes(pipes)
		return false
	level.pipes.clear()
	level.free()

	_free_pipes(pipes)
	return true


func _free_pipes(pipes: Array) -> void:
	for p in pipes:
		if is_instance_valid(p):
			p.free()
	pipes.clear()
