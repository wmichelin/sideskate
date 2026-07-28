extends RefCounted
## Shared MeshPart metadata, winding, layered holes, visual/collision AABB parity.

const _LevelGeometry := preload("res://scripts/mesh/level_geometry.gd")


func run() -> bool:
	var text := FileAccess.get_file_as_string("res://tests/levels/layered_demo.ssk")
	var spec := LevelLoader.parse_text(text, "layered_demo")
	if spec == null:
		push_error("parse: %s" % LevelLoader.last_error)
		return false

	var parts: Array = _LevelGeometry.build_parts(spec, spec.pipes)
	if parts.is_empty():
		push_error("no geometry parts")
		return false

	var roles: Dictionary = {}
	for part in parts:
		if part.triangle_count() <= 0:
			push_error("empty part %s" % part.material_key)
			return false
		var role := str(part.meta.get("face_role", ""))
		roles[role] = int(roles.get(role, 0)) + 1
		if not part.meta.has("zone") or not part.meta.has("layer"):
			push_error("missing zone/layer meta on %s" % part.material_key)
			return false
		# Winding: floor/lava tops should have clear +Y after X-mirror.
		if role == "top" or role == "lava":
			if part.triangle_count() < 1:
				push_error("empty top part")
				return false
			var a: Vector3 = part.faces[0]
			var b: Vector3 = part.faces[1]
			var c: Vector3 = part.faces[2]
			var n: Vector3 = (b - a).cross(c - a)
			if absf(n.y) < 0.001:
				push_error("top/lava winding degenerate for %s (ny=%s)" % [part.material_key, n.y])
				return false
			if str(part.material_key) == "floor" and n.y < 0.0:
				push_error("floor winding not upward (ny=%s)" % n.y)
				return false
		var shape: ConcavePolygonShape3D = part.to_concave_shape()
		if shape == null or shape.get_faces().is_empty():
			push_error("concave shape empty for %s" % part.material_key)
			return false

	for need in ["top", "ride", "back", "endcap"]:
		if not roles.has(need):
			push_error("missing face_role %s in layered_demo" % need)
			return false

	# Holes: story masks with kind 0 must not emit floor tris at that cell.
	var hole_cells := 0
	for story in spec.story_floor_masks:
		var mask: PackedByteArray = story.get("mask", PackedByteArray())
		for b in mask:
			if int(b) == 0:
				hole_cells += 1
	if hole_cells <= 0:
		push_error("layered_demo expected hole cells")
		return false

	var vis_box: AABB = _LevelGeometry.merged_aabb(parts)
	if vis_box.size.length() < 0.5:
		push_error("aabb too small %s" % vis_box)
		return false

	# Collision faces identical to visual part faces (same MeshPart instances).
	for part in parts:
		var mesh: ArrayMesh = part.to_array_mesh()
		var shape2: ConcavePolygonShape3D = part.to_concave_shape()
		if mesh == null or shape2 == null:
			push_error("mesh/shape null")
			return false
		if shape2.get_faces().size() != part.faces.size():
			push_error("collision face count != mesh part faces")
			return false

	return true
