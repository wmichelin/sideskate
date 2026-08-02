extends Node
## Holds cross-scene state for level selection and scene routing.

const GAMEPLAY_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/start_menu.tscn"

const _WEB_FULLSCREEN_JS := """
(function () {
	var el = document.getElementById('canvas') || document.body || document.documentElement;
	var req = el.requestFullscreen || el.webkitRequestFullscreen || el.msRequestFullscreen;
	if (req) {
		var p = req.call(el);
		if (p && typeof p.catch === 'function') p.catch(function () {});
	}
})()
"""

var pending_level_path: String = ""
var _web_fullscreen_done: bool = false


func _ready() -> void:
	if OS.has_feature("web"):
		# Best-effort at boot (usually blocked without a gesture).
		call_deferred("_try_web_fullscreen", false)


func _input(event: InputEvent) -> void:
	if _web_fullscreen_done or not OS.has_feature("web"):
		return
	var gesture := false
	if event is InputEventScreenTouch:
		gesture = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		gesture = (event as InputEventMouseButton).pressed
	if gesture:
		_try_web_fullscreen(true)


func play_level(path: String) -> void:
	_try_web_fullscreen(true)
	pending_level_path = path
	_change_scene_deferred(GAMEPLAY_SCENE)


func return_to_menu() -> void:
	pending_level_path = ""
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_change_scene_deferred(MENU_SCENE)


func _try_web_fullscreen(from_gesture: bool) -> void:
	if not OS.has_feature("web") or _web_fullscreen_done:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	JavaScriptBridge.eval(_WEB_FULLSCREEN_JS, true)
	# Browsers ignore fullscreen without a gesture; lock only after one.
	if from_gesture:
		_web_fullscreen_done = true


func _change_scene_deferred(scene_path: String) -> void:
	## Never swap scenes mid-input / mid-_ready; Escape and menu buttons both use this.
	var tree := get_tree()
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", scene_path)
