extends Node2D
## Surface-only level draw: floors, pipe ribbons, elevated deck tops.
## Drawn in a skater-centered Z window (lean band + pad); deep parks match shorts.

@export var grid_steps: int = 5
## How many iso-u depth strokes to split the pipe face into (not cross-section arcs).
@export var arc_ribs: int = 5
## Extra Z past the lean band on near and far sides, as a fraction of reference_depth.
## 0 = tight lean window; ~0.55 lets pipes continue into parallel perspective lines.
@export_range(0.0, 2.0, 0.05) var draw_band_pad: float = 0.55
## Faint white depth bands across the plaza. Off by default (debug clutter).
@export var show_depth_grid: bool = false
## Highlight the .ssk ASCII cell under the player (logical unit 1:1). Debug only.
@export var debug_cell_highlight: bool = false
@export var player_path: NodePath = NodePath("../../Player")
@export var cell_highlight_fill: Color = Color(1.0, 0.92, 0.2, 0.35)
@export var cell_highlight_stroke: Color = Color(1.0, 0.85, 0.1, 0.95)

var _level: RampLevel
var _player: Node2D


func _ready() -> void:
	z_index = -50
	_level = get_parent() as RampLevel
	_player = get_node_or_null(player_path) as Node2D
	if not DebugTools.is_available():
		debug_cell_highlight = false
	queue_redraw()


func _process(_delta: float) -> void:
	if DebugTools.is_available() and debug_cell_highlight:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _level == null:
		return
	var band := _view_z_band()
	_draw_backdrop_pad(band)
	_draw_floors(band)
	for pipe in _pipes_far_to_near():
		_draw_pipe(pipe, band)
	_draw_decks(band)
	if show_depth_grid:
		_draw_depth_grid(band)
	_draw_player_cell_highlight()


## Skater-centered draw window: lean band (±ref/2) plus pad into near/far parallels.
func _view_z_band() -> Vector2:
	var ref := maxf(_level.reference_depth, 0.0001)
	var half := ref * (0.5 + maxf(draw_band_pad, 0.0))
	var oz := _level.perspective_origin_z
	return Vector2(maxf(oz - half, _level.z_min), minf(oz + half, _level.z_max))


func _z_slice_count(z0: float, z1: float) -> int:
	var ref := maxf(_level.reference_depth, 1.0)
	var span := absf(z1 - z0)
	# Keep segments short so chords stay accurate once t clamps outside the lean band.
	return clampi(int(ceil(span / maxf(ref * 0.12, 16.0))), 4, 28)


func _pipes_far_to_near() -> Array:
	var pipes: Array = _level.pipes.duplicate()
	pipes.sort_custom(func(a, b): return a.z_max > b.z_max)
	return pipes


func _decks_far_to_near() -> Array:
	if _level.spec == null:
		return []
	var decks: Array = _level.spec.decks.duplicate()
	decks.sort_custom(func(a, b): return _deck_z_max(a) > _deck_z_max(b))
	return decks


func _deck_z_max(deck: Dictionary) -> float:
	var z := -INF
	for v in deck.poly:
		z = maxf(z, v.y)
	return z


func _deck_z_min(deck: Dictionary) -> float:
	var z := INF
	for v in deck.poly:
		z = minf(z, v.y)
	return z


func _draw_backdrop_pad(band: Vector2) -> void:
	var pad := 640.0
	var near_l := _level.project(_level.x_min() - pad, band.x, 0.0)
	var near_r := _level.project(_level.x_max() + pad, band.x, 0.0)
	var far_l := _level.project(_level.x_min() - pad * 0.5, band.y, 0.0)
	var far_r := _level.project(_level.x_max() + pad * 0.5, band.y, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(near_l.screen_x, near_l.ground_y + 50.0),
			Vector2(near_r.screen_x, near_r.ground_y + 50.0),
			Vector2(far_r.screen_x, far_r.ground_y - 30.0),
			Vector2(far_l.screen_x, far_l.ground_y - 30.0),
		]),
		Color(0.12, 0.14, 0.16, 1.0)
	)


func _densify_poly_z(poly: PackedVector2Array) -> PackedVector2Array:
	## Insert midpoints on long Z edges so outlines follow clamped lean.
	var out := PackedVector2Array()
	var n := poly.size()
	if n < 2:
		return out
	var ref := maxf(_level.reference_depth, 1.0)
	var band := maxf(ref * 0.12, 16.0)
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		out.append(a)
		var dz := absf(b.y - a.y)
		var steps := clampi(int(ceil(dz / band)), 0, 24)
		for s in range(1, steps):
			var t := float(s) / float(steps)
			out.append(a.lerp(b, t))
	return out


func _project_poly(poly: PackedVector2Array, height: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in _densify_poly_z(poly):
		var p: Dictionary = _level.project(v.x, v.y, height)
		out.append(Vector2(p.screen_x, p.ground_y - p.surface_screen_h))
	return out


func _project_deck_poly(deck: Dictionary, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in _densify_poly_z(poly):
		var p: Dictionary = _level.project_deck_point(deck, v.x, v.y)
		out.append(Vector2(p.screen_x, p.ground_y - p.surface_screen_h))
	return out


func _draw_floors(band: Vector2) -> void:
	if _level.spec == null:
		return
	for floor in _level.spec.floors:
		var clipped := _clip_poly_z_band(floor.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_poly(clipped, 0.0)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.28, 0.34, 0.30, 0.95))


func _draw_decks(band: Vector2) -> void:
	if _level.spec == null:
		return
	for deck in _decks_far_to_near():
		var clipped := _clip_poly_z_band(deck.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_deck_poly(deck, clipped)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.55, 0.48, 0.32, 0.92))
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.95, 0.55, 0.35, 0.85), 2.5)


func _draw_depth_grid(band: Vector2) -> void:
	if _level.spec == null or _level.spec.floors.is_empty():
		return
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var z := lerpf(band.x, band.y, t)
		var left := _level.project(_level.x_min(), z, 0.0)
		var right := _level.project(_level.x_max(), z, 0.0)
		draw_line(
			Vector2(left.screen_x, left.ground_y),
			Vector2(right.screen_x, right.ground_y),
			Color(1, 1, 1, 0.10),
			1.2
		)


func _draw_player_cell_highlight() -> void:
	if not DebugTools.is_available() or not debug_cell_highlight:
		return
	if _level == null or _level.spec == null:
		return
	if _level.spec.grid_w <= 0 or _level.spec.grid_h <= 0:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node2D
	if _player == null or not _player.has_node("PseudoDepthBody"):
		return
	var body: PseudoDepthBody = _player.get_node("PseudoDepthBody")
	var lx: float = body.logical_x
	var lz: float = body.logical_z
	var cell: Vector2i = _level.spec.cell_at(lx, lz)
	var b: Dictionary = _level.spec.cell_bounds(cell.x, cell.y)
	var under: Dictionary = _level.sample(lx, lz)
	var h := 0.0
	if under.get("active", true) or str(under.get("zone", "")) != "oob":
		h = float(under.get("height", 0.0))
	var corners := PackedVector2Array([
		_surf_point(float(b.x0), float(b.z0), h),
		_surf_point(float(b.x1), float(b.z0), h),
		_surf_point(float(b.x1), float(b.z1), h),
		_surf_point(float(b.x0), float(b.z1), h),
	])
	if Geometry2D.triangulate_polygon(corners).is_empty():
		return
	draw_colored_polygon(corners, cell_highlight_fill)
	for i in range(corners.size()):
		draw_line(
			corners[i],
			corners[(i + 1) % corners.size()],
			cell_highlight_stroke,
			2.5,
			true
		)


func _surf_point(logical_x: float, logical_z: float, height: float) -> Vector2:
	var p: Dictionary = _level.project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)


## Ribbon clipped to the padded view band; sliced along Z past the lean knees.
func _draw_pipe(pipe: QuarterPipe, band: Vector2) -> void:
	var z0 := maxf(pipe.z_min, band.x)
	var z1 := minf(pipe.z_max, band.y)
	if z1 <= z0 + 0.001:
		return

	var arc_steps := 10
	var z_steps := _z_slice_count(z0, z1)
	var slices: Array = []
	for r in range(z_steps + 1):
		var zt := float(r) / float(z_steps)
		slices.append(_arc_points(pipe, lerpf(z0, z1, zt), arc_steps))

	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var fill_col := Color(0.42, 0.38, 0.48, 0.92) if is_left else Color(0.38, 0.44, 0.52, 0.92)

	for r in range(z_steps):
		var near_arc: PackedVector2Array = slices[r]
		var far_arc: PackedVector2Array = slices[r + 1]
		for i in range(arc_steps):
			var quad := PackedVector2Array([
				near_arc[i],
				near_arc[i + 1],
				far_arc[i + 1],
				far_arc[i],
			])
			if Geometry2D.triangulate_polygon(quad).is_empty():
				continue
			draw_colored_polygon(quad, fill_col)

	var ribs := maxi(arc_ribs, 1)
	for r in range(1, ribs):
		var u := float(r) / float(ribs)
		_draw_pipe_u_stroke(pipe, z0, z1, u, Color(1, 1, 1, 0.14), 1.25, z_steps)

	_draw_pipe_top_stroke(pipe, z0, z1, z_steps)
	_draw_pipe_u_stroke(pipe, z0, z1, 0.0, Color(0.95, 0.85, 0.35, 0.85), 2.5, z_steps)


func _draw_pipe_u_stroke(
	pipe: QuarterPipe, z0: float, z1: float, u: float, col: Color, width: float, z_steps: int
) -> void:
	var prev: Vector2
	for r in range(z_steps + 1):
		var zt := float(r) / float(z_steps)
		var pt: Vector2 = _level.pipe_screen_point_for(pipe, lerpf(z0, z1, zt), u)
		if r > 0:
			draw_line(prev, pt, col, width)
		prev = pt


func _draw_pipe_top_stroke(pipe: QuarterPipe, z0: float, z1: float, z_steps: int) -> void:
	var covered := _deck_z_ranges_covering_pipe(pipe)
	var segments := _z_segments_minus_covered(z0, z1, covered)
	var span := maxf(z1 - z0, 0.001)
	for seg in segments:
		var s0: float = float(seg.x)
		var s1: float = float(seg.y)
		var local_steps := maxi(1, int(round(float(z_steps) * (s1 - s0) / span)))
		_draw_pipe_u_stroke(pipe, s0, s1, 1.0, Color(0.95, 0.55, 0.35, 0.9), 3.0, local_steps)


func _deck_z_ranges_covering_pipe(pipe: QuarterPipe) -> Array:
	var out: Array = []
	if _level.spec == null:
		return out
	var coping := pipe.x_min() if pipe.side == QuarterPipe.PipeSide.LEFT else pipe.x_max()
	for deck in _level.spec.decks:
		var covers := false
		for a in deck.get("anchors", []):
			if absf(float(a.coping_x) - coping) < 0.05:
				covers = true
				break
		if not covers:
			for v in deck.poly:
				if absf(v.x - coping) < 0.05:
					covers = true
					break
		if not covers:
			continue
		var dz0 := _deck_z_min(deck)
		var dz1 := _deck_z_max(deck)
		var lo := maxf(dz0, pipe.z_min)
		var hi := minf(dz1, pipe.z_max)
		if lo < hi:
			out.append(Vector2(lo, hi))
	return out


func _z_segments_minus_covered(z_min: float, z_max: float, covered: Array) -> Array:
	if covered.is_empty():
		return [Vector2(z_min, z_max)]
	var sorted: Array = covered.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x)
	var segs: Array = []
	var cursor := z_min
	for c in sorted:
		var lo: float = maxf(c.x, z_min)
		var hi: float = minf(c.y, z_max)
		if lo > cursor + 0.001:
			segs.append(Vector2(cursor, lo))
		cursor = maxf(cursor, hi)
	if cursor < z_max - 0.001:
		segs.append(Vector2(cursor, z_max))
	return segs


func _arc_points(pipe: QuarterPipe, logical_z: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		pts.append(_level.pipe_screen_point_for(pipe, logical_z, u))
	return pts


## Sutherland–Hodgman clip of XZ polygon to z ∈ [z0, z1].
func _clip_poly_z_band(poly: PackedVector2Array, z0: float, z1: float) -> PackedVector2Array:
	var kept := _clip_poly_halfplane(poly, true, z0)  # keep z >= z0
	return _clip_poly_halfplane(kept, false, z1)  # keep z <= z1


func _clip_poly_halfplane(poly: PackedVector2Array, keep_above: bool, z_edge: float) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var out := PackedVector2Array()
	var n := poly.size()
	for i in range(n):
		var cur: Vector2 = poly[i]
		var prev: Vector2 = poly[(i + n - 1) % n]
		var cur_in := (cur.y >= z_edge) if keep_above else (cur.y <= z_edge)
		var prev_in := (prev.y >= z_edge) if keep_above else (prev.y <= z_edge)
		if cur_in:
			if not prev_in:
				out.append(_intersect_z(prev, cur, z_edge))
			out.append(cur)
		elif prev_in:
			out.append(_intersect_z(prev, cur, z_edge))
	return out


func _intersect_z(a: Vector2, b: Vector2, z_edge: float) -> Vector2:
	var dz := b.y - a.y
	if absf(dz) < 0.000001:
		return Vector2(a.x, z_edge)
	var t := (z_edge - a.y) / dz
	return Vector2(lerpf(a.x, b.x, t), z_edge)
