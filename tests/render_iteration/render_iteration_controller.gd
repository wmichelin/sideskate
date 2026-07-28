extends Node
## Persistent orchestrator — never uses change_scene (that would free this node).
## Swaps a Host child between 2D/3D/menu packed scenes.


func _ready() -> void:
	if not has_node("Host"):
		var host := Node.new()
		host.name = "Host"
		add_child(host)
	call_deferred("_run")


func _host() -> Node:
	return get_node("Host")


func _run() -> void:
	var args := _parse_args()
	var pair: String = str(args.get("pair", "plaza_default"))
	var pose_name: String = str(args.get("pose", "spawn"))
	var out_dir: String = str(args.get("out", "user://render_compare"))
	var mode: String = str(args.get("mode", "3d-only"))
	var wait_frames: int = int(args.get("wait_frames", 4))

	var path_2d := "res://levels/%s.ssk" % pair
	var path_3d := "res://levels_3d/%s.ssk" % pair
	if not FileAccess.file_exists(path_3d):
		push_error("missing 3D twin %s" % path_3d)
		get_tree().quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var dest := "%s/%s/%s" % [out_dir, pair, pose_name]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))

	var report := {
		"pair": pair,
		"pose": pose_name,
		"mode": mode,
		"path_2d": path_2d,
		"path_3d": path_3d,
		"errors": [],
	}

	var code := 0
	if mode == "pair":
		code = await _run_pair(path_2d, path_3d, dest, pose_name, wait_frames, report)
	else:
		code = await _run_3d_only(path_3d, dest, pose_name, wait_frames, report)

	var report_path := "%s/report.json" % dest
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()
	print("render_iteration wrote %s (exit %d)" % [report_path, code])
	get_tree().quit(code)


func _swap_scene(packed_path: String) -> Node:
	var host := _host()
	for c in host.get_children():
		c.free()
	var packed: PackedScene = load(packed_path)
	if packed == null:
		return null
	var inst: Node = packed.instantiate()
	host.add_child(inst)
	return inst


func _run_3d_only(
	path_3d: String, dest: String, pose_name: String, wait_frames: int, report: Dictionary
) -> int:
	GameSession.pending_level_path = path_3d
	GameSession.pending_backend = GameSession.RenderBackend.WORLD_3D
	var scene := _swap_scene(GameSession.SCENE_3D)
	if scene == null:
		report["errors"].append("load 3d failed")
		return 1
	await _wait_frames(wait_frames + 2)
	_apply_pose(scene, pose_name)
	await _wait_frames(maxi(wait_frames, 2))
	var shot := "%s/3d.png" % dest
	if not await _capture(shot):
		report["errors"].append("3d capture failed")
		return 1
	report["shot_3d"] = shot
	_fill_3d_stats(scene, report)
	return 0


func _run_pair(
	path_2d: String,
	path_3d: String,
	dest: String,
	pose_name: String,
	wait_frames: int,
	report: Dictionary
) -> int:
	GameSession.pending_level_path = path_2d
	GameSession.pending_backend = GameSession.RenderBackend.CANVAS_2D
	var scene2 := _swap_scene(GameSession.SCENE_2D)
	if scene2 == null:
		report["errors"].append("load 2d failed")
		return 1
	await _wait_frames(wait_frames + 2)
	_apply_pose(scene2, pose_name)
	await _wait_frames(maxi(wait_frames, 2))
	var shot2 := "%s/2d.png" % dest
	if not await _capture(shot2):
		report["errors"].append("2d capture failed")
		return 1
	report["shot_2d"] = shot2

	# Escape → menu (simulate GameSession.return_to_menu without freeing runner).
	var menu := _swap_scene(GameSession.MENU_SCENE)
	if menu == null:
		report["errors"].append("menu load failed")
		return 1
	await _wait_frames(wait_frames)
	report["escape_ok"] = true

	GameSession.pending_level_path = path_3d
	GameSession.pending_backend = GameSession.RenderBackend.WORLD_3D
	var scene3 := _swap_scene(GameSession.SCENE_3D)
	if scene3 == null:
		report["errors"].append("load 3d after menu failed")
		return 1
	await _wait_frames(wait_frames + 2)
	_apply_pose(scene3, pose_name)
	await _wait_frames(maxi(wait_frames, 2))
	var shot3 := "%s/3d.png" % dest
	if not await _capture(shot3):
		report["errors"].append("3d capture failed")
		return 1
	report["shot_3d"] = shot3
	_fill_3d_stats(scene3, report)
	return 0


func _apply_pose(scene: Node, _pose_name: String) -> void:
	if scene == null:
		return
	var player = scene.get_node_or_null("Player")
	var level = scene.get_node_or_null("RampLevel") as RampLevel
	if player == null or level == null or level.spec == null:
		return
	if not player.has_node("PseudoDepthBody"):
		return
	var depth: PseudoDepthBody = player.get_node("PseudoDepthBody")
	depth.logical_x = level.spec.spawn_x
	depth.logical_z = level.spec.spawn_z
	depth.surface_height = 0.0
	depth.airborne = false
	depth.apply()
	var cam := scene.get_node_or_null("World3D/CameraRig3D")
	if cam != null and cam.has_method("set_follow_world"):
		cam.call(
			"set_follow_world",
			WorldSpace.logical_to_world(depth.logical_x, depth.logical_z, depth.surface_height)
		)


func _fill_3d_stats(scene: Node, report: Dictionary) -> void:
	if scene == null:
		return
	var vis := scene.get_node_or_null("World3D/LevelVisual3D")
	if vis == null:
		return
	report["mesh_count"] = vis.get("mesh_count")
	var aabb: AABB = vis.get("last_aabb")
	report["aabb"] = {
		"position": [aabb.position.x, aabb.position.y, aabb.position.z],
		"size": [aabb.size.x, aabb.size.y, aabb.size.z],
	}


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return false
	return img.save_png(ProjectSettings.globalize_path(path)) == OK


func _wait_frames(n: int) -> void:
	var tree := get_tree()
	for _i in range(n):
		await tree.process_frame


func _parse_args() -> Dictionary:
	var out := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var a: String = argv[i]
		if a.begins_with("--") and i + 1 < argv.size() and not str(argv[i + 1]).begins_with("--"):
			out[a.trim_prefix("--").replace("-", "_")] = argv[i + 1]
			i += 2
		elif a.begins_with("--"):
			out[a.trim_prefix("--").replace("-", "_")] = true
			i += 1
		else:
			i += 1
	return out
