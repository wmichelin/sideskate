class_name DeckMeshBuilder
extends RefCounted
## Deck tops + vertical side walls from LevelSpec.decks.


static func build(spec: LevelSpec) -> Array:
	var out: Array = []
	if spec == null:
		return out
	for deck in spec.decks:
		var parts := build_one(deck)
		out.append_array(parts)
	return out


static func build_one(deck: Dictionary) -> Array:
	var out: Array = []
	var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
	if poly.size() < 3:
		return out
	var top_h := float(deck.get("height", 0.0))
	var base_h := float(deck.get("base_height", 0.0))
	var layer := int(deck.get("layer", 0))
	var top := _build_top(poly, top_h)
	if top != null:
		out.append({"mesh": top, "material_key": "deck", "layer": layer})
	var walls := _build_walls(deck, poly, top_h, base_h)
	if walls != null:
		out.append({"mesh": walls, "material_key": "deck_wall", "layer": layer})
	return out


static func _build_top(poly: PackedVector2Array, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Fan triangulate from first vertex (decks are convex outlines from loader).
	var origin := WorldSpace.logical_to_world(poly[0].x, poly[0].y, height)
	for i in range(1, poly.size() - 1):
		var a := WorldSpace.logical_to_world(poly[i].x, poly[i].y, height)
		var b := WorldSpace.logical_to_world(poly[i + 1].x, poly[i + 1].y, height)
		st.add_vertex(origin)
		st.add_vertex(b)
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


static func _build_walls(
	deck: Dictionary, poly: PackedVector2Array, top_h: float, base_h: float
) -> ArrayMesh:
	if top_h <= base_h + 0.05:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := poly.size()
	var added := false
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if _edge_on_coping(deck, a, b):
			continue
		if a.distance_squared_to(b) < 0.01:
			continue
		var t0 := WorldSpace.logical_to_world(a.x, a.y, top_h)
		var t1 := WorldSpace.logical_to_world(b.x, b.y, top_h)
		var b0 := WorldSpace.logical_to_world(a.x, a.y, base_h)
		var b1 := WorldSpace.logical_to_world(b.x, b.y, base_h)
		st.add_vertex(t0)
		st.add_vertex(b1)
		st.add_vertex(t1)
		st.add_vertex(t0)
		st.add_vertex(b0)
		st.add_vertex(b1)
		added = true
	if not added:
		return null
	st.generate_normals()
	return st.commit()


static func _edge_on_coping(deck: Dictionary, a: Vector2, b: Vector2, eps: float = 0.05) -> bool:
	for anchor in deck.get("anchors", []):
		var cx := float(anchor.get("coping_x", NAN))
		if is_nan(cx):
			continue
		if absf(a.x - cx) <= eps and absf(b.x - cx) <= eps:
			return true
	return false
