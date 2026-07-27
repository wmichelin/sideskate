extends RefCounted
## Spine high→low against real RampLevel pipe nodes + LevelSpec (game path).


func run() -> bool:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		return false

	var level := RampLevel.new()
	level.spec = spec
	level.cell_size_x = spec.cell_w
	level.cell_size_z = spec.cell_h
	level.pipes.clear()
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.layer = int(pd.get("layer", 0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		level.pipes.append(qp)

	var l1_left: QuarterPipe = null
	for p in level.pipes:
		if int(p.side) == 0 and int(p.layer) == 1:
			l1_left = p
			break
	if l1_left == null:
		push_error("no L1 left node")
		_free_pipes(level)
		return false

	var from_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
	var z: float = (l1_left.z_min + l1_left.z_max) * 0.5
	var prefer: float = l1_left.base_height + l1_left.radius
	var behind := PipeMath.coping_sign(0)

	var hit: Dictionary = AerialMath.find_spine_transfer_target(
		level.pipes, from_x, z, behind, 0, l1_left.lip_x, spec.cell_w, 0.05, prefer, spec
	)
	if hit.is_empty() or int(hit.get("layer", -1)) != 0 or int(hit.get("side", -1)) != 1:
		push_error("node path high→low failed: %s (from_x=%s behind=%s prefer=%s)" % [
			hit, from_x, behind, prefer
		])
		_free_pipes(level)
		return false

	# Over hole west of coping (player drifted / unlocked air).
	var hole_x: float = from_x - spec.cell_w * 0.75
	var hit2: Dictionary = AerialMath.find_spine_transfer_target(
		level.pipes, hole_x, z, behind, 0, l1_left.lip_x, spec.cell_w, 0.05, prefer, spec
	)
	if hit2.is_empty() or int(hit2.get("layer", -1)) != 0:
		push_error("node path over hole failed: %s hole_x=%s cell=%s" % [
			hit2, hole_x, spec.cell_at(hole_x, z)
		])
		_free_pipes(level)
		return false

	_free_pipes(level)
	# Production map must keep L1 left / L0 right on a shared coping (no # gap).
	if not _production_shared_coping():
		return false
	return true


## levels/layered_demo mid-band used to be `#<<<========>>>#`, shifting L1 pipes
## one cell so high→low spine lerped through a solid deck pad.
func _production_shared_coping() -> bool:
	var text := FileAccess.get_file_as_string("res://levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo_prod")
	if spec == null:
		push_error("prod layered_demo parse: %s" % LevelLoader.last_error)
		return false
	var l1_left: Dictionary = {}
	var l0_right: Dictionary = {}
	for pd in spec.pipes:
		if int(pd.side) == 0 and int(pd.get("layer", 0)) == 1 and l1_left.is_empty():
			l1_left = pd
		if int(pd.side) == 1 and int(pd.get("layer", 0)) == 0 and l0_right.is_empty():
			l0_right = pd
	if l1_left.is_empty() or l0_right.is_empty():
		push_error("prod layered_demo missing L1 left / L0 right")
		return false
	var c1 := PipeMath.coping_x(0, float(l1_left.lip_x), float(l1_left.radius))
	var c0 := PipeMath.coping_x(1, float(l0_right.lip_x), float(l0_right.radius))
	if absf(c1 - c0) > 1.0:
		push_error("prod L1 left / L0 right coping gap: L1=%s L0=%s (remove mid-band # flanks)" % [c1, c0])
		return false
	return true


func _free_pipes(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
