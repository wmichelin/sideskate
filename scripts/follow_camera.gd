extends Camera2D
## Keeps the view horizontally centered on the player; Y framing stays fixed.

@export var target_path: NodePath = NodePath("../Player")

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
	var mid_y := get_viewport_rect().size.y * 0.5
	global_position = Vector2(_target.global_position.x, mid_y)
