class_name LevelLoader
extends RefCounted
## Parses .ssk ASCII levels into LevelSpec.


static func load_path(path: String) -> LevelSpec:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelLoader: cannot open %s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var spec := parse_text(text, path.get_file().get_basename())
	return spec


static func parse_text(text: String, default_name: String = "level") -> LevelSpec:
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
			if _is_map_row(stripped):
				in_map = true
				map_rows.append(line.rstrip("\n").rstrip("\r"))
				continue
			_parse_header_kv(spec, stripped)
		else:
			# Once map starts, non-empty lines are map (comments only if entire line is #comment with no map glyphs — treat # as deck)
			if stripped.is_empty():
				continue
			map_rows.append(line.rstrip("\n").rstrip("\r"))

	if not got_version:
		push_error("LevelLoader: missing 'ssk 1' version line")
		return null
	if map_rows.is_empty():
		push_error("LevelLoader: no map rows")
		return null
	if spec.width <= 0.0 or spec.depth <= 0.0:
		push_error("LevelLoader: width and depth are required and must be > 0")
		return null

	_normalize_row_widths(map_rows)
	var err := _build_geometry(spec, map_rows)
	if err != "":
		push_error("LevelLoader: %s" % err)
		return null
	return spec


static func _is_map_row(stripped: String) -> bool:
	if stripped.is_empty():
		return false
	# Header keys
	var key := stripped.split(" ")[0]
	if key in ["ssk", "name", "width", "depth", "pipe_radius", "deck_height", "perspective_inset", "far_geometry_scale"]:
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
		_:
			push_warning("LevelLoader: unknown header key '%s'" % key)


static func _normalize_row_widths(map_rows: PackedStringArray) -> void:
	var max_w := 0
	for r in map_rows:
		max_w = maxi(max_w, r.length())
	for i in range(map_rows.size()):
		while map_rows[i].length() < max_w:
			map_rows[i] += " "


static func _build_geometry(spec: LevelSpec, map_rows: PackedStringArray) -> String:
	var H := map_rows.size()
	var W := map_rows[0].length()
	var cw := spec.width / float(W)
	var ch := spec.depth / float(H)

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

	# Pipes from components
	var left_comps := _components(left_cells)
	var right_comps := _components(right_cells)
	spec.pipes.clear()

	for comp in left_comps:
		var pipe := _pipe_from_component(comp, true, cw, ch, H, spec.pipe_radius_override)
		spec.pipes.append(pipe)
	for comp in right_comps:
		var pipe := _pipe_from_component(comp, false, cw, ch, H, spec.pipe_radius_override)
		spec.pipes.append(pipe)

	# Floors
	spec.floors.clear()
	for comp in _components(floor_cells):
		var poly := _outline_poly(comp, cw, ch, H)
		spec.floors.append({"poly": poly, "height": 0.0})

	# Decks + height
	spec.decks.clear()
	var deck_comps := _components(deck_cells)
	for comp in deck_comps:
		var height := spec.deck_height_override
		if height < 0.0:
			height = _deck_height_from_neighbors(comp, grid, W, H, spec.pipes, cw, ch)
			if height < 0.0:
				return "deck component has no neighboring pipe (set deck_height or place next to <> )"
		var poly := _outline_poly(comp, cw, ch, H)
		spec.decks.append({"poly": poly, "height": height})

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


static func _deck_height_from_neighbors(
	comp: Array, grid: Array, W: int, H: int, pipes: Array, cw: float, ch: float
) -> float:
	var best := -1.0
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
			# Find pipe covering this neighbor tile center
			var nx := (float(n.x) + 0.5) * cw
			var nz := (float(H - 1 - n.y) + 0.5) * ch
			for pipe in pipes:
				if nx >= pipe.x_min - 0.001 and nx <= pipe.x_max + 0.001 \
						and nz >= pipe.z_min - 0.001 and nz <= pipe.z_max + 0.001:
					best = maxf(best, float(pipe.radius))
	return best


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
	return poly


static func _add_edge(edges: Dictionary, a: Vector2, b: Vector2) -> void:
	var key := _edge_key(a, b)
	edges[key] = int(edges.get(key, 0)) + 1


static func _edge_key(a: Vector2, b: Vector2) -> String:
	# Canonical order
	if a.x < b.x or (is_equal_approx(a.x, b.x) and a.y < b.y):
		return "%.6f,%.6f|%.6f,%.6f" % [a.x, a.y, b.x, b.y]
	return "%.6f,%.6f|%.6f,%.6f" % [b.x, b.y, a.x, a.y]
