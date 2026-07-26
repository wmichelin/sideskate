extends Node2D
## Head debug arrow for one [MotionVectors.Kind]. Display-only (does not step sim).

@export var kind: MotionVectors.Kind = MotionVectors.Kind.ACTUAL
@export var player_path: NodePath = NodePath("../..")
@export var min_speed: float = 8.0
@export var pixels_per_speed: float = 0.1
@export var min_length: float = 18.0
@export var max_length: float = 90.0
@export var shaft_width: float = 2.5
@export var arrow_color: Color = Color(0.45, 0.95, 0.75, 0.95)

var _player: Node2D
var _speed_label: Label


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return
	z_index = 25
	_player = get_node_or_null(player_path) as Node2D
	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 11)
	_speed_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92, 1.0))
	_speed_label.position = Vector2(-28, -14)
	_speed_label.size = Vector2(56, 16)
	add_child(_speed_label)
	_speed_label.visible = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _player == null or not _player.has_method("motion_screen") or not _player.has_method("motion_speed"):
		_speed_label.visible = false
		return

	var screen_v: Vector2 = _player.call("motion_screen", kind)
	var speed: float = float(_player.call("motion_speed", kind))
	if speed < min_speed or screen_v.length_squared() < 0.0001:
		_speed_label.visible = false
		return

	var dir := screen_v.normalized()
	var length := clampf(speed * pixels_per_speed, min_length, max_length)
	var tip := dir * length
	var side := Vector2(-dir.y, dir.x)
	var head_len := mini(12.0, length * 0.35)
	var head_w := head_len * 0.65
	var base := tip - dir * head_len

	draw_line(Vector2.ZERO, base, arrow_color, shaft_width, true)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			base + side * head_w,
			base - side * head_w,
		]),
		arrow_color
	)

	_speed_label.visible = true
	_speed_label.text = "%.0f" % speed
	_speed_label.position = tip + Vector2(-28, -18)
