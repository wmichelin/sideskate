class_name AerialSpineClearance
extends RefCounted
## Spine-lock clearance soft-floor + defer-land gates (pure).
## While X settles, feet stay at/above the dest coping floor (and any taller
## intervening deck/flat/lava) instead of rejecting land and tunneling.

const _ContactMath := preload("res://scripts/contact_math.gd")

const CLEARANCE_EPS := 0.5


## Solid underfoot height from an air-contact record, or NAN if not solid.
static func underfoot_solid_height(contact: Dictionary) -> float:
	if not _ContactMath.is_air_contact_solid(contact):
		return NAN
	return float(contact.get("height", 0.0))


## Locked spine target pipe (side + lip + story base).
static func is_locked_target(
	hit: Dictionary,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
) -> bool:
	if hit.is_empty() or not _ContactMath.is_pipe(hit):
		return false
	if int(hit.get("side", -1)) != air_side:
		return false
	var lip := float(hit.get("lip_x", NAN))
	if is_nan(lip) or absf(lip - air_lip_x) > 0.05:
		return false
	var base := float(hit.get("base_height", NAN))
	if not is_nan(base) and not is_nan(air_base_height) and absf(base - air_base_height) > 0.5:
		return false
	return true


## Destination top-coping floor for the locked spine target.
static func dest_coping_floor(air_base_height: float, air_radius: float) -> float:
	return air_base_height + maxf(air_radius, 0.0)


## Soft-floor height while spine-locked and not ready to land:
## dest coping floor, raised by intervening non-pipe solids or the target arc
## before coping alignment. Foreign pipes never raise the floor (high→low).
static func clearance_floor(
	contact: Dictionary,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	air_radius: float,
	settle_active: bool,
	aligned: bool,
) -> float:
	if not should_defer_target_land(settle_active, aligned):
		# Settle done + aligned: only ride non-pipe pads still underfoot (no dest hold).
		var solid_only := underfoot_solid_height(contact)
		var hit_only: Dictionary = contact.get("hit", {})
		if not is_nan(solid_only) and not _ContactMath.is_pipe(hit_only):
			return solid_only
		return NAN

	var floor_h := dest_coping_floor(air_base_height, air_radius)
	var solid := underfoot_solid_height(contact)
	if is_nan(solid):
		return floor_h
	var hit: Dictionary = contact.get("hit", {})
	if is_locked_target(hit, air_side, air_lip_x, air_base_height):
		return maxf(floor_h, solid)
	if _ContactMath.is_pipe(hit):
		return floor_h
	return maxf(floor_h, solid)


## True when clearance_floor returned a finite floor to apply.
static func should_apply_clearance(
	contact: Dictionary,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	air_radius: float,
	settle_active: bool,
	aligned: bool,
) -> bool:
	return not is_nan(
		clearance_floor(
			contact,
			air_side,
			air_lip_x,
			air_base_height,
			air_radius,
			settle_active,
			aligned,
		)
	)


## Clamp height above floor; kill downward vel when resting. No-op if already clear.
static func apply_clearance(
	height: float,
	vel_y: float,
	floor_h: float,
	eps: float = CLEARANCE_EPS,
) -> Dictionary:
	var floor := floor_h + maxf(eps, 0.0)
	if height >= floor - 0.001:
		return {"height": height, "vel_y": vel_y, "resting": false}
	var next_vy := vel_y
	if next_vy < 0.0:
		next_vy = 0.0
	return {"height": floor, "vel_y": next_vy, "resting": true}


## Defer land on the locked target until X settle is done or coping-aligned.
static func should_defer_target_land(settle_active: bool, aligned: bool) -> bool:
	return settle_active and not aligned
