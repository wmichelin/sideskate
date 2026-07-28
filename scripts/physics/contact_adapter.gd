class_name ContactAdapter
extends RefCounted
## Convert Godot collision contacts into dictionaries expected by skate helpers.

const _WorldSpace := preload("res://scripts/world_space.gd")


static func hit_from_collision(col: KinematicCollision3D, index: int = 0) -> Dictionary:
	if col == null:
		return {}
	var collider := col.get_collider(index)
	var meta: Dictionary = meta_from_collider(collider)
	var n := col.get_normal(index)
	var point := col.get_position(index)
	var logical: Dictionary = _WorldSpace.world_to_logical(point)
	var world_n_to_logical := Vector3(-n.x, n.y, n.z)
	var out := {
		"active": true,
		"zone": str(meta.get("zone", "flat")),
		"layer": int(meta.get("layer", 0)),
		"face_role": str(meta.get("face_role", "top")),
		"height": float(logical.get("height", 0.0)),
		"x": float(logical.get("x", 0.0)),
		"z": float(logical.get("z", 0.0)),
		"normal": world_n_to_logical,
		"solid": str(meta.get("face_role", "")) != "lava",
		"hit": meta.duplicate(true),
	}
	# Pipe identity fields when present on the part meta.
	for key in ["side", "lip_x", "radius", "base_height", "z_min", "z_max", "top_coping"]:
		if meta.has(key):
			out[key] = meta[key]
			out["hit"][key] = meta[key]
	return out


static func meta_from_collider(collider: Object) -> Dictionary:
	if collider == null:
		return {}
	if collider.has_meta("mesh_part_meta"):
		return _meta_dict(collider.get_meta("mesh_part_meta"))
	if collider is Node:
		var n := collider as Node
		if n.has_meta("mesh_part_meta"):
			return _meta_dict(n.get_meta("mesh_part_meta"))
		var p := n.get_parent()
		if p != null and p.has_meta("mesh_part_meta"):
			return _meta_dict(p.get_meta("mesh_part_meta"))
	return {}


static func _meta_dict(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return (raw as Dictionary).duplicate(true)


static func collect_slide_hits(body: CharacterBody3D) -> Array:
	var out: Array = []
	if body == null:
		return out
	for i in range(body.get_slide_collision_count()):
		var col := body.get_slide_collision(i)
		if col == null:
			continue
		out.append(hit_from_collision(col, 0))
	return out
