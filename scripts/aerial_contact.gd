class_name AerialContact
extends RefCounted
## Sticky query params + unlocked air-over identity from a resolved contact.
## Player owns RampLevel.resolve_air_contact I/O and pose writes.

const _ContactMath := preload("res://scripts/contact_math.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


## Sticky pipe args for RampLevel.resolve_air_contact.
## Over-pipe free air and any X-lock keep the same footprint identity.
static func sticky_query(
	air_over: String,
	air_x_locked: bool,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	air_z_min: float,
	air_z_max: float,
) -> Dictionary:
	if air_over == "left_pipe" or air_over == "right_pipe" or air_x_locked:
		return {
			"side": air_side,
			"lip_x": air_lip_x,
			"base_height": air_base_height,
			"z_min": air_z_min,
			"z_max": air_z_max,
		}
	return {
		"side": -1,
		"lip_x": NAN,
		"base_height": NAN,
		"z_min": NAN,
		"z_max": NAN,
	}


## Identity patch after unlocked air contact. Locked air returns apply=false
## (collision/landing still uses the contact; coping id stays put).
## kind: "pipe" | "pad" | "hole" | "plain"
static func unlocked_identity_from_contact(
	contact: Dictionary,
	air_x_locked: bool,
) -> Dictionary:
	if air_x_locked:
		return {"apply": false}
	var zone := str(contact.get("zone", "flat"))
	var layer := int(contact.get("layer", -1))
	var chit: Dictionary = contact.get("hit", {})
	if _ContactMath.is_pipe(chit):
		return {
			"apply": true,
			"kind": "pipe",
			"air_over": zone,
			"air_over_layer": layer,
			"hit": chit,
		}
	if zone == "flat" or zone == "deck":
		return {
			"apply": true,
			"kind": "pad",
			"air_over": zone,
			"air_over_layer": layer,
			"air_base_height": float(contact.get("height", chit.get("base_height", 0.0))),
		}
	if zone == "hole":
		return {
			"apply": true,
			"kind": "hole",
			"air_over": zone,
			"air_over_layer": layer,
			"air_base_height": float(contact.get("height", 0.0)),
		}
	return {
		"apply": true,
		"kind": "plain",
		"air_over": zone,
		"air_over_layer": layer,
	}


## Pipe air-over identity from a sample hit (adopt / begin-air helpers).
static func pipe_identity_from_hit(
	under: Dictionary,
	fallback_side: int,
	fallback_lip_x: float,
	fallback_base: float,
	fallback_z_min: float,
	fallback_z_max: float,
	pipe_radius: float,
	layer: int = -1,
) -> Dictionary:
	var side := int(under.get("side", fallback_side))
	var lip := float(under.get("lip_x", fallback_lip_x))
	var base := float(under.get("base_height", fallback_base))
	var z_min := float(under.get("z_min", fallback_z_min))
	var z_max := float(under.get("z_max", fallback_z_max))
	var out_layer := layer
	if under.has("layer"):
		out_layer = int(under.get("layer", -1))
	return {
		"air_over": _PipeMath.zone_name(side),
		"air_side": side,
		"air_lip_x": lip,
		"air_radius": pipe_radius,
		"air_base_height": base,
		"air_z_min": z_min,
		"air_z_max": z_max,
		"air_coping_x": _PipeMath.coping_x(side, lip, pipe_radius),
		"transfer_behind_sign": _PipeMath.coping_sign(side),
		"air_over_layer": out_layer,
	}


## Same lip identity or shared coping column as the pipe left this aerial.
static func is_exit_pipe_coping(
	coping: float,
	side: int,
	lip: float,
	exit_side: int,
	exit_lip: float,
	exit_coping: float,
) -> bool:
	if exit_side < 0:
		return false
	if side == exit_side and not is_nan(exit_lip) and not is_nan(lip) \
			and absf(lip - exit_lip) < 0.05:
		return true
	# Same coping column (stacked layers / twin lips share top X).
	if not is_nan(exit_coping) and not is_nan(coping) \
			and absf(coping - exit_coping) < 1.0:
		return true
	return false


## True when hit is the pipe (or coping column) left this aerial.
static func is_exit_pipe_hit(
	hit: Dictionary,
	exit_side: int,
	exit_lip: float,
	exit_coping: float,
	exit_z_min: float,
	exit_z_max: float,
) -> bool:
	if hit.is_empty() or exit_side < 0:
		return false
	var side := int(hit.get("side", -1))
	var lip := float(hit.get("lip_x", NAN))
	var coping := float(hit.get("top_coping", NAN))
	if is_nan(coping) and not is_nan(lip):
		coping = _PipeMath.coping_x(side, lip, float(hit.get("radius", 150.0)))
	if not is_nan(exit_z_min) and hit.has("z_min") \
			and absf(float(hit.z_min) - exit_z_min) > 0.05:
		return false
	if not is_nan(exit_z_max) and hit.has("z_max") \
			and absf(float(hit.z_max) - exit_z_max) > 0.05:
		return false
	return is_exit_pipe_coping(coping, side, lip, exit_side, exit_lip, exit_coping)
