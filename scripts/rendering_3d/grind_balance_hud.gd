class_name GrindBalanceHud
extends Node
## Always-on balance meter while grinding (production HUD, not debug-gated).


@export var player_path: NodePath = NodePath("../Player")
@export var visual_path: NodePath = NodePath("../PlayerVisual")
@export var bar_offset: Vector3 = Vector3(0.0, 0.85, 0.0)
@export var bar_px: Vector2 = Vector2(80.0, 10.0)

var _player: Node
var _visual: Node3D
var _layer: CanvasLayer
var _root: Control
var _bg: ColorRect
var _center: ColorRect
var _fill: ColorRect


func _ready() -> void:
	process_priority = 101
	_player = get_node_or_null(player_path)
	_visual = get_node_or_null(visual_path) as Node3D
	_layer = CanvasLayer.new()
	_layer.name = "GrindBalanceHud"
	_layer.layer = 21
	add_child(_layer)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	_layer.add_child(_root)
	_bg = ColorRect.new()
	_bg.color = Color(0.08, 0.09, 0.11, 0.75)
	_bg.size = bar_px
	_root.add_child(_bg)
	_fill = ColorRect.new()
	_fill.color = Color(0.95, 0.55, 0.2, 1.0)
	_fill.size = Vector2(0.0, bar_px.y)
	_root.add_child(_fill)
	_center = ColorRect.new()
	_center.color = Color(0.92, 0.94, 0.98, 0.9)
	_center.size = Vector2(2.0, bar_px.y)
	_center.position = Vector2(bar_px.x * 0.5 - 1.0, 0.0)
	_root.add_child(_center)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _visual == null:
		_visual = get_node_or_null(visual_path) as Node3D
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
	if cam == null or _visual == null:
		_root.visible = false
		return
	var world := _visual.global_position + bar_offset
	if cam.is_position_behind(world):
		_root.visible = false
		return
	var screen: Vector2 = cam.unproject_position(world)
	_root.position = Vector2(
		roundf(screen.x - bar_px.x * 0.5),
		roundf(screen.y - bar_px.y * 0.5)
	)
	_root.visible = true
	var half := bar_px.x * 0.5
	var mag := absf(lean) * half
	if lean < 0.0:
		_fill.position = Vector2(half - mag, 0.0)
		_fill.size = Vector2(mag, bar_px.y)
		_fill.color = Color(0.95, 0.45, 0.35, 1.0)
	else:
		_fill.position = Vector2(half, 0.0)
		_fill.size = Vector2(mag, bar_px.y)
		_fill.color = Color(0.95, 0.65, 0.25, 1.0)
