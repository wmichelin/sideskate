extends CanvasLayer
## Live readout of depth + surface (flat / pipe) state.

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
	var surface: Dictionary = {}
	if _player.get("last_surface") != null:
		surface = _player.last_surface
	var zone := str(surface.get("zone", "flat"))
	var pipe_angle := float(surface.get("angle", 0.0))
	label.text = (
		"PSEUDO-DEPTH DEBUG\n"
		+ "X: %.1f  (sx %.1f)\n" % [s.x, s.get("screen_x", s.x)]
		+ "Z: %.1f  (t=%.2f)\n" % [s.z, s.t]
		+ "Scale: %.3f\n" % s.scale
		+ "Screen Y: %.1f\n" % s.screen_y
		+ "z_index: %d\n" % s.z_index
		+ "Zone: %s\n" % zone
		+ "Surf H: %.1f (scr %.1f)\n" % [s.surface_height, s.get("surface_screen_h", 0.0)]
		+ "Pipe angle: %.1f deg\n" % pipe_angle
		+ "WASD — Up = farther"
	)
