extends RefCounted
## AerialSpineClearance: soft-floor + defer-land gates.

const _Clearance := preload("res://scripts/aerial_spine_clearance.gd")


func run() -> bool:
	return (
		_solid_height()
		and _locked_target()
		and _apply_clearance()
		and _defer_land()
		and _clearance_floor()
	)


func _solid_height() -> bool:
	var solid := ContactMath.make_air_contact(
		"deck", 1, 141.0, true, {"zone": "deck", "height": 141.0}
	)
	if absf(_Clearance.underfoot_solid_height(solid) - 141.0) > 0.01:
		push_error("solid height from contact")
		return false
	var hole := ContactMath.make_air_contact("hole", 1, 141.0, false, {})
	if not is_nan(_Clearance.underfoot_solid_height(hole)):
		push_error("hole must not be solid height")
		return false
	return true


func _locked_target() -> bool:
	var hit := {
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 500.0,
		"base_height": 0.0,
	}
	if not _Clearance.is_locked_target(hit, 1, 500.0, 0.0):
		push_error("matching pipe is target")
		return false
	if _Clearance.is_locked_target(hit, 0, 500.0, 0.0):
		push_error("wrong side not target")
		return false
	if _Clearance.is_locked_target({"zone": "deck"}, 1, 500.0, 0.0):
		push_error("deck not target")
		return false
	var wrong_story := hit.duplicate()
	wrong_story["base_height"] = 141.0
	if _Clearance.is_locked_target(wrong_story, 1, 500.0, 0.0):
		push_error("wrong story not target")
		return false
	return true


func _apply_clearance() -> bool:
	var clear := _Clearance.apply_clearance(200.0, -50.0, 100.0)
	if absf(float(clear.height) - 200.0) > 0.01 or bool(clear.resting):
		push_error("above floor must leave height alone")
		return false
	var rest := _Clearance.apply_clearance(90.0, -40.0, 100.0, 0.5)
	if absf(float(rest.height) - 100.5) > 0.01:
		push_error("must lift to floor+eps: %s" % rest.height)
		return false
	if absf(float(rest.vel_y)) > 0.01 or not bool(rest.resting):
		push_error("must zero downward vel when resting")
		return false
	var rise := _Clearance.apply_clearance(90.0, 30.0, 100.0, 0.5)
	if absf(float(rise.vel_y) - 30.0) > 0.01:
		push_error("must keep upward vel when lifting")
		return false
	return true


func _defer_land() -> bool:
	if not _Clearance.should_defer_target_land(true, false):
		push_error("settle+unaligned must defer")
		return false
	if _Clearance.should_defer_target_land(false, false):
		push_error("settle done must not defer")
		return false
	if _Clearance.should_defer_target_land(true, true):
		push_error("aligned must not defer")
		return false
	return true


func _clearance_floor() -> bool:
	var hole := ContactMath.make_air_contact("hole", 1, 141.0, false, {})
	# Mid-settle over a hole: hold dest coping floor (low→high across gaps).
	var over_hole := _Clearance.clearance_floor(hole, 0, 1000.0, 141.0, 141.0, true, false)
	if absf(over_hole - 282.0) > 0.01:
		push_error("mid-settle hole must hold dest coping: %s" % over_hole)
		return false
	var deck := ContactMath.make_air_contact(
		"deck", 1, 300.0, true, {"zone": "deck", "height": 300.0}
	)
	var over_deck := _Clearance.clearance_floor(deck, 0, 1000.0, 141.0, 141.0, true, false)
	if absf(over_deck - 300.0) > 0.01:
		push_error("taller deck must raise floor: %s" % over_deck)
		return false
	var foreign_hit := {
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 500.0,
		"base_height": 0.0,
		"height": 400.0,
	}
	var foreign := ContactMath.make_air_contact("right_pipe", 0, 400.0, true, foreign_hit)
	var over_foreign := _Clearance.clearance_floor(
		foreign, 0, 1000.0, 141.0, 141.0, true, false
	)
	if absf(over_foreign - 282.0) > 0.01:
		push_error("foreign pipe must not raise floor: %s" % over_foreign)
		return false
	# Settle done + aligned over lava: no dest hold (allow land / normal fall).
	var lava := ContactMath.make_air_contact(
		"lava", 0, 0.0, true, {"zone": "lava", "height": 0.0}
	)
	var done := _Clearance.clearance_floor(lava, 0, 1000.0, 141.0, 141.0, false, true)
	if absf(done - 0.0) > 0.01:
		push_error("aligned over lava still soft-floors pad: %s" % done)
		return false
	if _Clearance.should_apply_clearance(hole, 0, 1000.0, 141.0, 141.0, false, true):
		push_error("aligned over hole must not clear")
		return false
	return true
