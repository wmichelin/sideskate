extends RefCounted
## Route touches through the viewport and physical devices through InputMap.

var _tree: SceneTree
var _host: Node
var _touch: TouchControls
var _pause: CanvasLayer
var _old_size: Vector2i
var _old_accumulated: bool


func cases() -> Array:
	return ["pause_cancels_and_resumes", "touch_restores_after_gamepad", "cancel_preserves_physical_input", "focus_and_visibility_cancel", "teardown_releases_owned_actions"]


func run() -> bool:
	var ok := true
	for test in cases():
		ok = bool(call(test)) and ok
	return ok


func _setup() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_old_size = _tree.root.size
	_old_accumulated = Input.use_accumulated_input
	_tree.root.size = Vector2i(1280, 720)
	Input.use_accumulated_input = false
	PlatformCaps.mobile_os_override = true
	_host = Node.new()
	_tree.root.add_child(_host)
	_pause = load("res://scenes/pause_menu.tscn").instantiate()
	_host.add_child(_pause)
	_touch = load("res://scenes/touch_controls.tscn").instantiate()
	_host.add_child(_touch)


func _teardown() -> void:
	_tree.paused = false
	_host.free()
	_tree.root.size = _old_size
	Input.use_accumulated_input = _old_accumulated
	PlatformCaps.clear_overrides()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
	return ok


func _finger(control: String, down: bool, index: int = 0, offset := Vector2.ZERO) -> void:
	var node := _touch.get_node("%" + control) as Control
	var event := InputEventScreenTouch.new()
	event.position = node.get_global_rect().get_center() + offset
	event.pressed = down
	event.index = index
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.keycode = KEY_D
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _pad(down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func pause_cancels_and_resumes() -> bool:
	_setup()
	_finger("StickBase", true, 0, Vector2(100, 0))
	var ok := _check(Input.get_action_strength("move_right") > 0.5, "Real touch must engage the stick")
	_finger("OllieButton", true, 1)
	ok = _check(Input.is_action_pressed("ollie"), "Second finger must hold ollie alongside the stick") and ok
	# Pause button uses real GUI routing; no manufactured player state.
	_finger("PauseButton", true, 2)
	_finger("PauseButton", false, 2)
	_touch._process(0.0)
	ok = _check(_tree.paused and not _touch.is_overlay_active(), "Touch pause must hide gameplay controls") and ok
	_finger("StickBase", false, 0)
	_finger("OllieButton", false, 1)
	ok = _check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("ollie"), "Pausing must cancel held virtual actions before resume") and ok
	_pause.close_pause()
	_touch._process(0.0)
	_finger("StickBase", true, 0, Vector2(100, 0))
	ok = _check(Input.get_action_strength("move_right") > 0.5, "Fresh touch must work after resume") and ok
	_finger("StickBase", false)
	_teardown()
	return ok


func touch_restores_after_gamepad() -> bool:
	_setup()
	# Advance only the activity guard, retaining real event routing.
	_touch._joypad_hide_armed_msec = 0
	_pad(true)
	var ok := _check(not _touch.is_overlay_active(), "Controller input must hide touch controls")
	_pad(false)
	_finger("StickBase", true, 0, Vector2(100, 0))
	ok = _check(_touch.is_overlay_active() and Input.get_action_strength("move_right") > 0.5, "Deliberate touch must restore controls after gamepad use") and ok
	_finger("StickBase", false)
	_teardown()
	return ok


func cancel_preserves_physical_input() -> bool:
	_setup()
	_key(true)
	_finger("StickBase", true, 0, Vector2(100, 0))
	_finger("StickBase", false)
	var ok := _check(Input.is_action_pressed("move_right"), "Touch release must preserve held keyboard action on the same axis")
	_finger("StickBase", true, 0, Vector2(100, 0))
	_finger("OllieButton", true, 1)
	_touch._joypad_hide_armed_msec = 0
	_pad(true)
	ok = _check(Input.is_action_pressed("ollie") and Input.is_action_pressed("move_right"), "Gamepad takeover must retain both physical holds when cancelling virtual stick and ollie") and ok
	_key(false)
	_pad(false)
	_finger("StickBase", false, 0)
	_finger("OllieButton", false, 1)
	ok = _check(not Input.is_action_pressed("ollie") and not Input.is_action_pressed("move_right"), "Final physical releases must leave actions neutral") and ok
	_teardown()
	return ok


func focus_and_visibility_cancel() -> bool:
	_setup()
	_finger("StickBase", true, 0, Vector2(100, 0))
	_touch.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var ok := _check(not Input.is_action_pressed("move_right"), "Focus loss must release touch movement")
	_finger("StickBase", true, 1, Vector2(100, 0))
	ok = _check(not Input.is_action_pressed("move_right"), "Unfocused controls must ignore new touches") and ok
	_finger("StickBase", false, 1)
	_finger("StickBase", false, 0)
	_touch.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	_finger("OllieButton", true)
	_touch.hide()
	ok = _check(not Input.is_action_pressed("ollie"), "Hiding overlay must cancel virtual ollie") and ok
	_finger("OllieButton", false)
	_teardown()
	return ok


func teardown_releases_owned_actions() -> bool:
	_setup()
	_key(true)
	_finger("StickBase", true, 0, Vector2(100, 0))
	_finger("TransferButton", true, 1)
	var held := Input.is_action_pressed("transfer")
	_host.remove_child(_touch)
	_touch.free()
	var ok := _check(held and Input.is_action_pressed("move_right") and not Input.is_action_pressed("transfer"), "Exiting overlay must clear owned input and retain held physical input")
	_key(false)
	_teardown()
	return ok
