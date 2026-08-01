extends RefCounted
## IdlCompiler + coping classification matrices.


func run() -> bool:
	return (
		_halfpipe_compiles()
		and _deck_backed_is_open()
		and _spine_shared()
		and _layered_cross_story_spine()
		and _cross_story_spans_are_explicit()
		and _cross_story_contact_ownership()
		and _unrelated_story_breaks_do_not_split_coping()
		and _open_coping()
		and _playable_levels_compile()
		and _step_height_scales_ramp_and_pipe()
		and _step_height_defaults_under_cell_w()
	)


func _step_height_scales_ramp_and_pipe() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_step_height.ssk")
	if not m.is_valid():
		push_error("step_height compile: %s" % ",".join(m.compile_errors))
		return false
	var cw := m.cell_w
	var want_rise := 3.0 * 40.0
	var want_radius := 3.0 * cw
	if m.ramps.is_empty() or m.pipes.is_empty():
		push_error("step_height map missing ramp or pipe")
		return false
	var ramp: RampSurface = m.ramps[m.ramps.keys()[0]]
	var pipe: PipeSurface = m.pipes[m.pipes.keys()[0]]
	var rs: Dictionary = ramp.sample_at_z((ramp.z_min + ramp.z_max) * 0.5)
	var ps: Dictionary = pipe.sample_at_z((pipe.z_min + pipe.z_max) * 0.5)
	if absf(float(rs.get("rise", -1.0)) - want_rise) > 0.01:
		push_error("ramp rise want %.1f got %s" % [want_rise, rs.get("rise", rs.get("radius"))])
		return false
	if absf(float(rs.radius) - want_radius) > 0.01:
		push_error("ramp radius(X) want %.1f got %.1f" % [want_radius, float(rs.radius)])
		return false
	if absf(float(ps.get("rise", -1.0)) - want_rise) > 0.01:
		push_error("pipe rise want %.1f got %s" % [want_rise, ps.get("rise", ps.get("radius"))])
		return false
	if absf(float(ps.radius) - want_radius) > 0.01:
		push_error("pipe radius(X) want %.1f got %.1f" % [want_radius, float(ps.radius)])
		return false
	var peak_r := ramp.height_at_theta((ramp.z_min + ramp.z_max) * 0.5, PI * 0.5)
	var peak_p := pipe.height_at_theta((pipe.z_min + pipe.z_max) * 0.5, PI * 0.5)
	if absf(peak_r - want_rise) > 0.01 or absf(peak_p - want_rise) > 0.01:
		push_error("peak height want %.1f ramp=%.1f pipe=%.1f" % [want_rise, peak_r, peak_p])
		return false
	return true


func _step_height_defaults_under_cell_w() -> bool:
	var m: ParkModel = IdlCompiler.compile_path("res://tests/levels/sim/sim_step_height_default.ssk")
	if not m.is_valid():
		push_error("step_height default compile: %s" % ",".join(m.compile_errors))
		return false
	var cw := m.cell_w
	var want_rise := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var want_radius := 3.0 * cw
	var ramp: RampSurface = m.ramps[m.ramps.keys()[0]]
	var pipe: PipeSurface = m.pipes[m.pipes.keys()[0]]
	var rs: Dictionary = ramp.sample_at_z((ramp.z_min + ramp.z_max) * 0.5)
	var ps: Dictionary = pipe.sample_at_z((pipe.z_min + pipe.z_max) * 0.5)
	var rr := float(rs.get("rise", rs.radius))
	var pr := float(ps.get("rise", ps.radius))
	if absf(rr - want_rise) > 0.01 or absf(float(rs.radius) - want_radius) > 0.01:
		push_error(
			"default ramp rise/radius want rise=%.1f radius=%.1f got rise=%.1f radius=%.1f"
			% [want_rise, want_radius, rr, float(rs.radius)]
		)
		return false
	if absf(pr - want_rise) > 0.01 or absf(float(ps.radius) - want_radius) > 0.01:
		push_error(
			"default pipe rise/radius want rise=%.1f radius=%.1f got rise=%.1f radius=%.1f"
			% [want_rise, want_radius, pr, float(ps.radius)]
		)
		return false
	if want_rise >= want_radius - 0.01:
		push_error("default step_height should keep ramps under 45°")
		return false
	return true


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
	var span := l0_right.span_at_z(z)
	if span == null or span.wall_id.is_empty() or not m.walls.has(span.wall_id):
		push_error("cross-story span should own an explicit wall")
		return false
	var wall: WallSurface = m.walls[span.wall_id]
	var h_eff := float(wall.sample_at_z(z).top_height)
	if h_eff <= h_geom + 10.0:
		push_error("effective lip should be L1 height (%.1f vs geom %.1f)" % [h_eff, h_geom])
		return false
	if absf(float(l0_right.sample_at_z(z).height) - h_geom) > 0.01:
		push_error("geometric coping height was mutated by cross-story compilation")
		return false
	return true


func _cross_story_spans_are_explicit() -> bool:
	var m := IdlCompiler.compile_path("res://tests/levels/sim/sim_cross_story.ssk")
	if not m.is_valid():
		push_error("cross-story fixture compile fail")
		return false
	var source: PipeSurface = null
	for id in m.all_pipe_ids():
		var pipe: PipeSurface = m.pipes[id]
		if str(id).contains("L0") and pipe.side == SimKinds.PipeSide.RIGHT:
			source = pipe
			break
	if source == null:
		push_error("cross-story fixture missing source pipe")
		return false
	var cope: CopingEdge = m.copings[source.coping_id]
	var wall_spans := 0
	var open_spans := 0
	for span_value in cope.spans:
		var span: CopingSpan = span_value
		if not span.wall_id.is_empty():
			wall_spans += 1
			var wall: WallSurface = m.walls.get(span.wall_id)
			if wall == null or wall.upper_partner_pipe_id.is_empty():
				push_error("wall span missing action-only upper partner")
				return false
		else:
			open_spans += 1
	if wall_spans != 2 or open_spans < 1:
		push_error("expected 2 wall Z spans plus a hole span, got %d/%d" % [wall_spans, open_spans])
		return false
	var hash_again := IdlCompiler.compile_path(
		"res://tests/levels/sim/sim_cross_story.ssk"
	).model_hash
	if m.model_hash != hash_again:
		push_error("canonical topology hash is not deterministic")
		return false
	return true


func _cross_story_contact_ownership() -> bool:
	var m := IdlCompiler.compile_path("res://tests/levels/sim/sim_cross_story.ssk")
	var query := SurfaceQuery.new(m)
	var wall: WallSurface = null
	for id in m.all_wall_ids():
		wall = m.walls[id]
		break
	if wall == null:
		push_error("contact ownership fixture has no wall")
		return false
	var z := (wall.z_min + wall.z_max) * 0.5
	var sample := wall.sample_at_z(z)
	var x := float(sample.x)
	var h := (float(sample.bottom_height) + float(sample.top_height)) * 0.5
	var edge := query.edge_at(wall.source_pipe_id, z, "coping")
	if edge == null or edge.to_surface_id != wall.id:
		push_error("source coping does not resolve uniquely to wall")
		return false
	var boundary_hit := query.blocker_at(Vector3(x, z, h))
	if str(boundary_hit.get("feature_id", "")) != wall.id:
		push_error("shared boundary owner should be wall, got %s" % boundary_hit)
		return false
	var sweep := query.sweep_capsule(Vector3(x - 1.0, z, h), Vector3(x + 1.0, z, h))
	if str(sweep.get("feature_id", "")) != wall.id \
			or not sweep.has("projection") or not sweep.has("normal") or not sweep.has("t"):
		push_error("uniform swept contact should select wall first: %s" % sweep)
		return false
	var source_side := query.blocker_at(
		Vector3(x - SimTolerances.CONTACT_EPS * 2.0, z, h)
	)
	if not source_side.is_empty():
		push_error("source side of wall should remain ride-space: %s" % source_side)
		return false
	return true


func _unrelated_story_breaks_do_not_split_coping() -> bool:
	var m := IdlCompiler.compile_path("res://levels/layered_demo.ssk")
	var pipe: PipeSurface = m.pipes.get("pipe_0_L0_S0")
	if pipe == null:
		push_error("coping seam: missing layered outer quarter pipe")
		return false
	var coping: CopingEdge = m.copings.get(pipe.coping_id)
	if coping == null or coping.spans.size() != 1:
		push_error(
			"coping seam: unrelated upper-story Z breaks split continuous outer coping"
		)
		return false
	var span: CopingSpan = coping.spans[0]
	if absf(span.z_min - pipe.z_min) > 0.01 or absf(span.z_max - pipe.z_max) > 0.01:
		push_error("coping seam: merged span does not cover the full quarter pipe")
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
		"res://tests/levels/sim/sim_cross_story.ssk",
	]:
		var m: ParkModel = IdlCompiler.compile_path(path)
		if not m.is_valid():
			push_error("compile %s: %s" % [path, ",".join(m.compile_errors)])
			return false
		if m.pipes.is_empty() and m.patches.is_empty():
			push_error("%s empty model" % path)
			return false
	return true
