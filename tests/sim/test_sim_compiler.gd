extends RefCounted
## IdlCompiler + coping classification matrices.


func run() -> bool:
	return (
		_halfpipe_compiles()
		and _deck_backed_is_open()
		and _spine_shared()
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
