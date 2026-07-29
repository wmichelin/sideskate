class_name SurfaceQuery
extends RefCounted
## Pure geometry queries over ParkModel — no scene/node deps.


var model: ParkModel


func _init(m: ParkModel = null) -> void:
	model = m


## All supports at (x,z) with height ≤ feet_y + CONTACT_EPS, sorted high→low then id.
func supports_below(x: float, z: float, feet_y: float) -> Array:
	var out: Array = []
	if model == null:
		return out
	for pid in model.patches.keys():
		var patch: SupportPatch = model.patches[pid]
		if not patch.contains_xz(x, z):
			continue
		if patch.height > feet_y + SimTolerances.CONTACT_EPS:
			continue
		out.append({
			"surface_id": patch.id,
			"kind": patch.kind,
			"height": patch.height,
			"lethal": patch.lethal,
			"patch": patch,
		})
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		if not pipe.contains_xz(x, z):
			continue
		var proj := pipe.project(x, z, feet_y)
		if not bool(proj.get("ok", false)):
			continue
		var ph := float(proj.point.z)
		if ph > feet_y + SimTolerances.CONTACT_EPS:
			continue
		out.append({
			"surface_id": pipe.id,
			"kind": SimKinds.SurfaceKind.PIPE,
			"height": ph,
			"lethal": false,
			"pipe": pipe,
			"proj": proj,
		})
	out.sort_custom(func(a, b):
		# Highest support first (descending height), then stable id.
		var dh := float(a.height) - float(b.height)
		if absf(dh) > 0.0001:
			return dh > 0.0
		# Prefer non-lethal when heights tie (floor over lava).
		var la := bool(a.get("lethal", false))
		var lb := bool(b.get("lethal", false))
		if la != lb:
			return not la
		return str(a.surface_id) < str(b.surface_id)
	)
	return out


func top_support(x: float, z: float, feet_y: float) -> Dictionary:
	var all := supports_below(x, z, feet_y)
	if all.is_empty():
		return {}
	return all[0]


func project_to_surface(surface_id: String, x: float, z: float, h: float) -> Dictionary:
	if model == null:
		return {"ok": false}
	if model.patches.has(surface_id):
		var patch: SupportPatch = model.patches[surface_id]
		return patch.project(x, z, h)
	if model.pipes.has(surface_id):
		var pipe: PipeSurface = model.pipes[surface_id]
		return pipe.project(x, z, h)
	return {"ok": false}


## First topological edge crossed when advancing pipe u toward its gate.
## WALL_EXTENSION uses u_gate=2 (wall top); others typically gate at 1 (geometric coping).
func crossed_edge(surface_id: String, old_u: float, new_u: float) -> Dictionary:
	if model == null:
		return {}
	for eid in model.edges.keys():
		var edge: TopologyEdge = model.edges[eid]
		if edge.from_surface_id != surface_id:
			continue
		var gate := edge.u_gate
		if old_u < gate - 0.0001 and new_u >= gate - 0.0001:
			return {
				"edge": edge,
				"edge_id": edge.id,
				"remainder_u": new_u - gate,
			}
	return {}


## Copings in horizontal direction from position (layer-agnostic).
## direction: -1 left / +1 right. Returns ranked candidate dicts.
func copings_in_direction(
	x: float, z: float, h: float, direction: float, max_cells: int = -1
) -> Array:
	var out: Array = []
	if model == null or absf(direction) < 0.001:
		return out
	var cells := max_cells if max_cells > 0 else SimTolerances.FACING_COPING_CELLS
	var max_dist := float(cells) * model.cell_w + SimTolerances.ALIGN_EPS
	var dir := signf(direction)
	for cid in model.all_coping_ids():
		var cope: CopingEdge = model.copings[cid]
		if not cope.contains_z(z):
			continue
		var samp := cope.sample_at_z(z)
		if samp.is_empty():
			continue
		var cx := float(samp.coping_x)
		var dx := cx - x
		if dx * dir <= 0.0:
			continue
		var dist := absf(dx)
		if dist > max_dist:
			continue
		# Opposite facing: left pipe opens left (outward -1); want target whose
		# inward faces the traveler. Acid wants opposite-facing.
		out.append({
			"coping_id": cid,
			"coping": cope,
			"distance": dist,
			"height_delta": absf(float(samp.height) - h),
			"coping_x": cx,
			"height": float(samp.height),
			"side": cope.side,
			"class": cope.coping_class,
		})
	out.sort_custom(func(a, b):
		var dd := float(a.distance) - float(b.distance)
		if absf(dd) > 0.01:
			return dd < 0.0
		var dh := float(a.height_delta) - float(b.height_delta)
		if absf(dh) > 0.01:
			return dh < 0.0
		return str(a.coping_id) < str(b.coping_id)
	)
	return out


## Public solid query at a point (world border / space / pipe / wall).
func blocker_at(p: Vector3) -> Dictionary:
	return _blocker_at(p)


## Analytical capsule segment vs solid containment (world border / space / pipe / wall).
## Returns earliest hit or {}. Hits never kill — solvers stop into-wall motion.
func sweep_capsule(from: Vector3, to: Vector3) -> Dictionary:
	# from/to = Vector3(x, z, height)
	var motion := to - from
	var steps := maxi(1, int(ceil(motion.length() / maxf(SimTolerances.CAPSULE_RADIUS * 0.5, 1.0))))
	var earliest := {}
	var earliest_t := INF
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		var hit := _blocker_at(p)
		if not hit.is_empty() and t < earliest_t:
			earliest_t = t
			earliest = hit
			earliest["t"] = t
			earliest["point"] = p
	return earliest


func _blocker_at(p: Vector3) -> Dictionary:
	var x := p.x
	var z := p.y
	var h := p.z
	var margin := SimTolerances.CAPSULE_RADIUS
	# Invisible walls sit *outside* the park AABB so edge pipe copings (x=0 /
	# x=width) remain rideable. Inset walls made plaza edge >>> / <<< sticky.
	if x < -margin:
		return {"kind": "bounds", "axis": "x", "sign": -1.0, "reason": "west wall"}
	if x > model.width + margin:
		return {"kind": "bounds", "axis": "x", "sign": 1.0, "reason": "east wall"}
	if z < -margin:
		return {"kind": "bounds", "axis": "z", "sign": -1.0, "reason": "near wall"}
	if z > model.depth + margin:
		return {"kind": "bounds", "axis": "z", "sign": 1.0, "reason": "far wall"}
	# Non-playable footprint (space) — solid invisible wall, never fall out.
	var cell := model.cell_at(x, z)
	if not model.is_playable_cell(cell.x, cell.y):
		return {"kind": "bounds", "axis": "", "sign": 0.0, "reason": "unplayable cell"}
	# Foreign pipe body: below the ride surface inside a pipe footprint = clipping through.
	for pipe_id in model.pipes.keys():
		var pipe: PipeSurface = model.pipes[pipe_id]
		if not pipe.contains_xz(x, z):
			continue
		var proj := pipe.project(x, z, h)
		if not bool(proj.get("ok", false)):
			continue
		var ph := float(proj.point.z)
		if h < ph - SimTolerances.CONTACT_EPS:
			return {
				"kind": "pipe",
				"surface_id": pipe.id,
				"reason": "through pipe body",
			}
	# Deck platforms: solid below the top — ride on top only, never through the base.
	for patch_id in model.patches.keys():
		var patch: SupportPatch = model.patches[patch_id]
		if int(patch.kind) != SimKinds.SurfaceKind.DECK:
			continue
		if not patch.contains_xz(x, z):
			continue
		# On or above the ride surface — free (landing / skating the top).
		if h >= patch.height - SimTolerances.CONTACT_EPS:
			continue
		# Below the platform base — open (story below).
		if h < patch.base_height - SimTolerances.CONTACT_EPS:
			continue
		return {
			"kind": "deck",
			"surface_id": patch.id,
			"reason": "through deck body",
		}
	# Wall extension solids: inside outward pad volume below pad top near coping.
	for cid in model.copings.keys():
		var cope: CopingEdge = model.copings[cid]
		if cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
			continue
		if not cope.contains_z(z):
			continue
		var samp := cope.sample_at_z(z)
		var cx := float(samp.coping_x)
		var top := float(samp.height)
		var out := cope.outward_sign
		# Thin slab outward from coping.
		var depth := model.cell_w * 0.5
		var x0 := cx
		var x1 := cx + out * depth
		var lo := minf(x0, x1)
		var hi := maxf(x0, x1)
		if x < lo - SimTolerances.CAPSULE_RADIUS or x > hi + SimTolerances.CAPSULE_RADIUS:
			continue
		if h >= top + SimTolerances.CONTACT_EPS:
			continue
		# Below deck top inside wall slab → blocked.
		if h < top:
			return {
				"kind": "wall",
				"coping_id": cid,
				"reason": "wall extension",
			}
	return {}
