extends RefCounted
## PerspectiveMath / project invariants: converge X, linear unclamped t, clamped gscale.


func run() -> bool:
	var origin_x := 640.0
	var origin_z := 200.0
	var z_min := 0.0
	var near_y := 560.0
	var far_y := 300.0
	var ref_d := 400.0
	var ref_w := 1280.0
	var inset := 70.0
	var far_g := 0.7
	var logical_x := 900.0

	var near_z := origin_z
	var far_z := origin_z + ref_d * 0.5
	var p_near := PerspectiveMath.project(
		logical_x, near_z, 100.0,
		origin_x, origin_z, z_min, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	var p_far := PerspectiveMath.project(
		logical_x, far_z, 100.0,
		origin_x, origin_z, z_min, near_y, far_y, ref_d, ref_w, inset, far_g
	)

	# X moves toward origin as Z increases (within lean band)
	var dist_near := absf(float(p_near.screen_x) - origin_x)
	var dist_far := absf(float(p_far.screen_x) - origin_x)
	if dist_far >= dist_near - 0.01:
		push_error("screen_x should converge toward origin with Z (near dist=%s far=%s)" % [dist_near, dist_far])
		return false

	# Unclamped t is linear in Z (no knee): t = (z - (origin - ref/2)) / ref
	var t0 := PerspectiveMath.perspective_t(origin_z - ref_d, origin_z, ref_d)
	var t1 := PerspectiveMath.perspective_t(origin_z, origin_z, ref_d)
	var t2 := PerspectiveMath.perspective_t(origin_z + ref_d, origin_z, ref_d)
	if absf(t0 - (-0.5)) > 0.001 or absf(t1 - 0.5) > 0.001 or absf(t2 - 1.5) > 0.001:
		push_error("perspective_t not linear/unclamped: %s %s %s" % [t0, t1, t2])
		return false
	# Equal Z steps → equal Δt
	var mid := origin_z + ref_d * 0.25
	var t_a := PerspectiveMath.perspective_t(origin_z, origin_z, ref_d)
	var t_b := PerspectiveMath.perspective_t(mid, origin_z, ref_d)
	var t_c := PerspectiveMath.perspective_t(origin_z + ref_d * 0.5, origin_z, ref_d)
	if absf((t_b - t_a) - (t_c - t_b)) > 0.0001:
		push_error("t steps not equal (knee?): %s %s %s" % [t_a, t_b, t_c])
		return false

	# Height / geometry_scale uses clamped t (outside [0,1] does not overshoot far_g)
	var t_below := -0.5
	var t_above := 1.5
	var g_lo := PerspectiveMath.geometry_scale_at(t_below, far_g)
	var g_hi := PerspectiveMath.geometry_scale_at(t_above, far_g)
	if absf(g_lo - 1.0) > 0.001:
		push_error("geometry_scale below band should clamp to 1, got %s" % g_lo)
		return false
	if absf(g_hi - far_g) > 0.001:
		push_error("geometry_scale above band should clamp to far_g=%s, got %s" % [far_g, g_hi])
		return false

	var h_far := float(p_far.surface_screen_h)
	var want_h := 100.0 * float(p_far.geometry_scale)
	if absf(h_far - want_h) > 0.01:
		push_error("surface_screen_h should be height*gscale")
		return false

	# Fixed lean Z: same world point keeps the same x_scale if origin_z is unchanged
	# (skater depth stick must not re-lean the park).
	var z_world := 120.0
	var lean_z := z_min + ref_d * 0.5
	var a := PerspectiveMath.project(
		logical_x, z_world, 0.0,
		origin_x, lean_z, z_min, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	var b := PerspectiveMath.project(
		logical_x, z_world, 0.0,
		origin_x, lean_z, z_min, near_y, far_y, ref_d, ref_w, inset, far_g
	)
	if absf(float(a.x_scale) - float(b.x_scale)) > 0.0001:
		push_error("x_scale must be stable for fixed lean origin_z")
		return false
	# Ground Y trucks with world Z, independent of lean origin.
	var y0 := PerspectiveMath.ground_screen_y(z_world, z_min, near_y, far_y, ref_d)
	var y1 := PerspectiveMath.ground_screen_y(z_world + 40.0, z_min, near_y, far_y, ref_d)
	if y1 >= y0:
		push_error("farther Z should move up the screen (smaller Y)")
		return false

	if not _air_shadow_scale():
		return false

	return true


func _air_shadow_scale() -> bool:
	var min_s := 0.5
	# At support: full width.
	if absf(PerspectiveMath.air_shadow_width_scale(0.0, 200.0, min_s) - 1.0) > 0.001:
		push_error("air shadow at support want scale 1")
		return false
	# Mid height: between min and 1.
	var mid := PerspectiveMath.air_shadow_width_scale(100.0, 200.0, min_s)
	if mid <= min_s or mid >= 1.0:
		push_error("air shadow mid height want in (min,1), got %s" % mid)
		return false
	# At/above ref: min scale.
	var hi := PerspectiveMath.air_shadow_width_scale(200.0, 200.0, min_s)
	if absf(hi - min_s) > 0.001:
		push_error("air shadow at ref want min %s, got %s" % [min_s, hi])
		return false
	var above := PerspectiveMath.air_shadow_width_scale(400.0, 200.0, min_s)
	if absf(above - min_s) > 0.001:
		push_error("air shadow above ref stays at min, got %s" % above)
		return false
	# Higher → smaller (or equal once clamped).
	var a := PerspectiveMath.air_shadow_width_scale(40.0, 200.0, min_s)
	var b := PerspectiveMath.air_shadow_width_scale(120.0, 200.0, min_s)
	if b >= a:
		push_error("air shadow must shrink as height rises (%s → %s)" % [a, b])
		return false
	return true
