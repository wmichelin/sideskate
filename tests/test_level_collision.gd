extends RefCounted
## LevelCollision3D builds metadata StaticBody trimeshes; ray hits face roles.

const _CollisionLayers := preload("res://scripts/physics/collision_layers.gd")
const _ContactAdapter := preload("res://scripts/physics/contact_adapter.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("no tree")
		return false
	GameSession.pending_level_path = "res://tests/levels/test_halfpipe.ssk"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)

	var level := main.get_node_or_null("RampLevel") as RampLevel
	var col := main.get_node_or_null("World3D/LevelCollision3D")
	var vis := main.get_node_or_null("World3D/LevelVisual3D")
	var player = main.get_node_or_null("Player")
	if level == null or col == null or vis == null or player == null:
		push_error("missing nodes")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	if level.spec == null:
		var text := FileAccess.get_file_as_string("res://tests/levels/test_halfpipe.ssk")
		var spec := LevelLoader.parse_text(text, "test_halfpipe")
		if spec == null:
			push_error(LevelLoader.last_error)
			main.queue_free()
			return false
		level.apply_spec(spec)
		level.rebuilt.emit()

	col.call("rebuild")
	vis.call("rebuild")
	if int(col.get("part_count")) <= 0:
		push_error("collision part_count == 0")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if int(vis.get("mesh_count")) <= 0:
		push_error("visual mesh_count == 0")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	# AABB parity (approx): visual and collision should cover similar extents.
	var va: AABB = vis.get("last_aabb")
	var ca: AABB = col.get("last_aabb")
	if va.size.length() < 0.1 or ca.size.length() < 0.1:
		push_error("empty aabb vis=%s col=%s" % [va, ca])
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	if absf(va.size.x - ca.size.x) > 0.5 or absf(va.size.z - ca.size.z) > 0.5:
		push_error("aabb mismatch vis=%s col=%s" % [va, ca])
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	if not (player is CharacterBody3D):
		push_error("Player is not CharacterBody3D")
		main.queue_free()
		GameSession.pending_level_path = ""
		return false

	# Prove contact via CharacterBody sweep (trimesh raycasts are unreliable).
	var body := player as CharacterBody3D
	var start: Vector3 = _WorldSpace.logical_to_world(
		level.spec.spawn_x, level.spec.spawn_z, level.spec.spawn_height + 200.0
	)
	body.global_position = start
	body.collision_mask = _CollisionLayers.player_mask()
	var motion := Vector3(0.0, -5.0, 0.0)
	var col_hit := body.move_and_collide(motion)
	if col_hit == null:
		push_error(
			"floor collide miss at spawn (parts=%s aabb=%s)"
			% [col.get("part_count"), col.get("last_aabb")]
		)
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	var meta: Dictionary = _ContactAdapter.hit_from_collision(col_hit)
	if str(meta.get("face_role", "")) == "":
		push_error("collide hit missing face_role meta=%s" % meta)
		main.queue_free()
		GameSession.pending_level_path = ""
		return false
	# Restore player to spawn for scene teardown cleanliness.
	if player.has_method("_teleport_body_to_logical"):
		player.depth.logical_x = level.spec.spawn_x
		player.depth.logical_z = level.spec.spawn_z
		player.depth.surface_height = level.spec.spawn_height
		player.call("_teleport_body_to_logical")

	main.queue_free()
	GameSession.pending_level_path = ""
	return true
