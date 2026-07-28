class_name FloorMeshBuilder
extends RefCounted
## Merged horizontal floor/lava quads from LevelSpec story masks.

const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")


static func build_parts(spec: LevelSpec) -> Array:
	## Returns Array of MeshPart (CPU faces + meta).
	var out: Array = []
	if spec == null or spec.grid_w <= 0 or spec.grid_h <= 0:
		return out
	var W := spec.grid_w
	var H := spec.grid_h
	var cw := spec.cell_w
	var ch := spec.cell_h
	for story in spec.story_floor_masks:
		var height := float(story.get("height", 0.0))
		var layer := int(story.get("layer", 0))
		var mask: PackedByteArray = story.get("mask", PackedByteArray())
		if mask.size() < W * H:
			continue
		var floor_part = _MeshPart.make(
			"floor",
			layer,
			{"zone": "flat", "layer": layer, "face_role": "top", "height": height},
		)
		var lava_part = _MeshPart.make(
			"lava",
			layer,
			{"zone": "lava", "layer": layer, "face_role": "lava", "height": height},
		)
		for r in range(H):
			var z0 := float(H - 1 - r) * ch
			var z1 := float(H - r) * ch
			var c := 0
			while c < W:
				var kind: int = int(mask[r * W + c])
				if kind == 0:
					c += 1
					continue
				var c1 := c + 1
				while c1 < W and int(mask[r * W + c1]) == kind:
					c1 += 1
				var x0 := float(c) * cw
				var x1 := float(c1) * cw
				if kind == 2:
					_quad(lava_part, x0, z0, x1, z1, height)
				else:
					_quad(floor_part, x0, z0, x1, z1, height)
				c = c1
		if not floor_part.is_empty():
			out.append(floor_part)
		if not lava_part.is_empty():
			out.append(lava_part)
	return out


static func build(spec: LevelSpec) -> Array:
	## Legacy wrapper: Array of {mesh, material_key, layer, meta, part}.
	return _parts_to_legacy(build_parts(spec))


static func _parts_to_legacy(parts: Array) -> Array:
	var out: Array = []
	for part in parts:
		var mesh: ArrayMesh = part.to_array_mesh()
		if mesh == null:
			continue
		out.append({
			"mesh": mesh,
			"material_key": part.material_key,
			"layer": part.layer,
			"meta": part.meta,
			"part": part,
		})
	return out


static func _quad(part, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var a: Vector3 = _WorldSpace.logical_to_world(x0, z0, y)
	var b: Vector3 = _WorldSpace.logical_to_world(x1, z0, y)
	var c: Vector3 = _WorldSpace.logical_to_world(x1, z1, y)
	var d: Vector3 = _WorldSpace.logical_to_world(x0, z1, y)
	# Upward normals after WorldSpace X-mirror (opposite of MeshPart.append_quad default).
	part.append_tri(a, b, c)
	part.append_tri(a, c, d)
