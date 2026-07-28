class_name LevelCollision3D
extends Node3D
## StaticBody3D colliders from shared MeshPart faces (same source as LevelVisual3D).

const LevelGeometryScript := preload("res://scripts/mesh/level_geometry.gd")
const CollisionLayersScript := preload("res://scripts/physics/collision_layers.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")

@export var level_path: NodePath = NodePath("../../RampLevel")

var _level: RampLevel
var _body_root: Node3D
var part_count: int = 0
var last_aabb: AABB = AABB()
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
	var parts: Array = LevelGeometryScript.build_parts(_level.spec, _level.pipes)
	for part in parts:
		if part == null or not part.has_method("is_empty") or part.is_empty():
			continue
		_add_part(part)
	last_aabb = LevelGeometryScript.merged_aabb(parts)


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


func _add_part(part) -> void:
	var face_role := str(part.meta.get("face_role", "top"))
	var zone := str(part.meta.get("zone", ""))
	# Deck walls are covered by the solid deck prism from the top part.
	if zone == "deck" and face_role == "wall":
		return
	var body := StaticBody3D.new()
	body.name = "%s_L%s_%s" % [part.material_key, part.layer, face_role]
	body.collision_layer = CollisionLayersScript.bit(
		CollisionLayersScript.ride_layers_for_face(face_role)
	)
	body.collision_mask = 0
	body.set_meta("mesh_part_meta", part.meta.duplicate(true))
	body.set_meta("face_role", face_role)
	body.set_meta("zone", zone)
	body.set_meta("layer", int(part.meta.get("layer", part.layer)))
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	if zone == "deck" and face_role == "top":
		var solid := _deck_solid_shape(part)
		if solid == null:
			return
		cs.shape = solid
	elif face_role == "top" or face_role == "lava":
		var ab: AABB = part.aabb()
		if ab.size.length() < 0.0001:
			return
		var box := BoxShape3D.new()
		var sz := ab.size
		sz.y = maxf(sz.y, 0.05)
		box.size = sz
		cs.shape = box
		cs.position = ab.position + sz * 0.5
	else:
		var shape: ConcavePolygonShape3D = part.to_concave_shape()
		if shape == null:
			return
		cs.shape = shape
	body.add_child(cs)
	_body_root.add_child(body)
	_meta_by_owner[body.get_instance_id()] = part.meta.duplicate(true)
	part_count += 1


## Solid convex prism for deck footprint (base→top). Hollow wall trimeshes let
## CharacterBody tunnel inside; this volume stays solid.
func _deck_solid_shape(part) -> Shape3D:
	var top_h := float(part.meta.get("height", 0.0))
	var base_h := float(part.meta.get("base_height", 0.0))
	if top_h < base_h:
		var tmp := top_h
		top_h = base_h
		base_h = tmp
	var poly = part.meta.get("poly", PackedVector2Array())
	if typeof(poly) == TYPE_PACKED_VECTOR2_ARRAY and poly.size() >= 3:
		var pts := PackedVector3Array()
		for p in poly:
			pts.append(_WorldSpace.logical_to_world(p.x, p.y, top_h))
			pts.append(_WorldSpace.logical_to_world(p.x, p.y, base_h))
		var convex := ConvexPolygonShape3D.new()
		convex.points = pts
		return convex
	# Fallback: AABB prism as convex.
	var ab: AABB = part.aabb()
	if ab.size.length() < 0.0001:
		return null
	var y0 := _WorldSpace.logic_to_meters(base_h)
	var y1 := _WorldSpace.logic_to_meters(top_h)
	var pts2 := PackedVector3Array()
	var x0 := ab.position.x
	var x1 := ab.position.x + ab.size.x
	var z0 := ab.position.z
	var z1 := ab.position.z + ab.size.z
	for xz in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		pts2.append(Vector3(xz.x, minf(y0, y1), xz.y))
		pts2.append(Vector3(xz.x, maxf(y0, y1), xz.y))
	var convex2 := ConvexPolygonShape3D.new()
	convex2.points = pts2
	return convex2


func _clear() -> void:
	if _body_root == null:
		return
	for c in _body_root.get_children():
		c.queue_free()
