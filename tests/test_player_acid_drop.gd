extends RefCounted
## Player acid drop via facing-cast path (not legacy AerialMath.find_acid_drop_target).

const _Fixture := preload("res://tests/player_runtime_fixture.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/test_acid_outside.ssk"):
		return false
	var ok = (
		_acid_locks_opposite_coping(fx)
		and _acid_settle_reaches_coping(fx)
		and _spine_height_gate(fx)
	)
	fx.teardown()
	return ok


## Exit left wall, stand outside right wall, travel −X onto right coping.
func _acid_locks_opposite_coping(fx) -> bool:
	var left = fx.find_pipe(QuarterPipe.PipeSide.LEFT, 0)
	var right = fx.find_pipe(QuarterPipe.PipeSide.RIGHT, 0)
	if left == null or right == null:
		push_error("acid_outside missing pipes")
		return false
	var right_cope = PipeMath.coping_x(int(right.side), right.lip_x, right.radius)
	var z = (float(left.z_min) + float(left.z_max)) * 0.5
	fx.seed_pipe_exit_air(left, 60.0)
	fx.player.depth.logical_x = right_cope + 60.0
	fx.player.depth.logical_z = z
	fx.player._air_x_locked = false
	fx.player.facing_coping_cells = 8
	fx.player.air_vel_y = -120.0
	fx.player._vert_vel = -120.0
	fx.player._last_nonzero_vert_vel = -120.0
	fx.player._velocity.x = -200.0
	fx.player._actual_vel_x = -200.0
	fx.player._exit_travel_x = -1.0
	fx.player.facing_h = "l"
	fx.player.call("_try_acid_drop")
	if not bool(fx.player._acid_drop_lock):
		push_error("acid press must lock")
		return false
	if absf(float(fx.player._air_coping_x) - right_cope) > 1.0:
		push_error(
			"acid must target opposite coping got %s want %s"
			% [fx.player._air_coping_x, right_cope]
		)
		return false
	return true


func _acid_settle_reaches_coping(fx) -> bool:
	var left = fx.find_pipe(QuarterPipe.PipeSide.LEFT, 0)
	var right = fx.find_pipe(QuarterPipe.PipeSide.RIGHT, 0)
	if left == null or right == null:
		return false
	var right_cope = PipeMath.coping_x(int(right.side), right.lip_x, right.radius)
	var z = (float(left.z_min) + float(left.z_max)) * 0.5
	fx.seed_pipe_exit_air(left, 80.0)
	fx.player.depth.logical_x = right_cope + 70.0
	fx.player.depth.logical_z = z
	fx.player._air_x_locked = false
	fx.player.facing_coping_cells = 8
	fx.player.air_vel_y = -150.0
	fx.player._vert_vel = -150.0
	fx.player._last_nonzero_vert_vel = -150.0
	fx.player._velocity.x = -220.0
	fx.player._actual_vel_x = -220.0
	fx.player._exit_travel_x = -1.0
	fx.player.facing_h = "l"
	fx.player.call("_try_acid_drop")
	if not bool(fx.player._acid_drop_lock):
		push_error("acid settle setup failed")
		return false
	var start_x = float(fx.player.depth.logical_x)
	for _i in range(180):
		fx.tick(1)
		if ContactMath.is_lava(fx.player.last_surface) and not bool(fx.player._airborne):
			push_error("acid settle landed in lava")
			return false
		if not bool(fx.player._settle.x_active) and bool(fx.player._acid_drop_lock):
			break
	var end_x = float(fx.player.depth.logical_x)
	if absf(end_x - start_x) < 1.0 and absf(start_x - right_cope) > 5.0:
		push_error("acid settle did not advance X")
		return false
	if bool(fx.player._acid_drop_lock) and not bool(fx.player._settle.x_active):
		if absf(end_x - right_cope) > 2.0:
			push_error("acid settle finished off coping: x=%s want=%s" % [end_x, right_cope])
			return false
	return true


func _spine_height_gate(fx) -> bool:
	if not fx.load_level("res://tests/levels/layered_demo.ssk"):
		return false
	var l0 = fx.find_pipe(QuarterPipe.PipeSide.RIGHT, 0)
	var l1 = fx.find_pipe(QuarterPipe.PipeSide.LEFT, 1)
	if l0 == null or l1 == null:
		push_error("layered_demo missing pipes for spine gate")
		return false
	var cope0 = PipeMath.coping_x(int(l0.side), l0.lip_x, l0.radius)
	var z = (float(l0.z_min) + float(l0.z_max)) * 0.5
	fx.clear_to_air()
	fx.player._air_x_locked = true
	fx.player._transfer_available = true
	fx.player._acid_drop_available = true
	fx.player._air_side = int(l0.side)
	fx.player._air_lip_x = l0.lip_x
	fx.player._air_radius = l0.radius
	fx.player._air_base_height = l0.base_height
	fx.player._air_z_min = l0.z_min
	fx.player._air_z_max = l0.z_max
	fx.player._air_coping_x = cope0
	fx.player.air_over = "right_pipe"
	fx.player._air_over_layer = 0
	fx.player.facing_h = "l"
	fx.player.facing_coping_cells = 8
	fx.player.depth.logical_x = cope0
	fx.player.depth.logical_z = z
	var dest_h = float(l1.base_height) + float(l1.radius)
	fx.player.air_abs_height = dest_h - 20.0
	fx.player.air_vel_y = 80.0
	fx.player._vert_vel = 80.0
	fx.player._last_nonzero_vert_vel = 80.0
	fx.player.depth.surface_height = fx.player.air_abs_height
	# Even if a facing coping exists, height gate must refuse early low→high.
	if fx.player._try_spine_transfer(true):
		push_error("spine must refuse below dest coping height")
		return false
	return true
