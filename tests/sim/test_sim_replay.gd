extends RefCounted
## Recorded input/state replay, model identity and bounded diagnostic retention.

const HALFPIPE := "res://tests/levels/sim/sim_halfpipe.ssk"
const SPINE := "res://tests/levels/sim/sim_spine_transfer_speed.ssk"
const RAIL := "res://tests/levels/sim/sim_rail_x.ssk"
var _failed := false


func run() -> bool:
	for case in [
		_identity_fields, _model_geometry_identity, _snapshot_round_trip,
		_ollie_spin_tuning_replay, _transfer_replay, _grind_fall_respawn_replay,
		_lava_respawn_replay, _streaming_and_rejection, _recording_boundary, _bounded_history,
	]:
		var ok: bool = case.call()
		print("SIM_REPLAY_CASE %s %s" % [case.get_method(), "PASS" if ok else "FAIL"])
		_failed = _failed or not ok
	if "--sim-soak" in OS.get_cmdline_user_args():
		_failed = not _memory_soak() or _failed
	return not _failed


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("sim replay: " + detail)
	return ok


func _sim(path: String = HALFPIPE) -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(FileAccess.get_file_as_string(path), path.get_file()):
		return null
	return sim


func _changed(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL: return not value
		TYPE_INT: return value + 1
		TYPE_FLOAT: return value + 0.123456789 if is_finite(value) else 123.0
		TYPE_STRING: return value + "_changed"
		TYPE_VECTOR2: return value + Vector2(0.25, 0.0)
		TYPE_VECTOR3: return value + Vector3(0.25, 0.0, 0.0)
	return value


func _identity_fields() -> bool:
	var state := SimState.new()
	for property in state.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			if not _check(state.to_dict().has(property.name), "unversioned state property " + property.name):
				return false
	var baseline := state.state_hash()
	for field in SimState.SNAPSHOT_FIELDS:
		var original: Variant = state.get(field)
		state.set(field, _changed(original))
		var excluded: bool = field in SimState.PRESENTATION_LATCHES or field == "last_reject"
		if not _check((state.state_hash() == baseline) == excluded, "state identity field " + field):
			return false
		state.set(field, original)
	state.maneuver = ManeuverPlan.new()
	baseline = state.state_hash()
	for field in ManeuverPlan.SNAPSHOT_FIELDS:
		var original: Variant = state.maneuver.get(field)
		state.maneuver.set(field, _changed(original))
		if not _check(state.state_hash() != baseline, "plan identity field " + field):
			return false
		state.maneuver.set(field, original)
	state.maneuver = null
	state.u = 0.000000001
	if not _check(state.state_hash() != SimState.new().state_hash(), "scalar float precision"):
		return false
	if not _check(SimSnapshot.digest({"a": 1.0, "b": 2.0}) == SimSnapshot.digest({"b": 2.0, "a": 1.0}),
			"canonical dictionary order"):
		return false
	var sim := _sim()
	baseline = sim.gameplay_hash()
	for field in PlayerSim.INPUT_FIELDS + PlayerSim.TUNING_FIELDS + PlayerSim.SNAPSHOT_FIELDS:
		if field == "checkpoint_history":
			continue
		var original: Variant = sim.get(field)
		sim.set(field, _changed(original))
		if not _check((sim.gameplay_hash() == baseline) == (field == "ollie_just_popped"),
				"orchestrator identity field " + field):
			return false
		sim.set(field, original)
	sim.checkpoint_history[0].position.x += 1.0
	if not _check(sim.gameplay_hash() != baseline, "checkpoint history identity"):
		return false
	sim.checkpoint_history[0].position.x -= 1.0
	var tuning := sim.tuning_snapshot()
	for field in tuning.global:
		var changed := tuning.duplicate(true)
		changed.global[field] = _changed(changed.global[field])
		sim.apply_tuning(changed)
		var differs := sim.gameplay_hash() != baseline
		sim.apply_tuning(tuning)
		if not _check(differs, "global tuning identity " + field):
			return false
	return true


func _model_geometry_identity() -> bool:
	var source := "ssk 2\nname hash_probe\nstep_height 20\n---\nlayer 0\nheight 0\n)))==@==(((\n)))=====(((\n"
	for shape in [source, source.replace(")", ">").replace("(", "<")]:
		var a := IdlCompiler.compile_text(shape)
		var b := IdlCompiler.compile_text(shape.replace("step_height 20", "step_height 40"))
		if not _check(a.is_valid() and b.is_valid() and a.model_hash != b.model_hash,
				"60/120 pipe/ramp rise identity"):
			return false
	var model := IdlCompiler.compile_text(source)
	for field in ["width", "depth", "cell_w", "cell_h", "grid_w", "grid_h",
			"spawn_x", "spawn_z", "spawn_height", "spawn_facing"]:
		var original: Variant = model.get(field)
		model.set(field, _changed(original))
		var differs := IdlCompiler._hash_model(model) != model.model_hash
		model.set(field, original)
		if not _check(differs, "model field " + field):
			return false
	model.playable_mask[0] = 0
	if not _check(IdlCompiler._hash_model(model) != model.model_hash, "playable footprint identity"):
		return false
	model.playable_mask[0] = 1
	var coping: CopingEdge = model.copings[model.all_coping_ids()[0]]
	coping.height_samples[0].height += 1.0
	if not _check(IdlCompiler._hash_model(model) != model.model_hash, "coping height identity"):
		return false
	coping.height_samples[0].height -= 1.0
	coping.spans[0].effective_height_samples[0].height += 1.0
	if not _check(IdlCompiler._hash_model(model) != model.model_hash, "effective coping height identity"):
		return false
	coping.spans[0].effective_height_samples[0].height -= 1.0
	var edge: TopologyEdge = model.edges[model.all_edge_ids()[0]]
	edge.u_gate += 0.1
	return _check(IdlCompiler._hash_model(model) != model.model_hash, "topology gate identity")


func _snapshot_round_trip() -> bool:
	var sim := _sim()
	sim.state.maneuver = ManeuverPlan.new()
	sim.state.maneuver.start_position = Vector3(1.1, 2.2, 3.3)
	sim.state.maneuver.start_velocity = Vector3(100.0, 2.0, 300.0)
	sim.state.maneuver.z_start = 2.2
	sim.state.maneuver.z_end = 3.0
	sim.ollie_charge = 0.3333333333333333
	sim.transfer_hold_eligible = 0.0733333333333333
	sim.set_input(Vector2(0.1, -0.2), true, false, true, false, true, false, true)
	var snapshot := SimSnapshot.decode(SimSnapshot.encode(sim.gameplay_snapshot()))
	var restored := PlayerSim.new()
	if not _check(restored.setup_from_model(sim.model) and restored.model == sim.model,
			"bootstrap shares the immutable compiled model"):
		return false
	if not _check(restored.restore_snapshot(snapshot), "restore complete snapshot"):
		return false
	if not _check(restored.gameplay_hash() == sim.gameplay_hash(), "exact snapshot round trip"):
		return false
	if not _check(restored.state.air_peak_height == -INF, "INF sentinel survives JSON transport"):
		return false
	restored.state.maneuver.elapsed += 0.01
	restored.checkpoint_history[0].position.x += 1.0
	if not _check(restored.gameplay_hash() != sim.gameplay_hash(), "restored state owns its data"):
		return false
	snapshot.state.erase("tangent_velocity")
	return _check(not restored.restore_snapshot(snapshot), "reject incomplete snapshot")


func _replay_equal(sim: PlayerSim, data: Dictionary, path: String) -> bool:
	var serialized := SimSnapshot.encode(data)
	var decoded := SimSnapshot.decode(serialized)
	var target := _sim(path)
	var result := SimTrace.replay(decoded, target)
	return _check(bool(result.get("ok", false)) and result.get("final_hash") == sim.gameplay_hash(),
		"serialized replay: %s" % result.get("error", "hash mismatch"))


func _ollie_spin_tuning_replay() -> bool:
	var sim := _sim()
	sim.ollie_accel = 0.0
	if not sim.start_recording():
		return false
	for _i in range(20):
		sim.set_input(Vector2.ZERO, false, false, true)
		sim.tick()
	if not _check(sim.ollie_charge == 1.0 and sim.state.is_grounded(), "recorded grounded charge"):
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not _check(sim.state.is_airborne() and not sim.ollie_available, "recorded ollie release"):
		return false
	var original_tuning := sim.tuning_snapshot()
	SimTolerances.SPIN_RATE = PI * 60.0 / 20.0
	for _i in range(20):
		sim.set_input(Vector2.ZERO, false, false, false, false, false, true)
		sim.tick()
	for _i in range(40):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	sim.apply_tuning(original_tuning)
	# Every tuning change belongs to its next physics event.
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not _check(sim.state.is_grounded() and not sim.state.falling, "recorded spin landing"):
		return false
	return _replay_equal(sim, sim.stop_recording(), HALFPIPE)


func _transfer_replay() -> bool:
	var sim := _sim(SPINE)
	var source: PipeSurface
	for id in sim.model.all_pipe_ids():
		if sim.model.pipes[id].side == SimKinds.PipeSide.RIGHT:
			source = sim.model.pipes[id]
	if source == null:
		return false
	var z := (source.z_min + source.z_max) * 0.5
	sim.state.surface_id = source.id
	sim.state.u = 1.0
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.position = Vector3(source.x_at_theta(z, PI * 0.5), z, source.height_at_theta(z, PI * 0.5))
	sim.state.set_facing_side("r")
	sim.start_recording()
	var transferred := false
	for _i in range(30):
		sim.set_input(Vector2.ZERO, true, false)
		sim.tick()
		if sim.state.has_maneuver():
			transferred = sim.state.maneuver.kind == ManeuverPlan.Kind.TRANSFER
			break
	if not _check(transferred, "recorded held transfer accepted"):
		return false
	# Restore also supports an initial snapshot halfway through an accepted plan.
	var mid := SimSnapshot.decode(SimSnapshot.encode(sim.gameplay_snapshot()))
	var restored := _sim(SPINE)
	if not _check(restored.restore_snapshot(mid) and restored.gameplay_hash() == sim.gameplay_hash(),
			"mid-transfer initial restore"):
		return false
	for _i in range(20):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	return _replay_equal(sim, sim.stop_recording(), SPINE)


func _grind_fall_respawn_replay() -> bool:
	var sim := _sim(RAIL)
	var rail: RailSurface = sim.model.rails[sim.model.all_rail_ids()[0]]
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3((rail.x_min + rail.x_max) * 0.5, rail.z, rail.top_height + 10.0)
	sim.state.velocity = Vector3(30.0, 0.0, -40.0)
	sim.start_recording()
	sim.set_input(Vector2.ZERO, false, false, false, false, false, false, true)
	sim.tick()
	if not _check(sim.state.is_grinding(), "recorded grind input mounts"):
		return false
	for _i in range(8):
		sim.set_input(Vector2(0.2, 0.0), false, false, true)
		sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not _check(sim.state.is_airborne() and not sim.ollie_available, "recorded grind ollie release"):
		return false
	sim.begin_fall()
	if not _check(sim.state.falling, "recorded fall command"):
		return false
	for _i in range(130):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	if not _check(not sim.state.falling and sim.state.tick < 30, "fall recovery resets local tick"):
		return false
	sim.respawn()
	sim.tick()
	var data := sim.stop_recording()
	if not _check(data.event_count == 143, "monotonic events include external fall/respawn"):
		return false
	return _replay_equal(sim, data, RAIL)


func _lava_respawn_replay() -> bool:
	var text := "ssk 2\nname replay_lava\n---\nlayer 0\nheight 0\n==@=xxx===\n==========\n"
	var sim := PlayerSim.new()
	var target := PlayerSim.new()
	if not sim.setup_from_text(text) or not target.setup_from_text(text):
		return false
	sim.start_recording()
	for _i in range(60):
		sim.set_input(Vector2.RIGHT, false, false)
		sim.tick()
		if not sim.state.alive:
			break
	if not _check(not sim.state.alive, "recorded input reaches lava"):
		return false
	sim.tick() # Dead physics ticks remain ordered no-op events.
	sim.respawn()
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	var data := SimSnapshot.decode(SimSnapshot.encode(sim.stop_recording()))
	var result := SimTrace.replay(data, target)
	return _check(bool(result.get("ok", false)) and target.state.alive,
		"lava/respawn replay: %s" % result.get("error", ""))


func _streaming_and_rejection() -> bool:
	var sim := _sim()
	var path := "user://sim_replay_test_%d.jsonl" % OS.get_process_id()
	if not _check(sim.start_recording(path), "open stream"):
		return false
	for _i in range(230):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	var summary := sim.stop_recording()
	if not _check(summary.events.is_empty() and summary.error.is_empty(), "stream retains no full event array"):
		return false
	var data := SimTrace.read_recording(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not _check(data.get("events", []).size() == 230, "stream contains every event past retention window"):
		return false
	if not _replay_equal(sim, data, HALFPIPE):
		return false
	for field in ["version", "model_hash", "event_count", "engine_version"]:
		var broken := data.duplicate(true)
		broken[field] = _changed(broken[field])
		if not _check(not SimTrace.replay(broken, _sim()).get("ok", false), "reject incompatible " + field):
			return false
	var broken := data.duplicate(true)
	broken.events[0].input.erase("ollie_just_released")
	if not _check(not SimTrace.replay(broken, _sim()).get("ok", false), "reject incomplete action input"):
		return false
	broken = data.duplicate(true)
	broken.events[0].input.ollie_pressed = true
	return _check(not SimTrace.replay(broken, _sim()).get("ok", false), "detect changed gameplay input")


func _bounded_history() -> bool:
	var sim := _sim()
	for _i in range(400):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	var frames := sim.trace.frames
	var expected := mini(sim.trace.capacity, 401)
	if not _check(frames.size() == expected and sim.trace.total_ticks == 400, "bounded ring and total ticks"):
		return false
	if expected > 0 and not _check(frames[0].index == 401 - expected and frames[-1].index == 400,
			"ring retains chronological recent window"):
		return false
	if not _check(sim.trace.replay_hashes().size() == expected and sim.trace.final_hash() == sim.gameplay_hash(),
			"retained replay hashes and on-demand final hash"):
		return false
	sim.trace.capacity = 0
	sim.tick()
	return _check(sim.trace.frames.is_empty() and sim.trace.final_hash() == sim.gameplay_hash(),
		"disabled trace serializes no tick snapshots but retains final_hash API")


func _recording_boundary() -> bool:
	var sim := _sim()
	sim.start_recording()
	sim.tick()
	var tick := sim.state.tick
	sim.set_input(Vector2.RIGHT, false, false, true)
	sim.accel += 1.0
	var recording := sim.stop_recording()
	if not _check(sim.state.tick == tick and recording.events[-1].kind == "input",
			"stop preserves pending input/tuning without a physics step"):
		return false
	if not _replay_equal(sim, recording, HALFPIPE):
		return false
	var envelope: Dictionary = JSON.parse_string(SimSnapshot.encode(sim.gameplay_snapshot()))
	envelope.data = "AAAA"
	if not _check(SimSnapshot.decode(JSON.stringify(envelope)).is_empty(), "reject corrupted transport before Variant decoding"):
		return false
	envelope.data_sha256 = str(envelope.data).sha256_text()
	return _check(SimSnapshot.decode(JSON.stringify(envelope)).is_empty(), "reject truncated Variant data without engine errors")


func _memory_soak() -> bool:
	for moving in [false, true]:
		var sim := _sim()
		# Gentle alternating control stays on the spawn floor for the entire run.
		sim.accel = 10.0
		sim.max_speed = 10.0
		var before := OS.get_static_memory_usage()
		var warm := before
		var middle := before
		for i in range(36000):
			var control := Vector2(0.1 if i % 120 < 60 else -0.1, 0.0) if moving else Vector2.ZERO
			sim.set_input(control, false, false)
			sim.tick()
			if i == 599:
				warm = OS.get_static_memory_usage()
			if i == 17999:
				middle = OS.get_static_memory_usage()
		var after := OS.get_static_memory_usage()
		print("SIM_TRACE_SOAK ", JSON.stringify({
			"moving": moving, "ticks": 36000, "frames": sim.trace.frames.size(),
			"initial_growth_bytes": after - before, "after_warmup_growth_bytes": after - warm,
			"second_half_growth_bytes": after - middle,
		}))
		if not _check(sim.trace.frames.size() <= SimTrace.RECENT_FRAME_LIMIT
				and absi(after - warm) < 1048576 and absi(after - middle) < 1048576,
				"36,000 tick retention/memory plateau"):
			return false
	return true
