class_name AerialMath
extends RefCounted
## Pure aerial action helpers (transfer / spine-transfer / acid-drop routing + selection).
## Pipe entries are duck-typed: QuarterPipe nodes or {side, lip_x, radius, z_min, z_max}.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")

const ACTION_TRANSFER := "transfer"
const ACTION_ACID_DROP := "acid_drop"
## Max deck cells between opposite copings for spine transfer (inclusive).
## 3+ cells → normal free-air transfer instead.
const SPINE_GAP_MAX_CELLS := 2


static func _pipe_base_height(pipe: Variant) -> float:
	if typeof(pipe) == TYPE_DICTIONARY:
		return float(pipe.get("base_height", 0.0))
	return float(pipe.base_height)


static func _pipe_layer(pipe: Variant) -> int:
	if typeof(pipe) == TYPE_DICTIONARY:
		return int(pipe.get("layer", -1))
	return int(pipe.layer)


## Same-button routing: rising/apex → transfer; falling/rest-after-down → acid drop.
static func choose_air_action(
	vert_vel: float, last_nonzero_vert_vel: float, rest_eps: float = 0.5
) -> String:
	if _MotionMath.transfer_vert_ok(vert_vel, last_nonzero_vert_vel, rest_eps):
		return ACTION_TRANSFER
	return ACTION_ACID_DROP


## Prefer measured horizontal velocity; fall back to Momentum X.
static func resolve_horiz_vel(
	actual_vx: float, momentum_vx: float, actual_eps: float = 8.0, dead_eps: float = 1.0
) -> float:
	var hx := actual_vx
	if absf(hx) < actual_eps:
		hx = momentum_vx
	if absf(hx) < dead_eps:
		return 0.0
	return hx


## Acid travel direction for targeting / land.
## Order: live ACTUAL → pipe-exit outward → MOMENTUM.
## Never prefer stick-MOMENTUM over exit travel: while pipe X-locked, stick still
## integrates into `_velocity` and often points into the bowl — that used to make
## acid cast backward into the exit wall (felt like a reverse snap).
static func resolve_acid_travel_x(
	actual_vx: float,
	momentum_vx: float,
	exit_travel_x: float,
	dead_eps: float = 1.0,
) -> float:
	if absf(actual_vx) >= dead_eps:
		return actual_vx
	if absf(exit_travel_x) >= dead_eps:
		return exit_travel_x
	if absf(momentum_vx) >= dead_eps:
		return momentum_vx
	return 0.0


## Opposite wall for acid drop: vel right → LEFT pipe; vel left → RIGHT pipe.
static func acid_drop_want_side(horiz_vel: float) -> int:
	return 0 if horiz_vel > 0.0 else 1  # QuarterPipe.PipeSide.LEFT / RIGHT


## True when coping lies strictly ahead of `from_x` along travel.
static func acid_coping_ahead(from_x: float, coping_x: float, travel_x: float) -> bool:
	if absf(travel_x) < 1.0:
		return false
	return (coping_x - from_x) * travel_x > 0.0


## Clamp a proposed X step so acid settle never moves opposite travel.
static func acid_clamp_x_step(
	from_x: float, next_x: float, to_x: float, travel_x: float
) -> float:
	if absf(travel_x) < 1.0:
		return next_x
	if travel_x > 0.0:
		# Only rightward, and never past the target.
		return clampf(next_x, from_x, maxf(from_x, to_x))
	return clampf(next_x, minf(from_x, to_x), from_x)


## Sign that forbids reverse after acid / fly-out (0 = no hold).
static func land_hold_sign(acid_travel: float, no_reverse: bool, exit_travel: float) -> float:
	if absf(acid_travel) >= 1.0:
		return signf(acid_travel)
	if no_reverse and absf(exit_travel) >= 1.0:
		return signf(exit_travel)
	return 0.0


## Zero velocity that fights hold_sign (into-bowl after acid / fly-out).
static func clamp_against_hold(vx: float, hold_sign: float) -> float:
	if absf(hold_sign) >= 1.0 and vx * hold_sign < 0.0:
		return 0.0
	return vx


## Along-arc velocity when landing on a pipe from air (classic / acid / soft).
static func pipe_land_along(
	approach_x: float,
	land_vy: float,
	land_side: int,
	was_locked: bool,
	was_acid: bool,
	no_reverse: bool,
	acid_travel: float,
	hold_sign: float,
	carry_peak: float,
) -> float:
	var ax := approach_x
	if was_locked and not no_reverse:
		var carry := maxf(absf(ax), carry_peak)
		ax = lock_carry_velocity_x(carry, land_side)
	var along := ax
	if was_acid:
		along = acid_land_along(ax, land_vy, land_side, acid_travel)
	elif no_reverse:
		along = clamp_against_hold(along, hold_sign)
	elif was_locked or land_vy < -1.0:
		along = merge_drop_in_along(ax, land_vy, land_side)
	return clamp_against_hold(along, hold_sign)


## Acid land along-arc: keep travel sign. Absorb fall into-pipe only when that
## drop-in continues travel (opposite wall). Never emit along opposite travel.
static func acid_land_along(
	approach_x: float, land_vy: float, land_side: int, travel_x: float
) -> float:
	if absf(travel_x) < 1.0:
		return approach_x
	var travel_sgn := signf(travel_x)
	var along := approach_x
	if land_vy < -1.0:
		var from_fall := drop_in_along_from_land_vy(land_vy, land_side)
		# Opposite-wall drop-in matches travel; same-wall drop-in is a reverse.
		if from_fall * travel_sgn > 0.0:
			along = merge_drop_in_along(approach_x, land_vy, land_side)
	if along * travel_sgn < 0.0:
		along = absf(along) * travel_sgn
	elif absf(along) < 1.0 and land_vy < -1.0:
		var fall2 := drop_in_along_from_land_vy(land_vy, land_side)
		if fall2 * travel_sgn > 0.0:
			along = fall2
	return along


## Landing floor while airborne.
## Pipe-exit X-lock defaults to coping floor, but a solid sampled pad at/above
## coping (layer `=` / deck) wins — you cannot fall through floors into the ramp.
## Acid-drop lock and free air always use the sampled underfoot height.
static func landing_support_height(
	air_x_locked: bool,
	acid_drop_lock: bool,
	air_over: String,
	coping_floor: float,
	sampled_height: float,
) -> float:
	if air_x_locked and not acid_drop_lock and (
		air_over == "left_pipe" or air_over == "right_pipe"
	):
		# Solid at/above coping (upper-story floor over the pipe run).
		if sampled_height >= coping_floor - 1.5:
			return sampled_height
		return coping_floor
	return sampled_height


## Falling vert at top coping → along-arc drop-in (`land_vy * coping_sign`).
## Rising / rest → 0 (no outward kick from landing).
static func drop_in_along_from_land_vy(land_vy: float, side: int) -> float:
	if land_vy >= 0.0:
		return 0.0
	return land_vy * _PipeMath.coping_sign(side)


## Along-arc seed when landing locked on a pipe coping (pipe-exit, acid, spine).
## Converts falling vert into drop-in; keeps approach speed when already faster
## into the pipe. Outward approach alone does not seed along-arc.
static func merge_drop_in_along(approach_x: float, land_vy: float, side: int) -> float:
	var sign := _PipeMath.coping_sign(side)
	var from_fall := drop_in_along_from_land_vy(land_vy, side)
	# In signed space, into-pipe is negative. Take the stronger into-pipe speed.
	return minf(approach_x * sign, from_fall * sign) * sign


## Horizontal MOMENTUM to stash while acid/spine X-locked: into the target pipe
## at `carry_speed`. Survives gravity climb so low→high land keeps approach.
static func lock_carry_velocity_x(carry_speed: float, side: int) -> float:
	return -maxf(carry_speed, 0.0) * _PipeMath.coping_sign(side)


## X settle duration for locking onto an opposite coping (acid / spine).
## Continuous in height: `base + per_height * height_above_coping`.
## If `duration_max` > 0, soft-cap (still continuous below the cap).
static func lock_x_duration_for_height(
	height_above_coping: float,
	duration_base: float,
	duration_per_height: float,
	duration_max: float = 0.0,
) -> float:
	var d := (
		maxf(duration_base, 0.0)
		+ maxf(duration_per_height, 0.0) * maxf(height_above_coping, 0.0)
	)
	if duration_max > 0.0:
		d = minf(d, duration_max)
	return d


## Spine X settle: height term plus gap distance, floored so near-coping
## clearance holds (height_above≈0) never collapse to a snap across the plaza.
static func spine_lock_x_duration(
	gap_x: float,
	height_above_coping: float,
	duration_base: float,
	duration_per_height: float,
	duration_per_x: float,
	duration_min: float,
	duration_max: float = 0.0,
) -> float:
	var d := (
		maxf(duration_base, 0.0)
		+ maxf(duration_per_height, 0.0) * maxf(height_above_coping, 0.0)
		+ maxf(duration_per_x, 0.0) * absf(gap_x)
	)
	d = maxf(d, maxf(duration_min, 0.0))
	if duration_max > 0.0:
		d = minf(d, duration_max)
	return d


## Cubic smoothstep on 0…1 (ease in/out for X settle).
static func smoothstep01(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Quintic smootherstep — zero 1st/2nd derivatives at ends.
static func smootherstep01(u: float) -> float:
	var t := clampf(u, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Pipe-exit X-lock → free air (parabolic fly-out) when still rising, feet are
## within `above_coping` of the lip (not higher), and planar INPUT points toward
## that pipe's side (right → +X, left → −X). MOMENTUM is ignored — only the stick
## wish. X must dominate Z (`|input_x| > |input_z|`); pure/mostly vertical wish
## must not fly out. Falling (`air_vel_y` ≤ 0) never flies out. Acid-drop lock
## never flies out this way.
## `coping_floor` is absolute lip height (`base_height + radius`). `above_coping`
## is the debug-tunable *max* height above that floor (0 = only at coping; small
## values keep fly-out near the lip — apex is outside the window). Never pass
## radius alone as `coping_floor` on elevated stories.
static func should_fly_out_pipe_lock(
	air_x_locked: bool,
	acid_drop_lock: bool,
	air_side: int,
	air_abs_height: float,
	coping_floor: float,
	above_coping: float,
	input_x: float,
	air_vel_y: float,
	input_eps: float = 0.15,
	input_z: float = 0.0,
) -> bool:
	if not air_x_locked or acid_drop_lock:
		return false
	# Rising only — ignore while falling or at apex rest.
	if air_vel_y <= 0.0:
		return false
	# Window above coping: at/above lip, but not higher than the debug slider.
	var height_above := air_abs_height - coping_floor
	if height_above < -0.001:
		return false
	if height_above > maxf(above_coping, 0.0) + 0.001:
		return false
	# Stick must clearly push toward the pipe side; X must dominate Z (not vertical wish).
	if absf(input_x) <= input_eps:
		return false
	if absf(input_x) <= absf(input_z):
		return false
	var out := _PipeMath.coping_sign(air_side)
	return input_x * out > input_eps


## True when `x` is the top coping (lip ± radius), not the lip / flat edge.
static func is_top_coping(
	side: int, lip_x: float, radius: float, x: float, eps: float = 0.05
) -> bool:
	return absf(x - _PipeMath.coping_x(side, lip_x, radius)) <= eps


## Nearest opposite-facing TOP coping near horizontal velocity.
## `buffer` / `max_ahead` are legacy logical-X windows — gameplay acid uses
## FacingCastMath + `facing_coping_cells` instead. Kept for unit tests.
static func find_acid_drop_target(
	pipes: Array,
	logical_x: float,
	logical_z: float,
	horiz_vel: float,
	buffer: float,
	max_ahead: float,
) -> Dictionary:
	if absf(horiz_vel) < 1.0:
		return {}
	var facing := signf(horiz_vel)
	var want_side := acid_drop_want_side(horiz_vel)
	var best: Dictionary = {}
	var best_ahead := INF
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var side: int = int(pipe.side)
		var lip: float = float(pipe.lip_x)
		var radius: float = float(pipe.radius)
		# Top coping only — never the lip.
		var top_coping: float = _PipeMath.coping_x(side, lip, radius)
		var ahead: float = (top_coping - logical_x) * facing
		if ahead < -buffer:
			continue
		if ahead > max_ahead:
			continue
		if ahead < best_ahead:
			best_ahead = ahead
			best = {
				"active": true,
				"zone": _PipeMath.zone_name(side),
				"side": side,
				"lip_x": lip,
				"radius": radius,
				"base_height": _pipe_base_height(pipe),
				"layer": _pipe_layer(pipe),
				"top_coping": top_coping,
			}
	return best


## Deck-cell count for a coping gap (for docs/tests).
static func spine_gap_cells(dist: float, cell_w: float) -> int:
	var cw := maxf(cell_w, 0.001)
	return int(round(maxf(dist, 0.0) / cw))


## Opposite pipe for spine transfer: LEFT ↔ RIGHT (same coping column or ≤2 cells).
static func spine_opposite_side(side: int) -> int:
	return 1 if side == 0 else 0  # RIGHT if LEFT, LEFT if RIGHT


## Deprecated alias: behind RIGHT(+1) → LEFT; behind LEFT(−1) → RIGHT.
static func spine_want_side(behind_sign: float) -> int:
	return spine_opposite_side(1 if behind_sign > 0.0 else 0)


## True if candidate coping floor `cand_h` beats `best_h` for spine height pick.
## Prefer highest ≤ prefer_h; else lowest above prefer_h. NAN prefer_h → ignore height.
static func spine_height_better(cand_h: float, best_h: float, prefer_h: float) -> bool:
	if is_nan(prefer_h):
		return false
	var cand_below := cand_h <= prefer_h + 0.05
	var best_below := best_h <= prefer_h + 0.05
	if cand_below and not best_below:
		return true
	if not cand_below and best_below:
		return false
	if cand_below and best_below:
		# Nearest at/below: highest coping floor still under feet.
		return cand_h > best_h + 0.001
	# Both above: nearest above = lowest coping floor.
	return cand_h < best_h - 0.001


static func _pipe_x_range(pipe: Variant) -> Vector2:
	if typeof(pipe) == TYPE_DICTIONARY:
		return Vector2(float(pipe.get("x_min", 0.0)), float(pipe.get("x_max", 0.0)))
	return Vector2(float(pipe.x_min()), float(pipe.x_max()))


static func _pipe_hit_dict(pipe: Variant) -> Dictionary:
	var side: int = int(pipe.side)
	var lip: float = float(pipe.lip_x)
	var radius: float = float(pipe.radius)
	var base_h := _pipe_base_height(pipe)
	var z_min := float(pipe.get("z_min", NAN)) if typeof(pipe) == TYPE_DICTIONARY else float(pipe.z_min)
	var z_max := float(pipe.get("z_max", NAN)) if typeof(pipe) == TYPE_DICTIONARY else float(pipe.z_max)
	return {
		"active": true,
		"zone": _PipeMath.zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"base_height": base_h,
		"z_min": z_min,
		"z_max": z_max,
		"layer": _pipe_layer(pipe),
		"top_coping": _PipeMath.coping_x(side, lip, radius),
	}


## Glyph at (col,row) on a specific layer index. Space if missing.
static func _glyph_on_layer(spec: Variant, col: int, row: int, layer_index: int) -> String:
	if spec == null:
		return " "
	for L in spec.layers:
		if int(L.get("index", -1)) != layer_index:
			continue
		var rows: PackedStringArray = L.get("rows", PackedStringArray())
		if row < 0 or row >= rows.size():
			return " "
		var line: String = rows[row]
		if col < 0 or col >= line.length():
			return " "
		return line[col]
	return " "


## Opposite-pipe hits under (col,row): holes/empty/same-side pipes are transparent —
## keep scanning lower stories. Floor/deck (and only those) stop the stack.
static func _spine_opposite_at_column(
	spec: Variant,
	pipes: Array,
	col: int,
	row: int,
	want_side: int,
	exclude_side: int,
	exclude_lip_x: float,
	logical_z: float,
) -> Array:
	var out: Array = []
	if spec == null or spec.grid_w <= 0:
		return out
	var want_glyph := "<" if want_side == 0 else ">"
	var cw: float = maxf(float(spec.cell_w), 0.001)
	# High → low so upper holes don't hide lower opposite pipes.
	var layer_order: Array = spec.layers.duplicate()
	layer_order.sort_custom(func(a, b): return float(a.get("height", 0.0)) > float(b.get("height", 0.0)))
	for L in layer_order:
		var layer_i := int(L.get("index", -1))
		var glyph := _glyph_on_layer(spec, col, row, layer_i)
		var gzone := ContactMath.zone_from_glyph(glyph)
		if gzone == "hole" or glyph == " ":
			continue
		if glyph == want_glyph:
			var x_mid := (float(col) + 0.5) * cw
			for pipe in pipes:
				if int(pipe.side) != want_side:
					continue
				if int(pipe.side) == exclude_side and absf(float(pipe.lip_x) - exclude_lip_x) < 0.05:
					continue
				var pl := _pipe_layer(pipe)
				if pl >= 0 and layer_i >= 0 and pl != layer_i:
					continue
				if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
					continue
				var xr := _pipe_x_range(pipe)
				if x_mid < xr.x - 0.001 or x_mid > xr.y + 0.001:
					continue
				out.append(_pipe_hit_dict(pipe))
			# Keep scanning lower stories for stacked opposites.
			continue
		if gzone == "pipe":
			# Own-side / other-run pipe: transparent for downward opposite search.
			continue
		# Floor / deck: solid pad — stop looking through this column.
		break
	return out


## Walk ±X across ≤ SPINE_GAP_MAX_CELLS columns; holes/empty/same-side pipes are
## transparent downward so a lower opposite under `.` still counts. Logical grid
## only — no screen / perspective.
static func _spine_candidates_from_glyphs(
	spec: Variant,
	pipes: Array,
	from_x: float,
	logical_z: float,
	want_side: int,
	exclude_side: int,
	exclude_lip_x: float,
) -> Array:
	var out: Array = []
	if spec == null or spec.grid_w <= 0 or spec.grid_h <= 0:
		return out
	var cell: Vector2i = spec.cell_at(from_x, logical_z)
	var start_col := cell.x
	var row := cell.y
	for step in [-1, 1]:
		var col := start_col
		var gap_used := 0
		for _i in range(spec.grid_w + 1):
			if col < 0 or col >= spec.grid_w:
				break
			var hits: Array = _spine_opposite_at_column(
				spec, pipes, col, row, want_side, exclude_side, exclude_lip_x, logical_z
			)
			for h in hits:
				out.append(h)
			if hits.is_empty():
				gap_used += 1
				if gap_used > SPINE_GAP_MAX_CELLS:
					break
			col += step
	return out


## Pick best hit: prefer_h height rule, then smaller |Δcoping_x| (logical only).
static func _pick_spine_candidate(
	candidates: Array, from_x: float, prefer_h: float
) -> Dictionary:
	var best: Dictionary = {}
	var best_gap := INF
	var best_h := -INF
	for hit in candidates:
		if hit.is_empty():
			continue
		var top_coping: float = float(hit.get("top_coping", from_x))
		var gap: float = absf(top_coping - from_x)
		var coping_floor: float = float(hit.get("base_height", 0.0)) + float(hit.get("radius", 0.0))
		var take := false
		if best.is_empty():
			take = true
		elif not is_nan(prefer_h):
			if spine_height_better(coping_floor, best_h, prefer_h):
				take = true
			elif absf(coping_floor - best_h) <= 0.001 and gap < best_gap:
				take = true
		elif gap < best_gap:
			take = true
		if take:
			best = hit
			best_gap = gap
			best_h = coping_floor
	return best


## Opposite-facing TOP coping within 0..SPINE_GAP_MAX_CELLS of `from_x` (logical X).
## Gap is |Δcoping_x| only — aligned opposite stacks (|Δx|≈0) are valid. No screen /
## perspective. Want side = opposite of `exclude_side` (pipe you're on).
## `behind_sign` is unused for filtering (call-site compat).
## Among matches: nearest coping floor at/below prefer_h, else nearest above.
static func find_spine_transfer_target(
	pipes: Array,
	from_x: float,
	logical_z: float,
	_behind_sign: float,
	exclude_side: int,
	exclude_lip_x: float,
	cell_w: float,
	eps: float = 0.05,
	prefer_h: float = NAN,
	spec: Variant = null,
) -> Dictionary:
	# behind_sign kept for call-site compat; want side = opposite(exclude_side).
	var want_side := spine_opposite_side(exclude_side)
	var max_dist := float(SPINE_GAP_MAX_CELLS) * maxf(cell_w, 0.001) + eps
	var candidates: Array = []

	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if int(pipe.side) == exclude_side and absf(float(pipe.lip_x) - exclude_lip_x) < 0.05:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var hit: Dictionary = _pipe_hit_dict(pipe)
		var gap: float = absf(float(hit.top_coping) - from_x)
		# Logical X gap only (aligned = 0). Never screen / perspective.
		if gap > max_dist:
			continue
		candidates.append(hit)

	if spec != null:
		for ghit in _spine_candidates_from_glyphs(
			spec, pipes, from_x, logical_z, want_side, exclude_side, exclude_lip_x
		):
			var ggap: float = absf(float(ghit.get("top_coping", from_x)) - from_x)
			if ggap <= max_dist:
				candidates.append(ghit)

	return _pick_spine_candidate(candidates, from_x, prefer_h)


## Nearest other pipe whose coping lies behind us (spine / back-to-back).
static func find_pipe_behind(
	pipes: Array,
	from_x: float,
	logical_z: float,
	behind: float,
	exclude_side: int,
	exclude_lip_x: float,
) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for pipe in pipes:
		if int(pipe.side) == exclude_side and absf(float(pipe.lip_x) - exclude_lip_x) < 0.05:
			continue
		if logical_z < float(pipe.z_min) - 0.001 or logical_z > float(pipe.z_max) + 0.001:
			continue
		var side: int = int(pipe.side)
		var lip: float = float(pipe.lip_x)
		var radius: float = float(pipe.radius)
		var coping: float = _PipeMath.coping_x(side, lip, radius)
		var dist: float = (coping - from_x) * behind
		# Allow shared coping (dist ~ 0) and nearby opposite transitions.
		if dist < -0.05 or dist > maxf(radius * 2.0, 200.0):
			continue
		var score: float = absf(dist)
		if score < best_dist:
			best_dist = score
			best = {
				"active": true,
				"zone": _PipeMath.zone_name(side),
				"side": side,
				"lip_x": lip,
				"radius": radius,
				"base_height": _pipe_base_height(pipe),
				"layer": _pipe_layer(pipe),
			}
	return best
