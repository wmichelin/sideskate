extends Node2D
## Draws the lane band + depth grid so near/far bounds are obvious while playtesting.


@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0
@export var left_x: float = 60.0
@export var right_x: float = 1220.0
@export var z_min: float = 0.0
@export var z_max: float = 100.0
@export var grid_steps: int = 5


func _draw() -> void:
	# Ground fill: trapezoid (wider near, narrower far) for a cheap perspective cue.
	var near_left := Vector2(left_x - 40.0, near_screen_y + 40.0)
	var near_right := Vector2(right_x + 40.0, near_screen_y + 40.0)
	var far_left := Vector2(left_x + 120.0, far_screen_y - 20.0)
	var far_right := Vector2(right_x - 120.0, far_screen_y - 20.0)
	draw_colored_polygon(
		PackedVector2Array([near_left, near_right, far_right, far_left]),
		Color(0.18, 0.22, 0.20, 1.0)
	)

	# Lane band tint between near and far horizontals.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(left_x, near_screen_y),
			Vector2(right_x, near_screen_y),
			Vector2(right_x - 80.0, far_screen_y),
			Vector2(left_x + 80.0, far_screen_y),
		]),
		Color(0.25, 0.32, 0.28, 0.85)
	)

	# Near / far boundary lines.
	draw_line(Vector2(left_x, near_screen_y), Vector2(right_x, near_screen_y), Color(0.95, 0.85, 0.35, 0.95), 3.0)
	draw_line(Vector2(left_x + 80.0, far_screen_y), Vector2(right_x - 80.0, far_screen_y), Color(0.45, 0.75, 1.0, 0.95), 3.0)

	# Depth grid (constant-Z isolines).
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var y := lerpf(near_screen_y, far_screen_y, t)
		var inset := lerpf(0.0, 80.0, t)
		var col := Color(1, 1, 1, 0.18)
		draw_line(Vector2(left_x + inset, y), Vector2(right_x - inset, y), col, 1.5)

	# Perspective rays (left/right edges of the lane).
	draw_line(Vector2(left_x, near_screen_y), Vector2(left_x + 80.0, far_screen_y), Color(1, 1, 1, 0.22), 1.5)
	draw_line(Vector2(right_x, near_screen_y), Vector2(right_x - 80.0, far_screen_y), Color(1, 1, 1, 0.22), 1.5)
