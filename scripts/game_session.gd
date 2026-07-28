extends Node
## Holds cross-scene state for level selection and scene routing.

const GAMEPLAY_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/start_menu.tscn"

var pending_level_path: String = ""


func play_level(path: String) -> void:
	pending_level_path = path
	_change_scene_deferred(GAMEPLAY_SCENE)


func return_to_menu() -> void:
	pending_level_path = ""
	_change_scene_deferred(MENU_SCENE)


func _change_scene_deferred(scene_path: String) -> void:
	## Never swap scenes mid-input / mid-_ready; Escape and menu buttons both use this.
	var tree := get_tree()
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", scene_path)
