class_name PlayerRuntimeFixture
extends RefCounted
## Shared Player + RampLevel scene bootstrap for runtime regressions.
## Not collected by TestHarness (name does not match test_*.gd).


var main: Node = null
var player = null
var ramp: RampLevel = null


func setup(level_path: String = "res://tests/levels/layered_demo.ssk") -> bool:
	teardown()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("PlayerRuntimeFixture: no SceneTree")
		return false
	main = load("res://scenes/main.tscn").instantiate()
	if main == null:
		push_error("PlayerRuntimeFixture: failed to load main.tscn")
		return false
	tree.root.add_child(main)
	player = main.get_node_or_null("Player")
	ramp = main.get_node_or_null("RampLevel") as RampLevel
	if player == null or ramp == null:
		push_error("PlayerRuntimeFixture: missing Player or RampLevel")
		teardown()
		return false
	_wire_player_onready()
	if not level_path.is_empty():
		if not load_level(level_path):
			teardown()
			return false
	return true


func load_level(level_path: String) -> bool:
	if ramp == null:
		return false
	var text := FileAccess.get_file_as_string(level_path)
	if text.is_empty() and not FileAccess.file_exists(level_path):
		push_error("PlayerRuntimeFixture: missing level %s" % level_path)
		return false
	var spec := LevelLoader.parse_text(text, level_path.get_file().get_basename())
	if spec == null:
		push_error("PlayerRuntimeFixture parse: %s" % LevelLoader.last_error)
		return false
	ramp.apply_spec(spec)
	# apply_spec does not emit rebuilt; notify Player so depth Z bounds / spawn sync.
	ramp.rebuilt.emit()
	return true


func teardown() -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
	main = null
	player = null
	ramp = null


func tick(n: int = 1, delta: float = 1.0 / 60.0) -> void:
	if player == null:
		return
	for _i in range(n):
		player._physics_process(delta)


func find_pipe(side: int, layer: int, z: float = NAN) -> QuarterPipe:
	if ramp == null:
		return null
	for pipe in ramp.pipes:
		if int(pipe.side) != side or int(pipe.layer) != layer:
			continue
		if not is_nan(z) and not pipe.contains_z(z):
			continue
		return pipe
	return null


func clear_to_air() -> void:
	if player == null:
		return
	player.call("_clear_air")
	player._on_ramp = false
	player._airborne = true
	player.depth.airborne = true


func seed_pipe_exit_air(pipe: QuarterPipe, height_above_coping: float = 40.0) -> void:
	if player == null or pipe == null:
		return
	var coping := PipeMath.coping_x(int(pipe.side), pipe.lip_x, pipe.radius)
	var z := (float(pipe.z_min) + float(pipe.z_max)) * 0.5
	clear_to_air()
	player._air_x_locked = true
	player._acid_drop_lock = false
	player._spine_transfer_lock = false
	player._transfer_available = true
	player._acid_drop_available = true
	player._flew_out_this_aerial = false
	player._crossed_pipe_coping_this_aerial = true
	player._air_side = int(pipe.side)
	player._air_lip_x = float(pipe.lip_x)
	player._air_radius = float(pipe.radius)
	player._air_base_height = float(pipe.base_height)
	player._air_z_min = float(pipe.z_min)
	player._air_z_max = float(pipe.z_max)
	player._air_coping_x = coping
	player._exit_pipe_side = int(pipe.side)
	player._exit_pipe_lip = float(pipe.lip_x)
	player._exit_pipe_coping = coping
	player._exit_pipe_z_min = float(pipe.z_min)
	player._exit_pipe_z_max = float(pipe.z_max)
	player._exit_travel_x = PipeMath.coping_sign(int(pipe.side))
	player.air_over = PipeMath.zone_name(int(pipe.side))
	player._air_over_layer = int(pipe.layer)
	player.air_abs_height = float(pipe.base_height) + float(pipe.radius) + height_above_coping
	player.air_vel_y = -80.0
	player._vert_vel = -80.0
	player._last_nonzero_vert_vel = -80.0
	player.depth.logical_x = coping
	player.depth.logical_z = z
	player.depth.surface_height = player.air_abs_height
	player._velocity = Vector2(PipeMath.coping_sign(int(pipe.side)) * 180.0, 0.0)
	player._actual_vel_x = player._velocity.x
	player.facing_h = "r" if player._velocity.x > 0.0 else "l"


func _wire_player_onready() -> void:
	player.depth = player.get_node("PseudoDepthBody")
	var head_label = player.get_node_or_null("Body/HeadDebug/Label")
	var head_panel = player.get_node_or_null("Body/HeadDebug")
	var face = player.get_node_or_null("Body/FaceNose")
	if head_label != null:
		player._head_debug_label = head_label
	if head_panel != null:
		player._head_debug_panel = head_panel
	if face != null:
		player._face_nose = face
