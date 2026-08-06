class_name BoardYawTracker
extends RefCounted
## Presentation board yaw: snap on spawn/restore; co-rotate with hang apex facing_yaw.

var yaw: float = 0.0
var _prev_facing_yaw: float = 0.0
var _inited: bool = false


func snap_to_facing(facing_h: float) -> void:
	yaw = PI if facing_h >= 0.0 else 0.0
	_inited = true


func tick(
	facing_h: float, facing_yaw: float, force_snap: bool = false, spin_handoff: bool = false
) -> float:
	if force_snap or not _inited:
		snap_to_facing(facing_h)
		_prev_facing_yaw = facing_yaw
		return yaw
	var dyaw := angle_difference(_prev_facing_yaw, facing_yaw)
	var handoff := (
		spin_handoff
		or (
			absf(absf(_prev_facing_yaw) - PI) < 0.01
			and absf(facing_yaw) < 0.01
		)
	)
	if absf(dyaw) > 0.0001 and not handoff:
		yaw += dyaw
	_prev_facing_yaw = facing_yaw
	return yaw
