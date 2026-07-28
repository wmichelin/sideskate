extends Node
## Holds cross-scene state for level selection and render backend routing.

enum RenderBackend { CANVAS_2D, WORLD_3D }

const SCENE_2D := "res://scenes/main.tscn"
const SCENE_3D := "res://scenes/main_3d.tscn"
const MENU_SCENE := "res://scenes/start_menu.tscn"

var pending_level_path: String = ""
var pending_backend: RenderBackend = RenderBackend.CANVAS_2D


func play_level(path: String, backend: RenderBackend = RenderBackend.CANVAS_2D) -> void:
	pending_level_path = path
	pending_backend = backend
	var scene := SCENE_3D if backend == RenderBackend.WORLD_3D else SCENE_2D
	_change_scene_deferred(scene)


func return_to_menu() -> void:
	pending_level_path = ""
	pending_backend = RenderBackend.CANVAS_2D
	_change_scene_deferred(MENU_SCENE)


func backend_for_path(path: String) -> RenderBackend:
	if path.begins_with("res://levels_3d/"):
		return RenderBackend.WORLD_3D
	return RenderBackend.CANVAS_2D


func paired_path(path: String) -> String:
	## Map 2D ↔ 3D twin by basename (levels/foo.ssk ↔ levels_3d/foo.ssk).
	var file := path.get_file()
	if path.begins_with("res://levels_3d/"):
		return "res://levels/%s" % file
	if path.begins_with("res://levels/"):
		return "res://levels_3d/%s" % file
	return path


func _change_scene_deferred(scene_path: String) -> void:
	## Never swap scenes mid-input / mid-_ready; Escape and menu buttons both use this.
	var tree := get_tree()
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", scene_path)
