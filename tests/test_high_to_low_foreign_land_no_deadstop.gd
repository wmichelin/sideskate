extends RefCounted
## Regression: higher-story air landing on a lower pipe must convert falling
## speed into along-ramp motion — no dead-stop on the near/bottom L1 route.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false

	var l1l = fx.find_pipe(QuarterPipe.PipeSide.LEFT, 1)
	var l0r = fx.find_pipe(QuarterPipe.PipeSide.RIGHT, 0)
	if l1l == null or l0r == null:
		push_error("missing pipes")
		fx.teardown()
		return false

	var z: float = (float(l1l.z_min) + float(l1l.z_max)) * 0.5
	var cope_l1: float = PipeMath.coping_x(0, float(l1l.lip_x), float(l1l.radius))
	var approach_vx: float = -120.0
	var player = fx.player

	# No-input fall: unlocked air falling from L1 towards the shared coping
	# column; landing on L0 must retain a meaningful along-ramp speed.
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
		fx.tick(1)
		if not player._airborne and player._on_ramp:
			landed = true
			landed_base = float(player._ramp_base_height)
			landed_along = float(player._ramp_along)
			landed_side = int(player._ramp_side)
			break

	var land_ok := (
		landed
		and absf(landed_base - 0.0) < 0.5
		and landed_side == int(l0r.side)
		and absf(landed_along) > 50.0
		and signf(landed_along) == signf(approach_vx)
		and not bool(player._spine_transfer_lock)
	)
	if not land_ok:
		push_error(
			"high→low land regression: landed=%s base=%s side=%s along=%s spine=%s"
			% [landed, landed_base, landed_side, landed_along, player._spine_transfer_lock]
		)
	var spine_ok := _held_high_to_low_spine_transfers(fx, player, l1l, l0r, z)
	var deck_ok := _spine_refuses_deck_land(player, l0r, z)
	fx.teardown()
	return land_ok and spine_ok and deck_ok


## Mid-lerp over an L1 deck must not clip a spine lock aimed at L0.
## Target land is deferred until settle finishes or coping-aligned.
func _spine_refuses_deck_land(player, l0: QuarterPipe, z: float) -> bool:
	player.call("_clear_air")
	player._on_ramp = false
	player._airborne = true
	player.depth.airborne = true
	player._air_x_locked = true
	player._spine_transfer_lock = true
	player._acid_drop_lock = false
	player._air_side = int(l0.side)
	player._air_lip_x = float(l0.lip_x)
	player._air_radius = float(l0.radius)
	player._air_base_height = float(l0.base_height)
	player._air_coping_x = PipeMath.coping_x(int(l0.side), l0.lip_x, l0.radius)
	player._air_z_min = float(l0.z_min)
	player._air_z_max = float(l0.z_max)
	player.air_over = PipeMath.zone_name(int(l0.side))
	player._air_over_layer = int(l0.layer)
	player.air_abs_height = 145.0
	player.air_vel_y = -40.0
	player._velocity = Vector2(PipeMath.coping_sign(int(l0.side)) * 80.0, 0.0)
	player.depth.logical_x = player._air_coping_x + 20.0
	player.depth.logical_z = z
	player.depth.surface_height = player.air_abs_height
	player._settle.x_active = true

	var deck_hit := {"zone": "deck", "active": true, "height": 141.0}
	var contact := ContactMath.make_air_contact("deck", 1, 141.0, true, deck_hit)
	var landed: bool = bool(player.call("_try_land_from_air_contact", contact, 150.0, 1.0 / 60.0, 1.0))
	if landed or not bool(player._airborne) or not bool(player._spine_transfer_lock):
		push_error(
			"spine must refuse deck land: landed=%s air=%s spine=%s"
			% [landed, player._airborne, player._spine_transfer_lock]
		)
		return false

	var pipe_hit := {
		"zone": PipeMath.zone_name(int(l0.side)),
		"active": true,
		"side": int(l0.side),
		"lip_x": float(l0.lip_x),
		"radius": float(l0.radius),
		"base_height": float(l0.base_height),
		"height": float(l0.base_height) + float(l0.radius),
		"theta": PI * 0.5,
	}
	var pipe_contact := ContactMath.make_air_contact(
		str(pipe_hit.zone), int(l0.layer), float(pipe_hit.height), true, pipe_hit
	)
	player.air_abs_height = float(pipe_hit.height) - 1.0
	player.air_vel_y = -40.0
	var deferred: bool = bool(
		player.call(
			"_try_land_from_air_contact",
			pipe_contact,
			float(pipe_hit.height) + 10.0,
			1.0 / 60.0,
			1.0,
		)
	)
	if deferred:
		push_error("spine must defer target land while settle unaligned")
		return false

	player._settle.x_active = false
	player.depth.logical_x = player._air_coping_x
	player.air_abs_height = float(pipe_hit.height) - 1.0
	player.air_vel_y = -40.0
	var pipe_landed: bool = bool(
		player.call(
			"_try_land_from_air_contact",
			pipe_contact,
			float(pipe_hit.height) + 10.0,
			1.0 / 60.0,
			1.0,
		)
	)
	if not pipe_landed:
		push_error("spine must land on locked target once settle done")
		return false
	return true


func _held_high_to_low_spine_transfers(
	fx, player, l1: QuarterPipe, l0: QuarterPipe, z: float
) -> bool:
	var coping := PipeMath.coping_x(int(l1.side), l1.lip_x, l1.radius)
	player.call("_clear_air")
	player._on_ramp = false
	player._airborne = true
	player.depth.airborne = true
	player._air_x_locked = true
	player._spine_transfer_lock = false
	player._acid_drop_lock = false
	player._transfer_available = true
	player._acid_drop_available = true
	player._air_side = int(l1.side)
	player._air_lip_x = l1.lip_x
	player._air_radius = l1.radius
	player._air_base_height = l1.base_height
	player._air_z_min = l1.z_min
	player._air_z_max = l1.z_max
	player._air_coping_x = coping
	player._exit_pipe_side = int(l1.side)
	player._exit_pipe_lip = l1.lip_x
	player._exit_pipe_coping = coping
	player._exit_pipe_z_min = l1.z_min
	player._exit_pipe_z_max = l1.z_max
	player.air_over = "left_pipe"
	player._air_over_layer = int(l1.layer)
	player.air_abs_height = l1.base_height + l1.radius + 40.0
	player.air_vel_y = 100.0
	player._vert_vel = 100.0
	player._last_nonzero_vert_vel = 100.0
	player.facing_h = "l"
	player.depth.logical_x = coping
	player.depth.logical_z = z
	player.depth.surface_height = player.air_abs_height

	if not player._try_spine_transfer(true):
		push_error("held transfer must spine high→low")
		return false
	var target_ok := (
		bool(player._spine_transfer_lock)
		and absf(float(player._air_base_height) - float(l0.base_height)) < 0.5
		and absf(float(player._air_z_min) - float(l0.z_min)) < 0.05
		and absf(float(player._air_z_max) - float(l0.z_max)) < 0.05
	)
	if not target_ok:
		push_error(
			"held high→low spine picked wrong target: base=%s z=[%s,%s]"
			% [player._air_base_height, player._air_z_min, player._air_z_max]
		)
		return false

	# Solid deck prisms used to snag the capsule mid-settle (side-wall stick).
	# X must keep advancing toward the dest coping through the deck corridor.
	var dest_cope := PipeMath.coping_x(int(l0.side), l0.lip_x, l0.radius)
	var start_x := float(player.depth.logical_x)
	if not bool(player._settle.x_active):
		player._begin_spine_x_lerp(dest_cope)
	var stuck := true
	for _i in range(90):
		fx.tick(1)
		var x := float(player.depth.logical_x)
		if absf(x - dest_cope) < 15.0 or absf(x - start_x) > 40.0:
			stuck = false
			break
		if not bool(player._spine_transfer_lock):
			stuck = false
			break
	if stuck:
		push_error(
			"high→low spine stuck mid-deck: x=%s start=%s dest=%s"
			% [player.depth.logical_x, start_x, dest_cope]
		)
		return false
	return true
