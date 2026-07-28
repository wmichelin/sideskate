class_name LogicalPose
extends RefCounted
## Renderer-neutral skater pose snapshot (2D and 3D presenters consume this).

var logical_x: float = 0.0
var logical_z: float = 0.0
var feet_height: float = 0.0
var support_height: float = 0.0
var surface_tilt: float = 0.0
var airborne: bool = false
var facing_h: float = 1.0
var active_layer: int = 0


func copy_from_depth(depth: PseudoDepthBody, facing: float = 1.0, layer: int = 0) -> void:
	logical_x = depth.logical_x
	logical_z = depth.logical_z
	feet_height = depth.surface_height
	support_height = depth.support_height
	surface_tilt = depth.surface_tilt
	airborne = depth.airborne
	facing_h = facing
	active_layer = layer
