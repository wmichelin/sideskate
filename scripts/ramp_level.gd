class_name RampLevel
extends Node2D
## Level runtime: loads .ssk, samples floor/deck/pipes, projects to screen.

const _PerspectiveMath := preload("res://scripts/perspective_math.gd")
const ContactMath := preload("res://scripts/contact_math.gd")

@export var level_path: String = "res://levels/plaza_default.ssk"

@export_group("World scale")
## Logical units per ASCII column. Level width = columns × this.
@export var cell_size_x: float = 47.0
## Logical units per ASCII row. Level depth = rows × this.
@export var cell_size_z: float = 26.0

@export_group("Perspective")
## Screen Y of the near edge (z_min). Larger Y = lower on screen.
@export var near_screen_y: float = 560.0
## Screen Y at `reference_depth` units past z_min (not at z_max). Deep levels
## keep the same px/Z so they extend off-frame instead of compressing.
@export var far_screen_y: float = 300.0
## Logical depth span that maps near_screen_y → far_screen_y.
@export var reference_depth: float = 485.0
## Logical width used only for X convergence math — not the level's real span.
@export var reference_width: float = 1280.0
## X convergence toward the skater. 0 = side-on truck (parallel edges, camera
## slides in Z). Higher values tilt into a looking-down vanishing point.
@export var perspective_inset: float = 70.0
@export var far_geometry_scale: float = 1.0

signal rebuilt

var spec: LevelSpec
var pipes: Array = []  # QuarterPipe nodes

var z_min: float = 0.0
var z_max: float = 100.0
## Far X converges toward the skater so adjacent pipes share lean.
var perspective_origin_x: float = 640.0
## World-fixed Z lean anchor (z_min + reference_depth/2). Depth stick only trucks
## the camera / draw window — it must not re-center X perspective.
var perspective_origin_z: float = 0.0
## Skater Z for draw-band culling only (not used for lean / x_scale).
var view_origin_z: float = 0.0
var _loaded_path: String = ""

@onready var _visual: Node2D = $RampVisual


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
	var loaded: LevelSpec = LevelLoader.load_path(path, cell_size_x, cell_size_z)
	# load_path aborts the process on malformed files; null is only possible if quit is deferred.
	if loaded == null:
		return false
	apply_spec(loaded)
	rebuilt.emit()
	return true


## Re-parse the current .ssk with the active cell sizes (debug tuning).
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
		n.base_height = float(pd.get("base_height", 0.0))
		n.layer = int(pd.get("layer", 0))
		n.z_min = pd.z_min
		n.z_max = pd.z_max
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


## Absolute lean band: t=0 at z_min, t=1 at z_min+reference_depth.
func sync_lean_origin_z() -> void:
	perspective_origin_z = z_min + reference_depth * 0.5


## Skater X recenters horizontal lean. Skater Z only moves the draw window
## (up/down truck) — never perspective_origin_z.
## Threshold avoids redrawing the whole park every physics tick while skating.
func set_perspective_origin(logical_x: float, logical_z: float) -> void:
	var x_moved := absf(logical_x - perspective_origin_x) >= 2.0
	var z_moved := absf(logical_z - view_origin_z) >= 4.0
	if not x_moved and not z_moved:
		return
	if x_moved:
		perspective_origin_x = logical_x
	if z_moved:
		view_origin_z = logical_z
	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


func depth_t(logical_z: float) -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


## Lean rate vs world-fixed origin_z. Unclamped so lip lines keep one slope.
func perspective_t(logical_z: float) -> float:
	return _PerspectiveMath.perspective_t(logical_z, perspective_origin_z, reference_depth)


func geometry_scale_at(logical_z: float) -> float:
	return _PerspectiveMath.geometry_scale_at(perspective_t(logical_z), far_geometry_scale)


func inset_at(logical_z: float) -> float:
	return _PerspectiveMath.inset_at(perspective_t(logical_z), perspective_inset)


## Pixels of screen-Y per logical Z unit (near edge → farther = smaller Y).
func screen_y_per_z() -> float:
	return _PerspectiveMath.screen_y_per_z(near_screen_y, far_screen_y, reference_depth)


func ground_screen_y(logical_z: float) -> float:
	# Absolute mapping — deep levels grow taller in screen space and stay off-frame
	# until the camera pans with the player.
	return _PerspectiveMath.ground_screen_y(
		logical_z, z_min, near_screen_y, far_screen_y, reference_depth
	)


func x_min() -> float:
	if spec:
		return spec.x_min
	return 0.0


func x_max() -> float:
	if spec:
		return spec.x_max
	return 1280.0


## Prefer a specific pipe first (side + lip [+ base_height]). Stops spine
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
) -> Dictionary:
	if prefer_side >= 0 and not is_nan(prefer_lip_x):
		var sticky: Array = []
		for pipe in pipes:
			if int(pipe.side) != prefer_side:
				continue
			if absf(pipe.lip_x - prefer_lip_x) > 0.05:
				continue
			if not is_nan(prefer_base_h) and absf(pipe.base_height - prefer_base_h) > 0.5:
				continue
			var preferred: Dictionary = pipe.query_surface(logical_x, logical_z)
			if preferred.get("active", false):
				sticky.append(preferred)
		if not sticky.is_empty():
			if is_nan(prefer_h):
				return ContactMath.pick_highest(sticky)
			return _pick_sticky_by_prefer_h(sticky, prefer_h)

	var candidates: Array = sample_candidates(logical_x, logical_z)
	if candidates.is_empty():
		# Never label playable XZ as oob (deck poly edge / hole / clamp lag).
		return _fallback_hit(logical_x, logical_z, prefer_h)
	if is_nan(prefer_h):
		return ContactMath.pick_highest(candidates)
	return ContactMath.pick_by_prefer_h(candidates, prefer_h)


## Vertical sweep for air landing: returns {hit, height, crossed_solid}.
func sample_sweep(logical_x: float, logical_z: float, h0: float, h1: float) -> Dictionary:
	var candidates: Array = sample_candidates(logical_x, logical_z)
	if candidates.is_empty():
		var fb: Dictionary = _fallback_hit(logical_x, logical_z, maxf(h0, h1))
		if str(fb.get("zone", "")) == "hole" or not fb.get("active", true):
			return {"hit": fb, "height": float(fb.get("height", 0.0)), "crossed_solid": false}
		candidates = [fb]
	return ContactMath.resolve_vertical(candidates, h0, h1)


## Single air-contact resolve for label + collision.
## Zone matches cell highlight: `sample(x,z,prefer_h)` (+ hole glyph).
## Sticky pipe only overrides when that footprint is still under us AND the
## highlight sample is the same pipe or has already fallen below it (no tunnel).
## Returns ContactMath.make_air_contact(...).
func resolve_air_contact(
	logical_x: float,
	logical_z: float,
	prefer_h: float,
	sticky_side: int = -1,
	sticky_lip_x: float = NAN,
	sticky_base_h: float = NAN,
) -> Dictionary:
	if spec == null:
		return ContactMath.make_air_contact("oob", -1, 0.0, false, _flat_hit(false, "oob", 0.0))

	# Same underfoot sample as cell highlight.
	var highlight: Dictionary = sample(logical_x, logical_z, -1, NAN, prefer_h)
	var cell := spec.cell_at(logical_x, logical_z)
	var ginfo: Dictionary = spec.glyph_at_prefer_h(cell.x, cell.y, prefer_h)
	var glyph := str(ginfo.get("glyph", " "))
	var layer := int(ginfo.get("layer", -1))
	var layer_h := float(ginfo.get("layer_height", 0.0))
	var gzone := ContactMath.zone_from_glyph(glyph)

	# Hole on this story — first-class, even if a lower surface samples below.
	if gzone == "hole":
		return ContactMath.make_air_contact("hole", layer, layer_h, false, {})

	# Deck glyph: keep deck solid even when outline poly misses the cell edge.
	if gzone == "deck":
		var deck_hit: Dictionary = _deck_hit_for_layer(layer)
		if not deck_hit.is_empty():
			var deck_h := float(deck_hit.get("height", layer_h))
			if is_nan(prefer_h) or prefer_h + ContactMath.LAND_EPS >= deck_h:
				return ContactMath.make_air_contact("deck", layer, deck_h, true, deck_hit)

	# Sticky: only if still in footprint and highlight agrees or dipped under the pipe.
	var sticky: Dictionary = {}
	if sticky_side >= 0 and not is_nan(sticky_lip_x):
		for pipe in pipes:
			if int(pipe.side) != sticky_side:
				continue
			if absf(pipe.lip_x - sticky_lip_x) > 0.05:
				continue
			if not is_nan(sticky_base_h) and absf(pipe.base_height - sticky_base_h) > 0.5:
				continue
			var q: Dictionary = pipe.query_surface(logical_x, logical_z)
			if q.get("active", false):
				sticky = q.duplicate()
				sticky["radius"] = pipe.radius
				if not sticky.has("layer"):
					sticky["layer"] = int(pipe.layer)
				break
	if not sticky.is_empty():
		var sticky_h := float(sticky.get("height", 0.0))
		var use_sticky := false
		if highlight.is_empty() or (
			not highlight.get("active", true) and str(highlight.get("zone", "")) == "oob"
		):
			use_sticky = true
		elif ContactMath.same_pipe(highlight, sticky):
			use_sticky = true
		else:
			var hh := float(highlight.get("height", 0.0))
			# Highlight already below this pipe surface → dipped through; keep sticky solid.
			if hh < sticky_h - ContactMath.LAND_EPS:
				use_sticky = true
		if use_sticky:
			return ContactMath.make_air_contact(
				str(sticky.get("zone", "left_pipe")),
				int(sticky.get("layer", -1)),
				sticky_h,
				true,
				sticky,
			)

	var playable := spec.is_playable_xz(logical_x, logical_z)

	var hit: Dictionary = highlight
	if hit.is_empty() or (
		not hit.get("active", true) and str(hit.get("zone", "")) == "oob"
	):
		hit = _sample_on_layer(logical_x, logical_z, layer, layer_h, prefer_h)
	if hit.is_empty() or (
		not hit.get("active", true) and str(hit.get("zone", "")) == "oob"
	):
		# Still playable but no sample (e.g. hairline past pipe edge): never "oob".
		if playable:
			var any_hit: Dictionary = sample(logical_x, logical_z, -1, NAN, NAN)
			if not any_hit.is_empty() and (
				any_hit.get("active", true) or str(any_hit.get("zone", "")) != "oob"
			):
				hit = any_hit
			else:
				hit = _flat_hit(true, "flat", maxf(layer_h, 0.0), maxi(layer, 0))
		else:
			# Outside footprint — caller should clamp pose; still avoid oob zone.
			hit = _flat_hit(true, "flat", 0.0, 0)

	var zone := str(hit.get("zone", "flat"))
	if zone == "oob":
		zone = "flat"
		hit = _flat_hit(true, "flat", 0.0, maxi(layer, 0))
	if zone == "hole":
		return ContactMath.make_air_contact("hole", maxi(layer, 0), layer_h, false, hit)
	var hit_layer := int(hit.get("layer", layer))
	if hit_layer < 0:
		hit_layer = _layer_for_hit(hit, layer)
	return ContactMath.make_air_contact(
		zone,
		hit_layer,
		float(hit.get("height", 0.0)),
		true,
		hit,
	)


func _layer_for_hit(hit: Dictionary, fallback: int) -> int:
	if hit.has("layer") and int(hit.layer) >= 0:
		return int(hit.layer)
	if spec == null:
		return fallback
	var base := float(hit.get("base_height", hit.get("height", 0.0)))
	for L in spec.layers:
		if absf(float(L.get("height", 0.0)) - base) <= 0.5:
			return int(L.get("index", fallback))
	return fallback


func _sample_on_layer(
	logical_x: float,
	logical_z: float,
	layer: int,
	layer_h: float,
	prefer_h: float,
) -> Dictionary:
	for pipe in pipes:
		if layer >= 0 and int(pipe.layer) != layer:
			continue
		if layer < 0 and absf(pipe.base_height - layer_h) > 0.5:
			continue
		var ph: Dictionary = pipe.query_surface(logical_x, logical_z)
		if ph.get("active", false):
			ph = ph.duplicate()
			ph["radius"] = pipe.radius
			ph["layer"] = int(pipe.layer)
			return ph
	if spec:
		for h in spec.floor_heights_at(logical_x, logical_z):
			if absf(float(h) - layer_h) <= 0.5:
				return _flat_hit(true, "flat", float(h), layer)
		var p := Vector2(logical_x, logical_z)
		for deck in spec.decks:
			if layer >= 0 and int(deck.get("layer", -1)) != layer:
				continue
			if absf(float(deck.get("height", 0.0)) - layer_h) > 0.5 and layer >= 0:
				continue
			if LevelSpec.point_in_poly(p, deck.poly):
				return _deck_hit(deck)
	return sample(logical_x, logical_z, -1, NAN, prefer_h)


## Transfer probe: decks, other pipes, flats. Excludes the source pipe.
func sample_transfer(
	logical_x: float,
	logical_z: float,
	exclude_side: int,
	exclude_lip_x: float,
	prefer_h: float = NAN,
) -> Dictionary:
	var candidates: Array = []
	var p := Vector2(logical_x, logical_z)
	if spec:
		for deck in spec.decks:
			if LevelSpec.point_in_poly(p, deck.poly):
				candidates.append(_deck_hit(deck))

	for pipe in pipes:
		if pipe.side == exclude_side and absf(pipe.lip_x - exclude_lip_x) < 0.05:
			continue
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			hit["radius"] = pipe.radius
			candidates.append(hit)

	if spec:
		for h in spec.floor_heights_at(logical_x, logical_z):
			candidates.append(_flat_hit(true, "flat", float(h)))

	if candidates.is_empty():
		return _flat_hit(true, "flat", 0.0)
	if is_nan(prefer_h):
		return ContactMath.pick_highest(candidates)
	return ContactMath.pick_by_prefer_h(candidates, prefer_h)


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
					out.append(_flat_hit(
						true,
						"flat",
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
		"pipe":
			for pipe in pipes:
				var q: Dictionary = pipe.query_surface(logical_x, logical_z)
				if q.get("active", false):
					return q
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


## Facing-cast viz: glyph story at prefer_h → that story’s surface.
## Returns { height, zone, layer, is_coping, side, lip_x, radius, base_height }.
## Pipe cells use the matching layer’s pipe only. Holes fall through below that story.
func cast_surface_at(logical_x: float, logical_z: float, prefer_h: float) -> Dictionary:
	if spec == null or spec.grid_w <= 0:
		var fb: Dictionary = sample(logical_x, logical_z, -1, NAN, prefer_h)
		return {
			"height": float(fb.get("height", 0.0)),
			"zone": str(fb.get("zone", "flat")),
			"layer": int(fb.get("layer", -1)),
			"is_coping": false,
			"side": int(fb.get("side", -1)),
			"lip_x": float(fb.get("lip_x", NAN)),
			"radius": float(fb.get("radius", 0.0)),
			"base_height": float(fb.get("base_height", 0.0)),
		}
	var cell := spec.cell_at(logical_x, logical_z)
	return _cast_info_for_cell(cell.x, cell.y, logical_x, logical_z, prefer_h, 0)


func cast_surface_height(logical_x: float, logical_z: float, prefer_h: float) -> float:
	return float(cast_surface_at(logical_x, logical_z, prefer_h).get("height", 0.0))


func _cast_info_for_cell(
	col: int,
	row: int,
	logical_x: float,
	logical_z: float,
	prefer_h: float,
	depth: int,
) -> Dictionary:
	var empty := {
		"height": 0.0,
		"zone": "hole",
		"layer": -1,
		"is_coping": false,
		"side": -1,
		"lip_x": NAN,
		"radius": 0.0,
		"base_height": 0.0,
	}
	if depth > 8:
		return empty
	var ginfo: Dictionary = spec.glyph_at_prefer_h(col, row, prefer_h)
	var glyph := str(ginfo.get("glyph", " "))
	var layer := int(ginfo.get("layer", -1))
	var layer_h := float(ginfo.get("layer_height", 0.0))
	var gzone := ContactMath.zone_from_glyph(glyph)
	match gzone:
		"pipe":
			var want_side := 0 if glyph == "<" else 1
			var pipe_info: Dictionary = _pipe_info_on_layer(
				logical_x, logical_z, want_side, layer, col, row
			)
			if pipe_info.is_empty():
				var mid: Dictionary = spec.cell_bounds(col, row)
				var mx := (float(mid.x0) + float(mid.x1)) * 0.5
				pipe_info = _pipe_info_on_layer(mx, logical_z, want_side, layer, col, row)
			if pipe_info.is_empty():
				return {
					"height": layer_h,
					"zone": "pipe",
					"layer": layer,
					"is_coping": false,
					"side": want_side,
					"lip_x": NAN,
					"radius": 0.0,
					"base_height": layer_h,
				}
			return pipe_info
		"flat":
			return {
				"height": layer_h,
				"zone": "flat",
				"layer": layer,
				"is_coping": false,
				"side": -1,
				"lip_x": NAN,
				"radius": 0.0,
				"base_height": layer_h,
			}
		"deck":
			var deck: Dictionary = _deck_hit_for_layer(layer)
			var dh := layer_h
			if not deck.is_empty():
				dh = float(deck.get("height", layer_h))
			return {
				"height": dh,
				"zone": "deck",
				"layer": layer,
				"is_coping": false,
				"side": -1,
				"lip_x": NAN,
				"radius": 0.0,
				"base_height": layer_h,
			}
		"hole":
			# Must drop prefer below this story’s glyph window (LAND_EPS band).
			var below := layer_h - ContactMath.LAND_EPS - 0.05
			if below < -0.01 and layer_h <= 0.0:
				return empty
			return _cast_info_for_cell(
				col, row, logical_x, logical_z, below, depth + 1
			)
		_:
			var hit: Dictionary = sample(logical_x, logical_z, -1, NAN, prefer_h)
			return {
				"height": float(hit.get("height", 0.0)),
				"zone": str(hit.get("zone", "flat")),
				"layer": int(hit.get("layer", -1)),
				"is_coping": false,
				"side": int(hit.get("side", -1)),
				"lip_x": float(hit.get("lip_x", NAN)),
				"radius": float(hit.get("radius", 0.0)),
				"base_height": float(hit.get("base_height", 0.0)),
			}


func _pipe_info_on_layer(
	logical_x: float,
	logical_z: float,
	want_side: int,
	layer: int,
	col: int,
	row: int,
) -> Dictionary:
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if layer >= 0 and int(pipe.layer) != layer:
			continue
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if not hit.get("active", false):
			continue
		var lip := float(pipe.lip_x)
		var radius := float(pipe.radius)
		var side := int(pipe.side)
		var cope := PipeMath.coping_x(side, lip, radius)
		var is_cope := false
		if spec != null:
			var b: Dictionary = spec.cell_bounds(col, row)
			# Cell owns coping if cope lies in [x0, x1] (inclusive edges).
			is_cope = cope >= float(b.x0) - 0.05 and cope <= float(b.x1) + 0.05
		else:
			is_cope = AerialMath.is_top_coping(side, lip, radius, logical_x, 0.5 * radius)
		return {
			"height": float(hit.get("height", 0.0)),
			"zone": str(hit.get("zone", "pipe")),
			"layer": layer,
			"is_coping": is_cope,
			"side": side,
			"lip_x": lip,
			"radius": radius,
			"base_height": float(pipe.base_height),
			"top_coping": cope,
			"theta": float(hit.get("theta", 0.0)),
		}
	return {}


func _pipe_height_on_layer(
	logical_x: float, logical_z: float, want_side: int, layer: int
) -> float:
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		if layer >= 0 and int(pipe.layer) != layer:
			continue
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			return float(hit.get("height", 0.0))
	return NAN


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
func project_deck_point(deck: Dictionary, logical_x: float, logical_z: float) -> Dictionary:
	return project(logical_x, logical_z, float(deck.height))


## Project logical (x,z,height) to screen.
## X scales toward perspective_origin_x with depth (same for floor/pipes/decks)
## so adjacent features share lean instead of fanning from the level midpoint.
## Height uses geometry_scale alone. X lean uses reference_width (not level span)
## so wider maps keep the same vanishing rate as a single bay.
func project(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	return _PerspectiveMath.project(
		logical_x,
		logical_z,
		surface_height,
		perspective_origin_x,
		perspective_origin_z,
		z_min,
		near_screen_y,
		far_screen_y,
		reference_depth,
		reference_width,
		perspective_inset,
		far_geometry_scale
	)


func pipe_screen_point_for(pipe: QuarterPipe, logical_z: float, u: float) -> Vector2:
	var theta := clampf(u, 0.0, 1.0) * PI * 0.5
	var x_off := pipe.radius * sin(theta)
	var height := pipe.base_height + pipe.radius * (1.0 - cos(theta))
	var logical_x: float
	if pipe.side == QuarterPipe.PipeSide.LEFT:
		logical_x = pipe.lip_x - x_off
	else:
		logical_x = pipe.lip_x + x_off
	var p := project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)
