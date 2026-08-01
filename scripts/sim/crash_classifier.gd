class_name CrashClassifier
extends RefCounted
## Enumerated sudden-stop fall policy for AirSolver / GroundSolver.


var model: ParkModel
var ollie_lip_frac: float = 0.50


func _init(m: ParkModel = null, lip_frac: float = 0.50) -> void:
	model = m
	ollie_lip_frac = clampf(lip_frac, 0.0, 1.0)


func set_ollie_lip_frac(lip_frac: float) -> void:
	ollie_lip_frac = clampf(lip_frac, 0.0, 1.0)


## `ctx` keys:
## - mode: "reject" | "hang_flat_mount" | "hang_clip" | "ground_contain"
## - u: float (pipe parameter; estimated from position if missing)
## - launch_id: String (defaults to state.air_launch_surface_id)
## - was_hanging: bool (hang_flat_mount after seat)
## - launch_exit: bool (own-slope outer-back peak leave)
## - deck_ride_off: bool (intentional deck open-side leave)
## - launch_outward_deck: bool (air-out into launch slope's abutting `#`)
func is_crash(state: SimState, contact: Dictionary, ctx: Dictionary = {}) -> bool:
	if state == null or model == null or not state.alive or state.falling:
		return false
	var mode := str(ctx.get("mode", "reject"))
	if mode == "hang_flat_mount" or mode == "hang_clip":
		return _hang_flat_crash(state, contact, ctx)
	# Hang remount / corridor must not use the free-air reject bail table.
	if state.is_hanging():
		return false
	if bool(ctx.get("launch_exit", false)) or bool(ctx.get("deck_ride_off", false)) \
			or bool(ctx.get("launch_outward_deck", false)):
		return false
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", SimKinds.ContactRole.SOLID))
	var reason := str(contact.get("reason", ""))
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	if reason == "slope outer back":
		return true
	if kind == "bounds" or role == SimKinds.ContactRole.BOUNDS:
		return true
	# Free-air into an open climb wall / lip fence (no abutting outward `#`).
	# Deck-backed wall tops stay fly-out / deck-out playable.
	if kind == "wall" or role == SimKinds.ContactRole.WALL_CLIMB:
		return _wall_is_open_fence(sid, state.position.y)
	if kind == "feature_wall":
		# Open-side cage of the launch slope's own air-out `#` is not a wipeout.
		if is_launch_outward_deck(state, sid, ctx):
			return false
		return true
	if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
		if is_launch_outward_deck(state, sid, ctx):
			return false
		return true
	if kind == "support_top" \
			and int(contact.get("support_kind", -1)) == SimKinds.SurfaceKind.DECK:
		if is_launch_outward_deck(state, sid, ctx):
			return false
	if is_foreign_pipe_lip_crash(state, contact, ctx):
		return true
	return false


## Climb wall with no abutting outward `#` — free-air smash / lip fence wipeout.
func _wall_is_open_fence(wall_id: String, z: float) -> bool:
	if model == null or wall_id.is_empty() or not model.walls.has(wall_id):
		return false
	var wall: WallSurface = model.walls[wall_id]
	var ws: Dictionary = wall.sample_at_z(z)
	if ws.is_empty():
		return true
	var wx := float(ws.x)
	var cope: CopingEdge = model.copings.get(wall.source_coping_id)
	if cope != null:
		var span: CopingSpan = cope.span_at_z(z)
		if span != null and not span.outward_deck_id.is_empty():
			return false
	for pid in model.patches.keys():
		var pad: SupportPatch = model.patches[pid]
		if int(pad.kind) != SimKinds.SurfaceKind.DECK:
			continue
		if z < pad.z_min - SimTolerances.ALIGN_EPS or z > pad.z_max + SimTolerances.ALIGN_EPS:
			continue
		if (
			absf(pad.x_min - wx) <= SimTolerances.ALIGN_EPS
			or absf(pad.x_max - wx) <= SimTolerances.ALIGN_EPS
		):
			return false
	return true


## Free-air into the outward `#` that backs the launch pipe/ramp coping.
func is_launch_outward_deck(
	state: SimState, deck_id: String, ctx: Dictionary = {}
) -> bool:
	if state == null or model == null or deck_id.is_empty():
		return false
	if not model.patches.has(deck_id):
		return false
	if int((model.patches[deck_id] as SupportPatch).kind) != SimKinds.SurfaceKind.DECK:
		return false
	var launch := str(ctx.get("launch_id", ""))
	if launch.is_empty():
		launch = state.air_launch_surface_id
	if launch.is_empty():
		return false
	var coping_id := ""
	if model.pipes.has(launch):
		coping_id = (model.pipes[launch] as PipeSurface).coping_id
	elif model.ramps.has(launch):
		coping_id = (model.ramps[launch] as RampSurface).coping_id
	else:
		return false
	var cope: CopingEdge = model.copings.get(coping_id)
	if cope == null:
		return false
	var span: CopingSpan = cope.span_at_z(state.position.y)
	return span != null and span.outward_deck_id == deck_id


## Coping span at `z` lists `deck_id` as the outward `#` for `slope_id` (pipe/ramp/wall).
func deck_abuts_slope(deck_id: String, slope_id: String, z: float) -> bool:
	if model == null or deck_id.is_empty() or slope_id.is_empty():
		return false
	if not model.patches.has(deck_id):
		return false
	if int((model.patches[deck_id] as SupportPatch).kind) != SimKinds.SurfaceKind.DECK:
		return false
	var coping_id := ""
	if model.pipes.has(slope_id):
		coping_id = (model.pipes[slope_id] as PipeSurface).coping_id
	elif model.ramps.has(slope_id):
		coping_id = (model.ramps[slope_id] as RampSurface).coping_id
	elif model.walls.has(slope_id):
		var wall: WallSurface = model.walls[slope_id]
		var pipe: PipeSurface = model.pipes.get(wall.source_pipe_id) as PipeSurface
		if pipe == null:
			return false
		coping_id = pipe.coping_id
		var ws: Dictionary = wall.sample_at_z(z)
		if not ws.is_empty():
			var pad: SupportPatch = model.patches[deck_id]
			var wx := float(ws.x)
			if (
				absf(pad.x_min - wx) <= SimTolerances.ALIGN_EPS
				or absf(pad.x_max - wx) <= SimTolerances.ALIGN_EPS
			):
				return true
	else:
		return false
	var cope: CopingEdge = model.copings.get(coping_id)
	if cope == null:
		return false
	var span: CopingSpan = cope.span_at_z(z)
	return span != null and span.outward_deck_id == deck_id


## Pipe / ramp / wall-source-pipe owning this contact (empty if none).
func contact_slope_id(contact: Dictionary) -> String:
	if model == null or contact.is_empty():
		return ""
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	if owner.is_empty():
		return ""
	if model.pipes.has(owner) or model.ramps.has(owner):
		return owner
	if model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		if not wall.source_pipe_id.is_empty() and model.pipes.has(wall.source_pipe_id):
			return wall.source_pipe_id
		return owner
	if str(contact.get("kind", "")) == "support_top":
		var sk := int(contact.get("support_kind", -1))
		if sk == SimKinds.SurfaceKind.PIPE or sk == SimKinds.SurfaceKind.RAMP:
			return owner
	return ""


## Free-air into a foreign pipe's upper ollie-lip band → crash wall (never Mount).
## Deck-launch contact timing is decided by AirSolver's swept surface gate.
func is_foreign_pipe_lip_crash(
	state: SimState, contact: Dictionary, ctx: Dictionary = {}
) -> bool:
	if state == null or model == null or state.is_hanging():
		return false
	var pipe := contact_pipe(contact)
	if pipe == null:
		return false
	if is_same_slope_reentry(state, pipe, ctx):
		return false
	var u := float(ctx.get("u", NAN))
	if is_nan(u):
		u = estimate_pipe_u(pipe, state.position)
	if is_nan(u):
		# Outside the projectable solid (common on the outer back) — still a
		# lip-band crash when height sits in the upper ollie band.
		u = estimate_pipe_u_from_height(pipe, state.position.y, state.position.z)
	if is_nan(u):
		return false
	return u >= 1.0 - clampf(ollie_lip_frac, 0.0, 1.0)


func contact_pipe(contact: Dictionary) -> PipeSurface:
	if model == null or contact.is_empty():
		return null
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	var kind := str(contact.get("kind", ""))
	if kind == "pipe" or int(contact.get("role", -1)) == SimKinds.ContactRole.LIP_COLUMN:
		if model.pipes.has(owner):
			return model.pipes[owner]
	if model.pipes.has(owner):
		return model.pipes[owner]
	if model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		return model.pipes.get(wall.source_pipe_id) as PipeSurface
	if kind == "support_top" \
			and int(contact.get("support_kind", -1)) == SimKinds.SurfaceKind.PIPE:
		return model.pipes.get(owner) as PipeSurface
	return null


func is_same_slope_reentry(state: SimState, pipe: PipeSurface, ctx: Dictionary = {}) -> bool:
	if pipe == null or model == null:
		return false
	var launch := str(ctx.get("launch_id", ""))
	if launch.is_empty() and state != null:
		launch = state.air_launch_surface_id
	if launch.is_empty():
		return false
	if launch == pipe.id:
		return true
	var z := state.position.y if state != null else 0.0
	if model.ramps.has(launch):
		return ramp_abuts_pipe(launch, pipe, z)
	return false


func ramp_abuts_pipe(ramp_id: String, pipe: PipeSurface, z: float) -> bool:
	if ramp_id.is_empty() or pipe == null or model == null:
		return false
	if not model.ramps.has(ramp_id):
		return false
	var ramp: RampSurface = model.ramps[ramp_id]
	if ramp.side != pipe.side:
		return false
	var abut_eps := model.cell_h * 0.5 + 1.0
	var overlap := minf(ramp.z_max, pipe.z_max) - maxf(ramp.z_min, pipe.z_min)
	if overlap < -abut_eps:
		return false
	var z_lo := maxf(ramp.z_min, pipe.z_min)
	var z_hi := minf(ramp.z_max, pipe.z_max)
	var z_probe := z
	if z_hi >= z_lo:
		z_probe = clampf(z, z_lo, z_hi)
	elif absf(ramp.z_min - pipe.z_max) <= abut_eps:
		z_probe = ramp.z_min
	elif absf(ramp.z_max - pipe.z_min) <= abut_eps:
		z_probe = ramp.z_max
	else:
		return false
	var rcx := ramp.coping_x_at(z_probe)
	var pcx := pipe.coping_x_at(z_probe)
	if is_nan(rcx):
		rcx = ramp.coping_x_at(clampf(z_probe, ramp.z_min, ramp.z_max))
	if is_nan(pcx):
		pcx = pipe.coping_x_at(clampf(z_probe, pipe.z_min, pipe.z_max))
	if is_nan(rcx) or is_nan(pcx):
		return false
	return absf(rcx - pcx) <= SimTolerances.ALIGN_EPS


func estimate_pipe_u(pipe: PipeSurface, at: Vector3) -> float:
	if pipe == null:
		return NAN
	var proj := pipe.project(at.x, at.y, at.z)
	if bool(proj.get("ok", false)):
		return float(proj.u)
	return estimate_pipe_u_from_height(pipe, at.y, at.z)


## Recover pipe `u` from height when XZ sits outside the projectable solid
## (outer-back approaches). Pipe: h = base + rise·(1 − cos(u·π/2)).
func estimate_pipe_u_from_height(pipe: PipeSurface, z: float, h: float) -> float:
	if pipe == null:
		return NAN
	var z_ref := clampf(z, pipe.z_min, pipe.z_max - 0.001)
	var sample: Dictionary = pipe.sample_at_z(z_ref)
	if sample.is_empty():
		return NAN
	var base := float(sample.base_height)
	var rise := float(sample.get("rise", sample.radius))
	if rise < 0.001:
		return NAN
	if h < base - SimTolerances.CONTACT_EPS:
		return NAN
	# Clamp into the loft so slightly-above-peak hits still read as lip u.
	var t := clampf((h - base) / rise, 0.0, 1.0)
	var cos_th := clampf(1.0 - t, -1.0, 1.0)
	return acos(cos_th) / (PI * 0.5)


func _hang_flat_crash(state: SimState, contact: Dictionary, ctx: Dictionary) -> bool:
	if state == null:
		return false
	if not state.is_hanging() and not bool(ctx.get("was_hanging", false)):
		return false
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	var surface_id := str(contact.get("surface_id", owner))
	var sid := owner
	if sid == "__void_floor__" or sid == "__park_floor__":
		return true
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", -1))
	var mode := str(ctx.get("mode", ""))
	# Hang X-lock on the coping seam shares volume with the abutting outward `#`.
	# Lip-column remap sets owner→pipe while surface_id stays the `#` — that
	# corridor is air-out / remount space, not a wipeout. Deep pad clips still fall.
	if mode == "hang_clip":
		if role == SimKinds.ContactRole.LIP_COLUMN:
			return false
		if _is_hang_lip_column_deck(state, surface_id, contact):
			return false
		if _is_hang_lip_column_deck(state, owner, contact):
			return false
	if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
		return true
	if kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		return (
			sk == SimKinds.SurfaceKind.FLOOR
			or sk == SimKinds.SurfaceKind.DECK
		)
	if model.patches.has(sid):
		var patch: SupportPatch = model.patches[sid]
		if patch.lethal:
			return false
		var pk := int(patch.kind)
		return pk == SimKinds.SurfaceKind.FLOOR or pk == SimKinds.SurfaceKind.DECK
	return false


## Outward deck of the hang edge's coping, while X-locked on the coping line.
func _is_hang_lip_column_deck(
	state: SimState, deck_id: String, _contact: Dictionary = {}
) -> bool:
	if state == null or model == null or deck_id.is_empty() or not state.is_hanging():
		return false
	if not model.patches.has(deck_id):
		return false
	if int((model.patches[deck_id] as SupportPatch).kind) != SimKinds.SurfaceKind.DECK:
		return false
	var pipe := _hang_source_pipe(state)
	if pipe == null:
		return false
	var cope: CopingEdge = model.copings.get(pipe.coping_id)
	if cope == null:
		return false
	var z := state.position.y
	var span: CopingSpan = cope.span_at_z(z)
	if span == null or span.outward_deck_id != deck_id:
		return false
	var cx := pipe.coping_x_at(z)
	if is_nan(cx):
		return false
	# Deep into the pad (past the lock) is a real flat clip; coping column is not.
	var into_pad := (state.position.x - cx) * pipe.outward_sign()
	return into_pad <= SimTolerances.CAPSULE_RADIUS * 2.0


func _hang_source_pipe(state: SimState) -> PipeSurface:
	if state == null or model == null:
		return null
	var eid := state.hang_launch_edge_id
	if eid.is_empty():
		eid = state.hang_edge_id
	var edge: TopologyEdge = model.edges.get(eid)
	if edge == null:
		return null
	if model.pipes.has(edge.from_surface_id):
		return model.pipes[edge.from_surface_id] as PipeSurface
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		return model.pipes.get(wall.source_pipe_id) as PipeSurface
	return null
