class_name CompiledParkMeshBuilder
extends RefCounted
## Presentation tessellation of the immutable analytical park. Coordinates come
## from compiled surfaces; neither LevelSpec nor QuarterPipe owns this geometry.

const ARC_STEPS := 12
const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")
const _RailMeshBuilder := preload("res://scripts/mesh/rail_mesh_builder.gd")


static func build_parts(model: ParkModel) -> Array:
	var parts: Array = []
	if model == null or not model.is_valid():
		return parts
	for id in model.all_patch_ids():
		if id == "__void_floor__":
			continue
		parts.append_array(_patch_parts(model, model.patches[id]))
	for id in model.all_pipe_ids():
		parts.append_array(_slope_parts(model, model.pipes[id], false))
	for id in model.all_ramp_ids():
		parts.append_array(_slope_parts(model, model.ramps[id], true))
	for id in model.all_wall_ids():
		parts.append(_wall_part(model, model.walls[id]))
	for id in model.all_rail_ids():
		parts.append_array(_rail_parts(model, model.rails[id]))
	# Geometry above is constructed with outward right-hand cross products.
	# Godot uses clockwise front faces and generates the opposite normal.
	for part in parts:
		for i in range(0, part.faces.size(), 3):
			var second: Vector3 = part.faces[i + 1]
			part.faces[i + 1] = part.faces[i + 2]
			part.faces[i + 2] = second
	return parts.filter(func(part): return not part.is_empty())


static func _part(model: ParkModel, id: String, material: String, role: String, zone: String) -> MeshPart:
	var layer := int(id.get_slice("_L", 1).get_slice("_", 0))
	return _MeshPart.make(material, layer, {
		"surface_id": id, "model_hash": model.model_hash,
		"zone": zone, "face_role": role, "layer": layer,
	})


static func _world(p: Vector3) -> Vector3:
	return _WorldSpace.logical_to_world(p.x, p.y, p.z)


static func _slope_point(surf, z: float, u: float) -> Vector3:
	return _world(Vector3(surf.x_at_theta(z, u * PI * 0.5), z, surf.height_at_theta(z, u * PI * 0.5)))


## Every compiled Z sample is a tessellation boundary, preserving loft changes.
static func _slope_parts(model: ParkModel, surf, is_ramp: bool) -> Array:
	var family := "ramp" if is_ramp else "pipe"
	var zone := ("ramp_" if is_ramp else "pipe_") + ("left" if surf.outward_sign() < 0.0 else "right")
	var ride := _part(model, surf.id, family + "_ride", "ride", zone)
	var back := _part(model, surf.id, family + "_wall", "back", zone)
	var caps := _part(model, surf.id, family + "_wall", "endcap", zone)
	var steps := 1 if is_ramp else ARC_STEPS
	var zs: Array[float] = [surf.z_min, surf.z_max]
	for sample in surf.samples:
		var z := float(sample.z)
		if not zs.has(z):
			zs.append(z)
	zs.sort()
	for zi in range(zs.size() - 1):
		var z0 := zs[zi]
		var z1 := zs[zi + 1]
		for i in range(steps):
			var u0 := float(i) / steps
			var u1 := float(i + 1) / steps
			var a := _slope_point(surf, z0, u0)
			var b := _slope_point(surf, z0, u1)
			var c := _slope_point(surf, z1, u1)
			var d := _slope_point(surf, z1, u0)
			if surf.outward_sign() < 0.0:
				ride.append_tri(a, c, b)
				ride.append_tri(a, d, c)
			else:
				ride.append_tri(a, b, c)
				ride.append_tri(a, c, d)
		var s0: Dictionary = surf.sample_at_z(z0)
		var s1: Dictionary = surf.sample_at_z(z1)
		var a := _slope_point(surf, z0, 1.0)
		var b := _slope_point(surf, z1, 1.0)
		var c := _world(Vector3(surf.coping_x_at(z1), z1, s1.base_height))
		var d := _world(Vector3(surf.coping_x_at(z0), z0, s0.base_height))
		if surf.outward_sign() < 0.0:
			back.append_tri(a, b, c)
			back.append_tri(a, c, d)
		else:
			back.append_tri(a, c, b)
			back.append_tri(a, d, c)
	for z in [surf.z_min, surf.z_max]:
		var sample: Dictionary = surf.sample_at_z(z)
		var foot := _world(Vector3(surf.coping_x_at(z), z, sample.base_height))
		for i in range(steps):
			var a := _slope_point(surf, z, float(i) / steps)
			var b := _slope_point(surf, z, float(i + 1) / steps)
			if (z == surf.z_min) == (surf.outward_sign() < 0.0):
				caps.append_tri(foot, a, b)
			else:
				caps.append_tri(foot, b, a)
	return [ride, back, caps]


static func _wall_part(model: ParkModel, wall: WallSurface) -> MeshPart:
	var part := _part(model, wall.id, "pipe_wall", "wall", "wall")
	var zs: Array[float] = [wall.z_min, wall.z_max]
	for sample in wall.samples:
		if not zs.has(float(sample.z)):
			zs.append(float(sample.z))
	zs.sort()
	var source: PipeSurface = model.pipes[wall.source_pipe_id]
	for i in range(zs.size() - 1):
		var a := _world(wall.position_at(zs[i], 0.0))
		var b := _world(wall.position_at(zs[i], 1.0))
		var c := _world(wall.position_at(zs[i + 1], 1.0))
		var d := _world(wall.position_at(zs[i + 1], 0.0))
		if source.outward_sign() > 0.0:
			part.append_tri(a, b, c)
			part.append_tri(a, c, d)
		else:
			part.append_tri(a, c, b)
			part.append_tri(a, d, c)
	return part


static func _patch_parts(model: ParkModel, patch: SupportPatch) -> Array:
	var deck := patch.kind == SimKinds.SurfaceKind.DECK
	var lava := patch.kind == SimKinds.SurfaceKind.LAVA
	var material := "deck" if deck else ("lava" if lava else "floor")
	var top := _part(model, patch.id, material, "lava" if lava else "top", "deck" if deck else ("lava" if lava else "flat"))
	top.meta["height"] = patch.height
	top.meta["base_height"] = patch.base_height
	var query := SurfaceQuery.new(model)
	# Grid-aligned slabs preserve holes and concavity and keep triangles local.
	# The support query selects the compiled owner when lava overlaps a floor.
	var r0 := maxi(0, int(floor(patch.z_min / model.cell_h)))
	var r1 := mini(model.grid_h, int(ceil(patch.z_max / model.cell_h)))
	var c0 := maxi(0, int(floor(patch.x_min / model.cell_w)))
	var c1 := mini(model.grid_w, int(ceil(patch.x_max / model.cell_w)))
	for r in range(r0, r1):
		var z0 := r * model.cell_h
		var z1 := (r + 1) * model.cell_h
		var c := c0
		while c < c1:
			if not _patch_cell_visible(query, patch, (c + 0.5) * model.cell_w, (z0 + z1) * 0.5):
				c += 1
				continue
			var end := c + 1
			while end < c1 and _patch_cell_visible(query, patch, (end + 0.5) * model.cell_w, (z0 + z1) * 0.5):
				end += 1
			var a := _world(Vector3(c * model.cell_w, z0, patch.height))
			var b := _world(Vector3(end * model.cell_w, z0, patch.height))
			var e := _world(Vector3(end * model.cell_w, z1, patch.height))
			var d := _world(Vector3(c * model.cell_w, z1, patch.height))
			top.append_tri(a, b, e)
			top.append_tri(a, e, d)
			c = end
	var parts: Array = [top]
	if deck:
		var walls := _part(model, patch.id, "deck_wall", "wall", "deck")
		# The outline is the actual exterior; no internal rectangle seams appear.
		for loop in _patch_loops(patch):
			for i in range(loop.size()):
				var a: Vector2 = loop[i]
				var b: Vector2 = loop[(i + 1) % loop.size()]
				if query._deck_edge_is_coping_aligned(a, b):
					continue
				var mid := (a + b) * 0.5
				var normal := Vector2(-(b - a).y, (b - a).x).normalized()
				if patch.contains_xz(mid.x + normal.x * 0.5, mid.y + normal.y * 0.5):
					normal = -normal
				var wa := _world(Vector3(a.x, a.y, patch.height))
				var wb := _world(Vector3(b.x, b.y, patch.height))
				var wc := _world(Vector3(b.x, b.y, patch.base_height))
				var wd := _world(Vector3(a.x, a.y, patch.base_height))
				var desired := Vector3(-normal.x, 0.0, normal.y)
				if (wb - wa).cross(wc - wa).dot(desired) > 0.0:
					walls.append_tri(wa, wb, wc)
					walls.append_tri(wa, wc, wd)
				else:
					walls.append_tri(wa, wc, wb)
					walls.append_tri(wa, wd, wc)
		parts.append(walls)
	return parts


static func _patch_loops(patch: SupportPatch) -> Array:
	var loops: Array = [patch.poly]
	loops.append_array(patch.holes)
	return loops


static func _patch_cell_visible(query: SurfaceQuery, patch: SupportPatch, x: float, z: float) -> bool:
	if not patch.contains_xz(x, z):
		return false
	var owner := query.top_support(x, z, patch.height)
	return str(owner.get("surface_id", "")) == patch.id


static func _rail_parts(model: ParkModel, rail: RailSurface) -> Array:
	var bar := _part(model, rail.id, "rail", "rail", "rail")
	var bottom := rail.bottom_height()
	var thickness := rail.top_height - bottom
	var half_z := maxf(thickness * 0.5, 2.0)
	var post_half := maxf(thickness * 0.45, 1.5)
	_RailMeshBuilder._append_box(bar, rail.x_min, rail.x_max, rail.z - half_z, rail.z + half_z, bottom, rail.top_height)
	var parts: Array = [bar]
	if bottom <= rail.base_height + 0.5:
		return parts
	for x in [rail.x_min + post_half, rail.x_max - post_half]:
		var post := _part(model, rail.id, "rail_post", "rail_post", "rail")
		_RailMeshBuilder._append_box(post, x - post_half, x + post_half, rail.z - post_half, rail.z + post_half, rail.base_height, bottom)
		parts.append(post)
	return parts
