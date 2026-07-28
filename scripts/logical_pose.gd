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


func duplicate_pose() -> LogicalPose:
	var p := LogicalPose.new()
	p.logical_x = logical_x
	p.logical_z = logical_z
	p.feet_height = feet_height
	p.support_height = support_height
	p.surface_tilt = surface_tilt
	p.airborne = airborne
	p.facing_h = facing_h
	p.active_layer = active_layer
	return p


## Interpolate between two authoritative physics snapshots (render frames only).
static func lerp_poses(a: LogicalPose, b: LogicalPose, t: float) -> LogicalPose:
	var u := clampf(t, 0.0, 1.0)
	var out := LogicalPose.new()
	if a == null and b == null:
		return out
	if a == null:
		return b.duplicate_pose()
	if b == null:
		return a.duplicate_pose()
	out.logical_x = lerpf(a.logical_x, b.logical_x, u)
	out.logical_z = lerpf(a.logical_z, b.logical_z, u)
	out.feet_height = lerpf(a.feet_height, b.feet_height, u)
	out.support_height = lerpf(a.support_height, b.support_height, u)
	out.surface_tilt = lerp_angle(a.surface_tilt, b.surface_tilt, u)
	out.airborne = b.airborne if u >= 0.5 else a.airborne
	out.facing_h = b.facing_h if u >= 0.5 else a.facing_h
	out.active_layer = b.active_layer if u >= 0.5 else a.active_layer
	return out
