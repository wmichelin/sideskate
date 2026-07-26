class_name PerspectiveMath
extends RefCounted
## Pure pseudo-depth projection helpers (no scene state).


static func perspective_t(
	logical_z: float, origin_z: float, reference_depth: float
) -> float:
	var ref := maxf(reference_depth, 0.0001)
	var z0 := origin_z - ref * 0.5
	return (logical_z - z0) / ref


static func far_x_scale(perspective_inset: float, reference_width: float) -> float:
	var ref_w := maxf(reference_width, 0.0001)
	return clampf(1.0 - (2.0 * perspective_inset) / ref_w, 0.15, 1.0)


static func x_scale_at(t: float, perspective_inset: float, reference_width: float) -> float:
	var far := far_x_scale(perspective_inset, reference_width)
	# Unclamped t keeps one slope; soft-limit so extreme pads don't invert X.
	return clampf(lerpf(1.0, far, t), 0.08, 2.5)


static func geometry_scale_at(t: float, far_geometry_scale: float) -> float:
	return lerpf(1.0, far_geometry_scale, clampf(t, 0.0, 1.0))


static func inset_at(t: float, perspective_inset: float) -> float:
	return lerpf(0.0, perspective_inset, clampf(t, 0.0, 1.0))


static func screen_y_per_z(
	near_screen_y: float, far_screen_y: float, reference_depth: float
) -> float:
	var ref := maxf(reference_depth, 0.0001)
	return (near_screen_y - far_screen_y) / ref


static func ground_screen_y(
	logical_z: float,
	z_min: float,
	near_screen_y: float,
	far_screen_y: float,
	reference_depth: float
) -> float:
	return near_screen_y - (logical_z - z_min) * screen_y_per_z(
		near_screen_y, far_screen_y, reference_depth
	)


## Project logical (x, z, height) → screen fields.
static func project(
	logical_x: float,
	logical_z: float,
	surface_height: float,
	origin_x: float,
	origin_z: float,
	z_min: float,
	near_screen_y: float,
	far_screen_y: float,
	reference_depth: float,
	reference_width: float,
	perspective_inset: float,
	far_geometry_scale: float
) -> Dictionary:
	var t := perspective_t(logical_z, origin_z, reference_depth)
	var inset := inset_at(t, perspective_inset)
	var gscale := geometry_scale_at(t, far_geometry_scale)
	var ground_y := ground_screen_y(
		logical_z, z_min, near_screen_y, far_screen_y, reference_depth
	)
	var x_scale := x_scale_at(t, perspective_inset, reference_width)
	var screen_x := origin_x + (logical_x - origin_x) * x_scale
	return {
		"t": t,
		"screen_x": screen_x,
		"ground_y": ground_y,
		"surface_screen_h": surface_height * gscale,
		"geometry_scale": gscale,
		"inset": inset,
		"x_scale": x_scale,
	}
