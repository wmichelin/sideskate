extends RefCounted
## WorldSpace mapping + mesh builders produce valid geometry.


func run() -> bool:
	var w := WorldSpace.logical_to_world(10.0, 20.0, 5.0)
	if w != Vector3(10, 5, 20):
		push_error("logical_to_world mismatch %s" % w)
		return false
	var back: Dictionary = WorldSpace.world_to_logical(w)
	if not is_equal_approx(float(back.x), 10.0) or not is_equal_approx(float(back.z), 20.0):
		push_error("world_to_logical mismatch")
		return false

	var text := FileAccess.get_file_as_string("res://tests/levels/test_halfpipe.ssk")
	var spec := LevelLoader.parse_text(text, "test_halfpipe")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		return false

	var floors: Array = FloorMeshBuilder.build(spec)
	if floors.is_empty():
		push_error("no floor meshes")
		return false
	for part in floors:
		var mesh: ArrayMesh = part.mesh
		if mesh == null or mesh.get_surface_count() < 1:
			push_error("empty floor mesh")
			return false

	var pipes: Array = PipeMeshBuilder.build_from_pipes(spec.pipes)
	if pipes.is_empty():
		push_error("no pipe meshes")
		return false
	# Sample first pipe ride surface against QuarterPipe.query_surface height.
	var pd: Dictionary = spec.pipes[0]
	var qp := QuarterPipe.new()
	qp.side = int(pd.side)
	qp.lip_x = float(pd.lip_x)
	qp.radius = float(pd.radius)
	qp.base_height = float(pd.get("base_height", 0.0))
	qp.z_min = float(pd.z_min)
	qp.z_max = float(pd.z_max)
	var mid_x := qp.lip_x + (1.0 if qp.side == QuarterPipe.PipeSide.RIGHT else -1.0) * qp.radius * 0.5
	var hit: Dictionary = qp.query_surface(mid_x, (qp.z_min + qp.z_max) * 0.5)
	if not hit.get("active", false):
		push_error("pipe sample inactive")
		return false
	var theta := asin(0.5)
	var profile := PipeMeshBuilder._profile_point(qp, theta, qp.side == QuarterPipe.PipeSide.LEFT)
	if absf(profile.y - float(hit.height)) > 0.5:
		push_error("pipe mesh profile vs query_surface height mismatch %s vs %s" % [profile.y, hit.height])
		return false

	var decks: Array = DeckMeshBuilder.build(spec)
	# halfpipe may or may not have decks; don't require
	for part in decks:
		var dm: ArrayMesh = part.mesh
		if dm == null or dm.get_surface_count() < 1:
			push_error("empty deck mesh")
			return false

	return true
