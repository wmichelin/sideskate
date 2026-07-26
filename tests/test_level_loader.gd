extends RefCounted
## LevelLoader.parse_text: fixtures, spawn, pipe radii, decks, uneven rows.


func run() -> bool:
	var ok := true
	ok = _smoke_fixture("res://levels/test_halfpipe.ssk") and ok
	ok = _smoke_fixture("res://levels/test_twin_bay.ssk") and ok
	ok = _smoke_fixture("res://levels/test_stagger_spine.ssk") and ok
	ok = _smoke_fixture("res://levels/test_ledge_drop.ssk") and ok
	ok = _smoke_fixture("res://levels/test_asymm_pipes.ssk") and ok
	ok = _halfpipe_geometry() and ok
	ok = _ledge_spawn_facing() and ok
	ok = _uneven_rows_fail() and ok
	ok = _stagger_deck_height() and ok
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
		# Spawn is on floor glyph; floors should cover it.
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
	var text := _read("res://levels/test_halfpipe.ssk")
	var spec := LevelLoader.parse_text(text, "test_halfpipe")
	if spec == null:
		push_error("halfpipe parse failed: %s" % LevelLoader.last_error)
		return false
	# 22 columns × cell, 8 rows
	var cx := LevelLoader.cell_size_x
	var cz := LevelLoader.cell_size_z
	if not is_equal_approx(spec.width, 22.0 * cx):
		push_error("halfpipe width want %s got %s" % [22.0 * cx, spec.width])
		return false
	if not is_equal_approx(spec.depth, 8.0 * cz):
		push_error("halfpipe depth want %s got %s" % [8.0 * cz, spec.depth])
		return false
	# @ at col 11 (0-based), row 3 → spawn center
	var want_x := (11.0 + 0.5) * cx
	var want_z := (8.0 - 1.0 - 3.0 + 0.5) * cz
	if not is_equal_approx(spec.spawn_x, want_x) or not is_equal_approx(spec.spawn_z, want_z):
		push_error("halfpipe spawn want (%s,%s) got (%s,%s)" % [want_x, want_z, spec.spawn_x, spec.spawn_z])
		return false
	# <<<< run → radius = 4 cells
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
	return true


func _ledge_spawn_facing() -> bool:
	var text := _read("res://levels/test_ledge_drop.ssk")
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
	var text := """ssk 1
name bad_uneven
---
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


func _stagger_deck_height() -> bool:
	var text := _read("res://levels/test_stagger_spine.ssk")
	var spec := LevelLoader.parse_text(text, "test_stagger_spine")
	if spec == null:
		push_error("stagger parse failed: %s" % LevelLoader.last_error)
		return false
	if spec.decks.is_empty():
		push_error("stagger: expected decks from #")
		return false
	# Neighbor pipes are 4-wide <> runs (`<<<<` / `>>>>`) → radius 4 * cell_x
	var want_h := 4.0 * LevelLoader.cell_size_x
	for deck in spec.decks:
		if not is_equal_approx(float(deck.height), want_h):
			push_error("stagger deck height want %s got %s" % [want_h, deck.height])
			return false
	return true
