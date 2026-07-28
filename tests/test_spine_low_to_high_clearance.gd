extends RefCounted
## Low→high spine into deck-flanked L1 `#<<<========>>>#` — no solid tunneling.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")
const _Clearance := preload("res://scripts/aerial_spine_clearance.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false

	var l1 = _find_deck_flanked_l1_left(fx)
	if l1 == null:
		push_error("no deck-flanked L1 left pipe")
		fx.teardown()
		return false

	var player = fx.player
	var cell_w: float = float(fx.ramp.spec.cell_w)
	var cope1 := PipeMath.coping_x(int(l1.side), l1.lip_x, l1.radius)
	var z := (float(l1.z_min) + float(l1.z_max)) * 0.5
	var dest_h := float(l1.base_height) + float(l1.radius)
	# Start west of the flanking `#` deck so the corridor crosses deck + coping.
	var start_x := cope1 - cell_w * 4.0

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

	# Corridor gate must refuse below peak.
	var low_hit := {
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
	player.air_abs_height = dest_h - 20.0
	player.depth.surface_height = player.air_abs_height
	var corr_low: Dictionary = player._build_spine_corridor(
		start_x, cope1, int(l1.side), float(l1.lip_x), float(l1.base_height), float(l1.radius)
	)
	if _Clearance.feet_clear_corridor(player.air_abs_height, float(corr_low.peak)):
		push_error("below peak must fail corridor gate")
		fx.teardown()
		return false

	player.air_abs_height = dest_h + 12.0
	player.depth.surface_height = player.air_abs_height
	player._apply_spine_lock(low_hit, 220.0)
	if not bool(player._spine_transfer_lock):
		push_error("spine lock failed")
		fx.teardown()
		return false
	if player._spine_corridor.is_empty():
		push_error("spine corridor not stored")
		fx.teardown()
		return false
	if not bool(player._settle.x_active):
		player.depth.logical_x = start_x
		player._begin_spine_x_lerp(cope1)
	if not bool(player._settle.x_active):
		push_error("expected active X settle")
		fx.teardown()
		return false

	var penetrated := false
	var landed_ok := false
	var crossed_deck_x := false
	for _i in range(240):
		fx.tick(1)
		var holding: bool = bool(player._spine_transfer_lock) and (
			bool(player._settle.x_active) or not player._is_aligned_with_air_coping()
		)
		if holding:
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
			if str(under.get("zone", "")) == "deck":
				crossed_deck_x = true
			if (
				not is_nan(floor_h)
				and not ContactMath.is_pipe(uhit)
				and player.air_abs_height < floor_h - _Clearance.CLEARANCE_EPS - 0.05
			):
				penetrated = true
				push_error(
					"tunneled solid: h=%s floor=%s zone=%s x=%s"
					% [player.air_abs_height, floor_h, under.get("zone", ""), player.depth.logical_x]
				)
				break
			if player.air_abs_height + 0.05 < dest_h:
				penetrated = true
				push_error(
					"below dest mid-corridor: h=%s dest=%s"
					% [player.air_abs_height, dest_h]
				)
				break
			if player._on_ramp and str(player.last_surface.get("zone", "")) == "deck":
				penetrated = true
				push_error("must not land on deck mid-spine")
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

	if penetrated:
		fx.teardown()
		return false
	if not landed_ok:
		push_error(
			"incomplete: air=%s spine=%s settle=%s h=%s x=%s crossed_deck=%s"
			% [
				player._airborne,
				player._spine_transfer_lock,
				player._settle.x_active,
				player.air_abs_height,
				player.depth.logical_x,
				crossed_deck_x,
			]
		)
		fx.teardown()
		return false

	fx.teardown()
	return true


## Prefer L1 left pipe whose west neighbor glyph is deck `#`.
func _find_deck_flanked_l1_left(fx):
	var spec: LevelSpec = fx.ramp.spec
	var cell_w: float = float(spec.cell_w)
	for pipe in fx.ramp.pipes:
		if int(pipe.side) != QuarterPipe.PipeSide.LEFT or int(pipe.layer) != 1:
			continue
		var cope := PipeMath.coping_x(int(pipe.side), pipe.lip_x, pipe.radius)
		var z := (float(pipe.z_min) + float(pipe.z_max)) * 0.5
		var cell: Vector2i = spec.cell_at(cope - cell_w * 0.6, z)
		var ginfo: Dictionary = spec.glyph_at_prefer_h(cell.x, cell.y, 200.0)
		if str(ginfo.get("glyph", "")) == "#":
			return pipe
	return null
