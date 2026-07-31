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
	col.set("build_bodies", true)
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

	main.queue_free()
	GameSession.pending_level_path = ""
	return true
