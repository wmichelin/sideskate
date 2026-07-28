class_name AerialSpineClearance
extends RefCounted
## Spine clearance corridor + soft-floor + defer-land gates (pure).
## At lock, sample solids along [from_x→to_x]; during settle, never drop below
## the corridor floor at the current X (deck tops + locked target pipe arc).

const _ContactMath := preload("res://scripts/contact_math.gd")

const CLEARANCE_EPS := 0.5
const CORRIDOR_SAMPLES := 16


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


## Height that contributes to the corridor at one sample.
## Non-pipe solids always count. Locked target pipe arc counts. Foreign pipes ignored.
static func corridor_sample_height(
	contact: Dictionary,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
) -> float:
	var solid := underfoot_solid_height(contact)
	if is_nan(solid):
		return NAN
	var hit: Dictionary = contact.get("hit", {})
	if _ContactMath.is_pipe(hit):
		if is_locked_target(hit, air_side, air_lip_x, air_base_height):
			return solid
		return NAN
	# Lava is a crash pit, not corridor clearance.
	if str(hit.get("zone", contact.get("zone", ""))) == "lava":
		return NAN
	return solid


## Build corridor samples. `sample_contact` is Callable(x: float) -> Dictionary air-contact.
## Returns { xs: PackedFloat32Array, heights: PackedFloat32Array, peak: float, dest_floor: float }.
static func build_corridor(
	from_x: float,
	to_x: float,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	air_radius: float,
	sample_contact: Callable,
	sample_count: int = CORRIDOR_SAMPLES,
) -> Dictionary:
	var dest := dest_coping_floor(air_base_height, air_radius)
	var n := maxi(sample_count, 2)
	var xs := PackedFloat32Array()
	var heights := PackedFloat32Array()
	xs.resize(n)
	heights.resize(n)
	var peak := dest
	for i in range(n):
		var t := float(i) / float(n - 1)
		var x := lerpf(from_x, to_x, t)
		xs[i] = x
		var h := dest
		if sample_contact.is_valid():
			var contact: Dictionary = sample_contact.call(x)
			var sample_h := corridor_sample_height(
				contact, air_side, air_lip_x, air_base_height
			)
			if not is_nan(sample_h):
				h = maxf(h, sample_h)
		heights[i] = h
		if h > peak:
			peak = h
	return {"xs": xs, "heights": heights, "peak": peak, "dest_floor": dest}


## Corridor from explicit height samples (unit tests).
static func corridor_from_heights(
	xs: PackedFloat32Array,
	heights: PackedFloat32Array,
	dest_floor: float,
) -> Dictionary:
	var peak := dest_floor
	for i in range(heights.size()):
		peak = maxf(peak, float(heights[i]))
	return {
		"xs": xs,
		"heights": heights,
		"peak": peak,
		"dest_floor": dest_floor,
	}


## Interpolated corridor floor at logical X (plus dest coping floor).
static func floor_at_x(corridor: Dictionary, logical_x: float) -> float:
	if corridor.is_empty():
		return NAN
	var dest := float(corridor.get("dest_floor", 0.0))
	var xs: PackedFloat32Array = corridor.get("xs", PackedFloat32Array())
	var heights: PackedFloat32Array = corridor.get("heights", PackedFloat32Array())
	if xs.is_empty() or heights.is_empty() or xs.size() != heights.size():
		return dest
	if xs.size() == 1:
		return maxf(dest, float(heights[0]))
	var x0 := float(xs[0])
	var x1 := float(xs[xs.size() - 1])
	if absf(x1 - x0) < 0.001:
		return maxf(dest, float(heights[0]))
	var t := clampf((logical_x - x0) / (x1 - x0), 0.0, 1.0)
	# Piecewise linear along samples.
	var f := t * float(xs.size() - 1)
	var i0 := mini(int(floor(f)), xs.size() - 2)
	var local_t := f - float(i0)
	var h := lerpf(float(heights[i0]), float(heights[i0 + 1]), local_t)
	return maxf(dest, h)


## Feet must clear the corridor peak (dest coping and any taller pad/arc on path).
static func feet_clear_corridor(feet_h: float, peak: float, eps: float = 0.05) -> bool:
	if is_nan(peak):
		return false
	return feet_h + maxf(eps, 0.0) >= peak


## Soft-floor while spine X settle is still running, or until coping-aligned after settle.
static func should_hold_spine_clearance(settle_active: bool, aligned: bool) -> bool:
	return settle_active or not aligned


## Soft-floor while holding: corridor floor at X, raised by live underfoot when needed.
static func clearance_floor(
	contact: Dictionary,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	air_radius: float,
	settle_active: bool,
	aligned: bool,
	corridor: Dictionary = {},
	logical_x: float = NAN,
) -> float:
	if not should_hold_spine_clearance(settle_active, aligned):
		return NAN

	var floor_h := dest_coping_floor(air_base_height, air_radius)
	if not corridor.is_empty() and not is_nan(logical_x):
		var c_floor := floor_at_x(corridor, logical_x)
		if not is_nan(c_floor):
			floor_h = maxf(floor_h, c_floor)

	var solid := underfoot_solid_height(contact)
	if is_nan(solid):
		return floor_h
	var hit: Dictionary = contact.get("hit", {})
	if is_locked_target(hit, air_side, air_lip_x, air_base_height):
		return maxf(floor_h, solid)
	if _ContactMath.is_pipe(hit):
		return floor_h
	# Lava is a crash, not a ride-over pad.
	if str(hit.get("zone", contact.get("zone", ""))) == "lava":
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
	corridor: Dictionary = {},
	logical_x: float = NAN,
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
			corridor,
			logical_x,
		)
	)


## Clamp height above floor; kill downward vel only while resting on the floor.
## Well above the floor, gravity keeps running so spine still reads as an arc.
static func apply_clearance(
	height: float,
	vel_y: float,
	floor_h: float,
	eps: float = CLEARANCE_EPS,
	max_lift: float = INF,
) -> Dictionary:
	var floor := floor_h + maxf(eps, 0.0)
	if height < floor - 0.001:
		var target := floor
		if max_lift < INF:
			target = minf(floor, height + maxf(max_lift, 0.0))
		return {
			"height": target,
			"vel_y": 0.0 if vel_y < 0.0 else vel_y,
			"resting": target >= floor - 0.001,
		}
	# Near the soft-floor: rest. Far above: leave vertical motion alone.
	if height <= floor + CLEARANCE_EPS:
		return {
			"height": height,
			"vel_y": 0.0 if vel_y < 0.0 else vel_y,
			"resting": true,
		}
	return {"height": height, "vel_y": vel_y, "resting": false}


## Defer land on the locked target until X settle is done or coping-aligned.
static func should_defer_target_land(settle_active: bool, aligned: bool) -> bool:
	return settle_active and not aligned
