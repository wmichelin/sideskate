extends Node
## F6 entry: open tests/TestRunner.tscn and press F6 (or set as main scene headless).

const Harness = preload("res://tests/test_harness.gd")


func _ready() -> void:
	var code := Harness.run_all()
	get_tree().quit(code)
