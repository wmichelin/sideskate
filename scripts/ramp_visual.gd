extends Node2D
## Surface-only level draw: floors, pipe ribbons, elevated deck tops.
## Draw window follows skater Z (truck only). X lean uses world-fixed origin_z.

@export var grid_steps: int = 5
## How many iso-u depth strokes to split the pipe face into (not cross-section arcs).
@export var arc_ribs: int = 4
## Extra Z past the lean band on near and far sides, as a fraction of reference_depth.
@export_range(0.0, 2.0, 0.05) var draw_band_pad: float = 1.15
## Arc samples along the quarter-pipe profile (fill + ribs share this).
@export_range(4, 16, 1) var arc_steps: int = 8
## Checkerboard flat ground using ASCII floor cells. Tunable in TUNING.
@export var show_floor_checker: bool = true
## ASCII cells per checker tile (1 = finest / slowest; 4–8 is usually enough).
@export_range(1, 16, 1) var floor_checker_tile: int = 6
@export var floor_checker_a: Color = Color(0.24, 0.30, 0.26, 0.95)
@export var floor_checker_b: Color = Color(0.33, 0.39, 0.34, 0.95)
## Faint white depth bands across the plaza. Off by default (debug clutter).
@export var show_depth_grid: bool = false
## Highlight the .ssk ASCII cell under the player (logical unit 1:1). Debug only.
@export var debug_cell_highlight: bool = false
@export var player_path: NodePath = NodePath("../../Player")
@export var cell_highlight_fill: Color = Color(1.0, 0.92, 0.2, 0.35)
@export var cell_highlight_stroke: Color = Color(1.0, 0.85, 0.1, 0.95)

var _level: RampLevel
var _player: Node2D
var _checker_tex: ImageTexture
var _checker_tex_a: Color = Color(0, 0, 0, 0)
var _checker_tex_b: Color = Color(0, 0, 0, 0)
var _floor_checker_mesh: ArrayMesh = ArrayMesh.new()


func _ready() -> void:
	z_index = -50
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_level = get_parent() as RampLevel
	_player = get_node_or_null(player_path) as Node2D
	if not DebugTools.is_available():
		debug_cell_highlight = false
	queue_redraw()


func _process(_delta: float) -> void:
	if DebugTools.is_available() and debug_cell_highlight:
		queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _level == null:
		return
	var band := _view_z_band()
	_draw_backdrop_pad(band)
	_draw_floors(band)
	for pipe in _pipes_far_to_near():
		_draw_pipe(pipe, band)
	_draw_decks(band)
	if show_depth_grid:
		_draw_depth_grid(band)
	_draw_player_cell_highlight()


## Skater-centered draw window (culling only — does not move X lean).
func _view_z_band() -> Vector2:
	var ref := maxf(_level.reference_depth, 0.0001)
	var half := ref * (0.5 + maxf(draw_band_pad, 0.0))
	var oz := _level.view_origin_z
	return Vector2(maxf(oz - half, _level.z_min), minf(oz + half, _level.z_max))


func _pipes_far_to_near() -> Array:
	var pipes: Array = _level.pipes.duplicate()
	pipes.sort_custom(func(a, b): return a.z_max > b.z_max)
	return pipes


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
	draw_colored_polygon(
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


func _draw_floors(band: Vector2) -> void:
	if _level.spec == null:
		return
	if show_floor_checker and _level.spec.floor_mask.size() > 0:
		_draw_floor_checker(band)
		return
	for floor in _level.spec.floors:
		var clipped := _clip_poly_z_band(floor.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_poly(clipped, 0.0)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.28, 0.34, 0.30, 0.95))


func _ensure_checker_texture() -> void:
	if (
		_checker_tex != null
		and _checker_tex_a.is_equal_approx(floor_checker_a)
		and _checker_tex_b.is_equal_approx(floor_checker_b)
	):
		return
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, floor_checker_a)
	img.set_pixel(1, 1, floor_checker_a)
	img.set_pixel(1, 0, floor_checker_b)
	img.set_pixel(0, 1, floor_checker_b)
	if _checker_tex == null:
		_checker_tex = ImageTexture.create_from_image(img)
	else:
		_checker_tex.update(img)
	_checker_tex_a = floor_checker_a
	_checker_tex_b = floor_checker_b


## Coarse tiles baked into one textured mesh. `floor_checker_tile` ASCII cells per square.
func _draw_floor_checker(band: Vector2) -> void:
	_ensure_checker_texture()
	var spec := _level.spec
	var W := spec.grid_w
	var H := spec.grid_h
	var cw := spec.cell_w
	var ch := spec.cell_h
	var mask := spec.floor_mask
	if W <= 0 or H <= 0 or cw <= 0.0 or ch <= 0.0 or mask.size() < W * H:
		return

	var r_min := clampi(int(ceil(float(H) - 1.0 - band.y / ch)), 0, H - 1)
	var r_max := clampi(int(floor(float(H) - band.x / ch - 0.0001)), 0, H - 1)
	if r_max < r_min:
		return

	var tile := maxi(floor_checker_tile, 1)
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var r0 := r_min - (r_min % tile)
	for r in range(r0, r_max + 1, tile):
		var r_far := maxi(r, 0)
		var r_near := mini(r + tile - 1, H - 1)
		if r_near < r_min or r_far > r_max:
			continue
		var z0 := maxf(float(H - 1 - r_near) * ch, band.x)
		var z1 := minf(float(H - r_far) * ch, band.y)
		if z1 <= z0 + 0.001:
			continue
		var ty := int(r_far / tile)
		for c in range(0, W, tile):
			var c1 := mini(c + tile, W)
			if not _tile_has_floor(mask, W, c, c1, r_far, r_near + 1):
				continue
			var x0 := float(c) * cw
			var x1 := float(c1) * cw
			var p00: Dictionary = _level.project(x0, z0, 0.0)
			var p10: Dictionary = _level.project(x1, z0, 0.0)
			var p11: Dictionary = _level.project(x1, z1, 0.0)
			var p01: Dictionary = _level.project(x0, z1, 0.0)
			var s00 := Vector2(p00.screen_x, p00.ground_y)
			var s10 := Vector2(p10.screen_x, p10.ground_y)
			var s11 := Vector2(p11.screen_x, p11.ground_y)
			var s01 := Vector2(p01.screen_x, p01.ground_y)
			# Solid UV sample from 2×2 checker tex (NEAREST).
			var tx := int(c / tile)
			var uv := Vector2(0.25, 0.25) if ((tx + ty) & 1) == 0 else Vector2(0.75, 0.25)
			verts.append(s00)
			verts.append(s10)
			verts.append(s11)
			uvs.append(uv)
			uvs.append(uv)
			uvs.append(uv)
			verts.append(s00)
			verts.append(s11)
			verts.append(s01)
			uvs.append(uv)
			uvs.append(uv)
			uvs.append(uv)

	if verts.is_empty():
		return
	_floor_checker_mesh.clear_surfaces()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_floor_checker_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_floor_checker_mesh, _checker_tex)


func _tile_has_floor(
	mask: PackedByteArray, W: int, c0: int, c1: int, r0: int, r1: int
) -> bool:
	for r in range(r0, r1):
		var row_base := r * W
		for c in range(c0, c1):
			if mask[row_base + c] != 0:
				return true
	return false


func _draw_decks(band: Vector2) -> void:
	if _level.spec == null:
		return
	for deck in _decks_far_to_near():
		var clipped := _clip_poly_z_band(deck.poly, band.x, band.y)
		if clipped.size() < 3:
			continue
		var pts := _project_deck_poly(deck, clipped)
		if pts.size() >= 3:
			draw_colored_polygon(pts, Color(0.55, 0.48, 0.32, 0.92))
			for i in range(pts.size()):
				draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0.95, 0.55, 0.35, 0.85), 2.5)


func _draw_depth_grid(band: Vector2) -> void:
	if _level.spec == null or _level.spec.floors.is_empty():
		return
	for i in range(1, grid_steps):
		var t := float(i) / float(grid_steps)
		var z := lerpf(band.x, band.y, t)
		var left := _level.project(_level.x_min(), z, 0.0)
		var right := _level.project(_level.x_max(), z, 0.0)
		draw_line(
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
	var cell: Vector2i = _level.spec.cell_at(lx, lz)
	var b: Dictionary = _level.spec.cell_bounds(cell.x, cell.y)
	var under: Dictionary = _level.sample(lx, lz)
	var h := 0.0
	if under.get("active", true) or str(under.get("zone", "")) != "oob":
		h = float(under.get("height", 0.0))
	var corners := PackedVector2Array([
		_surf_point(float(b.x0), float(b.z0), h),
		_surf_point(float(b.x1), float(b.z0), h),
		_surf_point(float(b.x1), float(b.z1), h),
		_surf_point(float(b.x0), float(b.z1), h),
	])
	draw_colored_polygon(corners, cell_highlight_fill)
	for i in range(corners.size()):
		draw_line(
			corners[i],
			corners[(i + 1) % corners.size()],
			cell_highlight_stroke,
			2.5,
			true
		)


func _surf_point(logical_x: float, logical_z: float, height: float) -> Vector2:
	var p: Dictionary = _level.project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)


## One near→far ribbon (lean is linear/unclamped, so chords are exact — no Z slices).
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
		draw_colored_polygon(
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
		draw_line(a, b, Color(1, 1, 1, 0.14), 1.25)

	_draw_pipe_top_stroke(pipe, z0, z1)
	draw_line(
		_level.pipe_screen_point_for(pipe, z0, 0.0),
		_level.pipe_screen_point_for(pipe, z1, 0.0),
		Color(0.95, 0.85, 0.35, 0.85),
		2.5
	)


func _draw_pipe_top_stroke(pipe: QuarterPipe, z0: float, z1: float) -> void:
	var covered := _deck_z_ranges_covering_pipe(pipe)
	var segments := _z_segments_minus_covered(z0, z1, covered)
	for seg in segments:
		draw_line(
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
