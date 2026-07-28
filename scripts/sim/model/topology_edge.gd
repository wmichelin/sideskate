class_name TopologyEdge
extends RefCounted
## Transition between surfaces or into air.


var id: String = ""
var kind: int = 0 ## SimKinds.EdgeKind
var from_surface_id: String = ""
var to_surface_id: String = "" ## empty if open/unsupported → air
var coping_id: String = ""
var u_gate: float = 1.0 ## pipe: theta/u at which edge fires (1 = coping)
