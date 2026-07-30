class_name RampSurface
extends RefCounted
## Lofted triangular ramp: lip→peak is a straight incline (45° when width = rise).


var id: String = ""
var side: int = 0 ## SimKinds.PipeSide
var z_min: float = 0.0
var z_max: float = 0.0
## Sorted samples along Z: {z, lip_x, radius, base_height}
var samples: Array = []
var coping_id: String = ""


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
			return {
				"z": zc,
				"lip_x": lerpf(float(a.lip_x), float(b.lip_x), t),
				"radius": lerpf(float(a.radius), float(b.radius), t),
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


## u ∈ [0,1] along the incline (0 = lip, 1 = peak). `theta` kept for PipeSurface API parity.
func height_at_theta(z: float, theta: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var u := clampf(theta / (PI * 0.5), 0.0, 1.0)
	return float(s.base_height) + float(s.radius) * u


func x_at_theta(z: float, theta: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return NAN
	var u := clampf(theta / (PI * 0.5), 0.0, 1.0)
	var lip := float(s.lip_x)
	var r := float(s.radius)
	var off := r * u
	return lip - off if side == SimKinds.PipeSide.LEFT else lip + off


## Incline hypotenuse length for this Z sample (arc-length scale for along speed).
func incline_length(z: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return 0.0
	var r := float(s.radius)
	return r * sqrt(2.0)


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
	var u := clampf(dx / r, 0.0, 1.0)
	return u * (PI * 0.5)


func contains_xz(x: float, z: float) -> bool:
	if z < z_min - 0.001 or z > z_max + 0.001:
		return false
	return not is_nan(theta_from_xz(x, z))


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
	# Constant 45° normal (outward into the bowl / away from back wall).
	var inv := 1.0 / sqrt(2.0)
	var n_x := inv if side == SimKinds.PipeSide.LEFT else -inv
	var n_h := inv
	# Tangent along incline (increasing u = toward peak/coping).
	var t_x := -inv if side == SimKinds.PipeSide.LEFT else inv
	var t_h := inv
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
		"lip_x": float(s.lip_x),
		"base_height": float(s.base_height),
		"coping_x": coping_x_at(z),
		"coping_height": float(s.base_height) + r,
	}


func outward_sign() -> float:
	return -1.0 if side == SimKinds.PipeSide.LEFT else 1.0
