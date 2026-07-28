class_name PlayerRuntimeFixture
extends RefCounted
## Shared main.tscn + level bootstrap for PlayerSim presentation tests.


var tree: SceneTree
var main: Node
var player
var level: RampLevel
var sim: PlayerSim


func setup(level_path: String) -> bool:
	tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("PlayerRuntimeFixture: no SceneTree")
		return false
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("PlayerRuntimeFixture: failed to load main.tscn")
		return false
	main = packed.instantiate()
	tree.root.add_child(main)
	player = main.get_node_or_null("Player")
	level = main.get_node_or_null("RampLevel") as RampLevel
	if player == null or level == null:
		push_error("PlayerRuntimeFixture: missing Player or RampLevel")
		teardown()
		return false
	var text := FileAccess.get_file_as_string(level_path)
	if text.is_empty():
		push_error("PlayerRuntimeFixture: missing level %s" % level_path)
		teardown()
		return false
	var spec := LevelLoader.parse_text(text, level_path.get_file().get_basename())
	if spec == null:
		push_error("PlayerRuntimeFixture parse: %s" % LevelLoader.last_error)
		teardown()
		return false
	level.apply_spec(spec)
	if player.has_method("_boot_sim"):
		player._boot_sim()
	sim = player.get_sim() if player.has_method("get_sim") else null
	if sim == null:
		push_error("PlayerRuntimeFixture: PlayerSim not booted")
		teardown()
		return false
	return true


func teardown() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	main = null
	player = null
	level = null
	sim = null
	GameSession.pending_level_path = ""
