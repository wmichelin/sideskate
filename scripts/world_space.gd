class_name WorldSpace
extends RefCounted
## Sole logical ↔ Godot 3D mapping for the 3D renderer.
##
## Camera sits at low Z and looks toward +Z (into the park). With Y-up that
## mirrors screen X, so world X is −logical X so left/right match the 2D game.


static func logical_to_world(logical_x: float, logical_z: float, height: float) -> Vector3:
	return Vector3(-logical_x, height, logical_z)


static func world_to_logical(world: Vector3) -> Dictionary:
	return {"x": -world.x, "z": world.z, "height": world.y}
