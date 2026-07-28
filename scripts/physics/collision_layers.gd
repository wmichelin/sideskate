class_name CollisionLayers
extends RefCounted
## Physics layer bits for park + player (1-based Godot layer indices).

const PLAYER := 1
const WORLD_RIDE := 2
const WORLD_WALL := 3
const LAVA := 4
const PLAYABLE_BOUNDS := 5


static func bit(layer: int) -> int:
	return 1 << (layer - 1)


static func player_mask() -> int:
	return bit(WORLD_RIDE) | bit(WORLD_WALL) | bit(PLAYABLE_BOUNDS) | bit(LAVA)


static func ride_layers_for_face(face_role: String) -> int:
	match face_role:
		"wall", "back", "endcap":
			return WORLD_WALL
		"lava":
			return LAVA
		_:
			return WORLD_RIDE
