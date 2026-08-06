class_name GrindBalanceHud
extends CanvasLayer
## Always-on balance meter while grinding (production HUD, not debug-gated).


@export var player_path: NodePath = NodePath("../Player")
@export var visual_path: NodePath = NodePath("../World3D/PlayerVisual")
@export var bar_offset: Vector3 = Vector3(0.0, 0.95, 0.0)
@export var bar_px: Vector2 = Vector2(96.0, 12.0)

var _player: Node
var _visual: Node3D
var _root: Control
var _bg: ColorRect
var _center: ColorRect
var _fill: ColorRect
var _label: Label


func _ready() -> void:
	layer = 25
	process_priority = 101
	_resolve_refs()
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.05, 0.06, 0.08, 0.85)
	_bg.size = bar_px
	_root.add_child(_bg)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = Color(0.95, 0.55, 0.2, 1.0)
	_fill.size = Vector2(0.0, bar_px.y)
	_root.add_child(_fill)
	_center = ColorRect.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.color = Color(0.95, 0.97, 1.0, 1.0)
	_center.size = Vector2(3.0, bar_px.y)
	_center.position = Vector2(bar_px.x * 0.5 - 1.5, 0.0)
	_root.add_child(_center)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	_label.position = Vector2(0.0, -18.0)
	_label.size = Vector2(bar_px.x, 16.0)
	_label.text = "balance"
	_root.add_child(_label)


func _resolve_refs() -> void:
	_player = get_node_or_null(player_path)
	if _player == null and get_parent() != null:
		_player = get_parent().get_node_or_null("Player")
	_visual = get_node_or_null(visual_path) as Node3D
	if _visual == null and get_parent() != null:
		_visual = get_parent().get_node_or_null("World3D/PlayerVisual") as Node3D


func _process(_delta: float) -> void:
	if _player == null or _visual == null:
		_resolve_refs()
	if _root == null or _player == null:
		return
	var grinding := _player.has_method("is_grinding") and bool(_player.call("is_grinding"))
	if not grinding:
		_root.visible = false
		return
	var lean := 0.0
	if _player.has_method("grind_balance_frac"):
		lean = clampf(float(_player.call("grind_balance_frac")), -1.0, 1.0)
	var cam := get_viewport().get_camera_3d()
	var screen := Vector2.ZERO
	var placed := false
	if cam != null and _visual != null:
		var world := _visual.global_position + bar_offset
		if not cam.is_position_behind(world):
			screen = cam.unproject_position(world)
			placed = true
	if not placed:
		# Fallback: center-top of viewport so the meter is never invisible.
		var vp := get_viewport().get_visible_rect().size
		screen = Vector2(vp.x * 0.5, vp.y * 0.18)
	var bar_pos := Vector2(
		roundf(screen.x - bar_px.x * 0.5),
		roundf(screen.y - bar_px.y * 0.5)
	)
	_bg.position = bar_pos
	_center.position = bar_pos + Vector2(bar_px.x * 0.5 - 1.5, 0.0)
	_label.position = bar_pos + Vector2(0.0, -18.0)
	_root.visible = true
	var half := bar_px.x * 0.5
	var mag := absf(lean) * half
	if lean < -0.001:
		_fill.position = bar_pos + Vector2(half - mag, 0.0)
		_fill.size = Vector2(maxf(mag, 0.0), bar_px.y)
		_fill.color = Color(0.95, 0.4, 0.32, 1.0)
	elif lean > 0.001:
		_fill.position = bar_pos + Vector2(half, 0.0)
		_fill.size = Vector2(maxf(mag, 0.0), bar_px.y)
		_fill.color = Color(0.95, 0.65, 0.25, 1.0)
	else:
		_fill.position = bar_pos + Vector2(half, 0.0)
		_fill.size = Vector2.ZERO
	_label.text = "balance"
