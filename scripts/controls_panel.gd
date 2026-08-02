extends Control
## Full-screen Controls view. Emits `closed` when Back / Esc is used.

signal closed

@onready var _back: Button = %BackButton
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_rows()
	UiChrome.apply_menu_button(_back)
	_back.pressed.connect(_on_back)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _on_back() -> void:
	closed.emit()


func _populate_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for entry in ControlsCatalog.rows():
		var input_label := str(entry[0])
		var action_label := str(entry[1])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var left := Label.new()
		left.text = input_label
		left.custom_minimum_size = Vector2(200, 0)
		left.add_theme_color_override("font_color", Color(0.95, 0.6, 0.28, 0.95))
		left.add_theme_font_size_override("font_size", 18)
		var right := Label.new()
		right.text = action_label
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1))
		right.add_theme_font_size_override("font_size", 18)
		row.add_child(left)
		row.add_child(right)
		_rows.add_child(row)
