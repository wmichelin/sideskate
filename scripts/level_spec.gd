class_name LevelSpec
extends RefCounted
## Parsed .ssk level: floors, decks, pipes, spawn, perspective.

var name: String = ""
var width: float = 1280.0
var depth: float = 100.0
var perspective_inset: float = 80.0
var far_geometry_scale: float = 0.72
var pipe_radius_override: float = -1.0
var deck_height_override: float = -1.0

var spawn_x: float = 640.0
var spawn_z: float = 40.0

## Each: { "poly": PackedVector2Array (x,z), "height": float }
var floors: Array = []
## Each: { "poly": PackedVector2Array, "height": float }
var decks: Array = []
## Each: { "side": int, "lip_x": float, "radius": float, "z_min": float, "z_max": float,
##         "x_min": float, "x_max": float }
var pipes: Array = []

var z_min: float = 0.0
var z_max: float = 100.0
var x_min: float = 0.0
var x_max: float = 1280.0


static func point_in_poly(point: Vector2, poly: PackedVector2Array) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in range(n):
		var pi: Vector2 = poly[i]
		var pj: Vector2 = poly[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
				(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y + 0.0000001) + pi.x):
			inside = not inside
		j = i
	return inside


func contains_playable(logical_x: float, logical_z: float) -> bool:
	var p := Vector2(logical_x, logical_z)
	for floor in floors:
		if point_in_poly(p, floor.poly):
			return true
	for deck in decks:
		if point_in_poly(p, deck.poly):
			return true
	for pipe in pipes:
		if logical_x >= pipe.x_min - 0.001 and logical_x <= pipe.x_max + 0.001 \
				and logical_z >= pipe.z_min - 0.001 and logical_z <= pipe.z_max + 0.001:
			return true
	return false
