extends Node2D
## Draws the wide plaza floor + left/right quarter-pipe placeholders.
## All perspective math comes from parent RampLevel.project / pipe_screen_point.

@export var grid_steps: int = 5
@export var arc_ribs: int = 5

var _level: RampLevel


func _ready() -> void:
	z_index = -50
	_level = get_parent() as RampLevel
	queue_redraw()


func _draw() -> void:
	if _level == null:
		return
	_draw_backdrop_pad()
	_draw_plaza()
	_draw_pipe(true)
	_draw_pipe(false)
	_draw_lips()
	_draw_depth_grid()


func _draw_backdrop_pad() -> void:
	var near_l := _level.project(_level.x_min() - 40.0, _level.z_min, 0.0)
	var near_r := _level.project(_level.x_max() + 40.0, _level.z_min, 0.0)
	var far_l := _level.project(_level.x_min() - 20.0, _level.z_max, 0.0)
	var far_r := _level.project(_level.x_max() + 20.0, _level.z_max, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(near_l.screen_x, near_l.ground_y + 50.0),
			Vector2(near_r.screen_x, near_r.ground_y + 50.0),
			Vector2(far_r.screen_x, far_r.ground_y - 30.0),
			Vector2(far_l.screen_x, far_l.ground_y - 30.0),
		]),
		Color(0.12, 0.14, 0.16, 1.0)
	)


func _draw_plaza() -> void:
	var n_l := _level.project(_level.lip_left, _level.z_min, 0.0)
	var n_r := _level.project(_level.lip_right, _level.z_min, 0.0)
	var f_l := _level.project(_level.lip_left, _level.z_max, 0.0)
	var f_r := _level.project(_level.lip_right, _level.z_max, 0.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(n_l.screen_x, n_l.ground_y),
			Vector2(n_r.screen_x, n_r.ground_y),
			Vector2(f_r.screen_x, f_r.ground_y),
			Vector2(f_l.screen_x, f_l.ground_y),
		]),
		Color(0.28, 0.34, 0.30, 0.95)
	)


func _draw_lips() -> void:
	var n_l := _level.pipe_screen_point(true, _level.z_min, 0.0)
	var f_l := _level.pipe_screen_point(true, _level.z_max, 0.0)
	var n_r := _level.pipe_screen_point(false, _level.z_min, 0.0)
	var f_r := _level.pipe_screen_point(false, _level.z_max, 0.0)
	draw_line(n_l, f_l, Color(0.95, 0.85, 0.35, 0.95), 3.0)
	draw_line(n_r, f_r, Color(0.95, 0.85, 0.35, 0.95), 3.0)

	var near_l := _level.project(_level.lip_left, _level.z_min, 0.0)
	var near_r := _level.project(_level.lip_right, _level.z_min, 0.0)
	var far_l := _level.project(_level.lip_left, _level.z_max, 0.0)
	var far_r := _level.project(_level.lip_right, _level.z_max, 0.0)
	draw_line(
		Vector2(near_l.screen_x, near_l.ground_y),
		Vector2(near_r.screen_x, near_r.ground_y),
		Color(0.85, 0.9, 0.75, 0.55),
		2.0
	)
	draw_line(
		Vector2(far_l.screen_x, far_l.ground_y),
		Vector2(far_r.screen_x, far_r.ground_y),
		Color(0.45, 0.75, 1.0, 0.75),
		2.5
	)


func _draw_depth_grid() -> void:
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var z := lerpf(_level.z_min, _level.z_max, t)
		var left := _level.project(_level.lip_left, z, 0.0)
		var right := _level.project(_level.lip_right, z, 0.0)
		draw_line(
			Vector2(left.screen_x, left.ground_y),
			Vector2(right.screen_x, right.ground_y),
			Color(1, 1, 1, 0.14),
			1.5
		)


func _draw_pipe(is_left: bool) -> void:
	var steps := 10
	var near_arc := _arc_points(is_left, _level.z_min, steps)
	var far_arc := _arc_points(is_left, _level.z_max, steps)

	var fill := PackedVector2Array()
	for p in near_arc:
		fill.append(p)
	for i in range(far_arc.size() - 1, -1, -1):
		fill.append(far_arc[i])
	var fill_col := Color(0.42, 0.38, 0.48, 0.92) if is_left else Color(0.38, 0.44, 0.52, 0.92)
	draw_colored_polygon(fill, fill_col)

	for r in range(arc_ribs + 1):
		var t := float(r) / float(arc_ribs)
		var z := lerpf(_level.z_min, _level.z_max, t)
		var arc := _arc_points(is_left, z, steps)
		var col := Color(1, 1, 1, 0.22 if r == 0 or r == arc_ribs else 0.12)
		for i in range(arc.size() - 1):
			draw_line(arc[i], arc[i + 1], col, 2.0 if r == 0 else 1.25)

	var top_near := _level.pipe_screen_point(is_left, _level.z_min, 1.0)
	var top_far := _level.pipe_screen_point(is_left, _level.z_max, 1.0)
	draw_line(top_near, top_far, Color(0.95, 0.55, 0.35, 0.9), 3.0)


func _arc_points(is_left: bool, logical_z: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		pts.append(_level.pipe_screen_point(is_left, logical_z, u))
	return pts
