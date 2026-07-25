extends CanvasLayer
## Live readout of the player's logical depth state.

@export var player_path: NodePath = NodePath("../Player")

@onready var label: Label = $Panel/Label

var _player: Node2D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D


func _process(_delta: float) -> void:
	if _player == null or not _player.has_node("PseudoDepthBody"):
		label.text = "No player / PseudoDepthBody"
		return
	var depth: PseudoDepthBody = _player.get_node("PseudoDepthBody")
	var s := depth.debug_snapshot()
	label.text = (
		"PSEUDO-DEPTH DEBUG\n"
		+ "X: %.1f\n" % s.x
		+ "Z: %.1f  (t=%.2f)\n" % [s.z, s.t]
		+ "Scale: %.3f\n" % s.scale
		+ "Screen Y: %.1f\n" % s.screen_y
		+ "z_index: %d\n" % s.z_index
		+ "WASD / Arrows / Stick — Up = farther"
	)
