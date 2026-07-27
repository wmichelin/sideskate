extends Node2D
## One half of the Far → Player → Near painter split. Host owns geometry;
## this node only provides a CanvasItem so Near can composite above the skater.

enum Pass { FAR, NEAR }

@export var pass_kind: Pass = Pass.FAR

var host: Node2D


func _draw() -> void:
	if host != null and host.has_method("paint_pass"):
		host.call("paint_pass", self, pass_kind == Pass.NEAR)
