extends RefCounted
## Cutover gate: main scene Player boots PlayerSim; model hash stamped.


func run() -> bool:
	return (
		_player_sim_boots()
		and _playable_idls_compile()
		and _hash_stamped_on_presentation()
	)


func _player_sim_boots() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("no tree")
		return false
	GameSession.pending_level_path = "res://tests/levels/sim/sim_halfpipe.ssk"
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main.tscn missing")
		return false
	var main: Node = packed.instantiate()
	tree.root.add_child(main)
	var player = main.get_node_or_null("Player")
	var level := main.get_node_or_null("RampLevel") as RampLevel
	if player == null or level == null:
		push_error("Player/RampLevel missing")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if level.spec == null:
		var text := FileAccess.get_file_as_string("res://tests/levels/sim/sim_halfpipe.ssk")
		var spec := LevelLoader.parse_text(text, "sim_halfpipe")
		if spec == null:
			push_error(LevelLoader.last_error)
			main.queue_free()
			return false
		level.apply_spec(spec)
	player._boot_sim()
	var sim: PlayerSim = player.get_sim()
	if sim == null or sim.state == null:
		push_error("PlayerSim not booted")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if str(player.sim_model_hash()).is_empty():
		push_error("empty model hash")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	sim.set_input(Vector2.ZERO, false, false)
	for _i in range(8):
		sim.tick()
	if not sim.state.alive:
		push_error("died at spawn")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	main.queue_free()
	GameSession.pending_level_path = ""
	return true


func _playable_idls_compile() -> bool:
	var any := false
	for dir_path in ["res://levels", "res://debug_levels"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name.ends_with(".ssk") and not name.begins_with("_"):
				any = true
				var path := "%s/%s" % [dir_path, name]
				var model := IdlCompiler.compile_path(path)
				if model == null or not model.is_valid():
					push_error("IDL compile failed: %s" % path)
					return false
				if model.model_hash.is_empty():
					push_error("empty hash for %s" % path)
					return false
			name = dir.get_next()
		dir.list_dir_end()
	if not any:
		push_error("no .ssk in levels/ or debug_levels/")
		return false
	return true


func _hash_stamped_on_presentation() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	GameSession.pending_level_path = "res://tests/levels/sim/sim_halfpipe.ssk"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	var player = main.get_node("Player")
	var level := main.get_node("RampLevel") as RampLevel
	if level.spec == null:
		var text := FileAccess.get_file_as_string("res://tests/levels/sim/sim_halfpipe.ssk")
		level.apply_spec(LevelLoader.parse_text(text, "sim_halfpipe"))
	player._boot_sim()
	var hash_s := str(player.sim_model_hash())
	var col := main.get_node_or_null("World3D/LevelCollision3D")
	var vis := main.get_node_or_null("World3D/LevelVisual3D")
	if col == null or vis == null:
		push_error("missing presentation nodes")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if str(col.get_meta("sim_model_hash", "")) != hash_s:
		push_error("collision hash mismatch")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if str(vis.get_meta("sim_model_hash", "")) != hash_s:
		push_error("visual hash mismatch")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	main.queue_free()
	GameSession.pending_level_path = ""
	return true
