extends Control
## Start menu: splash title + one button per .ssk in res://levels/.
## Files whose names start with `_` (e.g. `_template.ssk`) are skipped.

const LEVELS_DIR := "res://levels"

@onready var _list: VBoxContainer = %LevelList
@onready var _status: Label = %StatusLabel


func _ready() -> void:
	_populate_levels()


func _populate_levels() -> void:
	for child in _list.get_children():
		child.queue_free()

	var paths := _scan_level_paths()
	if paths.is_empty():
		_status.text = "No levels found in res://levels/"
		return

	_status.text = "Select a level"
	var style_normal := _make_button_style(Color(0.14, 0.16, 0.18, 0.95), Color(0.85, 0.55, 0.28, 0.55))
	var style_hover := _make_button_style(Color(0.22, 0.18, 0.12, 0.98), Color(0.95, 0.65, 0.3, 0.9))
	for path in paths:
		var display := _display_name_for(path)
		var btn := Button.new()
		btn.text = display
		btn.custom_minimum_size = Vector2(420, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)
		btn.add_theme_stylebox_override("focus", style_hover)
		btn.pressed.connect(_on_level_pressed.bind(path))
		_list.add_child(btn)


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


func _scan_level_paths() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		push_error("StartMenu: cannot open %s" % LEVELS_DIR)
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if (
			not dir.current_is_dir()
			and file_name.ends_with(".ssk")
			and not file_name.begins_with("_")
		):
			out.append("%s/%s" % [LEVELS_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


func _display_name_for(path: String) -> String:
	var spec: LevelSpec = LevelLoader.load_path(path)
	if spec != null and spec.name != "":
		return spec.name
	return path.get_file().get_basename()


func _on_level_pressed(path: String) -> void:
	_status.text = "Loading…"
	GameSession.play_level(path)
