extends Node
## Central gate for debug HUD and cell highlight.
## Off in release exports unless custom feature `debug_tools` is set.

## True in editor/debug builds, or exports with feature tag `debug_tools`.
var available: bool = false
## Head arrows for INPUT / MOMENTUM / ACTUAL. Off by default.
var show_motion_vectors: bool = false
## Zone / facing box over the skater's head. Off by default.
var show_head_debug: bool = false
## Bottom-left FPS counter. On by default while debugging.
var show_fps: bool = true
## DisplayServer VSync. Mailbox when on (high-refresh friendly); off = uncapped.
var vsync_enabled: bool = true

signal show_motion_vectors_changed(enabled: bool)
signal show_head_debug_changed(enabled: bool)
signal show_fps_changed(enabled: bool)
signal vsync_changed(enabled: bool)


func _ready() -> void:
	available = (OS.is_debug_build() or OS.has_feature("debug_tools")) and not _cmdline_disables_debug()
	_apply_vsync(vsync_enabled)
	if not available:
		call_deferred("_strip_debug_nodes")


func _cmdline_disables_debug() -> bool:
	# Godot user args after `--`, e.g. `godot --path . -- --no-debug-tools`
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-debug-tools":
			return true
	return false


func is_available() -> bool:
	return available


func set_show_motion_vectors(on: bool) -> void:
	if not available:
		on = false
	if show_motion_vectors == on:
		return
	show_motion_vectors = on
	show_motion_vectors_changed.emit(show_motion_vectors)


func set_show_head_debug(on: bool) -> void:
	if not available:
		on = false
	if show_head_debug == on:
		return
	show_head_debug = on
	show_head_debug_changed.emit(show_head_debug)


func set_show_fps(on: bool) -> void:
	if not available:
		on = false
	if show_fps == on:
		return
	show_fps = on
	show_fps_changed.emit(show_fps)


func set_vsync_enabled(on: bool) -> void:
	if vsync_enabled == on:
		return
	vsync_enabled = on
	_apply_vsync(vsync_enabled)
	vsync_changed.emit(vsync_enabled)


func _apply_vsync(on: bool) -> void:
	# Mailbox presents the latest frame — better for 120Hz than classic vsync.
	var mode := (
		DisplayServer.VSYNC_MAILBOX if on else DisplayServer.VSYNC_DISABLED
	)
	DisplayServer.window_set_vsync_mode(mode)


func _strip_debug_nodes() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("debug_tools"):
		if is_instance_valid(n):
			n.queue_free()
