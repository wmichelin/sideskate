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
	_link_shared_spines(model)
	_merge_equivalent_coping_spans(model)
	_build_topology_edges(model)
	_add_void_floor(model)
	model.model_hash = _hash_model(model)
	return model


## Invisible floor under the whole park AABB — catches holes / fall-through.
static func _add_void_floor(model: ParkModel) -> void:
	var patch := SupportPatch.new()
	patch.id = "__void_floor__"
	patch.kind = SimKinds.SurfaceKind.FLOOR
	patch.height = SimTolerances.VOID_FLOOR
	patch.base_height = SimTolerances.VOID_FLOOR
	patch.lethal = false
	# Pad past AABB so a brief Z overshoot still has a support under feet.
	var pad := SimTolerances.CAPSULE_RADIUS * 2.0
	var w := maxf(model.width, model.cell_w) + pad
	var d := maxf(model.depth, model.cell_h) + pad
	patch.poly = PackedVector2Array([
		Vector2(-pad, -pad),
		Vector2(w, -pad),
		Vector2(w, d),
		Vector2(-pad, d),
	])
	_bounds_from_poly(patch)
	model.patches[patch.id] = patch


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
			var glyph := "(" if pipe.side == SimKinds.PipeSide.LEFT else ")"
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
		var breaks: Array[float] = [cope.z_min, cope.z_max]
		for pid in model.patches.keys():
			var patch: SupportPatch = model.patches[pid]
			if patch.z_max <= cope.z_min + 0.001 or patch.z_min >= cope.z_max - 0.001:
				continue
			breaks.append(clampf(patch.z_min, cope.z_min, cope.z_max))
			breaks.append(clampf(patch.z_max, cope.z_min, cope.z_max))
		for pipe_id in model.pipes.keys():
			var other: PipeSurface = model.pipes[pipe_id]
			if other.id == cope.pipe_id:
				continue
			if other.z_max <= cope.z_min + 0.001 or other.z_min >= cope.z_max - 0.001:
				continue
			breaks.append(clampf(other.z_min, cope.z_min, cope.z_max))
			breaks.append(clampf(other.z_max, cope.z_min, cope.z_max))
		breaks.sort()
		var unique: Array[float] = []
		for value in breaks:
			if unique.is_empty() or absf(value - unique[-1]) > 0.01:
				unique.append(value)
		cope.spans.clear()
		cope.support_patch_id = ""
		cope.shared_with_id = ""
		cope.coping_class = SimKinds.CopingClass.OPEN
		for i in range(unique.size() - 1):
			var z0 := unique[i]
			var z1 := unique[i + 1]
			if z1 - z0 <= 0.01:
				continue
			var mid := (z0 + z1) * 0.5
			var desc := _classify_coping_at(spec, model, cope, mid)
			var span := CopingSpan.new()
			span.id = "span_%s_%d" % [cope.id, cope.spans.size()]
			span.coping_id = cope.id
			span.z_min = z0
			span.z_max = z1
			span.coping_class = int(desc.class)
			span.support_patch_id = str(desc.get("support_patch_id", ""))
			span.outward_deck_id = str(desc.get("outward_deck_id", ""))
			span.partner_coping_id = str(desc.get("partner_coping_id", ""))
			var h0 := _effective_height_for_desc(model, cope, desc, z0)
			var h1 := _effective_height_for_desc(model, cope, desc, z1)
			span.effective_height_samples = [
				{"z": z0, "height": h0},
				{"z": z1, "height": h1},
			]
			if span.coping_class == SimKinds.CopingClass.WALL_EXTENSION:
				var wall := _build_wall_surface(model, cope, span, desc)
				span.wall_id = wall.id
				model.walls[wall.id] = wall
				cope.coping_class = SimKinds.CopingClass.WALL_EXTENSION
				if not span.support_patch_id.is_empty():
					cope.support_patch_id = span.support_patch_id
			elif cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
				cope.coping_class = span.coping_class
			cope.spans.append(span)


static func _classify_coping_at(
	spec: LevelSpec, model: ParkModel, cope: CopingEdge, z: float
) -> Dictionary:
	var samp := cope.sample_at_z(z)
	if samp.is_empty():
		return {"class": SimKinds.CopingClass.OPEN}
	var cx := float(samp.coping_x)
	var ch := float(samp.height)
	var out := cope.outward_sign
	var desc := {"class": SimKinds.CopingClass.OPEN}
	var probe_x := cx + out * maxf(spec.cell_w * 0.25, 1.0)
	var best_patch: SupportPatch = null
	for pid in model.patches.keys():
		var patch: SupportPatch = model.patches[pid]
		if patch.lethal or not patch.contains_xz(probe_x, z):
			continue
		if best_patch == null or patch.height > best_patch.height:
			best_patch = patch
	if best_patch != null:
		if best_patch.kind == SimKinds.SurfaceKind.DECK:
			desc = {
				"class": SimKinds.CopingClass.OPEN,
				"outward_deck_id": best_patch.id,
			}
		else:
			var dh := best_patch.height - ch
			if absf(dh) <= SimTolerances.SEAM_EPS:
				desc = {
					"class": SimKinds.CopingClass.SUPPORT_SEAM,
					"support_patch_id": best_patch.id,
				}
			elif dh > SimTolerances.SEAM_EPS:
				desc = {
					"class": SimKinds.CopingClass.WALL_EXTENSION,
					"support_patch_id": best_patch.id,
				}
	# A taller opposite pipe creates a story wall and is action-only at the top.
	var max_gap := model.cell_w * 3.0 + SimTolerances.ALIGN_EPS
	var best_other: PipeSurface = null
	var best_h := -INF
	for pipe_id in model.pipes.keys():
		var other: PipeSurface = model.pipes[pipe_id]
		if other.id == cope.pipe_id or other.side == cope.side or not other.contains_xz(
			other.coping_x_at(z), z
		):
			continue
		if z < other.z_min - 0.001 or z > other.z_max + 0.001:
			continue
		var ox := other.coping_x_at(z)
		var oh := other.height_at_theta(z, PI * 0.5)
		if is_nan(ox) or is_nan(oh):
			continue
		var gap := ox - cx if cope.side == SimKinds.PipeSide.RIGHT else cx - ox
		if gap < -SimTolerances.ALIGN_EPS or gap > max_gap:
			continue
		if oh <= ch + SimTolerances.SEAM_EPS or oh <= best_h:
			continue
		best_h = oh
		best_other = other
	if best_other != null:
		desc = {
			"class": SimKinds.CopingClass.WALL_EXTENSION,
			"partner_pipe_id": best_other.id,
			"partner_coping_id": best_other.coping_id,
		}
	return desc


static func _effective_height_for_desc(
	model: ParkModel, cope: CopingEdge, desc: Dictionary, z: float
) -> float:
	var support_id := str(desc.get("support_patch_id", ""))
	if model.patches.has(support_id):
		return model.patches[support_id].height
	var partner_id := str(desc.get("partner_pipe_id", ""))
	if model.pipes.has(partner_id):
		var partner: PipeSurface = model.pipes[partner_id]
		return partner.height_at_theta(z, PI * 0.5)
	return float(cope.sample_at_z(z).height)


static func _build_wall_surface(
	model: ParkModel, cope: CopingEdge, span: CopingSpan, desc: Dictionary
) -> WallSurface:
	var wall := WallSurface.new()
	wall.id = "wall_%s" % span.id
	wall.source_pipe_id = cope.pipe_id
	wall.source_coping_id = cope.id
	wall.coping_span_id = span.id
	wall.z_min = span.z_min
	wall.z_max = span.z_max
	wall.top_support_id = span.support_patch_id
	wall.upper_partner_pipe_id = str(desc.get("partner_pipe_id", ""))
	for z in [span.z_min, span.z_max]:
		var geom := cope.sample_at_z(z)
		wall.samples.append({
			"z": z,
			"x": float(geom.coping_x),
			"bottom_height": float(geom.height),
			"top_height": span.effective_height_at(z),
		})
	return wall


static func _link_shared_spines(model: ParkModel) -> void:
	var ids: Array = model.all_coping_ids()
	var max_gap := model.cell_w * 3.0 + SimTolerances.ALIGN_EPS
	var max_dh := SimTolerances.SEAM_EPS * 4.0
	for i in range(ids.size()):
		var a: CopingEdge = model.copings[ids[i]]
		for j in range(i + 1, ids.size()):
			var b: CopingEdge = model.copings[ids[j]]
			if a.side == b.side:
				continue
			var right_c: CopingEdge = a if a.side == SimKinds.PipeSide.RIGHT else b
			var left_c: CopingEdge = b if a.side == SimKinds.PipeSide.RIGHT else a
			var linked := false
			for span_value in right_c.spans:
				var right_span: CopingSpan = span_value
				if right_span.coping_class != SimKinds.CopingClass.OPEN \
						or not right_span.partner_coping_id.is_empty():
					continue
				for left_value in left_c.spans:
					var left_span: CopingSpan = left_value
					if left_span.coping_class != SimKinds.CopingClass.OPEN \
							or not left_span.partner_coping_id.is_empty():
						continue
					var z0 := maxf(right_span.z_min, left_span.z_min)
					var z1 := minf(right_span.z_max, left_span.z_max)
					if z1 - z0 < SimTolerances.ALIGN_EPS:
						continue
					var mid := (z0 + z1) * 0.5
					var rs := right_c.sample_at_z(mid)
					var ls := left_c.sample_at_z(mid)
					var dh := absf(float(rs.height) - float(ls.height))
					var gap := float(ls.coping_x) - float(rs.coping_x)
					if dh > max_dh or gap < -SimTolerances.ALIGN_EPS or gap > max_gap:
						continue
					right_span.coping_class = SimKinds.CopingClass.SHARED_SPINE
					right_span.partner_coping_id = left_c.id
					left_span.coping_class = SimKinds.CopingClass.SHARED_SPINE
					left_span.partner_coping_id = right_c.id
					linked = true
					break
			if linked:
				if right_c.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
					right_c.coping_class = SimKinds.CopingClass.SHARED_SPINE
					right_c.shared_with_id = left_c.id
				if left_c.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
					left_c.coping_class = SimKinds.CopingClass.SHARED_SPINE
					left_c.shared_with_id = right_c.id


## Global Z breakpoints are needed while classifying cross-story contacts, but
## they must not become gameplay seams on an otherwise continuous coping.
static func _merge_equivalent_coping_spans(model: ParkModel) -> void:
	for coping_id in model.all_coping_ids():
		var coping: CopingEdge = model.copings[coping_id]
		var merged: Array = []
		for span_value in coping.spans:
			var span: CopingSpan = span_value
			var previous: CopingSpan = merged[-1] if not merged.is_empty() else null
			if previous == null or not _coping_spans_are_equivalent(previous, span):
				merged.append(span)
				continue
			previous.z_max = span.z_max
			for i in range(1, span.effective_height_samples.size()):
				previous.effective_height_samples.append(span.effective_height_samples[i])
		coping.spans = merged


static func _coping_spans_are_equivalent(a: CopingSpan, b: CopingSpan) -> bool:
	# Wall surfaces own their own sampled geometry and IDs, so retain their
	# explicit spans. Non-wall spans can preserve every height sample when joined.
	return (
		a.wall_id.is_empty()
		and b.wall_id.is_empty()
		and absf(a.z_max - b.z_min) <= 0.01
		and a.coping_class == b.coping_class
		and a.support_patch_id == b.support_patch_id
		and a.outward_deck_id == b.outward_deck_id
		and a.partner_coping_id == b.partner_coping_id
	)


static func _build_topology_edges(model: ParkModel) -> void:
	model.edges.clear()
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		var cope: CopingEdge = model.copings.get(pipe.coping_id)
		if cope == null:
			continue
		for span_value in cope.spans:
			var span: CopingSpan = span_value
			var edge := TopologyEdge.new()
			edge.id = "edge_%s_coping" % span.id
			edge.from_surface_id = pipe.id
			edge.coping_id = cope.id
			edge.z_min = span.z_min
			edge.z_max = span.z_max
			edge.boundary = "coping"
			edge.u_gate = 1.0
			edge.transfer_target_id = span.partner_coping_id
			if not span.wall_id.is_empty():
				edge.kind = SimKinds.EdgeKind.SEAM
				edge.to_surface_id = span.wall_id
			elif span.coping_class == SimKinds.CopingClass.SUPPORT_SEAM:
				edge.kind = SimKinds.EdgeKind.SEAM
				edge.to_surface_id = span.support_patch_id
			else:
				edge.kind = SimKinds.EdgeKind.OPEN_COPING
				edge.to_surface_id = ""
			model.edges[edge.id] = edge
	for wall_id in model.walls.keys():
		var wall: WallSurface = model.walls[wall_id]
		var bottom := TopologyEdge.new()
		bottom.id = "edge_%s_bottom" % wall.id
		bottom.from_surface_id = wall.id
		bottom.to_surface_id = wall.source_pipe_id
		bottom.coping_id = wall.source_coping_id
		bottom.kind = SimKinds.EdgeKind.SEAM
		bottom.boundary = "bottom"
		bottom.u_gate = 0.0
		bottom.z_min = wall.z_min
		bottom.z_max = wall.z_max
		model.edges[bottom.id] = bottom
		var top := TopologyEdge.new()
		top.id = "edge_%s_top" % wall.id
		top.from_surface_id = wall.id
		top.to_surface_id = wall.top_support_id
		top.coping_id = wall.source_coping_id
		top.boundary = "top"
		top.u_gate = 1.0
		top.z_min = wall.z_min
		top.z_max = wall.z_max
		if wall.top_support_id.is_empty():
			top.kind = SimKinds.EdgeKind.OPEN_COPING
		else:
			top.kind = SimKinds.EdgeKind.SEAM
		if not wall.upper_partner_pipe_id.is_empty():
			var partner: PipeSurface = model.pipes[wall.upper_partner_pipe_id]
			top.transfer_target_id = partner.coping_id
		model.edges[top.id] = top


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
	var lines: PackedStringArray = PackedStringArray()
	lines.append("name:%s" % model.name)
	for id in model.all_pipe_ids():
		var pipe: PipeSurface = model.pipes[id]
		lines.append("pipe:%s:%d:%.4f:%.4f" % [id, pipe.side, pipe.z_min, pipe.z_max])
		for sample_value in pipe.samples:
			var sample: Dictionary = sample_value
			lines.append(
				"ps:%.4f:%.4f:%.4f:%.4f"
				% [sample.z, sample.lip_x, sample.radius, sample.base_height]
			)
	for id in model.all_wall_ids():
		var wall: WallSurface = model.walls[id]
		lines.append(
			"wall:%s:%s:%s:%s:%.4f:%.4f"
			% [
				id,
				wall.source_pipe_id,
				wall.top_support_id,
				wall.upper_partner_pipe_id,
				wall.z_min,
				wall.z_max,
			]
		)
		for sample_value in wall.samples:
			var sample: Dictionary = sample_value
			lines.append(
				"ws:%.4f:%.4f:%.4f:%.4f"
				% [sample.z, sample.x, sample.bottom_height, sample.top_height]
			)
	for id in model.all_coping_ids():
		var c: CopingEdge = model.copings[id]
		lines.append("cope:%s:%d:%s" % [id, c.coping_class, c.shared_with_id])
		for span_value in c.spans:
			var span: CopingSpan = span_value
			lines.append(
				"span:%s:%d:%.4f:%.4f:%s:%s:%s:%s"
				% [
					span.id,
					span.coping_class,
					span.z_min,
					span.z_max,
					span.support_patch_id,
					span.outward_deck_id,
					span.wall_id,
					span.partner_coping_id,
				]
			)
	var patch_ids: Array = model.all_patch_ids()
	patch_ids.sort()
	for id in patch_ids:
		var patch: SupportPatch = model.patches[id]
		lines.append(
			"patch:%s:%d:%.4f:%.4f:%s"
			% [id, patch.kind, patch.height, patch.base_height, patch.lethal]
		)
		for point in patch.poly:
			lines.append("pp:%.4f:%.4f" % [point.x, point.y])
	for id in model.all_edge_ids():
		var edge: TopologyEdge = model.edges[id]
		lines.append(
			"edge:%s:%d:%s:%s:%s:%.4f:%.4f:%s"
			% [
				id,
				edge.kind,
				edge.from_surface_id,
				edge.to_surface_id,
				edge.boundary,
				edge.z_min,
				edge.z_max,
				edge.transfer_target_id,
			]
		)
	ctx.update("\n".join(lines).to_utf8_buffer())
	return ctx.finish().hex_encode()
