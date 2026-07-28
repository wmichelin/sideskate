class_name IdlCompiler
extends RefCounted
## Compile LevelSpec (parsed .ssk) into an immutable ParkModel.


const _LevelLoader := preload("res://scripts/level_loader.gd")


static func compile_text(text: String, name_hint: String = "") -> ParkModel:
	var spec: LevelSpec = _LevelLoader.parse_text(text, name_hint)
	if spec == null:
		var m := ParkModel.new()
		m.compile_errors.append("parse failed: %s" % _LevelLoader.last_error)
		return m
	return compile_spec(spec)


static func compile_path(path: String) -> ParkModel:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty() and not FileAccess.file_exists(path):
		var m := ParkModel.new()
		m.compile_errors.append("missing file: %s" % path)
		return m
	return compile_text(text, path.get_file().get_basename())


static func compile_spec(spec: LevelSpec) -> ParkModel:
	var model := ParkModel.new()
	model.name = spec.name
	model.cell_w = spec.cell_w
	model.cell_h = spec.cell_h
	model.grid_w = spec.grid_w
	model.grid_h = spec.grid_h
	model.width = spec.width
	model.depth = spec.depth
	model.spawn_x = spec.spawn_x
	model.spawn_z = spec.spawn_z
	model.spawn_height = spec.spawn_height
	model.spawn_facing = spec.spawn_facing
	model.playable_mask = spec.playable_mask.duplicate()

	_compile_floors(spec, model)
	_compile_decks(spec, model)
	_compile_pipes(spec, model)
	_classify_copings(spec, model)
	_build_topology_edges(model)
	_link_shared_spines(model)
	model.model_hash = _hash_model(model)
	return model


static func _compile_floors(spec: LevelSpec, model: ParkModel) -> void:
	var i := 0
	for floor in spec.floors:
		var patch := SupportPatch.new()
		patch.id = "floor_%d_L%d" % [i, int(floor.get("layer", 0))]
		patch.kind = SimKinds.SurfaceKind.FLOOR
		patch.height = float(floor.get("height", 0.0))
		patch.base_height = patch.height
		patch.poly = floor.get("poly", PackedVector2Array())
		_bounds_from_poly(patch)
		model.patches[patch.id] = patch
		i += 1
	# Lava pads stored as floors with zone in some loaders — check story masks via layers.
	# LevelSpec doesn't separate lava; scan layers for x glyphs into lava patches.
	_compile_lava_from_layers(spec, model)


static func _compile_lava_from_layers(spec: LevelSpec, model: ParkModel) -> void:
	var lava_i := 0
	for L in spec.layers:
		var layer_i := int(L.get("index", 0))
		var base_h := float(L.get("height", 0.0))
		var rows: PackedStringArray = L.get("rows", PackedStringArray())
		var cells: Array = []
		for r in range(rows.size()):
			var line: String = rows[r]
			for c in range(line.length()):
				var ch := line[c]
				if ch == "x" or ch == "X":
					cells.append(Vector2i(c, r))
		if cells.is_empty():
			continue
		# Merge 4-connected lava into components.
		for comp in _components(cells):
			var patch := SupportPatch.new()
			patch.id = "lava_%d_L%d" % [lava_i, layer_i]
			patch.kind = SimKinds.SurfaceKind.LAVA
			patch.height = base_h
			patch.base_height = base_h
			patch.lethal = true
			patch.poly = _outline_poly(comp, spec.cell_w, spec.cell_h, spec.grid_h)
			_bounds_from_poly(patch)
			model.patches[patch.id] = patch
			lava_i += 1


static func _compile_decks(spec: LevelSpec, model: ParkModel) -> void:
	var i := 0
	for deck in spec.decks:
		var patch := SupportPatch.new()
		patch.id = "deck_%d_L%d" % [i, int(deck.get("layer", 0))]
		patch.kind = SimKinds.SurfaceKind.DECK
		patch.height = float(deck.get("height", 0.0))
		patch.base_height = float(deck.get("base_height", 0.0))
		patch.poly = deck.get("poly", PackedVector2Array())
		_bounds_from_poly(patch)
		model.patches[patch.id] = patch
		i += 1


static func _compile_pipes(spec: LevelSpec, model: ParkModel) -> void:
	# Group LevelSpec pipe dicts by (side, layer, connected Z/X runs).
	# Existing loader already emits one dict per contiguous run component.
	var i := 0
	for p in spec.pipes:
		var pipe := PipeSurface.new()
		var side := int(p.get("side", 0))
		var layer := int(p.get("layer", 0))
		pipe.id = "pipe_%d_L%d_S%d" % [i, layer, side]
		pipe.side = side
		pipe.z_min = float(p.get("z_min", 0.0))
		pipe.z_max = float(p.get("z_max", 0.0))
		var lip := float(p.get("lip_x", 0.0))
		var radius := float(p.get("radius", 0.0))
		var base_h := float(p.get("base_height", 0.0))
		# Uniform sample at z_min/z_max (loader stores constant R per component).
		pipe.samples = [
			{"z": pipe.z_min, "lip_x": lip, "radius": radius, "base_height": base_h},
			{"z": pipe.z_max, "lip_x": lip, "radius": radius, "base_height": base_h},
		]
		var cope := CopingEdge.new()
		cope.id = "coping_%s" % pipe.id
		cope.pipe_id = pipe.id
		cope.side = side
		cope.z_min = pipe.z_min
		cope.z_max = pipe.z_max
		cope.outward_sign = -1.0 if side == SimKinds.PipeSide.LEFT else 1.0
		var cx := lip - radius if side == SimKinds.PipeSide.LEFT else lip + radius
		var ch := base_h + radius
		cope.height_samples = [
			{"z": pipe.z_min, "height": ch, "coping_x": cx},
			{"z": pipe.z_max, "height": ch, "coping_x": cx},
		]
		cope.coping_class = SimKinds.CopingClass.OPEN
		pipe.coping_id = cope.id
		model.pipes[pipe.id] = pipe
		model.copings[cope.id] = cope
		i += 1

	# Refine variable-width lofts from layer glyphs when widths change along Z.
	_refine_pipe_lofts_from_glyphs(spec, model)


static func _refine_pipe_lofts_from_glyphs(spec: LevelSpec, model: ParkModel) -> void:
	# For each pipe, rebuild samples from per-row run widths that match side+lip band.
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		var new_samples: Array = []
		for L in spec.layers:
			var layer_i := int(L.get("index", 0))
			# Match by base_height ≈ layer height for this pipe's first sample.
			var base0 := float((pipe.samples[0] as Dictionary).base_height)
			var lh := float(L.get("height", 0.0))
			if absf(base0 - lh) > 0.5:
				continue
			var rows: PackedStringArray = L.get("rows", PackedStringArray())
			var glyph := "<" if pipe.side == SimKinds.PipeSide.LEFT else ">"
			for r in range(rows.size()):
				var z0 := float(spec.grid_h - 1 - r) * spec.cell_h
				var z1 := float(spec.grid_h - r) * spec.cell_h
				var z_mid := (z0 + z1) * 0.5
				if z_mid < pipe.z_min - 0.01 or z_mid > pipe.z_max + 0.01:
					continue
				var line: String = rows[r]
				var run := _pipe_run_on_row(line, glyph, pipe, spec)
				if run.is_empty():
					continue
				new_samples.append({
					"z": z_mid,
					"lip_x": float(run.lip_x),
					"radius": float(run.radius),
					"base_height": lh,
				})
		if new_samples.size() >= 2:
			new_samples.sort_custom(func(a, b): return float(a.z) < float(b.z))
			pipe.samples = new_samples
			pipe.z_min = float(new_samples[0].z) - spec.cell_h * 0.5
			pipe.z_max = float(new_samples[new_samples.size() - 1].z) + spec.cell_h * 0.5
			# Refresh coping samples from loft.
			var cope: CopingEdge = model.copings[pipe.coping_id]
			cope.z_min = pipe.z_min
			cope.z_max = pipe.z_max
			var hs: Array = []
			for s in pipe.samples:
				var lip := float(s.lip_x)
				var radius := float(s.radius)
				var base_h := float(s.base_height)
				var cx := lip - radius if pipe.side == SimKinds.PipeSide.LEFT else lip + radius
				hs.append({"z": float(s.z), "height": base_h + radius, "coping_x": cx})
			cope.height_samples = hs


static func _pipe_run_on_row(line: String, glyph: String, pipe: PipeSurface, spec: LevelSpec) -> Dictionary:
	var best := {}
	var c := 0
	while c < line.length():
		if line[c] != glyph:
			c += 1
			continue
		var start := c
		while c < line.length() and line[c] == glyph:
			c += 1
		var width_cells := c - start
		var radius := float(width_cells) * spec.cell_w
		var x0 := float(start) * spec.cell_w
		var x1 := float(c) * spec.cell_w
		var lip: float
		if pipe.side == SimKinds.PipeSide.LEFT:
			lip = x1 ## lip on right edge of < run
		else:
			lip = x0 ## lip on left edge of > run
		# Prefer run whose lip matches existing pipe lip closely.
		var ref_lip := float((pipe.samples[0] as Dictionary).lip_x)
		if absf(lip - ref_lip) < spec.cell_w * 0.6:
			return {"lip_x": lip, "radius": radius}
		if best.is_empty() or absf(lip - ref_lip) < absf(float(best.lip_x) - ref_lip):
			best = {"lip_x": lip, "radius": radius}
	return best


static func _classify_copings(spec: LevelSpec, model: ParkModel) -> void:
	for cope_id in model.copings.keys():
		var cope: CopingEdge = model.copings[cope_id]
		var mid_z := cope.midpoint_z()
		var samp := cope.sample_at_z(mid_z)
		if samp.is_empty():
			continue
		var cx := float(samp.coping_x)
		var ch := float(samp.height)
		var out := cope.outward_sign
		# Probe a point just outward of coping at mid Z.
		var probe_x := cx + out * maxf(spec.cell_w * 0.25, 1.0)
		var best_patch: SupportPatch = null
		var best_h := -INF
		for pid in model.patches.keys():
			var patch: SupportPatch = model.patches[pid]
			if patch.lethal:
				continue
			if not patch.contains_xz(probe_x, mid_z):
				continue
			if patch.height > best_h:
				best_h = patch.height
				best_patch = patch
		if best_patch == null:
			cope.coping_class = SimKinds.CopingClass.OPEN
			continue
		var dh := best_patch.height - ch
		if absf(dh) <= SimTolerances.SEAM_EPS:
			cope.coping_class = SimKinds.CopingClass.SUPPORT_SEAM
			cope.support_patch_id = best_patch.id
		elif dh > SimTolerances.SEAM_EPS:
			cope.coping_class = SimKinds.CopingClass.WALL_EXTENSION
			cope.support_patch_id = best_patch.id
			# Raise effective coping to deck top.
			for s in cope.height_samples:
				s["height"] = best_patch.height
		else:
			# Outward pad below coping — treat as open (can fly over drop).
			cope.coping_class = SimKinds.CopingClass.OPEN


static func _link_shared_spines(model: ParkModel) -> void:
	var ids: Array = model.all_coping_ids()
	var max_gap := model.cell_w * 3.0 + SimTolerances.ALIGN_EPS
	for i in range(ids.size()):
		var a: CopingEdge = model.copings[ids[i]]
		for j in range(i + 1, ids.size()):
			var b: CopingEdge = model.copings[ids[j]]
			if a.side == b.side:
				continue
			# Must face each other: LEFT coping outward −X, RIGHT outward +X.
			# Facing each other means LEFT is to the right of RIGHT (>>> then <<<).
			var z0 := maxf(a.z_min, b.z_min)
			var z1 := minf(a.z_max, b.z_max)
			if z1 - z0 < SimTolerances.ALIGN_EPS:
				continue
			var mid := (z0 + z1) * 0.5
			var sa := a.sample_at_z(mid)
			var sb := b.sample_at_z(mid)
			if sa.is_empty() or sb.is_empty():
				continue
			var ax := float(sa.coping_x)
			var bx := float(sb.coping_x)
			var ah := float(sa.height)
			var bh := float(sb.height)
			if absf(ah - bh) > SimTolerances.SEAM_EPS * 4.0:
				continue
			# Order: right-pipe coping (side RIGHT) should be left of left-pipe coping.
			var right_c: CopingEdge = a if a.side == SimKinds.PipeSide.RIGHT else b
			var left_c: CopingEdge = b if a.side == SimKinds.PipeSide.RIGHT else a
			var rx := float(right_c.sample_at_z(mid).coping_x)
			var lx := float(left_c.sample_at_z(mid).coping_x)
			var gap := lx - rx
			if gap < -SimTolerances.ALIGN_EPS or gap > max_gap:
				continue
			# Optional: deck/floor between them, or near-touching >>><<<.
			if right_c.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
				right_c.coping_class = SimKinds.CopingClass.SHARED_SPINE
			if left_c.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
				left_c.coping_class = SimKinds.CopingClass.SHARED_SPINE
			right_c.shared_with_id = left_c.id
			left_c.shared_with_id = right_c.id


static func _build_topology_edges(model: ParkModel) -> void:
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		var cope: CopingEdge = model.copings.get(pipe.coping_id)
		if cope == null:
			continue
		var edge := TopologyEdge.new()
		edge.id = "edge_%s" % cope.id
		edge.from_surface_id = pipe.id
		edge.coping_id = cope.id
		edge.u_gate = 1.0
		match cope.coping_class:
			SimKinds.CopingClass.SUPPORT_SEAM, SimKinds.CopingClass.WALL_EXTENSION:
				edge.kind = SimKinds.EdgeKind.SEAM
				edge.to_surface_id = cope.support_patch_id
			SimKinds.CopingClass.OPEN, SimKinds.CopingClass.SHARED_SPINE:
				edge.kind = SimKinds.EdgeKind.OPEN_COPING
				edge.to_surface_id = ""
		model.edges[edge.id] = edge


static func _bounds_from_poly(patch: SupportPatch) -> void:
	if patch.poly.is_empty():
		return
	patch.x_min = INF
	patch.x_max = -INF
	patch.z_min = INF
	patch.z_max = -INF
	for p in patch.poly:
		patch.x_min = minf(patch.x_min, p.x)
		patch.x_max = maxf(patch.x_max, p.x)
		patch.z_min = minf(patch.z_min, p.y)
		patch.z_max = maxf(patch.z_max, p.y)


static func _components(cells: Array) -> Array:
	var set := {}
	for c in cells:
		set[c] = true
	var out: Array = []
	var visited := {}
	for c in cells:
		if visited.has(c):
			continue
		var stack: Array = [c]
		var comp: Array = []
		visited[c] = true
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			comp.append(cur)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cur + d
				if set.has(n) and not visited.has(n):
					visited[n] = true
					stack.append(n)
		out.append(comp)
	return out


static func _outline_poly(comp: Array, cw: float, ch: float, grid_h: int) -> PackedVector2Array:
	# Axis-aligned bbox outline (sufficient for support queries).
	var c0 := 999999
	var c1 := -999999
	var r0 := 999999
	var r1 := -999999
	for cell in comp:
		c0 = mini(c0, cell.x)
		c1 = maxi(c1, cell.x)
		r0 = mini(r0, cell.y)
		r1 = maxi(r1, cell.y)
	var x0 := float(c0) * cw
	var x1 := float(c1 + 1) * cw
	var z0 := float(grid_h - 1 - r1) * ch
	var z1 := float(grid_h - r0) * ch
	return PackedVector2Array([
		Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)
	])


static func _hash_model(model: ParkModel) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var buf := PackedByteArray()
	buf.append_array(model.name.to_utf8_buffer())
	for id in model.all_pipe_ids():
		buf.append_array(str(id).to_utf8_buffer())
	for id in model.all_coping_ids():
		var c: CopingEdge = model.copings[id]
		buf.append_array(("%s:%d" % [id, c.coping_class]).to_utf8_buffer())
	for id in model.all_patch_ids():
		buf.append_array(str(id).to_utf8_buffer())
	ctx.update(buf)
	return ctx.finish().hex_encode()
