class_name LevelDebug3D
extends Node3D
## Cell highlight + facing-cast cell pads for the 3D park (mirrors RampVisual debug).

@export var debug_cell_highlight: bool = false
@export var debug_facing_cast: bool = false
@export_range(1, 16, 1) var facing_cast_distance: int = 3
@export var highlight_lift: float = 0.08
@export var player_path: NodePath = NodePath("../../Player")
@export var level_path: NodePath = NodePath("../../RampLevel")

var _player: Node
var _level: RampLevel
var _cell_root: Node3D
var _cast_root: Node3D
var _cell_mat: StandardMaterial3D
var _cast_mat: StandardMaterial3D
var _cast_cope_mat: StandardMaterial3D


func _ready() -> void:
	_cell_root = Node3D.new()
	_cell_root.name = "CellHighlight"
	add_child(_cell_root)
	_cast_root = Node3D.new()
	_cast_root.name = "FacingCast"
	add_child(_cast_root)
	_cell_mat = _make_mat(Color(0.35, 0.95, 0.55, 0.38))
	_cast_mat = _make_mat(Color(0.35, 0.85, 1.0, 0.32))
	_cast_cope_mat = _make_mat(Color(1.0, 0.72, 0.25, 0.4))
	_resolve_refs()


func _resolve_refs() -> void:
	_player = get_node_or_null(player_path)
	_level = get_node_or_null(level_path) as RampLevel


func _process(_delta: float) -> void:
	if _player == null or _level == null:
		_resolve_refs()
	if _player == null or _level == null or _level.spec == null:
		_clear_children(_cell_root)
		_clear_children(_cast_root)
		return
	if not DebugTools.is_available():
		_clear_children(_cell_root)
		_clear_children(_cast_root)
		return
	_update_cell_highlight()
	_update_facing_cast()


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _prefer_h() -> float:
	if bool(_player.get("_airborne")):
		return float(_player.get("air_abs_height"))
	var depth: PseudoDepthBody = _player.get_node_or_null("PseudoDepthBody") as PseudoDepthBody
	if depth != null:
		return depth.surface_height
	return 0.0


func _trail_z() -> float:
	if _player.has_method("cell_sample_xz"):
		return float(_player.call("cell_sample_xz").y)
	var depth: PseudoDepthBody = _player.get_node_or_null("PseudoDepthBody") as PseudoDepthBody
	if depth != null:
		return depth.logical_z
	return 0.0


func _feet_cell() -> Vector2i:
	if _player.has_method("cell_under_feet"):
		return _player.call("cell_under_feet") as Vector2i
	if _player.has_method("cell_sample_xz"):
		var xz: Vector2 = _player.call("cell_sample_xz")
		return _level.spec.cell_at(xz.x, xz.y)
	var depth: PseudoDepthBody = _player.get_node_or_null("PseudoDepthBody") as PseudoDepthBody
	if depth != null:
		return _level.spec.cell_at(depth.logical_x, depth.logical_z)
	return Vector2i.ZERO


func _update_cell_highlight() -> void:
	_clear_children(_cell_root)
	if not debug_cell_highlight:
		return
	if _level.spec.grid_w <= 0 or _level.spec.grid_h <= 0:
		return
	var cell := _feet_cell()
	var lx: float
	var lz: float
	if _player.has_method("cell_sample_xz"):
		var xz: Vector2 = _player.call("cell_sample_xz")
		lx = xz.x
		lz = xz.y
	else:
		var b: Dictionary = _level.spec.cell_bounds(cell.x, cell.y)
		lx = (float(b.x0) + float(b.x1)) * 0.5
		lz = (float(b.z0) + float(b.z1)) * 0.5
	var surf: Dictionary = _level.sample(lx, lz, -1, NAN, _prefer_h())
	var h := float(surf.get("height", 0.0)) + highlight_lift
	_add_cell_pad(_cell_root, cell, h, _cell_mat)


func _update_facing_cast() -> void:
	_clear_children(_cast_root)
	if not debug_facing_cast:
		return
	if _level.spec.grid_w <= 0 or _level.spec.grid_h <= 0:
		return
	var cell := _feet_cell()
	var facing := str(_player.get("facing_h"))
	if facing != "l" and facing != "r":
		facing = "r"
	var hits: Array = _level.facing_cast(
		cell.x, cell.y, facing, facing_cast_distance, _trail_z(), _prefer_h()
	)
	for hit in hits:
		var h := float(hit.get("height", 0.0)) + highlight_lift
		var is_cope := bool(hit.get("is_coping", false))
		var mat := _cast_cope_mat if is_cope else _cast_mat
		var c: Vector2i = hit.get("cell", Vector2i(int(hit.get("col", 0)), int(hit.get("row", 0))))
		_add_cell_pad(_cast_root, c, h, mat)


func _add_cell_pad(parent: Node3D, cell: Vector2i, height: float, mat: Material) -> void:
	var b: Dictionary = _level.spec.cell_bounds(cell.x, cell.y)
	var x0 := float(b.x0)
	var x1 := float(b.x1)
	var z0 := float(b.z0)
	var z1 := float(b.z1)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = _pad_mesh(x0, x1, z0, z1, height)
	mi.material_override = mat
	parent.add_child(mi)


func _pad_mesh(x0: float, x1: float, z0: float, z1: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP
	var c := Color.WHITE
	var p0 := WorldSpace.logical_to_world(x0, z0, height)
	var p1 := WorldSpace.logical_to_world(x1, z0, height)
	var p2 := WorldSpace.logical_to_world(x1, z1, height)
	var p3 := WorldSpace.logical_to_world(x0, z1, height)
	# Two triangles; winding flipped for −X world map.
	st.set_normal(n)
	st.set_color(c)
	st.add_vertex(p0)
	st.add_vertex(p2)
	st.add_vertex(p1)
	st.add_vertex(p0)
	st.add_vertex(p3)
	st.add_vertex(p2)
	return st.commit()


func _clear_children(node: Node3D) -> void:
	for child in node.get_children():
		child.queue_free()
