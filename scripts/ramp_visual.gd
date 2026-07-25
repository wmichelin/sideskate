extends Node2D
## Draws the wide plaza floor + left/right quarter-pipe placeholders in pseudo-3D perspective.

@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0
@export var lip_left: float = 180.0
@export var lip_right: float = 1100.0
@export var pipe_radius: float = 150.0
@export var z_min: float = 0.0
@export var z_max: float = 100.0
@export var grid_steps: int = 5
@export var arc_ribs: int = 5
@export var perspective_inset: float = 80.0


func _ready() -> void:
	z_index = -50
	var level := get_parent() as RampLevel
	if level:
		lip_left = level.lip_left
		lip_right = level.lip_right
		pipe_radius = level.pipe_radius
		z_min = level.z_min
		z_max = level.z_max
	queue_redraw()


func _draw() -> void:
	_draw_backdrop_pad()
	_draw_plaza()
	_draw_pipe(true)
	_draw_pipe(false)
	_draw_lips()
	_draw_depth_grid()


func _depth_y(t: float) -> float:
	return lerpf(near_screen_y, far_screen_y, t)


func _inset(t: float) -> float:
	return lerpf(0.0, perspective_inset, t)


func _draw_backdrop_pad() -> void:
	# Soft pad under the whole playfield.
	var pad := PackedVector2Array([
		Vector2(lip_left - pipe_radius - 40.0, near_screen_y + 50.0),
		Vector2(lip_right + pipe_radius + 40.0, near_screen_y + 50.0),
		Vector2(lip_right + pipe_radius - perspective_inset + 20.0, far_screen_y - 30.0),
		Vector2(lip_left - pipe_radius + perspective_inset - 20.0, far_screen_y - 30.0),
	])
	draw_colored_polygon(pad, Color(0.12, 0.14, 0.16, 1.0))


func _draw_plaza() -> void:
	var poly := PackedVector2Array([
		Vector2(lip_left, near_screen_y),
		Vector2(lip_right, near_screen_y),
		Vector2(lip_right - perspective_inset, far_screen_y),
		Vector2(lip_left + perspective_inset, far_screen_y),
	])
	draw_colored_polygon(poly, Color(0.28, 0.34, 0.30, 0.95))


func _draw_lips() -> void:
	draw_line(
		Vector2(lip_left, near_screen_y),
		Vector2(lip_left + perspective_inset, far_screen_y),
		Color(0.95, 0.85, 0.35, 0.95),
		3.0
	)
	draw_line(
		Vector2(lip_right, near_screen_y),
		Vector2(lip_right - perspective_inset, far_screen_y),
		Color(0.95, 0.85, 0.35, 0.95),
		3.0
	)
	# Near / far plaza edges.
	draw_line(
		Vector2(lip_left, near_screen_y),
		Vector2(lip_right, near_screen_y),
		Color(0.85, 0.9, 0.75, 0.55),
		2.0
	)
	draw_line(
		Vector2(lip_left + perspective_inset, far_screen_y),
		Vector2(lip_right - perspective_inset, far_screen_y),
		Color(0.45, 0.75, 1.0, 0.75),
		2.5
	)


func _draw_depth_grid() -> void:
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var y := _depth_y(t)
		var inset := _inset(t)
		draw_line(
			Vector2(lip_left + inset, y),
			Vector2(lip_right - inset, y),
			Color(1, 1, 1, 0.14),
			1.5
		)


func _draw_pipe(is_left: bool) -> void:
	# Build a perspective-scaled quarter-pipe wedge from near to far.
	var steps := 10
	var near_arc := _arc_points(is_left, 0.0, steps)
	var far_arc := _arc_points(is_left, 1.0, steps)

	# Filled body: near arc → far arc reversed.
	var fill := PackedVector2Array()
	for p in near_arc:
		fill.append(p)
	for i in range(far_arc.size() - 1, -1, -1):
		fill.append(far_arc[i])
	var fill_col := Color(0.42, 0.38, 0.48, 0.92) if is_left else Color(0.38, 0.44, 0.52, 0.92)
	draw_colored_polygon(fill, fill_col)

	# Arc ribs at a few depths.
	for r in range(arc_ribs + 1):
		var t := float(r) / float(arc_ribs)
		var arc := _arc_points(is_left, t, steps)
		var col := Color(1, 1, 1, 0.22 if r == 0 or r == arc_ribs else 0.12)
		for i in range(arc.size() - 1):
			draw_line(arc[i], arc[i + 1], col, 2.0 if r == 0 else 1.25)

	# Coping / top edge (vertical lip at pipe top).
	var top_near := _pipe_point(is_left, 0.0, 1.0)
	var top_far := _pipe_point(is_left, 1.0, 1.0)
	draw_line(top_near, top_far, Color(0.95, 0.55, 0.35, 0.9), 3.0)


## t_depth 0=near 1=far; u 0=lip 1=top of pipe.
func _pipe_point(is_left: bool, t_depth: float, u: float) -> Vector2:
	var theta := u * PI * 0.5
	var x_off := pipe_radius * sin(theta)
	var height := pipe_radius * (1.0 - cos(theta))
	var inset := _inset(t_depth)
	var lip := lip_left if is_left else lip_right
	# Perspective: lips converge toward center as depth increases.
	var lip_screen := lip + inset if is_left else lip - inset
	var x: float
	if is_left:
		x = lip_screen - x_off * lerpf(1.0, 0.72, t_depth)
	else:
		x = lip_screen + x_off * lerpf(1.0, 0.72, t_depth)
	var y := _depth_y(t_depth) - height * lerpf(1.0, 0.72, t_depth)
	return Vector2(x, y)


func _arc_points(is_left: bool, t_depth: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		pts.append(_pipe_point(is_left, t_depth, u))
	return pts
