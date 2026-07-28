class_name PerspectiveMath
extends RefCounted
## Pure pseudo-depth projection helpers (no scene state).
##
## Camera-relative **homogeneous** depth: one scale `s = focal / (focal + Δz)`
## drives screen X, ground Y, and height so Z truck is a projective move — not an
## affine X lean sliding over a linear Y map (that shears / elongates the park).


static func far_x_scale(perspective_inset: float, reference_width: float) -> float:
	var ref_w := maxf(reference_width, 0.0001)
	return clampf(1.0 - (2.0 * perspective_inset) / ref_w, 0.15, 0.99)


## Focal length so scale at +reference_depth/2 matches inset far_x_scale.
static func focal_length(
	reference_depth: float, perspective_inset: float, reference_width: float
) -> float:
	var ref := maxf(reference_depth, 0.0001)
	var far := far_x_scale(perspective_inset, reference_width)
	# far = focal / (focal + ref/2)  →  focal = far * (ref/2) / (1 - far)
	return far * (ref * 0.5) / maxf(1.0 - far, 0.01)


## Homogeneous depth scale. 1 at the camera focus plane (`origin_z`).
static func depth_scale(
	logical_z: float,
	origin_z: float,
	reference_depth: float,
	perspective_inset: float,
	reference_width: float,
) -> float:
	var focal := focal_length(reference_depth, perspective_inset, reference_width)
	var z_eye := focal + (logical_z - origin_z)
	# Soft-limit behind / through the camera so X never inverts hard.
	var s := focal / maxf(z_eye, focal * 0.08)
	return clampf(s, 0.08, 2.5)


## Linear band parameter (debug / art curves). Prefer `depth_scale` for projection.
static func perspective_t(
	logical_z: float, origin_z: float, reference_depth: float
) -> float:
	var ref := maxf(reference_depth, 0.0001)
	var z0 := origin_z - ref * 0.5
	return (logical_z - z0) / ref


static func x_scale_at(
	logical_z: float,
	origin_z: float,
	reference_depth: float,
	perspective_inset: float,
	reference_width: float,
) -> float:
	return depth_scale(
		logical_z, origin_z, reference_depth, perspective_inset, reference_width
	)


static func geometry_scale_at(t: float, far_geometry_scale: float) -> float:
	return lerpf(1.0, far_geometry_scale, clampf(t, 0.0, 1.0))


static func inset_at(t: float, perspective_inset: float) -> float:
	return lerpf(0.0, perspective_inset, clampf(t, 0.0, 1.0))


static func screen_y_per_z(
	near_screen_y: float, far_screen_y: float, reference_depth: float
) -> float:
	var ref := maxf(reference_depth, 0.0001)
	return (near_screen_y - far_screen_y) / ref


## Reference depth that makes one ASCII Z cell the same near-plane screen size
## as one ASCII X cell. Tall maps stay scrollable instead of Z-compressing.
static func glyph_matched_reference_depth(
	near_screen_y: float,
	far_screen_y: float,
	cell_size_x: float,
	cell_size_z: float,
) -> float:
	var cell_x := maxf(cell_size_x, 0.0001)
	var span := near_screen_y - far_screen_y
	return maxf(span * maxf(cell_size_z, 0.0001) / cell_x, 0.0001)


## Ground Y from the same homogeneous `s` as X (focus plane → mid-screen).
static func ground_screen_y(
	logical_z: float,
	origin_z: float,
	near_screen_y: float,
	far_screen_y: float,
	reference_depth: float,
	perspective_inset: float,
	reference_width: float,
) -> float:
	var s := depth_scale(
		logical_z, origin_z, reference_depth, perspective_inset, reference_width
	)
	var focus_y := (near_screen_y + far_screen_y) * 0.5
	var far := far_x_scale(perspective_inset, reference_width)
	# At +ref/2, s=far and ground_y lands on far_screen_y.
	var fy := (near_screen_y - far_screen_y) / (2.0 * maxf(1.0 - far, 0.01))
	return focus_y - fy * (1.0 - s)


## Project logical (x, z, height) → screen fields (camera at origin_x / origin_z).
static func project(
	logical_x: float,
	logical_z: float,
	surface_height: float,
	origin_x: float,
	origin_z: float,
	near_screen_y: float,
	far_screen_y: float,
	reference_depth: float,
	reference_width: float,
	perspective_inset: float,
	far_geometry_scale: float
) -> Dictionary:
	var t := perspective_t(logical_z, origin_z, reference_depth)
	var s := depth_scale(
		logical_z, origin_z, reference_depth, perspective_inset, reference_width
	)
	var inset := inset_at(t, perspective_inset)
	# Heights share projective `s` (far_geometry_scale is an overall art multiply).
	var gscale := s * maxf(far_geometry_scale, 0.01)
	var ground_y := ground_screen_y(
		logical_z,
		origin_z,
		near_screen_y,
		far_screen_y,
		reference_depth,
		perspective_inset,
		reference_width
	)
	var screen_x := origin_x + (logical_x - origin_x) * s
	return {
		"t": t,
		"screen_x": screen_x,
		"ground_y": ground_y,
		"surface_screen_h": surface_height * gscale,
		"geometry_scale": gscale,
		"inset": inset,
		"x_scale": s,
	}


## Width multiplier for an airborne ground shadow. 1 at support, falls toward
## `min_scale` as height_above approaches `ref_height` (then clamps).
static func air_shadow_width_scale(
	height_above_support: float,
	ref_height: float = 200.0,
	min_scale: float = 0.5,
) -> float:
	var ref := maxf(ref_height, 0.001)
	var t := clampf(maxf(height_above_support, 0.0) / ref, 0.0, 1.0)
	return lerpf(1.0, min_scale, t)
