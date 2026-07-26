extends Node2D
## Surface-only level draw: floors, pipe ribbons, elevated deck tops.
## Far features paint first so nearer geometry occludes without volume skirts.

@export var grid_steps: int = 5
@export var arc_ribs: int = 5

var _level: RampLevel


func _ready() -> void:
	z_index = -50
	_level = get_parent() as RampLevel
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _level == null:
		return
	_draw_backdrop_pad()
	_draw_floors()
	for pipe in _pipes_far_to_near():
		_draw_pipe(pipe)
	_draw_decks()
	_draw_depth_grid()


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


func _draw_backdrop_pad() -> void:
	var pad := 640.0
	var near_l := _level.project(_level.x_min() - pad, _level.z_min, 0.0)
	var near_r := _level.project(_level.x_max() + pad, _level.z_min, 0.0)
	var far_l := _level.project(_level.x_min() - pad * 0.5, _level.z_max, 0.0)
	var far_r := _level.project(_level.x_max() + pad * 0.5, _level.z_max, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(near_l.screen_x, near_l.ground_y + 50.0),
			Vector2(near_r.screen_x, near_r.ground_y + 50.0),
			Vector2(far_r.screen_x, far_r.ground_y - 30.0),
			Vector2(far_l.screen_x, far_l.ground_y - 30.0),
		]),
		Color(0.12, 0.14, 0.16, 1.0)
	)


func _project_poly(poly: PackedVector2Array, height: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in poly:
		var p: Dictionary = _level.project(v.x, v.y, height)
		out.append(Vector2(p.screen_x, p.ground_y - p.surface_screen_h))
	return out


func _project_deck_poly(deck: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in deck.poly:
		var p: Dictionary = _level.project_deck_point(deck, v.x, v.y)
		out.append(Vector2(p.screen_x, p.ground_y - p.surface_screen_h))
	return out


func _draw_floors() -> void:
	if _level.spec == null:
		return
	for floor in _level.spec.floors:
		var pts := _project_poly(floor.poly, 0.0)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.28, 0.34, 0.30, 0.95))


func _draw_decks() -> void:
	if _level.spec == null:
		return
	for deck in _decks_far_to_near():
		var pts := _project_deck_poly(deck)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.55, 0.48, 0.32, 0.92))
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.95, 0.55, 0.35, 0.85), 2.5)


func _draw_depth_grid() -> void:
	if _level.spec == null or _level.spec.floors.is_empty():
		return
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var z := lerpf(_level.z_min, _level.z_max, t)
		var left := _level.project(_level.x_min(), z, 0.0)
		var right := _level.project(_level.x_max(), z, 0.0)
		draw_line(
			Vector2(left.screen_x, left.ground_y),
			Vector2(right.screen_x, right.ground_y),
			Color(1, 1, 1, 0.10),
			1.2
		)


func _draw_pipe(pipe: QuarterPipe) -> void:
	var steps := 10
	var near_arc := _arc_points(pipe, pipe.z_min, steps)
	var far_arc := _arc_points(pipe, pipe.z_max, steps)
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var fill_col := Color(0.42, 0.38, 0.48, 0.92) if is_left else Color(0.38, 0.44, 0.52, 0.92)

	for i in range(steps):
		var quad := PackedVector2Array([
			near_arc[i],
			near_arc[i + 1],
			far_arc[i + 1],
			far_arc[i],
		])
		if Geometry2D.triangulate_polygon(quad).is_empty():
			continue
		draw_colored_polygon(quad, fill_col)

	for r in range(arc_ribs + 1):
		var t := float(r) / float(arc_ribs)
		var z := lerpf(pipe.z_min, pipe.z_max, t)
		var arc := _arc_points(pipe, z, steps)
		var col := Color(1, 1, 1, 0.22 if r == 0 or r == arc_ribs else 0.12)
		for i in range(arc.size() - 1):
			draw_line(arc[i], arc[i + 1], col, 2.0 if r == 0 else 1.25)

	_draw_pipe_top_stroke(pipe)
	var lip_near := _level.pipe_screen_point_for(pipe, pipe.z_min, 0.0)
	var lip_far := _level.pipe_screen_point_for(pipe, pipe.z_max, 0.0)
	draw_line(lip_near, lip_far, Color(0.95, 0.85, 0.35, 0.85), 2.5)


## Orange coping stroke, broken where a deck covers this pipe's top.
func _draw_pipe_top_stroke(pipe: QuarterPipe) -> void:
	var covered := _deck_z_ranges_covering_pipe(pipe)
	var segments := _z_segments_minus_covered(pipe.z_min, pipe.z_max, covered)
	for seg in segments:
		var a: Vector2 = _level.pipe_screen_point_for(pipe, seg.x, 1.0)
		var b: Vector2 = _level.pipe_screen_point_for(pipe, seg.y, 1.0)
		draw_line(a, b, Color(0.95, 0.55, 0.35, 0.9), 3.0)


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
			# Fallback: deck edge shares this pipe's coping X.
			for v in deck.poly:
				if absf(v.x - coping) < 0.05:
					covers = true
					break
		if not covers:
			continue
		var z0 := _deck_z_min(deck)
		var z1 := _deck_z_max(deck)
		var lo := maxf(z0, pipe.z_min)
		var hi := minf(z1, pipe.z_max)
		if lo < hi:
			out.append(Vector2(lo, hi))
	return out


## Return uncovered [z0,z1] segments as Vector2(z0, z1).
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
