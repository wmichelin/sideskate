class_name LevelLoader
extends RefCounted
## Parses .ssk ASCII levels into LevelSpec.
## World size = glyph columns/rows × cell size (not header width/depth).
## Malformed files abort the process with a dialog naming the path and reason.

static var last_error: String = ""
## Global defaults; RampLevel / debug sliders override per load.
static var cell_size_x: float = 47.0
static var cell_size_z: float = 47.0


static func load_path(
	path: String, cell_x: float = -1.0, cell_z: float = -1.0
) -> LevelSpec:
	last_error = ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_abort("Cannot open level file:\n%s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var spec := parse_text(
		text, path.get_file().get_basename(), path, cell_x, cell_z
	)
	if spec == null:
		_abort(last_error if last_error != "" else "Malformed level:\n%s" % path)
		return null
	return spec


## Parse only — returns null on error and sets last_error (no quit). Prefer load_path.
## Format: ssk 2 with one or more `layer N` / `height` / ASCII map blocks after `---`.
static func parse_text(
	text: String,
	default_name: String = "level",
	source_path: String = "",
	cell_x: float = -1.0,
	cell_z: float = -1.0,
) -> LevelSpec:
	var label := source_path if source_path != "" else default_name
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var spec := LevelSpec.new()
	spec.name = default_name
	var cx := cell_x if cell_x > 0.0 else cell_size_x
	var cz := cell_z if cell_z > 0.0 else cell_size_z

	var got_version := false
	var header_done := false
	var layers: Array = []  # {index, height, rows: PackedStringArray}
	var cur: Dictionary = {}
	var in_layer_map := false

	for raw in lines:
		var line: String = raw
		if line.begins_with("\ufeff"):
			line = line.substr(1)
		var stripped := line.strip_edges()

		if not header_done:
			if stripped.is_empty() or stripped.begins_with("#"):
				continue
			if stripped.begins_with("ssk"):
				var ver := stripped.split(" ", false)
				if ver.size() < 2 or ver[1] != "2":
					return _fail(label, "expected 'ssk 2' (got '%s')" % stripped)
				got_version = true
				continue
			if _is_map_separator(stripped):
				if not got_version:
					return _fail(label, "missing 'ssk 2' version line")
				header_done = true
				continue
			_parse_header_kv(spec, stripped)
			continue

		# Layer body: blank lines outside a map are separators.
		if not in_layer_map and stripped.is_empty():
			continue
		if _is_map_separator(stripped):
			if not cur.is_empty():
				var ferr := _finalize_layer_block(cur, label)
				if ferr != "":
					return _fail(label, ferr)
				layers.append(cur)
				cur = {}
				in_layer_map = false
			continue
		if stripped.begins_with("layer"):
			if in_layer_map or not cur.is_empty():
				var ferr2 := _finalize_layer_block(cur, label)
				if ferr2 != "":
					return _fail(label, ferr2)
				layers.append(cur)
				cur = {}
				in_layer_map = false
			var parts := stripped.split(" ", false)
			if parts.size() < 2 or not str(parts[1]).is_valid_int():
				return _fail(label, "expected 'layer N', got '%s'" % stripped)
			cur = {
				"index": int(parts[1]),
				"height": NAN,
				"rows": PackedStringArray(),
				"got_height": false,
			}
			continue
		if cur.is_empty():
			return _fail(label, "map content before 'layer N' (ssk 2 requires layer blocks)")
		if not in_layer_map and stripped.begins_with("height"):
			var hp := stripped.split(" ", false, 1)
			if hp.size() < 2 or not str(hp[1]).is_valid_float():
				return _fail(label, "expected 'height <float>', got '%s'" % stripped)
			cur.height = float(hp[1])
			cur.got_height = true
			continue
		if not cur.get("got_height", false):
			return _fail(label, "layer %s missing 'height' before map rows" % cur.get("index", "?"))
		in_layer_map = true
		var row := line.rstrip("\n").rstrip("\r")
		# Zero-length lines are EOF noise; all-space rows are OOB cells (keep width).
		if row.is_empty():
			continue
		cur.rows.append(row)

	if not got_version:
		return _fail(label, "missing 'ssk 2' version line")
	if not cur.is_empty():
		var ferr3 := _finalize_layer_block(cur, label)
		if ferr3 != "":
			return _fail(label, ferr3)
		layers.append(cur)
	if layers.is_empty():
		return _fail(label, "no layers (expected '---' then 'layer N' / 'height' / map)")
	if cx <= 0.0 or cz <= 0.0:
		return _fail(label, "cell size must be > 0")

	var err := _build_layered_geometry(spec, layers, cx, cz)
	if err != "":
		return _fail(label, err)
	return spec


static func _finalize_layer_block(cur: Dictionary, _label: String) -> String:
	if cur.is_empty():
		return ""
	if not cur.get("got_height", false) or is_nan(float(cur.get("height", NAN))):
		return "layer %s missing height" % cur.get("index", "?")
	var rows: PackedStringArray = cur.rows
	if rows.is_empty():
		return "layer %s has no map rows" % cur.get("index", "?")
	var width_err := _require_uniform_row_widths(rows)
	if width_err != "":
		return "layer %s: %s" % [cur.get("index", "?"), width_err]
	return ""


static func _fail(source: String, detail: String) -> LevelSpec:
	last_error = "Malformed level '%s':\n%s" % [source, detail]
	push_error(last_error)
	return null


static func _abort(message: String) -> void:
	push_error(message)
	printerr(message)
	OS.alert(message, "SideSkate — malformed level")
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.quit(1)


static func _is_map_separator(stripped: String) -> bool:
	return stripped == "---" or stripped == "map"


static func _is_map_row(stripped: String) -> bool:
	if stripped.is_empty():
		return false
	# Header keys
	var key := stripped.split(" ")[0]
	if key in ["ssk", "name", "width", "depth", "pipe_radius", "deck_height", "perspective_inset", "far_geometry_scale", "reference_depth", "reference_width", "spawn_facing", "layer", "height"]:
		return false
	# Must contain at least one map glyph (not only spaces)
	for glyph in stripped:
		if glyph in ["<", ">", "=", ".", "#", "@", "x", "X", " "]:
			continue
		return false
	for glyph2 in stripped:
		if glyph2 != " ":
			return true
	return false


static func _parse_header_kv(spec: LevelSpec, stripped: String) -> void:
	var parts := stripped.split(" ", false, 1)
	if parts.is_empty():
		return
	var key: String = parts[0]
	var val: String = parts[1] if parts.size() > 1 else ""
	match key:
		"name":
			spec.name = val.strip_edges()
		"width", "depth", "perspective_inset", "far_geometry_scale", "reference_depth", "reference_width":
			# Deprecated: world size / perspective are game-global, not per-level.
			push_warning(
				"LevelLoader: header '%s' is ignored — set on RampLevel / TUNING, not in .ssk"
				% key
			)
		"pipe_radius":
			spec.pipe_radius_override = float(val)
		"deck_height":
			spec.deck_height_override = float(val)
		"spawn_facing":
			var f := val.strip_edges().to_lower()
			if f == "l" or f == "left":
				spec.spawn_facing = "l"
			elif f == "r" or f == "right":
				spec.spawn_facing = "r"
			else:
				push_warning("LevelLoader: spawn_facing must be l or r (got '%s')" % val)
		_:
			push_warning("LevelLoader: unknown header key '%s'" % key)


static func _require_uniform_row_widths(map_rows: PackedStringArray) -> String:
	if map_rows.is_empty():
		return "no map rows"
	var w := map_rows[0].length()
	for i in range(1, map_rows.size()):
		if map_rows[i].length() != w:
			return "map row %d width %d != row 0 width %d (all rows must be the same length)" % [
				i, map_rows[i].length(), w
			]
	return ""


static func _build_layered_geometry(spec: LevelSpec, layers: Array, cell_x: float, cell_z: float) -> String:
	layers.sort_custom(func(a, b): return int(a.index) < int(b.index))
	var seen_idx := {}
	for L in layers:
		var idx: int = int(L.index)
		if seen_idx.has(idx):
			return "duplicate layer %d" % idx
		seen_idx[idx] = true

	var W := -1
	var H := -1
	spec.floors.clear()
	spec.decks.clear()
	spec.pipes.clear()
	spec.floor_cells.clear()
	spec.layers.clear()
	spec.story_floor_masks.clear()
	spec.playable_mask = PackedByteArray()
	spec.floor_mask = PackedByteArray()

	var spawn := {"found": false, "c": 0, "r": 0, "height": 0.0, "layer": 0}
	for L in layers:
		var rows: PackedStringArray = L.rows
		if W < 0:
			W = rows[0].length()
			H = rows.size()
			spec.grid_w = W
			spec.grid_h = H
			spec.cell_w = cell_x
			spec.cell_h = cell_z
			spec.width = float(W) * cell_x
			spec.depth = float(H) * cell_z
			spec.floor_mask.resize(W * H)
			spec.floor_mask.fill(0)
			spec.playable_mask.resize(W * H)
			spec.playable_mask.fill(0)
		else:
			if rows.size() != H:
				return "layer %d row count %d != layer 0 row count %d" % [L.index, rows.size(), H]
			if rows[0].length() != W:
				return "layer %d width %d != layer 0 width %d" % [L.index, rows[0].length(), W]

		var err := _append_layer_geometry(
			spec, rows, cell_x, cell_z, float(L.height), int(L.index), spawn
		)
		if err != "":
			return err

		spec.layers.append({
			"index": int(L.index),
			"height": float(L.height),
			"rows": rows,
		})

	if not spawn.found:
		return "missing @ spawn"
	spec.spawn_x = (float(spawn.c) + 0.5) * cell_x
	spec.spawn_z = (float(H - 1 - spawn.r) + 0.5) * cell_z
	spec.spawn_height = float(spawn.height)
	spec.spawn_layer = int(spawn.layer)

	var footprint_err := _validate_upper_layer_footprint(spec)
	if footprint_err != "":
		return footprint_err

	_recompute_bounds(spec)
	return ""


## Build one layer into spec. `spawn` is {found, c, r, height, layer} mutated in place.
## `=` / `@` = floor; `.` = hole (no floor); space = OOB.
static func _append_layer_geometry(
	spec: LevelSpec,
	map_rows: PackedStringArray,
	cell_x: float,
	cell_z: float,
	base_height: float,
	layer_index: int,
	spawn: Dictionary,
) -> String:
	var H := map_rows.size()
	var W := map_rows[0].length()
	var cw := cell_x
	var ch := cell_z

	var grid: Array = []
	for r in range(H):
		var row_chars: Array = []
		for c in range(W):
			row_chars.append(map_rows[r][c])
		grid.append(row_chars)

	var floor_cells: Array = []
	var deck_cells: Array = []
	var story_mask := PackedByteArray()
	story_mask.resize(W * H)
	story_mask.fill(0)

	for r in range(H):
		for c in range(W):
			var glyph: String = grid[r][c]
			match glyph:
				"=":
					floor_cells.append(Vector2i(c, r))
					story_mask[r * W + c] = 1
				"x", "X":
					# Lava: solid pad at layer height (lethal when grounded).
					# Story mask: 1 = floor, 2 = lava (draw/sample without glyph scan).
					floor_cells.append(Vector2i(c, r))
					story_mask[r * W + c] = 2
				".":
					pass  # hole — valid glyph, no floor
				"@":
					floor_cells.append(Vector2i(c, r))
					story_mask[r * W + c] = 1
					if spawn.found:
						return "multiple @ spawn markers"
					spawn.found = true
					spawn.c = c
					spawn.r = r
					spawn.height = base_height
					spawn.layer = layer_index
				"#":
					deck_cells.append(Vector2i(c, r))
				"<", ">":
					pass
				" ":
					pass
				_:
					return "invalid glyph '%s' at layer %d col=%d row=%d" % [
						glyph, layer_index, c, r
					]

	if layer_index == 0:
		for r in range(H):
			for c in range(W):
				if grid[r][c] != " ":
					spec.playable_mask[r * W + c] = 1

	var layer_pipes: Array = _pipes_from_aligned_runs(
		grid, W, H, cw, ch, spec.pipe_radius_override, base_height
	)
	for pipe in layer_pipes:
		pipe["layer"] = layer_index
		spec.pipes.append(pipe)

	for cell in floor_cells:
		var ci: Vector2i = cell
		spec.floor_cells.append(ci)
		if layer_index == 0:
			spec.floor_mask[ci.y * W + ci.x] = 1
	spec.story_floor_masks.append({"height": base_height, "mask": story_mask, "layer": layer_index})

	for comp in _components(floor_cells):
		var poly := _outline_poly(comp, cw, ch, H)
		spec.floors.append({
			"poly": poly,
			"height": base_height,
			"layer": layer_index,
		})

	var deck_comps := _components(deck_cells)
	for comp in deck_comps:
		var neighbors := _deck_neighbor_pipes(comp, grid, W, H, layer_pipes, cw, ch)
		if neighbors.is_empty() and spec.deck_height_override < 0.0:
			return (
				"layer %d: deck component has no neighboring pipe (set deck_height or place next to <> )"
				% layer_index
			)
		var rise := spec.deck_height_override
		if rise < 0.0:
			rise = float(neighbors[0].radius)
			for i in range(1, neighbors.size()):
				var rh := float(neighbors[i].radius)
				if not is_equal_approx(rh, rise):
					push_warning(
						"LevelLoader: layer %d deck neighbors have unequal pipe radii (%.1f vs %.1f); spine coping will gap. Use matching <> run widths."
						% [layer_index, rise, rh]
					)
				rise = maxf(rise, rh)
		var height := base_height + rise
		var anchors: Array = []
		for pipe in neighbors:
			var is_left: bool = pipe.side == QuarterPipe.PipeSide.LEFT
			anchors.append({
				"lip_x": float(pipe.lip_x),
				"side": pipe.side,
				"radius": float(pipe.radius),
				"coping_x": float(pipe.x_min) if is_left else float(pipe.x_max),
			})
		var dpoly := _outline_poly(comp, cw, ch, H)
		spec.decks.append({
			"poly": dpoly,
			"height": height,
			"anchors": anchors,
			"layer": layer_index,
			"base_height": base_height,
		})

	return ""


## Upper layers must use `.` (not space) inside the layer-0 playable footprint.
static func _validate_upper_layer_footprint(spec: LevelSpec) -> String:
	if spec.layers.size() <= 1 or spec.playable_mask.is_empty():
		return ""
	var W := spec.grid_w
	var H := spec.grid_h
	for L in spec.layers:
		if int(L.get("index", 0)) == 0:
			continue
		var rows: PackedStringArray = L.get("rows", PackedStringArray())
		for r in range(H):
			var line: String = rows[r]
			for c in range(W):
				if spec.playable_mask[r * W + c] == 0:
					continue
				if line[c] == " ":
					return (
						"layer %d: space inside playable footprint at col=%d row=%d (use '.' for holes)"
						% [L.get("index", -1), c, r]
					)
	return ""


static func _recompute_bounds(spec: LevelSpec) -> void:
	spec.z_min = 0.0
	spec.z_max = spec.depth
	spec.x_min = 0.0
	spec.x_max = spec.width
	if spec.pipes.is_empty() and spec.floors.is_empty() and spec.decks.is_empty():
		return
	var xmin := INF
	var xmax := -INF
	var zmin := INF
	var zmax := -INF
	for pipe in spec.pipes:
		xmin = minf(xmin, pipe.x_min)
		xmax = maxf(xmax, pipe.x_max)
		zmin = minf(zmin, pipe.z_min)
		zmax = maxf(zmax, pipe.z_max)
	for region in spec.floors + spec.decks:
		for v in region.poly:
			xmin = minf(xmin, v.x)
			xmax = maxf(xmax, v.x)
			zmin = minf(zmin, v.y)
			zmax = maxf(zmax, v.y)
	spec.x_min = xmin
	spec.x_max = xmax
	spec.z_min = zmin
	spec.z_max = zmax


static func _pipes_from_aligned_runs(
	grid: Array, W: int, H: int, cw: float, ch: float, radius_override: float,
	base_height: float = 0.0
) -> Array:
	# Collect per-row horizontal <> runs, then merge only identical column spans
	# that are contiguous in row — so stepped layouts don't fatten into one AABB.
	var runs: Array = []
	for r in range(H):
		var c := 0
		while c < W:
			var glyph: String = grid[r][c]
			if glyph != "<" and glyph != ">":
				c += 1
				continue
			var c0 := c
			while c < W and grid[r][c] == glyph:
				c += 1
			runs.append({
				"is_left": glyph == "<",
				"c0": c0,
				"c1": c - 1,
				"r0": r,
				"r1": r,
			})

	var used := {}
	var pipes: Array = []
	for i in range(runs.size()):
		if used.has(i):
			continue
		used[i] = true
		var band: Dictionary = runs[i].duplicate()
		var changed := true
		while changed:
			changed = false
			for j in range(runs.size()):
				if used.has(j):
					continue
				var other: Dictionary = runs[j]
				if other.is_left != band.is_left:
					continue
				if other.c0 != band.c0 or other.c1 != band.c1:
					continue
				if other.r0 > band.r1 + 1 or other.r1 < band.r0 - 1:
					continue
				band.r0 = mini(band.r0, other.r0)
				band.r1 = maxi(band.r1, other.r1)
				used[j] = true
				changed = true
		pipes.append(_pipe_from_band(band, cw, ch, H, radius_override, base_height))
	return pipes


static func _pipe_from_band(
	band: Dictionary, cw: float, ch: float, H: int, radius_override: float,
	base_height: float = 0.0
) -> Dictionary:
	var x0 := float(band.c0) * cw
	var x1 := float(band.c1 + 1) * cw
	var z0 := float(H - 1 - band.r1) * ch
	var z1 := float(H - band.r0) * ch
	var radius: float = radius_override if radius_override > 0.0 else (x1 - x0)
	var is_left: bool = band.is_left
	var lip_x: float = x1 if is_left else x0
	return {
		"side": QuarterPipe.PipeSide.LEFT if is_left else QuarterPipe.PipeSide.RIGHT,
		"lip_x": lip_x,
		"radius": radius,
		"base_height": base_height,
		"z_min": z0,
		"z_max": z1,
		"x_min": lip_x - radius if is_left else lip_x,
		"x_max": lip_x if is_left else lip_x + radius,
	}


static func _pipe_from_component(
	comp: Array, is_left: bool, cw: float, ch: float, H: int, radius_override: float
) -> Dictionary:
	var min_c := 999999
	var max_c := -1
	var min_r := 999999
	var max_r := -1
	for cell in comp:
		var ci: Vector2i = cell
		min_c = mini(min_c, ci.x)
		max_c = maxi(max_c, ci.x)
		min_r = mini(min_r, ci.y)
		max_r = maxi(max_r, ci.y)

	var x0 := float(min_c) * cw
	var x1 := float(max_c + 1) * cw
	# row r → z in [(H-1-r)*ch, (H-r)*ch]; min_r is far (high z), max_r is near (low z)
	var z0 := float(H - 1 - max_r) * ch
	var z1 := float(H - min_r) * ch

	var radius: float
	if radius_override > 0.0:
		radius = radius_override
	else:
		radius = x1 - x0

	var lip_x: float
	if is_left:
		lip_x = x1  # right edge of < run
	else:
		lip_x = x0  # left edge of > run

	return {
		"side": QuarterPipe.PipeSide.LEFT if is_left else QuarterPipe.PipeSide.RIGHT,
		"lip_x": lip_x,
		"radius": radius,
		"z_min": z0,
		"z_max": z1,
		"x_min": lip_x - radius if is_left else lip_x,
		"x_max": lip_x if is_left else lip_x + radius,
	}


static func _deck_neighbor_pipes(
	comp: Array, grid: Array, W: int, H: int, pipes: Array, cw: float, ch: float
) -> Array:
	var out: Array = []
	var seen_pipes := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for cell in comp:
		var ci: Vector2i = cell
		for d in dirs:
			var n: Vector2i = ci + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H:
				continue
			var chv: String = grid[n.y][n.x]
			if chv != "<" and chv != ">":
				continue
			var nx := (float(n.x) + 0.5) * cw
			var nz := (float(H - 1 - n.y) + 0.5) * ch
			for pi in range(pipes.size()):
				var pipe: Dictionary = pipes[pi]
				if nx < pipe.x_min - 0.001 or nx > pipe.x_max + 0.001:
					continue
				if nz < pipe.z_min - 0.001 or nz > pipe.z_max + 0.001:
					continue
				if seen_pipes.has(pi):
					continue
				seen_pipes[pi] = true
				out.append(pipe)
	return out


static func _components(cells: Array) -> Array:
	var set := {}
	for c in cells:
		set[c] = true
	var comps: Array = []
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
		comps.append(comp)
	return comps


## Build rectilinear outline in XZ (Vector2 x,z) from tile cells.
static func _outline_poly(comp: Array, cw: float, ch: float, H: int) -> PackedVector2Array:
	# Edge map: undirected edges as string keys; count occurrences
	var edges := {}
	for cell in comp:
		var ci: Vector2i = cell
		var x0 := float(ci.x) * cw
		var x1 := float(ci.x + 1) * cw
		var z0 := float(H - 1 - ci.y) * ch
		var z1 := float(H - ci.y) * ch
		_add_edge(edges, Vector2(x0, z0), Vector2(x1, z0))
		_add_edge(edges, Vector2(x1, z0), Vector2(x1, z1))
		_add_edge(edges, Vector2(x1, z1), Vector2(x0, z1))
		_add_edge(edges, Vector2(x0, z1), Vector2(x0, z0))

	# Keep edges that appear once (boundary)
	var boundary: Array = []  # each [Vector2, Vector2]
	for key in edges:
		if edges[key] == 1:
			var parts: PackedStringArray = key.split("|")
			var a_parts := parts[0].split(",")
			var b_parts := parts[1].split(",")
			boundary.append([
				Vector2(float(a_parts[0]), float(a_parts[1])),
				Vector2(float(b_parts[0]), float(b_parts[1])),
			])

	if boundary.is_empty():
		return PackedVector2Array()

	# Chain into a loop
	var poly := PackedVector2Array()
	var current: Vector2 = boundary[0][0]
	var next: Vector2 = boundary[0][1]
	var used := {}
	used[0] = true
	poly.append(current)

	for _i in range(boundary.size()):
		poly.append(next)
		current = next
		var found := false
		for j in range(boundary.size()):
			if used.has(j):
				continue
			var e: Array = boundary[j]
			if e[0].distance_to(current) < 0.0001:
				next = e[1]
				used[j] = true
				found = true
				break
			if e[1].distance_to(current) < 0.0001:
				next = e[0]
				used[j] = true
				found = true
				break
		if not found:
			break
		if next.distance_to(poly[0]) < 0.0001:
			break

	# Remove duplicate closing point if present
	if poly.size() > 1 and poly[poly.size() - 1].distance_to(poly[0]) < 0.0001:
		poly.resize(poly.size() - 1)
	return _simplify_colinear(poly)


static func _simplify_colinear(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3:
		return poly
	var out := PackedVector2Array()
	var n := poly.size()
	for i in range(n):
		var prev: Vector2 = poly[(i - 1 + n) % n]
		var cur: Vector2 = poly[i]
		var next: Vector2 = poly[(i + 1) % n]
		var ab := cur - prev
		var bc := next - cur
		# Drop vertices that sit on a straight axis-aligned or colinear run.
		if absf(ab.x * bc.y - ab.y * bc.x) < 0.0001:
			continue
		out.append(cur)
	return out if out.size() >= 3 else poly


static func _add_edge(edges: Dictionary, a: Vector2, b: Vector2) -> void:
	var key := _edge_key(a, b)
	edges[key] = int(edges.get(key, 0)) + 1


static func _edge_key(a: Vector2, b: Vector2) -> String:
	# Canonical order
	if a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y):
		return "%.6f,%.6f|%.6f,%.6f" % [a.x, a.y, b.x, b.y]
	return "%.6f,%.6f|%.6f,%.6f" % [b.x, b.y, a.x, a.y]
