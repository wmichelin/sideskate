extends RefCounted
## PlatformCaps override, stick→axis math, InputMap synthesis, joypad hide.


func run() -> bool:
	PlatformCaps.clear_overrides()
	PlatformCaps.mobile_os_override = true
	if not PlatformCaps.should_show_touch_controls():
		push_error("override true failed")
		return false
	PlatformCaps.mobile_os_override = false
	if PlatformCaps.should_show_touch_controls():
		push_error("override false failed")
		return false
	PlatformCaps.clear_overrides()

	# Web phone/tablet probe (itch HTML5) — no native mobile feature required.
	PlatformCaps.web_mobile_probe_override = true
	if not PlatformCaps._web_is_phone_or_tablet():
		push_error("web_mobile_probe_override true failed")
		return false
	PlatformCaps.web_mobile_probe_override = false
	if PlatformCaps._web_is_phone_or_tablet():
		push_error("web_mobile_probe_override false should not force true off-web")
		return false
	PlatformCaps.clear_overrides()
	PlatformCaps.note_screen_touch()
	# note_screen_touch alone is not enough off-web (feature gate); clear after.
	if PlatformCaps.should_show_touch_controls():
		# Desktop headless must stay false unless override/mobile.
		push_error("touch-seen should not show controls off-web")
		return false
	PlatformCaps.clear_overrides()

	var zero: Dictionary = TouchControls.axes_from_stick(Vector2.ZERO)
	if float(zero.left) != 0.0 or float(zero.right) != 0.0:
		push_error("zero stick should clear X")
		return false
	var dead: Dictionary = TouchControls.axes_from_stick(Vector2(0.1, 0.0), 0.15)
	if float(dead.right) != 0.0:
		push_error("inside deadzone should be zero")
		return false
	var right: Dictionary = TouchControls.axes_from_stick(Vector2(1, 0), 0.15)
	if float(right.right) < 0.99 or float(right.left) != 0.0:
		push_error("full right failed: %s" % right)
		return false
	var up: Dictionary = TouchControls.axes_from_stick(Vector2(0, -1), 0.15)
	if float(up.up) < 0.99:
		push_error("full up failed: %s" % up)
		return false

	var packed_touch: PackedScene = load("res://scenes/touch_controls.tscn")
	if packed_touch == null:
		push_error("touch_controls.tscn missing")
		return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	PlatformCaps.mobile_os_override = true
	var overlay: CanvasLayer = packed_touch.instantiate()
	tree.root.add_child(overlay)
	if not overlay.has_method("force_show_for_test"):
		push_error("missing force_show_for_test")
		_teardown(overlay)
		return false
	overlay.call("force_show_for_test")
	overlay.call("apply_stick_for_test", Vector2(1, 0))
	var axis_x := Input.get_axis("move_left", "move_right")
	if axis_x < 0.5:
		push_error("stick should press move_right, got axis=%s" % axis_x)
		_teardown(overlay)
		return false
	overlay.call("notify_joypad_activity_for_test")
	if bool(overlay.call("is_overlay_active")):
		push_error("overlay should hide after joypad activity")
		_teardown(overlay)
		return false
	var axis_after := Input.get_axis("move_left", "move_right")
	if absf(axis_after) > 0.01:
		push_error("axes should clear after joypad hide, got %s" % axis_after)
		_teardown(overlay)
		return false
	_teardown(overlay)

	var packed_main: PackedScene = load("res://scenes/main.tscn")
	if packed_main == null:
		push_error("main.tscn missing")
		return false
	GameSession.pending_level_path = "res://levels/layers.ssk"
	var main: Node = packed_main.instantiate()
	tree.root.add_child(main)
	var touch := main.get_node_or_null("TouchControls")
	if touch == null:
		push_error("TouchControls missing from main.tscn")
		main.queue_free()
		GameSession.pending_level_path = ""
		PlatformCaps.clear_overrides()
		return false
	main.queue_free()
	GameSession.pending_level_path = ""
	PlatformCaps.clear_overrides()
	return true


func _teardown(overlay: Node) -> void:
	if overlay != null and overlay.has_method("_clear_all_actions"):
		overlay.call("_clear_all_actions")
	if overlay != null:
		overlay.queue_free()
	PlatformCaps.clear_overrides()
