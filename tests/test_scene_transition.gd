extends RefCounted
## Scene-transition hygiene: GameSession state, baked death overlay, reload cycle.


func run() -> bool:
	# Backend routing helpers.
	if GameSession.backend_for_path("res://levels/plaza_default.ssk") != GameSession.RenderBackend.CANVAS_2D:
		push_error("2D path backend wrong")
		return false
	if GameSession.backend_for_path("res://levels_3d/plaza_default.ssk") != GameSession.RenderBackend.WORLD_3D:
		push_error("3D path backend wrong")
		return false
	var twin := GameSession.paired_path("res://levels/plaza_default.ssk")
	if twin != "res://levels_3d/plaza_default.ssk":
		push_error("paired_path 2D→3D got %s" % twin)
		return false
	if GameSession.paired_path(twin) != "res://levels/plaza_default.ssk":
		push_error("paired_path 3D→2D round-trip failed")
		return false

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
	player.call("_ensure_death_overlay")
	var bound = player.get("_death_overlay")
	if bound != death:
		push_error("Player did not bind baked DeathOverlay (got %s)" % bound)
		main.queue_free()
		return false

	GameSession.pending_level_path = ""
	GameSession.pending_backend = GameSession.RenderBackend.CANVAS_2D

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
