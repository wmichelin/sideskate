extends RefCounted
## AerialSpineClearance: corridor + soft-floor + defer-land gates.

const _Clearance := preload("res://scripts/aerial_spine_clearance.gd")


func run() -> bool:
	return (
		_solid_height()
		and _locked_target()
		and _corridor_sample()
		and _corridor_build_and_floor()
		and _feet_clear_peak()
		and _apply_clearance()
		and _defer_land()
		and _clearance_floor_hold()
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
	return true


func _corridor_sample() -> bool:
	var deck := ContactMath.make_air_contact(
		"deck", 1, 200.0, true, {"zone": "deck", "height": 200.0}
	)
	var dh := _Clearance.corridor_sample_height(deck, 0, 1000.0, 141.0)
	if absf(dh - 200.0) > 0.01:
		push_error("deck must raise corridor sample")
		return false
	var foreign := ContactMath.make_air_contact(
		"right_pipe",
		0,
		400.0,
		true,
		{"zone": "right_pipe", "side": 1, "lip_x": 500.0, "base_height": 0.0, "height": 400.0},
	)
	if not is_nan(_Clearance.corridor_sample_height(foreign, 0, 1000.0, 141.0)):
		push_error("foreign pipe must not contribute to corridor")
		return false
	var target := ContactMath.make_air_contact(
		"left_pipe",
		1,
		250.0,
		true,
		{"zone": "left_pipe", "side": 0, "lip_x": 1000.0, "base_height": 141.0, "height": 250.0},
	)
	var th := _Clearance.corridor_sample_height(target, 0, 1000.0, 141.0)
	if absf(th - 250.0) > 0.01:
		push_error("locked target arc must contribute")
		return false
	return true


func _corridor_build_and_floor() -> bool:
	var xs := PackedFloat32Array([0.0, 50.0, 100.0])
	var hs := PackedFloat32Array([141.0, 200.0, 282.0])
	var c := _Clearance.corridor_from_heights(xs, hs, 282.0)
	if absf(float(c.peak) - 282.0) > 0.01:
		push_error("peak should be dest when dest tallest: %s" % c.peak)
		return false
	var c2 := _Clearance.corridor_from_heights(
		xs, PackedFloat32Array([141.0, 300.0, 282.0]), 282.0
	)
	if absf(float(c2.peak) - 300.0) > 0.01:
		push_error("deck above dest must raise peak: %s" % c2.peak)
		return false
	var mid := _Clearance.floor_at_x(c2, 50.0)
	if absf(mid - 300.0) > 0.01:
		push_error("floor_at_x mid: %s" % mid)
		return false
	var built := _Clearance.build_corridor(
		0.0,
		100.0,
		0,
		1000.0,
		141.0,
		141.0,
		Callable(self, "_sample_deck_then_hole"),
		5,
	)
	if float(built.peak) < 281.0:
		push_error("built corridor peak must include dest: %s" % built.peak)
		return false
	if float(built.peak) < 199.0:
		push_error("built corridor peak must include deck: %s" % built.peak)
		return false
	return true


func _sample_deck_then_hole(x: float) -> Dictionary:
	if x < 40.0:
		return ContactMath.make_air_contact(
			"deck", 1, 200.0, true, {"zone": "deck", "height": 200.0}
		)
	return ContactMath.make_air_contact("hole", 1, 141.0, false, {})


func _feet_clear_peak() -> bool:
	if _Clearance.feet_clear_corridor(280.0, 282.0):
		push_error("must refuse below peak")
		return false
	if not _Clearance.feet_clear_corridor(282.0, 282.0):
		push_error("must clear at peak")
		return false
	return true


func _apply_clearance() -> bool:
	var clear := _Clearance.apply_clearance(200.0, -50.0, 100.0)
	if absf(float(clear.height) - 200.0) > 0.01:
		push_error("above floor must leave height alone")
		return false
	if absf(float(clear.vel_y) + 50.0) > 0.01:
		push_error("well above floor must keep gravity (vel_y)")
		return false
	var near := _Clearance.apply_clearance(100.7, -50.0, 100.0, 0.5)
	if absf(float(near.vel_y)) > 0.01:
		push_error("near soft-floor must kill downward vel")
		return false
	var rest := _Clearance.apply_clearance(90.0, -40.0, 100.0, 0.5)
	if absf(float(rest.height) - 100.5) > 0.01:
		push_error("must lift to floor+eps: %s" % rest.height)
		return false
	return true


func _defer_land() -> bool:
	if not _Clearance.should_defer_target_land(true, false):
		push_error("settle+unaligned must defer")
		return false
	if _Clearance.should_defer_target_land(false, false):
		push_error("settle done must not defer")
		return false
	return true


func _clearance_floor_hold() -> bool:
	var hole := ContactMath.make_air_contact("hole", 1, 141.0, false, {})
	var xs := PackedFloat32Array([0.0, 100.0])
	var hs := PackedFloat32Array([200.0, 282.0])
	var corr := _Clearance.corridor_from_heights(xs, hs, 282.0)
	var mid := _Clearance.clearance_floor(
		hole, 0, 1000.0, 141.0, 141.0, true, false, corr, 50.0
	)
	# floor_at_x maxes with dest_floor (282)
	if absf(mid - 282.0) > 0.01:
		push_error("corridor+dest floor mid: %s" % mid)
		return false
	var tall := _Clearance.corridor_from_heights(
		PackedFloat32Array([0.0, 100.0]),
		PackedFloat32Array([300.0, 300.0]),
		282.0,
	)
	var tall_mid := _Clearance.clearance_floor(
		hole, 0, 1000.0, 141.0, 141.0, true, false, tall, 50.0
	)
	if absf(tall_mid - 300.0) > 0.01:
		push_error("taller corridor must win: %s" % tall_mid)
		return false
	var done := _Clearance.clearance_floor(
		hole, 0, 1000.0, 141.0, 141.0, false, true, corr, 50.0
	)
	if not is_nan(done):
		push_error("settle-done+aligned must release: %s" % done)
		return false
	return true
