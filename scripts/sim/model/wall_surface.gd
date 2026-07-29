class_name WallSurface
extends RefCounted
## Explicit vertical ride surface joining a pipe coping to a higher edge.


var id: String = ""
var source_pipe_id: String = ""
var source_coping_id: String = ""
var coping_span_id: String = ""
var z_min: float = 0.0
var z_max: float = 0.0
var samples: Array = [] ## {z, x, bottom_height, top_height}
var top_support_id: String = ""
var upper_partner_pipe_id: String = "" ## transfer target only


func contains_z(z: float) -> bool:
	return z >= z_min - SimTolerances.ALIGN_EPS and z <= z_max + SimTolerances.ALIGN_EPS


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
		if zc < za - 0.001 or zc > zb + 0.001:
			continue
		var t := 0.0 if absf(zb - za) < 0.001 else clampf((zc - za) / (zb - za), 0.0, 1.0)
		return {
			"z": zc,
			"x": lerpf(float(a.x), float(b.x), t),
			"bottom_height": lerpf(float(a.bottom_height), float(b.bottom_height), t),
			"top_height": lerpf(float(a.top_height), float(b.top_height), t),
		}
	return (samples[-1] as Dictionary).duplicate()


func position_at(z: float, u: float) -> Vector3:
	var s := sample_at_z(z)
	if s.is_empty():
		return Vector3.ZERO
	return Vector3(
		float(s.x),
		z,
		lerpf(float(s.bottom_height), float(s.top_height), clampf(u, 0.0, 1.0))
	)


func u_at_height(z: float, height: float) -> float:
	var s := sample_at_z(z)
	if s.is_empty():
		return 0.0
	var bottom := float(s.bottom_height)
	var span := maxf(float(s.top_height) - bottom, 0.001)
	return clampf((height - bottom) / span, 0.0, 1.0)


func height_at_u(z: float, u: float) -> float:
	return position_at(z, u).z


func project(x: float, z: float, height: float) -> Dictionary:
	if not contains_z(z):
		return {"ok": false}
	var s := sample_at_z(z)
	var bottom := float(s.bottom_height)
	var top := float(s.top_height)
	if height < bottom - SimTolerances.CONTACT_EPS or height > top + SimTolerances.CONTACT_EPS:
		return {"ok": false}
	var u := u_at_height(z, height)
	var point := position_at(z, u)
	return {
		"ok": true,
		"point": point,
		"normal": Vector3.ZERO,
		"tangent_along": Vector3(0, 0, 1),
		"tangent_z": Vector3(0, 1, 0),
		"u": u,
		"v": clampf((z - z_min) / maxf(z_max - z_min, 0.001), 0.0, 1.0),
		"separation": absf(x - float(s.x)),
		"surface_id": id,
	}
