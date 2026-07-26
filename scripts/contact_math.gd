class_name ContactMath
extends RefCounted
## Pure vertical contact helpers for layered levels (physics-tick only).
## Surfaces are duck-typed sample hits: {zone, height, side?, lip_x?, base_height?, ...}.

const LAND_EPS := 1.5
const HEIGHT_TIE_EPS := 0.05


static func is_solid(hit: Dictionary) -> bool:
	var zone := str(hit.get("zone", ""))
	return zone == "flat" or zone == "deck"


static func is_pipe(hit: Dictionary) -> bool:
	var zone := str(hit.get("zone", ""))
	return zone == "left_pipe" or zone == "right_pipe"


static func surface_pref_rank(hit: Dictionary) -> int:
	if is_solid(hit):
		return 2
	if is_pipe(hit):
		return 1
	return 0


## Drop pipes strictly below a solid at/under prefer_h (`=` is not a hole).
static func candidates_blocked_by_solids(
	candidates: Array, prefer_h: float, land_eps: float = LAND_EPS
) -> Array:
	var solid_h := -INF
	for c in candidates:
		if not is_solid(c):
			continue
		var h := float(c.get("height", 0.0))
		if h <= prefer_h + land_eps and h > solid_h:
			solid_h = h
	if solid_h < -INF + 1.0:
		return candidates
	var out: Array = []
	for c2 in candidates:
		var h2 := float(c2.get("height", 0.0))
		if is_pipe(c2) and h2 < solid_h - HEIGHT_TIE_EPS:
			continue
		out.append(c2)
	return out if not out.is_empty() else candidates


static func pick_highest(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var best: Dictionary = candidates[0]
	var best_h := float(best.get("height", 0.0))
	for i in range(1, candidates.size()):
		var c: Dictionary = candidates[i]
		var h := float(c.get("height", 0.0))
		if h > best_h + 0.001:
			best = c
			best_h = h
		elif absf(h - best_h) <= 0.001 and surface_pref_rank(c) > surface_pref_rank(best):
			best = c
	return best


## Topmost surface with height ≤ prefer_h + land_eps (solids occlude lower pipes).
static func pick_by_prefer_h(
	candidates: Array, prefer_h: float, land_eps: float = LAND_EPS
) -> Dictionary:
	if candidates.is_empty():
		return {}
	var blocked := candidates_blocked_by_solids(candidates, prefer_h, land_eps)
	if blocked.is_empty():
		blocked = candidates
	var best_below: Dictionary = {}
	var best_below_h := -INF
	for c in blocked:
		var h := float(c.get("height", 0.0))
		if h > prefer_h + land_eps:
			continue
		if h > best_below_h + 0.001:
			best_below = c
			best_below_h = h
		elif absf(h - best_below_h) <= 0.001 and surface_pref_rank(c) > surface_pref_rank(best_below):
			best_below = c
	if not best_below.is_empty():
		return best_below
	return _pick_lowest(blocked)


static func _pick_lowest(candidates: Array) -> Dictionary:
	var lowest: Dictionary = candidates[0]
	var lowest_h := float(lowest.get("height", 0.0))
	for i in range(1, candidates.size()):
		var c: Dictionary = candidates[i]
		var h := float(c.get("height", 0.0))
		if h < lowest_h:
			lowest = c
			lowest_h = h
	return lowest


## True when surface height lies in the vertical sweep interval (tunnel catch).
static func height_in_sweep(
	surface_h: float, h0: float, h1: float, land_eps: float = LAND_EPS
) -> bool:
	var hi := maxf(h0, h1)
	var lo := minf(h0, h1)
	return surface_h <= hi + land_eps and surface_h >= lo - land_eps


## Vertical sweep [h0 → h1]: catch the highest surface crossed / under max height.
## Returns { "hit": Dictionary, "height": float, "crossed_solid": bool }.
static func resolve_vertical(
	candidates: Array, h0: float, h1: float, land_eps: float = LAND_EPS
) -> Dictionary:
	if candidates.is_empty():
		return {"hit": {}, "height": 0.0, "crossed_solid": false}
	var hi := maxf(h0, h1)
	var lo := minf(h0, h1)
	var falling := h0 >= h1 - 0.0001

	# Solids whose height lies in the swept interval (catches tunneling past `=`).
	var best_solid: Dictionary = {}
	var best_solid_h := -INF
	for c in candidates:
		if not is_solid(c):
			continue
		var h := float(c.get("height", 0.0))
		if not height_in_sweep(h, h0, h1, land_eps):
			continue
		if h > best_solid_h + 0.001 or (
			absf(h - best_solid_h) <= 0.001
			and surface_pref_rank(c) > surface_pref_rank(best_solid)
		):
			best_solid = c
			best_solid_h = h

	if falling and not best_solid.is_empty():
		return {
			"hit": best_solid,
			"height": best_solid_h,
			"crossed_solid": true,
		}

	# Pipes (and other non-solids) crossed in the interval — same tunnel catch.
	# Prefer solids above; here nothing solid was in-range.
	var best_cross: Dictionary = {}
	var best_cross_h := -INF
	for c2 in candidates:
		var h2 := float(c2.get("height", 0.0))
		if not height_in_sweep(h2, h0, h1, land_eps):
			continue
		if h2 > best_cross_h + 0.001 or (
			absf(h2 - best_cross_h) <= 0.001
			and surface_pref_rank(c2) > surface_pref_rank(best_cross)
		):
			best_cross = c2
			best_cross_h = h2
	if falling and not best_cross.is_empty():
		return {
			"hit": best_cross,
			"height": best_cross_h,
			"crossed_solid": is_solid(best_cross),
		}

	var hit := pick_by_prefer_h(candidates, hi, land_eps)
	if hit.is_empty():
		return {"hit": {}, "height": 0.0, "crossed_solid": false}
	var hit_h := float(hit.get("height", 0.0))
	return {
		"hit": hit,
		"height": hit_h,
		"crossed_solid": is_solid(hit) and falling and h0 > hit_h + 0.05 and h1 <= hit_h + land_eps,
	}


## Fresh mount only near feet; already on ramp always allowed; solid pad blocks remount.
static func should_mount_pipe(
	hit: Dictionary,
	feet_h: float,
	on_ramp: bool,
	solid_pad: bool,
	ride_off_eps: float = 0.5,
) -> bool:
	if not is_pipe(hit):
		return false
	if on_ramp:
		return true
	if solid_pad:
		return false
	var h := float(hit.get("height", 0.0))
	return h >= feet_h - ride_off_eps


## Coping-exit launch only when underfoot is the same pipe identity.
static func should_coping_launch(underfoot_hit: Dictionary, cross_pipe: Dictionary) -> bool:
	if underfoot_hit.is_empty() or cross_pipe.is_empty():
		return false
	if not is_pipe(underfoot_hit):
		return false
	if int(underfoot_hit.get("side", -1)) != int(cross_pipe.get("side", -2)):
		return false
	if absf(float(underfoot_hit.get("lip_x", 0.0)) - float(cross_pipe.get("lip_x", 1.0))) > 0.05:
		return false
	var ub := float(underfoot_hit.get("base_height", 0.0))
	var cb := float(cross_pipe.get("base_height", 0.0))
	return absf(ub - cb) <= 0.5


## Same pipe identity (side + lip + base_height).
static func same_pipe(a: Dictionary, b: Dictionary) -> bool:
	if not is_pipe(a) or not is_pipe(b):
		return false
	if int(a.get("side", -1)) != int(b.get("side", -2)):
		return false
	if absf(float(a.get("lip_x", 0.0)) - float(b.get("lip_x", 1.0))) > 0.05:
		return false
	return absf(float(a.get("base_height", 0.0)) - float(b.get("base_height", 0.0))) <= 0.5


## Air-contact record: drives both debug label and landing collision.
static func make_air_contact(
	zone: String,
	layer: int,
	height: float,
	solid: bool,
	hit: Dictionary = {}
) -> Dictionary:
	return {
		"zone": zone,
		"layer": layer,
		"height": height,
		"solid": solid,
		"hit": hit,
	}


static func is_air_contact_solid(contact: Dictionary) -> bool:
	return bool(contact.get("solid", false))


## Falling feet reached/crossed a solid air contact — always land (no climb refuse).
static func should_land_on_air_contact(
	contact: Dictionary, h0: float, h1: float, land_eps: float = LAND_EPS
) -> bool:
	if not is_air_contact_solid(contact):
		return false
	var sh := float(contact.get("height", 0.0))
	# Still above support after this tick.
	if h1 > sh + 0.05:
		return false
	# Reached or dipped through — always catch while contact is solid.
	return true


## Glyph on a story: hole / floor / pipe / deck / empty.
static func zone_from_glyph(glyph: String) -> String:
	match glyph:
		".":
			return "hole"
		"=", "@":
			return "flat"
		"#", "^", "v", "V":
			return "deck"
		"<", ">":
			return "pipe"
		" ":
			return "oob"
		_:
			return "flat"
