class_name LevelSpec
extends RefCounted
## Parsed .ssk level: floors, decks, pipes, spawn.

var name: String = ""
## Derived: columns × cell_size_x / rows × cell_size_z.
var width: float = 0.0
var depth: float = 0.0
var pipe_radius_override: float = -1.0
var deck_height_override: float = -1.0

var spawn_x: float = 640.0
var spawn_z: float = 40.0
## Spawn horizontal facing: "l" or "r" (default right).
var spawn_facing: String = "r"

## Each: { "poly": PackedVector2Array (x,z), "height": float }
var floors: Array = []
## Each: { "poly": PackedVector2Array, "height": float }
var decks: Array = []
## Each: { "side": int, "lip_x": float, "radius": float, "z_min": float, "z_max": float,
##         "x_min": float, "x_max": float }
var pipes: Array = []
## Floor glyph cells as Vector2i(col, row) — row 0 = far/top.
var floor_cells: Array = []
## PackedByteArray length grid_w*grid_h; 1 = floor. Row-major, row 0 = far/top.
var floor_mask: PackedByteArray = PackedByteArray()

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


## Logical XZ bounds of ASCII cell (col, row). Returns {x0,x1,z0,z1}.
func cell_bounds(col: int, row: int) -> Dictionary:
	var c := clampi(col, 0, maxi(grid_w - 1, 0))
	var r := clampi(row, 0, maxi(grid_h - 1, 0))
	var x0 := float(c) * cell_w
	var x1 := float(c + 1) * cell_w
	var z0 := float(grid_h - 1 - r) * cell_h
	var z1 := float(grid_h - r) * cell_h
	return {"x0": x0, "x1": x1, "z0": z0, "z1": z1}


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
