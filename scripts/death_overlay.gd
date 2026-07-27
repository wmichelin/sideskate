extends CanvasLayer
## Full-screen death flash (display only). Calls `on_done` after hold.

signal finished

@export var hold_seconds: float = 1.25

var _veil: ColorRect
var _label: Label
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui()
	visible = true


func _ensure_ui() -> void:
	if _veil != null:
		return
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(0.75, 0.02, 0.02, 0.92)
	_veil.visible = false
	add_child(_veil)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 48)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_label.text = "you're dead"
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Show red veil + message, wait, hide, emit finished.
func play() -> void:
	if _busy:
		return
	_ensure_ui()
	_busy = true
	_veil.visible = true
	_label.visible = true
	await get_tree().create_timer(hold_seconds).timeout
	_veil.visible = false
	_label.visible = false
	_busy = false
	finished.emit()
