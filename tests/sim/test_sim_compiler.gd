extends RefCounted
## IdlCompiler + coping classification matrices.


func run() -> bool:
	return (
		_halfpipe_compiles()
		and _deck_backed_is_open()
		and _spine_shared()
		and _layered_cross_story_spine()
		and _open_coping()
		and _playable_levels_compile()
	)


func _halfpipe_compiles() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_halfpipe.ssk")
	if not m.is_valid():
		push_error("halfpipe compile: %s" % ",".join(m.compile_errors))
		return false
	if m.pipes.is_empty():
		push_error("halfpipe has no pipes")
		return false
	if m.model_hash.is_empty():
		push_error("missing model hash")
		return false
	if not m.patches.has("__void_floor__"):
		push_error("missing invisible void floor patch")
		return false
	var void_p: SupportPatch = m.patches["__void_floor__"]
	if absf(void_p.height - SimTolerances.VOID_FLOOR) > 0.01:
		push_error("void floor height wrong")
		return false
	return true


func _deck_backed_is_open() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_deck_backed.ssk")
	if not m.is_valid():
		push_error("deck_backed compile fail")
		return false
	var found_open := false
	for cid in m.copings.keys():
		var c: CopingEdge = m.copings[cid]
		if c.side == SimKinds.PipeSide.LEFT:
			# Same-height outward # is air/fly corridor, not auto-mount seam.
			if c.coping_class == SimKinds.CopingClass.OPEN:
				found_open = true
			else:
				push_error("left deck-backed coping should be OPEN, got %s" % c.class_name_str())
				return false
	if not found_open:
		push_error("no left OPEN coping on deck_backed")
		return false
	return true


func _spine_shared() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_spine.ssk")
	if not m.is_valid():
		push_error("spine compile fail")
		return false
	var shared := 0
	for cid in m.copings.keys():
		var c: CopingEdge = m.copings[cid]
		if c.coping_class == SimKinds.CopingClass.SHARED_SPINE:
			shared += 1
	if shared < 2:
		push_error("expected shared spine copings, got %d" % shared)
		return false
	return true


func _layered_cross_story_spine() -> bool:
	# L0 right faces taller L1 left: climb to L1 lip (WALL_EXTENSION), then air/fly.
	# Must not air-out at L0 geometric height through the upper pipe.
	var m: ParkModel = IdlCompiler.compile_path("res://levels/layered_demo.ssk")
	if not m.is_valid():
		push_error("layered_demo compile fail")
		return false
	var l0_right: CopingEdge = null
	var l0_pipe: PipeSurface = null
	for id in m.pipes.keys():
		var p: PipeSurface = m.pipes[id]
		if not id.begins_with("pipe_1_L0"):
			continue
		l0_pipe = p
		l0_right = m.copings.get(p.coping_id)
		break
	if l0_right == null or l0_pipe == null:
		push_error("missing L0 right pipe")
		return false
	if l0_right.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
		push_error("L0 right should climb to L1 lip, got %s" % l0_right.class_name_str())
		return false
	var z := (l0_pipe.z_min + l0_pipe.z_max) * 0.5
	# Prefer a Z that overlaps an L1 left pipe.
	for id in m.pipes.keys():
		var p2: PipeSurface = m.pipes[id]
		if p2.side != SimKinds.PipeSide.LEFT:
			continue
		if not str(id).contains("L1"):
			continue
		z = clampf((p2.z_min + p2.z_max) * 0.5, l0_pipe.z_min, l0_pipe.z_max)
		break
	var h_geom := l0_pipe.height_at_theta(z, PI * 0.5)
	var h_eff := float(l0_right.sample_at_z(z).height)
	if h_eff <= h_geom + 10.0:
		push_error("effective lip should be L1 height (%.1f vs geom %.1f)" % [h_eff, h_geom])
		return false
	return true


func _open_coping() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_open_fly.ssk")
	if not m.is_valid():
		push_error("open_fly compile fail: %s" % ",".join(m.compile_errors))
		return false
	# Outer sides of halfpipe with lower flat outside → OPEN.
	var opens := 0
	for cid in m.copings.keys():
		var c: CopingEdge = m.copings[cid]
		if c.coping_class == SimKinds.CopingClass.OPEN:
			opens += 1
	if opens < 1:
		push_error("expected OPEN coping on open_fly")
		return false
	return true


func _playable_levels_compile() -> bool:
	for path in [
		"res://levels/plaza_default.ssk",
		"res://levels/spine_demo.ssk",
		"res://levels/layered_demo.ssk",
		"res://levels/variable_height_ramps.ssk",
		"res://tests/levels/test_halfpipe.ssk",
	]:
		var m: ParkModel = IdlCompiler.compile_path(path)
		if not m.is_valid():
			push_error("compile %s: %s" % [path, ",".join(m.compile_errors)])
			return false
		if m.pipes.is_empty() and m.patches.is_empty():
			push_error("%s empty model" % path)
			return false
	return true
