extends RefCounted
## AerialTransfer: meaningful hit, begin-air targets, acid/spine lock resolve.

const _AerialTransfer := preload("res://scripts/aerial_transfer.gd")


func run() -> bool:
	return (
		_meaningful_hit()
		and _build_targets()
		and _acid_lock()
		and _spine_gate_and_lock()
	)


func _meaningful_hit() -> bool:
	if _AerialTransfer.hit_is_meaningful({}):
		push_error("empty not meaningful")
		return false
	if not _AerialTransfer.hit_is_meaningful({"zone": "deck"}):
		push_error("deck must be meaningful")
		return false
	if not _AerialTransfer.hit_is_meaningful({
		"zone": "left_pipe", "side": 0, "lip_x": 100.0, "base_height": 0.0
	}):
		push_error("pipe must be meaningful")
		return false
	if _AerialTransfer.hit_is_meaningful({"zone": "flat", "height": 0.0}):
		push_error("flat not meaningful for locked transfer")
		return false
	return true


func _build_targets() -> bool:
	var pipe = _AerialTransfer.build_begin_air_target(
		{
			"zone": "right_pipe",
			"side": 1,
			"lip_x": 400.0,
			"base_height": 0.0,
			"radius": 100.0,
			"z_min": 0.0,
			"z_max": 100.0,
			"layer": 0,
		},
		420.0,
		100.0,
	)
	var want = PipeMath.coping_x(1, 400.0, 100.0)
	if absf(float(pipe.anchor_x) - want) > 0.01:
		push_error("pipe transfer anchor want coping, got %s" % pipe.anchor_x)
		return false
	if bool(pipe.target.lock_x):
		push_error("free transfer must stay unlocked")
		return false
	var deck = _AerialTransfer.build_begin_air_target(
		{"zone": "deck", "base_height": 141.0, "layer": 1}, 250.0, 0.0
	)
	if str(deck.target.zone) != "deck" or absf(float(deck.anchor_x) - 250.0) > 0.01:
		push_error("deck target failed: %s" % deck)
		return false
	var flat = _AerialTransfer.build_begin_air_target(
		{"zone": "flat", "height": 0.0, "layer": 0}, 250.0, 0.0
	)
	if str(flat.target.zone) != "flat":
		push_error("flat fallback failed")
		return false
	return true


func _acid_lock() -> bool:
	var hit := {
		"side": 0,
		"lip_x": 300.0,
		"radius": 100.0,
		"base_height": 0.0,
		"top_coping": PipeMath.coping_x(0, 300.0, 100.0),
		"layer": 0,
	}
	# Travel +X wants LEFT pipe ahead (outside → coping).
	var ok = _AerialTransfer.resolve_acid_lock(hit, 50.0, 80.0, 50.0)
	if not bool(ok.ok) or absf(float(ok.coping_x) - float(hit.top_coping)) > 0.01:
		push_error("acid lock opposite ahead failed: %s" % ok)
		return false
	# Wrong side for travel.
	var bad_side = _AerialTransfer.resolve_acid_lock(hit, 50.0, -80.0, 50.0)
	if bool(bad_side.ok):
		push_error("acid lock must reject wrong side")
		return false
	# Behind, not ahead (player already past coping while traveling +).
	var behind = _AerialTransfer.resolve_acid_lock(hit, 250.0, 80.0, 250.0)
	if bool(behind.ok):
		push_error("acid lock must reject behind coping")
		return false
	return true


func _spine_gate_and_lock() -> bool:
	var hit := {
		"side": 1,
		"lip_x": 400.0,
		"radius": 100.0,
		"base_height": 141.0,
		"layer": 1,
	}
	var dest_h = 141.0 + 100.0
	if _AerialTransfer.spine_feet_clear_dest(dest_h - 2.0, hit):
		push_error("spine must refuse below dest coping")
		return false
	if not _AerialTransfer.spine_feet_clear_dest(dest_h, hit):
		push_error("spine must clear at dest coping")
		return false
	var lock = _AerialTransfer.resolve_spine_lock(hit, 300.0, 180.0)
	if not bool(lock.ok) or absf(float(lock.vx) - (-180.0)) > 0.01:
		push_error("spine lock carry failed: %s" % lock)
		return false
	if str(lock.air_over) != "right_pipe":
		push_error("spine air_over wrong")
		return false
	return true
