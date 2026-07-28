class_name WorldSpace
extends RefCounted
## Sole logical ↔ Godot 3D (meter) mapping for render + physics.
##
## Camera sits at low Z and looks toward +Z (into the park). With Y-up that
## mirrors screen X, so world X is −logical X so left/right match the 2D game.
## Godot physics expects ~1 unit = 1 meter; logical units use `LOGIC_PER_METER`.

## Logical units per Godot meter (matches Player.logic_per_meter default).
const LOGIC_PER_METER := 100.0


static func logic_to_meters(logical: float) -> float:
	return logical / LOGIC_PER_METER


static func meters_to_logic(meters: float) -> float:
	return meters * LOGIC_PER_METER


static func logical_to_world(logical_x: float, logical_z: float, height: float) -> Vector3:
	return Vector3(
		-logic_to_meters(logical_x),
		logic_to_meters(height),
		logic_to_meters(logical_z)
	)


static func world_to_logical(world: Vector3) -> Dictionary:
	return {
		"x": meters_to_logic(-world.x),
		"z": meters_to_logic(world.z),
		"height": meters_to_logic(world.y),
	}


static func logical_velocity_to_world(vel_x: float, vel_z: float, vel_y: float) -> Vector3:
	return Vector3(
		-logic_to_meters(vel_x),
		logic_to_meters(vel_y),
		logic_to_meters(vel_z)
	)


static func world_velocity_to_logical(world_vel: Vector3) -> Dictionary:
	return {
		"x": meters_to_logic(-world_vel.x),
		"z": meters_to_logic(world_vel.z),
		"y": meters_to_logic(world_vel.y),
	}
