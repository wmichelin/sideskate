extends RefCounted
## Low→high spine settle: no tunneling of non-pipe solids; land on L1 target.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")
const _Clearance := preload("res://scripts/aerial_spine_clearance.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false

	var l1 = fx.find_pipe(QuarterPipe.PipeSide.LEFT, 1)
	if l1 == null:
		push_error("layered_demo missing L1 left")
		fx.teardown()
		return false

	var player = fx.player
	var cell_w: float = float(fx.ramp.spec.cell_w)
	var cope1 := PipeMath.coping_x(int(l1.side), l1.lip_x, l1.radius)
	var z := (float(l1.z_min) + float(l1.z_max)) * 0.5
	var dest_h := float(l1.base_height) + float(l1.radius)
	# Start a few cells west of L1 coping (gap / hole toward L0), already clear of dest.
	var start_x := cope1 - cell_w * 3.0

	fx.clear_to_air()
	player._air_x_locked = false
	player._spine_transfer_lock = false
	player._acid_drop_lock = false
	player._transfer_available = true
	player._acid_drop_available = true
	player._flew_out_this_aerial = false
	player.depth.logical_x = start_x
	player.depth.logical_z = z
	player.air_abs_height = dest_h + 12.0
	player.air_vel_y = 40.0
	player._vert_vel = 40.0
	player._last_nonzero_vert_vel = 40.0
	player._air_carry_speed = 220.0
	player.depth.surface_height = player.air_abs_height
	player.facing_h = "r"

	var hit := {
		"zone": "left_pipe",
		"side": int(l1.side),
		"lip_x": float(l1.lip_x),
		"radius": float(l1.radius),
		"base_height": float(l1.base_height),
		"top_coping": cope1,
		"z_min": float(l1.z_min),
		"z_max": float(l1.z_max),
		"layer": int(l1.layer),
	}
	player._apply_spine_lock(hit, 220.0)
	if not bool(player._spine_transfer_lock):
		push_error("spine lock failed")
		fx.teardown()
		return false
	# Ensure a real X settle across the gap (shared-column locks can no-op settle).
	if not bool(player._settle.x_active) or absf(float(player._settle.x_to) - start_x) < 1.0:
		player.depth.logical_x = start_x
		player._begin_transfer_x_lerp(cope1, true, float(l1.radius))
	if not bool(player._settle.x_active):
		push_error("expected active X settle toward L1 coping")
		fx.teardown()
		return false

	var penetrated := false
	var landed_ok := false
	for _i in range(200):
		fx.tick(1)
		if bool(player._spine_transfer_lock) or bool(player._airborne):
			var under: Dictionary = player._level.resolve_air_contact(
				player.depth.logical_x,
				player.depth.logical_z,
				player.air_abs_height,
				-1,
				NAN,
				NAN,
				false,
				NAN,
				NAN,
			)
			var floor_h := _Clearance.underfoot_solid_height(under)
			var uhit: Dictionary = under.get("hit", {})
			if (
				not is_nan(floor_h)
				and not ContactMath.is_pipe(uhit)
				and player.air_abs_height < floor_h - _Clearance.CLEARANCE_EPS - 0.05
			):
				penetrated = true
				push_error(
					"tunneled non-pipe solid: h=%s floor=%s zone=%s x=%s"
					% [
						player.air_abs_height,
						floor_h,
						under.get("zone", ""),
						player.depth.logical_x,
					]
				)
				break
		if not player._airborne and player._on_ramp:
			if (
				absf(float(player._ramp_base_height) - float(l1.base_height)) < 0.5
				and int(player._ramp_side) == int(l1.side)
			):
				landed_ok = true
			else:
				push_error(
					"landed wrong pipe: base=%s side=%s"
					% [player._ramp_base_height, player._ramp_side]
				)
			break
		if (
			bool(player._spine_transfer_lock)
			and not bool(player._settle.x_active)
			and player._is_aligned_with_air_coping()
			and player.air_abs_height >= dest_h - 1.0
		):
			# Settled on coping still airborne — clearance held us above dest.
			landed_ok = true
			break

	if penetrated:
		fx.teardown()
		return false
	if not landed_ok:
		push_error(
			"low→high incomplete: air=%s spine=%s settle=%s on_ramp=%s h=%s x=%s want=%s"
			% [
				player._airborne,
				player._spine_transfer_lock,
				player._settle.x_active,
				player._on_ramp,
				player.air_abs_height,
				player.depth.logical_x,
				cope1,
			]
		)
		fx.teardown()
		return false

	fx.teardown()
	return true
