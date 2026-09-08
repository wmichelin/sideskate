extends RefCounted
## Connected upper-floor outlines and holes control Z-local coping ownership.

const T_ROWS := ["...........=", "...........=", "........====", "...........=", "...........="]
const U_ROWS := ["........====", "...........=", "...........=", "...........=", "........===="]
const HOLE_ROWS := [".......=====", ".......=...=", ".......=...=", ".......=...=", ".......====="]


func cases() -> Array:
	return ["t_outline", "u_outline", "interior_hole", "matching_height_seams", "unrelated_outline_keeps_open_span"]


func run() -> bool:
	return t_outline() and u_outline() and interior_hole() \
		and matching_height_seams() and unrelated_outline_keeps_open_span()


func t_outline() -> bool:
	return _both_sides(T_ROWS, [false, false, true, false, false], 200.0)


func u_outline() -> bool:
	return _both_sides(U_ROWS, [true, false, false, false, true], 200.0)


func interior_hole() -> bool:
	return _both_sides(HOLE_ROWS, [true, false, false, false, true], 200.0)


func matching_height_seams() -> bool:
	return _both_sides(T_ROWS, [false, false, true, false, false], 120.0) \
		and _both_sides(HOLE_ROWS, [true, false, false, false, true], 120.0)


func unrelated_outline_keeps_open_span() -> bool:
	return _both_sides(
		["...........=", "...........=", "..........==", "...........=", "...........="],
		[false, false, false, false, false], 200.0
	)


func _both_sides(rows: Array, occupied: Array, height: float) -> bool:
	for mirror in [false, true]:
		if not _check_layout(rows, occupied, height, mirror):
			return false
	return true


func _map_text(rows: Array, height: float, mirror: bool) -> String:
	var text := "ssk 2\nname coping_footprint\n---\nlayer 0\nheight 0\n"
	for i in range(5):
		var row := "=@===)))====" if i == 2 else "=====)))===="
		text += (row.reverse().replace(")", "(") if mirror else row) + "\n"
	text += "---\nlayer 1\nheight %s\n" % height
	for row in rows:
		text += (str(row).reverse() if mirror else str(row)) + "\n"
	return text


func _check_layout(rows: Array, occupied: Array, height: float, mirror: bool) -> bool:
	var text := _map_text(rows, height, mirror)
	var model := IdlCompiler.compile_text(text)
	if not model.is_valid() or model.pipes.size() != 1:
		return _fail("fixture compilation: %s" % model.compile_errors)
	if model.model_hash != IdlCompiler.compile_text(text).model_hash:
		return _fail("repeat compilation changed model identity")
	var pipe: PipeSurface = model.pipes[model.all_pipe_ids()[0]]
	var cope: CopingEdge = model.copings[pipe.coping_id]
	var query := SurfaceQuery.new(model)
	var expected_spans := 1
	for row in range(5):
		if row > 0 and occupied[row] != occupied[row - 1]:
			expected_spans += 1
		var z := (4.5 - float(row)) * model.cell_h
		var expected := SimKinds.CopingClass.OPEN
		if occupied[row]:
			expected = SimKinds.CopingClass.WALL_EXTENSION if height > 120.0 else SimKinds.CopingClass.SUPPORT_SEAM
		var span := cope.span_at_z(z)
		if span.coping_class != expected:
			return _fail("row %d mirror=%s height=%s: expected %s got %s" % [
				row, mirror, height, expected, span.coping_class,
			])
		var face := pipe.coping_x_at(z)
		if height > 120.0:
			var hit := query.sweep_capsule(Vector3(face - 3, z, 160), Vector3(face + 3, z, 160))
			if occupied[row] != (str(hit.get("kind", "")) == "wall"):
				return _fail("wall sweep disagrees with authored footprint at row %d: %s" % [row, hit])
		elif occupied[row]:
			var edge := query.edge_at(pipe.id, z, "coping")
			if edge == null or not model.patches.has(edge.to_surface_id):
				return _fail("matching-height floor did not receive support seam")
	if cope.spans.size() != expected_spans:
		return _fail("equivalent classifications created unnecessary coping seams: %s != %s" % [cope.spans.size(), expected_spans])
	return true


func _fail(message: String) -> bool:
	push_error("coping footprint: " + message)
	return false
