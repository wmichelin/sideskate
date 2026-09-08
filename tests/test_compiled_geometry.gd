extends RefCounted
## Numerical geometry and footprint checks against the compiled park.

const Geometry := preload("res://scripts/mesh/level_geometry.gd")
const Space := preload("res://scripts/world_space.gd")


func run() -> bool:
	return _exact_footprints() and _corner_touching_boundaries() and _gate_geometry()


func _corner_touching_boundaries() -> bool:
	var spec := LevelLoader.parse_text("""ssk 2
name touching_holes
---
layer 0
height 0
========
==.=====
===.====
====@===
========
""", "touching_holes")
	var model := IdlCompiler.compile_spec(spec)
	return _glyph_coverage(spec, model) and _flat_mesh_coverage(model)


func _gate_geometry() -> bool:
	var displaced_checked := false
	for path in [
		"res://levels/layers.ssk", "res://levels/offset_demo.ssk",
		"res://debug_levels/plaza_default.ssk", "res://debug_levels/spine_demo.ssk",
		"res://debug_levels/layered_demo.ssk", "res://debug_levels/variable_height_ramps.ssk",
		"res://debug_levels/plaza_default_deep.ssk",
	]:
		var spec := LevelLoader.parse_text(FileAccess.get_file_as_string(path), path)
		var model := IdlCompiler.compile_spec(spec)
		if not _glyph_coverage(spec, model):
			return false
		var parts := Geometry.build_model_parts(model)
		var error := _parts_error(model, parts)
		if not error.is_empty():
			return _fail("%s: %s" % [path, error])
		if not displaced_checked:
			for part in parts:
				if str(part.meta.get("face_role", "")) != "ride":
					continue
				var original: Vector3 = part.faces[0]
				part.faces[0] += Vector3(0.0, 0.25, 0.0)
				if _parts_error(model, parts).is_empty():
					return _fail("a displaced ride vertex passed numerical geometry validation")
				part.faces[0] = original
				displaced_checked = true
				break
	return displaced_checked


## Each compiled footprint must agree with every source glyph, including cells
## inside a component's bounds that belong to another surface or an exact hole.
func _glyph_coverage(spec: LevelSpec, model: ParkModel) -> bool:
	for layer in spec.layers:
		var rows: PackedStringArray = layer.rows
		for r in range(rows.size()):
			for c in range(rows[r].length()):
				var x := (c + 0.5) * spec.cell_w
				var z := (spec.grid_h - r - 0.5) * spec.cell_h
				var found := {"floor": false, "deck": false, "lava": false}
				for id in model.all_patch_ids():
					if id == "__void_floor__" or int(str(id).get_slice("_L", 1)) != int(layer.index):
						continue
					var patch: SupportPatch = model.patches[id]
					if patch.contains_xz(x, z):
						found[str(id).get_slice("_", 0)] = true
				var glyph := rows[r][c]
				if found.floor != (glyph in ["=", "@", "-", "x", "X"]) \
						or found.deck != (glyph == "#") or found.lava != (glyph in ["x", "X"]):
					return _fail("%s layer%s cell(%s,%s) glyph=%s footprint=%s" % [spec.name, layer.index, c, r, glyph, found])
	return true


func _logical(world: Vector3) -> Vector3:
	var p := Space.world_to_logical(world)
	return Vector3(p.x, p.z, p.height)


func _parts_error(model: ParkModel, parts: Array) -> String:
	if parts.is_empty():
		return "empty geometry"
	for part in parts:
		var id := str(part.meta.get("surface_id", ""))
		if str(part.meta.get("model_hash", "")) != model.model_hash:
			return "geometry has a foreign source model"
		var role := str(part.meta.get("face_role", ""))
		var surf = model.pipes.get(id, model.ramps.get(id))
		var patch: SupportPatch = model.patches.get(id)
		var wall: WallSurface = model.walls.get(id)
		if surf == null and patch == null and wall == null and not model.rails.has(id):
			return "unknown geometric owner %s" % id
		var arrays: Array = part.to_array_mesh().surface_get_arrays(0)
		var mesh_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if mesh_normals.size() != part.faces.size():
			return "mesh omitted vertex normals"
		for i in range(0, part.faces.size(), 3):
			var a: Vector3 = part.faces[i]
			var b: Vector3 = part.faces[i + 1]
			var c: Vector3 = part.faces[i + 2]
			if not a.is_finite() or not b.is_finite() or not c.is_finite():
				return "non-finite triangle"
			var normal := (c - a).cross(b - a)
			if normal.length_squared() < 0.00000001:
				return "degenerate triangle on %s %s" % [id, role]
			normal = normal.normalized()
			for j in range(3):
				if not mesh_normals[i + j].is_finite() or mesh_normals[i + j].dot(normal) < (0.99 if role == "ride" else 0.999):
					return "ArrayMesh normal disagrees with clockwise face on %s" % id
			# Check the normals that Godot actually renders against analytical
			# geometry, not just a triangle cross with an assumed winding.
			normal = mesh_normals[i]
			var center := _logical((a + b + c) / 3.0)
			if surf != null and role == "ride":
				var low_u := INF
				var high_u := -INF
				for vertex in [a, b, c]:
					var p := _logical(vertex)
					var theta: float = surf.theta_from_xz(p.x, p.y)
					if surf is PipeSurface:
						var sample: Dictionary = surf.sample_at_z(p.y)
						# atan2 remains stable at both ellipse endpoints after
						# world-meter float conversion (asin(x) does not at coping).
						theta = atan2(absf(p.x - sample.lip_x) / sample.radius, 1.0 - (p.z - sample.base_height) / sample.rise)
					if is_nan(theta) or absf(surf.height_at_theta(p.y, theta) - p.z) > 0.02 \
							or absf(surf.x_at_theta(p.y, theta) - p.x) > 0.02:
						return "ride vertex is displaced from %s" % id
					low_u = minf(low_u, theta)
					high_u = maxf(high_u, theta)
				var theta := (low_u + high_u) * 0.5
				# Differentiate authoritative sample positions. This also detects
				# reversed winding without reusing the mesh builder's triangles.
				var dt := 0.0001
				var before := Vector3(surf.x_at_theta(center.y, theta - dt), center.y, surf.height_at_theta(center.y, theta - dt))
				var after := Vector3(surf.x_at_theta(center.y, theta + dt), center.y, surf.height_at_theta(center.y, theta + dt))
				var tangent := Space.logical_velocity_to_world(after.x - before.x, 0.0, after.z - before.z)
				var expected: Vector3 = tangent.cross(Vector3.BACK).normalized() * surf.outward_sign()
				if normal.dot(expected) < 0.99:
					return "ride normal disagrees with %s: got%s want%s" % [id, normal, expected]
			elif surf != null and role in ["back", "endcap"]:
				for vertex in [a, b, c]:
					var p := _logical(vertex)
					var sample: Dictionary = surf.sample_at_z(p.y)
					var on_back: bool = absf(p.x - surf.coping_x_at(p.y)) < 0.02
					var theta: float = surf.theta_from_xz(p.x, p.y)
					if p.z < float(sample.base_height) - 0.02 or p.z > surf.height_at_theta(p.y, PI * 0.5) + 0.02:
						return "slope side vertex outside height bounds"
					if role == "back" and not on_back:
						return "slope back vertex outside coping plane"
					if role == "endcap" and (absf(p.y - surf.z_min) > 0.02 and absf(p.y - surf.z_max) > 0.02):
						return "endcap outside depth boundary"
					if role == "endcap" and not (on_back and absf(p.z - sample.base_height) < 0.02):
						if surf is PipeSurface:
							theta = atan2(absf(p.x - sample.lip_x) / sample.radius, 1.0 - (p.z - sample.base_height) / sample.rise)
						if is_nan(theta) or absf(surf.height_at_theta(p.y, theta) - p.z) > 0.02:
							return "endcap vertex outside analytical profile"
				var expected := Vector3(-surf.outward_sign(), 0.0, 0.0) if role == "back" else Vector3(0.0, 0.0, -1.0 if absf(center.y - surf.z_min) < 0.02 else 1.0)
				if normal.dot(expected) < 0.99:
					return "slope exterior normal reversed"
			elif patch != null and role in ["top", "lava"]:
				if not patch.contains_xz(center.x, center.y) or absf(center.z - patch.height) > 0.01:
					return "flat triangle is outside %s" % id
				if normal.dot(Vector3.UP) < 0.999:
					return "flat normal does not face upward"
			elif patch != null and role == "wall":
				var outward := Vector2(-normal.x, normal.z)
				if absf(normal.y) > 0.001 or patch.contains_xz(center.x + outward.x * 0.5, center.y + outward.y * 0.5) \
						or not patch.contains_xz(center.x - outward.x * 0.5, center.y - outward.y * 0.5):
					return "deck wall normal does not face the exterior"
			elif model.rails.has(id):
				var radial: Vector3 = (a + b + c) / 3.0 - part.aabb().get_center()
				if normal.dot(radial) <= 0.0:
					return "rail box normal does not face outward"
			elif wall != null:
				var source: PipeSurface = model.pipes[wall.source_pipe_id]
				if normal.dot(Vector3(source.outward_sign(), 0.0, 0.0)) < 0.99:
					return "wall normal does not face the bowl"
				for vertex in [a, b, c]:
					var p := _logical(vertex)
					var s := wall.sample_at_z(p.y)
					if absf(p.x - float(s.x)) > 0.01 or p.z < float(s.bottom_height) - 0.01 \
							or p.z > float(s.top_height) + 0.01:
						return "wall vertex is outside %s" % id
	return ""


func _exact_footprints() -> bool:
	var floor_model := IdlCompiler.compile_text("""ssk 2
name floor_hole
---
layer 0
height 0
=======
=..====
=..=@==
=======
""", "floor_hole")
	if floor_model == null or not floor_model.is_valid():
		return _fail("floor hole did not compile")
	var floor_query := SurfaceQuery.new(floor_model)
	var hole := floor_query.top_support(70.5, 70.5, 0.0)
	if not _flat_mesh_coverage(floor_model):
		return false
	if str(hole.get("surface_id", "")) != "__void_floor__":
		return _fail("enclosed dot cell acquired phantom floor support")
	var deck_sim := PlayerSim.new()
	if not deck_sim.setup_from_text("""ssk 2
name deck_hole
deck_height 120
---
layer 0
height 0
=========
===###===
===#@#===
===###===
=========
""", "deck_hole"):
		return _fail("deck hole did not compile")
	if not deck_sim.query.blocker_at(deck_sim.state.position).is_empty():
		return _fail("floor spawn inside enclosed deck hole was covered by deck solid")
	var hole_position := deck_sim.state.position
	deck_sim.respawn()
	if not deck_sim.state.position.is_equal_approx(hole_position) \
			or not deck_sim.query.blocker_at(deck_sim.state.position).is_empty():
		return _fail("deck-hole checkpoint did not restore a legal floor pose")
	var deck: SupportPatch = null
	for id in deck_sim.model.all_patch_ids():
		if deck_sim.model.patches[id].kind == SimKinds.SurfaceKind.DECK:
			deck = deck_sim.model.patches[id]
			break
	if deck == null or deck.holes.size() != 1:
		return _fail("compiled deck did not retain its interior boundary")
	var inner_face := deck_sim.query.blocker_at(hole_position + Vector3(20.0, 0.0, 0.0))
	if str(inner_face.get("kind", "")) != "feature_wall":
		return _fail("deck-hole boundary did not block entry into the deck side")
	if not _flat_mesh_coverage(deck_sim.model):
		return false
	var hash_before := deck_sim.model.model_hash
	deck.holes.clear()
	if IdlCompiler._hash_model(deck_sim.model) == hash_before:
		return _fail("model identity omitted an interior footprint boundary")
	var lava_model := IdlCompiler.compile_text("""ssk 2
name concave_lava
---
layer 0
height 0
xxxx===
x======
x==@===
=======
""", "concave_lava")
	if lava_model == null or not lava_model.is_valid():
		return _fail("concave lava did not compile")
	if not _flat_mesh_coverage(lava_model):
		return false
	var lava_query := SurfaceQuery.new(lava_model)
	if not lava_query.lethal_at(lava_model.spawn_x, lava_model.spawn_z, 0.0).is_empty():
		return _fail("lava bounding box made the dry concavity lethal")
	if lava_query.lethal_at(23.5, 70.5, 0.0).is_empty():
		return _fail("actual lava cell lost its hazard")
	var rail_model := IdlCompiler.compile_text("""ssk 2
name rail_floor
---
layer 0
height 0
=======
==---==
===@===
=======
""", "rail_floor")
	var rail_query := SurfaceQuery.new(rail_model)
	var rail_support := rail_query.top_support(164.5, 117.5, 0.0)
	if str(rail_support.get("surface_id", "")) == "__void_floor__":
		return _fail("rail glyph lost its documented floor support")
	return true


## Test the generated triangles at each fixture cell as well as the analytical
## footprints, so a mesh that bridges a hole or a dry lava notch fails.
func _flat_mesh_coverage(model: ParkModel) -> bool:
	var parts := Geometry.build_model_parts(model)
	var query := SurfaceQuery.new(model)
	for id in model.all_patch_ids():
		if id == "__void_floor__":
			continue
		var patch: SupportPatch = model.patches[id]
		var triangles: Array[PackedVector2Array] = []
		for part in parts:
			if part.meta.surface_id != id or part.meta.face_role not in ["top", "lava"]:
				continue
			for i in range(0, part.faces.size(), 3):
				var triangle := PackedVector2Array()
				for j in range(3):
					var p := _logical(part.faces[i + j])
					triangle.append(Vector2(p.x, p.y))
				triangles.append(triangle)
		for r in range(model.grid_h):
			for c in range(model.grid_w):
				var center := Vector2((c + 0.5) * model.cell_w, (r + 0.5) * model.cell_h)
				var rendered := false
				for triangle in triangles:
					if Geometry2D.is_point_in_polygon(center, triangle):
						rendered = true
						break
				var owner := str(query.top_support(center.x, center.y, patch.height).get("surface_id", ""))
				if rendered != (owner == id):
					return _fail("flat mesh coverage differs from %s at %s" % [id, center])
	return true


func _fail(message: String) -> bool:
	push_error("compiled geometry: %s" % message)
	return false
