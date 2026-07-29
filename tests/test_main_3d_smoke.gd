extends RefCounted
## Gameplay scene loads, 3D meshes rebuild, camera exists.


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("no tree")
		return false
	GameSession.pending_level_path = "res://tests/levels/test_halfpipe.ssk"
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main.tscn missing")
		return false
	var main: Node = packed.instantiate()
	tree.root.add_child(main)

	var level := main.get_node_or_null("RampLevel") as RampLevel
	var vis := main.get_node_or_null("World3D/LevelVisual3D")
	var cam := main.get_node_or_null("World3D/CameraRig3D")
	var col := main.get_node_or_null("World3D/LevelCollision3D")
	var pvis := main.get_node_or_null("World3D/PlayerVisual")
	if level == null or vis == null or cam == null or pvis == null or col == null:
		push_error("missing 3D nodes")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	# Force rebuild after level apply.
	if level.spec == null:
		var text := FileAccess.get_file_as_string("res://tests/levels/test_halfpipe.ssk")
		var spec := LevelLoader.parse_text(text, "test_halfpipe")
		if spec == null:
			push_error(LevelLoader.last_error)
			main.queue_free()
			return false
		level.apply_spec(spec)
	vis.call("rebuild")
	col.call("rebuild")
	if int(vis.get("mesh_count")) <= 0:
		push_error("mesh_count == 0 after rebuild")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if int(col.get("part_count")) <= 0:
		push_error("collision part_count == 0 after rebuild")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	var player = main.get_node_or_null("Player")
	if player == null or not (player is CharacterBody3D):
		push_error("Player missing or not CharacterBody3D")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	var pose_sim := PlayerSim.new()
	if not pose_sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("player pose: layered setup failed")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	var deck_wall: WallSurface = null
	for wall_id in pose_sim.model.all_wall_ids():
		var candidate: WallSurface = pose_sim.model.walls[wall_id]
		if not candidate.outward_deck_id.is_empty():
			deck_wall = candidate
			break
	if deck_wall == null:
		push_error("player pose: missing deck-backed wall")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	var z := (deck_wall.z_min + deck_wall.z_max) * 0.5
	var source: PipeSurface = pose_sim.model.pipes[deck_wall.source_pipe_id]
	var expected_tilt := -source.outward_sign() * PI * 0.5
	var st := pose_sim.state
	st.mode = SimState.Mode.GROUNDED
	st.surface_id = deck_wall.id
	st.u = 0.9
	st.position = deck_wall.position_at(z, st.u)
	st.tangent_velocity = Vector2(500.0, 0.0)
	player.set("_sim", pose_sim)
	player.call("_sync_from_sim")
	var player_depth: PseudoDepthBody = player.get("depth")
	if player_depth == null or absf(player_depth.surface_tilt - expected_tilt) > 0.01:
		push_error("player pose: wall lean missing before deck-back release")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	st.mode = SimState.Mode.AIRBORNE
	st.surface_id = ""
	st.position.z += 10.0
	st.velocity = Vector3(0.0, 0.0, 500.0)
	st.clear_hang()
	player.call("_sync_from_sim")
	if absf(player_depth.surface_tilt - expected_tilt) > 0.01:
		push_error("player pose: X-aligned deck-back air leveled early")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	st.velocity.x = 100.0
	player.call("_sync_from_sim")
	if absf(player_depth.surface_tilt) > 0.01:
		push_error("player pose: did not level after horizontal release")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	main.queue_free()
	GameSession.pending_level_path = ""
	return true
