extends RefCounted
## Aligned `#` deck abutting a pipe coping: mount deck top, no fly-out into wall.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false
	var player = fx.player
	var ramp = fx.ramp

	# L0 left pipe with #### deck outward on the same rows.
	var pipe: QuarterPipe = null
	for p in ramp.pipes:
		if int(p.layer) == 0 and int(p.side) == QuarterPipe.PipeSide.LEFT \
				and p.contains_z(100.0):
			pipe = p
			break
	if pipe == null:
		push_error("missing L0 left pipe")
		fx.teardown()
		return false

	var cope := PipeMath.coping_x(int(pipe.side), pipe.lip_x, pipe.radius)
	var ext: Dictionary = ContactMath.outward_deck_extension(
		ramp.spec.decks, int(pipe.side), cope, 100.0
	)
	if ext.is_empty():
		push_error("layered_demo L0 left must have outward deck extension")
		fx.teardown()
		return false

	# Entering air from this pipe must mount the deck instead.
	player.call("_clear_air")
	player._on_ramp = true
	player._airborne = false
	player.depth.airborne = false
	player._ramp_side = int(pipe.side)
	player._ramp_lip_x = float(pipe.lip_x)
	player._ramp_base_height = float(pipe.base_height)
	player._ramp_z_min = float(pipe.z_min)
	player._ramp_z_max = float(pipe.z_max)
	player._ramp_along = 200.0
	player._velocity = Vector2(-200.0, 0.0)
	player.depth.logical_x = cope + 5.0
	player.depth.logical_z = 100.0
	player.depth.surface_height = float(pipe.base_height) + float(pipe.radius) - 5.0

	player._enter_air_from_pipe({
		"side": int(pipe.side),
		"lip_x": float(pipe.lip_x),
		"radius": float(pipe.radius),
		"base_height": float(pipe.base_height),
	}, 200.0)

	if bool(player._airborne) or bool(player._air_x_locked):
		push_error(
			"pipe+deck must mount grounded: air=%s lock=%s"
			% [player._airborne, player._air_x_locked]
		)
		fx.teardown()
		return false
	if absf(float(player.depth.surface_height) - float(ext.height)) > 1.0:
		push_error(
			"must sit on deck top: h=%s want=%s"
			% [player.depth.surface_height, ext.height]
		)
		fx.teardown()
		return false
	if float(player.depth.logical_x) >= cope - 0.5:
		# Left pipe: outward is −X, so mounted x should be < cope.
		push_error(
			"must mount outward of coping: x=%s cope=%s"
			% [player.depth.logical_x, cope]
		)
		fx.teardown()
		return false

	# Fly-out still refused if somehow air-locked on an extension pipe.
	fx.clear_to_air()
	player._air_x_locked = true
	player._spine_transfer_lock = false
	player._acid_drop_lock = false
	player._flew_out_this_aerial = false
	player._crossed_pipe_coping_this_aerial = true
	player._air_side = int(pipe.side)
	player._air_lip_x = float(pipe.lip_x)
	player._air_radius = float(pipe.radius)
	player._air_base_height = float(pipe.base_height)
	player._air_coping_x = cope
	player._exit_pipe_side = int(pipe.side)
	player._exit_pipe_lip = float(pipe.lip_x)
	player._exit_travel_x = PipeMath.coping_sign(int(pipe.side))
	player.air_abs_height = float(ext.height) + 10.0
	player.air_vel_y = 80.0
	player._last_input = Vector2(PipeMath.coping_sign(int(pipe.side)), 0.0)
	player.depth.logical_x = cope
	player.depth.logical_z = 100.0
	player.depth.surface_height = player.air_abs_height
	if bool(player._try_fly_out_from_pipe_lock()):
		push_error("fly-out must refuse into aligned deck extension")
		fx.teardown()
		return false

	# After a normal fly-out (no deck), exit back must stay solid — not excepted.
	fx.clear_to_air()
	player._air_x_locked = false
	player._flew_out_this_aerial = true
	player._airborne = true
	player._exit_pipe_side = int(pipe.side)
	player._exit_pipe_lip = float(pipe.lip_x)
	player.call("_refresh_action_collision_filters")
	for body in player._excluded_ride_bodies:
		if not is_instance_valid(body):
			continue
		if str(body.get_meta("face_role", "")) == "back":
			push_error("flew-out must not exclude pipe back (ghost wall)")
			fx.teardown()
			return false

	fx.teardown()
	return true
