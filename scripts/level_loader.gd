class_name LevelLoader
extends RefCounted
## Parses .ssk ASCII levels into LevelSpec.
## Malformed files abort the process with a dialog naming the path and reason.

static var last_error: String = ""


static func load_path(path: String) -> LevelSpec:
	last_error = ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_abort("Cannot open level file:\n%s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var spec := parse_text(text, path.get_file().get_basename(), path)
	if spec == null:
		_abort(last_error if last_error != "" else "Malformed level:\n%s" % path)
		return null
	return spec


## Parse only — returns null on error and sets last_error (no quit). Prefer load_path.
static func parse_text(
	text: String, default_name: String = "level", source_path: String = ""
) -> LevelSpec:
	var label := source_path if source_path != "" else default_name
	var lines := text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var spec := LevelSpec.new()
	spec.name = default_name

	var map_rows: PackedStringArray = PackedStringArray()
	var in_map := false
	var got_version := false

	for raw in lines:
		var line: String = raw
		# Strip UTF-8 BOM if present
		if line.begins_with("\ufeff"):
			line = line.substr(1)

		var stripped := line.strip_edges()
		if not in_map:
			if stripped.is_empty():
				continue
			if stripped.begins_with("#"):
				continue
			if stripped.begins_with("ssk"):
				got_version = true
				continue
			if _is_map_separator(stripped):
				in_map = true
				continue
			# Legacy: first map-looking row starts the grid (cannot begin with #
			# because those lines are header comments until ---).
			if _is_map_row(stripped):
				push_warning(
					"LevelLoader: %s — map started without '---' separator; add a '---' line after the header so rows can begin with #"
					% label
				)
				in_map = true
				map_rows.append(line.rstrip("\n").rstrip("\r"))
				continue
			_parse_header_kv(spec, stripped)
		else:
			if stripped.is_empty():
				continue
			if _is_map_separator(stripped):
				return _fail(label, "extra '---' separator inside map")
			map_rows.append(line.rstrip("\n").rstrip("\r"))

	if not got_version:
		return _fail(label, "missing 'ssk 1' version line")
	if map_rows.is_empty():
		return _fail(label, "no map rows (expected '---' then ASCII grid)")
	if spec.width <= 0.0 or spec.depth <= 0.0:
		return _fail(label, "width and depth are required and must be > 0")

	var width_err := _require_uniform_row_widths(map_rows)
	if width_err != "":
		return _fail(label, width_err)

	var err := _build_geometry(spec, map_rows)
	if err != "":
		return _fail(label, err)
	return spec


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
	if key in ["ssk", "name", "width", "depth", "pipe_radius", "deck_height", "perspective_inset", "far_geometry_scale", "reference_depth", "spawn_facing"]:
		return false
	# Must contain at least one map glyph (not only spaces)
	for glyph in stripped:
		if glyph in ["<", ">", "=", ".", "#", "@", " "]:
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
		"width":
			spec.width = float(val)
		"depth":
			spec.depth = float(val)
		"pipe_radius":
			spec.pipe_radius_override = float(val)
		"deck_height":
			spec.deck_height_override = float(val)
		"perspective_inset":
			spec.perspective_inset = float(val)
		"far_geometry_scale":
			spec.far_geometry_scale = float(val)
		"reference_depth":
			spec.reference_depth = float(val)
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


static func _build_geometry(spec: LevelSpec, map_rows: PackedStringArray) -> String:
	var H := map_rows.size()
	var W := map_rows[0].length()
	var cw := spec.width / float(W)
	var ch := spec.depth / float(H)
	spec.grid_w = W
	spec.grid_h = H
	spec.cell_w = cw
	spec.cell_h = ch

	# grid[row][col] character
	var grid: Array = []
	for r in range(H):
		var row_chars: Array = []
		for c in range(W):
			row_chars.append(map_rows[r][c])
		grid.append(row_chars)

	var spawn_found := false
	var spawn_c := 0
	var spawn_r := 0

	# Classify cells
	var floor_cells: Array = []  # Vector2i
	var deck_cells: Array = []
	var left_cells: Array = []
	var right_cells: Array = []

	for r in range(H):
		for c in range(W):
			var glyph: String = grid[r][c]
			match glyph:
				"=", ".":
					floor_cells.append(Vector2i(c, r))
				"@":
					floor_cells.append(Vector2i(c, r))
					if spawn_found:
						return "multiple @ spawn markers"
					spawn_found = true
					spawn_c = c
					spawn_r = r
				"#":
					deck_cells.append(Vector2i(c, r))
				"<":
					left_cells.append(Vector2i(c, r))
				">":
					right_cells.append(Vector2i(c, r))
				" ":
					pass
				_:
					return "invalid glyph '%s' at col=%d row=%d" % [glyph, c, r]

	if not spawn_found:
		return "missing @ spawn"

	spec.spawn_x = (float(spawn_c) + 0.5) * cw
	spec.spawn_z = (float(H - 1 - spawn_r) + 0.5) * ch

	# Pipes from column-aligned horizontal runs (jagged columns stay separate).
	spec.pipes.clear()
	for pipe in _pipes_from_aligned_runs(grid, W, H, cw, ch, spec.pipe_radius_override):
		spec.pipes.append(pipe)

	# Floors
	spec.floors.clear()
	for comp in _components(floor_cells):
		var poly := _outline_poly(comp, cw, ch, H)
		spec.floors.append({"poly": poly, "height": 0.0})

	# Decks + height + lip anchors (for perspective-consistent drawing)
	spec.decks.clear()
	var deck_comps := _components(deck_cells)
	for comp in deck_comps:
		var neighbors := _deck_neighbor_pipes(comp, grid, W, H, spec.pipes, cw, ch)
		if neighbors.is_empty() and spec.deck_height_override < 0.0:
			return "deck component has no neighboring pipe (set deck_height or place next to <> )"
		var height := spec.deck_height_override
		if height < 0.0:
			height = float(neighbors[0].radius)
			for i in range(1, neighbors.size()):
				var rh := float(neighbors[i].radius)
				if not is_equal_approx(rh, height):
					push_warning(
						"LevelLoader: deck neighbors have unequal pipe radii (%.1f vs %.1f); spine coping will gap. Use matching <> run widths."
						% [height, rh]
					)
				height = maxf(height, rh)
		var anchors: Array = []
		for pipe in neighbors:
			var is_left: bool = pipe.side == QuarterPipe.PipeSide.LEFT
			anchors.append({
				"lip_x": float(pipe.lip_x),
				"side": pipe.side,
				"radius": float(pipe.radius),
				"coping_x": float(pipe.x_min) if is_left else float(pipe.x_max),
			})
		var poly := _outline_poly(comp, cw, ch, H)
		spec.decks.append({"poly": poly, "height": height, "anchors": anchors})

	# Bounds
	spec.z_min = 0.0
	spec.z_max = spec.depth
	spec.x_min = 0.0
	spec.x_max = spec.width
	if not spec.pipes.is_empty() or not spec.floors.is_empty() or not spec.decks.is_empty():
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

	return ""


static func _pipes_from_aligned_runs(
	grid: Array, W: int, H: int, cw: float, ch: float, radius_override: float
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
		pipes.append(_pipe_from_band(band, cw, ch, H, radius_override))
	return pipes


static func _pipe_from_band(
	band: Dictionary, cw: float, ch: float, H: int, radius_override: float
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
