class_name TestHarness
extends RefCounted
## Shared discovery + execution for CLI (--script) and TestRunner.tscn (F6).


static func run_all() -> int:
	var failed := 0
	var passed := 0
	var paths: PackedStringArray = []
	_collect_tests("res://tests", paths)
	paths.sort()
	if paths.is_empty():
		push_error("No test_*.gd files found under res://tests")
		return 1

	print("=== SideSkate tests (%d) ===" % paths.size())
	for path in paths:
		var script: GDScript = load(path) as GDScript
		if script == null:
			push_error("FAIL load: %s" % path)
			failed += 1
			continue
		var inst = script.new()
		if not inst.has_method("run"):
			push_error("FAIL %s: missing run() -> bool" % path)
			failed += 1
			continue
		var ok: bool = inst.run()
		if ok:
			print("PASS  %s" % path.get_file())
			passed += 1
		else:
			push_error("FAIL  %s" % path.get_file())
			failed += 1

	print("=== %d passed, %d failed ===" % [passed, failed])
	return 0 if failed == 0 else 1


static func _collect_tests(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_collect_tests(full, out)
		elif (
			name.begins_with("test_")
			and name.ends_with(".gd")
			and name != "test_runner.gd"
			and name != "test_runner_scene.gd"
			and name != "test_harness.gd"
		):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
