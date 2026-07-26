class_name FacingCastMath
extends RefCounted
## Pure facing-cast resolution (logical grid only — no draw / perspective).
## Reusable by debug highlight and gameplay (spine probe, transfers, etc.).
##
## Pipes are duck-typed: QuarterPipe nodes or anything with
## side / lip_x / radius / layer / base_height / query_surface(x,z).

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")


## Columns ahead of origin along facing_h ("l"/"r"), steps 1…distance.
## Does not include the origin cell. Stops at grid edges.
static func cells_ahead(
	grid_w: int,
	grid_h: int,
	origin_col: int,
	origin_row: int,
	facing_h: String,
	distance: int,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dist := maxi(distance, 0)
	if dist <= 0 or grid_w <= 0 or grid_h <= 0:
		return out
	if origin_row < 0 or origin_row >= grid_h:
		return out
	var step := -1 if facing_h == "l" else 1
	for i in range(1, dist + 1):
		var col := origin_col + step * i
		if col < 0 or col >= grid_w:
			break
		out.append(Vector2i(col, origin_row))
	return out


## Surface under (x,z) for cast: glyph story at prefer_h, same-layer pipe arc,
## holes fall through. Returns { height, zone, layer, is_coping, side, lip_x,
## radius, base_height, top_coping?, theta? }.
static func resolve_surface(
	spec: Variant,
	pipes: Array,
	logical_x: float,
	logical_z: float,
	prefer_h: float,
) -> Dictionary:
	if spec == null or int(spec.grid_w) <= 0:
		return _empty_surface("flat", 0.0, -1)
	var cell: Vector2i = spec.cell_at(logical_x, logical_z)
	return _resolve_cell(spec, pipes, cell.x, cell.y, logical_x, logical_z, prefer_h, 0)


static func resolve_height(
	spec: Variant,
	pipes: Array,
	logical_x: float,
	logical_z: float,
	prefer_h: float,
) -> float:
	return float(resolve_surface(spec, pipes, logical_x, logical_z, prefer_h).get("height", 0.0))


## Full facing cast: cells ahead + resolved surface at each cell mid / trail_z.
## Each hit: cell, bounds (x0,x1,z0,z1), mid_x, trail_z, plus resolve_surface fields.
static func cast_ahead(
	spec: Variant,
	pipes: Array,
	origin_col: int,
	origin_row: int,
	facing_h: String,
	distance: int,
	trail_z: float,
	prefer_h: float,
) -> Array:
	var out: Array = []
	if spec == null:
		return out
	var cells: Array[Vector2i] = cells_ahead(
		int(spec.grid_w), int(spec.grid_h), origin_col, origin_row, facing_h, distance
	)
	for cell in cells:
		var b: Dictionary = spec.cell_bounds(cell.x, cell.y)
		var mid_x := (float(b.x0) + float(b.x1)) * 0.5
		var surf: Dictionary = resolve_surface(spec, pipes, mid_x, trail_z, prefer_h)
		var hit: Dictionary = {
			"cell": cell,
			"col": cell.x,
			"row": cell.y,
			"x0": float(b.x0),
			"x1": float(b.x1),
			"z0": float(b.z0),
			"z1": float(b.z1),
			"mid_x": mid_x,
			"trail_z": trail_z,
		}
		for k in surf.keys():
			hit[k] = surf[k]
		out.append(hit)
	return out


## First coping hit in a cast (empty if none).
## Optionally skip a pipe identity (side + lip) — e.g. the pipe you're already on.
static func first_coping(
	hits: Array,
	exclude_side: int = -1,
	exclude_lip_x: float = NAN,
) -> Dictionary:
	for hit in hits:
		if not bool(hit.get("is_coping", false)):
			continue
		if exclude_side >= 0 and int(hit.get("side", -1)) == exclude_side \
				and not is_nan(exclude_lip_x) \
				and absf(float(hit.get("lip_x", INF)) - exclude_lip_x) < 0.05:
			continue
		return hit
	return {}


## Cast ahead and return the first coping cell (see cast_ahead / first_coping).
static func first_coping_ahead(
	spec: Variant,
	pipes: Array,
	origin_col: int,
	origin_row: int,
	facing_h: String,
	distance: int,
	trail_z: float,
	prefer_h: float,
	exclude_side: int = -1,
	exclude_lip_x: float = NAN,
) -> Dictionary:
	var hits: Array = cast_ahead(
		spec, pipes, origin_col, origin_row, facing_h, distance, trail_z, prefer_h
	)
	return first_coping(hits, exclude_side, exclude_lip_x)


static func _empty_surface(zone: String, height: float, layer: int) -> Dictionary:
	return {
		"height": height,
		"zone": zone,
		"layer": layer,
		"is_coping": false,
		"side": -1,
		"lip_x": NAN,
		"radius": 0.0,
		"base_height": height,
	}


static func _resolve_cell(
	spec: Variant,
	pipes: Array,
	col: int,
	row: int,
	logical_x: float,
	logical_z: float,
	prefer_h: float,
	depth: int,
) -> Dictionary:
	if depth > 8:
		return _empty_surface("hole", 0.0, -1)
	var ginfo: Dictionary = spec.glyph_at_prefer_h(col, row, prefer_h)
	var glyph := str(ginfo.get("glyph", " "))
	var layer := int(ginfo.get("layer", -1))
	var layer_h := float(ginfo.get("layer_height", 0.0))
	var gzone := _ContactMath.zone_from_glyph(glyph)
	match gzone:
		"pipe":
			var want_side := 0 if glyph == "<" else 1
			var pipe_info: Dictionary = _pipe_info_on_layer(
				spec, pipes, logical_x, logical_z, want_side, layer, col, row
			)
			if pipe_info.is_empty():
				var mid: Dictionary = spec.cell_bounds(col, row)
				var mx := (float(mid.x0) + float(mid.x1)) * 0.5
				pipe_info = _pipe_info_on_layer(
					spec, pipes, mx, logical_z, want_side, layer, col, row
				)
			if pipe_info.is_empty():
				var stub := _empty_surface("pipe", layer_h, layer)
				stub["side"] = want_side
				return stub
			return pipe_info
		"flat":
			return _empty_surface("flat", layer_h, layer)
		"deck":
			var dh := _deck_height_for_layer(spec, layer)
			if is_nan(dh):
				dh = layer_h
			var deck := _empty_surface("deck", dh, layer)
			deck["base_height"] = layer_h
			return deck
		"hole":
			var below := layer_h - _ContactMath.LAND_EPS - 0.05
			if below < -0.01 and layer_h <= 0.0:
				return _empty_surface("hole", 0.0, layer)
			return _resolve_cell(
				spec, pipes, col, row, logical_x, logical_z, below, depth + 1
			)
		_:
			return _empty_surface("flat", maxf(layer_h, 0.0), layer)


static func _deck_height_for_layer(spec: Variant, layer: int) -> float:
	if spec == null:
		return NAN
	for deck in spec.decks:
		if layer >= 0 and int(deck.get("layer", -1)) != layer:
			continue
		return float(deck.get("height", 0.0))
	return NAN


static func _pipe_info_on_layer(
	spec: Variant,
	pipes: Array,
	logical_x: float,
	logical_z: float,
	want_side: int,
	layer: int,
	col: int,
	row: int,
) -> Dictionary:
	for pipe in pipes:
		if int(pipe.side) != want_side:
			continue
		var pl := _pipe_layer(pipe)
		if layer >= 0 and pl >= 0 and pl != layer:
			continue
		var hit: Dictionary = _pipe_query(pipe, logical_x, logical_z)
		if not hit.get("active", false):
			continue
		var lip := float(pipe.lip_x)
		var radius := float(pipe.radius)
		var side := int(pipe.side)
		var cope := _PipeMath.coping_x(side, lip, radius)
		var is_cope := false
		if spec != null:
			var b: Dictionary = spec.cell_bounds(col, row)
			is_cope = cope >= float(b.x0) - 0.05 and cope <= float(b.x1) + 0.05
		else:
			is_cope = absf(logical_x - cope) <= maxf(radius * 0.5, 0.05)
		return {
			"height": float(hit.get("height", 0.0)),
			"zone": str(hit.get("zone", "pipe")),
			"layer": layer,
			"is_coping": is_cope,
			"side": side,
			"lip_x": lip,
			"radius": radius,
			"base_height": _pipe_base_height(pipe),
			"top_coping": cope,
			"theta": float(hit.get("theta", 0.0)),
		}
	return {}


static func _pipe_layer(pipe: Variant) -> int:
	if typeof(pipe) == TYPE_DICTIONARY:
		return int(pipe.get("layer", -1))
	return int(pipe.layer)


static func _pipe_base_height(pipe: Variant) -> float:
	if typeof(pipe) == TYPE_DICTIONARY:
		return float(pipe.get("base_height", 0.0))
	return float(pipe.base_height)


static func _pipe_query(pipe: Variant, logical_x: float, logical_z: float) -> Dictionary:
	if typeof(pipe) == TYPE_OBJECT and pipe.has_method("query_surface"):
		return pipe.query_surface(logical_x, logical_z)
	# Dict / duck: approximate QuarterPipe.query_surface.
	var side: int
	var lip: float
	var radius: float
	var z_min: float
	var z_max: float
	if typeof(pipe) == TYPE_DICTIONARY:
		side = int(pipe.get("side", 0))
		lip = float(pipe.get("lip_x", 0.0))
		radius = float(pipe.get("radius", 0.0))
		z_min = float(pipe.get("z_min", -INF))
		z_max = float(pipe.get("z_max", INF))
	else:
		side = int(pipe.side)
		lip = float(pipe.lip_x)
		radius = float(pipe.radius)
		z_min = float(pipe.z_min)
		z_max = float(pipe.z_max)
	var base_h := _pipe_base_height(pipe)
	if logical_z < z_min - 0.001 or logical_z > z_max + 0.001:
		return {"active": false}
	var x_min := lip - radius if side == 0 else lip
	var x_max := lip if side == 0 else lip + radius
	if logical_x < x_min - 0.001 or logical_x > x_max + 0.001:
		return {"active": false}
	var x_offset := (lip - logical_x) if side == 0 else (logical_x - lip)
	x_offset = clampf(x_offset, 0.0, radius)
	var ratio := 0.0 if radius <= 0.0001 else clampf(x_offset / radius, 0.0, 1.0)
	var theta := asin(ratio)
	var height := base_h + radius * (1.0 - cos(theta))
	return {
		"active": true,
		"zone": "left_pipe" if side == 0 else "right_pipe",
		"height": height,
		"theta": theta,
		"lip_x": lip,
		"side": side,
		"base_height": base_h,
		"radius": radius,
		"layer": _pipe_layer(pipe),
	}
