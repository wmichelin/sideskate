class_name MeshPartDebug
extends RefCounted
## Green boundary wires + orange triangle-edge lattice from MeshPart faces.


static func append_boundary_edges(st: SurfaceTool, part: MeshPart, lift: Vector3 = Vector3.ZERO) -> void:
	if part == null or part.is_empty():
		return
	var edge_count: Dictionary = {}
	var edge_pts: Dictionary = {}
	var n := part.triangle_count()
	for t in range(n):
		var i0 := t * 3
		var a: Vector3 = part.faces[i0]
		var b: Vector3 = part.faces[i0 + 1]
		var c: Vector3 = part.faces[i0 + 2]
		_count_edge(edge_count, edge_pts, a, b)
		_count_edge(edge_count, edge_pts, b, c)
		_count_edge(edge_count, edge_pts, c, a)
	for key in edge_count.keys():
		if int(edge_count[key]) != 1:
			continue
		var pair: Array = edge_pts[key]
		st.add_vertex(pair[0] + lift)
		st.add_vertex(pair[1] + lift)


static func append_all_edges(st: SurfaceTool, part: MeshPart, lift: Vector3 = Vector3.ZERO) -> void:
	if part == null or part.is_empty():
		return
	var seen: Dictionary = {}
	var n := part.triangle_count()
	for t in range(n):
		var i0 := t * 3
		var a: Vector3 = part.faces[i0]
		var b: Vector3 = part.faces[i0 + 1]
		var c: Vector3 = part.faces[i0 + 2]
		_emit_unique_edge(st, seen, a, b, lift)
		_emit_unique_edge(st, seen, b, c, lift)
		_emit_unique_edge(st, seen, c, a, lift)


static func _count_edge(counts: Dictionary, pts: Dictionary, a: Vector3, b: Vector3) -> void:
	var key := _edge_key(a, b)
	counts[key] = int(counts.get(key, 0)) + 1
	if not pts.has(key):
		pts[key] = [a, b]


static func _emit_unique_edge(
	st: SurfaceTool, seen: Dictionary, a: Vector3, b: Vector3, lift: Vector3
) -> void:
	var key := _edge_key(a, b)
	if seen.has(key):
		return
	seen[key] = true
	st.add_vertex(a + lift)
	st.add_vertex(b + lift)


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var a2 := a
	var b2 := b
	# Order-independent key with quantized coords.
	if _lex_less(b, a):
		a2 = b
		b2 = a
	return "%s|%s" % [_q(a2), _q(b2)]


static func _lex_less(a: Vector3, b: Vector3) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


static func _q(v: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [v.x, v.y, v.z]
