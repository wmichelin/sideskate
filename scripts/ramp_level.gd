class_name RampLevel
extends Node2D
## Level runtime: loads .ssk, samples floor/deck/pipes, projects to screen.

const _PerspectiveMath := preload("res://scripts/perspective_math.gd")
const ContactMath := preload("res://scripts/contact_math.gd")

@export var level_path: String = "res://levels/layers.ssk"

@export_group("World scale")
## Logical units per ASCII column. Level width = columns × this.
@export var cell_size_x: float = 47.0
## Logical units per ASCII row. Level depth = rows × this.
## Default matches cell_size_x so one glyph is square in world space.
@export var cell_size_z: float = 47.0
## Per-glyph-cell pipe/ramp rise. Below cell_size_x → ramps under 45°.
## TUNING slider / reload forces this over any `.ssk` `step_height` header.
@export var step_height: float = 40.0

@export_group("Perspective")
## Screen Y of the near edge (z_min). Larger Y = lower on screen.
@export var near_screen_y: float = 560.0
## Screen Y at `reference_depth` units past z_min (not at z_max). Deep levels
## keep the same px/Z so they extend off-frame instead of compressing.
@export var far_screen_y: float = 300.0
## Logical depth span that maps near_screen_y → far_screen_y.
## Default matches glyph cells: one Z cell ≈ one X cell on screen at the near plane.
@export var reference_depth: float = 500.0
## Logical width used only for X convergence math — not the level's real span.
@export var reference_width: float = 1280.0
## X convergence toward the skater. 0 = side-on truck (parallel edges, camera
## slides in Z). Higher values tilt into a looking-down vanishing point.
@export var perspective_inset: float = 155.0
@export var far_geometry_scale: float = 1.0

signal rebuilt

var spec: LevelSpec
var pipes: Array = []  # QuarterPipe nodes

var z_min: float = 0.0
var z_max: float = 100.0
## Far X converges toward the skater so adjacent pipes share lean.
var perspective_origin_x: float = 640.0
## Z lean anchor — locked to the skater so depth stick re-perspectives the park
## (nearer / farther geometry widens or converges as you truck in Z).
var perspective_origin_z: float = 0.0
## Skater Z for draw-band culling (kept in sync with perspective_origin_z).
var view_origin_z: float = 0.0
var _loaded_path: String = ""
## Cached focal / far scale for project_screen (avoids recomputing per vertex).
var _proj_focal: float = 1.0
var _proj_far_scale: float = 1.0
var _proj_cache_ref: float = NAN
var _proj_cache_inset: float = NAN
var _proj_cache_width: float = NAN

@onready var _visual: Node2D = get_node_or_null("RampVisual") as Node2D


func _ready() -> void:
	var path := level_path
	if GameSession.pending_level_path != "":
		path = GameSession.pending_level_path
	if path != "":
		load_level(path)


func load_level(path: String) -> bool:
	_loaded_path = path
	level_path = path
	LevelLoader.cell_size_x = cell_size_x
	LevelLoader.cell_size_z = cell_size_z
	LevelLoader.default_step_height = step_height
	var loaded: LevelSpec = LevelLoader.load_path(
		path, cell_size_x, cell_size_z, step_height
	)
	# load_path aborts the process on malformed files; null is only possible if quit is deferred.
	if loaded == null:
		return false
	apply_spec(loaded)
	rebuilt.emit()
	return true


## Re-parse the current .ssk with the active cell / step sizes (debug tuning).
func reload() -> bool:
	var path := _loaded_path if _loaded_path != "" else level_path
	if path == "":
		return false
	return load_level(path)


func apply_spec(s: LevelSpec) -> void:
	spec = s
	z_min = s.z_min
	z_max = s.z_max

	# Clear previous pipe nodes
	for p in pipes:
		if is_instance_valid(p):
			p.queue_free()
	pipes.clear()

	for pd in s.pipes:
		var n := QuarterPipe.new()
		n.side = pd.side
		n.lip_x = pd.lip_x
		n.radius = pd.radius
		n.rise = float(pd.get("rise", pd.radius))
		n.base_height = float(pd.get("base_height", 0.0))
		n.layer = int(pd.get("layer", 0))
		n.z_min = pd.z_min
		n.z_max = pd.z_max
		n.kind = str(pd.get("kind", "pipe"))
		add_child(n)
		pipes.append(n)

	if spec:
		perspective_origin_x = spec.spawn_x
		view_origin_z = spec.spawn_z
	sync_lean_origin_z()
	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


## Keep lean Z locked to the current view / skater truck.
func sync_lean_origin_z() -> void:
	perspective_origin_z = view_origin_z


## Keep near-plane screen size of one Z cell matched to one X cell.
func sync_reference_depth_to_glyphs() -> void:
	reference_depth = _PerspectiveMath.glyph_matched_reference_depth(
		near_screen_y, far_screen_y, cell_size_x, cell_size_z
	)
	sync_lean_origin_z()


## Lock camera to the skater (homogeneous depth origin). Draw-band refresh is
## thresholded; origins still update every call for smooth projective truck.
func set_perspective_origin(logical_x: float, logical_z: float) -> void:
	var x_moved := absf(logical_x - perspective_origin_x) >= 6.0
	var z_moved := absf(logical_z - view_origin_z) >= 8.0
	perspective_origin_x = logical_x
	perspective_origin_z = logical_z
	view_origin_z = logical_z
	if not x_moved and not z_moved:
		return
	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


func depth_t(logical_z: float) -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


## Camera-relative lean rate (linear band param; projection uses depth_scale).
func perspective_t(logical_z: float) -> float:
	return _PerspectiveMath.perspective_t(logical_z, perspective_origin_z, reference_depth)


## Homogeneous depth scale at this Z (1 on the skater's focus plane).
func geometry_scale_at(logical_z: float) -> float:
	return (
		_PerspectiveMath.depth_scale(
			logical_z,
			perspective_origin_z,
			reference_depth,
			perspective_inset,
			reference_width
		)
		* maxf(far_geometry_scale, 0.01)
	)


func inset_at(logical_z: float) -> float:
	return _PerspectiveMath.inset_at(perspective_t(logical_z), perspective_inset)


## Pixels of screen-Y per logical Z unit (near edge → farther = smaller Y).
func screen_y_per_z() -> float:
	return _PerspectiveMath.screen_y_per_z(near_screen_y, far_screen_y, reference_depth)


func ground_screen_y(logical_z: float) -> float:
	# Same homogeneous depth scale as X — skater focus plane sits at mid-screen.
	return _PerspectiveMath.ground_screen_y(
		logical_z,
		perspective_origin_z,
		near_screen_y,
		far_screen_y,
		reference_depth,
		perspective_inset,
		reference_width
	)


func x_min() -> float:
	if spec:
		return spec.x_min
	return 0.0


func x_max() -> float:
	if spec:
		return spec.x_max
	return 1280.0


## Prefer a specific pipe first (side + lip [+ base_height + Z span]). Stops spine
## neighbors that share a coping X — and stacked-layer pipes that share lip —
## from stealing the sample while still riding.
## `prefer_h`: topmost surface at or below feet/support; else nearest below.
## `prefer_base_h`: with sticky side/lip, only that story's pipe sticks.
func sample(
	logical_x: float,
	logical_z: float,
	prefer_side: int = -1,
	prefer_lip_x: float = NAN,
	prefer_h: float = NAN,
	prefer_base_h: float = NAN,
	prefer_z_min: float = NAN,
	prefer_z_max: float = NAN,
) -> Dictionary:
	if prefer_side >= 0 and not is_nan(prefer_lip_x):
		var sticky: Array = []
		var matched_identity := false
		for pipe in pipes:
			if int(pipe.side) != prefer_side:
				continue
			if absf(pipe.lip_x - prefer_lip_x) > 0.05:
				continue
			if not is_nan(prefer_base_h) and absf(pipe.base_height - prefer_base_h) > 0.5:
				continue
			if not is_nan(prefer_z_min) and absf(pipe.z_min - prefer_z_min) > 0.05:
				continue
			if not is_nan(prefer_z_max) and absf(pipe.z_max - prefer_z_max) > 0.05:
				continue
			matched_identity = true
			var preferred: Dictionary = pipe.query_surface(logical_x, logical_z)
			if preferred.get("active", false):
				sticky.append(preferred)
		if not sticky.is_empty():
			if is_nan(prefer_h):
				return ContactMath.pick_highest(sticky)
			return _pick_sticky_by_prefer_h(sticky, prefer_h)
		# Sticky identity known but footprint inactive (e.g. past L1 coping while
		# stacked L0 still covers this X). Never fall through to another pipe.
		if matched_identity:
			return {"active": false}

	var candidates: Array = sample_candidates(logical_x, logical_z)
	if candidates.is_empty():
		# Never label playable XZ as oob (deck poly edge / hole / clamp lag).
		return _fallback_hit(logical_x, logical_z, prefer_h)
	if is_nan(prefer_h):
		return ContactMath.pick_highest(candidates)
	return ContactMath.pick_by_prefer_h(candidates, prefer_h)


## Active pipe in the story selected at the player's feet. This prevents a
## lower stacked pipe/lava from displacing a visible upper-story pipe merely
## because that pipe's arc is above the current feet height.
func sample_pipe_on_story(logical_x: float, logical_z: float, prefer_h: float) -> Dictionary:
	if spec == null:
		return {}
	var cell := spec.cell_at(logical_x, logical_z)
	var ginfo: Dictionary = spec.glyph_at_prefer_h(cell.x, cell.y, prefer_h)
	if ContactMath.zone_from_glyph(str(ginfo.get("glyph", " "))) not in ["pipe", "ramp"]:
		return {}
	var layer := int(ginfo.get("layer", -1))
	var candidates: Array = []
	for pipe in pipes:
		if int(pipe.layer) != layer:
			continue
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			candidates.append(hit)
	if candidates.is_empty():
		return {}
	return ContactMath.pick_highest(candidates)


## Vertical sweep for air landing: returns {hit, height, crossed_solid}.
func sample_sweep(logical_x: float, logical_z: float, h0: float, h1: float) -> Dictionary:
	var candidates: Array = sample_candidates(logical_x, logical_z)
	if candidates.is_empty():
		var fb: Dictionary = _fallback_hit(logical_x, logical_z, maxf(h0, h1))
		if str(fb.get("zone", "")) == "hole" or not fb.get("active", true):
			return {"hit": fb, "height": float(fb.get("height", 0.0)), "crossed_solid": false}
		candidates = [fb]
	return ContactMath.resolve_vertical(candidates, h0, h1)


func sample_candidates(logical_x: float, logical_z: float) -> Array:
	var out: Array = []
	for pipe in pipes:
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			out.append(hit)
	var p := Vector2(logical_x, logical_z)
	if spec:
		var deck_heights := {}
		for deck in spec.decks:
			if LevelSpec.point_in_poly(p, deck.poly):
				var dh: Dictionary = _deck_hit(deck)
				out.append(dh)
				deck_heights[float(dh.get("height", 0.0))] = true
		var cell := spec.cell_at(logical_x, logical_z)
		# `#` cells always contribute their deck even when the outline poly
		# excludes the half-open edge (walk-off → false oob while still playable).
		if spec.grid_w > 0 and cell.x >= 0 and cell.y >= 0 \
				and cell.x < spec.grid_w and cell.y < spec.grid_h:
			for L in spec.layers:
				var rows: PackedStringArray = L.get("rows", PackedStringArray())
				if cell.y >= rows.size():
					continue
				var line: String = rows[cell.y]
				if cell.x >= line.length() or line[cell.x] != "#":
					continue
				var layer_i := int(L.get("index", -1))
				var deck_hit: Dictionary = _deck_hit_for_layer(layer_i)
				if deck_hit.is_empty():
					continue
				var h := float(deck_hit.get("height", 0.0))
				if deck_heights.has(h):
					continue
				out.append(deck_hit)
				deck_heights[h] = true
		if not spec.story_floor_masks.is_empty() and spec.grid_w > 0:
			for story in spec.story_floor_masks:
				var mask: PackedByteArray = story.get("mask", PackedByteArray())
				if mask.size() < spec.grid_w * spec.grid_h:
					continue
				if cell.x < 0 or cell.y < 0 or cell.x >= spec.grid_w or cell.y >= spec.grid_h:
					continue
				if mask[cell.y * spec.grid_w + cell.x] != 0:
					var pad_zone := "flat"
					if mask[cell.y * spec.grid_w + cell.x] == 2:
						pad_zone = "lava"
					out.append(_flat_hit(
						true,
						pad_zone,
						float(story.get("height", 0.0)),
						int(story.get("layer", -1)),
					))
		else:
			for h in spec.floor_heights_at(logical_x, logical_z):
				out.append(_flat_hit(true, "flat", float(h)))
	return out


## When candidates are empty: playable cell → glyph surface / hole; outside → hole
## (pose should clamp). Never returns zone `oob`.
func _fallback_hit(logical_x: float, logical_z: float, prefer_h: float = NAN) -> Dictionary:
	if spec == null:
		return _flat_hit(false, "hole", 0.0, 0)
	if not spec.is_playable_xz(logical_x, logical_z):
		return _flat_hit(false, "hole", 0.0, 0)
	var cell := spec.cell_at(logical_x, logical_z)
	var ph := prefer_h
	if is_nan(ph):
		ph = INF
	var ginfo: Dictionary = spec.glyph_at_prefer_h(cell.x, cell.y, ph)
	var glyph := str(ginfo.get("glyph", " "))
	var layer := int(ginfo.get("layer", -1))
	var layer_h := float(ginfo.get("layer_height", 0.0))
	var gzone := ContactMath.zone_from_glyph(glyph)
	match gzone:
		"hole":
			return _flat_hit(false, "hole", layer_h, layer)
		"deck":
			var deck_hit: Dictionary = _deck_hit_for_layer(layer)
			if not deck_hit.is_empty():
				return deck_hit
			return _flat_hit(true, "deck", layer_h, layer)
		"lava":
			return _flat_hit(true, "lava", maxf(layer_h, 0.0), maxi(layer, 0))
		"pipe":
			for pipe in pipes:
				if pipe.is_ramp():
					continue
				var q: Dictionary = pipe.query_surface(logical_x, logical_z)
				if q.get("active", false):
					return q
			return _flat_hit(true, "flat", maxf(layer_h, 0.0), maxi(layer, 0))
		"ramp":
			for pipe in pipes:
				if not pipe.is_ramp():
					continue
				var rq: Dictionary = pipe.query_surface(logical_x, logical_z)
				if rq.get("active", false):
					return rq
			return _flat_hit(true, "flat", maxf(layer_h, 0.0), maxi(layer, 0))
		"oob":
			return _flat_hit(false, "hole", 0.0, maxi(layer, 0))
		_:
			return _flat_hit(true, "flat", maxf(layer_h, 0.0), maxi(layer, 0))


func _deck_hit_for_layer(layer: int) -> Dictionary:
	if spec == null:
		return {}
	for deck in spec.decks:
		if layer >= 0 and int(deck.get("layer", -1)) != layer:
			continue
		return _deck_hit(deck)
	return {}


## Facing cast — pure math lives in FacingCastMath; these wrap the level's
## spec + pipes for gameplay / debug callers.
func cast_surface_at(logical_x: float, logical_z: float, prefer_h: float) -> Dictionary:
	return FacingCastMath.resolve_surface(spec, pipes, logical_x, logical_z, prefer_h)


func cast_surface_height(logical_x: float, logical_z: float, prefer_h: float) -> float:
	return FacingCastMath.resolve_height(spec, pipes, logical_x, logical_z, prefer_h)


## Full facing cast from a grid origin (cells + surfaces). See FacingCastMath.cast_ahead.
func facing_cast(
	origin_col: int,
	origin_row: int,
	facing_h: String,
	distance: int,
	trail_z: float,
	prefer_h: float,
) -> Array:
	return FacingCastMath.cast_ahead(
		spec, pipes, origin_col, origin_row, facing_h, distance, trail_z, prefer_h
	)


## Sticky side+lip: highest story whose base is at/below feet.
func _pick_sticky_by_prefer_h(sticky: Array, prefer_h: float) -> Dictionary:
	var land_eps := ContactMath.LAND_EPS
	var best: Dictionary = {}
	var best_base := -INF
	var best_h := -INF
	for c in sticky:
		var base := float(c.get("base_height", 0.0))
		if base > prefer_h + land_eps:
			continue
		var h := float(c.get("height", 0.0))
		if base > best_base + 0.001 or (absf(base - best_base) <= 0.001 and h > best_h):
			best = c
			best_base = base
			best_h = h
	if not best.is_empty():
		return best
	return ContactMath.pick_by_prefer_h(sticky, prefer_h)


func _deck_hit(deck: Dictionary) -> Dictionary:
	return {
		"active": true,
		"zone": "deck",
		"height": float(deck.height),
		"angle": 0.0,
		"theta": 0.0,
		"normal_x": 0.0,
		"normal_y": 1.0,
		"t_along_pipe": 0.0,
		"deck": deck,
		"base_height": float(deck.get("base_height", 0.0)),
		"layer": int(deck.get("layer", -1)),
	}


func _flat_hit(
	active: bool, zone: String = "flat", height: float = 0.0, layer: int = -1
) -> Dictionary:
	return {
		"active": active,
		"zone": zone,
		"height": height,
		"angle": 0.0,
		"theta": 0.0,
		"normal_x": 0.0,
		"normal_y": 1.0,
		"t_along_pipe": 0.0,
		"base_height": height,
		"layer": layer,
	}


## Project a world point for gameplay visuals.
func project_surface(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	return project(logical_x, logical_z, surface_height)


## Decks use the same projector as everything else (logical X → perspective lerp).
## Top height follows adjacent pipe screen-circles so the pad meets the ramp tops.
func project_deck_point(deck: Dictionary, logical_x: float, logical_z: float) -> Dictionary:
	return project(logical_x, logical_z, deck_visual_height(deck, logical_z))


## Logical height for drawing a deck top at `logical_z`: matches the tallest
## adjacent pipe's screen-space quarter-circle rise (glyph width → circle radius).
## Under homogeneous projection, screen radius / gscale = |lip−coping| / far_g
## (depth scale cancels), so this is Z-independent — no per-vertex project.
func deck_visual_height(deck: Dictionary, _logical_z: float = 0.0) -> float:
	var base := float(deck.get("base_height", 0.0))
	var anchors: Array = deck.get("anchors", [])
	if anchors.is_empty():
		return float(deck.get("height", base))
	var rise := 0.0
	var any := false
	var g := maxf(far_geometry_scale, 0.01)
	for anchor in anchors:
		var lip := float(anchor.get("lip_x", NAN))
		var coping := float(anchor.get("coping_x", NAN))
		if is_nan(lip) or is_nan(coping):
			continue
		rise = maxf(rise, absf(coping - lip) / g)
		any = true
	if not any:
		return float(deck.get("height", base))
	return base + rise


## Project logical (x,z,height) to screen.
## Camera at (perspective_origin_x, perspective_origin_z): X converges toward the
## skater and ground Y shares the same depth `t` so Z motion does not shear.
## Height uses geometry_scale alone. X lean uses reference_width (not level span)
## so wider maps keep the same vanishing rate as a single bay.
func project(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	return _PerspectiveMath.project(
		logical_x,
		logical_z,
		surface_height,
		perspective_origin_x,
		perspective_origin_z,
		near_screen_y,
		far_screen_y,
		reference_depth,
		reference_width,
		perspective_inset,
		far_geometry_scale
	)


## Fast screen position (no Dictionary). Prefer this in draw hot paths.
func project_screen(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Vector2:
	_ensure_proj_cache()
	return _PerspectiveMath.project_screen(
		logical_x,
		logical_z,
		surface_height,
		perspective_origin_x,
		perspective_origin_z,
		near_screen_y,
		far_screen_y,
		_proj_focal,
		_proj_far_scale,
		far_geometry_scale
	)


## Screen-space profile (θ=0 lip → θ=π/2 coping).
## Pipes: quarter circle. Ramps: straight incline.
func pipe_screen_point_for(pipe: QuarterPipe, logical_z: float, u: float) -> Vector2:
	var frame := pipe_arc_frame(pipe, logical_z)
	return pipe_arc_point(frame, u)


## Lip / radius / center for one pipe cross-section (two projects, reused for all u).
func pipe_arc_frame(pipe: QuarterPipe, logical_z: float) -> Dictionary:
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var coping_x := pipe.x_min() if is_left else pipe.x_max()
	var lip := project_screen(pipe.lip_x, logical_z, pipe.base_height)
	var cope_flat := project_screen(coping_x, logical_z, pipe.base_height)
	var cope_peak := project_screen(coping_x, logical_z, pipe.base_height + pipe.effective_rise())
	var r := absf(cope_flat.x - lip.x)
	return {
		"lip": lip,
		"peak": cope_peak,
		"r": r,
		"center": Vector2(lip.x, lip.y - r),
		"sgn": -1.0 if is_left else 1.0,
		"is_ramp": pipe.is_ramp(),
	}


func pipe_arc_point(frame: Dictionary, u: float) -> Vector2:
	var uu := clampf(u, 0.0, 1.0)
	if bool(frame.get("is_ramp", false)):
		var lip: Vector2 = frame.lip
		var peak: Vector2 = frame.peak
		return lip.lerp(peak, uu)
	var r: float = float(frame.r)
	var lip_p: Vector2 = frame.lip
	if r <= 0.0001:
		return lip_p
	var theta := uu * PI * 0.5
	var center: Vector2 = frame.center
	var sgn: float = float(frame.sgn)
	return Vector2(center.x + sgn * r * sin(theta), center.y + r * cos(theta))


## Cached focal / far scale (only depends on inset / ref depth / width).
func _ensure_proj_cache() -> void:
	if (
		_proj_cache_ref == reference_depth
		and _proj_cache_inset == perspective_inset
		and _proj_cache_width == reference_width
	):
		return
	_proj_far_scale = _PerspectiveMath.far_x_scale(perspective_inset, reference_width)
	_proj_focal = _proj_far_scale * (maxf(reference_depth, 0.0001) * 0.5) / maxf(
		1.0 - _proj_far_scale, 0.01
	)
	_proj_cache_ref = reference_depth
	_proj_cache_inset = perspective_inset
	_proj_cache_width = reference_width


func invalidate_proj_cache() -> void:
	_proj_cache_ref = NAN
