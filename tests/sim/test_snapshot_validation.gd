extends RefCounted
## Invalid transported numbers must not poison live state or shared tuning.

const LEVEL := "res://tests/levels/sim/sim_halfpipe.ssk"


func cases() -> Array:
	return ["snapshot_numbers", "tuning_numbers", "replay_numbers", "valid_sentinel"]


func run() -> bool:
	return snapshot_numbers() and tuning_numbers() and replay_numbers() and valid_sentinel()


func _sim() -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(FileAccess.get_file_as_string(LEVEL), "snapshot_validation"):
		return null
	return sim


func _check(ok: bool, detail: String) -> bool:
	if not ok:
		print("SNAPSHOT_VALIDATION_FAILED " + detail)
	return ok


func snapshot_numbers() -> bool:
	var sim := _sim()
	if sim == null:
		return false
	var original := sim.gameplay_snapshot()
	var original_hash := SimSnapshot.digest(original)
	var paths := [
		["state", "position"], ["state", "velocity"], ["state", "tangent_velocity"],
		["state", "u"], ["state", "facing_yaw"], ["state", "air_peak_height"],
		["state", "maneuver", "start_velocity"], ["state", "maneuver", "elapsed"],
		["sim", "checkpoint_position"], ["sim", "checkpoint_history", 0, "position"],
		["sim", "ollie_charge"], ["sim", "transfer_hold_eligible"],
		["input", "last_wish"], ["tuning", "player", "accel"],
		["tuning", "global", "GRAVITY"],
	]
	for path in paths:
		for invalid in [NAN, INF, -INF]:
			if path == ["state", "air_peak_height"] and invalid == -INF:
				continue
			var changed := original.duplicate(true)
			changed.state.maneuver = ManeuverPlan.new().to_dict()
			var parent: Variant = changed
			for key in path.slice(0, -1):
				parent = parent[key]
			var field: Variant = path[-1]
			var value: Variant = parent[field]
			var components := 3 if value is Vector3 else (2 if value is Vector2 else 1)
			for component in range(components):
				var replacement: Variant = value
				if replacement is Vector2 or replacement is Vector3:
					replacement[component] = invalid
				else:
					replacement = invalid
				parent[field] = replacement
				var accepted := sim.restore_snapshot(changed)
				var unchanged := SimSnapshot.digest(sim.gameplay_snapshot()) == original_hash
				# Restore even on a failing implementation, so globals cannot leak.
				sim.restore_snapshot(original)
				if not _check(not accepted and unchanged, "%s[%d]=%s must reject atomically" % [path, component, invalid]):
					return false
	return true


func tuning_numbers() -> bool:
	var sim := _sim()
	if sim == null:
		return false
	var original := sim.tuning_snapshot()
	var original_hash := SimSnapshot.digest(sim.gameplay_snapshot())
	for group in original:
		for field in original[group]:
			if not original[group][field] is float:
				continue
			for invalid in [NAN, INF, -INF]:
				var changed := original.duplicate(true)
				changed[group][field] = invalid
				var accepted := sim.apply_tuning(changed)
				var unchanged := SimSnapshot.digest(sim.gameplay_snapshot()) == original_hash
				sim.apply_tuning(original)
				if not _check(not accepted and unchanged, "tuning %s.%s must reject atomically" % [group, field]):
					return false
	return true


func replay_numbers() -> bool:
	var source := _sim()
	if source == null or not source.start_recording():
		return false
	source.set_input(Vector2.RIGHT, false, false)
	source.tick()
	var recording := source.stop_recording()
	for field in ["initial", "input", "tuning", "delta"]:
		var invalid_values := [NAN, INF, -INF, 0.0, -0.1] if field == "delta" else [NAN, INF, -INF]
		for invalid in invalid_values:
			var changed := recording.duplicate(true)
			match field:
				"initial": changed.initial.state.position.x = invalid
				"input": changed.events[0].input.last_wish.y = invalid
				"tuning": changed.events[0].tuning.global.GRAVITY = invalid
				"delta": changed.events[0].delta = invalid
			var target := _sim()
			var before := SimSnapshot.digest(target.gameplay_snapshot())
			var result := SimTrace.replay(changed, target)
			if not _check(not bool(result.get("ok", false)) and not str(result.get("error", "")).is_empty(),
					"replay must report invalid " + field):
				return false
			if not _check(SimSnapshot.digest(target.gameplay_snapshot()) == before,
					"invalid first replay event must not mutate input/state/tuning: " + field):
				return false
	var unknown := recording.duplicate(true)
	unknown.events[0].kind = "unrecognized"
	var target := _sim()
	var before := SimSnapshot.digest(target.gameplay_snapshot())
	var result := SimTrace.replay(unknown, target)
	return _check(not bool(result.get("ok", false)) and result.get("error") == "Unknown recording command"
		and SimSnapshot.digest(target.gameplay_snapshot()) == before, "unknown replay command must reject before input mutation")


func valid_sentinel() -> bool:
	var sim := _sim()
	if sim == null:
		return false
	var source := sim.gameplay_snapshot()
	var transported := SimSnapshot.decode(SimSnapshot.encode(source))
	if not _check(sim.restore_snapshot(transported) and sim.state.air_peak_height == -INF,
			"documented negative infinity sentinel must survive transport and restore"):
		return false
	if not _check(SimSnapshot.digest(sim.gameplay_snapshot()) == SimSnapshot.digest(source),
			"valid round trip preserves every snapshot field"):
		return false
	# Zero gravity is valid tuning used by deterministic analytical fixtures.
	var tuning := sim.tuning_snapshot()
	var zero := tuning.duplicate(true)
	zero.global.GRAVITY = 0.0
	var accepted := sim.apply_tuning(zero)
	sim.apply_tuning(tuning)
	return _check(accepted, "finite tuning is not subjected to speculative ranges")
