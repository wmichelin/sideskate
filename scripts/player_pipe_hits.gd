class_name PlayerPipeHits
extends RefCounted
## Pipe-hit packing / radius lookup for Player sticky identity.
## Pure helpers — Player owns level.pipes and sticky fields.

const _PipeMath := preload("res://scripts/pipe_math.gd")


## Sticky ramp identity as a pipe hit dict (ContactMath.same_pipe / air enter).
static func ramp_pipe_hit(
	side: int,
	lip_x: float,
	base_height: float,
	z_min: float,
	z_max: float,
	radius: float,
) -> Dictionary:
	return {
		"active": true,
		"zone": _PipeMath.zone_name(side),
		"side": side,
		"lip_x": lip_x,
		"radius": radius,
		"base_height": base_height,
		"z_min": z_min,
		"z_max": z_max,
	}


## Resolve quarter-pipe radius from a sample hit, searching `pipes` when needed.
static func pipe_radius_for_hit(hit: Dictionary, pipes: Array) -> float:
	if hit.has("radius") and float(hit.radius) > 0.0:
		return float(hit.radius)
	var lip := float(hit.get("lip_x", 0.0))
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	for pipe in pipes:
		if pipe.side != side or absf(pipe.lip_x - lip) >= 0.05:
			continue
		if hit.has("base_height") \
				and absf(pipe.base_height - float(hit.base_height)) > 0.5:
			continue
		if hit.has("z_min") and absf(pipe.z_min - float(hit.z_min)) > 0.05:
			continue
		if hit.has("z_max") and absf(pipe.z_max - float(hit.z_max)) > 0.05:
			continue
		return pipe.radius
	return 150.0
