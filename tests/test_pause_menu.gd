extends RefCounted
## Pause menu is baked into main.tscn and pauses the tree without leaving the level.


func run() -> bool:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main.tscn missing")
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	GameSession.pending_level_path = "res://levels/layers.ssk"
	var main: Node = packed.instantiate()
	tree.root.add_child(main)
	var pause: Node = main.get_node_or_null("PauseMenu")
	if pause == null:
		push_error("PauseMenu missing from main.tscn")
		main.queue_free()
		return false
	if not pause.has_method("open_pause") or not pause.has_method("close_pause"):
		push_error("PauseMenu missing open/close API")
		main.queue_free()
		return false
	if tree.paused:
		push_error("tree unexpectedly paused before open")
		main.queue_free()
		return false
	pause.open_pause()
	if not tree.paused:
		push_error("tree should be paused while pause menu open")
		pause.close_pause()
		main.queue_free()
		return false
	if not bool(pause.call("is_open")):
		push_error("pause menu should report open")
		pause.close_pause()
		main.queue_free()
		return false
	pause.close_pause()
	if tree.paused:
		push_error("tree should resume after close_pause")
		main.queue_free()
		return false
	main.queue_free()
	GameSession.pending_level_path = ""
	return true
