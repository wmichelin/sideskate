class_name PipeMath
extends RefCounted
## Pure quarter-pipe helpers (no scene state).
## side matches QuarterPipe.PipeSide: 0 = LEFT, 1 = RIGHT.


static func coping_x(side: int, lip_x: float, radius: float) -> float:
	if side == 0:
		return lip_x - radius
	return lip_x + radius


static func coping_sign(side: int) -> float:
	return -1.0 if side == 0 else 1.0


## Logical X for half-open cell indexing while X-locked on top coping.
## Coping sits on the pipe's outer edge (`x_min` left / `x_max` right). Right
## coping is an exclusive cell boundary, so raw `floor(x/cw)` maps one cell
## outward; nudge toward the lip (into the pipe) so targeting / highlight stay
## on the pipe glyph. Used by LevelSpec.cell_at_for_pose.
static func pose_x_for_cell_query(
	logical_x: float, side: int, eps: float = 0.001
) -> float:
	return logical_x - coping_sign(side) * eps


static func zone_name(side: int) -> String:
	return "left_pipe" if side == 0 else "right_pipe"


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
