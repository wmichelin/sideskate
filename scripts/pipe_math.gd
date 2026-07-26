class_name PipeMath
extends RefCounted
## Pure quarter-pipe helpers (no scene state).


static func coping_x(side: int, lip_x: float, radius: float) -> float:
	if side == QuarterPipe.PipeSide.LEFT:
		return lip_x - radius
	return lip_x + radius


## True when two opposite-facing pipes share (or nearly share) a top coping X.
static func opposite_coping_near(
	side_a: int,
	lip_a: float,
	radius_a: float,
	side_b: int,
	lip_b: float,
	radius_b: float,
	eps: float = 1.0
) -> bool:
	if side_a == side_b:
		return false
	var ca := coping_x(side_a, lip_a, radius_a)
	var cb := coping_x(side_b, lip_b, radius_b)
	return absf(ca - cb) < eps
