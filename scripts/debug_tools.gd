extends Node
## Central gate for debug HUD, cell highlight, and god mode.
## Off in release exports unless custom feature `debug_tools` is set.

## True in editor/debug builds, or exports with feature tag `debug_tools`.
var available: bool = false
## Flight assist: no gravity; j/k adjust height. Only when available.
var god_mode: bool = false

signal god_mode_changed(enabled: bool)


func _ready() -> void:
	available = OS.is_debug_build() or OS.has_feature("debug_tools")
	if not available:
		god_mode = false
		call_deferred("_strip_debug_nodes")


func is_available() -> bool:
	return available


func set_god_mode(on: bool) -> void:
	if not available:
		on = false
	if god_mode == on:
		return
	god_mode = on
	god_mode_changed.emit(god_mode)


func toggle_god_mode() -> void:
	set_god_mode(not god_mode)


func _strip_debug_nodes() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("debug_tools"):
		if is_instance_valid(n):
			n.queue_free()
