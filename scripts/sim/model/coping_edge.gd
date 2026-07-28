class_name CopingEdge
extends RefCounted
## Compiled coping with exactly one classification.


var id: String = ""
var pipe_id: String = ""
var side: int = 0
var coping_class: int = 0 ## SimKinds.CopingClass
var z_min: float = 0.0
var z_max: float = 0.0
## Effective height along Z (deck top for WALL_EXTENSION).
var height_samples: Array = [] ## {z, height, coping_x}
var support_patch_id: String = "" ## for SUPPORT_SEAM / WALL_EXTENSION
var shared_with_id: String = "" ## opposite coping for SHARED_SPINE
var outward_sign: float = 1.0


func sample_at_z(z: float) -> Dictionary:
	if height_samples.is_empty():
		return {}
	if height_samples.size() == 1:
		return (height_samples[0] as Dictionary).duplicate()
	var zc := clampf(z, z_min, z_max)
	for i in range(height_samples.size() - 1):
		var a: Dictionary = height_samples[i]
		var b: Dictionary = height_samples[i + 1]
		var za := float(a.z)
		var zb := float(b.z)
		if zc >= za - 0.001 and zc <= zb + 0.001:
			var t := 0.0 if absf(zb - za) < 0.001 else clampf((zc - za) / (zb - za), 0.0, 1.0)
			return {
				"z": zc,
				"height": lerpf(float(a.height), float(b.height), t),
				"coping_x": lerpf(float(a.coping_x), float(b.coping_x), t),
			}
	return (height_samples[height_samples.size() - 1] as Dictionary).duplicate()


func contains_z(z: float) -> bool:
	return z >= z_min - SimTolerances.ALIGN_EPS and z <= z_max + SimTolerances.ALIGN_EPS


func midpoint_z() -> float:
	return (z_min + z_max) * 0.5


func class_name_str() -> String:
	return SimKinds.coping_class_name(coping_class)
