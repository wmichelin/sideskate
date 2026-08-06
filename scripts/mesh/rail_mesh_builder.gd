class_name RailMeshBuilder
extends RefCounted
## Along-X grind bars + vertical posts from LevelSpec.rails.


const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")


static func build_parts(spec: LevelSpec) -> Array:
	var out: Array = []
	if spec == null:
		return out
	var thickness := maxf(SimTolerances.RAIL_THICKNESS, 1.0)
	var half_z := maxf(thickness * 0.5, 2.0)
	var post_half := maxf(thickness * 0.45, 1.5)
	for rail in spec.rails:
		var x0 := float(rail.get("x_min", 0.0))
		var x1 := float(rail.get("x_max", 0.0))
		var z := float(rail.get("z", 0.0))
		var base := float(rail.get("base_height", 0.0))
		var top := base + SimTolerances.RAIL_OFFSET
		var bottom := top - thickness
		var layer := int(rail.get("layer", 0))
		var bar = _MeshPart.make(
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
		_append_box(bar, x0, x1, z - half_z, z + half_z, bottom, top)
		if not bar.is_empty():
			out.append(bar)
		# End posts from floor up to the underside of the bar.
		if bottom > base + 0.5:
			for px in [x0 + post_half, x1 - post_half]:
				var post = _MeshPart.make(
					"rail_post",
					layer,
					{
						"zone": "rail",
						"layer": layer,
						"face_role": "rail_post",
						"height": bottom,
						"base_height": base,
					},
				)
				_append_box(
					post,
					px - post_half,
					px + post_half,
					z - post_half,
					z + post_half,
					base,
					bottom,
				)
				if not post.is_empty():
					out.append(post)
	return out


static func _append_box(
	part,
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	h0: float,
	h1: float,
) -> void:
	var a := _WorldSpace.logical_to_world(x0, z0, h0)
	var b := _WorldSpace.logical_to_world(x1, z0, h0)
	var c := _WorldSpace.logical_to_world(x1, z1, h0)
	var d := _WorldSpace.logical_to_world(x0, z1, h0)
	var e := _WorldSpace.logical_to_world(x0, z0, h1)
	var f := _WorldSpace.logical_to_world(x1, z0, h1)
	var g := _WorldSpace.logical_to_world(x1, z1, h1)
	var h := _WorldSpace.logical_to_world(x0, z1, h1)
	part.append_quad(a, b, c, d) ## bottom
	part.append_quad(e, h, g, f) ## top
	part.append_quad(a, e, f, b) ## -Z
	part.append_quad(d, c, g, h) ## +Z
	part.append_quad(a, d, h, e) ## -X
	part.append_quad(b, f, g, c) ## +X
