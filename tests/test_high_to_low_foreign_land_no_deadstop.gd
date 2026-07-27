extends RefCounted
## Regression: higher-story air landing on a lower pipe must convert falling
## speed into along-ramp motion — no dead-stop on the near/bottom L1 route.


func run() -> bool:
	# Load the real scene so Player/@onready + physics tick code paths run.
	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)

	var player = main.get_node("Player")
	var level = main.get_node("RampLevel")
	if player == null or level == null:
		main.queue_free()
		return false

	# Ensure Player/@onready refs are usable even if _ready hasn't run yet.
	player.depth = player.get_node("PseudoDepthBody")
	player._head_debug_label = player.get_node("Body/HeadDebug/Label")
	player._head_debug_panel = player.get_node("Body/HeadDebug")
	player._face_nose = player.get_node("Body/FaceNose")

	var l1l: QuarterPipe = null
	var l0r: QuarterPipe = null
	# Rebuild pipes onto the scene's RampLevel so the test is deterministic.
	var ramp := level as RampLevel
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		main.queue_free()
		return false
	ramp.spec = spec
	ramp.cell_size_x = spec.cell_w
	ramp.cell_size_z = spec.cell_h
	ramp.pipes.clear()
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.layer = int(pd.get("layer", 0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		ramp.pipes.append(qp)
		if int(qp.side) == 0 and int(qp.layer) == 1 and l1l == null:
			l1l = qp
		if int(qp.side) == 1 and int(qp.layer) == 0 and l0r == null:
			l0r = qp
	if l1l == null or l0r == null:
		push_error("missing pipes")
		main.queue_free()
		return false

	# This test assumes Player has the scripted private fields used elsewhere.
	var z: float = (float(l1l.z_min) + float(l1l.z_max)) * 0.5
	var cope_l1: float = PipeMath.coping_x(0, float(l1l.lip_x), float(l1l.radius))
	var approach_vx: float = -120.0

	# No-input fall: we are unlocked air falling from L1 towards the shared
	# coping column; landing on L0 must retain a meaningful along-ramp speed.
	player.call("_clear_air")
	player._on_ramp = false
	player._airborne = true
	player.depth.airborne = true
	player._air_x_locked = false
	player._spine_transfer_lock = false
	player._acid_drop_lock = false
	player._flew_out_this_aerial = false
	player._transfer_available = true
	player._acid_drop_available = true
	player._ramp_side = 0
	player._air_side = 0
	player._air_lip_x = float(l1l.lip_x)
	player._air_radius = float(l1l.radius)
	player._air_base_height = float(l1l.base_height)
	player._air_coping_x = cope_l1
	player._exit_pipe_side = 0
	player._exit_pipe_lip = float(l1l.lip_x)
	player._exit_pipe_coping = cope_l1
	player._exit_travel_x = -1.0
	player._velocity = Vector2(approach_vx, 0.0)
	player.air_over = "left_pipe"
	player._air_over_layer = 1
	player.air_abs_height = 450.0
	player.air_vel_y = -50.0
	player.depth.logical_x = cope_l1 - 3.0
	player.depth.logical_z = z
	player.depth.surface_height = player.air_abs_height

	var landed := false
	var landed_base := -1.0
	var landed_along := 0.0
	var landed_side := -1
	for i in range(240):
		player._physics_process(1.0 / 60.0)
		if not player._airborne and player._on_ramp:
			landed = true
			landed_base = float(player._ramp_base_height)
			landed_along = float(player._ramp_along)
			landed_side = int(player._ramp_side)
			break

	main.queue_free()
	return (
		landed
		and absf(landed_base - 0.0) < 0.5
		and landed_side == int(l0r.side)
		and absf(landed_along) > 50.0
		and signf(landed_along) == signf(approach_vx)
		and not bool(player._spine_transfer_lock)
	)

