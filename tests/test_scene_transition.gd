extends RefCounted
## Scene-transition hygiene: GameSession state, baked death overlay, reload cycle.


func run() -> bool:
	# Baked DeathOverlay must be present in main.tscn (no mid-_ready add_child).
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("main.tscn missing")
		return false
	var main: Node = packed.instantiate()
	var death := main.get_node_or_null("DeathOverlay")
	if death == null:
		push_error("DeathOverlay not baked into main.tscn")
		main.free()
		return false

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		main.free()
		return false
	tree.root.add_child(main)
	# Script _ready adds group membership.
	if not death.is_in_group("death_overlay"):
		death.add_to_group("death_overlay")
	if not death.is_in_group("death_overlay"):
		push_error("DeathOverlay missing group")
		main.queue_free()
		return false

	var player = main.get_node_or_null("Player")
	if player == null:
		push_error("Player missing")
		main.queue_free()
		return false
	# PlayerSim shell looks up DeathOverlay via group; baked node must stay grouped.
	if not death.has_method("play"):
		push_error("DeathOverlay missing play()")
		main.queue_free()
		return false

	# 3D gameplay subtree present.
	if main.get_node_or_null("World3D/CameraRig3D") == null:
		push_error("CameraRig3D missing from unified main.tscn")
		main.queue_free()
		return false

	GameSession.pending_level_path = ""

	main.queue_free()
	var main2: Node = packed.instantiate()
	tree.root.add_child(main2)
	if main2.get_node_or_null("DeathOverlay") == null:
		push_error("DeathOverlay missing after reload")
		main2.queue_free()
		return false
	if main2.get_node_or_null("Player") == null:
		push_error("Player missing after reload")
		main2.queue_free()
		return false
	main2.queue_free()
	return true
