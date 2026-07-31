class_name DeckMeshBuilder
extends RefCounted
## Deck tops + vertical side walls from LevelSpec.decks.
## Tops follow `#` cells (or a concave-safe outline triangulation) — never fan
## fill, which spans notches over shorter deck rows and z-fights the pipe.


const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")
const _FloorMeshBuilder := preload("res://scripts/mesh/floor_mesh_builder.gd")


static func build_parts(spec: LevelSpec) -> Array:
	var out: Array = []
	if spec == null:
		return out
	for deck in spec.decks:
		out.append_array(build_one_parts(deck, spec))
	return out


static func build(spec: LevelSpec) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_parts(spec))


static func build_one(deck: Dictionary, spec: LevelSpec = null) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_one_parts(deck, spec))


static func build_one_parts(deck: Dictionary, spec: LevelSpec = null) -> Array:
	var out: Array = []
	var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
	if poly.size() < 3 and not deck.has("cells"):
		return out
	var top_h := float(deck.get("height", 0.0))
	var base_h := float(deck.get("base_height", 0.0))
	var layer := int(deck.get("layer", 0))
	var top = _build_top_part(deck, poly, top_h, layer, base_h, spec)
	if top != null and not top.is_empty():
		# Keep logical footprint for solid collision extrusion.
		top.meta["poly"] = poly.duplicate()
		out.append(top)
	if poly.size() >= 2:
		var walls = _build_walls_part(deck, poly, top_h, base_h, layer)
		if walls != null and not walls.is_empty():
			walls.meta["poly"] = poly.duplicate()
			out.append(walls)
	return out


static func _build_top_part(
	deck: Dictionary,
	poly: PackedVector2Array,
	height: float,
	layer: int,
	base_h: float,
	spec: LevelSpec,
):
	var part = _MeshPart.make(
		"deck",
		layer,
		{
			"zone": "deck",
			"layer": layer,
			"face_role": "top",
			"height": height,
			"base_height": base_h,
		},
	)
	# Prefer `#` cells: exact glyph coverage, no concave fan fill over pipes.
	var cells: Array = deck.get("cells", [])
	if cells is Array and not cells.is_empty() and spec != null \
			and spec.grid_h > 0 and spec.cell_w > 0.0 and spec.cell_h > 0.0:
		_append_cell_top_quads(part, cells, spec.cell_w, spec.cell_h, spec.grid_h, height)
	elif poly.size() >= 3:
		_append_outline_top_tris(part, poly, height)
	return part


## Row-merged quads over deck cells only (same strategy as FloorMeshBuilder).
static func _append_cell_top_quads(
	part,
	cells: Array,
	cw: float,
	ch: float,
	grid_h: int,
	height: float,
) -> void:
	var by_row: Dictionary = {}
	for cell in cells:
		var ci: Vector2i = cell
		if not by_row.has(ci.y):
			by_row[ci.y] = []
		(by_row[ci.y] as Array).append(ci.x)
	var rows: Array = by_row.keys()
	rows.sort()
	for r in rows:
		var cols: Array = by_row[r]
		cols.sort()
		var z0 := float(grid_h - 1 - int(r)) * ch
		var z1 := float(grid_h - int(r)) * ch
		var i := 0
		while i < cols.size():
			var c0: int = int(cols[i])
			var c1 := c0 + 1
			i += 1
			while i < cols.size() and int(cols[i]) == c1:
				c1 += 1
				i += 1
			_append_top_quad(part, float(c0) * cw, z0, float(c1) * cw, z1, height)


static func _append_top_quad(
	part, x0: float, z0: float, x1: float, z1: float, height: float
) -> void:
	var a: Vector3 = _WorldSpace.logical_to_world(x0, z0, height)
	var b: Vector3 = _WorldSpace.logical_to_world(x1, z0, height)
	var c: Vector3 = _WorldSpace.logical_to_world(x1, z1, height)
	var d: Vector3 = _WorldSpace.logical_to_world(x0, z1, height)
	# Match FloorMeshBuilder winding (upward after X-mirror).
	part.append_tri(a, b, c)
	part.append_tri(a, c, d)


## Concave-safe outline fill when cells are unavailable (legacy decks).
static func _append_outline_top_tris(part, poly: PackedVector2Array, height: float) -> void:
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	if idx.is_empty():
		# Last resort: fan (convex only). Prefer empty over filling a notch wrong.
		return
	var i := 0
	while i + 2 < idx.size():
		var p0: Vector2 = poly[idx[i]]
		var p1: Vector2 = poly[idx[i + 1]]
		var p2: Vector2 = poly[idx[i + 2]]
		var a: Vector3 = _WorldSpace.logical_to_world(p0.x, p0.y, height)
		var b: Vector3 = _WorldSpace.logical_to_world(p1.x, p1.y, height)
		var c: Vector3 = _WorldSpace.logical_to_world(p2.x, p2.y, height)
		# Geometry2D is CCW in logical XZ; X-mirror flips winding → swap for +Y.
		part.append_tri(a, c, b)
		i += 3


static func _build_walls_part(
	deck: Dictionary,
	poly: PackedVector2Array,
	top_h: float,
	base_h: float,
	layer: int,
):
	if top_h <= base_h + 0.05:
		return null
	var part = _MeshPart.make(
		"deck_wall",
		layer,
		{
			"zone": "deck",
			"layer": layer,
			"face_role": "wall",
			"height": top_h,
			"base_height": base_h,
		},
	)
	var n := poly.size()
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if edge_on_coping(deck, a, b):
			continue
		if a.distance_squared_to(b) < 0.01:
			continue
		var t0: Vector3 = _WorldSpace.logical_to_world(a.x, a.y, top_h)
		var t1: Vector3 = _WorldSpace.logical_to_world(b.x, b.y, top_h)
		var b0: Vector3 = _WorldSpace.logical_to_world(a.x, a.y, base_h)
		var b1: Vector3 = _WorldSpace.logical_to_world(b.x, b.y, base_h)
		part.append_tri(t0, b1, t1)
		part.append_tri(t0, b0, b1)
	if part.is_empty():
		return null
	return part


static func edge_on_coping(deck: Dictionary, a: Vector2, b: Vector2, eps: float = 0.05) -> bool:
	for anchor in deck.get("anchors", []):
		var cx := float(anchor.get("coping_x", NAN))
		if is_nan(cx):
			continue
		if absf(a.x - cx) <= eps and absf(b.x - cx) <= eps:
			return true
	return false
