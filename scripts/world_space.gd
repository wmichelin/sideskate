class_name WorldSpace
extends RefCounted
## Sole logical ↔ Godot 3D mapping for the 3D renderer.
## Logical X → world X, height → world Y, logical Z → world Z.


static func logical_to_world(logical_x: float, logical_z: float, height: float) -> Vector3:
	return Vector3(logical_x, height, logical_z)


static func world_to_logical(world: Vector3) -> Dictionary:
	return {"x": world.x, "z": world.z, "height": world.y}
