class_name RailSurface
extends RefCounted
## Along-X grind rail compiled from `-` glyphs.


var id: String = ""
var x_min: float = 0.0
var x_max: float = 0.0
## Centerline depth (logical Z).
var z: float = 0.0
## Top of the bar (layer base + RAIL_OFFSET).
var top_height: float = 0.0
var base_height: float = 0.0
var layer: int = 0


func contains_x(x: float, eps: float = 0.0) -> bool:
	return x >= x_min - eps and x <= x_max + eps


## Approximate distance from pose to rail top/centerline for snap / contact.
func distance_to_pose(pos: Vector3) -> float:
	var cx := clampf(pos.x, x_min, x_max)
	var dx := pos.x - cx
	var dz := pos.y - z
	var dh := pos.z - top_height
	return sqrt(dx * dx + dz * dz + dh * dh)


func bottom_height(thickness: float = -1.0) -> float:
	var th := thickness if thickness > 0.0 else SimTolerances.RAIL_THICKNESS
	return top_height - th
