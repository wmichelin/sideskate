class_name GroundMotion
extends RefCounted
## Pure grounded sticky / mount / coping-cross decisions. Player owns samples + pose.

const _ContactMath := preload("res://scripts/contact_math.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


## Pre-move sticky while already on a ramp.
## action: "skip" | "launch" | "leave" | "ride"
static func decide_sticky(
	on_ramp: bool,
	own_active: bool,
	underfoot: Dictionary,
	current: Dictionary,
	vx: float,
	ramp_side: int,
) -> Dictionary:
	if not on_ramp:
		return {"action": "skip", "toward": 0.0}
	var toward: float = maxf(vx * _PipeMath.coping_sign(ramp_side), 0.0)
	var action := _ContactMath.sticky_ramp_action(own_active, underfoot, current, toward)
	return {"action": action, "toward": toward}


## Fresh θ≈π/2 mount is an exit, not a safe entry.
static func is_rejected_fresh_coping(on_ramp: bool, hit: Dictionary) -> bool:
	return (
		not on_ramp
		and _ContactMath.is_pipe(hit)
		and float(hit.get("theta", 0.0)) >= PI * 0.5 - 0.001
	)


## Whether to mount/ride the underfoot pipe this tick.
static func decide_mount(
	hit: Dictionary,
	prev_support_h: float,
	on_ramp: bool,
	solid_pad: bool,
	ride_off_eps: float,
) -> Dictionary:
	var rejected := is_rejected_fresh_coping(on_ramp, hit)
	var allow := _ContactMath.should_mount_pipe(
		hit, prev_support_h, on_ramp, solid_pad, ride_off_eps
	)
	if rejected:
		allow = false
	return {"allow_pipe": allow, "rejected_fresh_coping": rejected}


## Post-arc sticky after `_move_along_pipe`.
## action: "ride" | "launch" | "leave"
static func decide_post_move(
	own_active: bool,
	own_hit: Dictionary,
	underfoot: Dictionary,
	current: Dictionary,
	ramp_along: float,
	ramp_side: int,
) -> Dictionary:
	var toward: float = maxf(ramp_along * _PipeMath.coping_sign(ramp_side), 0.0)
	var action := _ContactMath.sticky_ramp_action(own_active, underfoot, current, toward)
	var out := {"action": action, "toward": toward, "theta": 0.0}
	if action == "ride" and own_active:
		out["theta"] = float(own_hit.get("theta", 0.0))
	return out


## Flat / rejected-coping path after leaving or never mounting a pipe.
## action: "ride_off" | "coping_launch" | "commit"
static func decide_flat_path(
	hit: Dictionary,
	cross: Dictionary,
	solid_pad: bool,
	rejected_fresh_coping: bool,
	arc_speed: float,
) -> Dictionary:
	if rejected_fresh_coping:
		return {"action": "ride_off"}
	if (
		not cross.is_empty()
		and not solid_pad
		and _ContactMath.should_coping_launch(hit, cross)
	):
		var side: int = int(cross.get("side", 0))
		return {
			"action": "coping_launch",
			"hit": cross,
			"up_speed": maxf(arc_speed * _PipeMath.coping_sign(side), 0.0),
		}
	return {"action": "commit"}


## Highest-base pipe whose lip radius is crossed from `from_x` → `to_x`.
## `pipes` entries may be QuarterPipe nodes or Dictionaries with the same fields.
static func find_coping_cross(
	pipes: Array,
	logical_z: float,
	from_x: float,
	to_x: float,
	prefer_h: float,
) -> Dictionary:
	if is_equal_approx(from_x, to_x):
		return {}
	var best := {}
	var best_base := -INF
	for pipe in pipes:
		var z_min := float(_pipe_field(pipe, "z_min", 0.0))
		var z_max := float(_pipe_field(pipe, "z_max", 0.0))
		if logical_z < z_min - 0.001 or logical_z > z_max + 0.001:
			continue
		var base_h := float(_pipe_field(pipe, "base_height", 0.0))
		# Don't cross onto a pipe story far above the feet.
		if base_h > prefer_h + 1.5:
			continue
		var side: int = int(_pipe_field(pipe, "side", 0))
		var lip_x := float(_pipe_field(pipe, "lip_x", 0.0))
		var radius := float(_pipe_field(pipe, "radius", 0.0))
		var sign: float = _PipeMath.coping_sign(side)
		var from_off: float = (from_x - lip_x) * sign
		var to_off: float = (to_x - lip_x) * sign
		if from_off < radius - 0.001 and to_off >= radius - 0.001:
			if base_h >= best_base:
				best_base = base_h
				best = {
					"side": side,
					"lip_x": lip_x,
					"radius": radius,
					"base_height": base_h,
					"z_min": z_min,
					"z_max": z_max,
				}
	return best


static func _pipe_field(pipe, key: String, default: Variant = null) -> Variant:
	if pipe is Dictionary:
		return pipe.get(key, default)
	if pipe == null:
		return default
	return pipe.get(key)
