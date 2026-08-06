class_name RailMeshBuilder
extends RefCounted
## Thin along-X grind bars from LevelSpec.rails.


const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")


static func build_parts(spec: LevelSpec) -> Array:
	var out: Array = []
	if spec == null:
		return out
	var thickness := maxf(SimTolerances.RAIL_THICKNESS, 1.0)
	var half_z := maxf(thickness * 0.5, 2.0)
	for rail in spec.rails:
		var x0 := float(rail.get("x_min", 0.0))
		var x1 := float(rail.get("x_max", 0.0))
		var z := float(rail.get("z", 0.0))
		var base := float(rail.get("base_height", 0.0))
		var top := base + SimTolerances.RAIL_OFFSET
		var bottom := top - thickness
		var layer := int(rail.get("layer", 0))
		var part = _MeshPart.make(
			"rail",
			layer,
			{
				"zone": "rail",
				"layer": layer,
				"face_role": "rail",
				"height": top,
				"base_height": bottom,
			},
		)
		# Box: X along run, Y = logical Z (depth), height = logical height.
		var a := _WorldSpace.logical_to_world(x0, z - half_z, bottom)
		var b := _WorldSpace.logical_to_world(x1, z - half_z, bottom)
		var c := _WorldSpace.logical_to_world(x1, z + half_z, bottom)
		var d := _WorldSpace.logical_to_world(x0, z + half_z, bottom)
		var e := _WorldSpace.logical_to_world(x0, z - half_z, top)
		var f := _WorldSpace.logical_to_world(x1, z - half_z, top)
		var g := _WorldSpace.logical_to_world(x1, z + half_z, top)
		var h := _WorldSpace.logical_to_world(x0, z + half_z, top)
		part.append_quad(a, b, c, d) ## bottom
		part.append_quad(e, h, g, f) ## top
		part.append_quad(a, e, f, b) ## -Z face
		part.append_quad(d, c, g, h) ## +Z face
		part.append_quad(a, d, h, e) ## -X end
		part.append_quad(b, f, g, c) ## +X end
		if not part.is_empty():
			out.append(part)
	return out
