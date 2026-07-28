extends RefCounted
## AerialMath: action routing, acid-drop selection, coping≠lip, landing height.


func run() -> bool:
	var ok := true
	ok = _action_routing() and ok
	ok = _horiz_resolve() and ok
	ok = _acid_travel_resolve() and ok
	ok = _acid_land_along() and ok
	ok = _pipe_land_along() and ok
	ok = _landing_height() and ok
	ok = _drop_in_along() and ok
	ok = _lock_x_duration() and ok
	ok = _fly_out_pipe_lock() and ok
	ok = _acid_drop_selection() and ok
	ok = _spine_transfer() and ok
	ok = _spine_transfer_layers() and ok
	ok = _spine_layered_demo_high_to_low() and ok
	ok = _pipe_behind() and ok
	return ok


func _action_routing() -> bool:
	if AerialMath.choose_air_action(12.0, 0.0) != AerialMath.ACTION_TRANSFER:
		push_error("rising → transfer")
		return false
	if AerialMath.choose_air_action(0.0, 8.0) != AerialMath.ACTION_TRANSFER:
		push_error("apex after rise → transfer (acid must not steal)")
		return false
	if AerialMath.choose_air_action(-5.0, 8.0) != AerialMath.ACTION_ACID_DROP:
		push_error("falling → acid drop")
		return false
	if AerialMath.choose_air_action(0.0, -4.0) != AerialMath.ACTION_ACID_DROP:
		push_error("rest after down → acid drop")
		return false
	return true


func _horiz_resolve() -> bool:
	if absf(AerialMath.resolve_horiz_vel(40.0, -10.0) - 40.0) > 0.01:
		push_error("prefer actual vx")
		return false
	if absf(AerialMath.resolve_horiz_vel(2.0, -50.0) - (-50.0)) > 0.01:
		push_error("fall back to momentum when |actual| small")
		return false
	if absf(AerialMath.resolve_horiz_vel(0.0, 0.5)) > 0.01:
		push_error("dead zone → 0")
		return false
	return true


func _acid_travel_resolve() -> bool:
	# Live ACTUAL wins even over exit / momentum.
	if absf(AerialMath.resolve_acid_travel_x(40.0, -200.0, 1.0) - 40.0) > 0.01:
		push_error("acid travel prefer actual")
		return false
	# Stick into-bowl MOMENTUM must NOT beat pipe-exit outward.
	var after_exit := AerialMath.resolve_acid_travel_x(0.0, -180.0, 1.0)
	if absf(after_exit - 1.0) > 0.01:
		push_error("acid travel exit over into-bowl momentum, got %s" % after_exit)
		return false
	var left_exit := AerialMath.resolve_acid_travel_x(0.0, 90.0, -1.0)
	if absf(left_exit - (-1.0)) > 0.01:
		push_error("acid travel left exit over +momentum, got %s" % left_exit)
		return false
	# No exit → momentum.
	if absf(AerialMath.resolve_acid_travel_x(0.0, -50.0, 0.0) - (-50.0)) > 0.01:
		push_error("acid travel momentum when no exit")
		return false
	if absf(AerialMath.resolve_acid_travel_x(0.0, 0.0, 0.0)) > 0.01:
		push_error("acid travel dead → 0")
		return false
	# Opposite wall + ahead helpers.
	if AerialMath.acid_drop_want_side(80.0) != 0:
		push_error("travel right → want LEFT pipe")
		return false
	if AerialMath.acid_drop_want_side(-80.0) != 1:
		push_error("travel left → want RIGHT pipe")
		return false
	if not AerialMath.acid_coping_ahead(100.0, 200.0, 1.0):
		push_error("coping ahead right")
		return false
	if AerialMath.acid_coping_ahead(100.0, 50.0, 1.0):
		push_error("coping behind right must fail")
		return false
	# X step clamp: never left while travel +.
	var step := AerialMath.acid_clamp_x_step(100.0, 80.0, 200.0, 1.0)
	if absf(step - 100.0) > 0.01:
		push_error("acid clamp must block reverse step, got %s" % step)
		return false
	var fwd := AerialMath.acid_clamp_x_step(100.0, 150.0, 200.0, 1.0)
	if absf(fwd - 150.0) > 0.01:
		push_error("acid clamp allow forward, got %s" % fwd)
		return false
	return true


func _acid_land_along() -> bool:
	# Travel right onto LEFT pipe: fall drop-in is + along — keep / merge.
	var good := AerialMath.acid_land_along(20.0, -80.0, 0, 1.0)
	if good < 1.0:
		push_error("acid land opposite wall must keep +travel, got %s" % good)
		return false
	# Travel right onto RIGHT pipe (wrong wall): fall is − along — must not reverse.
	var no_rev := AerialMath.acid_land_along(50.0, -80.0, 1, 1.0)
	if no_rev * 1.0 < 0.0:
		push_error("acid land must never reverse travel, got %s" % no_rev)
		return false
	# Into-bowl approach while travel + → flip to travel sign.
	var flipped := AerialMath.acid_land_along(-120.0, -10.0, 1, 1.0)
	if flipped < 0.0:
		push_error("acid land must flip opposing approach, got %s" % flipped)
		return false
	return true


func _pipe_land_along() -> bool:
	if absf(AerialMath.land_hold_sign(80.0, true, -1.0) - 1.0) > 0.01:
		push_error("acid travel wins hold_sign")
		return false
	if absf(AerialMath.land_hold_sign(0.0, true, -40.0) - (-1.0)) > 0.01:
		push_error("exit travel hold when no acid travel")
		return false
	if absf(AerialMath.land_hold_sign(0.0, false, -40.0)) > 0.01:
		push_error("no hold without no_reverse")
		return false
	if absf(AerialMath.clamp_against_hold(-50.0, 1.0)) > 0.01:
		push_error("clamp kills reverse")
		return false
	if absf(AerialMath.clamp_against_hold(50.0, 1.0) - 50.0) > 0.01:
		push_error("clamp keeps travel")
		return false
	# Classic locked land: carry into right pipe.
	var classic := AerialMath.pipe_land_along(
		40.0, -60.0, 1, true, false, false, 0.0, 0.0, 180.0
	)
	if absf(classic - (-180.0)) > 0.01:
		push_error("classic locked land want carry -180, got %s" % classic)
		return false
	# Soft no-reverse: never merge into-bowl against hold.
	var soft := AerialMath.pipe_land_along(
		-90.0, -80.0, 1, false, false, true, 0.0, 1.0, 0.0
	)
	if absf(soft) > 0.01:
		push_error("soft no_reverse must zero reverse, got %s" % soft)
		return false
	# Acid land path.
	var acid := AerialMath.pipe_land_along(
		20.0, -80.0, 0, true, true, true, 1.0, 1.0, 100.0
	)
	if acid < 1.0:
		push_error("acid pipe_land_along must keep +travel, got %s" % acid)
		return false
	return true


func _landing_height() -> bool:
	# Pipe-exit lock uses radius when sample is below coping (classic drop-in).
	var locked := AerialMath.landing_support_height(true, false, "left_pipe", 150.0, 20.0)
	if absf(locked - 150.0) > 0.01:
		push_error("pipe-exit lock want radius floor, got %s" % locked)
		return false
	# Solid pad at/above coping wins (upper floor over pipe run).
	var pad := AerialMath.landing_support_height(true, false, "left_pipe", 150.0, 150.0)
	if absf(pad - 150.0) > 0.01:
		push_error("pipe-exit on pad want sampled, got %s" % pad)
		return false
	var pad_hi := AerialMath.landing_support_height(true, false, "right_pipe", 150.0, 188.0)
	if absf(pad_hi - 188.0) > 0.01:
		push_error("pipe-exit above coping pad want 188, got %s" % pad_hi)
		return false
	# Stacked L1 coping floor (base 188 + radius 188) wins over lower sample.
	var l1_coping := 376.0
	var l1_lock := AerialMath.landing_support_height(true, false, "left_pipe", l1_coping, 200.0)
	if absf(l1_lock - l1_coping) > 0.01:
		push_error("L1 pipe-exit lock want coping 376, got %s" % l1_lock)
		return false
	# Acid-drop lock must sample (no upward snap to radius).
	var acid := AerialMath.landing_support_height(true, true, "right_pipe", 150.0, 20.0)
	if absf(acid - 20.0) > 0.01:
		push_error("acid lock want sampled height, got %s" % acid)
		return false
	# Free air samples.
	var free := AerialMath.landing_support_height(false, false, "flat", 150.0, 44.0)
	if absf(free - 44.0) > 0.01:
		push_error("free air want sampled, got %s" % free)
		return false
	return true


func _drop_in_along() -> bool:
	# Right pipe (side 1): falling → negative along.
	var from_fall_r := AerialMath.drop_in_along_from_land_vy(-80.0, 1)
	if absf(from_fall_r - (-80.0)) > 0.01:
		push_error("right fall → along -80, got %s" % from_fall_r)
		return false
	# Left pipe (side 0): falling → positive along.
	var from_fall_l := AerialMath.drop_in_along_from_land_vy(-80.0, 0)
	if absf(from_fall_l - 80.0) > 0.01:
		push_error("left fall → along +80, got %s" % from_fall_l)
		return false
	if absf(AerialMath.drop_in_along_from_land_vy(10.0, 1)) > 0.01:
		push_error("rising land_vy → 0 along")
		return false
	# Keep faster approach into pipe (right: more negative).
	var keep := AerialMath.merge_drop_in_along(-120.0, -40.0, 1)
	if absf(keep - (-120.0)) > 0.01:
		push_error("keep faster approach, got %s" % keep)
		return false
	# Fall wins when deeper than approach.
	var fall_wins := AerialMath.merge_drop_in_along(-20.0, -90.0, 1)
	if absf(fall_wins - (-90.0)) > 0.01:
		push_error("fall wins when deeper, got %s" % fall_wins)
		return false
	# Outward approach alone → no seed (soft land).
	var soft := AerialMath.merge_drop_in_along(50.0, 0.0, 1)
	if absf(soft) > 0.01:
		push_error("outward approach alone → 0, got %s" % soft)
		return false
	# Outward approach + fall → use fall.
	var out_plus_fall := AerialMath.merge_drop_in_along(50.0, -70.0, 1)
	if absf(out_plus_fall - (-70.0)) > 0.01:
		push_error("outward+fall → fall, got %s" % out_plus_fall)
		return false
	# Low→high: climb drains land_vy; stashed into-pipe carry must win.
	var carry_x := AerialMath.lock_carry_velocity_x(200.0, 1)
	if absf(carry_x - (-200.0)) > 0.01:
		push_error("right carry want -200, got %s" % carry_x)
		return false
	var after_climb := AerialMath.merge_drop_in_along(carry_x, -15.0, 1)
	if absf(after_climb - (-200.0)) > 0.01:
		push_error("carry must survive weak land_vy, got %s" % after_climb)
		return false
	var carry_l := AerialMath.lock_carry_velocity_x(150.0, 0)
	if absf(carry_l - 150.0) > 0.01:
		push_error("left carry want +150, got %s" % carry_l)
		return false
	return true


func _lock_x_duration() -> bool:
	# duration = base + rate * height
	var at0 := AerialMath.lock_x_duration_for_height(0.0, 0.18, 0.002, 0.9)
	if absf(at0 - 0.18) > 0.001:
		push_error("at coping → base, got %s" % at0)
		return false
	var at100 := AerialMath.lock_x_duration_for_height(100.0, 0.18, 0.002, 0.9)
	if absf(at100 - 0.38) > 0.001:
		push_error("at 100 → 0.38, got %s" % at100)
		return false
	var at200 := AerialMath.lock_x_duration_for_height(200.0, 0.18, 0.002, 0.9)
	if absf(at200 - 0.58) > 0.001:
		push_error("at 200 → 0.58, got %s" % at200)
		return false
	var capped := AerialMath.lock_x_duration_for_height(1000.0, 0.18, 0.002, 0.9)
	if absf(capped - 0.9) > 0.001:
		push_error("above max soft-caps, got %s" % capped)
		return false
	var uncapped := AerialMath.lock_x_duration_for_height(1000.0, 0.18, 0.002, 0.0)
	if absf(uncapped - 2.18) > 0.001:
		push_error("max=0 uncapped, got %s" % uncapped)
		return false
	if absf(AerialMath.smoothstep01(0.0)) > 0.001:
		push_error("smoothstep(0) → 0")
		return false
	if absf(AerialMath.smoothstep01(1.0) - 1.0) > 0.001:
		push_error("smoothstep(1) → 1")
		return false
	var mid_s := AerialMath.smoothstep01(0.5)
	if absf(mid_s - 0.5) > 0.001:
		push_error("smoothstep(0.5) → 0.5, got %s" % mid_s)
		return false
	if absf(AerialMath.smootherstep01(0.0)) > 0.001:
		push_error("smootherstep(0) → 0")
		return false
	if absf(AerialMath.smootherstep01(1.0) - 1.0) > 0.001:
		push_error("smootherstep(1) → 1")
		return false
	var s25 := AerialMath.smootherstep01(0.25)
	if s25 >= 0.25:
		push_error("smootherstep eases in, got %s" % s25)
		return false
	var s75 := AerialMath.smootherstep01(0.75)
	if s75 <= 0.75:
		push_error("smootherstep eases out, got %s" % s75)
		return false
	return true


func _fly_out_pipe_lock() -> bool:
	# Right pipe (side 1): need INPUT +X, rising, height within [coping, coping+above].
	if not AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 1.0, 80.0):
		push_error("right pipe + input right + rising + in window → fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, -1.0, 80.0):
		push_error("right pipe + input left → no fly out")
		return false
	# Above the window (e.g. near apex with a small slider) → no fly out.
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 200.0, 150.0, 40.0, 1.0, 80.0):
		push_error("above window (coping+50 > +40) → no fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 200.0, 150.0, 1.0, 1.0, 80.0):
		push_error("near apex with above=1 → no fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 140.0, 150.0, 40.0, 1.0, 80.0):
		push_error("below coping → no fly out")
		return false
	# Falling / apex: never fly out even with outward input and in-window height.
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 1.0, -40.0):
		push_error("falling → no fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 1.0, 0.0):
		push_error("apex rest → no fly out")
		return false
	# Left pipe (side 0): need INPUT −X.
	if not AerialMath.should_fly_out_pipe_lock(true, false, 0, 170.0, 150.0, 40.0, -1.0, 80.0):
		push_error("left pipe + input left + rising + in window → fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 0, 170.0, 150.0, 40.0, 1.0, 80.0):
		push_error("left pipe + input right → no fly out")
		return false
	# Stick deadzone: |input| below eps does not fly out.
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 0.1, 80.0):
		push_error("input inside deadzone → no fly out")
		return false
	# Acid-drop lock never auto-flies out.
	if AerialMath.should_fly_out_pipe_lock(true, true, 1, 170.0, 150.0, 40.0, 1.0, 80.0):
		push_error("acid lock must not fly out")
		return false
	# Unlocked / not locked.
	if AerialMath.should_fly_out_pipe_lock(false, false, 1, 170.0, 150.0, 40.0, 1.0, 80.0):
		push_error("unlocked air must not fly out")
		return false
	# above_coping 0: unlock only at coping height.
	if not AerialMath.should_fly_out_pipe_lock(true, false, 1, 150.0, 150.0, 0.0, 1.0, 80.0):
		push_error("above=0 at coping + outward input + rising → fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 151.0, 150.0, 0.0, 1.0, 80.0):
		push_error("above=0 slightly over coping → no fly out")
		return false
	# Vertical / Z-dominant INPUT must not fly out (need X-dominant).
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 0.0, 80.0, 0.15, 1.0):
		push_error("pure vertical INPUT → no fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 0.5, 80.0, 0.15, 0.8):
		push_error("Z-dominant INPUT → no fly out")
		return false
	if not AerialMath.should_fly_out_pipe_lock(true, false, 1, 170.0, 150.0, 40.0, 0.8, 80.0, 0.15, 0.3):
		push_error("X-dominant outward INPUT → fly out")
		return false
	# Elevated story: window is relative to coping_floor (base+radius).
	if not AerialMath.should_fly_out_pipe_lock(true, false, 1, 360.0, 350.0, 40.0, 1.0, 80.0):
		push_error("L1 at coping+10 within +40 → fly out")
		return false
	if AerialMath.should_fly_out_pipe_lock(true, false, 1, 400.0, 350.0, 40.0, 1.0, 80.0):
		push_error("L1 at coping+50 outside +40 → no fly out")
		return false
	return true


func _acid_pipes() -> Array:
	# Plaza bay: left lip 200 r100 (coping 100), right lip 500 r100 (coping 600).
	return [
		{"side": 0, "lip_x": 200.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 1, "lip_x": 500.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]


func _acid_drop_selection() -> bool:
	var pipes := _acid_pipes()
	# Vel right → LEFT pipe. Target is usually slightly behind (returning to wall).
	# Player x=120, left coping=100 → ahead=-20 within buffer 44.
	var rightward := AerialMath.find_acid_drop_target(pipes, 120.0, 50.0, 80.0, 44.0, 120.0)
	if rightward.is_empty():
		push_error("rightward should find left pipe")
		return false
	if int(rightward.side) != 0:
		push_error("rightward want LEFT pipe, got side=%s" % rightward.side)
		return false
	if absf(float(rightward.top_coping) - 100.0) > 0.01:
		push_error("top_coping want 100 got %s" % rightward.top_coping)
		return false
	if absf(float(rightward.top_coping) - float(rightward.lip_x)) < 1.0:
		push_error("invariant: top coping must not equal lip")
		return false
	if not AerialMath.is_top_coping(
		int(rightward.side), float(rightward.lip_x), float(rightward.radius), float(rightward.top_coping)
	):
		push_error("is_top_coping failed for selected target")
		return false

	# Vel left → RIGHT pipe. Player x=620, right coping=600 → ahead=-20.
	var leftward := AerialMath.find_acid_drop_target(pipes, 620.0, 50.0, -80.0, 44.0, 120.0)
	if leftward.is_empty() or int(leftward.side) != 1:
		push_error("leftward want RIGHT pipe")
		return false
	if absf(float(leftward.top_coping) - 600.0) > 0.01:
		push_error("leftward top_coping want 600 got %s" % leftward.top_coping)
		return false

	# Ahead within max: player x=80 moving right, left coping 100 → ahead=20.
	var near := AerialMath.find_acid_drop_target(pipes, 80.0, 50.0, 80.0, 44.0, 120.0)
	if near.is_empty():
		push_error("near ahead should find left coping")
		return false
	var too_far := AerialMath.find_acid_drop_target(pipes, 80.0, 50.0, 80.0, 44.0, 10.0)
	if not too_far.is_empty():
		push_error("max_ahead should reject distant coping")
		return false

	# Behind beyond buffer → reject (ahead=-60 < -44).
	var past_buf := AerialMath.find_acid_drop_target(pipes, 160.0, 50.0, 80.0, 44.0, 120.0)
	if not past_buf.is_empty():
		push_error("beyond buffer should reject")
		return false

	# Z out of range.
	var oz := AerialMath.find_acid_drop_target(pipes, 120.0, 500.0, 80.0, 44.0, 120.0)
	if not oz.is_empty():
		push_error("Z OOB should reject")
		return false

	# Opposite-facing only: moving right never returns RIGHT.
	if int(rightward.side) == 1 or int(near.side) == 1:
		push_error("acid drop must be opposite-facing only")
		return false

	return true


func _spine_transfer() -> bool:
	var cw := 47.0
	var z := 50.0
	# From RIGHT pipe coping looking behind (+1) toward LEFT opposite.
	# Shared coping D=0: RIGHT lip 100 r100 coping 200; LEFT lip 300 r100 coping 200.
	var shared := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]
	var d0 := AerialMath.find_spine_transfer_target(
		shared, 200.0, z, 1.0, 1, 100.0, cw
	)
	if d0.is_empty() or int(d0.side) != 0:
		push_error("D=0 shared coping should find LEFT spine target")
		return false
	if absf(float(d0.top_coping) - 200.0) > 0.01:
		push_error("D=0 top_coping want 200")
		return false

	# D=1: gap = cw. RIGHT coping 200, LEFT coping 200+cw.
	var d1_pipes := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0 + cw, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]
	var d1 := AerialMath.find_spine_transfer_target(
		d1_pipes, 200.0, z, 1.0, 1, 100.0, cw
	)
	if d1.is_empty():
		push_error("D=1 should find spine target")
		return false
	if AerialMath.spine_gap_cells(float(d1.top_coping) - 200.0, cw) != 1:
		push_error("D=1 gap cells want 1")
		return false

	# D=2: gap = 2*cw — still spine transfer.
	var d2_pipes := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0 + 2.0 * cw, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]
	var d2 := AerialMath.find_spine_transfer_target(
		d2_pipes, 200.0, z, 1.0, 1, 100.0, cw
	)
	if d2.is_empty():
		push_error("D=2 should find spine target")
		return false

	# D=3: gap = 3*cw — normal transfer (no spine target).
	var d3_pipes := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0 + 3.0 * cw, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]
	var d3 := AerialMath.find_spine_transfer_target(
		d3_pipes, 200.0, z, 1.0, 1, 100.0, cw
	)
	if not d3.is_empty():
		push_error("D=3 must not spine-transfer (use normal transfer)")
		return false

	# Same-side only → empty.
	var same := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
		{"side": 1, "lip_x": 400.0, "radius": 100.0, "z_min": 0.0, "z_max": 100.0},
	]
	if not AerialMath.find_spine_transfer_target(same, 200.0, z, 1.0, 1, 100.0, cw).is_empty():
		push_error("same-side pipes must not spine-transfer")
		return false

	# Z outside band → empty.
	var oz := AerialMath.find_spine_transfer_target(
		shared, 200.0, 500.0, 1.0, 1, 100.0, cw
	)
	if not oz.is_empty():
		push_error("Z OOB must not spine-transfer")
		return false

	# From LEFT looking behind (−1) toward RIGHT.
	var from_left := AerialMath.find_spine_transfer_target(
		shared, 200.0, z, -1.0, 0, 300.0, cw
	)
	if from_left.is_empty() or int(from_left.side) != 1:
		push_error("from LEFT behind should find RIGHT")
		return false

	if AerialMath.spine_want_side(1.0) != 0 or AerialMath.spine_want_side(-1.0) != 1:
		push_error("spine_want_side mapping wrong")
		return false

	return true


## Stacked opposite pipes at shared X gap: pick by prefer_h (at/below, else above).
func _spine_transfer_layers() -> bool:
	var cw := 47.0
	var z := 50.0
	# From RIGHT L0 coping 200 looking behind toward LEFT opposites at same X.
	# L0 LEFT: base 0 r100 coping_floor 100; L1 LEFT: base 188 r100 coping_floor 288.
	var stacked := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "base_height": 0.0, "layer": 0,
			"z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0, "radius": 100.0, "base_height": 0.0, "layer": 0,
			"z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0, "radius": 100.0, "base_height": 188.0, "layer": 1,
			"z_min": 0.0, "z_max": 100.0},
	]
	if not AerialMath.spine_height_better(288.0, 100.0, 300.0):
		push_error("at/below: higher L1 should beat L0 when prefer mid-L1")
		return false
	if AerialMath.spine_height_better(100.0, 288.0, 300.0):
		push_error("at/below: L0 must not beat L1 when prefer mid-L1")
		return false
	if not AerialMath.spine_height_better(100.0, 288.0, 50.0):
		push_error("both above: lower L0 should beat L1")
		return false

	var mid_l1 := AerialMath.find_spine_transfer_target(
		stacked, 200.0, z, 1.0, 1, 100.0, cw, 0.05, 300.0
	)
	if mid_l1.is_empty() or int(mid_l1.get("layer", -1)) != 1:
		push_error("prefer at/above L1 coping should pick L1, got %s" % mid_l1)
		return false

	var mid_l0 := AerialMath.find_spine_transfer_target(
		stacked, 200.0, z, 1.0, 1, 100.0, cw, 0.05, 150.0
	)
	if mid_l0.is_empty() or int(mid_l0.get("layer", -1)) != 0:
		push_error("prefer between L0 and L1 coping should pick L0, got %s" % mid_l0)
		return false

	var below_both := AerialMath.find_spine_transfer_target(
		stacked, 200.0, z, 1.0, 1, 100.0, cw, 0.05, 10.0
	)
	if below_both.is_empty() or int(below_both.get("layer", -1)) != 0:
		push_error("prefer below both should pick nearest above (L0), got %s" % below_both)
		return false

	# Only L1 opposite in gap — up transfer from below L1 coping.
	var only_l1 := [
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "base_height": 0.0, "layer": 0,
			"z_min": 0.0, "z_max": 100.0},
		{"side": 0, "lip_x": 300.0, "radius": 100.0, "base_height": 188.0, "layer": 1,
			"z_min": 0.0, "z_max": 100.0},
	]
	var up := AerialMath.find_spine_transfer_target(
		only_l1, 200.0, z, 1.0, 1, 100.0, cw, 0.05, 50.0
	)
	if up.is_empty() or int(up.get("layer", -1)) != 1:
		push_error("only L1 in gap should up-transfer to L1, got %s" % up)
		return false

	return true


## layered_demo: L1 left coping shares X with L0 right — high→low spine.
func _spine_layered_demo_high_to_low() -> bool:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("layered_demo parse: %s" % LevelLoader.last_error)
		return false
	var l1_left: Dictionary = {}
	for pd in spec.pipes:
		if int(pd.side) == 0 and int(pd.get("layer", -1)) == 1:
			l1_left = pd
			break
	if l1_left.is_empty():
		push_error("layered_demo: no L1 left pipe")
		return false
	var from_x: float = PipeMath.coping_x(0, float(l1_left.lip_x), float(l1_left.radius))
	var z: float = (float(l1_left.z_min) + float(l1_left.z_max)) * 0.5
	var prefer: float = float(l1_left.get("base_height", 0.0)) + float(l1_left.radius)
	var hit: Dictionary = AerialMath.find_spine_transfer_target(
		spec.pipes, from_x, z, -1.0, 0, float(l1_left.lip_x), spec.cell_w, 0.05, prefer, spec
	)
	if hit.is_empty():
		push_error("high→low: expected L0 right from L1 left, got empty")
		return false
	if int(hit.get("layer", -1)) != 0 or int(hit.get("side", -1)) != 1:
		push_error("high→low want L0 right, got %s" % hit)
		return false

	# from_x over the hole west of coping (not exact shared X) — abs gap + glyph
	# walk must still find L0 right (signed "behind" would reject this).
	var hole_x: float = from_x - spec.cell_w * 0.6
	var hit_hole: Dictionary = AerialMath.find_spine_transfer_target(
		spec.pipes, hole_x, z, -1.0, 0, float(l1_left.lip_x), spec.cell_w, 0.05, prefer, spec
	)
	if hit_hole.is_empty() or int(hit_hole.get("layer", -1)) != 0:
		push_error("high→low from over hole should still find L0, got %s" % hit_hole)
		return false

	# Slight past shared coping into hole (classic signed-behind reject case).
	var past_x: float = from_x - 2.0
	var hit_past: Dictionary = AerialMath.find_spine_transfer_target(
		spec.pipes, past_x, z, -1.0, 0, float(l1_left.lip_x), spec.cell_w, 0.05, prefer, spec
	)
	if hit_past.is_empty() or int(hit_past.get("side", -1)) != 1:
		push_error("high→low past shared X must still find L0 right, got %s" % hit_past)
		return false
	return true


func _pipe_behind() -> bool:
	# Shared coping spine: LEFT lip 300 r100 (coping 200), RIGHT lip 100 r100 (coping 200).
	var pipes := [
		{"side": 0, "lip_x": 300.0, "radius": 100.0, "z_min": 0.0, "z_max": 80.0},
		{"side": 1, "lip_x": 100.0, "radius": 100.0, "z_min": 0.0, "z_max": 80.0},
	]
	# From left pipe, behind = -1 (LEFT coping_sign), find right neighbor.
	var hit := AerialMath.find_pipe_behind(pipes, 200.0, 40.0, -1.0, 0, 300.0)
	if hit.is_empty():
		push_error("pipe_behind should find opposite at shared coping")
		return false
	if int(hit.side) != 1:
		push_error("pipe_behind want RIGHT, got %s" % hit.side)
		return false
	# Excluding the right pipe should not return it.
	var skipped := AerialMath.find_pipe_behind(pipes, 200.0, 40.0, -1.0, 1, 100.0)
	if not skipped.is_empty() and int(skipped.side) == 1 and absf(float(skipped.lip_x) - 100.0) < 0.05:
		push_error("pipe_behind should honor exclude")
		return false
	return true
