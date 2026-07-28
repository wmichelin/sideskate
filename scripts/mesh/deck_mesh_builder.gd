class_name DeckMeshBuilder
extends RefCounted
## Deck tops + vertical side walls from LevelSpec.decks.

const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")
const _FloorMeshBuilder := preload("res://scripts/mesh/floor_mesh_builder.gd")


static func build_parts(spec: LevelSpec) -> Array:
	var out: Array = []
	if spec == null:
		return out
	for deck in spec.decks:
		out.append_array(build_one_parts(deck))
	return out


static func build(spec: LevelSpec) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_parts(spec))


static func build_one(deck: Dictionary) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_one_parts(deck))


static func build_one_parts(deck: Dictionary) -> Array:
	var out: Array = []
	var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
	if poly.size() < 3:
		return out
	var top_h := float(deck.get("height", 0.0))
	var base_h := float(deck.get("base_height", 0.0))
	var layer := int(deck.get("layer", 0))
	var top = _build_top_part(poly, top_h, layer, base_h)
	if top != null and not top.is_empty():
		# Keep logical footprint for solid collision extrusion.
		top.meta["poly"] = poly.duplicate()
		out.append(top)
	var walls = _build_walls_part(deck, poly, top_h, base_h, layer)
	if walls != null and not walls.is_empty():
		walls.meta["poly"] = poly.duplicate()
		out.append(walls)
	return out


static func _build_top_part(
	poly: PackedVector2Array, height: float, layer: int, base_h: float
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
	# Fan triangulate from first vertex (decks are convex outlines from loader).
	var origin: Vector3 = _WorldSpace.logical_to_world(poly[0].x, poly[0].y, height)
	for i in range(1, poly.size() - 1):
		var a: Vector3 = _WorldSpace.logical_to_world(poly[i].x, poly[i].y, height)
		var b: Vector3 = _WorldSpace.logical_to_world(poly[i + 1].x, poly[i + 1].y, height)
		part.append_tri(origin, b, a)
	return part


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
