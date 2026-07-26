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
	ok = _halfpipe_geometry() and ok
	ok = _ledge_spawn_facing() and ok
	ok = _uneven_rows_fail() and ok
	ok = _ssk1_rejected() and ok
	ok = _stagger_deck_height() and ok
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
	var want_r := 4.0 * cx
	if not is_equal_approx(left_r, want_r) or not is_equal_approx(right_r, want_r):
		push_error("halfpipe pipe radii want %s got L=%s R=%s" % [want_r, left_r, right_r])
		return false
	for p2 in spec.pipes:
		if absf(float(p2.get("base_height", -1.0))) > 0.001:
			push_error("halfpipe pipes should have base_height 0")
			return false
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
<<<<====@=>>>>
<<<<=====>>>>
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
<<<<====@=>>>>
<<<<========>>>>
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
	var want_h := 4.0 * LevelLoader.cell_size_x
	for deck in spec.decks:
		if not is_equal_approx(float(deck.height), want_h):
			push_error("stagger deck height want %s got %s" % [want_h, deck.height])
			return false
	return true


func _layered_upper_floor() -> bool:
	var r := 4.0 * LevelLoader.cell_size_x
	var text := (
		"ssk 2\nname layered_unit\n---\nlayer 0\nheight 0\n"
		+ "<<<<========>>>>\n<<<<====@===>>>>\n<<<<========>>>>\n"
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
	var r := 4.0 * LevelLoader.cell_size_x
	var text := (
		"ssk 2\nname spawn_l1\n---\nlayer 0\nheight 0\n"
		+ "<<<<========>>>>\n<<<<========>>>>\n<<<<========>>>>\n"
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
<<<<====>>>>
<<<<=@=.>>>>
<<<<====>>>>
"""
	var spec := LevelLoader.parse_text(text, "holes")
	if spec == null:
		push_error("holes parse failed: %s" % LevelLoader.last_error)
		return false
	# Center of the '.' cell should not be inside any floor poly.
	var cx := LevelLoader.cell_size_x
	var cz := LevelLoader.cell_size_z
	# Row 1, col 5 (0-based): <<<<====>>>> → cols 0-3 <, 4-7 =, 8-11 >
	# Wait map is <<<<====>>>> = 12 wide. <<<<=@=.>>>> 
	# Actually: <<<< = 4, =@=. = 4, >>>> = 4 → 12. Dot at col 7.
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
<<<<====>>>>
<<<<=@==>>>>
<<<<====>>>>
---
layer 1
height 100
<<<<====>>>>
<<<<  ==>>>>
<<<<====>>>>
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


func _free_node(n: Node) -> void:
	n.free()
