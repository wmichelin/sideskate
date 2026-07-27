extends Node2D
## Surface-only level draw: floors, pipe ribbons, elevated deck tops.
## Far → Player → Near Z-split: nearer park geometry composites above the skater
## so the player is occluded when behind a ramp. Draw window follows skater Z
## (truck only). X lean uses world-fixed origin_z.

const _PassScript := preload("res://scripts/ramp_visual_pass.gd")

@export var grid_steps: int = 5
## How many iso-u depth strokes to split the pipe face into (not cross-section arcs).
@export var arc_ribs: int = 4
## Extra Z past the lean band on near and far sides, as a fraction of reference_depth.
@export_range(0.0, 4.0, 0.05) var draw_band_pad: float = 2.0
## Arc samples along the quarter-pipe profile (fill + ribs share this).
@export_range(4, 32, 1) var arc_steps: int = 16
## Faint white depth bands across the plaza. Off by default (debug clutter).
@export var show_depth_grid: bool = false
## Highlight the .ssk ASCII cell under the player (logical unit 1:1). Debug only.
@export var debug_cell_highlight: bool = false
## Green cells ahead of facing_h (logical X columns). Debug only; off by default.
@export var debug_facing_cast: bool = false
@export_range(1, 16, 1) var facing_cast_distance: int = 3
@export var player_path: NodePath = NodePath("../../Player")
@export var cell_highlight_fill: Color = Color(1.0, 0.92, 0.2, 0.35)
@export var cell_highlight_stroke: Color = Color(1.0, 0.85, 0.1, 0.95)
@export var facing_cast_fill: Color = Color(0.2, 0.95, 0.35, 0.32)
@export var facing_cast_stroke: Color = Color(0.15, 0.85, 0.3, 0.95)
## Cast cell that owns a pipe top coping (visual distinct from green pads).
@export var facing_cast_coping_fill: Color = Color(1.0, 0.55, 0.15, 0.4)
@export var facing_cast_coping_stroke: Color = Color(1.0, 0.7, 0.2, 1.0)
## Relative z under RampLevel. Player sits between (typically 10–100).
@export var far_pass_z_index: int = -50
@export var near_pass_z_index: int = 200

var _level: RampLevel
var _player: Node2D
## Cached far→near pipe order; invalidated on refresh / pipe rebuild.
var _pipes_draw_order: Array = []
var _far: Node2D
var _near: Node2D
## CanvasItem currently receiving draw_* during paint_pass.
var _paint: CanvasItem


func _ready() -> void:
	z_index = 0
	_level = get_parent() as RampLevel
	_player = get_node_or_null(player_path) as Node2D
	if not DebugTools.is_available():
		debug_cell_highlight = false
		debug_facing_cast = false
	_ensure_passes()
	refresh()


func _process(_delta: float) -> void:
	_ensure_passes()
	# Split moves with the skater — redraw both passes every frame.
	if _far:
		_far.queue_redraw()
	if _near:
		_near.queue_redraw()


func refresh() -> void:
	_pipes_draw_order.clear()
	_ensure_passes()
	if _far:
		_far.queue_redraw()
	if _near:
		_near.queue_redraw()


func _ensure_passes() -> void:
	if _far != null and is_instance_valid(_far) and _near != null and is_instance_valid(_near):
		_far.z_index = far_pass_z_index
		_near.z_index = near_pass_z_index
		return
	if _far == null or not is_instance_valid(_far):
		_far = _make_pass("Far", false)
	if _near == null or not is_instance_valid(_near):
		_near = _make_pass("Near", true)


func _make_pass(node_name: String, is_near: bool) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	n.set_script(_PassScript)
	n.set("pass_kind", 1 if is_near else 0)
	n.set("host", self)
	n.z_as_relative = true
	n.z_index = near_pass_z_index if is_near else far_pass_z_index
	add_child(n)
	# Near after Far in tree so equal-z ties still prefer Near.
	if is_near:
		move_child(n, get_child_count() - 1)
	return n


## Called from RampVisualPass._draw. `near_pass`: Z nearer than the skater.
func paint_pass(ci: CanvasItem, near_pass: bool) -> void:
	if _level == null or ci == null:
		return
	_paint = ci
	var view := _view_z_band()
	var split_z := _player_split_z()
	# Backdrop always on Far so an empty far band (skater at back) still clears.
	if not near_pass:
		_draw_backdrop_pad(view)
	var band := _pass_band(view, near_pass, split_z)
	if band.y > band.x + 0.001:
		_draw_ground_floors(band)
		for pipe in _pipes_far_to_near():
			_draw_pipe(pipe, band)
		_draw_elevated_floors(band)
		_draw_decks(band)
	if near_pass:
		if show_depth_grid:
			_draw_depth_grid(view)
		_draw_player_cell_highlight()
		_draw_facing_cast_highlight()
	_paint = null


## Larger logical Z = farther from camera. Split at skater Z.
func _player_split_z() -> float:
	if _player == null:
		_player = get_node_or_null(player_path) as Node2D
	if _player != null and _player.has_node("PseudoDepthBody"):
		var body: PseudoDepthBody = _player.get_node("PseudoDepthBody")
		return body.logical_z
	if _level != null:
		return _level.view_origin_z
	return 0.0


## Near pass: Z ∈ [view.x, split). Far pass: Z ∈ [split, view.y].
func _pass_band(view: Vector2, near_pass: bool, split_z: float) -> Vector2:
	if near_pass:
		return Vector2(view.x, minf(view.y, split_z))
	return Vector2(maxf(view.x, split_z), view.y)


## Skater-centered draw window (culling only — does not move X lean).
func _view_z_band() -> Vector2:
	var ref := maxf(_level.reference_depth, 0.0001)
	var half := ref * (0.5 + maxf(draw_band_pad, 0.0))
	var oz := _level.view_origin_z
	return Vector2(maxf(oz - half, _level.z_min), minf(oz + half, _level.z_max))


func _pipes_far_to_near() -> Array:
	var pipes: Array = _level.pipes
	if (
		not _pipes_draw_order.is_empty()
		and _pipes_draw_order.size() == pipes.size()
		and (pipes.is_empty() or is_instance_valid(_pipes_draw_order[0]) and _pipes_draw_order[0] == pipes[0])
	):
		return _pipes_draw_order
	_pipes_draw_order = pipes.duplicate()
	_pipes_draw_order.sort_custom(func(a, b): return a.z_max > b.z_max)
	return _pipes_draw_order


func _decks_far_to_near() -> Array:
	if _level.spec == null:
		return []
	var decks: Array = _level.spec.decks.duplicate()
	decks.sort_custom(func(a, b): return _deck_z_max(a) > _deck_z_max(b))
	return decks


func _deck_z_max(deck: Dictionary) -> float:
	var z := -INF
	for v in deck.poly:
		z = maxf(z, v.y)
	return z


func _deck_z_min(deck: Dictionary) -> float:
	var z := INF
	for v in deck.poly:
		z = minf(z, v.y)
	return z


func _draw_backdrop_pad(band: Vector2) -> void:
	var pad := 640.0
	var near_l := _level.project(_level.x_min() - pad, band.x, 0.0)
	var near_r := _level.project(_level.x_max() + pad, band.x, 0.0)
	var far_l := _level.project(_level.x_min() - pad * 0.5, band.y, 0.0)
	var far_r := _level.project(_level.x_max() + pad * 0.5, band.y, 0.0)
	_paint.draw_colored_polygon(
		PackedVector2Array([
			Vector2(near_l.screen_x, near_l.ground_y + 50.0),
			Vector2(near_r.screen_x, near_r.ground_y + 50.0),
			Vector2(far_r.screen_x, far_r.ground_y - 30.0),
			Vector2(far_l.screen_x, far_l.ground_y - 30.0),
		]),
		Color(0.12, 0.14, 0.16, 1.0)
	)


func _project_poly(poly: PackedVector2Array, height: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in range(poly.size()):
		var v: Vector2 = poly[i]
		var p: Dictionary = _level.project(v.x, v.y, height)
		out[i] = Vector2(p.screen_x, p.ground_y - p.surface_screen_h)
	return out


func _project_deck_poly(deck: Dictionary, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in range(poly.size()):
		var v: Vector2 = poly[i]
		var p: Dictionary = _level.project_deck_point(deck, v.x, v.y)
		out[i] = Vector2(p.screen_x, p.ground_y - p.surface_screen_h)
	return out


func _draw_ground_floors(band: Vector2) -> void:
	if _level.spec == null:
		return
	var spec := _level.spec
	if not spec.story_floor_masks.is_empty() and spec.grid_w > 0:
		for story in spec.story_floor_masks:
			var h := float(story.get("height", 0.0))
			if h > 0.05:
				continue
			var mask: PackedByteArray = story.get("mask", PackedByteArray())
			if mask.size() < spec.grid_w * spec.grid_h:
				continue
			_draw_story_floor_cells(band, mask, 0.0, int(story.get("layer", -1)))
		return
	if spec.floor_mask.size() > 0 and spec.grid_w > 0:
		_draw_story_floor_cells(band, spec.floor_mask, 0.0, 0)
		return
	for floor in spec.floors:
		if float(floor.get("height", 0.0)) > 0.05:
			continue
		var clipped := _clip_poly_z_band(floor.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_poly(clipped, 0.0)
		if pts.size() >= 3:
			_paint.draw_colored_polygon(pts, Color(0.32, 0.38, 0.42, 0.88))


## Elevated stories: per-cell quads (outline polys break on holes / rings).
func _draw_elevated_floors(band: Vector2) -> void:
	if _level.spec == null:
		return
	var spec := _level.spec
	var W := spec.grid_w
	var H := spec.grid_h
	if W <= 0 or H <= 0:
		return
	for story in spec.story_floor_masks:
		var h := float(story.get("height", 0.0))
		if h <= 0.05:
			continue
		var mask: PackedByteArray = story.get("mask", PackedByteArray())
		if mask.size() < W * H:
			continue
		_draw_story_floor_cells(band, mask, h, int(story.get("layer", -1)))


func _draw_story_floor_cells(
	band: Vector2, mask: PackedByteArray, height: float, _layer: int = -1
) -> void:
	var spec := _level.spec
	var W := spec.grid_w
	var H := spec.grid_h
	var cw := spec.cell_w
	var ch := spec.cell_h
	if cw <= 0.0 or ch <= 0.0:
		return
	var r_min := clampi(int(ceil(float(H) - 1.0 - band.y / ch)), 0, H - 1)
	var r_max := clampi(int(floor(float(H) - band.x / ch - 0.0001)), 0, H - 1)
	if r_max < r_min:
		return
	var fill := Color(0.32, 0.38, 0.42, 0.88)
	var lava_fill := Color(0.72, 0.12, 0.05, 0.92)
	for r in range(r_min, r_max + 1):
		var z0 := maxf(float(H - 1 - r) * ch, band.x)
		var z1 := minf(float(H - r) * ch, band.y)
		if z1 <= z0 + 0.001:
			continue
		var c := 0
		while c < W:
			var kind: int = int(mask[r * W + c])
			if kind == 0:
				c += 1
				continue
			var c1 := c + 1
			while c1 < W and int(mask[r * W + c1]) == kind:
				c1 += 1
			var x0 := float(c) * cw
			var x1 := float(c1) * cw
			var cell_fill := lava_fill if kind == 2 else fill
			_paint.draw_colored_polygon(
				PackedVector2Array([
					_surf_point(x0, z0, height),
					_surf_point(x1, z0, height),
					_surf_point(x1, z1, height),
					_surf_point(x0, z1, height),
				]),
				cell_fill
			)
			c = c1


func _draw_decks(band: Vector2) -> void:
	if _level.spec == null:
		return
	for deck in _decks_far_to_near():
		var clipped := _clip_poly_z_band(deck.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_deck_poly(deck, clipped)
		if pts.size() >= 3:
			_paint.draw_colored_polygon(pts, Color(0.55, 0.48, 0.32, 0.92))
			for i in range(pts.size()):
				_paint.draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.95, 0.55, 0.35, 0.85), 2.5)


func _draw_depth_grid(band: Vector2) -> void:
	if _level.spec == null or _level.spec.floors.is_empty():
		return
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var z := lerpf(band.x, band.y, t)
		var left := _level.project(_level.x_min(), z, 0.0)
		var right := _level.project(_level.x_max(), z, 0.0)
		_paint.draw_line(
			Vector2(left.screen_x, left.ground_y),
			Vector2(right.screen_x, right.ground_y),
			Color(1, 1, 1, 0.10),
			1.2
		)


func _draw_player_cell_highlight() -> void:
	if not DebugTools.is_available() or not debug_cell_highlight:
		return
	if _level == null or _level.spec == null:
		return
	if _level.spec.grid_w <= 0 or _level.spec.grid_h <= 0:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node2D
	if _player == null or not _player.has_node("PseudoDepthBody"):
		return
	var body: PseudoDepthBody = _player.get_node("PseudoDepthBody")
	var lx: float = body.logical_x
	var lz: float = body.logical_z
	var cell: Vector2i
	if _player.has_method("cell_under_feet"):
		cell = _player.call("cell_under_feet") as Vector2i
		if _player.has_method("cell_sample_xz"):
			var xz: Vector2 = _player.call("cell_sample_xz")
			lx = xz.x
			lz = xz.y
	elif _player.has_method("cell_sample_xz"):
		var xz2: Vector2 = _player.call("cell_sample_xz")
		lx = xz2.x
		lz = xz2.y
		cell = _level.spec.cell_at(lx, lz)
	else:
		cell = _level.spec.cell_at(lx, lz)
	var prefer_h := float(body.surface_height)
	if bool(_player.get("_airborne")):
		prefer_h = float(_player.get("air_abs_height"))
	_draw_logical_cell(cell, prefer_h, cell_highlight_fill, cell_highlight_stroke, lx, lz)


## Green cells ahead of facing_h — draw only; resolution is FacingCastMath.
func _draw_facing_cast_highlight() -> void:
	if not DebugTools.is_available() or not debug_facing_cast:
		return
	if _level == null or _level.spec == null:
		return
	if _level.spec.grid_w <= 0 or _level.spec.grid_h <= 0:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node2D
	if _player == null or not _player.has_node("PseudoDepthBody"):
		return
	var body: PseudoDepthBody = _player.get_node("PseudoDepthBody")
	var cell: Vector2i
	if _player.has_method("cell_under_feet"):
		cell = _player.call("cell_under_feet") as Vector2i
	elif _player.has_method("cell_sample_xz"):
		var xz: Vector2 = _player.call("cell_sample_xz")
		cell = _level.spec.cell_at(xz.x, xz.y)
	else:
		cell = _level.spec.cell_at(body.logical_x, body.logical_z)
	var facing := str(_player.get("facing_h"))
	if facing != "l" and facing != "r":
		facing = "r"
	var prefer_h := float(body.surface_height)
	if bool(_player.get("_airborne")):
		prefer_h = float(_player.get("air_abs_height"))
	var trail_z := body.logical_z
	if _player.has_method("cell_sample_xz"):
		trail_z = float(_player.call("cell_sample_xz").y)
	var hits: Array = _level.facing_cast(
		cell.x, cell.y, facing, facing_cast_distance, trail_z, prefer_h
	)
	for hit in hits:
		_draw_cast_hit(hit)


## Draw one FacingCastMath.cast_ahead hit (flat pad; amber if coping).
func _draw_cast_hit(hit: Dictionary) -> void:
	var h := float(hit.get("height", 0.0))
	var is_cope := bool(hit.get("is_coping", false))
	var fill := facing_cast_coping_fill if is_cope else facing_cast_fill
	var stroke := facing_cast_coping_stroke if is_cope else facing_cast_stroke
	var x0 := float(hit.get("x0", 0.0))
	var x1 := float(hit.get("x1", 0.0))
	var z0 := float(hit.get("z0", 0.0))
	var z1 := float(hit.get("z1", 0.0))
	var corners := PackedVector2Array([
		_surf_point(x0, z0, h),
		_surf_point(x1, z0, h),
		_surf_point(x1, z1, h),
		_surf_point(x0, z1, h),
	])
	_paint.draw_colored_polygon(corners, fill)
	for i in range(corners.size()):
		_paint.draw_line(
			corners[i],
			corners[(i + 1) % corners.size()],
			stroke,
			3.0 if is_cope else 2.5,
			true
		)


func _draw_logical_cell(
	cell: Vector2i,
	prefer_h: float,
	fill: Color,
	stroke: Color,
	sample_x: float = NAN,
	sample_z: float = NAN,
	prefer_side: int = -1,
	prefer_lip_x: float = NAN,
	prefer_base_h: float = NAN,
	warp_to_surface: bool = false,
	trail_z: float = NAN,
) -> void:
	var b: Dictionary = _level.spec.cell_bounds(cell.x, cell.y)
	var x0 := float(b.x0)
	var x1 := float(b.x1)
	var z0 := float(b.z0)
	var z1 := float(b.z1)
	var corners_xz := [
		Vector2(x0, z0),
		Vector2(x1, z0),
		Vector2(x1, z1),
		Vector2(x0, z1),
	]
	var heights: Array[float] = []
	if warp_to_surface:
		var hz := trail_z
		if is_nan(hz):
			hz = (z0 + z1) * 0.5
		for p in corners_xz:
			heights.append(
				_surface_height_at(
					p.x, hz, prefer_h, prefer_side, prefer_lip_x, prefer_base_h
				)
			)
	else:
		var sx := sample_x
		var sz := sample_z
		if is_nan(sx) or is_nan(sz):
			sx = (x0 + x1) * 0.5
			sz = (z0 + z1) * 0.5
		var h := _surface_height_at(
			sx, sz, prefer_h, prefer_side, prefer_lip_x, prefer_base_h
		)
		for _i in range(4):
			heights.append(h)
	var corners := PackedVector2Array()
	for i in range(4):
		var p: Vector2 = corners_xz[i]
		corners.append(_surf_point(p.x, p.y, heights[i]))
	_paint.draw_colored_polygon(corners, fill)
	for i in range(corners.size()):
		_paint.draw_line(
			corners[i],
			corners[(i + 1) % corners.size()],
			stroke,
			2.5,
			true
		)


## Surface height at logical XZ (cell highlight). Optional sticky pipe.
func _surface_height_at(
	logical_x: float,
	logical_z: float,
	prefer_h: float,
	prefer_side: int = -1,
	prefer_lip_x: float = NAN,
	prefer_base_h: float = NAN,
) -> float:
	var under: Dictionary = _level.sample(
		logical_x, logical_z, prefer_side, prefer_lip_x, prefer_h, prefer_base_h
	)
	if under.get("active", true) or str(under.get("zone", "")) != "oob":
		return float(under.get("height", 0.0))
	return 0.0


func _surf_point(logical_x: float, logical_z: float, height: float) -> Vector2:
	var p: Dictionary = _level.project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)


## One near→far ribbon clipped to `band` (pass Z window).
func _draw_pipe(pipe: QuarterPipe, band: Vector2) -> void:
	var z0 := maxf(pipe.z_min, band.x)
	var z1 := minf(pipe.z_max, band.y)
	if z1 <= z0 + 0.001:
		return

	var steps := maxi(arc_steps, 4)
	var near_arc := _arc_points(pipe, z0, steps)
	var far_arc := _arc_points(pipe, z1, steps)
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var fill_col := Color(0.42, 0.38, 0.48, 0.92) if is_left else Color(0.38, 0.44, 0.52, 0.92)

	for i in range(steps):
		_paint.draw_colored_polygon(
			PackedVector2Array([
				near_arc[i],
				near_arc[i + 1],
				far_arc[i + 1],
				far_arc[i],
			]),
			fill_col
		)

	var ribs := maxi(arc_ribs, 1)
	for r in range(1, ribs):
		var u := float(r) / float(ribs)
		var a: Vector2 = _level.pipe_screen_point_for(pipe, z0, u)
		var b: Vector2 = _level.pipe_screen_point_for(pipe, z1, u)
		_paint.draw_line(a, b, Color(1, 1, 1, 0.14), 1.25)

	_draw_pipe_top_stroke(pipe, z0, z1)
	_paint.draw_line(
		_level.pipe_screen_point_for(pipe, z0, 0.0),
		_level.pipe_screen_point_for(pipe, z1, 0.0),
		Color(0.95, 0.85, 0.35, 0.85),
		2.5
	)


func _draw_pipe_top_stroke(pipe: QuarterPipe, z0: float, z1: float) -> void:
	var covered := _deck_z_ranges_covering_pipe(pipe)
	var segments := _z_segments_minus_covered(z0, z1, covered)
	for seg in segments:
		_paint.draw_line(
			_level.pipe_screen_point_for(pipe, float(seg.x), 1.0),
			_level.pipe_screen_point_for(pipe, float(seg.y), 1.0),
			Color(0.95, 0.55, 0.35, 0.9),
			3.0
		)


func _deck_z_ranges_covering_pipe(pipe: QuarterPipe) -> Array:
	var out: Array = []
	if _level.spec == null:
		return out
	var coping := pipe.x_min() if pipe.side == QuarterPipe.PipeSide.LEFT else pipe.x_max()
	for deck in _level.spec.decks:
		var covers := false
		for a in deck.get("anchors", []):
			if absf(float(a.coping_x) - coping) < 0.05:
				covers = true
				break
		if not covers:
			for v in deck.poly:
				if absf(v.x - coping) < 0.05:
					covers = true
					break
		if not covers:
			continue
		var dz0 := _deck_z_min(deck)
		var dz1 := _deck_z_max(deck)
		var lo := maxf(dz0, pipe.z_min)
		var hi := minf(dz1, pipe.z_max)
		if lo < hi:
			out.append(Vector2(lo, hi))
	return out


func _z_segments_minus_covered(z_min: float, z_max: float, covered: Array) -> Array:
	if covered.is_empty():
		return [Vector2(z_min, z_max)]
	var sorted: Array = covered.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x)
	var segs: Array = []
	var cursor := z_min
	for c in sorted:
		var lo: float = maxf(c.x, z_min)
		var hi: float = minf(c.y, z_max)
		if lo > cursor + 0.001:
			segs.append(Vector2(cursor, lo))
		cursor = maxf(cursor, hi)
	if cursor < z_max - 0.001:
		segs.append(Vector2(cursor, z_max))
	return segs


func _arc_points(pipe: QuarterPipe, logical_z: float, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(steps + 1)
	for i in range(steps + 1):
		pts[i] = _level.pipe_screen_point_for(pipe, logical_z, float(i) / float(steps))
	return pts


## Sutherland–Hodgman clip of XZ polygon to z ∈ [z0, z1].
func _clip_poly_z_band(poly: PackedVector2Array, z0: float, z1: float) -> PackedVector2Array:
	var kept := _clip_poly_halfplane(poly, true, z0)
	return _clip_poly_halfplane(kept, false, z1)


func _clip_poly_halfplane(poly: PackedVector2Array, keep_above: bool, z_edge: float) -> PackedVector2Array:
	if poly.size() < 3:
		return PackedVector2Array()
	var out := PackedVector2Array()
	var n := poly.size()
	for i in range(n):
		var cur: Vector2 = poly[i]
		var prev: Vector2 = poly[(i + n - 1) % n]
		var cur_in := (cur.y >= z_edge) if keep_above else (cur.y <= z_edge)
		var prev_in := (prev.y >= z_edge) if keep_above else (prev.y <= z_edge)
		if cur_in:
			if not prev_in:
				out.append(_intersect_z(prev, cur, z_edge))
			out.append(cur)
		elif prev_in:
			out.append(_intersect_z(prev, cur, z_edge))
	return out


func _intersect_z(a: Vector2, b: Vector2, z_edge: float) -> Vector2:
	var dz := b.y - a.y
	if absf(dz) < 0.000001:
		return Vector2(a.x, z_edge)
	var t := (z_edge - a.y) / dz
	return Vector2(lerpf(a.x, b.x, t), z_edge)
