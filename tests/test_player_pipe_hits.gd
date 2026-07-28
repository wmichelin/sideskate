extends RefCounted
## PlayerPipeHits: ramp hit packing / radius lookup.

const _PlayerPipeHits := preload("res://scripts/player_pipe_hits.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


func run() -> bool:
	return (
		_radius_uses_hit_field()
		and _radius_looks_up_pipes()
		and _radius_filters_by_z_extent()
		and _radius_defaults_when_missing()
		and _ramp_pipe_hit_packing()
	)


func _radius_uses_hit_field() -> bool:
	var r = _PlayerPipeHits.pipe_radius_for_hit({"radius": 120.0}, [])
	if absf(r - 120.0) > 0.001:
		push_error("hit.radius must win, got %s" % r)
		return false
	return true


func _radius_looks_up_pipes() -> bool:
	var pipes := [
		_fake_pipe(1, 400.0, 100.0, 0.0, 0.0, 80.0),
		_fake_pipe(1, 400.0, 200.0, 188.0, 0.0, 80.0),
	]
	var hit := {
		"side": 1,
		"lip_x": 400.0,
		"base_height": 188.0,
		"z_min": 0.0,
		"z_max": 80.0,
	}
	var r = _PlayerPipeHits.pipe_radius_for_hit(hit, pipes)
	if absf(r - 200.0) > 0.001:
		push_error("want upper pipe radius 200, got %s" % r)
		return false
	return true


func _radius_filters_by_z_extent() -> bool:
	var pipes := [
		_fake_pipe(0, 300.0, 90.0, 0.0, 0.0, 40.0),
		_fake_pipe(0, 300.0, 110.0, 0.0, 40.0, 80.0),
	]
	var hit := {
		"side": 0,
		"lip_x": 300.0,
		"base_height": 0.0,
		"z_min": 40.0,
		"z_max": 80.0,
	}
	var r = _PlayerPipeHits.pipe_radius_for_hit(hit, pipes)
	if absf(r - 110.0) > 0.001:
		push_error("z extent must select second pipe, got %s" % r)
		return false
	return true


func _radius_defaults_when_missing() -> bool:
	var r = _PlayerPipeHits.pipe_radius_for_hit({"side": 1, "lip_x": 10.0}, [])
	if absf(r - 150.0) > 0.001:
		push_error("default radius should be 150, got %s" % r)
		return false
	return true


func _ramp_pipe_hit_packing() -> bool:
	var hit = _PlayerPipeHits.ramp_pipe_hit(0, 320.0, 12.0, 5.0, 95.0, 140.0)
	if not bool(hit.get("active", false)):
		push_error("ramp hit must be active")
		return false
	if str(hit.get("zone", "")) != _PipeMath.zone_name(0):
		push_error("zone mismatch: %s" % hit.get("zone", ""))
		return false
	if int(hit.get("side", -1)) != 0:
		push_error("side mismatch")
		return false
	if absf(float(hit.get("lip_x", 0.0)) - 320.0) > 0.001:
		push_error("lip_x mismatch")
		return false
	if absf(float(hit.get("radius", 0.0)) - 140.0) > 0.001:
		push_error("radius mismatch")
		return false
	if absf(float(hit.get("base_height", 0.0)) - 12.0) > 0.001:
		push_error("base_height mismatch")
		return false
	if absf(float(hit.get("z_min", 0.0)) - 5.0) > 0.001:
		push_error("z_min mismatch")
		return false
	if absf(float(hit.get("z_max", 0.0)) - 95.0) > 0.001:
		push_error("z_max mismatch")
		return false
	return true


func _fake_pipe(
	side: int,
	lip_x: float,
	radius: float,
	base_height: float,
	z_min: float,
	z_max: float,
) -> Dictionary:
	return {
		"side": side,
		"lip_x": lip_x,
		"radius": radius,
		"base_height": base_height,
		"z_min": z_min,
		"z_max": z_max,
	}
