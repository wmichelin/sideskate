class_name LevelDebug3D
extends Node3D
## Cell highlight + facing-cast pads + green edge / orange surface lattices.

const LevelGeometryScript := preload("res://scripts/mesh/level_geometry.gd")
const MeshPartDebugScript := preload("res://scripts/mesh/mesh_part_debug.gd")

@export var debug_cell_highlight: bool = false
@export var debug_facing_cast: bool = false
## Green edge wire + orange surface lattice on collidable solids (default on).
@export var debug_edge_lines: bool = true
@export_range(1, 16, 1) var facing_cast_distance: int = 3
@export var highlight_lift: float = 0.08
## World-space lift (meters) so debug wires sit above collision faces.
@export var edge_lift: float = 0.0035
## Spacing for the orange surface lattice (logical units; legacy deck scans).
@export var lattice_spacing: float = 28.0
@export_range(2, 24, 1) var pipe_lattice_arc_steps: int = 8
@export_range(2, 24, 1) var pipe_lattice_z_steps: int = 6
@export var player_path: NodePath = NodePath("../Player")
@export var level_path: NodePath = NodePath("../../RampLevel")

var _player: Node
var _level: RampLevel
var _cell_root: Node3D
var _cast_root: Node3D
var _edge_root: Node3D
var _cell_mat: StandardMaterial3D
var _cast_mat: StandardMaterial3D
var _cast_cope_mat: StandardMaterial3D
var _edge_mat: StandardMaterial3D
var _lattice_mat: StandardMaterial3D
var _edge_cache_key: String = ""


func _ready() -> void:
	_cell_root = Node3D.new()
	_cell_root.name = "CellHighlight"
	add_child(_cell_root)
	_cast_root = Node3D.new()
	_cast_root.name = "FacingCast"
	add_child(_cast_root)
	_edge_root = Node3D.new()
	_edge_root.name = "EdgeLines"
	add_child(_edge_root)
	_cell_mat = _make_mat(Color(0.35, 0.95, 0.55, 0.38))
	_cast_mat = _make_mat(Color(0.35, 0.85, 1.0, 0.32))
	_cast_cope_mat = _make_mat(Color(1.0, 0.72, 0.25, 0.4))
	_edge_mat = _make_line_mat(Color(0.15, 1.0, 0.35, 1.0))
	_lattice_mat = _make_line_mat(Color(1.0, 0.55, 0.12, 1.0))
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
		_clear_children(_edge_root)
		_edge_cache_key = ""
		return
	if not DebugTools.is_available():
		_clear_children(_cell_root)
		_clear_children(_cast_root)
		_clear_children(_edge_root)
		_edge_cache_key = ""
		return
	_update_cell_highlight()
	_update_facing_cast()
	_update_edge_lines()


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _make_line_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Occlude like park meshes (no x-ray through nearer solids).
	mat.no_depth_test = false
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
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


func _update_edge_lines() -> void:
	if not debug_edge_lines:
		_clear_children(_edge_root)
		_edge_cache_key = ""
		return
	var key := _edge_rebuild_key()
	if key == _edge_cache_key and _edge_root.get_child_count() > 0:
		return
	_edge_cache_key = key
	_rebuild_edge_lines()


func _edge_rebuild_key() -> String:
	var s: LevelSpec = _level.spec
	return "%s:%s:%s:%s:%s:%s:%s:%s" % [
		s.get_instance_id(),
		s.cell_w,
		s.cell_h,
		s.decks.size(),
		_level.pipes.size(),
		lattice_spacing,
		pipe_lattice_arc_steps,
		pipe_lattice_z_steps,
	]


func _rebuild_edge_lines() -> void:
	_clear_children(_edge_root)
	var parts: Array = LevelGeometryScript.build_parts(_level.spec, _level.pipes)
	# Lift along world +Y so wires sit just above the shared collision faces.
	var lift := Vector3(0.0, edge_lift, 0.0)
	_add_line_mesh("Edges", _edge_mat, func(st: SurfaceTool) -> void:
		for part in parts:
			if part == null:
				continue
			# Green: boundary edges of walls/backs/endcaps/tops (skip dense ride lattice).
			var role := str(part.meta.get("face_role", ""))
			if role == "ride":
				# Coping / silhouette still useful — boundary only.
				MeshPartDebugScript.append_boundary_edges(st, part, lift)
			else:
				MeshPartDebugScript.append_boundary_edges(st, part, lift)
	)
	_add_line_mesh("Lattice", _lattice_mat, func(st: SurfaceTool) -> void:
		for part in parts:
			if part == null:
				continue
			var role := str(part.meta.get("face_role", ""))
			# Orange lattice visualizes the same triangles used for collision.
			if role in ["ride", "top", "wall", "back", "lava"]:
				MeshPartDebugScript.append_all_edges(st, part, lift)
	)


func _add_line_mesh(mesh_name: String, mat: Material, fill: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	fill.call(st)
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() <= 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.mesh = mesh
	mi.material_override = mat
	_edge_root.add_child(mi)


## Deck tops + vertical walls (skip wall/bottom on coping-shared edges — pipe owns those).
func _append_deck_wireframe(st: SurfaceTool, lift: float) -> void:
	for deck in _level.spec.decks:
		var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
		if poly.size() < 2:
			continue
		var top_h := float(deck.get("height", 0.0)) + lift
		var base_h := float(deck.get("base_height", 0.0)) + lift
		var has_walls := top_h > base_h + 0.05
		var n := poly.size()
		for i in range(n):
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[(i + 1) % n]
			if a.distance_squared_to(b) < 0.01:
				continue
			# Top outline always.
			_add_line_vert(st, a.x, a.y, top_h)
			_add_line_vert(st, b.x, b.y, top_h)
			var on_cope := _deck_edge_on_coping(deck, a, b)
			if has_walls and not on_cope:
				# Bottom of the rendered wall + verticals at both corners.
				_add_line_vert(st, a.x, a.y, base_h)
				_add_line_vert(st, b.x, b.y, base_h)
				_add_line_vert(st, a.x, a.y, top_h)
				_add_line_vert(st, a.x, a.y, base_h)
				_add_line_vert(st, b.x, b.y, top_h)
				_add_line_vert(st, b.x, b.y, base_h)


## Orange lattice on deck tops and non-coping wall faces.
func _append_deck_lattice(st: SurfaceTool, lift: float) -> void:
	var step := maxf(lattice_spacing, 4.0)
	for deck in _level.spec.decks:
		var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
		if poly.size() < 3:
			continue
		var top_h := float(deck.get("height", 0.0)) + lift
		var base_h := float(deck.get("base_height", 0.0)) + lift
		_lattice_poly_top(st, poly, top_h, step)
		if top_h > base_h + 0.05:
			var n := poly.size()
			for i in range(n):
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[(i + 1) % n]
				if a.distance_squared_to(b) < 0.01:
					continue
				if _deck_edge_on_coping(deck, a, b):
					continue
				_lattice_vertical_wall(st, a, b, base_h, top_h, step)


func _lattice_poly_top(st: SurfaceTool, poly: PackedVector2Array, height: float, step: float) -> void:
	var min_x := poly[0].x
	var max_x := poly[0].x
	var min_z := poly[0].y
	var max_z := poly[0].y
	for p in poly:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	# Lines of constant X across Z.
	var x := min_x
	while x <= max_x + 0.001:
		_lattice_polyline_in_poly(st, poly, true, x, min_z, max_z, height, step)
		x += step
	# Lines of constant Z across X.
	var z := min_z
	while z <= max_z + 0.001:
		_lattice_polyline_in_poly(st, poly, false, z, min_x, max_x, height, step)
		z += step


## Walk a straight scan line; emit segments where both endpoints are inside poly.
func _lattice_polyline_in_poly(
	st: SurfaceTool,
	poly: PackedVector2Array,
	fixed_x: bool,
	fixed: float,
	t0: float,
	t1: float,
	height: float,
	step: float,
) -> void:
	var samples := maxi(int(ceil((t1 - t0) / maxf(step * 0.5, 1.0))), 2)
	var prev_in := false
	var prev_t := t0
	for i in range(samples + 1):
		var t := lerpf(t0, t1, float(i) / float(samples))
		var pt := Vector2(fixed, t) if fixed_x else Vector2(t, fixed)
		var inside := LevelSpec.point_in_poly(pt, poly)
		if prev_in and inside:
			if fixed_x:
				_add_line_vert(st, fixed, prev_t, height)
				_add_line_vert(st, fixed, t, height)
			else:
				_add_line_vert(st, prev_t, fixed, height)
				_add_line_vert(st, t, fixed, height)
		prev_in = inside
		prev_t = t


func _lattice_vertical_wall(
	st: SurfaceTool, a: Vector2, b: Vector2, base_h: float, top_h: float, step: float
) -> void:
	var edge_len := a.distance_to(b)
	if edge_len < 0.01:
		return
	var u_steps := maxi(int(ceil(edge_len / step)), 1)
	var v_steps := maxi(int(ceil((top_h - base_h) / step)), 1)
	# Verticals along the wall.
	for i in range(u_steps + 1):
		var u := float(i) / float(u_steps)
		var p := a.lerp(b, u)
		_add_line_vert(st, p.x, p.y, base_h)
		_add_line_vert(st, p.x, p.y, top_h)
	# Horizontals at height bands.
	for j in range(v_steps + 1):
		var h := lerpf(base_h, top_h, float(j) / float(v_steps))
		_add_line_vert(st, a.x, a.y, h)
		_add_line_vert(st, b.x, b.y, h)


func _deck_edge_on_coping(deck: Dictionary, a: Vector2, b: Vector2, eps: float = 0.05) -> bool:
	for anchor in deck.get("anchors", []):
		var cx := float(anchor.get("coping_x", NAN))
		if is_nan(cx):
			continue
		if absf(a.x - cx) <= eps and absf(b.x - cx) <= eps:
			return true
	return false


## Pipe coping + back wall + endcap side silhouettes — never rails on the ride face.
func _append_pipe_wireframe(st: SurfaceTool, lift: float) -> void:
	const ARC_STEPS := 12
	for pipe in _level.pipes:
		var side := int(pipe.side)
		var is_left := side == QuarterPipe.PipeSide.LEFT
		var lip_x := float(pipe.lip_x)
		var radius := float(pipe.radius)
		var base := float(pipe.base_height)
		var z0 := float(pipe.z_min)
		var z1 := float(pipe.z_max)
		if absf(z1 - z0) < 0.01 or radius <= 0.001:
			continue
		var cope_x := PipeMath.coping_x(side, lip_x, radius)
		var cope_h := base + radius
		# Coping (top of back) along Z.
		_add_line_vert(st, cope_x, z0, cope_h + lift)
		_add_line_vert(st, cope_x, z1, cope_h + lift)
		# Back wall bottom along Z.
		_add_line_vert(st, cope_x, z0, base + lift)
		_add_line_vert(st, cope_x, z1, base + lift)
		# Back-wall side verticals at both Z ends.
		_add_line_vert(st, cope_x, z0, cope_h + lift)
		_add_line_vert(st, cope_x, z0, base + lift)
		_add_line_vert(st, cope_x, z1, cope_h + lift)
		_add_line_vert(st, cope_x, z1, base + lift)
		# Endcap sides only (no along-Z ride rails): arc + base chord at z_min/z_max.
		for z_end in [z0, z1]:
			var prev := _pipe_profile_point(lip_x, radius, base, 0.0, is_left)
			for i in range(1, ARC_STEPS + 1):
				var theta := (float(i) / float(ARC_STEPS)) * PI * 0.5
				var p := _pipe_profile_point(lip_x, radius, base, theta, is_left)
				_add_line_vert(st, prev.x, z_end, prev.y + lift)
				_add_line_vert(st, p.x, z_end, p.y + lift)
				prev = p
			_add_line_vert(st, lip_x, z_end, base + lift)
			_add_line_vert(st, cope_x, z_end, base + lift)


## Orange lattice on pipe ride surface + outer back wall.
func _append_pipe_lattice(st: SurfaceTool, lift: float) -> void:
	var arc_n := maxi(pipe_lattice_arc_steps, 2)
	var z_n := maxi(pipe_lattice_z_steps, 2)
	for pipe in _level.pipes:
		var side := int(pipe.side)
		var is_left := side == QuarterPipe.PipeSide.LEFT
		var lip_x := float(pipe.lip_x)
		var radius := float(pipe.radius)
		var base := float(pipe.base_height)
		var z0 := float(pipe.z_min)
		var z1 := float(pipe.z_max)
		if absf(z1 - z0) < 0.01 or radius <= 0.001:
			continue
		var cope_x := PipeMath.coping_x(side, lip_x, radius)
		var cope_h := base + radius
		# Ride surface: constant-θ rails along Z + constant-Z arcs.
		for i in range(arc_n + 1):
			var theta := (float(i) / float(arc_n)) * PI * 0.5
			var p := _pipe_profile_point(lip_x, radius, base, theta, is_left)
			_add_line_vert(st, p.x, z0, p.y + lift)
			_add_line_vert(st, p.x, z1, p.y + lift)
		for j in range(z_n + 1):
			var z := lerpf(z0, z1, float(j) / float(z_n))
			var prev := _pipe_profile_point(lip_x, radius, base, 0.0, is_left)
			for i in range(1, arc_n + 1):
				var theta := (float(i) / float(arc_n)) * PI * 0.5
				var p := _pipe_profile_point(lip_x, radius, base, theta, is_left)
				_add_line_vert(st, prev.x, z, prev.y + lift)
				_add_line_vert(st, p.x, z, p.y + lift)
				prev = p
		# Back wall lattice (coping face).
		var step := maxf(lattice_spacing, 4.0)
		var z_steps := maxi(int(ceil(absf(z1 - z0) / step)), 1)
		var h_steps := maxi(int(ceil((cope_h - base) / step)), 1)
		for i in range(z_steps + 1):
			var z := lerpf(z0, z1, float(i) / float(z_steps))
			_add_line_vert(st, cope_x, z, base + lift)
			_add_line_vert(st, cope_x, z, cope_h + lift)
		for j in range(h_steps + 1):
			var h := lerpf(base, cope_h, float(j) / float(h_steps)) + lift
			_add_line_vert(st, cope_x, z0, h)
			_add_line_vert(st, cope_x, z1, h)


## Profile point matching PipeMeshBuilder: Vector2(x, height), θ=0 lip → π/2 coping.
func _pipe_profile_point(
	lip_x: float, radius: float, base_height: float, theta: float, is_left: bool
) -> Vector2:
	var h := base_height + radius * (1.0 - cos(theta))
	var x: float
	if is_left:
		x = lip_x - radius * sin(theta)
	else:
		x = lip_x + radius * sin(theta)
	return Vector2(x, h)


func _add_line_vert(st: SurfaceTool, logical_x: float, logical_z: float, height: float) -> void:
	st.add_vertex(WorldSpace.logical_to_world(logical_x, logical_z, height))


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
