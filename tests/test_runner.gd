extends SceneTree
## Headless: godot4 --headless --path . --script res://tests/test_runner.gd

const Harness = preload("res://tests/test_harness.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	quit(Harness.run_all())
