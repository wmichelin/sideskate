extends Node2D
## Draws floor / deck polys and all quarter pipes from parent RampLevel.spec.

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
	for pipe in _level.pipes:
		_draw_pipe(pipe)
	_draw_decks()
	_draw_depth_grid()


func _draw_backdrop_pad() -> void:
	# Extra horizontal pad so the plaza fill survives camera pan near the edges.
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
	for deck in _level.spec.decks:
		var h := float(deck.height)
		var pts := _project_poly(deck.poly, h)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.55, 0.48, 0.32, 0.92))
			# Coping edge hint
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.95, 0.55, 0.35, 0.75), 2.0)


func _draw_depth_grid() -> void:
	if _level.spec == null or _level.spec.floors.is_empty():
		return
	# Grid across overall playable X at a few Z values on ground
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

	# Ribbon quads avoid self-intersecting single polygons under perspective.
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

	var top_near := _level.pipe_screen_point_for(pipe, pipe.z_min, 1.0)
	var top_far := _level.pipe_screen_point_for(pipe, pipe.z_max, 1.0)
	draw_line(top_near, top_far, Color(0.95, 0.55, 0.35, 0.9), 3.0)

	var lip_near := _level.pipe_screen_point_for(pipe, pipe.z_min, 0.0)
	var lip_far := _level.pipe_screen_point_for(pipe, pipe.z_max, 0.0)
	draw_line(lip_near, lip_far, Color(0.95, 0.85, 0.35, 0.85), 2.5)


func _arc_points(pipe: QuarterPipe, logical_z: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		pts.append(_level.pipe_screen_point_for(pipe, logical_z, u))
	return pts
