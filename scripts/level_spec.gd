class_name LevelSpec
extends RefCounted
## Parsed .ssk level: layered floors, decks, pipes, spawn.

var name: String = ""
## Derived: columns × cell_size_x / rows × cell_size_z.
var width: float = 0.0
var depth: float = 0.0
var pipe_radius_override: float = -1.0
var deck_height_override: float = -1.0

var spawn_x: float = 640.0
var spawn_z: float = 40.0
## Absolute logical height of the `@` spawn story (layer `height`).
var spawn_height: float = 0.0
## Layer index of the `@` marker (−1 if unset).
var spawn_layer: int = 0
## Spawn horizontal facing: "l" or "r" (default right).
var spawn_facing: String = "r"

## Each: { "poly": PackedVector2Array (x,z), "height": float, "layer": int }
var floors: Array = []
## Each: { "poly": PackedVector2Array, "height": float, "anchors": Array, "layer": int,
##         "base_height": float }
var decks: Array = []
## Each: { "side": int, "lip_x": float, "radius": float, "base_height": float,
##         "z_min": float, "z_max": float, "x_min": float, "x_max": float, "layer": int }
var pipes: Array = []
## Floor glyph cells as Vector2i(col, row) — row 0 = far/top (all stories).
var floor_cells: Array = []
## Ground-story (= / @) mask for checker draw. Row-major, row 0 = far/top.
var floor_mask: PackedByteArray = PackedByteArray()
## Per-story floor masks: [{ "height": float, "mask": PackedByteArray }, ...]
var story_floor_masks: Array = []
## Layer glyph grids for highlight / OOB: [{ "index": int, "height": float, "rows": PackedStringArray }]
var layers: Array = []
## Layer-0 non-space footprint: 1 = playable cell. Same size as floor_mask.
var playable_mask: PackedByteArray = PackedByteArray()

var z_min: float = 0.0
var z_max: float = 100.0
var x_min: float = 0.0
var x_max: float = 1280.0

## ASCII map grid (1:1 with .ssk map glyphs). row 0 = far/top.
var grid_w: int = 0
var grid_h: int = 0
var cell_w: float = 1.0
var cell_h: float = 1.0


## Map (col, row) for a logical point. row 0 = far (top of ASCII).
## Cells are half-open in X: [c·cw, (c+1)·cw). Prefer `cell_at_for_pose` when
## the skater may be X-locked on pipe coping (right coping sits on the exclusive edge).
func cell_at(logical_x: float, logical_z: float) -> Vector2i:
	if grid_w <= 0 or grid_h <= 0 or cell_w <= 0.0 or cell_h <= 0.0:
		return Vector2i.ZERO
	var col := clampi(int(floor(logical_x / cell_w)), 0, grid_w - 1)
	var row := clampi(grid_h - 1 - int(floor(logical_z / cell_h)), 0, grid_h - 1)
	return Vector2i(col, row)


## Cell under feet for targeting / debug. When X-locked over a pipe coping,
## adjusts X into the pipe so half-open `cell_at` keeps the pipe column
## (raw right-pipe coping would otherwise resolve one cell outward).
func cell_at_for_pose(
	logical_x: float,
	logical_z: float,
	air_x_locked: bool = false,
	air_over: String = "",
	air_side: int = 0,
) -> Vector2i:
	var x := logical_x
	if air_x_locked and (air_over == "left_pipe" or air_over == "right_pipe"):
		x = PipeMath.pose_x_for_cell_query(x, air_side)
	return cell_at(x, logical_z)


## Cells ahead of (origin_col, origin_row) along facing_h ("l"/"r"), steps 1…distance.
## Logical grid only — does not include the origin cell. Skips out-of-grid columns.
func facing_cast_cells(
	origin_col: int, origin_row: int, facing_h: String, distance: int
) -> Array[Vector2i]:
	return FacingCastMath.cells_ahead(
		grid_w, grid_h, origin_col, origin_row, facing_h, distance
	)


## Logical XZ bounds of ASCII cell (col, row). Returns {x0,x1,z0,z1}.
func cell_bounds(col: int, row: int) -> Dictionary:
	var c := clampi(col, 0, maxi(grid_w - 1, 0))
	var r := clampi(row, 0, maxi(grid_h - 1, 0))
	var x0 := float(c) * cell_w
	var x1 := float(c + 1) * cell_w
	var z0 := float(grid_h - 1 - r) * cell_h
	var z1 := float(grid_h - r) * cell_h
	return {"x0": x0, "x1": x1, "z0": z0, "z1": z1}


## True if layer-0 footprint marks this cell playable (non-space).
func is_playable_cell(col: int, row: int) -> bool:
	if playable_mask.is_empty() or grid_w <= 0:
		return true
	if col < 0 or row < 0 or col >= grid_w or row >= grid_h:
		return false
	return playable_mask[row * grid_w + col] != 0


func is_playable_xz(logical_x: float, logical_z: float) -> bool:
	# Outside the level AABB is always OOB (cell_at would otherwise clamp into col 0).
	if logical_x < x_min - 0.001 or logical_x > x_max + 0.001:
		return false
	if logical_z < z_min - 0.001 or logical_z > z_max + 0.001:
		return false
	var cell := cell_at(logical_x, logical_z)
	return is_playable_cell(cell.x, cell.y)


## Keep (x,z) inside the layer-0 playable footprint. Never leaves the skater in OOB.
func clamp_to_playable(logical_x: float, logical_z: float) -> Vector2:
	if is_playable_xz(logical_x, logical_z):
		return Vector2(logical_x, logical_z)
	# Soft clamp into level AABB, then snap to nearest playable cell center.
	var x := clampf(logical_x, x_min + 0.05, x_max - 0.05)
	var z := clampf(logical_z, z_min + 0.05, z_max - 0.05)
	if is_playable_xz(x, z):
		return Vector2(x, z)
	return nearest_playable_xz(x, z)


## Nearest playable cell center to (x,z). Falls back to spawn / level mid if mask empty.
func nearest_playable_xz(logical_x: float, logical_z: float) -> Vector2:
	if playable_mask.is_empty() or grid_w <= 0 or grid_h <= 0:
		return Vector2(
			clampf(logical_x, x_min + 0.05, x_max - 0.05),
			clampf(logical_z, z_min + 0.05, z_max - 0.05)
		)
	var best := Vector2(spawn_x, spawn_z)
	var best_d := INF
	for row in range(grid_h):
		for col in range(grid_w):
			if playable_mask[row * grid_w + col] == 0:
				continue
			var b: Dictionary = cell_bounds(col, row)
			var cx := (float(b.x0) + float(b.x1)) * 0.5
			var cz := (float(b.z0) + float(b.z1)) * 0.5
			var d := Vector2(cx - logical_x, cz - logical_z).length_squared()
			if d < best_d:
				best_d = d
				best = Vector2(cx, cz)
	return best


## Absolute floor heights with an `=` / `@` under (x,z). Uses per-cell story
## masks so holes (`.`) are not filled by ring outline polys.
func floor_heights_at(logical_x: float, logical_z: float) -> Array:
	var out: Array = []
	var cell := cell_at(logical_x, logical_z)
	if not story_floor_masks.is_empty() and grid_w > 0:
		for story in story_floor_masks:
			var mask: PackedByteArray = story.get("mask", PackedByteArray())
			if mask.size() < grid_w * grid_h:
				continue
			if cell.x < 0 or cell.y < 0 or cell.x >= grid_w or cell.y >= grid_h:
				continue
			if mask[cell.y * grid_w + cell.x] != 0:
				out.append(float(story.get("height", 0.0)))
		return out
	var p := Vector2(logical_x, logical_z)
	for floor in floors:
		if point_in_poly(p, floor.poly):
			out.append(float(floor.get("height", 0.0)))
	return out


## Glyph on the story with greatest height ≤ prefer_h at (col,row).
## Returns { "glyph": String, "layer_height": float, "layer": int }.
func glyph_at_prefer_h(col: int, row: int, prefer_h: float) -> Dictionary:
	var best := {"glyph": " ", "layer_height": -INF, "layer": -1}
	for L in layers:
		var h := float(L.get("height", 0.0))
		if h > prefer_h + 1.5:
			continue
		var rows: PackedStringArray = L.get("rows", PackedStringArray())
		if row < 0 or row >= rows.size():
			continue
		var line: String = rows[row]
		if col < 0 or col >= line.length():
			continue
		if h >= float(best.layer_height):
			best = {
				"glyph": line[col],
				"layer_height": h,
				"layer": int(L.get("index", -1)),
			}
	return best


static func point_in_poly(point: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in range(n):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
				(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x):
			inside = not inside
		j = i
	return inside


func contains_playable(logical_x: float, logical_z: float) -> bool:
	if not playable_mask.is_empty():
		return is_playable_xz(logical_x, logical_z)
	var p := Vector2(logical_x, logical_z)
	for floor in floors:
		if point_in_poly(p, floor.poly):
			return true
	for deck in decks:
		if point_in_poly(p, deck.poly):
			return true
	for pipe in pipes:
		if logical_x >= pipe.x_min - 0.001 and logical_x <= pipe.x_max + 0.001 \
				and logical_z >= pipe.z_min - 0.001 and logical_z <= pipe.z_max + 0.001:
			return true
	return false
