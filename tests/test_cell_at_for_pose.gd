extends RefCounted
## LevelSpec.cell_at_for_pose / PipeMath.pose_x_for_cell_query — targeting cell
## under feet while X-locked on pipe coping (half-open boundary fix).


func run() -> bool:
	var ok := true
	ok = _pose_x_nudge() and ok
	ok = _right_coping_cell() and ok
	ok = _left_coping_cell() and ok
	ok = _unlocked_no_nudge() and ok
	ok = _non_pipe_air_no_nudge() and ok
	ok = _facing_cast_cells() and ok
	return ok


func _spec(cw: float = 50.0, ch: float = 25.0, gw: int = 10, gh: int = 4) -> LevelSpec:
	var s := LevelSpec.new()
	s.cell_w = cw
	s.cell_h = ch
	s.grid_w = gw
	s.grid_h = gh
	return s


func _pose_x_nudge() -> bool:
	var right_coping := PipeMath.coping_x(1, 100.0, 100.0)  # 200
	var rq := PipeMath.pose_x_for_cell_query(right_coping, 1)
	if rq >= right_coping:
		push_error("RIGHT pose_x should nudge toward lip (left)")
		return false
	var left_coping := PipeMath.coping_x(0, 300.0, 100.0)  # 200
	var lq := PipeMath.pose_x_for_cell_query(left_coping, 0)
	if lq <= left_coping:
		push_error("LEFT pose_x should nudge toward lip (right)")
		return false
	return true


func _right_coping_cell() -> bool:
	# Right pipe occupies cols 2..3 → x [100,200]; coping = 200 = exclusive edge.
	var s := _spec(50.0)
	var last_pipe_col := 3
	var coping_x := float(last_pipe_col + 1) * s.cell_w  # 200
	var z := 40.0

	var raw := s.cell_at(coping_x, z)
	if raw.x != last_pipe_col + 1:
		push_error("raw right coping want col %d, got %d" % [last_pipe_col + 1, raw.x])
		return false

	var locked := s.cell_at_for_pose(coping_x, z, true, "right_pipe", 1)
	if locked.x != last_pipe_col:
		push_error("locked right coping want pipe col %d, got %d" % [last_pipe_col, locked.x])
		return false

	# Still inside pipe footprint for sampling after nudge.
	var qx := PipeMath.pose_x_for_cell_query(coping_x, 1)
	if qx < float(last_pipe_col) * s.cell_w or qx >= coping_x:
		push_error("nudged X must stay in last pipe cell [150,200)")
		return false
	return true


func _left_coping_cell() -> bool:
	# Left pipe occupies cols 2..3 → x [100,200]; coping = 100 = left edge of col 2.
	var s := _spec(50.0)
	var first_pipe_col := 2
	var coping_x := float(first_pipe_col) * s.cell_w  # 100
	var z := 40.0

	var raw := s.cell_at(coping_x, z)
	if raw.x != first_pipe_col:
		push_error("raw left coping want col %d, got %d" % [first_pipe_col, raw.x])
		return false

	var locked := s.cell_at_for_pose(coping_x, z, true, "left_pipe", 0)
	if locked.x != first_pipe_col:
		push_error("locked left coping must stay on pipe col %d, got %d" % [first_pipe_col, locked.x])
		return false
	return true


func _unlocked_no_nudge() -> bool:
	var s := _spec(50.0)
	var coping_x := 200.0  # would be right-pipe exclusive edge
	var z := 40.0
	var unlocked := s.cell_at_for_pose(coping_x, z, false, "right_pipe", 1)
	var raw := s.cell_at(coping_x, z)
	if unlocked != raw:
		push_error("unlocked pose must match raw cell_at")
		return false
	return true


func _non_pipe_air_no_nudge() -> bool:
	var s := _spec(50.0)
	var x := 200.0
	var z := 40.0
	# Locked but over flat/deck — do not apply pipe nudge.
	var over_flat := s.cell_at_for_pose(x, z, true, "flat", 1)
	var over_deck := s.cell_at_for_pose(x, z, true, "deck", 1)
	var raw := s.cell_at(x, z)
	if over_flat != raw or over_deck != raw:
		push_error("non-pipe air_over must not nudge cell query")
		return false
	return true


func _facing_cast_cells() -> bool:
	var s := _spec(50.0, 25.0, 10, 4)
	var right: Array[Vector2i] = FacingCastMath.cells_ahead(10, 4, 3, 1, "r", 3)
	if right.size() != 3 or right[0] != Vector2i(4, 1) or right[2] != Vector2i(6, 1):
		push_error("facing cast right want cols 4,5,6 row 1, got %s" % [right])
		return false
	var left: Array[Vector2i] = s.facing_cast_cells(2, 1, "l", 3)
	if left.size() != 2 or left[0] != Vector2i(1, 1) or left[1] != Vector2i(0, 1):
		push_error("facing cast left should stop at grid edge, got %s" % [left])
		return false
	var none: Array[Vector2i] = FacingCastMath.cells_ahead(10, 4, 5, 1, "r", 0)
	if not none.is_empty():
		push_error("distance 0 must be empty")
		return false
	return true
