class_name LogicalPose
extends RefCounted
## Renderer-neutral skater pose snapshot (2D and 3D presenters consume this).

var logical_x: float = 0.0
var logical_z: float = 0.0
var feet_height: float = 0.0
var support_height: float = 0.0
var surface_tilt: float = 0.0
## Contact plane lean for fall clearance (ramp/pipe normal); see PseudoDepthBody.
var support_tilt: float = 0.0
## Fall tumble extras (ragdoll presentation).
var fall_pitch: float = 0.0
var fall_twist: float = 0.0
var airborne: bool = false
var facing_h: float = 1.0
## Centered local-Y hang-apex turn (0 settled; ±π faces opposite).
var facing_yaw: float = 0.0
## Subtle local-Y steering turn from Z-stick input.
var depth_turn_yaw: float = 0.0
## Persistent presentation board yaw (local Y in lean frame). Independent of facing.
var board_yaw: float = 0.0
## True when this snapshot cleared spin_yaw without unwinding (land rebase / bout reset).
## Pose lerp must not animate facing/board through that jump.
var yaw_rebase: bool = false
var active_layer: int = 0


func copy_from_depth(depth: PseudoDepthBody, facing: float = 1.0, layer: int = 0) -> void:
	logical_x = depth.logical_x
	logical_z = depth.logical_z
	feet_height = depth.surface_height
	support_height = depth.support_height
	surface_tilt = depth.surface_tilt
	support_tilt = depth.support_tilt
	fall_pitch = depth.fall_pitch
	fall_twist = depth.fall_twist
	airborne = depth.airborne
	facing_h = facing
	facing_yaw = 0.0
	depth_turn_yaw = 0.0
	yaw_rebase = false
	active_layer = layer


func duplicate_pose() -> LogicalPose:
	var p := LogicalPose.new()
	p.logical_x = logical_x
	p.logical_z = logical_z
	p.feet_height = feet_height
	p.support_height = support_height
	p.surface_tilt = surface_tilt
	p.support_tilt = support_tilt
	p.fall_pitch = fall_pitch
	p.fall_twist = fall_twist
	p.airborne = airborne
	p.facing_h = facing_h
	p.facing_yaw = facing_yaw
	p.depth_turn_yaw = depth_turn_yaw
	p.board_yaw = board_yaw
	p.yaw_rebase = yaw_rebase
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
	out.support_tilt = lerp_angle(a.support_tilt, b.support_tilt, u)
	out.fall_pitch = lerp_angle(a.fall_pitch, b.fall_pitch, u)
	out.fall_twist = lerp_angle(a.fall_twist, b.fall_twist, u)
	out.airborne = b.airborne if u >= 0.5 else a.airborne
	var spin_rebase := a.yaw_rebase or b.yaw_rebase
	var equivalent_turn_handoff := (
		a.facing_h * b.facing_h < 0.0
		and absf(absf(a.facing_yaw - b.facing_yaw) - PI) < 0.01
	)
	if spin_rebase or equivalent_turn_handoff:
		# Rebase / equivalent facing: snap to the new frame — do not lerp a half-turn
		# that would desync body vs board.
		out.facing_h = b.facing_h
		out.facing_yaw = b.facing_yaw
		out.board_yaw = b.board_yaw
	else:
		out.facing_h = b.facing_h if u >= 0.5 else a.facing_h
		out.facing_yaw = lerp_angle(a.facing_yaw, b.facing_yaw, u)
		out.board_yaw = lerp_angle(a.board_yaw, b.board_yaw, u)
	out.depth_turn_yaw = lerp_angle(a.depth_turn_yaw, b.depth_turn_yaw, u)
	out.yaw_rebase = b.yaw_rebase
	out.active_layer = b.active_layer if u >= 0.5 else a.active_layer
	return out
