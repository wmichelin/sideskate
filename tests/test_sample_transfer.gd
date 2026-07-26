extends RefCounted
## RampLevel.sample_transfer: deck → other pipe → flat priority; excludes source.


func run() -> bool:
	var text := FileAccess.get_file_as_string("res://levels/test_stagger_spine.ssk")
	if text.is_empty():
		push_error("missing stagger fixture")
		return false
	var spec := LevelLoader.parse_text(text, "test_stagger_spine")
	if spec == null:
		push_error("parse failed: %s" % LevelLoader.last_error)
		return false

	var level := RampLevel.new()
	level.apply_spec(spec)

	# Find a deck cell center and a pipe to exclude.
	if spec.decks.is_empty() or level.pipes.is_empty():
		push_error("fixture needs decks + pipes")
		_free_level(level)
		return false

	var deck: Dictionary = spec.decks[0]
	var poly: PackedVector2Array = deck.poly
	var deck_x := 0.0
	var deck_z := 0.0
	for v in poly:
		deck_x += v.x
		deck_z += v.y
	deck_x /= float(poly.size())
	deck_z /= float(poly.size())

	var exclude: QuarterPipe = level.pipes[0]
	var hit_deck: Dictionary = level.sample_transfer(
		deck_x, deck_z, int(exclude.side), exclude.lip_x
	)
	if str(hit_deck.get("zone", "")) != "deck":
		push_error("transfer over deck should prefer deck, got %s" % hit_deck.get("zone"))
		_free_level(level)
		return false

	# Mid-floor away from decks/pipes → flat (or active flat fallback)
	var floor_x := spec.spawn_x
	var floor_z := spec.spawn_z
	var hit_floor: Dictionary = level.sample_transfer(
		floor_x, floor_z, int(exclude.side), exclude.lip_x
	)
	if str(hit_floor.get("zone", "")) != "flat":
		push_error("transfer over spawn floor want flat got %s" % hit_floor.get("zone"))
		_free_level(level)
		return false

	# Probe on a different pipe than exclude → pipe zone
	var other: QuarterPipe = null
	for pipe in level.pipes:
		if pipe == exclude:
			continue
		if absf(pipe.lip_x - exclude.lip_x) < 0.05 and int(pipe.side) == int(exclude.side):
			continue
		other = pipe
		break
	if other != null:
		var mid_x := (other.x_min() + other.x_max()) * 0.5
		var mid_z := (other.z_min + other.z_max) * 0.5
		var hit_pipe: Dictionary = level.sample_transfer(
			mid_x, mid_z, int(exclude.side), exclude.lip_x
		)
		if not str(hit_pipe.get("zone", "")).ends_with("_pipe"):
			push_error("transfer on other pipe want *_pipe got %s" % hit_pipe.get("zone"))
			_free_level(level)
			return false
		# Excluding that same pipe must not return it.
		var skipped: Dictionary = level.sample_transfer(
			mid_x, mid_z, int(other.side), other.lip_x
		)
		var same_pipe := (
			str(skipped.get("zone", "")).ends_with("_pipe")
			and int(skipped.get("side", -1)) == int(other.side)
			and absf(float(skipped.get("lip_x", -999.0)) - other.lip_x) < 0.05
		)
		if same_pipe:
			push_error("sample_transfer should exclude source pipe")
			_free_level(level)
			return false

	_free_level(level)
	return true


func _free_level(level: RampLevel) -> void:
	for p in level.pipes:
		if is_instance_valid(p):
			p.free()
	level.pipes.clear()
	level.free()
