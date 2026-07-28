class_name AerialLanding
extends RefCounted
## Pure air-landing resolve + motion patch. Player owns level samples and pose writes.

const _ContactMath := preload("res://scripts/contact_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


## Resolve a land candidate from air contact + optional sweep / hole-lower samples.
## Returns one of:
##   { "land": false }
##   { "need_sweep": true }
##   { "need_hole_lower": true, "hole_h": float }
##   { "land": true, "floor_h": float, "land_hit": Dictionary }
static func resolve_land_hit(
	contact: Dictionary,
	h_before: float,
	h1: float,
	air_vel_y: float,
	sweep: Dictionary = {},
	hole_lower: Dictionary = {},
) -> Dictionary:
	if air_vel_y > 0.0:
		return {"land": false}
	if _ContactMath.should_land_on_air_contact(contact, h_before, h1):
		return {
			"land": true,
			"floor_h": float(contact.get("height", 0.0)),
			"land_hit": contact.get("hit", {}),
		}
	# Hole / still above: optionally catch a lower solid crossed this tick.
	if _ContactMath.is_air_contact_solid(contact) and h1 > float(contact.get("height", 0.0)) + 0.05:
		return {"land": false}
	if sweep.is_empty():
		return {"need_sweep": true}

	var land_hit: Dictionary = sweep.get("hit", {})
	if land_hit.is_empty() or (
		not land_hit.get("active", true) and str(land_hit.get("zone", "")) == "oob"
	):
		return {"land": false}
	var floor_h := float(sweep.get("height", 0.0))

	# Don't land on a surface above the hole story we're falling through.
	# Equal height is OK (L0 coping often sits at L1 floor under `.` gaps).
	if str(contact.get("zone", "")) == "hole":
		var hole_h := float(contact.get("height", 0.0))
		if not _ContactMath.hole_fall_allows_floor(floor_h, hole_h):
			if hole_lower.is_empty():
				return {"need_hole_lower": true, "hole_h": hole_h}
			return _resolve_hole_lower(hole_lower, hole_h, h_before, h1)
		if h1 > floor_h + 0.05:
			return {"land": false}
		if h_before < floor_h - 0.05 and not bool(sweep.get("crossed_solid", false)):
			if not _ContactMath.height_in_sweep(floor_h, h_before, h1):
				return {"land": false}
	else:
		if h1 > floor_h + 0.05:
			return {"land": false}
		if h_before < floor_h - 0.05 and not bool(sweep.get("crossed_solid", false)):
			if not _ContactMath.height_in_sweep(floor_h, h_before, h1):
				return {"land": false}

	if land_hit.is_empty():
		return {"land": false}
	return {"land": true, "floor_h": floor_h, "land_hit": land_hit}


static func _resolve_hole_lower(
	lower: Dictionary, hole_h: float, h_before: float, h1: float
) -> Dictionary:
	if lower.is_empty() or (
		not lower.get("active", true) and str(lower.get("zone", "")) == "oob"
	):
		return {"land": false}
	var lh := float(lower.get("height", 0.0))
	if not _ContactMath.hole_fall_allows_floor(lh, hole_h):
		return {"land": false}
	if h1 > lh + 0.05:
		return {"land": false}
	if not _ContactMath.height_in_sweep(lh, h_before, h1) and h_before < lh - 0.05:
		return {"land": false}
	return {"land": true, "floor_h": lh, "land_hit": lower}


## Acid/spine target-only landing rejects (exit-pipe identity supplied by Player).
static func should_reject_land(
	land_hit: Dictionary,
	acid_drop_lock: bool,
	is_exit_pipe: bool,
	air_side: int,
	air_lip_x: float,
	spine_transfer_lock: bool,
	air_base_height: float,
) -> bool:
	if _ContactMath.acid_should_reject_land(
		land_hit, acid_drop_lock, is_exit_pipe, air_side, air_lip_x
	):
		return true
	return _ContactMath.spine_should_reject_land(
		land_hit, spine_transfer_lock, air_side, air_lip_x, air_base_height
	)


## Pin X while X-locked and near air coping.
static func land_pin_x(
	logical_x: float,
	air_x_locked: bool,
	air_coping_x: float,
	air_radius: float,
) -> float:
	if not air_x_locked:
		return logical_x
	var eps := maxf(air_radius * 0.05, 2.0)
	if absf(logical_x - air_coping_x) <= eps:
		return air_coping_x
	return logical_x


## Motion patch after a resolved land. Player clears air then applies this.
## kind: "solid" | "pipe" | "other"
static func compute_land_apply(
	land_hit: Dictionary,
	floor_h: float,
	logical_x: float,
	pin_x: float,
	approach_x: float,
	land_vy: float,
	was_locked: bool,
	was_acid: bool,
	acid_travel: float,
	flew_out: bool,
	acid_pressed: bool,
	exit_travel: float,
	carry_peak: float,
) -> Dictionary:
	var no_reverse := was_acid or acid_pressed or flew_out
	var hold_sign := _AerialMath.land_hold_sign(acid_travel, no_reverse, exit_travel)
	if _ContactMath.is_solid(land_hit):
		return {
			"kind": "solid",
			"floor_h": floor_h,
			"logical_x": pin_x,
			"vx": _AerialMath.clamp_against_hold(approach_x, hold_sign),
			"on_ramp": false,
			"move_along": false,
		}
	if _ContactMath.is_pipe(land_hit):
		var land_side := int(land_hit.get("side", QuarterPipe.PipeSide.RIGHT))
		var side_sign := _PipeMath.coping_sign(land_side)
		var along := _AerialMath.pipe_land_along(
			approach_x,
			land_vy,
			land_side,
			was_locked,
			was_acid,
			no_reverse,
			acid_travel,
			hold_sign,
			carry_peak,
		)
		var move_along := along * side_sign < -1.0 or absf(along) > 1.0
		return {
			"kind": "pipe",
			"floor_h": floor_h,
			"logical_x": pin_x if was_locked and not move_along else logical_x,
			"vx": along,
			"ramp_along": along,
			"on_ramp": true,
			"ramp_side": land_side,
			"ramp_lip_x": float(land_hit.get("lip_x", logical_x)),
			"ramp_base_height": float(land_hit.get("base_height", 0.0)),
			"ramp_z_min": float(land_hit.get("z_min", NAN)),
			"ramp_z_max": float(land_hit.get("z_max", NAN)),
			"move_along": move_along,
			"land_hit": land_hit,
		}
	return {
		"kind": "other",
		"floor_h": floor_h,
		"logical_x": pin_x,
		"vx": approach_x,
		"on_ramp": false,
		"move_along": false,
	}
