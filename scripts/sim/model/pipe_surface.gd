class_name PipeSurface
extends RefCounted
## Lofted quarter-pipe: lip/radius/rise/base sampled along Z.
## radius = X span; rise = height span (equal when step_height == cell_w).


var id: String = ""
var side: int = 0 ## SimKinds.PipeSide
var z_min: float = 0.0
var z_max: float = 0.0
## Sorted samples along Z: {z, lip_x, radius, rise, base_height}
var samples: Array = []
var coping_id: String = ""
## Conservative AABB over all samples (lip↔cope × base↔peak). Used for query culling.
var bound_x_min: float = 0.0
var bound_x_max: float = 0.0
var bound_h_min: float = 0.0
var bound_h_max: float = 0.0


static func _rise_of(s: Dictionary) -> float:
	return float(s.get("rise", s.get("radius", 0.0)))


## Recompute AABB after samples are filled / mutated.
func rebuild_bounds() -> void:
	bound_x_min = INF
	bound_x_max = -INF
	bound_h_min = INF
	bound_h_max = -INF
	if samples.is_empty():
		return
	for s in samples:
		var lip := float(s.lip_x)
		var r := float(s.radius)
		var rise := _rise_of(s)
		var base := float(s.base_height)
		var cope := lip - r if side == SimKinds.PipeSide.LEFT else lip + r
		bound_x_min = minf(bound_x_min, minf(lip, cope))
		bound_x_max = maxf(bound_x_max, maxf(lip, cope))
		bound_h_min = minf(bound_h_min, base)
		bound_h_max = maxf(bound_h_max, base + rise)


func sample_at_z(z: float) -> Dictionary:
	if samples.is_empty():
		return {}
	if samples.size() == 1:
		return (samples[0] as Dictionary).duplicate()
	var zc := clampf(z, z_min, z_max)
	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		var za := float(a.z)
		var zb := float(b.z)
		if zc >= za - 0.001 and zc <= zb + 0.001:
			var t := 0.0 if absf(zb - za) < 0.001 else (zc - za) / (zb - za)
			t = clampf(t, 0.0, 1.0)
			# Monotone lerp — no overshoot.
			return {
				"z": zc,
				"lip_x": lerpf(float(a.lip_x), float(b.lip_x), t),
				"radius": lerpf(float(a.radius), float(b.radius), t),
				"rise": lerpf(_rise_of(a), _rise_of(b), t),
				"base_height": lerpf(float(a.base_height), float(b.base_height), t),
			}
	return (samples[samples.size() - 1] as Dictionary).duplicate()


func coping_x_at(z: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var lip := float(s.lip_x)
	var r := float(s.radius)
	return lip - r if side == SimKinds.PipeSide.LEFT else lip + r


func height_at_theta(z: float, theta: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var th := clampf(theta, 0.0, PI * 0.5)
	return float(s.base_height) + _rise_of(s) * (1.0 - cos(th))


func x_at_theta(z: float, theta: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var th := clampf(theta, 0.0, PI * 0.5)
	var lip := float(s.lip_x)
	var r := float(s.radius)
	var off := r * sin(th)
	return lip - off if side == SimKinds.PipeSide.LEFT else lip + off


## Inverse: world (x,z) → theta if inside pipe band.
func theta_from_xz(x: float, z: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var lip := float(s.lip_x)
	var r := float(s.radius)
	if r <= 0.001:
		return NAN
	var dx := absf(x - lip)
	if side == SimKinds.PipeSide.LEFT:
		if x > lip + 0.001 or x < lip - r - 0.001:
			return NAN
	else:
		if x < lip - 0.001 or x > lip + r + 0.001:
			return NAN
	var ratio := clampf(dx / r, 0.0, 1.0)
	return asin(ratio)


func contains_xz(x: float, z: float) -> bool:
	if z < z_min - 0.001 or z > z_max + 0.001:
		return false
	return not is_nan(theta_from_xz(x, z))


## Solid interior excludes the coping boundary. The boundary belongs to the
## coping/wall topology, so stacked pipes cannot both own the same contact.
func contains_solid_xz(x: float, z: float) -> bool:
	if not contains_xz(x, z):
		return false
	var coping_x := coping_x_at(z)
	if is_nan(coping_x):
		return false
	if side == SimKinds.PipeSide.LEFT:
		return x > coping_x + 0.001
	return x < coping_x - 0.001


func project(x: float, z: float, h: float) -> Dictionary:
	var th := theta_from_xz(x, z)
	if is_nan(th):
		return {"ok": false}
	var px := x_at_theta(z, th)
	var ph := height_at_theta(z, th)
	var s := sample_at_z(z)
	var r := float(s.radius)
	var rise := _rise_of(s)
	# Scaled quarter-circle frame: reduces to circular when rise == radius.
	var n_x: float
	var n_h: float
	var t_x: float
	var t_h: float
	if side == SimKinds.PipeSide.LEFT:
		n_x = rise * cos(th)
		n_h = r * sin(th)
		t_x = -r * sin(th)
		t_h = rise * cos(th)
	else:
		n_x = -rise * cos(th)
		n_h = r * sin(th)
		t_x = r * sin(th)
		t_h = rise * cos(th)
	return {
		"ok": true,
		"point": Vector3(px, z, ph),
		"normal": Vector3(n_x, 0, n_h).normalized(),
		"tangent_along": Vector3(t_x, 0, t_h).normalized(),
		"tangent_z": Vector3(0, 1, 0),
		"u": th / (PI * 0.5),
		"v": clampf((z - z_min) / maxf(z_max - z_min, 0.001), 0.0, 1.0),
		"theta": th,
		"separation": h - ph,
		"surface_id": id,
		"radius": r,
		"rise": rise,
		"lip_x": float(s.lip_x),
		"base_height": float(s.base_height),
		"coping_x": coping_x_at(z),
		"coping_height": float(s.base_height) + rise,
	}


func outward_sign() -> float:
	return -1.0 if side == SimKinds.PipeSide.LEFT else 1.0
