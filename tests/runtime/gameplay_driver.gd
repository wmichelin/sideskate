extends Node
## InputMap automation of the real game. Events are submitted after the previous
## physics tick, when Godot schedules action edges for the next physics tick.
## Observations follow Player. Presentation state is read only.
const DIAGNOSTICS := preload("res://tests/support/runtime_diagnostics.gd")
const OBSERVER := preload("res://tests/runtime/physics_observer.gd")
const SCENARIOS := ["spawn", "gameplay", "air-out", "fly-out", "spine", "acid", "ramp-peak", "grind", "fall", "lava", "animation", "all"]
const FIXTURES := "res://tests/levels/runtime/"

var report: Dictionary = {"schema_version": 1, "completed": false, "checks": [], "errors": [], "screenshots": [], "scenarios": [], "checkpoints": {}, "failure_traces": [], "recordings": []}
var _diagnostics = DIAGNOSTICS.new()
var _observer: Node
var _events: Array[InputEvent] = []
var _held_keys: Dictionary = {}
var _dest := ""
var _report_path := ""
var _wait_frames := 4
var _input_log: Array = []
var _physics_tick := 0
var _level_path := ""
var _verified_ticks := 0
var _invalid_state_reported := false
var _recording_sim: PlayerSim
var _recording_path := ""


func _ready() -> void:
	_diagnostics.start()
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -10000
	Input.use_accumulated_input = false
	_observer = OBSERVER.new()
	_observer.process_mode = Node.PROCESS_MODE_ALWAYS
	_observer.process_physics_priority = 10000
	add_child(_observer)
	# Keep this observer alive while GameSession changes the actual current scene.
	get_tree().current_scene = null
	call_deferred("_run")


func _physics_process(_delta: float) -> void:
	_physics_tick += 1


func observe_completed_tick() -> void:
	var sim := _sim()
	if sim == null:
		return
	_verified_ticks += 1
	var state := sim.state
	if not _invalid_state_reported and (not state.position.is_finite() or not state.velocity.is_finite() or not state.tangent_velocity.is_finite()):
		_invalid_state_reported = true
		_check("finite_state_every_tick", false, _snapshot())


func flush_pending_input() -> void:
	var pending := _events.duplicate()
	_events.clear()
	for event in pending:
		Input.parse_input_event(event)
		_input_log.append({"physics_tick": _physics_tick + 1, "event": event.as_text(), "pressed": event.is_pressed()})


func _run() -> void:
	var args := _parse_args()
	_report_path = str(args.get("report", ""))
	if not report.errors.is_empty():
		_finish()
		return
	var pair: String = args.get("pair", "plaza_default")
	var pose: String = args.get("pose", "spawn")
	var mode: String = args.get("mode", "3d-only")
	var scenario: String = args.get("scenario", "gameplay" if mode == "gameplay" else "spawn")
	_wait_frames = int(args.get("wait_frames", "4"))
	if pose != "spawn":
		report.errors.append("Unsupported pose '%s'; supported: spawn. Use --scenario for input-reached maneuvers." % pose)
	if mode not in ["3d-only", "pair", "gameplay"]:
		report.errors.append("Unsupported mode '%s'; supported: 3d-only, pair, gameplay" % mode)
	if scenario not in SCENARIOS:
		report.errors.append("Unsupported scenario '%s'; supported: %s" % [scenario, SCENARIOS])
	if not str(args.get("wait_frames", "4")).is_valid_int() or _wait_frames < 1 or _wait_frames > 120:
		report.errors.append("--wait-frames must be an integer in [1, 120]")
	_level_path = str(args.get("level", ""))
	if _level_path.is_empty():
		if pair != pair.get_file() or pair.contains(".."):
			report.errors.append("--pair must be a level basename; use --level for an explicit resource path")
		else:
			for directory in ["res://levels/", "res://debug_levels/"]:
				if FileAccess.file_exists(directory + pair + ".ssk"):
					_level_path = directory + pair + ".ssk"
					break
	if not (_level_path.begins_with("res://levels/") or _level_path.begins_with("res://debug_levels/") or _level_path.begins_with("res://tests/levels/")) or _level_path.contains("..") or not _level_path.ends_with(".ssk") or not FileAccess.file_exists(_level_path):
		report.errors.append("Missing or unsupported level path: %s" % _level_path)
	var out: String = args.get("out", "user://render_compare")
	if out.is_empty() or out.begins_with("--"):
		report.errors.append("--out requires a writable directory")
	if report.errors.is_empty():
		pair = _level_path.get_file().get_basename()
		_dest = "%s/%s/%s" % [out.trim_suffix("/"), pair, pose]
		if _report_path.is_empty():
			_report_path = _dest.path_join("report.json")
		var status := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dest))
		if status != OK:
			report.errors.append("Cannot create output directory %s: %s" % [_dest, error_string(status)])
		else:
			var probe := FileAccess.open(_report_path, FileAccess.WRITE)
			if probe == null:
				report.errors.append("Cannot write report %s: %s" % [_report_path, error_string(FileAccess.get_open_error())])
			else:
				var initial_text := JSON.stringify(report)
				probe.store_string(initial_text)
				probe.flush()
				var write_error := probe.get_error()
				var written_bytes := probe.get_length()
				probe.close()
				var expected_bytes := initial_text.to_utf8_buffer().size()
				if write_error != OK or written_bytes != expected_bytes:
					report.errors.append("Cannot flush initial report %s: expected %d bytes, wrote %d (%s)" % [_report_path, expected_bytes, written_bytes, error_string(write_error)])
	report.merge({"pair": pair, "pose": pose, "mode": mode, "scenario": scenario, "path": _level_path,
		"runtime": {"engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "window": str(DisplayServer.window_get_size()), "physics_hz": Engine.physics_ticks_per_second, "max_fps": Engine.max_fps, "debug_tools": DebugTools.available}}, true)
	if not report.errors.is_empty():
		_finish()
		return
	if DisplayServer.get_name() == "headless":
		report.errors.append("Screenshots require a rendering display; run with a supervised virtual display")
		_finish()
		return
	if not await _load_level(_level_path):
		_finish()
		return
	await _ticks(_wait_frames)
	await _capture("3d")
	if mode == "pair":
		await _pause_cycle()
		report["escape_ok"] = report.errors.is_empty()
	if scenario == "gameplay" or scenario == "all":
		await _gameplay()
	var stories: Array = ["air-out", "fly-out", "spine", "acid", "ramp-peak", "grind", "fall", "lava", "animation"] if scenario == "all" else [scenario]
	for story in stories:
		if story not in ["spawn", "gameplay"]:
			await _story(story)
	await _release_all()
	await _frames(2)
	_finish()


func _parse_args() -> Dictionary:
	var result := {}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var arg := argv[i]
		if arg == "--no-debug-tools":
			i += 1
			continue
		if arg not in ["--pair", "--level", "--pose", "--out", "--mode", "--wait-frames", "--scenario", "--report"]:
			report.errors.append("Unknown argument: %s" % arg)
			i += 1
			continue
		if i + 1 >= argv.size() or argv[i + 1].begins_with("--"):
			report.errors.append("Missing value for %s" % arg)
			i += 1
			continue
		var key := arg.trim_prefix("--").replace("-", "_")
		if result.has(key):
			report.errors.append("Repeated argument: %s" % arg)
		result[key] = argv[i + 1]
		i += 2
	return result


func _sim() -> PlayerSim:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var player := scene.get_node_or_null("Player")
	return player.get_sim() if player != null else null


func _load_level(path: String) -> bool:
	await _release_all()
	_stop_recording()
	var previous := _sim()
	GameSession.play_level(path)
	for _i in range(180):
		await _ticks(1)
		if _sim() != null and _sim() != previous and GameSession.pending_level_path == path:
			var level := get_tree().current_scene.get_node("RampLevel") as RampLevel
			if level.level_path == path:
				var ready := _check_scene("load:" + path)
				_start_recording()
				return ready
	return _check("load:" + path, false, {"reason": "PlayerSim did not become ready within 180 physics ticks"})


func _check_scene(label: String) -> bool:
	var sim := _sim()
	if not _check(label + ":sim", sim != null):
		return false
	var state := sim.state
	_check(label + ":finite", state.position.is_finite() and state.velocity.is_finite() and state.tangent_velocity.is_finite())
	_check(label + ":owner", not state.is_grounded() or (sim.model.patches.has(state.surface_id) or sim.model.pipes.has(state.surface_id) or sim.model.ramps.has(state.surface_id) or sim.model.walls.has(state.surface_id)), _snapshot())
	var scene := get_tree().current_scene
	var visual := scene.get_node_or_null("World3D/LevelVisual3D")
	var meshes := int(visual.get("mesh_count")) if visual != null else 0
	_check(label + ":geometry", meshes > 0, {"mesh_count": meshes})
	report["mesh_count"] = meshes
	if visual != null:
		var bounds: AABB = visual.get("last_aabb")
		report["aabb"] = {"position": _vector(bounds.position), "size": _vector(bounds.size)}
	var camera := scene.get_node_or_null("World3D/CameraRig3D")
	_check(label + ":camera", camera != null and not camera.get("use_manual_origin"), {"normal_follow": camera != null and not camera.get("use_manual_origin")})
	if not DebugTools.available:
		_check(label + ":debug_off", get_tree().get_nodes_in_group("debug_tools").is_empty())
	return true


func _gameplay() -> void:
	report.scenarios.append("gameplay")
	GameSession.return_to_menu()
	await _scene_ready(GameSession.MENU_SCENE)
	var first_button := get_viewport().gui_get_focus_owner()
	await _tap(KEY_S)
	_check("keyboard_menu_navigation", get_viewport().gui_get_focus_owner() != first_button)
	await _tap(KEY_W)
	_check("keyboard_menu_navigation_back", get_viewport().gui_get_focus_owner() == first_button)
	await _capture("keyboard-menu")
	await _tap(KEY_ENTER)
	_check("keyboard_menu_confirmation", _sim() != null)
	if _sim() == null:
		return
	await _load_level(FIXTURES + "flat.ssk")
	var sim := _sim()
	var start := sim.state.position
	var camera := get_tree().current_scene.get_node("World3D/CameraRig3D") as CameraRig3D
	var spawn_world := WorldSpace.logical_to_world(start.x, start.y, start.z)
	_key(KEY_D, true)
	await _ticks(24)
	_key(KEY_D, false)
	await _ticks(1)
	var speed := sim.state.tangent_velocity.x
	_check("keyboard_movement", sim.state.position.x > start.x + 80.0 and speed > 400.0, _snapshot())
	_key(KEY_A, true)
	await _ticks(12)
	_key(KEY_A, false)
	await _ticks(1)
	_check("opposite_input_brakes", sim.state.tangent_velocity.x > 0.0 and sim.state.tangent_velocity.x < speed - 100.0, _snapshot())
	_checkpoint("movement_brake")
	await _frames(3)
	await _capture("movement")
	# Check the rendered follow target after drawing. A rig's first placement
	# from its default origin is not evidence that it followed player movement.
	var target := get_tree().current_scene.get_node("World3D/PlayerVisual") as Node3D
	var current := sim.state.position
	var logical_target := WorldSpace.logical_to_world(current.x, current.y, current.z)
	var actual_focus := camera.global_position - camera._orbit_offset()
	var follow_error := actual_focus.distance_to(target.global_position)
	var pose_error := target.global_position.distance_to(logical_target)
	var max_pose_lag := sim.max_speed * SimTolerances.FIXED_DT / WorldSpace.LOGIC_PER_METER + 0.02
	_check("camera_follows_movement",
		camera.global_position.is_finite() and target.global_position.is_finite()
		and absf(target.global_position.x - spawn_world.x) > 0.8
		and follow_error < 0.02 and pose_error <= max_pose_lag,
		{"spawn_world": _vector(spawn_world), "logical_target": _vector(logical_target),
		"presented_target": _vector(target.global_position), "actual_focus": _vector(actual_focus),
		"follow_error": follow_error, "pose_error": pose_error, "max_pose_lag": max_pose_lag})
	await _load_level(FIXTURES + "flat.ssk")
	sim = _sim()
	var grounded := sim.state.is_grounded()
	_key(KEY_SPACE, true)
	await _ticks(18)
	var charge := sim.ollie_charge
	_key(KEY_SPACE, false)
	await _ticks(1)
	_checkpoint("ollie_release")
	_check("fully_charged_ollie_release", grounded and charge >= 0.999 and sim.state.is_airborne() and sim.state.velocity.z > 0 and not sim.ollie_available, {"charge": charge, "state": _snapshot()})
	await _capture("ollie")
	await _pause_cycle()
	GameSession.return_to_menu()
	await _scene_ready(GameSession.MENU_SCENE)
	first_button = get_viewport().gui_get_focus_owner()
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	await _ticks(1)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await _ticks(1)
	_check("pad_menu_navigation", get_viewport().gui_get_focus_owner() != first_button)
	await _capture("pad-menu")
	_pad(JOY_BUTTON_A, true)
	await _ticks(1)
	_pad(JOY_BUTTON_A, false)
	await _scene_ready(GameSession.GAMEPLAY_SCENE)
	_check("pad_menu_confirmation", _sim() != null)
	if _sim() != null:
		await _load_level(FIXTURES + "flat.ssk")
		var before := _sim().state.position
		_axis(JOY_AXIS_LEFT_X, 1.0)
		await _ticks(20)
		_axis(JOY_AXIS_LEFT_X, 0.0)
		await _ticks(1)
		_checkpoint("pad_movement")
		_check("pad_axis_movement", _sim().state.position.x > before.x + 50, _snapshot())


func _pause_cycle() -> void:
	var sim := _sim()
	if sim == null:
		_check("pause_sim_available", false)
		return
	await _tap(KEY_ESCAPE)
	var pause := get_tree().current_scene.get_node_or_null("PauseMenu")
	if not _check("escape_pauses", get_tree().paused and pause != null and pause.is_open()):
		return
	var before := _snapshot()
	var hash_before := sim.gameplay_hash()
	await _ticks(12)
	_check("pause_freezes_tick_and_state", _snapshot() == before and sim.gameplay_hash() == hash_before, {"before": before, "after": _snapshot()})
	await _capture("paused")
	await _tap(KEY_ESCAPE)
	_check("escape_resumes", not get_tree().paused and not pause.is_open())
	var tick := sim.state.tick
	await _ticks(3)
	_check("resume_advances_sim", sim.state.tick >= tick + 3)
	await _tap(KEY_ESCAPE)
	pause.get_node("%ControlsButton").grab_focus()
	await _tap(KEY_ENTER)
	_check("pause_controls_open", pause._controls_panel != null and pause._controls_panel.visible)
	await _capture("controls")
	await _tap(KEY_ESCAPE)
	_check("controls_back_stays_paused", get_tree().paused and (pause._controls_panel == null or not pause._controls_panel.visible))
	pause.get_node("%QuitButton").grab_focus()
	await _tap(KEY_ENTER)
	await _scene_ready(GameSession.MENU_SCENE)
	_check("quit_returns_to_menu", not get_tree().paused and get_tree().current_scene.scene_file_path == GameSession.MENU_SCENE)
	await _capture("returned-menu")
	await _tap(KEY_ENTER)
	await _scene_ready(GameSession.GAMEPLAY_SCENE)
	_check("menu_reload", _sim() != null)


func _story(story: String) -> void:
	report.scenarios.append(story)
	match story:
		"air-out", "fly-out", "spine":
			await _pipe_story(story)
		"acid":
			await _acid_story()
		"ramp-peak":
			await _ramp_story()
		"grind":
			await _grind_story()
		"fall":
			await _fall_story()
		"lava":
			await _lava_story()
		"animation":
			await _animation_story()


func _skater_pose(label: String, expected: StringName) -> bool:
	var presenter := get_tree().current_scene.get_node("World3D/PlayerVisual") as LogicalPosePresenter3D
	var actual := presenter._skater_animator.pose_name if presenter._skater_animator != null else &""
	return _check("skater:" + label, actual == expected and presenter._skater != null
		and presenter._skater.visible and not presenter._body.visible,
		{"expected": expected, "actual": actual, "state": _snapshot()})


func _animation_story() -> void:
	if not await _load_level(FIXTURES + "flat.ssk"):
		return
	var sim := _sim()
	_skater_pose("ride", SkaterAnimationController.RIDE)
	await _capture("skater-ride")
	_key(KEY_SPACE, true)
	await _ticks(18)
	_skater_pose("charge", SkaterAnimationController.CHARGE)
	await _capture("skater-charge")
	_key(KEY_SPACE, false)
	await _ticks(5)
	_skater_pose("pop", SkaterAnimationController.OLLIE)
	await _capture("skater-pop")
	var reached := await _until(func(): return sim.state.is_airborne() and sim.state.velocity.z <= 0, 120)
	_check("skater:reached_apex", reached, _snapshot())
	_skater_pose("air", SkaterAnimationController.AIR)
	await _capture("skater-air")
	reached = await _until(func(): return sim.state.is_grounded(), 120)
	_check("skater:real_landing", reached, _snapshot())
	await _ticks(3)
	_skater_pose("land", SkaterAnimationController.LAND)
	await _capture("skater-land")
	await _ticks(24)
	_skater_pose("settled", SkaterAnimationController.RIDE)
	await _tap(KEY_ESCAPE)
	var presenter := get_tree().current_scene.get_node("World3D/PlayerVisual") as LogicalPosePresenter3D
	var paused_time := presenter._skater_anim.current_animation_position
	await _ticks(12)
	_check("skater:pause_freezes_animation", get_tree().paused
		and is_equal_approx(paused_time, presenter._skater_anim.current_animation_position))
	await _tap(KEY_ESCAPE)
	_key(KEY_Y, true)
	await _ticks(1)
	_key(KEY_Y, false)
	await _ticks(6)
	_skater_pose("fall", SkaterAnimationController.FALL)
	_check("skater:separate_fall_bodies", presenter._skater.get_parent() == presenter._rider_fall
		and presenter._board_fall.visible and not presenter._board.visible)
	await _capture("skater-fall")
	reached = await _until(func(): return not sim.state.falling, 180)
	_check("skater:recovered", reached, _snapshot())
	_skater_pose("recovery_pose", SkaterAnimationController.RIDE)
	_check("skater:reattached_after_fall", presenter._skater.get_parent() == presenter and presenter._board.visible)


func _pipe_story(story: String) -> void:
	if not await _load_level(FIXTURES + ("spine.ssk" if story == "spine" else "pipe.ssk")):
		return
	var sim := _sim()
	_key(KEY_D, true)
	var reached := await _until(func(): return sim.state.is_grounded() and sim.model.pipes.has(sim.state.surface_id) and sim.state.u > 0.65, 180)
	_key(KEY_D, false)
	_check(story + ":climbed_pipe", reached, _snapshot())
	if not reached:
		return
	reached = await _until(func(): return sim.state.is_hanging(), 90)
	_check(story + ":air_out", reached, _snapshot())
	if not reached:
		return
	_checkpoint(story + ":air_out")
	var source_edge := sim.state.hang_edge_id
	var source_pipe := str(sim.model.edges[source_edge].from_surface_id)
	var anchor_x := sim.state.position.x
	if story == "fly-out":
		_key(KEY_D, true)
		await _ticks(1)
		_key(KEY_D, false)
		_checkpoint("fly_out")
		_check("fly_out:outward_free_air", sim.state.is_airborne() and not sim.state.is_hanging() and sim.state.velocity.x > 0 and sim.state.free_air_upright, _snapshot())
	elif story == "spine":
		_key(KEY_T, true)
		reached = await _until(func(): return sim.state.has_maneuver(), 45)
		_key(KEY_T, false)
		_check("spine:accepted_transfer", reached, _snapshot())
		if reached:
			var target: String = sim.state.maneuver.dest_pipe_id
			_check("spine:opposite_facing_target", sim.model.pipes.has(target) and sim.model.pipes[target].side != sim.model.pipes[source_pipe].side, {"source": source_pipe, "target": target})
			reached = await _until(func(): return sim.state.is_grounded() and sim.state.surface_id == target, 150)
			_checkpoint("spine_remount")
			_check("spine:target_remount", reached and not sim.state.falling, _snapshot())
	else:
		await _ticks(5)
		_check("air_out:x_locked", sim.state.is_hanging() and absf(sim.state.position.x - anchor_x) < 0.001, _snapshot())
		reached = await _until(func(): return sim.state.is_grounded(), 150)
		_checkpoint("air_out_remount")
		_check("air_out:source_remount", reached and sim.state.surface_id == source_pipe and not sim.state.falling, _snapshot())
	await _capture(story)


func _acid_story() -> void:
	if not await _load_level(FIXTURES + "acid.ssk"):
		return
	var sim := _sim()
	_key(KEY_D, true)
	_key(KEY_SPACE, true)
	await _ticks(18)
	_key(KEY_SPACE, false)
	await _ticks(1)
	_key(KEY_D, false)
	_key(KEY_T, true)
	var reached := await _until(func(): return sim.state.has_maneuver(), 120)
	_key(KEY_T, false)
	_check("acid:accepted_transfer", reached, _snapshot())
	if reached:
		var target: String = sim.state.maneuver.dest_pipe_id
		reached = await _until(func(): return sim.state.is_grounded() and sim.state.surface_id == target, 150)
		_checkpoint("acid_remount")
		_check("acid:target_remount", reached and not sim.state.falling, _snapshot())
	await _capture("acid")


func _ramp_story() -> void:
	if not await _load_level(FIXTURES + "ramp.ssk"):
		return
	var sim := _sim()
	_key(KEY_D, true)
	var reached := await _until(func(): return sim.state.is_airborne(), 180)
	_key(KEY_D, false)
	_checkpoint("ramp_peak")
	_check("ramp_peak:free_air", reached and sim.state.velocity.x > 0 and sim.state.velocity.z > 0 and not sim.state.is_hanging() and sim.state.free_air_upright, _snapshot())
	await _capture("ramp-peak")


func _grind_story() -> void:
	if not await _load_level(FIXTURES + "rail.ssk"):
		return
	var sim := _sim()
	_key(KEY_SPACE, true)
	await _ticks(18)
	_key(KEY_SPACE, false)
	_key(KEY_R, true)
	_key(KEY_W, true)
	await _ticks(7)
	_key(KEY_W, false)
	var reached := await _until(func(): return sim.state.is_grinding(), 100)
	_checkpoint("grind_mount")
	_check("grind:input_mount", reached, _snapshot())
	if reached:
		_key(KEY_W, true)
		reached = await _until(func(): return sim.state.falling, 120)
		_key(KEY_W, false)
		_checkpoint("grind_fall")
		_check("grind:balance_fall", reached, _snapshot())
	_key(KEY_R, false)
	await _capture("grind")


func _fall_story() -> void:
	if not await _load_level(FIXTURES + "flat.ssk"):
		return
	var sim := _sim()
	_key(KEY_D, true)
	await _ticks(20)
	_key(KEY_D, false)
	_key(KEY_Y, true)
	await _ticks(1)
	_key(KEY_Y, false)
	_check("fall:input_starts_bout", sim.state.falling and sim.state.alive, _snapshot())
	var reached := await _until(func(): return not sim.state.falling, 150)
	_checkpoint("fall_recovery")
	_check("fall:checkpoint_recovery", reached and sim.state.alive and sim.state.is_grounded() and sim.state.position.distance_to(sim.checkpoint_position) < 1.0, _snapshot())
	await _capture("fall")


func _lava_story() -> void:
	if not await _load_level(FIXTURES + "lava.ssk"):
		return
	var sim := _sim()
	_key(KEY_D, true)
	var reached := await _until(func(): return not sim.state.alive, 150)
	_key(KEY_D, false)
	_check("lava:input_reaches_hazard", reached, _snapshot())
	if not reached:
		return
	var overlay := get_tree().get_first_node_in_group("death_overlay")
	var recovery := {"count": 0, "physics": false, "alive": false, "tick": 0}
	overlay.finished.connect(func():
		recovery.count += 1
		recovery.physics = Engine.is_in_physics_frame()
		recovery.alive = sim.state.alive
		recovery.tick = _physics_tick)
	await _tap(KEY_ESCAPE)
	var pause := get_tree().current_scene.get_node("PauseMenu")
	var dead_hash := sim.gameplay_hash()
	var hold_ticks := ceili(float(overlay.hold_seconds) / SimTolerances.FIXED_DT)
	await _ticks(hold_ticks + 12)
	_check("lava:pause_freezes_death", get_tree().paused and pause.is_open()
		and not sim.state.alive and sim.gameplay_hash() == dead_hash and recovery.count == 0)
	await _capture("lava-paused")
	# Queue Escape through real input. The remaining hold must still elapse.
	var resume_tick := _physics_tick
	_key(KEY_ESCAPE, true)
	await _ticks(1)
	_key(KEY_ESCAPE, false)
	reached = await _until(func(): return sim.state.alive, hold_ticks + 12)
	_checkpoint("lava_respawn")
	_check("lava:automatic_respawn", reached and sim.state.is_grounded()
		and sim.state.position.distance_to(sim.checkpoint_position) < 1.0, _snapshot())
	_check("lava:physics_recovery_after_resume", recovery.count == 1 and recovery.physics
		and recovery.alive and recovery.tick - resume_tick >= hold_ticks - 2, recovery)
	await _ticks(hold_ticks + 12)
	_check("lava:recovers_once", recovery.count == 1 and sim.state.alive)
	await _capture("lava")
	await _lava_exit_story()


func _lava_exit_story() -> void:
	if not await _load_level(FIXTURES + "lava.ssk"):
		return
	var sim := _sim()
	_key(KEY_D, true)
	var reached := await _until(func(): return not sim.state.alive, 150)
	_key(KEY_D, false)
	if not _check("lava:exit_reaches_hazard", reached, _snapshot()):
		return
	var overlay := get_tree().get_first_node_in_group("death_overlay")
	var recovery := {"count": 0}
	overlay.finished.connect(func(): recovery.count += 1)
	var hold_ticks := ceili(float(overlay.hold_seconds) / SimTolerances.FIXED_DT)
	await _tap(KEY_ESCAPE)
	var dead_hash := sim.gameplay_hash()
	_stop_recording()
	var pause := get_tree().current_scene.get_node("PauseMenu")
	pause.get_node("%QuitButton").grab_focus()
	await _tap(KEY_ENTER)
	await _scene_ready(GameSession.MENU_SCENE)
	await _tap(KEY_ENTER)
	await _scene_ready(GameSession.GAMEPLAY_SCENE)
	var replacement := _sim()
	await _ticks(hold_ticks + 12)
	_check("lava:exit_cancels_recovery", not is_instance_valid(overlay)
		and recovery.count == 0 and sim.gameplay_hash() == dead_hash
		and replacement != null and replacement != sim and replacement.state.alive)


func _until(predicate: Callable, limit: int) -> bool:
	for _i in range(limit):
		await _ticks(1)
		if predicate.call():
			return true
	return false


func _scene_ready(path: String) -> bool:
	for _i in range(180):
		await _ticks(1)
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == path and (path != GameSession.GAMEPLAY_SCENE or _sim() != null):
			await _frames(2)
			return true
	return _check("scene_ready:" + path, false)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	_events.append(event)
	_held_keys[code] = down


func _pad(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	_events.append(event)


func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_events.append(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await _ticks(1)
	_key(code, false)
	await _ticks(1)
	await _frames(3)


func _release_all() -> void:
	for code in _held_keys:
		if _held_keys[code]:
			_key(code, false)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _ticks(1)


func _ticks(count: int) -> void:
	for _i in range(count):
		await _observer.stepped


func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame


func _check(label: String, passed: bool, details: Dictionary = {}) -> bool:
	var result := {"check": label, "ok": passed, "physics_tick": _physics_tick, "details": details}
	report.checks.append(result)
	if not passed:
		report.errors.append(label)
		_save_trace(label)
	print("RUNTIME_CHECK ", JSON.stringify(result))
	return passed


func _snapshot() -> Dictionary:
	var sim := _sim()
	if sim == null:
		return {}
	var state := sim.state
	return {"tick": state.tick, "hash": state.state_hash(), "position": _vector(state.position), "velocity": _vector(state.velocity), "tangent_velocity": [state.tangent_velocity.x, state.tangent_velocity.y], "surface_id": state.surface_id, "mode": state.mode, "hang_edge": state.hang_edge_id, "falling": state.falling, "alive": state.alive}


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _capture(label: String) -> bool:
	var requested_state := _snapshot()
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dest.path_join(label + ".png")
	var success := img != null and not img.is_empty() and img.save_png(ProjectSettings.globalize_path(path)) == OK
	if success:
		var loaded := Image.load_from_file(ProjectSettings.globalize_path(path))
		success = loaded != null and not loaded.is_empty() and loaded.get_width() > 0 and loaded.get_height() > 0
	_check("capture:" + label, success, {"path": path, "state": _snapshot()})
	if success:
		report.screenshots.append({"path": path, "width": img.get_width(), "height": img.get_height(), "requested_state": requested_state, "state": _snapshot()})
		if label == "3d":
			report["shot_3d"] = path
	return success


func _save_trace(label: String) -> void:
	if _dest.is_empty():
		return
	var sim := _sim()
	var frames: Array = []
	if sim != null and sim.trace != null:
		frames = sim.trace.frames.slice(maxi(0, sim.trace.frames.size() - 180))
	var path := _dest.path_join("failure-trace-%d.json" % report.failure_traces.size())
	var file := FileAccess.open(path, FileAccess.WRITE)
	report.failure_traces.append(path)
	if file != null:
		file.store_string(JSON.stringify({"check": label, "state": _snapshot(), "input_events": _input_log, "recent_trace": JSON.parse_string(SimSnapshot.encode({"frames": frames})), "recording": _recording_path}, "  "))
		file.close()


func _checkpoint(label: String) -> void:
	var sim := _sim()
	if sim != null:
		report.checkpoints[label] = {"hash": sim.gameplay_hash(), "state": _snapshot(), "snapshot": JSON.parse_string(SimSnapshot.encode(sim.gameplay_snapshot()))}


func _start_recording() -> void:
	_recording_sim = _sim()
	_recording_path = _dest.path_join("recording-%d.jsonl" % report.recordings.size())
	if _check("start_recording", _recording_sim.start_recording(_recording_path), {"path": _recording_path}):
		report.recordings.append({"path": _recording_path, "level": get_tree().current_scene.get_node("RampLevel").level_path})


func _stop_recording() -> void:
	if _recording_sim == null:
		return
	var summary := _recording_sim.stop_recording()
	_check("finish_recording", str(summary.get("error", "")).is_empty(), {"path": _recording_path, "events": summary.get("event_count", 0)})
	_recording_sim = null


func _finish() -> void:
	_stop_recording()
	report["final_state"] = _snapshot()
	_events.clear()
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene != null:
		get_tree().current_scene = null
		scene.queue_free()
	await _frames(3)
	if _diagnostics.unexpected_count() > 0:
		report.errors.append("Unexpected runtime diagnostics: %d" % _diagnostics.unexpected_count())
	report["diagnostics"] = _diagnostics.entries
	_diagnostics.stop()
	report["completed"] = true
	report["verified_physics_ticks"] = _verified_ticks
	report["check_count"] = report.checks.size()
	report["failed"] = report.checks.filter(func(item): return not item.ok).size()
	report["input_events"] = _input_log
	var code := 0 if report.errors.is_empty() and report.check_count > 0 else 1
	if not _report_path.is_empty():
		var file := FileAccess.open(_report_path, FileAccess.WRITE)
		if file == null:
			report.errors.append("Failed writing final report: " + error_string(FileAccess.get_open_error()))
			code = 1
		else:
			var final_text := JSON.stringify(report, "  ")
			file.store_string(final_text)
			file.flush()
			var write_error := file.get_error()
			var written_bytes := file.get_length()
			file.close()
			var expected_bytes := final_text.to_utf8_buffer().size()
			if write_error != OK or written_bytes != expected_bytes:
				report.errors.append("Cannot flush final report %s: expected %d bytes, wrote %d (%s)" % [_report_path, expected_bytes, written_bytes, error_string(write_error)])
				code = 1
	print("RUNTIME_COMPLETE ", JSON.stringify({"completed": true, "check_count": report.check_count, "failed": report.failed, "errors": report.errors, "report": _report_path}))
	get_tree().paused = false
	get_tree().quit(code)
