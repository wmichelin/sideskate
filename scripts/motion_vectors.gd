class_name MotionVectors
extends RefCounted
## Named motion triad used across sim + debug visualization.
##
## Causal chain (industry “wish → control → world” pattern):
##   INPUT  — raw stick wish on logical X/Z only (no height; player cannot steer Y)
##   MOMENTUM — integrated control (`PlayerSim` tangent / air velocity)
##   ACTUAL — measured world motion from pose (includes height rate)
##
## Prefer `MotionVectors.Kind` in gameplay/debug code instead of ad-hoc strings.
## Head arrows and `Player.motion_world` / `motion_speed` are the display surface;
## sim gates (e.g. fly-out) should read the same underlying signals.


enum Kind {
	ACTUAL = 0,
	MOMENTUM = 1,
	INPUT = 2,
}


static func kind_name(kind: Kind) -> String:
	match kind:
		Kind.ACTUAL:
			return "actual"
		Kind.MOMENTUM:
			return "momentum"
		Kind.INPUT:
			return "input"
	return "unknown"


## True when the vector is constrained to the ground-plane axes (X + depth Z).
## INPUT is always planar; ACTUAL/MOMENTUM may include a vertical component.
static func is_planar(kind: Kind) -> bool:
	return kind == Kind.INPUT


## Default debug arrow tint for each kind (matches main scene).
static func debug_color(kind: Kind) -> Color:
	match kind:
		Kind.ACTUAL:
			return Color(0.45, 0.95, 0.75, 0.95)
		Kind.MOMENTUM:
			return Color(1.0, 0.72, 0.28, 0.95)
		Kind.INPUT:
			return Color(0.35, 0.72, 1.0, 0.95)
	return Color.WHITE
