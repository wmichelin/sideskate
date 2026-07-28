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
