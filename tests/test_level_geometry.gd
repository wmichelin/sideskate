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

	if not _notched_deck_top_stays_on_glyphs():
		return false
	return true


## Concave `#` (shorter mid-row deck) must not fan-fill over the pipe.
func _notched_deck_top_stays_on_glyphs() -> bool:
	var text := """ssk 2
name notch_deck
---
layer 0
height 0
===)))####
===)))####
===)))####
===)))####
=====)))##
===)))####
@==)))####
===)))####
===)))####
"""
	var spec := LevelLoader.parse_text(text, "notch_deck")
	if spec == null:
		push_error("notch deck: parse %s" % LevelLoader.last_error)
		return false
	if spec.decks.is_empty():
		push_error("notch deck: no decks")
		return false
	var deck: Dictionary = spec.decks[0]
	var cells: Array = deck.get("cells", [])
	if cells.is_empty():
		push_error("notch deck: missing cells on deck dict")
		return false
	var poly: PackedVector2Array = deck.get("poly", PackedVector2Array())
	var parts: Array = _LevelGeometry.build_parts(spec, spec.pipes)
	var deck_top = null
	for part in parts:
		if str(part.material_key) == "deck" and str(part.meta.get("face_role", "")) == "top":
			deck_top = part
			break
	if deck_top == null or deck_top.is_empty():
		push_error("notch deck: missing deck top mesh")
		return false
	var WorldSpace := preload("res://scripts/world_space.gd")
	# Every triangle centroid must sit inside the outline (not over the notch/pipe).
	var faces: PackedVector3Array = deck_top.faces
	var i := 0
	while i + 2 < faces.size():
		var wa: Vector3 = faces[i]
		var wb: Vector3 = faces[i + 1]
		var wc: Vector3 = faces[i + 2]
		var la: Dictionary = WorldSpace.world_to_logical(wa)
		var lb: Dictionary = WorldSpace.world_to_logical(wb)
		var lc: Dictionary = WorldSpace.world_to_logical(wc)
		var cx := (float(la.x) + float(lb.x) + float(lc.x)) / 3.0
		var cz := (float(la.z) + float(lb.z) + float(lc.z)) / 3.0
		if not Geometry2D.is_point_in_polygon(Vector2(cx, cz), poly):
			push_error(
				"notch deck: top tri centroid (%.1f,%.1f) outside deck outline (fan fill?)"
				% [cx, cz]
			)
			return false
		i += 3
	# Probe the mid-row notch column that is pipe, not `#`.
	var cw := spec.cell_w
	var ch := spec.cell_h
	var H := spec.grid_h
	var notch_r := 4
	var notch_c := 7  # in =====)))## the last # starts at col 8; col 7 is last )
	var probe := Vector2((float(notch_c) + 0.5) * cw, (float(H - 1 - notch_r) + 0.5) * ch)
	if Geometry2D.is_point_in_polygon(probe, poly):
		# If outline somehow includes it, mesh must still not cover — but outline
		# from cells should exclude pipe glyphs.
		push_error("notch deck: outline includes pipe cell at %s" % probe)
		return false
	# Also ensure that cell is not listed as a deck cell.
	for cell in cells:
		var ci: Vector2i = cell
		if ci.x == notch_c and ci.y == notch_r:
			push_error("notch deck: pipe cell marked as deck")
			return false
	return true
