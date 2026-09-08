class_name LevelCollision3D
extends Node3D
## StaticBody3D colliders from shared MeshPart geometry.
## Parts that share face_role + collision layer use one body. Their triangles
## remain identical to the shared rendered geometry, including holes.


const LevelGeometryScript := preload("res://scripts/mesh/level_geometry.gd")
const CollisionLayersScript := preload("res://scripts/physics/collision_layers.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")

@export var level_path: NodePath = NodePath("../../RampLevel")
## Godot colliders are presentation-only (player mask is 0). Enabled in main for
## fall-box contact; tests may toggle. Skip on huge parks if cost bites.
@export var build_bodies: bool = false

var _level: RampLevel
var _body_root: Node3D
var part_count: int = 0
var last_aabb: AABB = AABB()
var source_model: ParkModel
## Collider owner_id → MeshPart.meta for contact adapters.
var _meta_by_owner: Dictionary = {}


func _ready() -> void:
	add_to_group("level_collision_3d")
	_body_root = Node3D.new()
	_body_root.name = "Bodies"
	add_child(_body_root)
	_level = get_node_or_null(level_path) as RampLevel
	if _level != null:
		if not _level.rebuilt.is_connected(_on_rebuilt):
			_level.rebuilt.connect(_on_rebuilt)
		if _level.spec != null:
			rebuild()


func _on_rebuilt() -> void:
	rebuild()


func rebuild() -> void:
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel
	if _level == null or _level.spec == null:
		return
	_clear()
	part_count = 0
	last_aabb = AABB()
	_meta_by_owner.clear()
	source_model = _level.model
	set_meta("sim_model_hash", source_model.model_hash)
	var parts: Array = _level.geometry_parts
	last_aabb = LevelGeometryScript.merged_aabb(parts)
	if not build_bodies:
		return
	# All collision surfaces use the exact rendered faces. Bounding boxes filled
	# floor/lava holes and independent back slabs extended beyond compiled solids.
	var trimesh_batches: Dictionary = {} ## batch_key → {faces, meta, layer_bit}
	for part in parts:
		if part == null or not part.has_method("is_empty") or part.is_empty():
			continue
		var face_role := str(part.meta.get("face_role", "top"))
		var zone := str(part.meta.get("zone", ""))
		_accumulate_trimesh(trimesh_batches, part, face_role, zone)
	for key in trimesh_batches.keys():
		var batch: Dictionary = trimesh_batches[key]
		_add_merged_trimesh(batch)


func meta_for_collider(collider: Object) -> Dictionary:
	if collider == null:
		return {}
	var id := collider.get_instance_id()
	if _meta_by_owner.has(id):
		return (_meta_by_owner[id] as Dictionary).duplicate(true)
	if collider is Node and (collider as Node).has_meta("mesh_part_meta"):
		var m = (collider as Node).get_meta("mesh_part_meta")
		if typeof(m) == TYPE_DICTIONARY:
			return (m as Dictionary).duplicate(true)
	return {}


func _accumulate_trimesh(
	batches: Dictionary, part, face_role: String, zone: String
) -> void:
	var layer_bit := CollisionLayersScript.bit(
		CollisionLayersScript.ride_layers_for_face(face_role)
	)
	var key := "%s|%d" % [face_role, layer_bit]
	if not batches.has(key):
		batches[key] = {
			"faces": PackedVector3Array(),
			"face_role": face_role,
			"zone": zone,
			"layer_bit": layer_bit,
			"material_key": str(part.material_key),
			"layer": int(part.meta.get("layer", part.layer)),
			"surface_ids": [],
		}
	var faces: PackedVector3Array = batches[key].faces
	faces.append_array(part.faces)
	batches[key].faces = faces
	var ids: Array = batches[key].surface_ids
	var owner := str(part.meta.get("surface_id", ""))
	if not ids.has(owner):
		ids.append(owner)


func _add_merged_trimesh(batch: Dictionary) -> void:
	var faces: PackedVector3Array = batch.get("faces", PackedVector3Array())
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var meta: Dictionary = {
		"face_role": str(batch.get("face_role", "")),
		"zone": str(batch.get("zone", "")),
		"layer": int(batch.get("layer", 0)),
		"merged": true,
		"surface_ids": batch.get("surface_ids", []).duplicate(),
		"model_hash": source_model.model_hash,
	}
	_add_body(
		"%s_merged_%s" % [str(batch.get("material_key", "mesh")), str(batch.get("face_role", ""))],
		int(batch.get("layer_bit", 0)),
		meta,
		shape,
		Vector3.ZERO,
	)


func _add_body(
	body_name: String,
	layer_bit: int,
	meta: Dictionary,
	shape: Shape3D,
	shape_pos: Vector3,
) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = layer_bit
	body.collision_mask = 0
	body.set_meta("mesh_part_meta", meta.duplicate(true))
	body.set_meta("face_role", str(meta.get("face_role", "")))
	body.set_meta("zone", str(meta.get("zone", "")))
	body.set_meta("layer", int(meta.get("layer", 0)))
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = shape
	cs.position = shape_pos
	body.add_child(cs)
	_body_root.add_child(body)
	_meta_by_owner[body.get_instance_id()] = meta.duplicate(true)
	part_count += 1


func _clear() -> void:
	if _body_root == null:
		return
	for c in _body_root.get_children():
		c.queue_free()
