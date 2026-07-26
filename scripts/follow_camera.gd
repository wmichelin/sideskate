extends Camera2D
## Follows the player in X and Y so deep levels can scroll off-frame.
## Player sits a bit below vertical center for a near-ground bias.

@export var target_path: NodePath = NodePath("../Player")
## 0 = top of view, 1 = bottom. Player rests around here in the viewport.
@export var player_screen_y_frac: float = 0.68

var _target: Node2D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	make_current()
	_follow()


func _physics_process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if _target == null:
		_target = get_node_or_null(target_path) as Node2D
	if _target == null:
		return
	var vp_h := get_viewport_rect().size.y
	# Camera2D centers on global_position; place player at the desired screen fraction.
	var cam_y := _target.global_position.y - vp_h * (player_screen_y_frac - 0.5)
	global_position = Vector2(_target.global_position.x, cam_y)
