extends RefCounted
## LevelLoader.parse_text: fixtures, spawn, pipe radii, decks, uneven rows, layers.


func run() -> bool:
	var ok := true
	ok = _smoke_fixture("res://tests/levels/test_halfpipe.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/test_twin_bay.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/test_stagger_spine.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/test_ledge_drop.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/test_asymm_pipes.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/layered_demo.ssk") and ok
	ok = _smoke_fixture("res://tests/levels/test_lava.ssk") and ok
	ok = _lava_glyph_samples() and ok
	ok = _halfpipe_geometry() and ok
	ok = _pipe_radius_scales_with_glyphs() and ok
	ok = _ramp_radius_and_deck_from_neighbors() and ok
	ok = _pipe_screen_quarter_circle() and ok
	ok = _ledge_spawn_facing() and ok
	ok = _uneven_rows_fail() and ok
	ok = _ssk1_rejected() and ok
	ok = _stagger_deck_height() and ok
	ok = _z_band_deck_heights() and ok
	ok = _z_band_lr_conflict_fails() and ok
	ok = _deck_height_override_no_z_split() and ok
	ok = _layered_upper_floor() and ok
	ok = _spawn_on_upper_layer() and ok
	ok = _dot_is_hole_not_floor() and ok
	ok = _upper_space_in_footprint_fails() and ok
	ok = _clamp_to_playable() and ok
	ok = _deck_edge_never_oob() and ok
	return ok


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open %s" % path)
		return ""
	var t := f.get_as_text()
	f.close()
	return t


func _smoke_fixture(path: String) -> bool:
	var text := _read(path)
	if text.is_empty():
		return false
	var spec := LevelLoader.parse_text(text, path.get_file().get_basename(), path)
	if spec == null:
		push_error("parse_text failed for %s: %s" % [path, LevelLoader.last_error])
		return false
	if spec.pipes.is_empty():
		push_error("%s: expected pipes" % path)
		return false
	if not spec.contains_playable(spec.spawn_x, spec.spawn_z):
		var on_floor := false
		for region in spec.floors:
			if LevelSpec.point_in_poly(Vector2(spec.spawn_x, spec.spawn_z), region.poly):
				on_floor = true
				break
		if not on_floor:
			push_error("%s: spawn not on a floor poly" % path)
			return false
	return true


func _halfpipe_geometry() -> bool:
	var text := _read("res://tests/levels/test_halfpipe.ssk")
	var spec := LevelLoader.parse_text(text, "test_halfpipe")
	if spec == null:
		push_error("halfpipe parse failed: %s" % LevelLoader.last_error)
		return false
	var cx := LevelLoader.cell_size_x
	var cz := LevelLoader.cell_size_z
	if not is_equal_approx(spec.width, 22.0 * cx):
		push_error("halfpipe width want %s got %s" % [22.0 * cx, spec.width])
		return false
	if not is_equal_approx(spec.depth, 8.0 * cz):
		push_error("halfpipe depth want %s got %s" % [8.0 * cz, spec.depth])
		return false
	var want_x := (11.0 + 0.5) * cx
	var want_z := (8.0 - 1.0 - 3.0 + 0.5) * cz
	if not is_equal_approx(spec.spawn_x, want_x) or not is_equal_approx(spec.spawn_z, want_z):
		push_error("halfpipe spawn want (%s,%s) got (%s,%s)" % [want_x, want_z, spec.spawn_x, spec.spawn_z])
		return false
	var left_r := -1.0
	var right_r := -1.0
	for p in spec.pipes:
		if p.side == QuarterPipe.PipeSide.LEFT:
			left_r = float(p.radius)
		elif p.side == QuarterPipe.PipeSide.RIGHT:
			right_r = float(p.radius)
	var want_r := 3.0 * cx
	if not is_equal_approx(left_r, want_r) or not is_equal_approx(right_r, want_r):
		push_error("halfpipe pipe radii want %s got L=%s R=%s" % [want_r, left_r, right_r])
		return false
	for p2 in spec.pipes:
		if absf(float(p2.get("base_height", -1.0))) > 0.001:
			push_error("halfpipe pipes should have base_height 0")
			return false
	return true


## `(` → 1×cell radius; `((((` → 4×cell (height rise = radius for a quarter circle).
func _pipe_radius_scales_with_glyphs() -> bool:
	var text := """ssk 2
name glyph_radius
---
layer 0
height 0
((((====================))))
((((=========@==========))))
((((====================))))
"""
	var spec := LevelLoader.parse_text(text, "glyph_radius")
	if spec == null:
		push_error("glyph_radius parse failed: %s" % LevelLoader.last_error)
		return false
	var cx := LevelLoader.cell_size_x
	var left_r := -1.0
	var right_r := -1.0
	for p in spec.pipes:
		if int(p.side) == QuarterPipe.PipeSide.LEFT:
			left_r = float(p.radius)
		else:
			right_r = float(p.radius)
	var want := 4.0 * cx
	if not is_equal_approx(left_r, want) or not is_equal_approx(right_r, want):
		push_error("(((( radius want %s got L=%s R=%s" % [want, left_r, right_r])
		return false
	var one := """ssk 2
name one_glyph
---
layer 0
height 0
(========================)
(===========@============)
(========================)
"""
	var spec1 := LevelLoader.parse_text(one, "one_glyph")
	if spec1 == null:
		push_error("one_glyph parse failed: %s" % LevelLoader.last_error)
		return false
	var r1 := -1.0
	for p1 in spec1.pipes:
		if int(p1.side) == QuarterPipe.PipeSide.LEFT:
			r1 = float(p1.radius)
			break
	if r1 < 0.0:
		r1 = float(spec1.pipes[0].radius)
	if not is_equal_approx(r1, cx):
		push_error("( radius want %s got %s" % [cx, r1])
		return false
	if not is_equal_approx(left_r, 4.0 * r1):
		push_error("(((( should be 4× ( radius (%s vs %s)" % [left_r, r1])
		return false
	return true


## `<`/`>` ramps share pipe footprint radius; decks abutting ramps rise to peak.
func _ramp_radius_and_deck_from_neighbors() -> bool:
	var text := """ssk 2
name ramp_glyphs
---
layer 0
height 0
>>>###<<<
>>>#@#<<<
>>>###<<<
"""
	var spec := LevelLoader.parse_text(text, "ramp_glyphs")
	if spec == null:
		push_error("ramp_glyphs parse failed: %s" % LevelLoader.last_error)
		return false
	var cx := LevelLoader.cell_size_x
	var ramp_n := 0
	var pipe_n := 0
	var right_r := -1.0
	var right_rise := -1.0
	for p in spec.pipes:
		if str(p.get("kind", "pipe")) == "ramp":
			ramp_n += 1
			if int(p.side) == QuarterPipe.PipeSide.RIGHT:
				right_r = float(p.radius)
				right_rise = float(p.get("rise", p.radius))
		else:
			pipe_n += 1
	if ramp_n < 2 or pipe_n != 0:
		push_error("ramp_glyphs: expected ≥2 ramps and 0 pipes, got ramp=%d pipe=%d" % [
			ramp_n, pipe_n
		])
		return false
	var want := 3.0 * cx
	var want_rise := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	if not is_equal_approx(right_r, want):
		push_error(">>> radius want %s got %s" % [want, right_r])
		return false
	if not is_equal_approx(right_rise, want_rise):
		push_error(">>> rise want %s got %s" % [want_rise, right_rise])
		return false
	if spec.decks.is_empty():
		push_error("ramp_glyphs: expected deck from #")
		return false
	var deck_h := float(spec.decks[0].get("height", -1.0))
	if not is_equal_approx(deck_h, right_rise):
		push_error("deck height want ramp peak %s got %s" % [right_rise, deck_h])
		return false
	# Mixed ramp–deck–pipe composition.
	var mixed := """ssk 2
name ramp_pipe_deck
---
layer 0
height 0
>>>===(====
>>>==@=(===
>>>===(====
"""
	var spec2 := LevelLoader.parse_text(mixed, "ramp_pipe_deck")
	if spec2 == null:
		push_error("ramp_pipe_deck parse failed: %s" % LevelLoader.last_error)
		return false
	var kinds := {}
	for p2 in spec2.pipes:
		kinds[str(p2.get("kind", "pipe"))] = true
	if not kinds.has("ramp") or not kinds.has("pipe"):
		push_error("ramp_pipe_deck: need both kinds, got %s" % kinds)
		return false
	return true


## Drawn profile is a true quarter circle from glyph width; deck meets that coping.
func _pipe_screen_quarter_circle() -> bool:
	var level := RampLevel.new()
	level.perspective_origin_x = 640.0
	level.perspective_origin_z = 200.0
	level.z_min = 0.0
	level.near_screen_y = 560.0
	level.far_screen_y = 300.0
	level.reference_depth = 400.0
	level.reference_width = 1280.0
	level.perspective_inset = 70.0
	level.far_geometry_scale = 1.0
	var pipe := QuarterPipe.new()
	pipe.side = QuarterPipe.PipeSide.RIGHT
	pipe.lip_x = 400.0
	pipe.radius = 141.0
	pipe.base_height = 0.0
	pipe.z_min = 0.0
	pipe.z_max = 100.0
	var z := 180.0
	var lip: Vector2 = level.pipe_screen_point_for(pipe, z, 0.0)
	var mid: Vector2 = level.pipe_screen_point_for(pipe, z, 0.5)
	var cope: Vector2 = level.pipe_screen_point_for(pipe, z, 1.0)
	var cope_x_p: Dictionary = level.project(pipe.lip_x + pipe.radius, z, 0.0)
	var r := absf(float(cope_x_p.screen_x) - lip.x)
	var center := Vector2(lip.x, lip.y - r)
	var d0 := lip.distance_to(center)
	var d1 := mid.distance_to(center)
	var d2 := cope.distance_to(center)
	if absf(d0 - r) > 0.05 or absf(d1 - r) > 0.05 or absf(d2 - r) > 0.05:
		push_error("pipe screen points not on circle r=%s d=%s,%s,%s" % [r, d0, d1, d2])
		pipe.free()
		level.free()
		return false
	# Coping X matches projected glyph span; Y is lip.y - r (deck must meet this).
	if absf(cope.x - float(cope_x_p.screen_x)) > 0.05:
		push_error("coping X want %s got %s" % [cope_x_p.screen_x, cope.x])
		pipe.free()
		level.free()
		return false
	if absf(cope.y - (lip.y - r)) > 0.05:
		push_error("coping Y want %s got %s" % [lip.y - r, cope.y])
		pipe.free()
		level.free()
		return false
	# Deck visual height meets pipe coping.
	var deck := {
		"height": pipe.radius,
		"base_height": 0.0,
		"anchors": [{
			"lip_x": pipe.lip_x,
			"coping_x": pipe.lip_x + pipe.radius,
			"radius": pipe.radius,
			"side": pipe.side,
		}],
	}
	var deck_p: Dictionary = level.project_deck_point(deck, pipe.lip_x + pipe.radius * 0.5, z)
	var deck_y := float(deck_p.ground_y) - float(deck_p.surface_screen_h)
	if absf(deck_y - cope.y) > 0.05:
		push_error("deck Y should meet pipe coping %s got %s" % [cope.y, deck_y])
		pipe.free()
		level.free()
		return false
	var lip_off := lip - center
	var cope_off := cope - center
	if absf(lip_off.x) > 0.05 or lip_off.y < 0.0:
		push_error("lip should be directly below center, got off=%s" % lip_off)
		pipe.free()
		level.free()
		return false
	if absf(cope_off.y) > 0.05 or cope_off.x < 0.0:
		push_error("coping should be directly right of center, got off=%s" % cope_off)
		pipe.free()
		level.free()
		return false
	pipe.free()
	level.free()
	return true


func _ledge_spawn_facing() -> bool:
	var text := _read("res://tests/levels/test_ledge_drop.ssk")
	var spec := LevelLoader.parse_text(text, "test_ledge_drop")
	if spec == null:
		push_error("ledge parse failed: %s" % LevelLoader.last_error)
		return false
	if spec.spawn_facing != "l":
		push_error("ledge spawn_facing want l got %s" % spec.spawn_facing)
		return false
	if spec.decks.is_empty():
		push_error("ledge should have deck ledge")
		return false
	return true


func _uneven_rows_fail() -> bool:
	var text := """ssk 2
name bad_uneven
---
layer 0
height 0
(((=====@==)))
(((=======)))
"""
	var spec := LevelLoader.parse_text(text, "bad_uneven")
	if spec != null:
		push_error("uneven rows should fail parse")
		return false
	var err := LevelLoader.last_error
	if err.find("width") < 0:
		push_error("uneven-row error should mention width: %s" % err)
		return false
	return true


func _ssk1_rejected() -> bool:
	var text := """ssk 1
name old
---
(((=====@==)))
(((==========)))
"""
	var spec := LevelLoader.parse_text(text, "old")
	if spec != null:
		push_error("ssk 1 should be rejected")
		return false
	if LevelLoader.last_error.find("ssk 2") < 0:
		push_error("ssk1 reject should mention ssk 2: %s" % LevelLoader.last_error)
		return false
	return true


func _stagger_deck_height() -> bool:
	var text := _read("res://tests/levels/test_stagger_spine.ssk")
	var spec := LevelLoader.parse_text(text, "test_stagger_spine")
	if spec == null:
		push_error("stagger parse failed: %s" % LevelLoader.last_error)
		return false
	if spec.decks.is_empty():
		push_error("stagger: expected decks from #")
		return false
	var want_h := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	for deck in spec.decks:
		if not is_equal_approx(float(deck.height), want_h):
			push_error("stagger deck height want %s got %s" % [want_h, deck.height])
			return false
	return true


func _z_band_deck_heights() -> bool:
	var text := _read("res://tests/levels/sim/sim_z_band_deck.ssk")
	var spec := LevelLoader.parse_text(text, "sim_z_band_deck")
	if spec == null:
		push_error("z_band parse failed: %s" % LevelLoader.last_error)
		return false
	var short_h := 1.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var tall_h := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var saw_short := false
	var saw_tall := false
	for deck in spec.decks:
		var h := float(deck.height)
		if is_equal_approx(h, short_h):
			saw_short = true
		elif is_equal_approx(h, tall_h):
			saw_tall = true
		else:
			push_error("z_band: unexpected deck height %s (want %s or %s)" % [h, short_h, tall_h])
			return false
	if not saw_short or not saw_tall:
		push_error("z_band: need both short=%s and tall=%s decks (got %s)" % [
			short_h, tall_h, spec.decks.size()
		])
		return false
	# Equal-rise continuous `#` stays one patch (no spurious Z split).
	var spine := _read("res://tests/levels/sim/sim_spine_deck_solid.ssk")
	var spine_spec := LevelLoader.parse_text(spine, "sim_spine_deck_solid")
	if spine_spec == null:
		push_error("z_band equal spine parse failed: %s" % LevelLoader.last_error)
		return false
	var spine_h := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var deck_n := 0
	for deck in spine_spec.decks:
		deck_n += 1
		if not is_equal_approx(float(deck.height), spine_h):
			push_error("equal-rise spine deck height want %s got %s" % [spine_h, deck.height])
			return false
	if deck_n != 1:
		push_error("equal-rise spine want 1 deck patch, got %s" % deck_n)
		return false
	return true


func _z_band_lr_conflict_fails() -> bool:
	var text := (
		"ssk 2\nname lr_conflict\n---\nlayer 0\nheight 0\n"
		+ "===)))##(====\n===)))##(====\n===)))##(@===\n"
	)
	var spec := LevelLoader.parse_text(text, "lr_conflict")
	if spec != null:
		push_error("lr_conflict: expected parse failure for unequal L/R rises")
		return false
	var err := LevelLoader.last_error
	if err.find("unequal") < 0 and err.find("abutting") < 0:
		push_error("lr_conflict: error should mention unequal abutting rises, got: %s" % err)
		return false
	return true


func _deck_height_override_no_z_split() -> bool:
	var text := (
		"ssk 2\nname deck_override\ndeck_height 80\n---\nlayer 0\nheight 0\n"
		+ "===)##(====\n===)##(====\n=)))##(((==\n=)))##(((@=\n"
	)
	var spec := LevelLoader.parse_text(text, "deck_override")
	if spec == null:
		push_error("deck_override parse failed: %s" % LevelLoader.last_error)
		return false
	if spec.decks.size() != 1:
		push_error("deck_height override should keep one deck, got %s" % spec.decks.size())
		return false
	if not is_equal_approx(float(spec.decks[0].height), 80.0):
		push_error("deck_override height want 80 got %s" % spec.decks[0].height)
		return false
	return true


func _layered_upper_floor() -> bool:
	var r := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var text := (
		"ssk 2\nname layered_unit\n---\nlayer 0\nheight 0\n"
		+ "(((==========)))\n(((=====@====)))\n(((==========)))\n"
		+ "---\nlayer 1\nheight %s\n" % r
		+ "....========....\n....========....\n....========....\n"
	)
	var spec := LevelLoader.parse_text(text, "layered_unit")
	if spec == null:
		push_error("layered parse failed: %s" % LevelLoader.last_error)
		return false
	var upper := 0
	for floor in spec.floors:
		if is_equal_approx(float(floor.height), r):
			upper += 1
	if upper < 1:
		push_error("expected upper floor at height %s" % r)
		return false
	if spec.layers.size() != 2:
		push_error("expected 2 layers got %s" % spec.layers.size())
		return false
	return true


func _spawn_on_upper_layer() -> bool:
	var r := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var text := (
		"ssk 2\nname spawn_l1\n---\nlayer 0\nheight 0\n"
		+ "(((==========)))\n(((==========)))\n(((==========)))\n"
		+ "---\nlayer 1\nheight %s\n" % r
		+ "....========....\n....===@====....\n....========....\n"
	)
	var spec := LevelLoader.parse_text(text, "spawn_l1")
	if spec == null:
		push_error("spawn_l1 parse failed: %s" % LevelLoader.last_error)
		return false
	if not is_equal_approx(spec.spawn_height, r):
		push_error("spawn_height want %s got %s" % [r, spec.spawn_height])
		return false
	if spec.spawn_layer != 1:
		push_error("spawn_layer want 1 got %s" % spec.spawn_layer)
		return false
	return true


func _dot_is_hole_not_floor() -> bool:
	var text := """ssk 2
name holes
---
layer 0
height 0
(((======)))
(((=@=...)))
(((======)))
"""
	var spec := LevelLoader.parse_text(text, "holes")
	if spec == null:
		push_error("holes parse failed: %s" % LevelLoader.last_error)
		return false
	# Center of a '.' cell should not be inside any floor poly.
	# Map: ((( = 3, =@=... = 6, ))) = 3 → 12. Holes at cols 6-8 (against right pipe).
	var cx := LevelLoader.cell_size_x
	var cz := LevelLoader.cell_size_z
	var dot_x := (7.0 + 0.5) * cx
	var dot_z := (3.0 - 1.0 - 1.0 + 0.5) * cz  # H=3, row 1
	for floor in spec.floors:
		if LevelSpec.point_in_poly(Vector2(dot_x, dot_z), floor.poly):
			push_error(". cell should not be floor")
			return false
	if not spec.is_playable_xz(dot_x, dot_z):
		push_error(". cell should still be playable (not OOB)")
		return false
	return true


func _upper_space_in_footprint_fails() -> bool:
	var text := """ssk 2
name bad_space
---
layer 0
height 0
(((======)))
(((==@===)))
(((======)))
---
layer 1
height 100
(((======)))
(((=  ===)))
(((======)))
"""
	var spec := LevelLoader.parse_text(text, "bad_space")
	if spec != null:
		push_error("space inside footprint on upper layer should fail")
		return false
	if LevelLoader.last_error.find("space") < 0 and LevelLoader.last_error.find(".") < 0:
		push_error("expected footprint space error: %s" % LevelLoader.last_error)
		return false
	return true


func _clamp_to_playable() -> bool:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("clamp fixture load failed: %s" % LevelLoader.last_error)
		return false
	var out := spec.clamp_to_playable(-50.0, spec.spawn_z)
	if not spec.is_playable_xz(out.x, out.y):
		push_error("clamp_to_playable must land in playable, got %s" % out)
		return false
	if out.x < -0.01:
		push_error("clamp must not leave x negative, got %s" % out.x)
		return false
	var mid := spec.clamp_to_playable(spec.spawn_x, spec.spawn_z)
	if absf(mid.x - spec.spawn_x) > 0.05 or absf(mid.y - spec.spawn_z) > 0.05:
		push_error("clamp should preserve playable pose")
		return false
	return true


## Left edge of a `#` deck cell must sample as deck, never grounded oob.
func _deck_edge_never_oob() -> bool:
	var text := _read("res://tests/levels/test_ledge_drop.ssk")
	var spec := LevelLoader.parse_text(text, "test_ledge_drop")
	if spec == null:
		push_error("ledge parse failed: %s" % LevelLoader.last_error)
		return false
	var level := RampLevel.new()
	level.spec = spec
	level.pipes.clear()
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		qp.layer = int(pd.get("layer", 0))
		level.pipes.append(qp)
	# Far-left of map = deck `#` columns. Sample near x=0 edge.
	var z := spec.spawn_z
	var hit: Dictionary = level.sample(0.01, z)
	var zone := str(hit.get("zone", ""))
	if zone == "oob":
		push_error("deck edge must not sample oob, got %s" % hit)
		_free_node(level)
		return false
	if zone != "deck" and not hit.get("active", false):
		push_error("deck edge want active deck, got %s" % hit)
		_free_node(level)
		return false
	var outside: Dictionary = level.sample(-20.0, z)
	if str(outside.get("zone", "")) == "oob":
		push_error("outside footprint must not report oob (hole/fallback), got %s" % outside)
		_free_node(level)
		return false
	_free_node(level)
	return true


func _lava_glyph_samples() -> bool:
	var text := _read("res://tests/levels/test_lava.ssk")
	var spec := LevelLoader.parse_text(text, "test_lava")
	if spec == null:
		push_error("lava parse failed: %s" % LevelLoader.last_error)
		return false
	var level := RampLevel.new()
	level.spec = spec
	level.pipes.clear()
	for pd in spec.pipes:
		var qp := QuarterPipe.new()
		qp.side = int(pd.side)
		qp.lip_x = float(pd.lip_x)
		qp.radius = float(pd.radius)
		qp.base_height = float(pd.get("base_height", 0.0))
		qp.z_min = float(pd.z_min)
		qp.z_max = float(pd.z_max)
		qp.layer = int(pd.get("layer", 0))
		level.pipes.append(qp)
	# Row with xxxx: grid row 1 (0-based from top). Cell centers.
	var cw := spec.cell_w
	var ch := spec.cell_h
	var lava_c := 6  # first x in (((===xxxx===)))
	var lava_r := 1
	var lx := (float(lava_c) + 0.5) * cw
	var lz := (float(spec.grid_h - 1 - lava_r) + 0.5) * ch
	var hit: Dictionary = level.sample(lx, lz)
	if str(hit.get("zone", "")) != "lava":
		push_error("lava cell want zone lava, got %s" % hit)
		_free_node(level)
		return false
	if not hit.get("active", false):
		push_error("lava cell should be active solid")
		_free_node(level)
		return false
	var flat: Dictionary = level.sample(spec.spawn_x, spec.spawn_z)
	if str(flat.get("zone", "")) != "flat":
		push_error("spawn want flat, got %s" % flat)
		_free_node(level)
		return false
	_free_node(level)
	return true


func _free_node(n: Node) -> void:
	n.free()
