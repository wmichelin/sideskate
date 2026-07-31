class_name LevelVisual3D
extends Node3D
## Builds opaque ArrayMeshes from shared MeshPart geometry on `rebuilt`.
## One MeshInstance per MeshPart — frustum cull drops off-screen spine bays.
## Do not merge park-wide: wide AABB forces drawing the whole farm.


const LevelGeometryScript := preload("res://scripts/mesh/level_geometry.gd")

@export var level_path: NodePath = NodePath("../../RampLevel")

var _level: RampLevel
var _mesh_root: Node3D
var mesh_count: int = 0
var last_aabb: AABB = AABB()
var _materials: Dictionary = {} ## material_key → StandardMaterial3D


func _ready() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "Meshes"
	add_child(_mesh_root)
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
	_clear_meshes()
	mesh_count = 0
	last_aabb = AABB()
	var parts: Array = LevelGeometryScript.build_parts(_level.spec, _level.pipes)
	for part in parts:
		if part == null or not part.has_method("is_empty") or part.is_empty():
			continue
		var mesh: ArrayMesh = part.to_array_mesh()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "%s_L%s" % [str(part.material_key), str(part.layer)]
		mi.mesh = mesh
		mi.material_override = _material_for(str(part.material_key))
		# Shadows over a 100m park are pure fill cost; analytical play needs none.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_root.add_child(mi)
		mesh_count += 1
		var ab: AABB = mesh.get_aabb()
		if last_aabb.size == Vector3.ZERO:
			last_aabb = ab
		else:
			last_aabb = last_aabb.merge(ab)


func _clear_meshes() -> void:
	if _mesh_root == null:
		return
	for child in _mesh_root.get_children():
		child.queue_free()


func _material_for(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Double-sided: trough cameras often see deck undersides / thin ride ribbons.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	match key:
		"lava":
			mat.albedo_color = Color(0.72, 0.12, 0.05, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.6, 0.08, 0.02)
			mat.emission_energy_multiplier = 1.2
		"deck":
			mat.albedo_color = Color(0.55, 0.48, 0.32, 1.0)
		"deck_wall":
			mat.albedo_color = Color(0.38, 0.32, 0.22, 1.0)
		"pipe_ride":
			mat.albedo_color = Color(0.42, 0.38, 0.48, 1.0)
		"pipe_wall":
			mat.albedo_color = Color(0.28, 0.24, 0.32, 1.0)
		"ramp_ride":
			mat.albedo_color = Color(0.48, 0.40, 0.36, 1.0)
		"ramp_wall":
			mat.albedo_color = Color(0.32, 0.26, 0.22, 1.0)
		_:
			mat.albedo_color = Color(0.32, 0.38, 0.42, 1.0)
	_materials[key] = mat
	return mat
