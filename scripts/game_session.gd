extends Node
## Holds cross-scene state for level selection.

var pending_level_path: String = ""


func play_level(path: String) -> void:
	pending_level_path = path
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func return_to_menu() -> void:
	pending_level_path = ""
	get_tree().change_scene_to_file("res://scenes/start_menu.tscn")
