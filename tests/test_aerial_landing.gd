extends RefCounted
## AerialLanding: resolve land candidate + motion patch without a live Player.

const _AerialLanding := preload("res://scripts/aerial_landing.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")


func run() -> bool:
	return (
		_rising_refuses()
		and _direct_solid_land()
		and _solid_still_above_refuses()
		and _needs_sweep()
		and _sweep_land()
		and _hole_needs_lower()
		and _hole_lower_land()
		and _reject_spine_deck()
		and _pin_x()
		and _apply_solid_and_pipe()
	)


func _rising_refuses() -> bool:
	var r = _AerialLanding.resolve_land_hit(
		_ContactMath.make_air_contact("flat", 0, 10.0, true, {"zone": "flat", "height": 10.0}),
		20.0,
		5.0,
		40.0,
	)
	if bool(r.get("land", false)):
		push_error("rising must refuse land")
		return false
	return true


func _direct_solid_land() -> bool:
	var hit := {"zone": "flat", "active": true, "height": 100.0}
	var contact = _ContactMath.make_air_contact("flat", 0, 100.0, true, hit)
	var r = _AerialLanding.resolve_land_hit(contact, 110.0, 95.0, -40.0)
	if not bool(r.get("land", false)) or absf(float(r.floor_h) - 100.0) > 0.01:
		push_error("direct solid land failed: %s" % r)
		return false
	return true


func _solid_still_above_refuses() -> bool:
	var hit := {"zone": "flat", "active": true, "height": 100.0}
	var contact = _ContactMath.make_air_contact("flat", 0, 100.0, true, hit)
	var r = _AerialLanding.resolve_land_hit(contact, 130.0, 120.0, -40.0)
	if bool(r.get("land", false)) or bool(r.get("need_sweep", false)):
		push_error("still above solid must refuse without sweep: %s" % r)
		return false
	return true


func _needs_sweep() -> bool:
	var contact = _ContactMath.make_air_contact("hole", 1, 188.0, false, {})
	var r = _AerialLanding.resolve_land_hit(contact, 200.0, 150.0, -40.0)
	if not bool(r.get("need_sweep", false)):
		push_error("hole fall must request sweep")
		return false
	return true


func _sweep_land() -> bool:
	var contact = _ContactMath.make_air_contact("hole", 1, 188.0, false, {})
	var pipe := {
		"zone": "right_pipe",
		"active": true,
		"side": 1,
		"lip_x": 400.0,
		"base_height": 0.0,
		"height": 150.0,
	}
	var sweep := {"hit": pipe, "height": 150.0, "crossed_solid": true}
	var r = _AerialLanding.resolve_land_hit(contact, 200.0, 140.0, -40.0, sweep)
	if not bool(r.get("land", false)) or absf(float(r.floor_h) - 150.0) > 0.01:
		push_error("sweep land failed: %s" % r)
		return false
	return true


func _hole_needs_lower() -> bool:
	var contact = _ContactMath.make_air_contact("hole", 1, 100.0, false, {})
	var high := {
		"zone": "deck",
		"active": true,
		"height": 140.0,
	}
	var sweep := {"hit": high, "height": 140.0, "crossed_solid": true}
	var r = _AerialLanding.resolve_land_hit(contact, 160.0, 90.0, -40.0, sweep)
	if not bool(r.get("need_hole_lower", false)) or absf(float(r.hole_h) - 100.0) > 0.01:
		push_error("above-hole surface must request lower sample: %s" % r)
		return false
	return true


func _hole_lower_land() -> bool:
	var contact = _ContactMath.make_air_contact("hole", 1, 100.0, false, {})
	var high := {"zone": "deck", "active": true, "height": 140.0}
	var lower := {
		"zone": "flat",
		"active": true,
		"height": 0.0,
	}
	var sweep := {"hit": high, "height": 140.0, "crossed_solid": true}
	var r = _AerialLanding.resolve_land_hit(contact, 160.0, -5.0, -40.0, sweep, lower)
	if not bool(r.get("land", false)) or absf(float(r.floor_h) - 0.0) > 0.01:
		push_error("hole lower land failed: %s" % r)
		return false
	return true


func _reject_spine_deck() -> bool:
	var deck := {"zone": "deck", "active": true, "height": 141.0}
	if not _AerialLanding.should_reject_land(deck, false, false, 1, 400.0, true, 0.0):
		push_error("spine must reject deck")
		return false
	var pipe := {
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 400.0,
		"base_height": 0.0,
		"height": 150.0,
	}
	if _AerialLanding.should_reject_land(pipe, false, false, 1, 400.0, true, 0.0):
		push_error("spine must accept target pipe")
		return false
	return true


func _pin_x() -> bool:
	var pinned = _AerialLanding.land_pin_x(502.0, true, 500.0, 100.0)
	if absf(pinned - 500.0) > 0.01:
		push_error("aligned lock must pin coping, got %s" % pinned)
		return false
	var keep = _AerialLanding.land_pin_x(560.0, true, 500.0, 100.0)
	if absf(keep - 560.0) > 0.01:
		push_error("far from coping must keep x, got %s" % keep)
		return false
	return true


func _apply_solid_and_pipe() -> bool:
	var solid = _AerialLanding.compute_land_apply(
		{"zone": "flat", "height": 10.0},
		10.0,
		100.0,
		100.0,
		-80.0,
		-50.0,
		false,
		false,
		0.0,
		true,
		false,
		1.0,
		0.0,
	)
	if str(solid.kind) != "solid" or absf(float(solid.vx)) > 0.01:
		push_error("fly-out solid must clamp reverse, got %s" % solid)
		return false
	var pipe_hit := {
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 400.0,
		"base_height": 0.0,
		"height": 150.0,
		"z_min": 0.0,
		"z_max": 100.0,
	}
	var pipe = _AerialLanding.compute_land_apply(
		pipe_hit,
		150.0,
		400.0,
		420.0,
		40.0,
		-60.0,
		true,
		false,
		0.0,
		false,
		false,
		0.0,
		180.0,
	)
	if str(pipe.kind) != "pipe" or absf(float(pipe.ramp_along) - (-180.0)) > 0.01:
		push_error("classic pipe land want carry -180, got %s" % pipe)
		return false
	if not bool(pipe.move_along):
		push_error("pipe land with |along|>1 must move_along")
		return false
	return true
