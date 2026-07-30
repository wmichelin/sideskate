class_name SupportPatch
extends RefCounted
## Flat support (floor / deck / lava) compiled from IDL.


var id: String = ""
var kind: int = 0 ## SimKinds.SurfaceKind
var height: float = 0.0
var base_height: float = 0.0
var poly: PackedVector2Array = PackedVector2Array() ## (x, z) vertices
var x_min: float = 0.0
var x_max: float = 0.0
var z_min: float = 0.0
var z_max: float = 0.0
var lethal: bool = false


func contains_xz(x: float, z: float) -> bool:
	if x < x_min - 0.001 or x > x_max + 0.001:
		return false
	if z < z_min - 0.001 or z > z_max + 0.001:
		return false
	if _point_in_poly(x, z):
		return true
	# Even-odd ray cast treats the max-X vertical edge as outside. Hang lock X
	# for a right-edge coping is exactly x_max — must still count as on-pad so
	# air-out depth transfer can land floor/lava instead of falling through.
	var cx := (x_min + x_max) * 0.5
	var cz := (z_min + z_max) * 0.5
	var ix := x + clampf(cx - x, -0.05, 0.05)
	var iz := z + clampf(cz - z, -0.05, 0.05)
	if absf(ix - x) < 0.0001 and absf(iz - z) < 0.0001:
		return false
	return _point_in_poly(ix, iz)


func height_at(_x: float, _z: float) -> float:
	return height


func project(x: float, z: float, h: float) -> Dictionary:
	var on := contains_xz(x, z)
	return {
		"ok": on,
		"point": Vector3(x, z, height) if on else Vector3(x, z, h),
		"normal": Vector3(0, 0, 1), ## logical: up is +height → use (0,1,0) in xz-h? We use Vector3(x,z,h)
		"tangent_x": Vector3(1, 0, 0),
		"tangent_z": Vector3(0, 1, 0),
		"u": clampf((x - x_min) / maxf(x_max - x_min, 0.001), 0.0, 1.0),
		"v": clampf((z - z_min) / maxf(z_max - z_min, 0.001), 0.0, 1.0),
		"separation": h - height,
		"surface_id": id,
	}


## World point as Vector3(logical_x, logical_z, height).
func world_normal() -> Vector3:
	return Vector3(0, 0, 1)


func _point_in_poly(x: float, z: float) -> bool:
	var n := poly.size()
	if n < 3:
		return false
	var inside := false
	var j := n - 1
	for i in range(n):
		var xi := poly[i].x
		var zi := poly[i].y
		var xj := poly[j].x
		var zj := poly[j].y
		var intersect := ((zi > z) != (zj > z)) and \
			(x < (xj - xi) * (z - zi) / maxf(zj - zi, 0.0001) + xi)
		if intersect:
			inside = not inside
		j = i
	return inside
