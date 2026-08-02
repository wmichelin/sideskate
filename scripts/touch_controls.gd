class_name TouchControls
extends CanvasLayer
## In-level virtual stick + action buttons. Feeds InputMap; PlayerSim unchanged.

const _PlatformCaps := preload("res://scripts/platform_caps.gd")

const STICK_DEADZONE := 0.15
const JOYPAD_MOTION_DEADZONE := 0.25
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const ACTION_OLLIE := &"ollie"
const ACTION_TRANSFER := &"transfer"

@export var pause_menu_path: NodePath = NodePath("../PauseMenu")

@onready var _root: Control = %Root
@onready var _pause_btn: Button = %PauseButton
@onready var _stick_base: Control = %StickBase
@onready var _stick_knob: Control = %StickKnob
@onready var _ollie_btn: Button = %OllieButton
@onready var _transfer_btn: Button = %TransferButton

var _pause_menu: Node = null
var _joypad_hidden: bool = false
## Ignore phantom gamepad noise briefly after the overlay appears (common on mobile Web).
var _joypad_hide_armed_msec: int = 0
var _stick_active: bool = false
var _stick_touch_index: int = -1
var _ollie_held: bool = false
var _transfer_held: bool = false
var _move_held := {
	"left": false,
	"right": false,
	"up": false,
	"down": false,
}


static func axes_from_stick(v: Vector2, deadzone: float = STICK_DEADZONE) -> Dictionary:
	var out := {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
	var length := v.length()
	if length <= deadzone:
		return out
	var n := v / length
	var mag := clampf((length - deadzone) / maxf(1.0 - deadzone, 0.0001), 0.0, 1.0)
	var scaled := n * mag
	if scaled.x < 0.0:
		out.left = -scaled.x
	elif scaled.x > 0.0:
		out.right = scaled.x
	# UI Y: negative = up → move_up
	if scaled.y < 0.0:
		out.up = -scaled.y
	elif scaled.y > 0.0:
		out.down = scaled.y
	return out


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu = get_node_or_null(pause_menu_path)
	_style_chrome()
	_pause_btn.pressed.connect(_on_pause_pressed)
	_ollie_btn.button_down.connect(func() -> void: _set_action(ACTION_OLLIE, true))
	_ollie_btn.button_up.connect(func() -> void: _set_action(ACTION_OLLIE, false))
	_transfer_btn.button_down.connect(func() -> void: _set_action(ACTION_TRANSFER, true))
	_transfer_btn.button_up.connect(func() -> void: _set_action(ACTION_TRANSFER, false))
	_stick_base.gui_input.connect(_on_stick_gui_input)
	_apply_safe_area()
	_refresh_visibility()


func _exit_tree() -> void:
	_clear_all_actions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_all_actions()
		_reset_stick_visual()


func _process(_delta: float) -> void:
	# Re-evaluate every tick: web probes / touchscreen can become true after load,
	# and CanvasLayer.visible must flip (not only Root).
	if _joypad_hidden:
		return
	_refresh_visibility()


func _input(event: InputEvent) -> void:
	# Even while hidden: first finger down on Web unlocks the overlay.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_PlatformCaps.note_screen_touch()
		if not _joypad_hidden:
			_refresh_visibility()
	if not is_overlay_active():
		return
	if Time.get_ticks_msec() < _joypad_hide_armed_msec:
		return
	if event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed:
			_hide_for_joypad()
			return
	# Motion-only hide is desktop/pad; mobile Web often emits noisy axes.
	if event is InputEventJoypadMotion and not OS.has_feature("web"):
		var jm := event as InputEventJoypadMotion
		if absf(jm.axis_value) >= JOYPAD_MOTION_DEADZONE:
			_hide_for_joypad()


func is_overlay_active() -> bool:
	return visible and _root != null and _root.visible and not _joypad_hidden


func force_show_for_test() -> void:
	_joypad_hidden = false
	visible = true
	_root.visible = true


func apply_stick_for_test(v: Vector2) -> void:
	_apply_stick_vector(v)


func notify_joypad_activity_for_test() -> void:
	_hide_for_joypad()


func _refresh_visibility() -> void:
	var show_overlay: bool = _PlatformCaps.should_show_touch_controls() and not _joypad_hidden
	if show_overlay and not visible:
		_joypad_hide_armed_msec = Time.get_ticks_msec() + 1500
	visible = show_overlay
	_root.visible = show_overlay and not _is_pause_open()
	if not show_overlay:
		_clear_all_actions()
		_reset_stick_visual()


func _hide_for_joypad() -> void:
	_joypad_hidden = true
	_clear_all_actions()
	_reset_stick_visual()
	_root.visible = false
	visible = false


func _is_pause_open() -> bool:
	if _pause_menu == null:
		return false
	if _pause_menu.has_method("is_open"):
		return bool(_pause_menu.call("is_open"))
	return false


func _on_pause_pressed() -> void:
	if _pause_menu != null and _pause_menu.has_method("open_pause"):
		_pause_menu.call("open_pause")


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0:
		return
	var left := maxi(0, safe.position.x)
	var top := maxi(0, safe.position.y)
	var right := maxi(0, win.x - (safe.position.x + safe.size.x))
	var bottom := maxi(0, win.y - (safe.position.y + safe.size.y))
	_root.offset_left = float(left)
	_root.offset_top = float(top)
	_root.offset_right = float(-right)
	_root.offset_bottom = float(-bottom)


func _on_stick_gui_input(event: InputEvent) -> void:
	if not is_overlay_active():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_stick_active = true
			_stick_touch_index = st.index
			_update_stick_from_local(st.position)
		elif st.index == _stick_touch_index:
			_stick_active = false
			_stick_touch_index = -1
			_apply_stick_vector(Vector2.ZERO)
			_reset_stick_visual()
		_stick_base.accept_event()
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _stick_active and sd.index == _stick_touch_index:
			_update_stick_from_local(sd.position)
			_stick_base.accept_event()
		return
	# Mouse fallback for editor / forced desktop tests
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_stick_active = true
			_stick_touch_index = -2
			_update_stick_from_local(mb.position)
		elif _stick_touch_index == -2:
			_stick_active = false
			_stick_touch_index = -1
			_apply_stick_vector(Vector2.ZERO)
			_reset_stick_visual()
		_stick_base.accept_event()
		return
	if event is InputEventMouseMotion and _stick_active and _stick_touch_index == -2:
		var mm := event as InputEventMouseMotion
		_update_stick_from_local(mm.position)
		_stick_base.accept_event()


func _update_stick_from_local(local_pos: Vector2) -> void:
	var center := _stick_base.size * 0.5
	var radius := minf(center.x, center.y) * 0.85
	if radius <= 1.0:
		return
	var delta := local_pos - center
	var clamped := delta.limit_length(radius)
	_stick_knob.position = center + clamped - _stick_knob.size * 0.5
	_apply_stick_vector(clamped / radius)


func _apply_stick_vector(v: Vector2) -> void:
	var axes := axes_from_stick(v)
	_set_move_axis(MOVE_LEFT, float(axes.left), "left")
	_set_move_axis(MOVE_RIGHT, float(axes.right), "right")
	_set_move_axis(MOVE_UP, float(axes.up), "up")
	_set_move_axis(MOVE_DOWN, float(axes.down), "down")


func _set_move_axis(action: StringName, strength: float, key: String) -> void:
	if strength > 0.001:
		Input.action_press(action, strength)
		_move_held[key] = true
	elif _move_held[key]:
		Input.action_release(action)
		_move_held[key] = false


func _set_action(action: StringName, down: bool) -> void:
	if action == ACTION_OLLIE:
		if down == _ollie_held:
			return
		_ollie_held = down
	elif action == ACTION_TRANSFER:
		if down == _transfer_held:
			return
		_transfer_held = down
	else:
		return
	if down:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _clear_all_actions() -> void:
	for key in _move_held.keys():
		if _move_held[key]:
			var action: StringName
			match key:
				"left":
					action = MOVE_LEFT
				"right":
					action = MOVE_RIGHT
				"up":
					action = MOVE_UP
				"down":
					action = MOVE_DOWN
				_:
					continue
			Input.action_release(action)
			_move_held[key] = false
	if _ollie_held:
		Input.action_release(ACTION_OLLIE)
		_ollie_held = false
	if _transfer_held:
		Input.action_release(ACTION_TRANSFER)
		_transfer_held = false
	_stick_active = false
	_stick_touch_index = -1


func _reset_stick_visual() -> void:
	if _stick_base == null or _stick_knob == null:
		return
	var center := _stick_base.size * 0.5
	_stick_knob.position = center - _stick_knob.size * 0.5


func _style_chrome() -> void:
	_style_hit_button(_pause_btn, 18)
	_style_hit_button(_ollie_btn, 20)
	_style_hit_button(_transfer_btn, 16)
	_stick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.13, 0.15, 0.35)))
	_stick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.95, 0.65, 0.3, 0.55)))


func _style_hit_button(btn: Button, font_size: int) -> void:
	var normal := _panel_style(Color(0.14, 0.16, 0.18, 0.55))
	var pressed := _panel_style(Color(0.95, 0.65, 0.3, 0.55))
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", pressed)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88, 0.95))


func _panel_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	s.content_margin_left = 8
	s.content_margin_top = 8
	s.content_margin_right = 8
	s.content_margin_bottom = 8
	return s
