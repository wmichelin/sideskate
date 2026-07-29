class_name TopologyEdge
extends RefCounted
## Transition between surfaces or into air.


var id: String = ""
var kind: int = 0 ## SimKinds.EdgeKind
var from_surface_id: String = ""
var to_surface_id: String = "" ## empty if open/unsupported → air
var coping_id: String = ""
var u_gate: float = 1.0 ## pipe: theta/u at which edge fires (1 = coping)
var z_min: float = 0.0
var z_max: float = 0.0
var boundary: String = "coping" ## coping / bottom / top
var transfer_target_id: String = "" ## action-only; never ordinary transition


func contains_z(z: float) -> bool:
	return z >= z_min - SimTolerances.ALIGN_EPS and z <= z_max + SimTolerances.ALIGN_EPS
