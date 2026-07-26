extends CanvasLayer
## Live readout of depth + surface (flat / pipe) state.
## Header collapses the body; starts collapsed.

@export var player_path: NodePath = NodePath("../Player")
@export var start_collapsed: bool = true

@onready var _panel: PanelContainer = $Panel
@onready var _header: Control = $Panel/VBox/Header
@onready var _title: Label = $Panel/VBox/Header/Title
@onready var _body: Label = $Panel/VBox/Body
@onready var _toggle: Button = $Panel/VBox/Header/Toggle

var _player: Node2D
var _collapsed: bool = true


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return
	_player = get_node_or_null(player_path) as Node2D
	_wire_header_toggle()
	_set_collapsed(start_collapsed)


func _wire_header_toggle() -> void:
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header.gui_input.connect(_on_header_gui_input)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle.pressed.connect(_on_toggle_pressed)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_toggle_pressed()
		_header.accept_event()



func _process(_delta: float) -> void:
	if _collapsed:
		return
	if _player == null or not _player.has_node("PseudoDepthBody"):
		_body.text = "No player / PseudoDepthBody"
		_fit_panel()
		return
	var depth: PseudoDepthBody = _player.get_node("PseudoDepthBody")
	var s := depth.debug_snapshot()
	var surface: Dictionary = {}
	if _player.get("last_surface") != null:
		surface = _player.last_surface
	var zone := str(surface.get("zone", "flat"))
	if _player.has_method("zone_debug_label"):
		zone = str(_player.call("zone_debug_label"))
	var pipe_angle := float(surface.get("angle", 0.0))
	_body.text = (
		"X: %.1f  (sx %.1f)\n" % [s.x, s.get("screen_x", s.x)]
		+ "Z: %.1f  (t=%.2f)\n" % [s.z, s.t]
		+ "Scale: %.3f\n" % s.scale
		+ "Screen Y: %.1f\n" % s.screen_y
		+ "z_index: %d\n" % s.z_index
		+ "Zone: %s\n" % zone
		+ "Surf H: %.1f (scr %.1f)\n" % [s.surface_height, s.get("surface_screen_h", 0.0)]
		+ "Pipe angle: %.1f deg\n" % pipe_angle
		+ _cell_debug_line()
		+ "WASD — Up = farther | Space = ollie | P/T = transfer↑ / acid↓ | G = god (j/k vert)"
	)
	_fit_panel()


func _on_toggle_pressed() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(on: bool) -> void:
	_collapsed = on
	_body.visible = not on
	_toggle.text = "▶" if on else "▼"
	call_deferred("_fit_panel")


func _fit_panel() -> void:
	if _panel == null:
		return
	var min_sz := _panel.get_combined_minimum_size()
	_panel.size = Vector2(maxf(min_sz.x, 200.0), min_sz.y)


func _cell_debug_line() -> String:
	if _player == null or not _player.has_node("PseudoDepthBody"):
		return ""
	var level := get_node_or_null("../RampLevel") as RampLevel
	if level == null or level.spec == null or level.spec.grid_w <= 0:
		return ""
	var cell: Vector2i
	if _player.has_method("cell_under_feet"):
		cell = _player.call("cell_under_feet") as Vector2i
	else:
		var body: PseudoDepthBody = _player.get_node("PseudoDepthBody")
		var lx: float = body.logical_x
		var lz: float = body.logical_z
		if _player.has_method("cell_sample_xz"):
			var xz: Vector2 = _player.call("cell_sample_xz")
			lx = xz.x
			lz = xz.y
		cell = level.spec.cell_at(lx, lz)
	return "Cell: col=%d row=%d (%.1f×%.1f)\n" % [
		cell.x, cell.y, level.spec.cell_w, level.spec.cell_h
	]
