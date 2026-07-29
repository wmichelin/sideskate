class_name CopingSpan
extends RefCounted
## Z-local behavior for one geometric coping.


var id: String = ""
var coping_id: String = ""
var z_min: float = 0.0
var z_max: float = 0.0
var coping_class: int = SimKinds.CopingClass.OPEN
var effective_height_samples: Array = [] ## {z, height}
var support_patch_id: String = ""
var outward_deck_id: String = ""
var wall_id: String = ""
var partner_coping_id: String = "" ## maneuver target only; never an auto seam


func contains_z(z: float) -> bool:
	return z >= z_min - SimTolerances.ALIGN_EPS and z <= z_max + SimTolerances.ALIGN_EPS


func effective_height_at(z: float) -> float:
	if effective_height_samples.is_empty():
		return NAN
	if effective_height_samples.size() == 1:
		return float((effective_height_samples[0] as Dictionary).height)
	var zc := clampf(z, z_min, z_max)
	for i in range(effective_height_samples.size() - 1):
		var a: Dictionary = effective_height_samples[i]
		var b: Dictionary = effective_height_samples[i + 1]
		var za := float(a.z)
		var zb := float(b.z)
		if zc < za - 0.001 or zc > zb + 0.001:
			continue
		var t := 0.0 if absf(zb - za) < 0.001 else clampf((zc - za) / (zb - za), 0.0, 1.0)
		return lerpf(float(a.height), float(b.height), t)
	return float((effective_height_samples[-1] as Dictionary).height)


func class_name_str() -> String:
	return SimKinds.coping_class_name(coping_class)
