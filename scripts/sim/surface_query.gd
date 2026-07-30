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
	for ramp_id in model.ramps.keys():
		var ramp: RampSurface = model.ramps[ramp_id]
		if not ramp.contains_xz(x, z):
			continue
		var rproj := ramp.project(x, z, feet_y)
		if not bool(rproj.get("ok", false)):
			continue
		var rh := float(rproj.point.z)
		if rh > feet_y + SimTolerances.CONTACT_EPS:
			continue
		out.append({
			"surface_id": ramp.id,
			"kind": SimKinds.SurfaceKind.RAMP,
			"height": rh,
			"lethal": false,
			"ramp": ramp,
			"proj": rproj,
		})
	out.sort_custom(func(a, b):
		# Highest support first (descending height), then stable id.
		var dh := float(a.height) - float(b.height)
		if absf(dh) > 0.0001:
			return dh > 0.0
		# Prefer lethal when heights tie so lava footprints beat overlapping floor.
		var la := bool(a.get("lethal", false))
		var lb := bool(b.get("lethal", false))
		if la != lb:
			return la
		return str(a.surface_id) < str(b.surface_id)
	)
	return out


func top_support(x: float, z: float, feet_y: float) -> Dictionary:
	var all := supports_below(x, z, feet_y)
	if all.is_empty():
		return {}
	return all[0]


## Lethal pad covering (x,z) at feet height, or {}. Floor polys may overlap lava
## cells; grounded contact with any lethal pad still kills.
func lethal_at(x: float, z: float, feet_h: float) -> Dictionary:
	if model == null:
		return {}
	var best := {}
	var best_h := -INF
	for pid in model.patches.keys():
		var patch: SupportPatch = model.patches[pid]
		if not patch.lethal:
			continue
		if not patch.contains_xz(x, z):
			continue
		if absf(patch.height - feet_h) > SimTolerances.CONTACT_EPS:
			continue
		if patch.height >= best_h:
			best_h = patch.height
			best = {
				"surface_id": patch.id,
				"kind": patch.kind,
				"height": patch.height,
				"lethal": true,
				"patch": patch,
			}
	return best


func project_to_surface(surface_id: String, x: float, z: float, h: float) -> Dictionary:
	if model == null:
		return {"ok": false}
	if model.patches.has(surface_id):
		var patch: SupportPatch = model.patches[surface_id]
		return patch.project(x, z, h)
	if model.pipes.has(surface_id):
		var pipe: PipeSurface = model.pipes[surface_id]
		return pipe.project(x, z, h)
	if model.ramps.has(surface_id):
		var ramp: RampSurface = model.ramps[surface_id]
		return ramp.project(x, z, h)
	if model.walls.has(surface_id):
		var wall: WallSurface = model.walls[surface_id]
		return wall.project(x, z, h)
	return {"ok": false}


## Unique compiled edge for one surface boundary at this Z.
func edge_at(surface_id: String, z: float, boundary: String) -> TopologyEdge:
	if model == null:
		return null
	for eid in model.all_edge_ids():
		var edge: TopologyEdge = model.edges[eid]
		if edge.from_surface_id != surface_id or edge.boundary != boundary:
			continue
		if edge.contains_z(z):
			return edge
	return null


func edge_anchor_sample(edge: TopologyEdge, z: float) -> Dictionary:
	if edge == null or not edge.contains_z(z):
		return {}
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		var ws := wall.sample_at_z(z)
		var cope: CopingEdge = model.copings.get(wall.source_coping_id)
		return {
			"x": float(ws.x),
			"height": float(ws.top_height) if edge.boundary == "top" else float(ws.bottom_height),
			"outward_sign": cope.outward_sign if cope != null else 0.0,
			"source_pipe_id": wall.source_pipe_id,
			"source_surface_id": wall.id,
		}
	if model.pipes.has(edge.from_surface_id):
		var pipe: PipeSurface = model.pipes[edge.from_surface_id]
		return {
			"x": pipe.coping_x_at(z),
			"height": pipe.height_at_theta(z, PI * 0.5),
			"outward_sign": pipe.outward_sign(),
			"source_pipe_id": pipe.id,
			"source_surface_id": pipe.id,
		}
	if model.ramps.has(edge.from_surface_id):
		var ramp: RampSurface = model.ramps[edge.from_surface_id]
		return {
			"x": ramp.coping_x_at(z),
			"height": ramp.height_at_theta(z, PI * 0.5),
			"outward_sign": ramp.outward_sign(),
			"source_pipe_id": "",
			"source_surface_id": ramp.id,
			"source_ramp_id": ramp.id,
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
		var span := cope.span_at_z(z)
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
			"class": span.coping_class if span != null else cope.coping_class,
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
	var earliest := _wall_sweep_contact(from, to)
	var earliest_t := float(earliest.get("t", INF))
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


func _wall_sweep_contact(from: Vector3, to: Vector3) -> Dictionary:
	var best := {}
	var best_t := INF
	for wall_id in model.all_wall_ids():
		var wall: WallSurface = model.walls[wall_id]
		var mid_z := (from.y + to.y) * 0.5
		if not wall.contains_z(mid_z):
			continue
		var ws := wall.sample_at_z(mid_z)
		var wx := float(ws.x)
		var t := INF
		var dx0 := from.x - wx
		var dx1 := to.x - wx
		if dx0 * dx1 <= 0.0 and absf(to.x - from.x) > 0.0001:
			t = clampf((wx - from.x) / (to.x - from.x), 0.0, 1.0)
		elif absf(dx0) <= SimTolerances.CONTACT_EPS \
				and from.z > float(ws.top_height) \
				and to.z <= float(ws.top_height):
			t = clampf(
				(from.z - float(ws.top_height)) / maxf(from.z - to.z, 0.0001),
				0.0,
				1.0
			)
		if t >= best_t:
			continue
		var point := from.lerp(to, t)
		if not wall.contains_z(point.y):
			continue
		ws = wall.sample_at_z(point.y)
		if point.z < float(ws.bottom_height) - SimTolerances.CONTACT_EPS \
				or point.z > float(ws.top_height) + SimTolerances.CONTACT_EPS:
			continue
		var cope: CopingEdge = model.copings[wall.source_coping_id]
		best_t = t
		best = {
			"kind": "wall",
			"feature_id": wall.id,
			"surface_id": wall.id,
			"coping_id": wall.source_coping_id,
			"projection": wall.position_at(point.y, wall.u_at_height(point.y, point.z)),
			"normal": Vector3(-cope.outward_sign, 0.0, 0.0),
			"point": point,
			"t": t,
			"reason": "wall surface crossing",
		}
	return best


func _blocker_at(p: Vector3) -> Dictionary:
	var x := p.x
	var z := p.y
	var h := p.z
	# World walls on the park faces — cannot leave the footprint and fall out.
	# Edge pipe copings sit on x=0 / x=width (and z faces for depth); those poses
	# remain free. Past the face is solid.
	if x < 0.0:
		return {
			"kind": "bounds", "feature_id": "__west__", "axis": "x",
			"sign": -1.0, "normal": Vector3(1, 0, 0), "reason": "west wall",
		}
	if x > model.width:
		return {
			"kind": "bounds", "feature_id": "__east__", "axis": "x",
			"sign": 1.0, "normal": Vector3(-1, 0, 0), "reason": "east wall",
		}
	if z <= 0.0:
		return {
			"kind": "bounds", "feature_id": "__near__", "axis": "z",
			"sign": -1.0, "normal": Vector3(0, 1, 0), "reason": "near wall",
		}
	if z >= model.depth:
		return {
			"kind": "bounds", "feature_id": "__far__", "axis": "z",
			"sign": 1.0, "normal": Vector3(0, -1, 0), "reason": "far wall",
		}
	# Non-playable footprint (space) — solid invisible wall, never fall out.
	var cell := model.cell_at(x, z)
	if not model.is_playable_cell(cell.x, cell.y):
		return {
			"kind": "bounds", "feature_id": "__space__", "axis": "",
			"sign": 0.0, "normal": Vector3.ZERO, "reason": "unplayable cell",
		}
	# Pipe solid interiors are one-sided and exclude the coping boundary.
	for pipe_id in model.all_pipe_ids():
		var pipe: PipeSurface = model.pipes[pipe_id]
		if not pipe.contains_solid_xz(x, z):
			continue
		var proj := pipe.project(x, z, h)
		if not bool(proj.get("ok", false)):
			continue
		var ph := float(proj.point.z)
		if h < ph - SimTolerances.CONTACT_EPS:
			return {
				"kind": "pipe",
				"feature_id": pipe.id,
				"surface_id": pipe.id,
				"projection": proj.point,
				"normal": proj.normal,
				"reason": "through pipe body",
			}
	for ramp_id in model.all_ramp_ids():
		var ramp: RampSurface = model.ramps[ramp_id]
		if not ramp.contains_solid_xz(x, z):
			continue
		var rproj := ramp.project(x, z, h)
		if not bool(rproj.get("ok", false)):
			continue
		var rh := float(rproj.point.z)
		if h < rh - SimTolerances.CONTACT_EPS:
			return {
				"kind": "ramp",
				"feature_id": ramp.id,
				"surface_id": ramp.id,
				"projection": rproj.point,
				"normal": rproj.normal,
				"reason": "through ramp body",
			}
	# Deck platforms: solid below the top — ride on top only, never through the base.
	var patch_ids: Array = model.patches.keys()
	patch_ids.sort()
	for patch_id in patch_ids:
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
		# Wall face owns its full climb band — including the CONTACT_EPS seam
		# above the bottom. A rear-abutting `#` must not steal that band into a
		# deck-body rescue (mid-climb snap onto the pad instead of air-out).
		var wall_owns_boundary := false
		for wall_id in model.all_wall_ids():
			var owner: WallSurface = model.walls[wall_id]
			if not owner.contains_z(z):
				continue
			var owner_sample := owner.sample_at_z(z)
			if absf(x - float(owner_sample.x)) <= 0.001 \
					and h >= float(owner_sample.bottom_height) - SimTolerances.CONTACT_EPS \
					and h <= float(owner_sample.top_height) + SimTolerances.CONTACT_EPS:
				wall_owns_boundary = true
				break
		if wall_owns_boundary:
			continue
		return {
			"kind": "deck",
			"feature_id": patch.id,
			"surface_id": patch.id,
			"projection": Vector3(x, z, patch.height),
			"normal": Vector3(0, 0, 1),
			"reason": "through deck body",
		}
	# Floor-backed wall solids use the exact compiled wall Z span and support
	# patch extent. Cross-story walls are bounded by the upper pipe solid.
	for wall_id in model.all_wall_ids():
		var wall: WallSurface = model.walls[wall_id]
		if not wall.contains_z(z):
			continue
		var ws := wall.sample_at_z(z)
		var wx := float(ws.x)
		var cope: CopingEdge = model.copings[wall.source_coping_id]
		if h >= float(ws.top_height) - SimTolerances.CONTACT_EPS:
			continue
		if h <= float(ws.bottom_height) + SimTolerances.CONTACT_EPS:
			continue
		var on_face := absf(x - wx) <= 0.001
		var in_backing := false
		if not wall.top_support_id.is_empty():
			var patch: SupportPatch = model.patches.get(wall.top_support_id)
			in_backing = (
				patch != null
				and (x - wx) * cope.outward_sign >= -SimTolerances.CONTACT_EPS
				and patch.contains_xz(x, z)
			)
		if on_face or in_backing:
			return {
				"kind": "wall",
				"feature_id": wall.id,
				"surface_id": wall.id,
				"coping_id": wall.source_coping_id,
				"projection": wall.position_at(z, wall.u_at_height(z, h)),
				"normal": Vector3(-cope.outward_sign, 0.0, 0.0),
				"reason": "wall extension",
			}
	return {}
