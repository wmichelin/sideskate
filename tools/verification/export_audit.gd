extends SceneTree
## Run from an empty project so loose checkout files cannot conceal omissions.

var checks: Array = []
var files: PackedStringArray = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		print("Expected package path and report path")
		quit(1)
		return
	_check("package_mounted", ProjectSettings.load_resource_pack(args[0]))
	_scan("res://")
	for path in ["res://levels/layers.ssk", "res://levels/offset_demo.ssk"]:
		_check("packaged:" + path, FileAccess.file_exists(path) and not FileAccess.get_file_as_string(path).is_empty())
	for path in ["res://scenes/start_menu.tscn", "res://scenes/main.tscn", "res://assets/fonts/DejaVuSans.ttf", "res://assets/fonts/DejaVuSans-Bold.ttf", "res://assets/characters/ssk_skater.glb"]:
		_check("packaged:" + path, ResourceLoader.exists(path))
	for directory in ["res://tests/", "res://tools/", "res://debug_levels/", "res://docs/", "res://artifacts/", "res://art/"]:
		_check("excluded:" + directory, Array(files).filter(func(path): return path.begins_with(directory)).is_empty())
	var failed := checks.filter(func(item): return not item.ok).size()
	var report := {"schema_version": 1, "completed": true, "checks": checks, "check_count": checks.size(), "failed": failed, "errors": [], "files": files}
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("PACKAGE_COMPLETE ", JSON.stringify({"checks": checks.size(), "failed": failed}))
	quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool) -> void:
	checks.append({"name": label, "ok": ok})
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _scan(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		files.append(path.path_join(file))
	for child in directory.get_directories():
		_scan(path.path_join(child))
