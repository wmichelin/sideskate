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
	# Coping-aligned deck wall faces are omitted from the mesh (pipe back owns that
	# plane). Keep remaining deck walls as colliders — do not solid-fill the volume
	# (that recreated a catch wall on the open coping face).
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
		var top := _deck_top_shape(part)
		if top == null:
			return
		cs.shape = top
	elif face_role == "back":
		# Thin plane trimeshes tunnel; solid slab thickened outward from coping.
		var back := _pipe_back_solid_shape(part)
		if back == null:
			return
		cs.shape = back
	elif face_role == "top" or face_role == "lava":
		var ab: AABB = part.aabb()
		if ab.size.length() < 0.0001:
			return
		var box := BoxShape3D.new()
		var sz := ab.size
		sz.y = maxf(sz.y, 0.05)
		box.size = sz
		cs.position = ab.position + sz * 0.5
		cs.shape = box
	else:
		var shape: ConcavePolygonShape3D = part.to_concave_shape()
		if shape == null:
			return
		cs.shape = shape
	body.add_child(cs)
	_body_root.add_child(body)
	_meta_by_owner[body.get_instance_id()] = part.meta.duplicate(true)
	part_count += 1


## Outer pipe wall as a convex slab. Thickens through any outward `#` deck that
## anchors on this coping so the deck back is a solid wall extension — not a
## hollow you can fly into from the lip.
func _pipe_back_solid_shape(part) -> Shape3D:
	var side := int(part.meta.get("side", -1))
	var radius := float(part.meta.get("radius", 0.0))
	var base_h := float(part.meta.get("base_height", 0.0))
	var z0 := float(part.meta.get("z_min", 0.0))
	var z1 := float(part.meta.get("z_max", 0.0))
	var cope := float(part.meta.get("top_coping", NAN))
	if is_nan(cope):
		var lip := float(part.meta.get("lip_x", NAN))
		if side < 0 or is_nan(lip) or radius <= 0.001:
			return null
		cope = lip - radius if side == 0 else lip + radius
	if side < 0 or radius <= 0.001 or absf(z1 - z0) < 0.01:
		return null
	var top_h := base_h + radius
	# Outward from bowl: LEFT → −X logical, RIGHT → +X.
	var outward := -1.0 if side == 0 else 1.0
	var thick_logic := 8.0
	if _level != null and _level.spec != null:
		for deck in _level.spec.decks:
			if typeof(deck) != TYPE_DICTIONARY:
				continue
			var deck_h := float(deck.get("height", top_h))
			var matched := false
			for anchor in deck.get("anchors", []):
				if typeof(anchor) != TYPE_DICTIONARY:
					continue
				if int(anchor.get("side", -2)) != side:
					continue
				if absf(float(anchor.get("coping_x", NAN)) - cope) > 0.75:
					continue
				matched = true
				break
			if not matched:
				continue
			var poly = deck.get("poly", PackedVector2Array())
			if typeof(poly) != TYPE_PACKED_VECTOR2_ARRAY:
				continue
			for p in poly:
				var out_d: float = (p.x - cope) * outward
				if out_d > 0.5:
					thick_logic = maxf(thick_logic, out_d)
			# Raise the wall through the deck top when the pad sits on this coping.
			top_h = maxf(top_h, deck_h)
	var x_in := cope
	var x_out := cope + outward * thick_logic
	var pts := PackedVector3Array()
	for x in [x_in, x_out]:
		for z in [z0, z1]:
			for h in [base_h, top_h]:
				pts.append(_WorldSpace.logical_to_world(x, z, h))
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	return convex


## Thin deck top slab from triangulated faces (not a convex hull of the outline —
## concave `#` notches must not solid-fill over the pipe).
func _deck_top_shape(part) -> Shape3D:
	var shape: ConcavePolygonShape3D = part.to_concave_shape()
	if shape == null:
		return null
	return shape


func _clear() -> void:
	if _body_root == null:
		return
	for c in _body_root.get_children():
		c.queue_free()
