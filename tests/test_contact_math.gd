extends RefCounted
## ContactMath: vertical sweep, solid occlusion, mount / coping-launch guards.

const ContactMath := preload("res://scripts/contact_math.gd")


func run() -> bool:
	var ok := true
	ok = _sweep_catches_solid() and ok
	ok = _already_below_misses_solid() and ok
	ok = _hole_falls_to_pipe() and ok
	ok = _l1_pipe_preferred() and ok
	ok = _mount_and_coping_guards() and ok
	ok = _sample_sweep_integration() and ok
	ok = _air_contact_land_rules() and ok
	ok = _resolve_air_contact_integration() and ok
	ok = _acid_spine_land_rejects() and ok
	ok = _outward_deck_extension() and ok
	return ok


func _flat(h: float) -> Dictionary:
	return {
		"active": true,
		"zone": "flat",
		"height": h,
		"base_height": h,
	}


func _pipe(h: float, base: float = 0.0, side: int = 0, lip: float = 300.0) -> Dictionary:
	return {
		"active": true,
		"zone": "left_pipe" if side == 0 else "right_pipe",
		"height": h,
		"base_height": base,
		"side": side,
		"lip_x": lip,
		"radius": 100.0,
	}


func _sweep_catches_solid() -> bool:
	var cands := [_pipe(100.0, 0.0), _flat(188.0)]
	var r: Dictionary = ContactMath.resolve_vertical(cands, 220.0, 150.0)
	if not ContactMath.is_solid(r.hit):
		push_error("sweep want solid floor, got %s" % r)
		return false
	if absf(float(r.height) - 188.0) > 0.05:
		push_error("sweep want h=188 got %s" % r.height)
		return false
	if not bool(r.crossed_solid):
		push_error("sweep should mark crossed_solid")
		return false
	return true


func _already_below_misses_solid() -> bool:
	# Truly already under the solid: fall continues to pipe (no climb).
	var cands := [_pipe(100.0, 0.0), _flat(188.0)]
	var r: Dictionary = ContactMath.resolve_vertical(cands, 170.0, 140.0)
	if ContactMath.is_solid(r.hit) and absf(float(r.height) - 188.0) < 0.05:
		push_error("already-below must not climb to solid 188: %s" % r)
		return false
	if not ContactMath.is_pipe(r.hit):
		push_error("already-below want pipe, got %s" % r)
		return false
	return true


func _hole_falls_to_pipe() -> bool:
	var cands := [_pipe(100.0, 0.0)]
	var r: Dictionary = ContactMath.resolve_vertical(cands, 220.0, 150.0)
	if not ContactMath.is_pipe(r.hit):
		push_error("hole want pipe land, got %s" % r)
		return false
	return true


func _l1_pipe_preferred() -> bool:
	# Upper pipe at base 188 vs lower pipe — prefer_h high picks upper surface.
	var low := _pipe(100.0, 0.0, 0, 300.0)
	var high := _pipe(200.0, 188.0, 0, 300.0)
	var cands := [low, high]
	var r: Dictionary = ContactMath.resolve_vertical(cands, 250.0, 195.0)
	if absf(float(r.hit.get("base_height", -1.0)) - 188.0) > 0.05:
		push_error("L1 pipe land want base 188 got %s" % r)
		return false
	if not ContactMath.should_mount_pipe(r.hit, 195.0, false, false):
		push_error("should mount L1 pipe")
		return false
	if ContactMath.should_mount_pipe(r.hit, 195.0, false, true):
		push_error("solid pad must block remount")
		return false
	# Tunnel past L1 pipe in one tick — still catch it (not only solids).
	var tun: Dictionary = ContactMath.resolve_vertical(cands, 280.0, 150.0)
	if absf(float(tun.hit.get("base_height", -1.0)) - 188.0) > 0.05:
		push_error("pipe tunnel sweep want L1 base 188 got %s" % tun)
		return false
	# Slightly below surface still in sweep eps → height_in_sweep for land guard.
	if not ContactMath.height_in_sweep(200.0, 199.5, 150.0):
		push_error("height_in_sweep should catch near-miss below pipe")
		return false
	# Already well below L1: prefer_h sampling alone would skip it — landing must
	# still treat a tracked air_over surface as solid (tested via height compare).
	var below: Dictionary = ContactMath.pick_by_prefer_h(cands, 150.0)
	if absf(float(below.get("base_height", -1.0)) - 188.0) < 0.05:
		push_error("prefer_h below L1 must not keep L1 (use tracked air_over for that)")
		return false
	return true


func _mount_and_coping_guards() -> bool:
	var under := _pipe(188.0, 0.0, 0, 300.0)
	var cross_same := {"side": 0, "lip_x": 300.0, "base_height": 0.0, "radius": 100.0}
	var cross_l1 := {"side": 0, "lip_x": 300.0, "base_height": 188.0, "radius": 100.0}
	if not ContactMath.should_coping_launch(under, cross_same):
		push_error("same pipe identity should allow coping launch")
		return false
	if ContactMath.should_coping_launch(under, cross_l1):
		push_error("different base_height must not coping-launch")
		return false
	if ContactMath.should_coping_launch(_flat(188.0), cross_same):
		push_error("solid pad underfoot must not coping-launch")
		return false
	return true


func _sample_sweep_integration() -> bool:
	var level := RampLevel.new()
	var pipe := QuarterPipe.new()
	pipe.side = QuarterPipe.PipeSide.LEFT
	pipe.lip_x = 300.0
	pipe.radius = 100.0
	pipe.base_height = 0.0
	pipe.z_min = 0.0
	pipe.z_max = 100.0
	level.pipes = [pipe]
	var spec := LevelSpec.new()
	spec.grid_w = 4
	spec.grid_h = 1
	spec.cell_w = 100.0
	spec.cell_h = 100.0
	spec.story_floor_masks = [{
		"height": 188.0,
		"mask": PackedByteArray([1, 1, 1, 1]),
		"layer": 1,
	}]
	level.spec = spec
	var r: Dictionary = level.sample_sweep(200.0, 50.0, 220.0, 150.0)
	if not ContactMath.is_solid(r.hit) or absf(float(r.height) - 188.0) > 0.05:
		push_error("sample_sweep want flat 188 got %s" % r)
		_free(level)
		return false
	_free(level)
	return true


func _air_contact_land_rules() -> bool:
	var solid := ContactMath.make_air_contact("left_pipe", 1, 200.0, true, _pipe(200.0, 188.0))
	if not ContactMath.should_land_on_air_contact(solid, 210.0, 195.0):
		push_error("should land when falling onto solid air contact")
		return false
	if not ContactMath.should_land_on_air_contact(solid, 199.0, 150.0):
		push_error("should land when already dipped below solid air contact")
		return false
	if ContactMath.should_land_on_air_contact(solid, 250.0, 220.0):
		push_error("must not land while still above solid contact")
		return false
	var hole := ContactMath.make_air_contact("hole", 1, 188.0, false, {})
	if ContactMath.should_land_on_air_contact(hole, 220.0, 150.0):
		push_error("hole must not be a land surface")
		return false
	# L0 coping at L1 floor height under a `.` — must be allowed (was rejected before).
	if not ContactMath.hole_fall_allows_floor(188.0, 188.0):
		push_error("hole fall must allow floor_h == hole_h (stacked coping)")
		return false
	if not ContactMath.hole_fall_allows_floor(100.0, 188.0):
		push_error("hole fall must allow lower floor")
		return false
	if ContactMath.hole_fall_allows_floor(200.0, 188.0):
		push_error("hole fall must reject floor above hole story")
		return false
	if ContactMath.zone_from_glyph(".") != "hole":
		push_error("glyph . want hole")
		return false
	if ContactMath.zone_from_glyph("#") != "deck":
		push_error("glyph # want deck")
		return false
	if ContactMath.zone_from_glyph("x") != "lava" or ContactMath.zone_from_glyph("X") != "lava":
		push_error("glyph x/X want lava")
		return false
	var lava := {"zone": "lava", "height": 0.0}
	if not ContactMath.is_solid(lava) or not ContactMath.is_lava(lava):
		push_error("lava must be solid + is_lava")
		return false
	if ContactMath.is_safe_pad(lava):
		push_error("lava must not be a safe pad")
		return false
	if not ContactMath.is_safe_pad({"zone": "flat"}) or not ContactMath.is_safe_pad({"zone": "deck"}):
		push_error("flat/deck must be safe pads")
		return false
	return true


func _resolve_air_contact_integration() -> bool:
	var level := RampLevel.new()
	var low := QuarterPipe.new()
	low.side = QuarterPipe.PipeSide.LEFT
	low.lip_x = 400.0
	low.radius = 100.0
	low.base_height = 0.0
	low.layer = 0
	low.z_min = 0.0
	low.z_max = 100.0
	var high := QuarterPipe.new()
	high.side = QuarterPipe.PipeSide.LEFT
	high.lip_x = 400.0
	high.radius = 100.0
	high.base_height = 188.0
	high.layer = 1
	high.z_min = 0.0
	high.z_max = 100.0
	level.pipes = [low, high]
	var spec := LevelSpec.new()
	spec.grid_w = 8
	spec.grid_h = 1
	spec.cell_w = 50.0
	spec.cell_h = 100.0
	# Cols: pipe-ish left, floor, hole. Layer glyphs for prefer_h.
	spec.layers = [
		{"index": 0, "height": 0.0, "rows": PackedStringArray(["<<<====="])},
		{"index": 1, "height": 188.0, "rows": PackedStringArray(["<<<=..=="])},
	]
	spec.story_floor_masks = [
		{"height": 0.0, "mask": PackedByteArray([0, 0, 0, 1, 1, 1, 1, 1]), "layer": 0},
		{"height": 188.0, "mask": PackedByteArray([0, 0, 0, 0, 0, 0, 1, 1]), "layer": 1},
	]
	spec.playable_mask = PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1])
	level.spec = spec

	# Sticky L1 pipe at mid bowl — prefer_h below surface still keeps sticky (no tunnel).
	var mid_x := 400.0 - 100.0 * 0.5  # into left pipe
	var sticky: Dictionary = level.resolve_air_contact(
		mid_x, 50.0, 150.0, 0, 400.0, 188.0
	)
	if str(sticky.get("zone", "")) != "left_pipe":
		push_error("sticky L1 pipe want left_pipe got %s" % sticky)
		_free(level)
		return false
	if absf(float(sticky.get("hit", {}).get("base_height", -1.0)) - 188.0) > 0.05:
		push_error("sticky L1 want base 188 got %s" % sticky)
		_free(level)
		return false
	if not ContactMath.should_land_on_air_contact(sticky, 250.0, float(sticky.height) - 10.0):
		push_error("sticky L1 must land when falling through surface")
		_free(level)
		return false

	# High above pipe column: highlight sample wins (flat), not stale sticky L0.
	# Floor mask on cols 6-7; place x on floor with L0 sticky that still covers pipe cols.
	var floor_x := 6.5 * 50.0
	# Add L0 pipe that does NOT cover floor_x so sticky inactive — and a case where
	# sticky covers but highlight prefers flat at same height.
	var over_pipe_high: Dictionary = level.resolve_air_contact(
		mid_x, 50.0, 400.0, 0, 400.0, 0.0
	)
	# At prefer_h=400, topmost underfoot should match non-sticky sample (not force L0).
	var highlight: Dictionary = level.sample(mid_x, 50.0, -1, NAN, 400.0)
	if str(over_pipe_high.get("zone", "")) != str(highlight.get("zone", "")):
		push_error(
			"high prefer_h air contact must match highlight sample: contact=%s sample=%s"
			% [over_pipe_high, highlight]
		)
		_free(level)
		return false

	# L1 hole cell (col 4-5 are '.'): x in hole column.
	var hole_x := 4.5 * 50.0
	var hole_c: Dictionary = level.resolve_air_contact(hole_x, 50.0, 220.0)
	if str(hole_c.get("zone", "")) != "hole":
		push_error("L1 hole cell want hole got %s" % hole_c)
		_free(level)
		return false
	if int(hole_c.get("layer", -1)) != 1:
		push_error("L1 hole want layer 1 got %s" % hole_c)
		_free(level)
		return false
	if ContactMath.is_air_contact_solid(hole_c):
		push_error("hole must not be solid")
		_free(level)
		return false

	# Playable cell must never resolve to zone oob (even with absurd prefer_h).
	var no_oob: Dictionary = level.resolve_air_contact(mid_x, 50.0, -9999.0)
	if str(no_oob.get("zone", "")) == "oob":
		push_error("playable pose must not resolve air contact oob: %s" % no_oob)
		_free(level)
		return false

	_free(level)

	# Shared coping high→low: highlight prefers L1 left; spine/acid force_sticky
	# must keep L0 right so lock identity is not stolen same-tick.
	if not _force_sticky_shared_coping():
		return false
	return true


func _force_sticky_shared_coping() -> bool:
	# layered_demo: L1 left coping shares X with L0 right — spine/acid lock target.
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("layered_demo parse: %s" % LevelLoader.last_error)
		return false
	var level := RampLevel.new()
	level.spec = spec
	level.pipes.clear()
	var l1_left: QuarterPipe = null
	var l0_right: QuarterPipe = null
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
		if qp.side == 0 and qp.layer == 1 and l1_left == null:
			l1_left = qp
	if l1_left != null:
		var l1_coping := PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
		for qp in level.pipes:
			if qp.side != 1 or qp.layer != 0:
				continue
			var l0_coping := PipeMath.coping_x(1, qp.lip_x, qp.radius)
			if absf(l0_coping - l1_coping) < 1.0:
				l0_right = qp
				break
	if l1_left == null or l0_right == null:
		push_error("layered_demo missing L1 left / L0 right")
		_free(level)
		return false

	var cope_x: float = PipeMath.coping_x(0, l1_left.lip_x, l1_left.radius)
	var z: float = (l1_left.z_min + l1_left.z_max) * 0.5
	var prefer_h: float = l1_left.base_height + l1_left.radius
	# Into L1 left: highlight is left_pipe; L0 right sticky is inactive (outside footprint).
	var into_left: float = cope_x + 0.5
	var plain: Dictionary = level.resolve_air_contact(
		into_left, z, prefer_h, 1, l0_right.lip_x, l0_right.base_height
	)
	if str(plain.get("zone", "")) != "left_pipe":
		push_error("into L1 left without force_sticky want left_pipe: %s" % plain)
		_free(level)
		return false
	# On shared coping both footprints active — force_sticky must keep L0 right even
	# when highlight still prefers L1 left.
	var forced: Dictionary = level.resolve_air_contact(
		cope_x, z, prefer_h, 1, l0_right.lip_x, l0_right.base_height, true
	)
	if str(forced.get("zone", "")) != "right_pipe":
		push_error("force_sticky on shared coping must keep L0 right: %s" % forced)
		_free(level)
		return false
	if absf(float(forced.get("hit", {}).get("base_height", -1.0)) - l0_right.base_height) > 0.05:
		push_error("force_sticky want L0 base got %s" % forced)
		_free(level)
		return false

	_free(level)
	return true


func _acid_spine_land_rejects() -> bool:
	var exit_pipe := _pipe(150.0, 0.0, 0, 100.0)
	var target := _pipe(150.0, 0.0, 1, 500.0)
	var deck := {"active": true, "zone": "deck", "height": 141.0}
	if not ContactMath.acid_should_reject_land(exit_pipe, true, true, 1, 500.0):
		push_error("acid must reject exit wall")
		return false
	if ContactMath.acid_should_reject_land(target, true, false, 1, 500.0):
		push_error("acid must accept locked target")
		return false
	if not ContactMath.acid_should_reject_land(exit_pipe, true, false, 1, 500.0):
		push_error("acid must reject foreign pipe")
		return false
	if not ContactMath.spine_should_reject_land(deck, true, 1, 500.0, 0.0):
		push_error("spine must reject deck")
		return false
	if ContactMath.spine_should_reject_land(target, true, 1, 500.0, 0.0):
		push_error("spine must accept target pipe")
		return false
	var wrong_story := _pipe(338.0, 188.0, 1, 500.0)
	if not ContactMath.spine_should_reject_land(wrong_story, true, 1, 500.0, 0.0):
		push_error("spine must reject mismatched story")
		return false
	if not ContactMath.spine_should_reject_land(target, true, 1, 500.0, 0.0, true, false):
		push_error("spine must defer target land while settle unaligned")
		return false
	if ContactMath.spine_should_reject_land(target, true, 1, 500.0, 0.0, true, true):
		push_error("spine must accept target when aligned")
		return false
	var lava := {"zone": "lava", "height": 0.0, "active": true}
	if ContactMath.spine_should_reject_land(lava, true, 1, 500.0, 0.0, false, true, true):
		push_error("spine must allow lava crash")
		return false
	if ContactMath.spine_should_reject_land(deck, true, 1, 500.0, 0.0, false, true, false):
		push_error("spine must allow deck crash when off target Z")
		return false
	return true


func _outward_deck_extension() -> bool:
	var cope := 100.0
	var deck := {
		"height": 141.0,
		"base_height": 0.0,
		"poly": PackedVector2Array([
			Vector2(0.0, 40.0),
			Vector2(100.0, 40.0),
			Vector2(100.0, 80.0),
			Vector2(0.0, 80.0),
		]),
		"anchors": [{
			"side": QuarterPipe.PipeSide.LEFT,
			"coping_x": cope,
			"lip_x": 241.0,
			"radius": 141.0,
		}],
	}
	var hit: Dictionary = ContactMath.outward_deck_extension(
		[deck], QuarterPipe.PipeSide.LEFT, cope, 60.0
	)
	if hit.is_empty():
		push_error("left pipe must see outward deck extension")
		return false
	if absf(ContactMath.effective_coping_floor(0.0, 141.0, hit) - 141.0) > 0.01:
		push_error("effective coping should be deck top")
		return false
	if not ContactMath.outward_deck_extension(
		[deck], QuarterPipe.PipeSide.LEFT, cope, 200.0
	).is_empty():
		push_error("z outside deck must not match")
		return false
	if not ContactMath.outward_deck_extension(
		[deck], QuarterPipe.PipeSide.RIGHT, cope, 60.0
	).is_empty():
		push_error("wrong side must not match")
		return false
	# Deck only inward of coping is not an outward extension.
	var inward := deck.duplicate(true)
	inward["poly"] = PackedVector2Array([
		Vector2(100.0, 40.0),
		Vector2(200.0, 40.0),
		Vector2(200.0, 80.0),
		Vector2(100.0, 80.0),
	])
	if not ContactMath.outward_deck_extension(
		[inward], QuarterPipe.PipeSide.LEFT, cope, 60.0
	).is_empty():
		push_error("inward-only deck must not count as extension")
		return false
	return true


func _free(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
