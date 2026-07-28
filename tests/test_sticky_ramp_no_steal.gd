extends RefCounted
## Regression: L1 sticky ride must never adopt stacked L0 at shared coping.
## layered_demo: L1 left coping X == L0 right coping X.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")


func run() -> bool:
	if not _sticky_ramp_action_unit():
		return false
	if not _sample_no_fallthrough_past_l1():
		return false
	if not _ride_up_l1_never_adopts_l0():
		return false
	if not _dual_l1_bands_have_distinct_identities():
		return false
	return _fresh_lower_l1_entry_stays_grounded()


func _sticky_ramp_action_unit() -> bool:
	var l1 := {
		"active": true,
		"zone": "left_pipe",
		"side": 0,
		"lip_x": 1128.0,
		"base_height": 188.0,
	}
	var l0 := {
		"active": true,
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 752.0,
		"base_height": 0.0,
	}
	if ContactMath.sticky_ramp_action(true, l0, l1, 100.0) != "ride":
		push_error("own active must ride even if sample shows L0")
		return false
	if ContactMath.sticky_ramp_action(false, l0, l1, 100.0) != "launch":
		push_error("past L1 with L0 underfoot + up speed must launch")
		return false
	if ContactMath.sticky_ramp_action(false, l0, l1, 0.0) != "launch":
		push_error("past L1 with L0 underfoot must launch (never adopt)")
		return false
	if ContactMath.sticky_ramp_action(false, {"active": false}, l1, 50.0) != "launch":
		push_error("past L1 inactive + toward coping must launch")
		return false
	if ContactMath.sticky_ramp_action(false, {"active": false}, l1, 0.0) != "leave":
		push_error("past L1 inactive + no up speed must leave")
		return false
	var same_h_opp := {
		"active": true,
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 100.0,
		"base_height": 188.0,
	}
	if ContactMath.sticky_ramp_action(false, same_h_opp, l1, 10.0) != "launch":
		push_error("lateral opposite at same story must launch not adopt")
		return false
	return true


func _build_layered_demo() -> Dictionary:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("layered_demo parse: %s" % LevelLoader.last_error)
		return {}
	var level := RampLevel.new()
	level.spec = spec
	level.cell_size_x = spec.cell_w
	level.cell_size_z = spec.cell_h
	level.pipes.clear()
	var l1_left: QuarterPipe = null
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.layer = int(pd.get("layer", 0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		level.pipes.append(qp)
		if int(qp.side) == 0 and int(qp.layer) == 1 and l1_left == null:
			l1_left = qp
	var l0_right: QuarterPipe = null
	if l1_left != null:
		var c1 := PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
		for qp in level.pipes:
			if int(qp.side) != 1 or int(qp.layer) != 0:
				continue
			var c0 := PipeMath.coping_x(1, qp.lip_x, qp.radius)
			if absf(c1 - c0) < 1.0:
				l0_right = qp
				break
	if l1_left == null or l0_right == null:
		push_error("missing L1 left / shared L0 right")
		_free_level(level)
		return {}
	return {"level": level, "l1": l1_left, "l0": l0_right, "spec": spec}


func _sample_no_fallthrough_past_l1() -> bool:
	var built := _build_layered_demo()
	if built.is_empty():
		return false
	var level: RampLevel = built.level
	var l1: QuarterPipe = built.l1
	var l0: QuarterPipe = built.l0
	var cope := PipeMath.coping_x(0, l1.lip_x, l1.radius)
	var z := (l1.z_min + l1.z_max) * 0.5
	# Just past L1 coping (west): L1 inactive, L0 right still active.
	var past := cope - 2.0
	var prefer_h := l1.base_height + l1.radius
	var sticky: Dictionary = level.sample(
		past, z, int(l1.side), l1.lip_x, prefer_h, l1.base_height
	)
	if sticky.get("active", false):
		push_error("sticky past L1 coping should be inactive, got %s" % sticky)
		_free_level(level)
		return false
	if ContactMath.is_pipe(sticky):
		push_error("sticky past L1 must not return another pipe: %s" % sticky)
		_free_level(level)
		return false
	var plain: Dictionary = level.sample(past, z, -1, NAN, prefer_h)
	if not ContactMath.is_pipe(plain):
		push_error("plain past L1 should still see L0: %s" % plain)
		_free_level(level)
		return false
	if absf(float(plain.get("base_height", -1.0)) - l0.base_height) > 0.5:
		push_error("plain past L1 should be L0 base, got %s" % plain)
		_free_level(level)
		return false
	var current := {
		"active": true,
		"zone": "left_pipe",
		"side": int(l1.side),
		"lip_x": l1.lip_x,
		"base_height": l1.base_height,
	}
	if ContactMath.sticky_ramp_action(false, plain, current, 200.0) != "launch":
		push_error("sticky_ramp_action must launch past L1 with L0 underfoot")
		_free_level(level)
		return false
	_free_level(level)
	return true


## Simulate riding L1 left toward coping: identity stays L1 until launch —
## never adopts L0 base_height (the silent spine steal).
func _ride_up_l1_never_adopts_l0() -> bool:
	var built := _build_layered_demo()
	if built.is_empty():
		return false
	var level: RampLevel = built.level
	var l1: QuarterPipe = built.l1
	var z := (l1.z_min + l1.z_max) * 0.5
	var radius := l1.radius
	var base := l1.base_height
	var side := int(l1.side)
	var lip := l1.lip_x
	var cope_sign := PipeMath.coping_sign(side)
	var theta := 0.35
	var along_mag := 400.0
	var dt := 1.0 / 60.0
	var current := {
		"active": true,
		"zone": "left_pipe",
		"side": side,
		"lip_x": lip,
		"base_height": base,
	}
	for _i in range(120):
		var x_off := radius * sin(theta)
		var x := lip - x_off if side == 0 else lip + x_off
		var own: Dictionary = l1.query_surface(x, z)
		var prefer_h := base + radius * (1.0 - cos(theta))
		var sticky: Dictionary = level.sample(x, z, side, lip, prefer_h, base)
		var under := sticky
		if not own.get("active", false) and not ContactMath.is_pipe(sticky):
			under = level.sample(x, z, -1, NAN, prefer_h)
		# Going up: world vx points toward coping.
		var world_vx := along_mag * cope_sign
		var toward := maxf(world_vx * cope_sign, 0.0)
		var action := ContactMath.sticky_ramp_action(
			own.get("active", false), under, current, toward
		)
		if action == "ride":
			if absf(float(own.get("base_height", -1.0)) - base) > 0.5:
				push_error("ride must keep L1 base, got %s" % own)
				_free_level(level)
				return false
			if (
				ContactMath.is_pipe(sticky)
				and absf(float(sticky.get("base_height", -1.0)) - base) > 0.5
			):
				push_error("sticky sample stole story while riding: %s" % sticky)
				_free_level(level)
				return false
			theta += (along_mag * dt) / radius
			if theta >= PI * 0.5 - 0.001:
				_free_level(level)
				return true
			continue
		if action == "launch":
			if absf(float(current.get("base_height", -1.0)) - base) > 0.5:
				push_error("launch identity must still be L1")
				_free_level(level)
				return false
			_free_level(level)
			return true
		push_error("unexpected leave while climbing L1 at x=%s theta=%s" % [x, theta])
		_free_level(level)
		return false
	push_error("did not leave L1 within 120 ticks")
	_free_level(level)
	return false


func _dual_l1_bands_have_distinct_identities() -> bool:
	var built := _build_layered_demo()
	if built.is_empty():
		return false
	var level: RampLevel = built.level
	var upper_left: QuarterPipe = null
	var lower_left: QuarterPipe = null
	for pipe in level.pipes:
		if int(pipe.layer) != 1 or int(pipe.side) != QuarterPipe.PipeSide.LEFT:
			continue
		if upper_left == null or pipe.z_min > upper_left.z_min:
			upper_left = pipe
		if lower_left == null or pipe.z_min < lower_left.z_min:
			lower_left = pipe
	if upper_left == null or lower_left == null:
		push_error("expected separate upper and lower L1 left pipes")
		_free_level(level)
		return false
	if absf(upper_left.lip_x - lower_left.lip_x) > 0.05 \
			or absf(upper_left.base_height - lower_left.base_height) > 0.5:
		push_error("L1 left bands must share horizontal geometry for this regression")
		_free_level(level)
		return false
	var upper_hit: Dictionary = upper_left.query_surface(
		upper_left.lip_x - upper_left.radius * 0.5,
		(upper_left.z_min + upper_left.z_max) * 0.5
	)
	var lower_hit: Dictionary = lower_left.query_surface(
		lower_left.lip_x - lower_left.radius * 0.5,
		(lower_left.z_min + lower_left.z_max) * 0.5
	)
	if ContactMath.same_pipe(upper_hit, lower_hit):
		push_error("separate L1 Z bands must not compare as the same pipe")
		_free_level(level)
		return false

	for pipe in level.pipes:
		if int(pipe.layer) != 1:
			continue
		var z: float = (float(pipe.z_min) + float(pipe.z_max)) * 0.5
		var sign: float = PipeMath.coping_sign(int(pipe.side))
		for x in [
			pipe.lip_x + sign,
			pipe.lip_x + sign * pipe.radius * 0.5,
			pipe.lip_x + sign * (pipe.radius - 1.0),
		]:
			var story: Dictionary = level.sample_pipe_on_story(x, z, pipe.base_height)
			var expected: Dictionary = pipe.query_surface(x, z)
			if not ContactMath.same_pipe(story, expected):
				push_error("L1 story pipe stole at x=%s z=%s: %s" % [x, z, story])
				_free_level(level)
				return false
	_free_level(level)
	return true


func _fresh_lower_l1_entry_stays_grounded() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/layered_demo.ssk"):
		return false
	var player = fx.player
	var ramp = fx.ramp

	var lower_left: QuarterPipe = null
	for pipe in ramp.pipes:
		if int(pipe.layer) == 1 and int(pipe.side) == QuarterPipe.PipeSide.LEFT \
				and pipe.contains_z(169.0):
			lower_left = pipe
			break
	if lower_left == null:
		push_error("missing lower L1 left pipe at z=169")
		fx.teardown()
		return false
	var coping := PipeMath.coping_x(
		int(lower_left.side), lower_left.lip_x, lower_left.radius
	)
	# Start inside the pipe band (lip − a bit toward the trough), not past the lip.
	var entry_x := lower_left.lip_x + PipeMath.coping_sign(int(lower_left.side)) * 23.0
	player.call("_clear_air")
	player._on_ramp = false
	player._airborne = false
	player.depth.airborne = false
	player._velocity = Vector2(-120.0, 0.0)
	player.depth.logical_x = entry_x
	player.depth.logical_z = 169.0
	player.depth.surface_height = 141.0
	fx.tick(1)

	var ok: bool = (
		not bool(player._airborne)
		and bool(player._on_ramp)
		and absf(float(player._ramp_base_height) - 141.0) < 0.5
		and absf(float(player._ramp_z_min) - lower_left.z_min) < 0.05
		and absf(float(player._ramp_z_max) - lower_left.z_max) < 0.05
		and player.depth.logical_x > coping + 10.0
		and player.depth.surface_height < 282.0
	)
	if not ok:
		push_error(
			"fresh lower L1 entry snapped/escaped: x=%s h=%s ramp=%s air=%s z=[%s,%s]"
			% [
				player.depth.logical_x, player.depth.surface_height, player._on_ramp,
				player._airborne, player._ramp_z_min, player._ramp_z_max,
			]
		)
	if ok:
		for pipe in ramp.pipes:
			if int(pipe.layer) != 1 or not pipe.contains_z(169.0):
				continue
			var sign: float = PipeMath.coping_sign(int(pipe.side))
			player.call("_clear_air")
			player._on_ramp = false
			player._airborne = false
			player.depth.airborne = false
			player._velocity = Vector2(sign * 120.0, 0.0)
			player.depth.logical_x = pipe.lip_x + sign * 23.0
			player.depth.logical_z = 169.0
			player.depth.surface_height = 141.0
			for _tick in range(12):
				fx.tick(1)
				if bool(player._airborne) or not bool(player._on_ramp) \
						or absf(float(player._ramp_z_min) - pipe.z_min) > 0.05 \
						or absf(float(player._ramp_z_max) - pipe.z_max) > 0.05:
					ok = false
					push_error(
						"lower L1 climb lost exact identity: side=%s tick=%s ramp=%s air=%s"
						% [pipe.side, _tick, player._on_ramp, player._airborne]
					)
					break
			if not ok:
				break
	fx.teardown()
	return ok


func _free_level(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
