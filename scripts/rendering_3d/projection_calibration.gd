class_name ProjectionCalibration
extends RefCounted
## Compare 2D PerspectiveMath screen points vs Camera3D.unproject for framing tune.


static func max_error_px(level: RampLevel, camera: Camera3D, samples: Array) -> float:
	if level == null or camera == null:
		return INF
	var worst := 0.0
	for s in samples:
		var x := float(s.get("x", 0.0))
		var z := float(s.get("z", 0.0))
		var h := float(s.get("h", 0.0))
		var p2: Dictionary = level.project_surface(x, z, h)
		var screen_2d := Vector2(float(p2.screen_x), float(p2.ground_y) - float(p2.surface_screen_h))
		var world := WorldSpace.logical_to_world(x, z, h)
		var screen_3d: Vector2 = camera.unproject_position(world)
		worst = maxf(worst, screen_2d.distance_to(screen_3d))
	return worst


static func default_samples(level: RampLevel) -> Array:
	if level == null or level.spec == null:
		return []
	var sx := level.spec.spawn_x
	var sz := level.spec.spawn_z
	return [
		{"x": sx, "z": sz, "h": 0.0},
		{"x": sx + 100.0, "z": sz, "h": 0.0},
		{"x": sx, "z": sz + 100.0, "h": 0.0},
		{"x": sx, "z": sz, "h": 50.0},
	]
