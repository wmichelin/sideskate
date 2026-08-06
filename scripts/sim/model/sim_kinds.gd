class_name SimKinds
extends RefCounted
## Enumerations for the analytical park model.


enum SurfaceKind {
	FLOOR = 0,
	DECK = 1,
	PIPE = 2,
	LAVA = 3,
	WALL = 4,
	RAMP = 5,
	RAIL = 6,
}

enum CopingClass {
	OPEN = 0,
	SUPPORT_SEAM = 1,
	WALL_EXTENSION = 2,
	SHARED_SPINE = 3,
}

enum EdgeKind {
	SEAM = 0,
	OPEN_COPING = 1,
	WALL_TOP = 2,
	UNSUPPORTED = 3,
}

enum PipeSide {
	LEFT = 0,
	RIGHT = 1,
}

## Compiled air-contact ownership roles. One role owns each seam point; AirSolver
## dispositions (Mount / Reject / Corridor) key off this, not ad-hoc geometry votes.
enum ContactRole {
	SOLID = 0,
	LIP_COLUMN = 1,
	OUTWARD_DECK = 2,
	WALL_CLIMB = 3,
	OPEN_CORRIDOR = 4,
	SUPPORT_TOP = 5,
	HANG_ANCHOR = 6,
	BOUNDS = 7,
}

## Disposition for a single air contact.
enum ContactDisposition {
	MOUNT = 0,
	REJECT = 1,
	CORRIDOR = 2,
}


static func coping_class_name(c: int) -> String:
	match c:
		CopingClass.OPEN:
			return "OPEN"
		CopingClass.SUPPORT_SEAM:
			return "SUPPORT_SEAM"
		CopingClass.WALL_EXTENSION:
			return "WALL_EXTENSION"
		CopingClass.SHARED_SPINE:
			return "SHARED_SPINE"
		_:
			return "UNKNOWN"


static func surface_kind_name(k: int) -> String:
	match k:
		SurfaceKind.FLOOR:
			return "floor"
		SurfaceKind.DECK:
			return "deck"
		SurfaceKind.PIPE:
			return "pipe"
		SurfaceKind.LAVA:
			return "lava"
		SurfaceKind.WALL:
			return "wall"
		SurfaceKind.RAMP:
			return "ramp"
		SurfaceKind.RAIL:
			return "rail"
		_:
			return "unknown"
