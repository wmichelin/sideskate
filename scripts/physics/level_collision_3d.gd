class_name LevelCollision3D
extends Node3D
## StaticBody3D colliders from shared MeshPart geometry.
## Trimesh parts that share face_role + layer bit are merged into one body so
## pipe farms (spine_demo) do not spawn 200+ PhysicsServer objects.


const LevelGeometryScript := preload("res://scripts/mesh/level_geometry.gd")
const CollisionLayersScript := preload("res://scripts/physics/collision_layers.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")

@export var level_path: NodePath = NodePath("../../RampLevel")
## Godot colliders are presentation-only (player mask is 0). Skip on large parks
## unless a test / tool explicitly enables them.
@export var build_bodies: bool = false

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
	last_aabb = LevelGeometryScript.merged_aabb(parts)
	if not build_bodies:
		return
	# Merge concave trimeshes by (face_role, collision layer). Keep unique
	# convex slabs (pipe backs) and AABB floors as individual bodies.
	var trimesh_batches: Dictionary = {} ## batch_key → {faces, meta, layer_bit}
	for part in parts:
		if part == null or not part.has_method("is_empty") or part.is_empty():
			continue
		var face_role := str(part.meta.get("face_role", "top"))
		var zone := str(part.meta.get("zone", ""))
		if zone == "deck" and face_role == "top":
			_accumulate_trimesh(trimesh_batches, part, face_role, zone)
			continue
		if face_role == "back":
			_add_pipe_back(part)
			continue
		if face_role == "top" or face_role == "lava":
			_add_aabb_top(part, face_role, zone)
			continue
		# ride / endcap / wall / deck_wall → merged concave
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
		}
	var faces: PackedVector3Array = batches[key].faces
	faces.append_array(part.faces)
	batches[key].faces = faces


func _add_merged_trimesh(batch: Dictionary) -> void:
	var faces: PackedVector3Array = batch.get("faces", PackedVector3Array())
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var meta: Dictionary = {
		"face_role": str(batch.get("face_role", "")),
		"zone": str(batch.get("zone", "")),
		"layer": int(batch.get("layer", 0)),
		"merged": true,
	}
	_add_body(
		"%s_merged_%s" % [str(batch.get("material_key", "mesh")), str(batch.get("face_role", ""))],
		int(batch.get("layer_bit", 0)),
		meta,
		shape,
		Vector3.ZERO,
	)


func _add_aabb_top(part, face_role: String, zone: String) -> void:
	var ab: AABB = part.aabb()
	if ab.size.length() < 0.0001:
		return
	var box := BoxShape3D.new()
	var sz := ab.size
	sz.y = maxf(sz.y, 0.05)
	box.size = sz
	var meta: Dictionary = part.meta.duplicate(true)
	meta["face_role"] = face_role
	meta["zone"] = zone
	_add_body(
		"%s_L%s_%s" % [part.material_key, part.layer, face_role],
		CollisionLayersScript.bit(CollisionLayersScript.ride_layers_for_face(face_role)),
		meta,
		box,
		ab.position + sz * 0.5,
	)


func _add_pipe_back(part) -> void:
	var back := _pipe_back_solid_shape(part)
	if back == null:
		return
	var meta: Dictionary = part.meta.duplicate(true)
	meta["face_role"] = "back"
	_add_body(
		"%s_L%s_back" % [part.material_key, part.layer],
		CollisionLayersScript.bit(CollisionLayersScript.WORLD_WALL),
		meta,
		back,
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


func _clear() -> void:
	if _body_root == null:
		return
	for c in _body_root.get_children():
		c.queue_free()
