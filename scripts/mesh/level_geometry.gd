class_name LevelGeometry
extends RefCounted
## Single CPU-side face soup for visuals, StaticBody collision, and debug lattices.

const _FloorMeshBuilder := preload("res://scripts/mesh/floor_mesh_builder.gd")
const _PipeMeshBuilder := preload("res://scripts/mesh/pipe_mesh_builder.gd")
const _DeckMeshBuilder := preload("res://scripts/mesh/deck_mesh_builder.gd")


static func build_parts(spec: LevelSpec, pipes: Array) -> Array:
	var parts: Array = []
	if spec == null:
		return parts
	parts.append_array(_FloorMeshBuilder.build_parts(spec))
	parts.append_array(_PipeMeshBuilder.build_parts_from_pipes(pipes))
	parts.append_array(_DeckMeshBuilder.build_parts(spec))
	return parts


static func merged_aabb(parts: Array) -> AABB:
	var box := AABB()
	var any := false
	for part in parts:
		if part == null or not part.has_method("is_empty") or part.is_empty():
			continue
		var ab: AABB = part.aabb()
		if not any:
			box = ab
			any = true
		else:
			box = box.merge(ab)
	return box
