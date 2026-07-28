extends RefCounted
## PerspectiveMath: camera-relative homogeneous depth (shared s for X + Y).


func run() -> bool:
	var origin_x := 640.0
	var origin_z := 200.0
	var near_y := 560.0
	var far_y := 300.0
	var ref_d := 400.0
	var ref_w := 1280.0
	var inset := 70.0
	var far_g := 1.0
	var logical_x := 900.0

	var p_focus := PerspectiveMath.project(
		logical_x, origin_z, 100.0,
		origin_x, origin_z, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	var far_z := origin_z + ref_d * 0.5
	var p_far := PerspectiveMath.project(
		logical_x, far_z, 100.0,
		origin_x, origin_z, near_y, far_y, ref_d, ref_w, inset, far_g
	)

	# Focus plane: unit scale, mid-screen ground.
	if absf(float(p_focus.x_scale) - 1.0) > 0.01:
		push_error("focus plane x_scale should be 1, got %s" % p_focus.x_scale)
		return false
	var mid_y := (near_y + far_y) * 0.5
	if absf(float(p_focus.ground_y) - mid_y) > 0.5:
		push_error("focus plane ground_y should be mid-screen (%s vs %s)" % [p_focus.ground_y, mid_y])
		return false

	# Farther → converge toward origin_x and rise on screen.
	var dist_focus := absf(float(p_focus.screen_x) - origin_x)
	var dist_far := absf(float(p_far.screen_x) - origin_x)
	if dist_far >= dist_focus - 0.01:
		push_error("screen_x should converge with depth (focus=%s far=%s)" % [dist_focus, dist_far])
		return false
	if float(p_far.ground_y) >= float(p_focus.ground_y) - 0.01:
		push_error("farther Z should move up the screen")
		return false

	# Far band edge matches inset far scale and far_screen_y.
	var want_far := PerspectiveMath.far_x_scale(inset, ref_w)
	if absf(float(p_far.x_scale) - want_far) > 0.02:
		push_error("far edge x_scale want %s got %s" % [want_far, p_far.x_scale])
		return false
	if absf(float(p_far.ground_y) - far_y) > 1.0:
		push_error("far edge ground_y want %s got %s" % [far_y, p_far.ground_y])
		return false

	# Same s drives X and Y — camera truck must not shear (Δx_scale and ground_y
	# both come from s; a fixed world point scales consistently).
	var z_world := 120.0
	var cam_a := z_world + 80.0
	var cam_b := z_world - 40.0
	var a := PerspectiveMath.project(
		logical_x, z_world, 0.0,
		origin_x, cam_a, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	var b := PerspectiveMath.project(
		logical_x, z_world, 0.0,
		origin_x, cam_b, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	# Camera farther than the point → point is nearer → larger s, lower on screen.
	if float(a.x_scale) <= float(b.x_scale) + 0.0001:
		push_error("farther camera should raise depth scale at fixed Z")
		return false
	if float(a.ground_y) <= float(b.ground_y) + 0.01:
		push_error("farther camera should lower ground_y at fixed Z")
		return false
	# screen_x distance from origin scales exactly with x_scale (same s).
	var dx_a := absf(float(a.screen_x) - origin_x)
	var dx_b := absf(float(b.screen_x) - origin_x)
	var ratio_x := dx_a / maxf(dx_b, 0.0001)
	var ratio_s := float(a.x_scale) / maxf(float(b.x_scale), 0.0001)
	if absf(ratio_x - ratio_s) > 0.001:
		push_error("screen_x must track depth scale (%s vs %s)" % [ratio_x, ratio_s])
		return false

	# Linear t still available and unclamped.
	var t0 := PerspectiveMath.perspective_t(origin_z - ref_d, origin_z, ref_d)
	var t1 := PerspectiveMath.perspective_t(origin_z, origin_z, ref_d)
	if absf(t0 - (-0.5)) > 0.001 or absf(t1 - 0.5) > 0.001:
		push_error("perspective_t not linear/unclamped: %s %s" % [t0, t1])
		return false

	if not _glyph_matched_reference_depth():
		return false

	if not _air_shadow_scale():
		return false

	return true


func _glyph_matched_reference_depth() -> bool:
	var equal := PerspectiveMath.glyph_matched_reference_depth(560.0, 300.0, 47.0, 47.0)
	if absf(equal - 260.0) > 0.01:
		push_error("equal cells want reference_depth 260, got %s" % equal)
		return false
	var half := PerspectiveMath.glyph_matched_reference_depth(560.0, 300.0, 47.0, 23.5)
	if absf(half - 130.0) > 0.01:
		push_error("half cell_z want reference_depth 130, got %s" % half)
		return false
	var per_z := PerspectiveMath.screen_y_per_z(560.0, 300.0, equal)
	var px_x := 47.0
	var px_z := 47.0 * per_z
	if absf(px_z - px_x) > 0.01:
		push_error("glyph-matched depth must equalize near-plane cell px (%s vs %s)" % [px_x, px_z])
		return false
	return true


func _air_shadow_scale() -> bool:
	var min_s := 0.5
	if absf(PerspectiveMath.air_shadow_width_scale(0.0, 200.0, min_s) - 1.0) > 0.001:
		push_error("air shadow at support want scale 1")
		return false
	var mid := PerspectiveMath.air_shadow_width_scale(100.0, 200.0, min_s)
	if mid <= min_s or mid >= 1.0:
		push_error("air shadow mid height want in (min,1), got %s" % mid)
		return false
	var hi := PerspectiveMath.air_shadow_width_scale(200.0, 200.0, min_s)
	if absf(hi - min_s) > 0.001:
		push_error("air shadow at ref want min %s, got %s" % [min_s, hi])
		return false
	var above := PerspectiveMath.air_shadow_width_scale(400.0, 200.0, min_s)
	if absf(above - min_s) > 0.001:
		push_error("air shadow above ref stays at min, got %s" % above)
		return false
	var a := PerspectiveMath.air_shadow_width_scale(40.0, 200.0, min_s)
	var b := PerspectiveMath.air_shadow_width_scale(120.0, 200.0, min_s)
	if b >= a:
		push_error("air shadow must shrink as height rises (%s → %s)" % [a, b])
		return false
	return true
