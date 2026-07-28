class_name PlayerAirState
extends RefCounted
## Pure air-state patches for Player. Player merges dicts onto fields / depth.

const _PipeMath := preload("res://scripts/pipe_math.gd")


## Full grounded reset after landing / death / clear.
static func clear_patch() -> Dictionary:
	return {
		"airborne": false,
		"air_abs_height": 0.0,
		"air_vel_y": 0.0,
		"air_over": "",
		"air_over_layer": -1,
		"air_x_locked": false,
		"acid_drop_lock": false,
		"spine_transfer_lock": false,
		"apex_facing_done": false,
		"transfer_available": true,
		"acid_drop_available": true,
		"last_nonzero_vert_vel": 0.0,
		"air_carry_speed": 0.0,
		"air_z_min": NAN,
		"air_z_max": NAN,
		"exit_pipe_side": -1,
		"exit_pipe_lip": NAN,
		"exit_pipe_coping": NAN,
		"exit_pipe_z_min": NAN,
		"exit_pipe_z_max": NAN,
		"exit_travel_x": 0.0,
		"acid_travel_x": 0.0,
		"flew_out_this_aerial": false,
		"crossed_pipe_coping_this_aerial": false,
		"acid_pressed_this_aerial": false,
		"reset_settle": true,
		"depth_height_offset": 0.0,
	}


## Start airborne over `target`. Returns field patch + optional logical_x pin.
static func begin_air_over_patch(
	target: Dictionary,
	abs_height: float,
	snap_x: bool,
	layer_fallback: int,
) -> Dictionary:
	var side := int(target.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip := float(target.get("lip_x", 0.0))
	var radius := float(target.get("radius", 150.0))
	var base := float(target.get("base_height", 0.0))
	var locked := bool(target.get("lock_x", false))
	var layer := layer_fallback
	if target.has("layer"):
		layer = int(target.layer)
	var patch := {
		"airborne": true,
		"crossed_pipe_coping_this_aerial": false,
		"air_vel_y": 0.0,
		"air_over": str(target.get("zone", "flat")),
		"air_x_locked": locked,
		"acid_drop_lock": false,
		"spine_transfer_lock": false,
		"apex_facing_done": false,
		"air_base_height": base,
		"air_z_min": float(target.get("z_min", NAN)),
		"air_z_max": float(target.get("z_max", NAN)),
		"air_over_layer": layer,
		"depth_height_offset": 0.0,
	}
	if target.has("side"):
		patch["air_side"] = side
		patch["transfer_behind_sign"] = _PipeMath.coping_sign(side)
	if target.has("lip_x"):
		patch["air_lip_x"] = lip
	if target.has("radius"):
		patch["air_radius"] = radius
	var coping_floor := base + radius
	if locked:
		var coping := float(
			target.get("anchor_x", _PipeMath.coping_x(side, lip, radius))
		)
		patch["air_coping_x"] = coping
		patch["air_abs_height"] = maxf(abs_height, coping_floor)
		if snap_x:
			patch["logical_x"] = coping
	else:
		patch["air_abs_height"] = abs_height
	return patch


## Locked pipe-exit enter: begin-air target + exit identity + lip vertical.
static func enter_from_pipe_bundle(
	hit: Dictionary,
	logical_x: float,
	fallback_base: float,
	fallback_z_min: float,
	fallback_z_max: float,
	pipe_radius: float,
	layer_fallback: int,
	up_speed: float,
) -> Dictionary:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", logical_x))
	var radius: float = float(hit.get("radius", pipe_radius))
	var base_h: float = float(hit.get("base_height", fallback_base))
	var z_min: float = float(hit.get("z_min", fallback_z_min))
	var z_max: float = float(hit.get("z_max", fallback_z_max))
	var coping := _PipeMath.coping_x(side, lip, radius)
	var layer := layer_fallback
	if hit.has("layer"):
		layer = int(hit.layer)
	var target := {
		"zone": _PipeMath.zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"base_height": base_h,
		"z_min": z_min,
		"z_max": z_max,
		"layer": layer,
		"lock_x": true,
		"anchor_x": coping,
	}
	var begin := begin_air_over_patch(target, base_h + radius, true, layer)
	begin["exit_pipe_side"] = side
	begin["exit_pipe_lip"] = lip
	begin["exit_pipe_coping"] = coping
	begin["exit_pipe_z_min"] = z_min
	begin["exit_pipe_z_max"] = z_max
	begin["exit_travel_x"] = _PipeMath.coping_sign(side)
	begin["crossed_pipe_coping_this_aerial"] = true
	begin["air_vel_y"] = maxf(up_speed, 0.0)
	begin["ramp_along"] = 0.0
	begin["vx"] = 0.0
	begin["on_ramp"] = false
	begin["note_air_carry"] = up_speed
	return begin


## Grounded spine launch: leave ramp into unlocked air over the source pipe.
static func spine_launch_from_ramp_patch(
	surface_height: float,
	ramp_along: float,
	theta: float,
	ramp_side: int,
	ramp_lip: float,
	ramp_radius: float,
	ramp_base: float,
	ramp_z_min: float,
	ramp_z_max: float,
	layer: int,
) -> Dictionary:
	var up := absf(ramp_along) * sin(clampf(theta, 0.0, PI * 0.5))
	var sign := _PipeMath.coping_sign(ramp_side)
	return {
		"airborne": true,
		"on_ramp": false,
		"air_x_locked": false,
		"acid_drop_lock": false,
		"spine_transfer_lock": false,
		"apex_facing_done": false,
		"settle_x_active": false,
		"settle_tilt_active": false,
		"air_abs_height": surface_height,
		"air_vel_y": maxf(up, 0.0),
		"ramp_along": 0.0,
		"vx": 0.0,
		"air_side": ramp_side,
		"air_lip_x": ramp_lip,
		"air_radius": ramp_radius,
		"air_base_height": ramp_base,
		"air_z_min": ramp_z_min,
		"air_z_max": ramp_z_max,
		"exit_pipe_side": ramp_side,
		"exit_pipe_lip": ramp_lip,
		"exit_pipe_coping": _PipeMath.coping_x(ramp_side, ramp_lip, ramp_radius),
		"exit_pipe_z_min": ramp_z_min,
		"exit_pipe_z_max": ramp_z_max,
		"exit_travel_x": sign,
		"air_over": _PipeMath.zone_name(ramp_side),
		"air_over_layer": layer,
		"transfer_behind_sign": sign,
		"depth_airborne": true,
		"depth_surface_height": surface_height,
		"note_air_carry": up,
	}


## Fly-out unlock seed. Returns empty if gates fail (caller checks bools first).
static func fly_out_unlock_patch(
	exit_travel_x: float,
	air_side: int,
	air_carry_speed: float,
	transfer_release_min: float,
) -> Dictionary:
	var out := exit_travel_x
	var patch := {
		"air_x_locked": false,
		"flew_out_this_aerial": true,
	}
	if absf(out) < 1.0:
		out = _PipeMath.coping_sign(air_side)
		patch["exit_travel_x"] = out
	patch["vx"] = out * maxf(air_carry_speed, transfer_release_min)
	return patch


## Acid / spine coping lock field patch from AerialTransfer resolve_* result.
static func coping_lock_patch(
	lock: Dictionary,
	acid: bool,
	spine: bool,
	layer_fallback: int,
) -> Dictionary:
	var layer := layer_fallback
	if int(lock.get("layer", -1)) >= 0:
		layer = int(lock.layer)
	var patch := {
		"air_x_locked": true,
		"acid_drop_lock": acid,
		"spine_transfer_lock": spine,
		"air_side": int(lock.side),
		"air_lip_x": float(lock.lip_x),
		"air_radius": float(lock.radius),
		"air_base_height": float(lock.base_height),
		"air_z_min": float(lock.z_min),
		"air_z_max": float(lock.z_max),
		"air_coping_x": float(lock.coping_x),
		"air_over": str(lock.get("air_over", _PipeMath.zone_name(int(lock.side)))),
		"air_over_layer": layer,
		"transfer_behind_sign": float(
			lock.get("transfer_behind_sign", _PipeMath.coping_sign(int(lock.side)))
		),
	}
	if spine:
		patch["transfer_available"] = false
		patch["acid_drop_available"] = false
	if lock.has("vx"):
		patch["vx"] = float(lock.vx)
	return patch


## Exclude pipe for facing cast (exit → locked air → ramp).
static func facing_exclude(
	exit_side: int,
	exit_lip: float,
	exit_z_min: float,
	exit_z_max: float,
	air_x_locked: bool,
	air_over: String,
	air_side: int,
	air_lip_x: float,
	air_z_min: float,
	air_z_max: float,
	on_ramp: bool,
	ramp_side: int,
	ramp_lip: float,
	ramp_z_min: float,
	ramp_z_max: float,
) -> Dictionary:
	if exit_side >= 0 and not is_nan(exit_lip):
		return {
			"side": exit_side,
			"lip_x": exit_lip,
			"z_min": exit_z_min,
			"z_max": exit_z_max,
		}
	if air_x_locked or air_over == "left_pipe" or air_over == "right_pipe" \
			or (air_over == "hole" and (
				air_side == QuarterPipe.PipeSide.LEFT
				or air_side == QuarterPipe.PipeSide.RIGHT
			)):
		return {
			"side": air_side,
			"lip_x": air_lip_x,
			"z_min": air_z_min,
			"z_max": air_z_max,
		}
	if on_ramp:
		return {
			"side": ramp_side,
			"lip_x": ramp_lip,
			"z_min": ramp_z_min,
			"z_max": ramp_z_max,
		}
	return {"side": -1, "lip_x": NAN, "z_min": NAN, "z_max": NAN}


static func spine_from_side(
	air_x_locked: bool,
	air_over: String,
	air_side: int,
	facing_h: String,
) -> int:
	if air_x_locked:
		return air_side
	if air_over == "left_pipe" or air_over == "right_pipe":
		return air_side
	if air_over == "hole" and (
		air_side == QuarterPipe.PipeSide.LEFT or air_side == QuarterPipe.PipeSide.RIGHT
	):
		return air_side
	if facing_h == "l":
		return QuarterPipe.PipeSide.LEFT
	if facing_h == "r":
		return QuarterPipe.PipeSide.RIGHT
	return -1


static func spine_behind_sign(
	from_side: int,
	transfer_behind_sign: float,
	facing_h: String,
) -> float:
	if from_side >= 0:
		return _PipeMath.coping_sign(from_side)
	if absf(transfer_behind_sign) >= 0.001:
		return signf(transfer_behind_sign)
	return 1.0 if facing_h == "r" else -1.0


static func body_tilt_target_radians(
	air_x_locked: bool,
	air_side: int,
	airborne: bool,
	on_ramp: bool,
	last_surface: Dictionary,
	ramp_side: int,
) -> float:
	if air_x_locked:
		return -_PipeMath.coping_sign(air_side) * (PI * 0.5)
	if airborne or not on_ramp:
		return 0.0
	if last_surface.is_empty() or not last_surface.has("theta"):
		return 0.0
	var th := clampf(float(last_surface.theta), 0.0, PI * 0.5)
	var side := int(last_surface.get("side", ramp_side))
	return -_PipeMath.coping_sign(side) * th
