class_name AerialTargeting
extends RefCounted
## Facing-cast coping selection for acid / spine (Player supplies exit-pipe filter).


## First opposite-facing top coping within `cells` along travel.
## `is_exit_pipe` receives a cast hit dict and returns true to skip.
static func find_acid_coping_target(
	spec: LevelSpec,
	pipes: Array,
	cell: Vector2i,
	sample_z: float,
	prefer_h: float,
	logical_x: float,
	travel_x: float,
	cells: int,
	is_exit_pipe: Callable,
) -> Dictionary:
	if spec == null or absf(travel_x) < 1.0:
		return {}
	var want_side := AerialMath.acid_drop_want_side(travel_x)
	var face := "r" if travel_x > 0.0 else "l"
	var hits: Array = FacingCastMath.cast_ahead(
		spec, pipes, cell.x, cell.y, face, cells, sample_z, prefer_h
	)
	for hit in hits:
		if not bool(hit.get("is_coping", false)):
			continue
		var side := int(hit.get("side", -1))
		if side != want_side:
			continue
		if is_exit_pipe.is_valid() and bool(is_exit_pipe.call(hit)):
			continue
		var coping := float(hit.get("top_coping", NAN))
		if is_nan(coping):
			coping = PipeMath.coping_x(
				side,
				float(hit.get("lip_x", logical_x)),
				float(hit.get("radius", 150.0)),
			)
		if not AerialMath.acid_coping_ahead(logical_x, coping, travel_x):
			continue
		return hit
	return {}


## First facing-direction top coping ahead, excluding current underfoot/locked pipe.
static func find_facing_coping_target(
	spec: LevelSpec,
	pipes: Array,
	cell: Vector2i,
	sample_z: float,
	prefer_h: float,
	facing_h: String,
	cells: int,
	exclude_side: int,
	exclude_lip: float,
	exclude_z_min: float,
	exclude_z_max: float,
) -> Dictionary:
	if spec == null:
		return {}
	var hits: Array = FacingCastMath.cast_ahead(
		spec, pipes, cell.x, cell.y, facing_h, cells, sample_z, prefer_h
	)
	for hit in hits:
		if not bool(hit.get("is_coping", false)):
			continue
		var side := int(hit.get("side", -1))
		var lip := float(hit.get("lip_x", NAN))
		if side == exclude_side and not is_nan(exclude_lip) and not is_nan(lip) \
				and absf(lip - exclude_lip) < 0.05:
			var z_min := float(hit.get("z_min", NAN))
			var z_max := float(hit.get("z_max", NAN))
			var same_z := true
			if not is_nan(exclude_z_min) and not is_nan(z_min):
				same_z = same_z and absf(z_min - exclude_z_min) < 0.05
			if not is_nan(exclude_z_max) and not is_nan(z_max):
				same_z = same_z and absf(z_max - exclude_z_max) < 0.05
			if same_z:
				continue
		return hit
	return {}
