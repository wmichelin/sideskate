extends SceneTree
## Reconstruct the recordings emitted by the real Player input driver.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not source is Dictionary or not source.get("recordings") is Array:
		quit(1)
		return
	var checks: Array = []
	for entry in source.recordings:
		var sim := PlayerSim.new()
		var ok := sim.setup_from_text(FileAccess.get_file_as_string(entry.level), entry.level.get_file())
		var replay := SimTrace.replay(SimTrace.read_recording(entry.path), sim) if ok else {"ok": false, "error": "Invalid model"}
		checks.append({"name": entry.path, "ok": replay.get("ok", false), "events": replay.get("events", 0), "error": replay.get("error", "")})
		print("REPLAY_CHECK ", JSON.stringify(checks[-1]))
	var failed := checks.filter(func(item): return not item.ok).size()
	var report := {"completed": true, "checks": checks, "check_count": checks.size(), "failed": failed, "errors": []}
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	await process_frame
	await process_frame
	quit(0 if failed == 0 and not checks.is_empty() else 1)
