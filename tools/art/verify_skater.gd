extends SceneTree
## Check the exported character through Godot's real glTF import and animation.

const MODEL := "res://assets/characters/ssk_skater.glb"
var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_verify")


func _check(label: String, ok: bool, details: Dictionary = {}) -> void:
	checks.append({"name": label, "ok": ok, "details": details})
	if not ok:
		push_error(label + ": " + str(details))


func _verify() -> void:
	var packed := load(MODEL) as PackedScene
	_check("model_imported", packed != null)
	if packed == null:
		_finish()
		return
	var character := packed.instantiate()
	root.add_child(character)
	await process_frame
	var skeleton: Skeleton3D
	var animator: AnimationPlayer
	var meshes: Array[MeshInstance3D] = []
	var pending: Array[Node] = [character]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Skeleton3D:
			skeleton = node as Skeleton3D
		elif node is AnimationPlayer:
			animator = node as AnimationPlayer
		elif node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)
		for child in node.get_children():
			pending.append(child)
	_check("skeleton_present", skeleton != null)
	_check("animation_player_present", animator != null)
	_check("skinned_mesh_present", not meshes.is_empty())
	if skeleton == null or animator == null or meshes.is_empty():
		character.queue_free()
		_finish()
		return
	var names: Array[String] = []
	for index in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(index))
	_check("full_humanoid_skeleton", names.size() >= 40, {"bones": names})
	_check("authoring_controls_excluded", names.all(func(n: String) -> bool: return not n.begins_with("CTRL_")))
	for mesh in meshes:
		_check("mesh_has_skin:" + str(mesh.name), mesh.skin != null)
		_check("mesh_has_geometry:" + str(mesh.name), mesh.mesh != null and mesh.mesh.get_surface_count() > 0)
	var animations := animator.get_animation_list()
	for expected in ["ride_idle", "ollie_charge", "ollie_pop", "airborne", "landing", "grind", "fall", "crouch_preview", "rig_check"]:
		_check("clip:" + expected, animations.has(expected), {"animations": animations})
	if animator.has_animation("rig_check"):
		animator.play("rig_check")
		animator.seek(0.0, true)
		animator.advance(0.0)
		await process_frame
		var before: Array[Transform3D] = []
		for index in skeleton.get_bone_count():
			before.append(skeleton.get_bone_global_pose(index))
		animator.seek(0.5, true)
		animator.advance(0.0)
		await process_frame
		var moved := 0
		var finite := true
		for index in skeleton.get_bone_count():
			var pose := skeleton.get_bone_global_pose(index)
			finite = finite and pose.is_finite()
			if pose.origin.distance_to(before[index].origin) > 0.02:
				moved += 1
		_check("animation_moves_exported_bones", moved >= 5, {"moved_bones": moved})
		_check("finite_animated_transforms", finite)
	character.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	var failed := 0
	for entry in checks:
		if not entry.ok:
			failed += 1
	var args := OS.get_cmdline_user_args()
	var destination := args[0] if not args.is_empty() else "res://art/characters/godot_validation.json"
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write character validation report: " + destination)
		quit(1)
		return
	file.store_string(JSON.stringify({"completed": true, "failed": failed, "checks": checks}, "\t") + "\n")
	file.close()
	print("CHARACTER_IMPORT_CHECK: ", checks.size(), " checks, ", failed, " failures")
	quit(1 if failed else 0)
