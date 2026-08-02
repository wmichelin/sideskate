extends CanvasLayer
## In-level pause overlay. Stops the scene tree; Escape toggles / backs out of Controls.

signal resumed
signal quit_to_menu

const CONTROLS_SCENE := preload("res://scenes/controls_panel.tscn")

@onready var _root: Control = %Root
@onready var _pause_box: VBoxContainer = %PauseBox
@onready var _resume: Button = %ResumeButton
@onready var _controls: Button = %ControlsButton
@onready var _quit: Button = %QuitButton

var _controls_panel: Control = null
var _open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	UiChrome.apply_menu_button(_resume)
	UiChrome.apply_menu_button(_controls)
	UiChrome.apply_menu_button(_quit)
	_resume.pressed.connect(close_pause)
	_controls.pressed.connect(_open_controls)
	_quit.pressed.connect(_on_quit)
	hide()


func is_open() -> bool:
	return _open


func open_pause() -> void:
	if _open:
		return
	_open = true
	_show_pause_root()
	show()
	_root.visible = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true
	_resume.grab_focus()


func close_pause() -> void:
	if not _open:
		return
	_close_controls_panel()
	_open = false
	_root.visible = false
	hide()
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	resumed.emit()


func toggle_pause() -> void:
	if _controls_panel != null and is_instance_valid(_controls_panel) and _controls_panel.visible:
		_close_controls_panel()
		_show_pause_root()
		_resume.grab_focus()
		return
	if _open:
		close_pause()
	else:
		open_pause()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	# Controls panel owns Esc while visible (Back).
	if _controls_panel != null and is_instance_valid(_controls_panel) and _controls_panel.visible:
		return
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		close_pause()
		get_viewport().set_input_as_handled()


func _show_pause_root() -> void:
	_pause_box.visible = true


func _open_controls() -> void:
	_pause_box.visible = false
	if _controls_panel == null or not is_instance_valid(_controls_panel):
		_controls_panel = CONTROLS_SCENE.instantiate() as Control
		_root.add_child(_controls_panel)
		_controls_panel.closed.connect(_on_controls_closed)
	_controls_panel.visible = true


func _on_controls_closed() -> void:
	_close_controls_panel()
	_show_pause_root()
	_controls.grab_focus()


func _close_controls_panel() -> void:
	if _controls_panel != null and is_instance_valid(_controls_panel):
		_controls_panel.visible = false


func _on_quit() -> void:
	_close_controls_panel()
	_open = false
	_root.visible = false
	hide()
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	quit_to_menu.emit()
