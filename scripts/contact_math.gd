class_name ContactMath
extends RefCounted
## Pure vertical contact helpers for layered levels (physics-tick only).
## Surfaces are duck-typed sample hits: {zone, height, side?, lip_x?, base_height?, ...}.

const LAND_EPS := 1.5
const HEIGHT_TIE_EPS := 0.05


static func is_solid(hit: Dictionary) -> bool:
	var zone := str(hit.get("zone", ""))
	return zone == "flat" or zone == "deck" or zone == "lava"


static func is_lava(hit: Dictionary) -> bool:
	return str(hit.get("zone", "")) == "lava"


## Floor / deck pads that count as a safe respawn anchor (not lava).
static func is_safe_pad(hit: Dictionary) -> bool:
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
	if absf(float(underfoot_hit.get("base_height", 0.0)) \
			- float(cross_pipe.get("base_height", 0.0))) > 0.5:
		return false
	# Runtime cross hits carry Z bounds. Preserve compatibility with small
	# synthetic hits used by isolated motion tests.
	if underfoot_hit.has("z_min") and cross_pipe.has("z_min") \
			and absf(float(underfoot_hit.z_min) - float(cross_pipe.z_min)) > 0.05:
		return false
	if underfoot_hit.has("z_max") and cross_pipe.has("z_max") \
			and absf(float(underfoot_hit.z_max) - float(cross_pipe.z_max)) > 0.05:
		return false
	return true


## Same pipe identity (side + lip + base_height + optional Z span).
static func same_pipe(a: Dictionary, b: Dictionary) -> bool:
	if not is_pipe(a) or not is_pipe(b):
		return false
	if int(a.get("side", -1)) != int(b.get("side", -2)):
		return false
	if absf(float(a.get("lip_x", 0.0)) - float(b.get("lip_x", 1.0))) > 0.05:
		return false
	if absf(float(a.get("base_height", 0.0)) - float(b.get("base_height", 0.0))) > 0.5:
		return false
	# Synthetic test hits may omit Z. Runtime pipe samples always include it.
	if a.has("z_min") and b.has("z_min") \
			and absf(float(a.z_min) - float(b.z_min)) > 0.05:
		return false
	if a.has("z_max") and b.has("z_max") \
			and absf(float(a.z_max) - float(b.z_max)) > 0.05:
		return false
	return true


## Sticky ride decision when own footprint may be inactive (e.g. past coping).
## `own_active`: query_surface on the sticky identity is still underfoot.
## `underfoot`: RampLevel.sample result (must not steal another pipe while sticky).
## `toward_coping_speed`: along-arc speed toward the sticky pipe's coping (≥0 up).
## Returns "ride" | "launch" | "leave".
static func sticky_ramp_action(
	own_active: bool,
	underfoot: Dictionary,
	current: Dictionary,
	toward_coping_speed: float,
) -> String:
	if own_active:
		return "ride"
	# Past sticky footprint. Never adopt a different pipe (stacked L0 at shared X).
	if is_pipe(underfoot) and not same_pipe(underfoot, current):
		return "launch"
	if toward_coping_speed > 0.0:
		return "launch"
	return "leave"


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


## Falling through a hole at story height `hole_h`: may land on `floor_h`?
## Reject only surfaces *above* the hole plane. Equal height is allowed (e.g. L0
## coping floor matching L1 story height under a `.` gap).
static func hole_fall_allows_floor(
	floor_h: float, hole_h: float, eps: float = 0.05
) -> bool:
	return floor_h <= hole_h + eps


## Acid mid-lerp: refuse exit-wall land and non-target pipe land.
static func acid_should_reject_land(
	land_hit: Dictionary,
	acid_drop_lock: bool,
	is_exit_pipe: bool,
	air_side: int,
	air_lip_x: float,
) -> bool:
	if not acid_drop_lock or not is_pipe(land_hit):
		return false
	if is_exit_pipe:
		return true
	var hit_side := int(land_hit.get("side", -1))
	var hit_lip := float(land_hit.get("lip_x", NAN))
	return hit_side != air_side or is_nan(hit_lip) or absf(hit_lip - air_lip_x) > 0.05


## Spine mid-lerp: only land on the locked target pipe (and matching story).
## While X settle is still active and not coping-aligned, defer target land too
## (early mid-wall drop-in). Intervening deck/flat stay rejected for land while
## the target footprint is still underfoot — clearance soft-floor rides over them.
## If the player drifts off the target Z band or hits lava, allow crash land.
static func spine_should_reject_land(
	land_hit: Dictionary,
	spine_transfer_lock: bool,
	air_side: int,
	air_lip_x: float,
	air_base_height: float,
	settle_active: bool = false,
	aligned: bool = true,
	on_target_z: bool = true,
) -> bool:
	if not spine_transfer_lock:
		return false
	if not is_pipe(land_hit):
		# Lava is always a crash. Off-target Z → crash into ground/pads.
		if str(land_hit.get("zone", "")) == "lava":
			return false
		if not on_target_z:
			return false
		return true
	var spine_side := int(land_hit.get("side", -1))
	var spine_lip := float(land_hit.get("lip_x", NAN))
	if spine_side != air_side or is_nan(spine_lip) or absf(spine_lip - air_lip_x) > 0.05:
		return true
	var spine_base := float(land_hit.get("base_height", NAN))
	if not is_nan(spine_base) and not is_nan(air_base_height) \
			and absf(spine_base - air_base_height) > 0.5:
		return true
	# Matching target: wait until X settle finishes or coping align.
	if settle_active and not aligned:
		return true
	return false


## Glyph on a story: hole / floor / lava / deck / pipe / empty.
static func zone_from_glyph(glyph: String) -> String:
	match glyph:
		".":
			return "hole"
		"=", "@":
			return "flat"
		"x", "X":
			return "lava"
		"#", "^", "v", "V":
			return "deck"
		"<", ">":
			return "pipe"
		" ":
			return "oob"
		_:
			return "flat"
