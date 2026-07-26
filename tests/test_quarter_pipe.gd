extends RefCounted
## QuarterPipe.query_surface: lip / mid / coping θ+height; OOB inactive.


func run() -> bool:
	var pipe := QuarterPipe.new()
	pipe.side = QuarterPipe.PipeSide.LEFT
	pipe.lip_x = 200.0
	pipe.radius = 100.0
	pipe.z_min = 0.0
	pipe.z_max = 50.0

	var right := QuarterPipe.new()
	right.side = QuarterPipe.PipeSide.RIGHT
	right.lip_x = 300.0
	right.radius = 80.0
	right.z_min = 0.0
	right.z_max = 40.0

	var ok := _check(pipe, right)
	pipe.free()
	right.free()
	return ok


func _check(pipe: QuarterPipe, right: QuarterPipe) -> bool:
	# Lip (θ≈0, height≈0)
	var lip: Dictionary = pipe.query_surface(200.0, 25.0)
	if not lip.get("active", false):
		push_error("lip should be active")
		return false
	if absf(float(lip.theta)) > 0.02 or absf(float(lip.height)) > 0.5:
		push_error("lip θ/height want ~0 got θ=%s h=%s" % [lip.theta, lip.height])
		return false

	# Mid: x_offset = radius/2 → θ = asin(0.5), h = r*(1-cosθ)
	var mid_x := 200.0 - 50.0
	var mid: Dictionary = pipe.query_surface(mid_x, 25.0)
	var want_theta := asin(0.5)
	var want_h := 100.0 * (1.0 - cos(want_theta))
	if not mid.get("active", false):
		push_error("mid should be active")
		return false
	if absf(float(mid.theta) - want_theta) > 0.01 or absf(float(mid.height) - want_h) > 0.5:
		push_error("mid want θ=%s h=%s got θ=%s h=%s" % [want_theta, want_h, mid.theta, mid.height])
		return false

	# Coping / wall top: x_offset = radius → θ = PI/2, h = radius
	var top: Dictionary = pipe.query_surface(100.0, 25.0)
	if not top.get("active", false):
		push_error("coping should be active")
		return false
	if absf(float(top.theta) - PI * 0.5) > 0.02 or absf(float(top.height) - 100.0) > 0.5:
		push_error("coping want θ=PI/2 h=100 got θ=%s h=%s" % [top.theta, top.height])
		return false

	# OOB X / Z
	if pipe.query_surface(50.0, 25.0).get("active", true):
		push_error("OOB X should be inactive")
		return false
	if pipe.query_surface(150.0, 100.0).get("active", true):
		push_error("OOB Z should be inactive")
		return false

	var r_lip: Dictionary = right.query_surface(300.0, 10.0)
	if not r_lip.get("active", false) or absf(float(r_lip.height)) > 0.5:
		push_error("right lip should be active height~0")
		return false
	var r_top: Dictionary = right.query_surface(380.0, 10.0)
	if not r_top.get("active", false) or absf(float(r_top.height) - 80.0) > 0.5:
		push_error("right coping height want 80 got %s" % r_top.get("height"))
		return false

	# Elevated base_height shifts absolute height.
	pipe.base_height = 50.0
	var elev: Dictionary = pipe.query_surface(100.0, 25.0)
	if absf(float(elev.height) - 150.0) > 0.5:
		push_error("elevated coping want 150 got %s" % elev.height)
		return false
	if absf(float(elev.get("base_height", -1.0)) - 50.0) > 0.05:
		push_error("query should report base_height")
		return false

	return true
