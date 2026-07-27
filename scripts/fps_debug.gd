extends CanvasLayer
## Bottom-left FPS readout. Display-only; gated by DebugTools.show_fps.

@onready var _label: Label = $Label


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return
	layer = 90
	_apply_visible(DebugTools.show_fps)
	if not DebugTools.show_fps_changed.is_connected(_apply_visible):
		DebugTools.show_fps_changed.connect(_apply_visible)


func _process(_delta: float) -> void:
	if not visible or _label == null:
		return
	_label.text = "%d FPS" % Engine.get_frames_per_second()


func _apply_visible(on: bool) -> void:
	visible = on
	set_process(on)
	if on and _label:
		_label.text = "%d FPS" % Engine.get_frames_per_second()
