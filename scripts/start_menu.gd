extends Control
## Start menu: splash title + buttons for .ssk in res://levels/.
## In debug mode, also lists res://debug_levels/ after the playable set.
## Files whose names start with `_` (e.g. `_template.ssk`) are skipped.
## Arrow / WASD moves focus; Enter selects; list scrolls with focus.

const LEVELS_DIR := "res://levels"
const DEBUG_LEVELS_DIR := "res://debug_levels"

@onready var _list: VBoxContainer = %LevelList
@onready var _scroll: ScrollContainer = %LevelScroll
@onready var _status: Label = %StatusLabel

var _buttons: Array[Button] = []


func _ready() -> void:
	_populate_levels()


func _input(event: InputEvent) -> void:
	if _buttons.is_empty():
		return
	if event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		_move_focus(1)
		get_viewport().set_input_as_handled()


func _is_key(event: InputEvent, keycode: Key) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var k := event as InputEventKey
	return k.keycode == keycode or k.physical_keycode == keycode


func _move_focus(delta: int) -> void:
	if _buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var idx := 0
	if focused is Button:
		var found := _buttons.find(focused as Button)
		if found >= 0:
			idx = found
	var next := (idx + delta) % _buttons.size()
	if next < 0:
		next += _buttons.size()
	_buttons[next].grab_focus()


func _debug_levels_enabled() -> bool:
	return DebugTools != null and DebugTools.available


func _populate_levels() -> void:
	for child in _list.get_children():
		child.free()
	_buttons.clear()

	var style_normal := _make_button_style(Color(0.14, 0.16, 0.18, 0.95), Color(0.85, 0.55, 0.28, 0.55))
	var style_hover := _make_button_style(Color(0.22, 0.18, 0.12, 0.98), Color(0.95, 0.65, 0.3, 0.9))

	var paths := _scan_level_paths(LEVELS_DIR)
	if _debug_levels_enabled():
		paths.append_array(_scan_level_paths(DEBUG_LEVELS_DIR))
	if paths.is_empty():
		_status.text = "No levels found in res://levels/"
		return

	_status.text = "Select a level  ·  ↑↓ / WS  ·  Enter"
	for path in paths:
		_add_level_button(path, _display_name_for(path), style_normal, style_hover)

	if not _buttons.is_empty():
		_buttons[0].grab_focus()
		if not _scroll.follow_focus:
			_scroll.follow_focus = true


func _add_level_button(
	path: String,
	display: String,
	style_normal: StyleBoxFlat,
	style_hover: StyleBoxFlat
) -> void:
	var btn := Button.new()
	btn.text = display
	btn.custom_minimum_size = Vector2(420, 48)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.pressed.connect(_on_level_pressed.bind(path))
	_list.add_child(btn)
	_buttons.append(btn)


func _make_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_top = 10
	s.content_margin_right = 16
	s.content_margin_bottom = 10
	return s


func _scan_level_paths(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if (
			not dir.current_is_dir()
			and file_name.ends_with(".ssk")
			and not file_name.begins_with("_")
		):
			out.append("%s/%s" % [dir_path, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _display_name_for(path: String) -> String:
	if not FileAccess.file_exists(path):
		return path.get_file().get_basename()
	var text := FileAccess.get_file_as_bytes(path).get_string_from_utf8()
	if text.is_empty():
		return path.get_file().get_basename()
	var spec: LevelSpec = LevelLoader.parse_text(text, path.get_file().get_basename(), path)
	if spec != null and spec.name != "":
		return spec.name
	return path.get_file().get_basename()


func _on_level_pressed(path: String) -> void:
	_status.text = "Loading…"
	GameSession.play_level(path)
