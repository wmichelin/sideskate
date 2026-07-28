class_name FloorMeshBuilder
extends RefCounted
## Merged horizontal floor/lava quads from LevelSpec story masks.


static func build(spec: LevelSpec) -> Array:
	## Returns Array of {mesh: ArrayMesh, material_key: String, layer: int}.
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
		var floor_st := SurfaceTool.new()
		floor_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lava_st := SurfaceTool.new()
		lava_st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_floor := false
		var has_lava := false
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
					_quad(lava_st, x0, z0, x1, z1, height)
					has_lava = true
				else:
					_quad(floor_st, x0, z0, x1, z1, height)
					has_floor = true
				c = c1
		if has_floor:
			floor_st.generate_normals()
			out.append({"mesh": floor_st.commit(), "material_key": "floor", "layer": layer})
		if has_lava:
			lava_st.generate_normals()
			out.append({"mesh": lava_st.commit(), "material_key": "lava", "layer": layer})
	return out


static func _quad(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, y: float) -> void:
	var a := WorldSpace.logical_to_world(x0, z0, y)
	var b := WorldSpace.logical_to_world(x1, z0, y)
	var c := WorldSpace.logical_to_world(x1, z1, y)
	var d := WorldSpace.logical_to_world(x0, z1, y)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
