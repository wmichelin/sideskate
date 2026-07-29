class_name ParkModel
extends RefCounted
## Immutable compiled park: patches, pipes, copings, edges, bounds.


var name: String = ""
var model_hash: String = ""
var cell_w: float = 47.0
var cell_h: float = 47.0
var grid_w: int = 0
var grid_h: int = 0
var width: float = 0.0
var depth: float = 0.0
var spawn_x: float = 0.0
var spawn_z: float = 0.0
var spawn_height: float = 0.0
var spawn_facing: String = "r"
var compile_errors: PackedStringArray = PackedStringArray()

var patches: Dictionary = {} ## id -> SupportPatch
var pipes: Dictionary = {} ## id -> PipeSurface
var copings: Dictionary = {} ## id -> CopingEdge
var edges: Dictionary = {} ## id -> TopologyEdge
var playable_mask: PackedByteArray = PackedByteArray()


func is_valid() -> bool:
	return compile_errors.is_empty()


func get_patch(id: String) -> SupportPatch:
	return patches.get(id) as SupportPatch


func get_pipe(id: String) -> PipeSurface:
	return pipes.get(id) as PipeSurface


func get_coping(id: String) -> CopingEdge:
	return copings.get(id) as CopingEdge


func all_patch_ids() -> Array:
	return patches.keys()


func all_pipe_ids() -> Array:
	return pipes.keys()


func all_coping_ids() -> Array:
	var keys: Array = copings.keys()
	keys.sort()
	return keys


func is_playable_cell(col: int, row: int) -> bool:
	if grid_w <= 0 or grid_h <= 0 or playable_mask.is_empty():
		return false
	if col < 0 or row < 0 or col >= grid_w or row >= grid_h:
		return false
	return playable_mask[row * grid_w + col] != 0


## True when (x,z) is inside the world rectangle (not clamped cell query).
func in_world_xz(x: float, z: float) -> bool:
	return x >= 0.0 and x <= width and z >= 0.0 and z <= depth


## Traversable for feet: inside world and on a playable footprint cell.
func is_traversable_xz(x: float, z: float) -> bool:
	if not in_world_xz(x, z):
		return false
	var cell := cell_at(x, z)
	return is_playable_cell(cell.x, cell.y)


## Capsule-inset clamp to the world AABB (invisible border walls).
func clamp_xz(x: float, z: float) -> Vector2:
	var m := SimTolerances.CAPSULE_RADIUS
	var max_x := maxf(width - m, m)
	var max_z := maxf(depth - m, m)
	return Vector2(clampf(x, m, max_x), clampf(z, m, max_z))


func cell_at(x: float, z: float) -> Vector2i:
	if grid_w <= 0 or grid_h <= 0 or cell_w <= 0.0 or cell_h <= 0.0:
		return Vector2i.ZERO
	var col := clampi(int(floor(x / cell_w)), 0, grid_w - 1)
	var row := clampi(grid_h - 1 - int(floor(z / cell_h)), 0, grid_h - 1)
	return Vector2i(col, row)
