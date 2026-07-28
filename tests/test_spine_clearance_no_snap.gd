extends RefCounted
## Spine clearance must never bottom→top teleport; low→high still clears deck.


const _Fixture := preload("res://tests/player_runtime_fixture.gd")
const _Clearance := preload("res://scripts/aerial_spine_clearance.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false
	var ok := (
		_refuse_below_peak_margin(fx)
		and _no_teleport_lift_during_spine(fx)
		and _low_to_high_clears_deck(fx)
	)
	fx.teardown()
	return ok


func _find_deck_flanked_l1_left(fx):
	var spec: LevelSpec = fx.ramp.spec
	var cell_w: float = float(spec.cell_w)
	for pipe in fx.ramp.pipes:
		if int(pipe.side) != QuarterPipe.PipeSide.LEFT or int(pipe.layer) != 1:
			continue
		var cope := PipeMath.coping_x(int(pipe.side), pipe.lip_x, pipe.radius)
		var z := (float(pipe.z_min) + float(pipe.z_max)) * 0.5
		var west := spec.cell_at(cope - cell_w * 0.6, z)
		var ginfo: Dictionary = spec.glyph_at_prefer_h(
			west.x, west.y, float(pipe.base_height) + float(pipe.radius)
		)
		if str(ginfo.get("glyph", "")) == "#":
			return pipe
	return null


func _refuse_below_peak_margin(fx) -> bool:
	var l1 = _find_deck_flanked_l1_left(fx)
	if l1 == null:
		push_error("no deck-flanked L1 left")
		return false
	var cell_w: float = float(fx.ramp.spec.cell_w)
	var cope1 := PipeMath.coping_x(0, l1.lip_x, l1.radius)
	var dest_h := float(l1.base_height) + float(l1.radius)
	var start_x := cope1 - cell_w * 4.0
	var corr: Dictionary = fx.player._build_spine_corridor(
		start_x, cope1, 0, float(l1.lip_x), float(l1.base_height), float(l1.radius)
	)
	var peak := float(corr.get("peak", dest_h))
	var below := dest_h - 20.0
	# Hardened lock gate (try_spine): feet need peak + CLEARANCE_EPS.
	if below + 0.001 >= peak + _Clearance.CLEARANCE_EPS:
		push_error(
			"below-peak height unexpectedly clears lock margin (h=%s peak=%s)"
			% [below, peak]
		)
		return false
	if peak < dest_h - 0.01:
		push_error("corridor peak should be at least dest coping: %s < %s" % [peak, dest_h])
		return false
	return true


func _no_teleport_lift_during_spine(fx) -> bool:
	var l1 = _find_deck_flanked_l1_left(fx)
	if l1 == null:
		return false
	var cell_w: float = float(fx.ramp.spec.cell_w)
	var cope1 := PipeMath.coping_x(0, l1.lip_x, l1.radius)
	var z := (float(l1.z_min) + float(l1.z_max)) * 0.5
	var dest_h := float(l1.base_height) + float(l1.radius)
	var p = fx.player
	fx.clear_to_air()
	p._transfer_available = true
	p.depth.logical_x = cope1 - cell_w * 4.0
	p.depth.logical_z = z
	p.air_abs_height = dest_h + _Clearance.CLEARANCE_EPS + 2.0
	p.depth.surface_height = p.air_abs_height
	p.air_vel_y = 20.0
	p._vert_vel = 20.0
	p._last_nonzero_vert_vel = 20.0
	p._air_carry_speed = 220.0
	p.facing_h = "r"
	p._apply_spine_lock({
		"zone": "left_pipe",
		"side": 0,
		"lip_x": float(l1.lip_x),
		"radius": float(l1.radius),
		"base_height": float(l1.base_height),
		"top_coping": cope1,
		"z_min": float(l1.z_min),
		"z_max": float(l1.z_max),
		"layer": 1,
	}, 220.0)
	if not bool(p._spine_transfer_lock):
		push_error("expected spine lock at/above peak")
		return false
	var prev_h := float(p.air_abs_height)
	var max_up := 0.0
	for _i in range(180):
		fx.tick(1)
		var h := float(p.air_abs_height)
		var dh := h - prev_h
		if dh > max_up:
			max_up = dh
		# Hard gate: no single-tick clearance teleport.
		if dh > _Clearance.DEFAULT_MAX_LIFT_PER_TICK + 4.0:
			push_error(
				"bottom→top snap: dh=%s h %s→%s x=%s (cap=%s)"
				% [dh, prev_h, h, p.depth.logical_x, _Clearance.DEFAULT_MAX_LIFT_PER_TICK]
			)
			return false
		prev_h = h
		if not bool(p._airborne):
			break
	if max_up > _Clearance.DEFAULT_MAX_LIFT_PER_TICK + 4.0:
		push_error("recorded max up-tick %s exceeds cap" % max_up)
		return false
	return true


func _low_to_high_clears_deck(fx) -> bool:
	var l1 = _find_deck_flanked_l1_left(fx)
	if l1 == null:
		return false
	var cell_w: float = float(fx.ramp.spec.cell_w)
	var cope1 := PipeMath.coping_x(0, l1.lip_x, l1.radius)
	var z := (float(l1.z_min) + float(l1.z_max)) * 0.5
	var dest_h := float(l1.base_height) + float(l1.radius)
	var start_x := cope1 - cell_w * 4.0
	var p = fx.player
	fx.clear_to_air()
	p._transfer_available = true
	p.depth.logical_x = start_x
	p.depth.logical_z = z
	p.air_abs_height = dest_h + 8.0
	p.depth.surface_height = p.air_abs_height
	p.air_vel_y = 40.0
	p._vert_vel = 40.0
	p._last_nonzero_vert_vel = 40.0
	p._air_carry_speed = 240.0
	p.facing_h = "r"
	p._apply_spine_lock({
		"zone": "left_pipe",
		"side": 0,
		"lip_x": float(l1.lip_x),
		"radius": float(l1.radius),
		"base_height": float(l1.base_height),
		"top_coping": cope1,
		"z_min": float(l1.z_min),
		"z_max": float(l1.z_max),
		"layer": 1,
	}, 240.0)
	if not bool(p._spine_transfer_lock):
		push_error("low→high lock failed at clear height")
		return false
	var penetrated := false
	var landed_ok := false
	for _i in range(240):
		var h_before := float(p.air_abs_height)
		fx.tick(1)
		if bool(p._spine_transfer_lock):
			var under: Dictionary = p._level.resolve_air_contact(
				p.depth.logical_x,
				p.depth.logical_z,
				p.air_abs_height,
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
				and p.air_abs_height < floor_h - _Clearance.CLEARANCE_EPS - 0.05
			):
				penetrated = true
				push_error(
					"tunneled: h=%s floor=%s (was %s)"
					% [p.air_abs_height, floor_h, h_before]
				)
				break
		if not bool(p._airborne) and bool(p._on_ramp):
			if (
				absf(float(p._ramp_base_height) - float(l1.base_height)) < 0.5
				and int(p._ramp_side) == 0
			):
				landed_ok = true
			break
	if penetrated:
		return false
	if not landed_ok:
		push_error(
			"low→high incomplete: air=%s spine=%s h=%s x=%s"
			% [p._airborne, p._spine_transfer_lock, p.air_abs_height, p.depth.logical_x]
		)
		return false
	return true
