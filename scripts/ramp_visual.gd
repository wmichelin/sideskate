extends Node2D
## Surface-only level draw: floors, pipe ribbons, elevated deck tops.
## Far features paint first so nearer geometry occludes without volume skirts.

@export var grid_steps: int = 5
## How many iso-u depth strokes to split the pipe face into (not cross-section arcs).
@export var arc_ribs: int = 5
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
	_draw_backdrop_pad()
	_draw_floors()
	for pipe in _pipes_far_to_near():
		_draw_pipe(pipe)
	_draw_decks()
	if show_depth_grid:
		_draw_depth_grid()
	_draw_player_cell_highlight()


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


## Simple ribbon: near→far fill, depth strokes (constant u), lip + coping.
## No constant-Z arc ribs — those read as scallops under perspective.
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

	# Faint iso-u lines running near→far (same perspective as the yellow lip).
	var ribs := maxi(arc_ribs, 1)
	for r in range(1, ribs):
		var u := float(r) / float(ribs)
		var a: Vector2 = _level.pipe_screen_point_for(pipe, pipe.z_min, u)
		var b: Vector2 = _level.pipe_screen_point_for(pipe, pipe.z_max, u)
		draw_line(a, b, Color(1, 1, 1, 0.14), 1.25)

	_draw_pipe_top_stroke(pipe)
	var lip_near := _level.pipe_screen_point_for(pipe, pipe.z_min, 0.0)
	var lip_far := _level.pipe_screen_point_for(pipe, pipe.z_max, 0.0)
	draw_line(lip_near, lip_far, Color(0.95, 0.85, 0.35, 0.85), 2.5)


func _draw_pipe_top_stroke(pipe: QuarterPipe) -> void:
	var covered := _deck_z_ranges_covering_pipe(pipe)
	var segments := _z_segments_minus_covered(pipe.z_min, pipe.z_max, covered)
	for seg in segments:
		var a: Vector2 = _level.pipe_screen_point_for(pipe, float(seg.x), 1.0)
		var b: Vector2 = _level.pipe_screen_point_for(pipe, float(seg.y), 1.0)
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
