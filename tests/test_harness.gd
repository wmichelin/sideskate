class_name TestHarness
extends RefCounted
## Shared async runner: drain deferred scene work, capture errors, report every case.

const Diagnostics = preload("res://tests/support/runtime_diagnostics.gd")


static func run_all() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var diagnostics = Diagnostics.new()
	diagnostics.start()
	var options := _options()
	var paths: PackedStringArray = []
	_collect_tests("res://tests", paths)
	paths.sort()
	var report := {
		"schema_version": 1, "completed": false, "discovered_suites": paths.size(),
		"check_count": 0, "failed": 0, "checks": [], "errors": [],
		"engine": Engine.get_version_info().string,
	}
	print("=== SideSkate tests (%d suites) ===" % paths.size())
	for path in paths:
		var filter_text: String = options.get("test", "")
		if filter_text.ends_with(".gd") and not filter_text in path:
			continue
		diagnostics.begin_scope()
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			_add_result(report, path, false, [{"message": "Script cannot be instantiated"}])
			continue
		var inst = script.new()
		if inst == null or not inst.has_method("run"):
			_add_result(report, path, false, [{"message": "Missing run() -> bool"}])
			continue
		var methods: Array = ["run"]
		if inst.has_method("cases"):
			var declared: Variant = inst.call("cases")
			if not declared is Array and not declared is PackedStringArray:
				_add_result(report, path, false, [{"message": "cases() must return an array of method names"}])
				continue
			methods.assign(declared)
			if methods.is_empty():
				_add_result(report, path, false, [{"message": "cases() returned no test cases"}])
		var seen := {}
		for method in methods:
			var name := "%s::%s" % [path, method]
			if not filter_text.is_empty() and not filter_text in name:
				continue
			if (not method is String and not method is StringName) or not inst.has_method(method) or seen.has(method):
				_add_result(report, name, false, [{"message": "Invalid, missing or duplicate test method"}])
				continue
			seen[method] = true
			var expected: Dictionary = inst.call("expected_errors") if inst.has_method("expected_errors") else {}
			diagnostics.begin_scope(expected)
			var result: Variant = inst.call(method)
			# Resolve queue_free and deferred callbacks before judging the case.
			await tree.process_frame
			await tree.process_frame
			var errors: Array = diagnostics.failures()
			_add_result(report, name, typeof(result) == TYPE_BOOL and result == true and errors.is_empty(), errors)
		if inst is Node:
			inst.free()
		inst = null
	if int(report.check_count) == 0:
		report.errors.append("No matching test cases discovered")
	if diagnostics.unexpected_count() > 0:
		report.errors.append("%d unexpected runtime diagnostics" % diagnostics.unexpected_count())
	report["diagnostics"] = diagnostics.entries.duplicate(true)
	report.completed = true
	var report_path: String = options.get("report", "res://artifacts/checks/tests/report.json")
	var absolute := ProjectSettings.globalize_path(report_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		report.errors.append("Cannot write report: %s" % absolute)
	else:
		var encoded := JSON.stringify(report, "\t")
		file.store_string(encoded)
		file.flush()
		if file.get_error() != OK or file.get_length() != encoded.to_utf8_buffer().size():
			report.errors.append("Cannot finish report: %s" % absolute)
		file.close()
	diagnostics.stop()
	var failed: int = report.failed
	print("=== %d passed, %d failed ===" % [int(report.check_count) - failed, failed])
	print("SIDESKATE_TESTS_COMPLETE %s" % JSON.stringify({"checks": report.check_count, "failed": failed, "errors": report.errors}))
	return 0 if failed == 0 and report.errors.is_empty() else 1


static func _add_result(report: Dictionary, name: String, ok: bool, errors: Array) -> void:
	report.check_count += 1
	if not ok:
		report.failed += 1
	report.checks.append({"name": name, "ok": ok, "errors": errors})
	print("%s  %s" % ["PASS" if ok else "FAIL", name])


static func _options() -> Dictionary:
	var out := {}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] in ["--report", "--test"] and i + 1 < args.size():
			out[args[i].trim_prefix("--")] = args[i + 1]
			i += 2
		else:
			i += 1
	return out


static func _collect_tests(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			_collect_tests(dir_path.path_join(name), out)
		elif name.begins_with("test_") and name.ends_with(".gd") and name not in ["test_runner.gd", "test_runner_scene.gd", "test_harness.gd"]:
			out.append(dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
