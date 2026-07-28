class_name AerialTransfer
extends RefCounted
## Pure transfer / acid / spine target builders. Player owns scene locks + lerps.

const _ContactMath := preload("res://scripts/contact_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


## Deck or foreign pipe — not flat/hole fillers from sample_transfer.
static func hit_is_meaningful(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	if _ContactMath.is_pipe(hit):
		return true
	return str(hit.get("zone", "")) == "deck"


## Begin-air target + settle anchor for a free transfer probe hit.
## Returns { "target": Dictionary, "anchor_x": float }.
static func build_begin_air_target(
	hit: Dictionary,
	probe_x: float,
	pipe_radius: float,
) -> Dictionary:
	var zone := str(hit.get("zone", "flat"))
	if _ContactMath.is_pipe(hit):
		var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
		var lip: float = float(hit.get("lip_x", probe_x))
		var radius: float = pipe_radius
		var coping := _PipeMath.coping_x(side, lip, radius)
		return {
			"anchor_x": coping,
			"target": {
				"zone": _PipeMath.zone_name(side),
				"side": side,
				"lip_x": lip,
				"radius": radius,
				"base_height": float(hit.get("base_height", 0.0)),
				"z_min": float(hit.get("z_min", NAN)),
				"z_max": float(hit.get("z_max", NAN)),
				"layer": int(hit.get("layer", -1)),
				"lock_x": false,
				"anchor_x": coping,
			},
		}
	if zone == "deck":
		return {
			"anchor_x": probe_x,
			"target": {
				"zone": "deck",
				"lock_x": false,
				"anchor_x": probe_x,
				"layer": int(hit.get("layer", -1)),
				"base_height": float(hit.get("base_height", 0.0)),
			},
		}
	return {
		"anchor_x": probe_x,
		"target": {
			"zone": "flat",
			"lock_x": false,
			"anchor_x": probe_x,
			"layer": int(hit.get("layer", -1)),
			"base_height": float(hit.get("height", 0.0)),
		},
	}


## Validate acid cast hit (want side + ahead). Returns apply fields or ok=false.
static func resolve_acid_lock(
	hit: Dictionary,
	logical_x: float,
	travel_x: float,
	fallback_x: float,
) -> Dictionary:
	if hit.is_empty() or absf(travel_x) < 1.0:
		return {"ok": false}
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", fallback_x))
	var radius: float = float(hit.get("radius", 150.0))
	var coping: float = float(hit.get("top_coping", _PipeMath.coping_x(side, lip, radius)))
	if side != _AerialMath.acid_drop_want_side(travel_x):
		return {"ok": false}
	if not _AerialMath.acid_coping_ahead(logical_x, coping, travel_x):
		return {"ok": false}
	return {
		"ok": true,
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"coping_x": coping,
		"base_height": float(hit.get("base_height", 0.0)),
		"z_min": float(hit.get("z_min", NAN)),
		"z_max": float(hit.get("z_max", NAN)),
		"layer": int(hit.get("layer", -1)),
	}


## Feet must already clear the opposite lip (no early spine into a taller wall).
static func spine_feet_clear_dest(feet_h: float, hit: Dictionary, eps: float = 0.5) -> bool:
	if hit.is_empty():
		return false
	var dest_coping_h := (
		float(hit.get("base_height", 0.0)) + float(hit.get("radius", 150.0))
	)
	return feet_h >= dest_coping_h - eps


## Spine lock identity + into-pipe carry from a facing-cast hit.
static func resolve_spine_lock(
	hit: Dictionary,
	fallback_x: float,
	carry_speed: float,
) -> Dictionary:
	if hit.is_empty():
		return {"ok": false}
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", fallback_x))
	var radius: float = float(hit.get("radius", 150.0))
	var coping: float = float(hit.get("top_coping", _PipeMath.coping_x(side, lip, radius)))
	var base := float(hit.get("base_height", 0.0))
	return {
		"ok": true,
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"coping_x": coping,
		"base_height": base,
		"z_min": float(hit.get("z_min", NAN)),
		"z_max": float(hit.get("z_max", NAN)),
		"layer": int(hit.get("layer", -1)),
		"air_over": _PipeMath.zone_name(side),
		"transfer_behind_sign": _PipeMath.coping_sign(side),
		"vx": _AerialMath.lock_carry_velocity_x(carry_speed, side),
	}
