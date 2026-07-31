class_name AirSolver
extends RefCounted
## Ballistic free air + maneuver execution.


var model: ParkModel
var query: SurfaceQuery
var planner: ManeuverPlanner
var ground: GroundSolver
## Live caps from PlayerSim (absolute |vx| / depth stick scale).
var _max_speed: float = 880.0
var _max_speed_z: float = 400.0


func _init(
	m: ParkModel = null,
	q: SurfaceQuery = null,
	p: ManeuverPlanner = null,
	g: GroundSolver = null,
) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)
	planner = p if p != null else ManeuverPlanner.new(m, query)
	ground = g if g != null else GroundSolver.new(m, query)


func step(
	state: SimState,
	wish: Vector2,
	delta: float,
	max_speed: float = 880.0,
	max_speed_z: float = 400.0,
) -> void:
	if not state.is_airborne() or not state.alive:
		return
	_max_speed = maxf(max_speed, 0.0)
	_max_speed_z = maxf(max_speed_z, 0.0)
	if state.has_maneuver():
		_step_maneuver(state, wish, delta)
		return
	_step_free(state, wish, delta)


## ---- Single-owner air contact pipeline -------------------------------------

func _step_free(state: SimState, wish: Vector2, delta: float) -> void:
	state.note_air_height(state.position.z)
	_integrate_air_wish(state, wish, delta)
	if state.is_hanging():
		_update_hang_apex_facing(state, delta, wish)
	var from := state.position
	if state.is_hanging():
		var from_anchor := _hang_anchor(state, from.y)
		if from_anchor.is_empty():
			state.clear_hang()
		else:
			from.x = float(from_anchor.x)
			state.position.x = from.x
	# Embedded at start: resolve via the same disposition table (no parallel path).
	var embedded := query.blocker_at(from)
	if not embedded.is_empty():
		var ek := str(embedded.get("kind", ""))
		if ek == "pipe" or ek == "ramp" or ek == "deck" or ek == "wall" \
				or ek == "feature_wall" or ek == "bounds":
			embedded["t"] = 0.0
			embedded["point"] = from
			var ann := query.annotate_contact_ownership(embedded, from)
			ann["t"] = 0.0
			ann["point"] = from
			if _resolve_air_contact(state, ann, from, from.z):
				_assert_air_invariants(state)
				return
			from = state.position
	var to := from + Vector3(state.velocity.x, state.velocity.y, state.velocity.z) * delta
	to.x = clampf(to.x, 0.05, maxf(model.width - 0.05, 0.05))
	to.y = clampf(to.y, 0.05, maxf(model.depth - 0.05, 0.05))
	if state.is_hanging():
		var to_anchor := _hang_anchor(state, to.y)
		if not to_anchor.is_empty():
			to.x = float(to_anchor.x)
	var hang_id := state.hang_edge_id if state.is_hanging() else ""
	var contacts := query.collect_air_contacts(from, to, hang_id)
	# Walk contacts in order; Corridor continues to the next, Mount/Reject end the tick.
	for ci in range(contacts.size()):
		var contact: Dictionary = contacts[ci]
		var t := float(contact.get("t", 1.0))
		var at := from.lerp(to, t)
		state.position = from.lerp(to, maxf(t - 0.01, 0.0))
		var disp := _disposition_for_contact(state, contact, from.z)
		# Legacy bounce+_try_land: a wall/bounds Reject must not steal a later
		# Mount (layered inbound onto an upper pipe past a lower wall face).
		if disp == SimKinds.ContactDisposition.REJECT \
				and _stream_has_later_mount(state, contacts, ci, from.z):
			disp = SimKinds.ContactDisposition.CORRIDOR
		if disp == SimKinds.ContactDisposition.CORRIDOR:
			state.position = at
			continue
		if disp == SimKinds.ContactDisposition.MOUNT:
			if _mount_air_contact(state, contact, from.z):
				_assert_air_invariants(state)
				return
			# Mount refused — if a later Mount exists, keep going; else Reject.
			if _stream_has_later_mount(state, contacts, ci, from.z):
				state.position = at
				continue
			disp = SimKinds.ContactDisposition.REJECT
		if disp == SimKinds.ContactDisposition.REJECT:
			_reject_air_contact(state, contact, from)
			_assert_air_invariants(state)
			state.position.y = clampf(
				state.position.y, 0.05, maxf(model.depth - 0.05, 0.05)
			)
			return
	# No Mount/Reject: finish the segment.
	state.position = to
	_ensure_air_outside_slopes(state)
	state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
	_assert_air_invariants(state)


## True when a contact after `index` dispositions to Mount (and can seat).
func _stream_has_later_mount(
	state: SimState, contacts: Array, index: int, from_height: float
) -> bool:
	for j in range(index + 1, contacts.size()):
		var later: Dictionary = contacts[j]
		if _disposition_for_contact(state, later, from_height) \
				== SimKinds.ContactDisposition.MOUNT:
			return true
	return false


func _integrate_air_wish(state: SimState, wish: Vector2, delta: float) -> void:
	var w := wish
	var max_x := _max_speed
	var max_z := _max_speed_z
	if state.is_hanging():
		state.velocity.x = 0.0
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * max_z
	else:
		if absf(w.x) >= 0.15:
			var target := clampf(w.x, -1.0, 1.0) * max_x
			var vx := state.velocity.x
			if w.x * vx < 0.0:
				state.velocity.x = move_toward(vx, target, 800.0 * delta)
			elif absf(vx) < absf(target):
				state.velocity.x = move_toward(vx, target, 800.0 * delta)
		state.velocity.y = 0.0 if absf(w.y) < 0.15 else w.y * max_z
	# Absolute ceiling — gravity/ballistic/seeds may not exceed max_speed X.
	state.velocity.x = clampf(state.velocity.x, -max_x, max_x)
	state.velocity.z += SimTolerances.GRAVITY * delta


## Policy table: state + compiled contact role → Mount / Reject / Corridor.
func _disposition_for_contact(
	state: SimState, contact: Dictionary, from_height: float
) -> int:
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", SimKinds.ContactRole.SOLID))
	var reason := str(contact.get("reason", ""))
	# Hang remount always mounts the retained edge.
	if role == SimKinds.ContactRole.HANG_ANCHOR or kind == "hang_anchor":
		return SimKinds.ContactDisposition.MOUNT
	# Hang: remount retained source, or clear onto flat floor/lava/void.
	# Foreign lips/decks/walls Corridor so opposite-layer coping never steals.
	if state.is_hanging():
		if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
			return SimKinds.ContactDisposition.CORRIDOR
		if role == SimKinds.ContactRole.OPEN_CORRIDOR:
			return SimKinds.ContactDisposition.CORRIDOR
		if _hang_is_flat_land_contact(contact):
			return (
				SimKinds.ContactDisposition.MOUNT
				if state.velocity.z <= SimTolerances.CONTACT_EPS
				else SimKinds.ContactDisposition.CORRIDOR
			)
		if not _hang_owns_contact(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
		if kind == "wall" and state.velocity.z > SimTolerances.CONTACT_EPS * 10.0:
			return SimKinds.ContactDisposition.CORRIDOR
		if role == SimKinds.ContactRole.LIP_COLUMN \
				or kind == "wall" or role == SimKinds.ContactRole.WALL_CLIMB \
				or kind == "pipe" or kind == "support_top" or kind == "ramp":
			return (
				SimKinds.ContactDisposition.MOUNT
				if state.velocity.z <= SimTolerances.CONTACT_EPS
				else SimKinds.ContactDisposition.CORRIDOR
			)
		return SimKinds.ContactDisposition.CORRIDOR
	# Bounds / feature walls.
	if kind == "bounds" or role == SimKinds.ContactRole.BOUNDS:
		if reason == "slope outer back" and _can_land_slope_back(state, contact):
			return SimKinds.ContactDisposition.MOUNT
		# Leaving a `#` pad this bout: its open-side cage must not Reject-freeze
		# the ledge fall into the abutting bowl (coping-aligned edges can miss
		# when a pipe run splits under the deck edge mid-Z sample).
		if reason == "deck open side" \
				and state.air_launch_surface_id == str(contact.get("surface_id", "")):
			return SimKinds.ContactDisposition.CORRIDOR
		return SimKinds.ContactDisposition.REJECT
	# Deck ride-off onto an abutting pipe/ramp/wall: ledge fall / acid only —
	# never ordinary Mount (including lip column after a slow coast off the pad).
	if _deck_ride_off_blocks_slope_contact(state, contact):
		return SimKinds.ContactDisposition.CORRIDOR
	# OPEN corridor from outward — acid only, never ordinary mount.
	if role == SimKinds.ContactRole.OPEN_CORRIDOR:
		return SimKinds.ContactDisposition.CORRIDOR
	# Lip column: pipe/wall owns the land (floor ollie / hang return).
	if role == SimKinds.ContactRole.LIP_COLUMN:
		if state.velocity.z > SimTolerances.CONTACT_EPS * 10.0:
			return SimKinds.ContactDisposition.CORRIDOR
		return SimKinds.ContactDisposition.MOUNT
	# Wall climb face.
	if kind == "wall" or role == SimKinds.ContactRole.WALL_CLIMB:
		if _wall_contact_is_outward_exit(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
		if state.is_hanging() and state.velocity.z <= SimTolerances.CONTACT_EPS:
			return SimKinds.ContactDisposition.MOUNT
		# Layered inbound: lower wall face hands off to compiled upper partner pipe.
		if _wall_inbound_upper_partner_ok(state, contact):
			return SimKinds.ContactDisposition.MOUNT
		if _free_air_may_remount_source_wall(
			state, model.walls.get(str(contact.get("surface_id", ""))) as WallSurface
		):
			return SimKinds.ContactDisposition.MOUNT
		return SimKinds.ContactDisposition.REJECT
	# Outward deck / deck solid / support top on deck.
	if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
		if _deck_mount_gates_ok(state, contact, from_height):
			return SimKinds.ContactDisposition.MOUNT
		# Short same-pad / abutting-slope return near the ride top → Mount.
		if _force_near_pad_deck_land_ok(state, contact):
			return SimKinds.ContactDisposition.MOUNT
		# Skim / underside: Reject with mandatory exterior resolve (no vz kill freeze).
		return SimKinds.ContactDisposition.REJECT
	# Support-top crossing (floor / pipe / ramp / deck already handled above).
	if kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		if sk == SimKinds.SurfaceKind.DECK:
			if _deck_mount_gates_ok(state, contact, from_height):
				return SimKinds.ContactDisposition.MOUNT
			return SimKinds.ContactDisposition.CORRIDOR
		if state.is_hanging() and sk == SimKinds.SurfaceKind.DECK:
			return SimKinds.ContactDisposition.CORRIDOR
		if state.velocity.z > 0.0:
			return SimKinds.ContactDisposition.CORRIDOR
		return SimKinds.ContactDisposition.MOUNT
	# Pipe / ramp body solids.
	if kind == "pipe" or kind == "ramp":
		if state.velocity.z > 80.0:
			return SimKinds.ContactDisposition.CORRIDOR
		if state.is_hanging() and kind == "pipe" and _hang_rejects_pipe_hit(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
		return SimKinds.ContactDisposition.MOUNT
	return SimKinds.ContactDisposition.REJECT


## This air bout left an outward `#` deck onto its abutting slope — ordinary
## lip / support-top Mount is illegal (ledge fall / acid only). Pipe/ramp body
## solids are blocked only while still on the outward/deck side of the coping;
## bowl-side body Mounts stay legal so `===)))####` can land the arc (the path
## to the floor crosses pipe X).
func _deck_ride_off_blocks_slope_contact(state: SimState, contact: Dictionary) -> bool:
	var launch := state.air_launch_surface_id
	if launch.is_empty() or not model.patches.has(launch):
		return false
	var pad: SupportPatch = model.patches[launch]
	if int(pad.kind) != SimKinds.SurfaceKind.DECK:
		return false
	var kind := str(contact.get("kind", ""))
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	if owner.is_empty():
		return false
	var z := state.position.y
	var coping_id := ""
	if model.pipes.has(owner):
		coping_id = model.pipes[owner].coping_id
	elif model.ramps.has(owner):
		coping_id = model.ramps[owner].coping_id
	elif model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		var pipe: PipeSurface = model.pipes.get(wall.source_pipe_id)
		if pipe == null:
			return false
		coping_id = pipe.coping_id
	elif kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		if sk == SimKinds.SurfaceKind.PIPE and model.pipes.has(owner):
			coping_id = model.pipes[owner].coping_id
		elif sk == SimKinds.SurfaceKind.RAMP and model.ramps.has(owner):
			coping_id = model.ramps[owner].coping_id
	if coping_id.is_empty() or not _slope_span_has_outward_deck(coping_id, launch, z):
		return false
	# Body hit past the lip (bowl side) is an ordinary land, not the sticky pad exit.
	if (kind == "pipe" or kind == "ramp") \
			and not _deck_ride_off_still_outward(coping_id, state.position.x, z):
		return false
	return true


func _slope_span_has_outward_deck(coping_id: String, deck_id: String, z: float) -> bool:
	if coping_id.is_empty() or deck_id.is_empty():
		return false
	var cope: CopingEdge = model.copings.get(coping_id)
	if cope == null:
		return false
	var span: CopingSpan = cope.span_at_z(z)
	return span != null and span.outward_deck_id == deck_id


## True while X is still on the outward/deck side of the coping (sticky band).
func _deck_ride_off_still_outward(coping_id: String, x: float, z: float) -> bool:
	var cope: CopingEdge = model.copings.get(coping_id)
	if cope == null:
		return true
	var samp := cope.sample_at_z(z)
	if samp.is_empty():
		return true
	var cx := float(samp.coping_x)
	return (x - cx) * float(cope.outward_sign) > -SimTolerances.CAPSULE_RADIUS


func _can_land_slope_back(state: SimState, contact: Dictionary) -> bool:
	if state.velocity.z >= -SimTolerances.CONTACT_EPS or state.is_hanging():
		return false
	var sid := str(contact.get("surface_id", ""))
	return model.pipes.has(sid) or model.ramps.has(sid)


func _deck_mount_gates_ok(state: SimState, contact: Dictionary, from_height: float) -> bool:
	if state.is_hanging():
		return false
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return false
	var deck_id := str(contact.get("owner_id", contact.get("surface_id", "")))
	# Lip remap may point owner at a pipe/wall — not a deck mount.
	if not model.patches.has(deck_id):
		deck_id = str(contact.get("surface_id", ""))
	var deck: SupportPatch = model.patches.get(deck_id)
	if deck == null or int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return false
	if is_nan(from_height) or from_height <= deck.height + SimTolerances.CONTACT_EPS:
		return false
	if state.air_peak_height <= deck.height + _deck_land_min_above(state, deck.id):
		return false
	return true


func _force_near_pad_deck_land_ok(state: SimState, contact: Dictionary) -> bool:
	var deck_id := str(contact.get("surface_id", ""))
	if not model.patches.has(deck_id):
		return false
	var deck: SupportPatch = model.patches[deck_id]
	if int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return false
	var launch := state.air_launch_surface_id
	if launch != deck_id and not _slope_launch_abuts_deck(launch, deck_id, state.position.y):
		return false
	if not deck.contains_xz(state.position.x, state.position.y):
		return false
	if state.position.z < deck.height - SimTolerances.CAPSULE_RADIUS:
		return false
	if state.position.z > deck.height + SimTolerances.CONTACT_EPS:
		return false
	if state.air_peak_height <= deck.height + SimTolerances.CONTACT_EPS:
		return false
	return true


## Returns true when grounded after mount (tick complete).
func _mount_air_contact(state: SimState, contact: Dictionary, from_height: float) -> bool:
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", SimKinds.ContactRole.SOLID))
	var owner_id := str(contact.get("owner_id", contact.get("surface_id", "")))
	# Hang anchor remount.
	if role == SimKinds.ContactRole.HANG_ANCHOR or kind == "hang_anchor":
		return _try_return_to_anchor(state, from_height)
	# Lip column → mount pipe or wall owner.
	if role == SimKinds.ContactRole.LIP_COLUMN:
		if model.walls.has(owner_id):
			var whit := {
				"kind": "wall",
				"surface_id": owner_id,
				"projection": contact.get("projection", state.position),
			}
			if ground != null and ground._mount_wall_from_hit(
				state, whit, state.position
			):
				return true
			# Fall through to source pipe.
			var wall: WallSurface = model.walls[owner_id]
			owner_id = wall.source_pipe_id
		if model.pipes.has(owner_id):
			return _mount_pipe_owner(state, owner_id, contact)
		if model.ramps.has(owner_id):
			return _mount_ramp_owner(state, owner_id, contact)
	# Slope outer-back land.
	if kind == "feature_wall" and str(contact.get("reason", "")) == "slope outer back":
		return _try_land_through_slope_back(state, contact, from_height)
	# Support top / solid mount via existing snap + land helpers.
	if kind == "support_top":
		return _mount_support_top(state, contact, from_height)
	# Remap owner into a solid-shaped hit for snap.
	var hit := contact.duplicate()
	hit["surface_id"] = owner_id if not owner_id.is_empty() else str(contact.get("surface_id", ""))
	if role == SimKinds.ContactRole.LIP_COLUMN and model.pipes.has(hit["surface_id"]):
		hit["kind"] = "pipe"
	elif model.walls.has(hit["surface_id"]) or kind == "wall" \
			or role == SimKinds.ContactRole.WALL_CLIMB:
		hit["kind"] = "wall"
		hit["surface_id"] = str(contact.get("surface_id", hit["surface_id"]))
	elif model.patches.has(hit["surface_id"]):
		hit["kind"] = "deck"
	if _snap_onto_solid(state, hit, from_height):
		return true
	# Near-pad deck force mount.
	if hit.get("kind", "") == "deck" and _force_near_pad_deck_land(state, hit):
		return true
	return false


## Free-air approach into a wall that compiles an upper partner pipe (layered
## inbound). Same gate as `_snap_onto_solid`'s wall→partner handoff.
func _wall_inbound_upper_partner_ok(state: SimState, contact: Dictionary) -> bool:
	if state.is_hanging():
		return false
	var wall: WallSurface = model.walls.get(str(contact.get("surface_id", "")))
	if wall == null or wall.upper_partner_pipe_id.is_empty():
		return false
	var partner: PipeSurface = model.pipes.get(wall.upper_partner_pipe_id)
	if partner == null:
		return false
	return (
		(partner.side == SimKinds.PipeSide.LEFT and state.velocity.x > 0.0)
		or (partner.side == SimKinds.PipeSide.RIGHT and state.velocity.x < 0.0)
	)

func _mount_pipe_owner(state: SimState, pipe_id: String, contact: Dictionary) -> bool:
	var pipe: PipeSurface = model.pipes.get(pipe_id)
	if pipe == null:
		return false
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	var z := state.position.y
	var proj := pipe.project(state.position.x, z, state.position.z)
	var role := int(contact.get("role", -1))
	var force_lip := (
		role == SimKinds.ContactRole.LIP_COLUMN
		or str(contact.get("kind", "")) == "support_top"
	)
	if bool(proj.get("ok", false)) and _pipe_snap_allowed(state, pipe, proj):
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if not force_lip and not bool(proj.get("ok", false)):
		return false
	# Lip-column / coping seat: drop into the bowl just under the lip.
	var theta := PI * 0.5 * 0.92
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = pipe.id
	state.u = theta / (PI * 0.5)
	state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	state.position = Vector3(pipe.x_at_theta(z, theta), z, pipe.height_at_theta(z, theta))
	state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	return true


func _mount_ramp_owner(state: SimState, ramp_id: String, contact: Dictionary) -> bool:
	var ramp: RampSurface = model.ramps.get(ramp_id)
	if ramp == null:
		return false
	var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
	if not bool(rproj.get("ok", false)):
		return false
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = ramp.id
	state.u = float(rproj.u)
	state.v = float(rproj.v)
	state.position = rproj.point
	state.tangent_velocity = Vector2(-maxf(impact, 80.0), state.velocity.y)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	return true


func _mount_support_top(state: SimState, contact: Dictionary, from_height: float) -> bool:
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	var sk := int(contact.get("support_kind", -1))
	# Ownership may have remapped a deck support_top onto a pipe lip.
	if model.pipes.has(sid):
		return _mount_pipe_owner(state, sid, contact)
	if model.ramps.has(sid):
		return _mount_ramp_owner(state, sid, contact)
	if model.walls.has(sid):
		var whit := {
			"kind": "wall",
			"surface_id": sid,
			"projection": contact.get("projection", state.position),
		}
		return ground != null and ground._mount_wall_from_hit(state, whit, state.position)
	if not model.patches.has(sid):
		return false
	var patch: SupportPatch = model.patches[sid]
	if int(patch.kind) == SimKinds.SurfaceKind.DECK:
		if not _deck_mount_gates_ok(state, contact, from_height) \
				and not _force_near_pad_deck_land_ok(state, contact):
			return false
	var sh := float(contact.get("height", patch.height))
	if state.position.z > sh + SimTolerances.CONTACT_EPS:
		return false
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = sid
	state.u = 0.0
	state.v = 0.0
	state.position = Vector3(state.position.x, state.position.y, sh)
	state.tangent_velocity = Vector2(state.velocity.x, state.velocity.y)
	state.velocity = Vector3.ZERO
	state.facing_yaw = 0.0
	state.clear_hang()
	state.clear_air_peak()
	if patch.lethal:
		state.alive = false
	return true


## Reject: stay exterior with normal-consistent velocity. Never kill vertical while
## still intersecting (that was the underside freeze).
func _reject_air_contact(state: SimState, contact: Dictionary, from: Vector3) -> void:
	var kind := str(contact.get("kind", ""))
	var normal: Vector3 = contact.get("normal", Vector3.ZERO)
	if kind == "bounds" or kind == "feature_wall":
		_resolve_bounds_hit(state, contact, from)
		_ensure_air_outside_slopes(state)
		return
	# Prefer projecting out along the contact normal.
	if normal.length_squared() > 0.0001:
		state.velocity = _reject_into_normal(state.velocity, normal)
		var pt: Vector3 = contact.get("projection", contact.get("point", state.position))
		state.position = pt + normal.normalized() * SimTolerances.CONTACT_EPS
		_push_out_of_solids(state, normal)
	else:
		_bounce_off_solid_no_vz_kill(state, contact, from)
	_ensure_air_outside_slopes(state)


## Like _bounce_off_solid but never zeroes descending vz (freeze root cause).
func _bounce_off_solid_no_vz_kill(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var kind := str(hit.get("kind", ""))
	if kind == "pipe" or kind == "ramp":
		_bounce_off_solid(state, hit, from)
		return
	if kind == "wall":
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(normal.x) > 0.001 and state.velocity.x * normal.x < 0.0:
			state.velocity.x = 0.0
		_depenetrate(state, from)
		return
	# Deck / fallback: depenetrate without killing vertical — gravity continues;
	# next tick's support_top / lip owner will Mount.
	_depenetrate(state, from)
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y


## Embedded solid at segment start — returns true if the tick is finished (Mount).
func _resolve_air_contact(
	state: SimState, contact: Dictionary, from: Vector3, from_height: float
) -> bool:
	var disp := _disposition_for_contact(state, contact, from_height)
	if disp == SimKinds.ContactDisposition.CORRIDOR:
		return false
	if disp == SimKinds.ContactDisposition.MOUNT:
		if _mount_air_contact(state, contact, from_height):
			return true
		disp = SimKinds.ContactDisposition.REJECT
	_reject_air_contact(state, contact, from)
	return false


func _assert_air_invariants(state: SimState) -> void:
	if not OS.is_debug_build():
		return
	if state.is_grounded():
		# Mount: sole owner is the grounded surface.
		if state.surface_id.is_empty():
			push_warning("AirSolver invariant: grounded with empty surface_id")
		return
	if not state.is_airborne():
		return
	if query.has_dual_air_owner_at(state.position):
		push_warning(
			"AirSolver invariant: dual air owner at %s" % state.position
		)
	var blk := query.blocker_at(state.position)
	if blk.is_empty():
		return
	var kind := str(blk.get("kind", ""))
	# Hang / OPEN corridor may transit deck volumes; freeze = embedded + vz≈0.
	if kind == "deck" and absf(state.velocity.z) <= 0.01:
		push_warning(
			"AirSolver invariant: embedded in %s with zero vz at %s"
			% [blk.get("surface_id", kind), state.position]
		)
		return
	# After Reject, solids other than pass-through decks must not contain feet.
	if kind == "pipe" or kind == "ramp" or kind == "wall":
		push_warning(
			"AirSolver invariant: residual penetration in %s (%s) at %s"
			% [blk.get("surface_id", kind), kind, state.position]
		)


func _hang_launch_edge(state: SimState) -> TopologyEdge:
	if not state.hang_launch_edge_id.is_empty():
		var launch: TopologyEdge = model.edges.get(state.hang_launch_edge_id)
		if launch != null:
			return launch
	return model.edges.get(state.hang_edge_id) as TopologyEdge


func _hang_launch_pipe(state: SimState) -> PipeSurface:
	var edge := _hang_launch_edge(state)
	if edge == null:
		return null
	if model.pipes.has(edge.from_surface_id):
		return model.pipes[edge.from_surface_id] as PipeSurface
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		return model.pipes.get(wall.source_pipe_id) as PipeSurface
	return null


func _hang_lock_x(state: SimState) -> float:
	var launch := _hang_launch_edge(state)
	if launch == null:
		return state.position.x
	var pipe := _hang_launch_pipe(state)
	if pipe != null:
		var z_ref := clampf(state.position.y, pipe.z_min, pipe.z_max - 0.001)
		var cx := pipe.coping_x_at(z_ref)
		return state.position.x if is_nan(cx) else cx
	var sample := query.edge_anchor_sample(
		launch, clampf(state.position.y, launch.z_min, launch.z_max - 0.001)
	)
	return float(sample.x) if not sample.is_empty() else state.position.x


## Hang may leave the launch edge's Z span. Prefer a same-side OPEN coping whose
## lock X matches; otherwise keep a synthetic X-lock. Leaving Z does **not**
## clear hang — only fly-out / spine / acid / land / remount does.
func _hang_anchor(state: SimState, z: float) -> Dictionary:
	if not state.is_hanging():
		return {}
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge != null:
		var sample := query.edge_anchor_sample(edge, z)
		if not sample.is_empty():
			return sample
	var launch_pipe := _hang_launch_pipe(state)
	if launch_pipe == null:
		return {}
	var lock_x := _hang_lock_x(state)
	var cont := _hang_continuation_edge(z, launch_pipe.side, lock_x)
	if cont != null:
		state.hang_edge_id = cont.id
		var retargeted := query.edge_anchor_sample(cont, z)
		if not retargeted.is_empty():
			return retargeted
	# Gap: no coping at this depth — hold launch lock X and lip height.
	var z_ref := clampf(z, launch_pipe.z_min, launch_pipe.z_max - 0.001)
	return {
		"x": lock_x,
		"height": launch_pipe.height_at_theta(z_ref, PI * 0.5),
		"outward_sign": launch_pipe.outward_sign(),
		"source_pipe_id": launch_pipe.id,
		"source_surface_id": launch_pipe.id,
		"gap": true,
	}


func _hang_continuation_edge(z: float, side: int, lock_x: float) -> TopologyEdge:
	for eid in model.all_edge_ids():
		var edge: TopologyEdge = model.edges[eid]
		if edge == null or edge.kind != SimKinds.EdgeKind.OPEN_COPING:
			continue
		if not edge.contains_z(z):
			continue
		var sample := query.edge_anchor_sample(edge, z)
		if sample.is_empty():
			continue
		var pipe: PipeSurface = model.pipes.get(str(sample.get("source_pipe_id", "")))
		if pipe == null or pipe.side != side:
			continue
		if absf(float(sample.x) - lock_x) > SimTolerances.ALIGN_EPS:
			continue
		return edge
	return null


## Once per air-out: after vertical apex, turn around the body's local Y axis
## into the source pipe over APEX_FACING_DELAY (0 = instant).
func _update_hang_apex_facing(state: SimState, delta: float, wish: Vector2) -> void:
	if state.hang_apex_facing_done:
		return
	var launch := _hang_launch_edge(state)
	# Off the launch edge Z span: keep takeoff orientation (depth transfer).
	if launch == null or not launch.contains_z(state.position.y):
		state.hang_apex_facing_done = true
		state.hang_apex_timer = -1.0
		state.facing_yaw = 0.0
		return
	# Depth stick held: freeze takeoff lean; apex may still fire if they release
	# while remaining on the launch span.
	if absf(wish.y) >= 0.15:
		state.hang_apex_timer = -1.0
		state.facing_yaw = 0.0
		return
	var anchor := query.edge_anchor_sample(launch, state.position.y)
	var pipe: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
	if pipe == null:
		return
	# Into the bowl: opposite the pipe's outward (coping) direction.
	var into := "l" if pipe.outward_sign() > 0.0 else "r"
	if state.hang_apex_timer < 0.0:
		if state.velocity.z > 0.0:
			return
		state.hang_apex_timer = 0.0
		# Signed ±π around local Y into the bowl. Must not use
		# lerp_angle:  ±π are the same angle so it always picks one spin.
		state.hang_apex_from_yaw = 0.0
		state.hang_apex_to_yaw = PI * pipe.outward_sign()
		state.facing_yaw = 0.0
	else:
		state.hang_apex_timer += delta
	var delay := maxf(SimTolerances.APEX_FACING_DELAY, 0.0)
	var t := 1.0 if delay <= 0.0 else clampf(state.hang_apex_timer / delay, 0.0, 1.0)
	state.facing_yaw = lerpf(state.hang_apex_from_yaw, state.hang_apex_to_yaw, t)
	if t < 1.0:
		return
	state.hang_apex_facing_done = true
	# Gameplay faces into the bowl now, but presentation keeps the takeoff-facing
	# reflection until hang exit. R(±π) × old-facing is visually equivalent to
	# R(0) × new-facing, so clear_hang can hand off without a pop.
	state.facing = into
	state.facing_yaw = state.hang_apex_to_yaw


func _anchor_crossing_time(state: SimState, from: Vector3, to: Vector3) -> float:
	if not state.is_hanging() or to.z >= from.z:
		return INF
	var anchor := _hang_anchor(state, to.y)
	# Synthetic gap locks have no remount surface — don't treat lip height as a
	# return crossing while depth-transferring over void / lava.
	if anchor.is_empty() or bool(anchor.get("gap", false)):
		return INF
	var height := float(anchor.height)
	if from.z < height - SimTolerances.CONTACT_EPS \
			or to.z > height + SimTolerances.CONTACT_EPS:
		return INF
	return clampf((from.z - height) / maxf(from.z - to.z, 0.0001), 0.0, 1.0)


## Snap airborne contact with pipe / deck / wall onto that ride surface.
## Returns true when the skater is now grounded on the hit geometry.
## Pipe snaps follow ordinary-land facing rules — never auto spine/acid onto an
## opposite-facing pipe (those need the transfer button).
func _snap_onto_solid(state: SimState, hit: Dictionary, from_height: float = NAN) -> bool:
	var kind := str(hit.get("kind", ""))
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	if kind == "pipe":
		# Rising through a stacked pipe body (layered climb / hang) must not remount.
		if state.velocity.z > SimTolerances.CONTACT_EPS * 10.0 and state.is_hanging():
			return false
		if state.velocity.z > 80.0:
			return false
		var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
		if pipe == null:
			return false
		var proj := _pipe_proj_for_air_hit(state, pipe, hit)
		# Lower-story pipe bodies can wrap under upper lips — prefer a same-side
		# pipe whose surface matches the contact height.
		if not proj.is_empty():
			var dh0 := absf(float(proj.point.z) - state.position.z)
			var max_dh0 := maxf(float(proj.get("radius", 40.0)), 40.0)
			if dh0 > max_dh0:
				proj = {}
		if proj.is_empty():
			return false
		if not _pipe_snap_allowed(state, pipe, proj):
			# Leave position at the contact; bounce handler will depenetrate.
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if kind == "ramp":
		# Ordinary same-facing land / bounce — never hang from ramp peaks.
		if state.velocity.z > 80.0:
			return false
		var ramp: RampSurface = model.ramps.get(str(hit.get("surface_id", "")))
		if ramp == null:
			return false
		var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
		if not bool(rproj.get("ok", false)):
			var rpt: Vector3 = hit.get("projection", state.position)
			rproj = ramp.project(rpt.x, rpt.y, rpt.z)
		if not bool(rproj.get("ok", false)):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = ramp.id
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if kind == "deck":
		if not _deck_descending_cross_ok(state, hit, from_height):
			return false
		var deck_id := str(hit.get("surface_id", ""))
		if not model.patches.has(deck_id):
			return false
		var deck: SupportPatch = model.patches[deck_id]
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = deck.id
		state.u = 0.0
		state.v = 0.0
		var px := clampf(state.position.x, deck.x_min, deck.x_max)
		var pz := clampf(state.position.y, deck.z_min, deck.z_max)
		if deck.contains_xz(state.position.x, state.position.y):
			px = state.position.x
			pz = state.position.y
		state.position = Vector3(px, pz, deck.height)
		state.tangent_velocity = Vector2(state.velocity.x, vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if kind == "wall":
		if ground == null:
			return false
		var wall: WallSurface = model.walls.get(str(hit.get("surface_id", "")))
		# A free-air approach may land the compiled upper ramp. An anchored
		# air-out never takes this path; it returns to the source wall.
		if not state.is_hanging() and wall != null \
				and not wall.upper_partner_pipe_id.is_empty():
			var partner: PipeSurface = model.pipes.get(wall.upper_partner_pipe_id)
			var into_partner := partner != null and (
				(partner.side == SimKinds.PipeSide.LEFT and state.velocity.x > 0.0)
				or (partner.side == SimKinds.PipeSide.RIGHT and state.velocity.x < 0.0)
			)
			if into_partner:
				var z := state.position.y
				var projection := partner.project(
					partner.coping_x_at(z), z, partner.height_at_theta(z, PI * 0.5)
				)
				if bool(projection.get("ok", false)) \
						and _pipe_snap_allowed(state, partner, projection):
					state.mode = SimState.Mode.GROUNDED
					state.surface_id = partner.id
					state.u = float(projection.u)
					state.v = float(projection.v)
					state.position = projection.point
					state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
					state.velocity = Vector3.ZERO
					state.clear_hang()
					state.clear_air_peak()
					return true
		# Ordinary free air never acquires wall ownership — except recovering the
		# launch pipe's wall when hang cleared mid-air at the lock X. Bounce there
		# freezes beside a coplanar abutting deck (leaned, X stuck).
		if not state.is_hanging() and not _free_air_may_remount_source_wall(state, wall):
			return false
		# Rising hang must clear a wall extension (ollie off the geometric seam)
		# without sticky-mounting and climbing into the upper lip/deck.
		if state.velocity.z > SimTolerances.CONTACT_EPS * 10.0:
			return false
		var at: Vector3 = hit.get("projection", hit.get("point", state.position))
		return ground._mount_wall_from_hit(state, hit, at)
	return false


## Descending free air may remount the wall that belongs to this bout's launch
## pipe / wall — hang return without an active hang lock.
func _free_air_may_remount_source_wall(state: SimState, wall: WallSurface) -> bool:
	if wall == null or state.velocity.z > SimTolerances.CONTACT_EPS * 10.0:
		return false
	var launch := state.air_launch_surface_id
	if launch.is_empty():
		return false
	if wall.id == launch or wall.source_pipe_id == launch:
		return true
	if model.walls.has(launch):
		var lw: WallSurface = model.walls[launch]
		return lw != null and lw.source_pipe_id == wall.source_pipe_id
	return false


## Project the deterministic pipe feature selected by the solid query.
func _pipe_proj_for_air_hit(state: SimState, pipe: PipeSurface, hit: Dictionary = {}) -> Dictionary:
	var proj := pipe.project(state.position.x, state.position.y, state.position.z)
	if bool(proj.get("ok", false)):
		return proj
	if not hit.is_empty():
		var pt: Vector3 = hit.get("point", state.position)
		proj = pipe.project(pt.x, pt.y, pt.z)
		if bool(proj.get("ok", false)):
			return proj
	return {}


## A deck-backed OPEN span is compiled as action-only. Ordinary contact from its
## outward coping corridor may pass through for deck→bowl drops; deep body under
## the arc is solid (ollie / lateral flight must clear peak or collide).
func _pipe_snap_allowed(state: SimState, pipe: PipeSurface, proj: Dictionary) -> bool:
	if state.is_hanging():
		var anchor := _hang_anchor(state, state.position.y)
		var source: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if source != null and pipe.side != source.side:
			return false
	else:
		# Deck ledge leave onto this pipe's outward `#` — acid only, even on lip.
		if _slope_span_has_outward_deck(
			pipe.coping_id, state.air_launch_surface_id, state.position.y
		):
			return false
		var cx := pipe.coping_x_at(state.position.y)
		var out := pipe.outward_sign()
		var from_outward := not is_nan(cx) and (state.position.x - cx) * out >= -SimTolerances.CAPSULE_RADIUS
		# Past the coping into an outward deck needs acid — the coping column itself
		# remains a legal ordinary pipe land (lip owner) for non-deck launches.
		var clearly_outward := (
			not is_nan(cx)
			and (state.position.x - cx) * out > SimTolerances.CAPSULE_RADIUS
		)
		var cope: CopingEdge = model.copings.get(pipe.coping_id)
		var span: CopingSpan = cope.span_at_z(state.position.y) if cope != null else null
		if clearly_outward and span != null and not span.outward_deck_id.is_empty():
			return false
		if not from_outward:
			# Rising / lateral entry still needs clear travel facing. Descending
			# remounts (short ollie, low |vx|) must not reject the contact surface.
			if state.velocity.z > 0.0:
				var vx := state.velocity.x
				if absf(vx) < 1.0:
					return false
				var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
				if pipe.side != want:
					return false
	var cand := {
		"surface_id": pipe.id,
		"kind": SimKinds.SurfaceKind.PIPE,
		"height": float(proj.point.z),
		"lethal": false,
		"pipe": pipe,
		"proj": proj,
	}
	return not _pick_ordinary_land(state, [cand]).is_empty()


## Rejected pipe/deck/wall contact: push out and kill only into-solid speed.
## Must not zero all velocity (that froze inbound landings on layered right pipes).
func _bounce_off_solid(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var kind := str(hit.get("kind", ""))
	if kind == "pipe":
		var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
		if pipe != null:
			var proj := _pipe_proj_for_air_hit(state, pipe, hit)
			if not proj.is_empty():
				# Sit on the ride surface along the normal — Z-only lift still leaves
				# peak-ward X under a rising slope.
				var n: Vector3 = proj.normal
				var pt: Vector3 = proj.point
				if n.length_squared() > 0.0001:
					state.position = pt + n.normalized() * SimTolerances.CONTACT_EPS
					state.velocity = _reject_into_normal(state.velocity, n)
				else:
					state.position.z = maxf(
						state.position.z, float(pt.z) + SimTolerances.CONTACT_EPS
					)
					if state.velocity.z < 0.0:
						state.velocity.z = 0.0
				# Do not lerp back toward `from` — it is often still inside the solid
				# and would re-bury a clean normal projection.
				_push_out_of_solids(state, n if n.length_squared() > 0.0001 else Vector3.UP)
				return
	if kind == "ramp":
		var ramp: RampSurface = model.ramps.get(str(hit.get("surface_id", "")))
		if ramp != null:
			var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
			if not bool(rproj.get("ok", false)):
				var rpt: Vector3 = hit.get("projection", state.position)
				rproj = ramp.project(rpt.x, rpt.y, rpt.z)
			if bool(rproj.get("ok", false)):
				var rn: Vector3 = rproj.normal
				var rpt2: Vector3 = rproj.point
				if rn.length_squared() > 0.0001:
					state.position = rpt2 + rn.normalized() * SimTolerances.CONTACT_EPS
					state.velocity = _reject_into_normal(state.velocity, rn)
				else:
					state.position.z = maxf(
						state.position.z, float(rpt2.z) + SimTolerances.CONTACT_EPS
					)
					if state.velocity.z < 0.0:
						state.velocity.z = 0.0
				_push_out_of_solids(state, rn if rn.length_squared() > 0.0001 else Vector3.UP)
				return
	if kind == "wall":
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if absf(normal.x) > 0.001 and state.velocity.x * normal.x < 0.0:
			state.velocity.x = 0.0
		# A vertical face never consumes falling speed.
		_depenetrate(state, from)
		return
	# Deck / fallback: walk back along the motion. Hang and rising contacts must
	# not consume height (rear-deck trip / mid fly-out stall).
	if not state.is_hanging() and state.velocity.z < 0.0:
		state.velocity.z = 0.0
	_depenetrate(state, from)
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y


## Drop velocity into a surface normal so free-air never keeps drilling underground.
func _reject_into_normal(world: Vector3, normal: Vector3) -> Vector3:
	if normal.length_squared() < 0.0001:
		return world
	var n := normal.normalized()
	var vn := world.dot(n)
	if vn < 0.0:
		return world - n * vn
	return world


## If still inside a solid after a normal projection, step along `hint_n` (not
## back toward an embedded `from`).
func _push_out_of_solids(state: SimState, hint_n: Vector3) -> void:
	if query.blocker_at(state.position).is_empty():
		return
	var step := hint_n.normalized() * SimTolerances.CONTACT_EPS
	if step.length_squared() < 0.0001:
		step = Vector3(0.0, 0.0, SimTolerances.CONTACT_EPS)
	for _i in range(16):
		if query.blocker_at(state.position).is_empty():
			return
		state.position += step
	# Last resort: project onto whatever solid owns the feet.
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind == "pipe" or kind == "ramp":
		var sid := str(hit.get("surface_id", ""))
		var surf = model.pipes.get(sid)
		if surf == null:
			surf = model.ramps.get(sid)
		if surf != null:
			var proj: Dictionary = surf.project(
				state.position.x, state.position.y, state.position.z
			)
			if bool(proj.get("ok", false)):
				var n2: Vector3 = proj.normal
				state.position = (
					proj.point + n2.normalized() * SimTolerances.CONTACT_EPS
				)
				state.velocity = _reject_into_normal(state.velocity, n2)


func _wall_contact_is_outward_exit(state: SimState, hit: Dictionary) -> bool:
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	return absf(normal.x) > 0.001 and state.velocity.x * normal.x > 0.0


## Air crossing a slope outer-back face may still ordinary-land onto that slope.
func _try_land_through_slope_back(state: SimState, hit: Dictionary, from_height: float) -> bool:
	# Only descending approaches — rising fly-outs / hangs must clear the back.
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return false
	if state.is_hanging():
		return false
	var sid := str(hit.get("surface_id", ""))
	var z := state.position.y
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	if model.pipes.has(sid):
		var pipe: PipeSurface = model.pipes[sid]
		var inward_x := pipe.coping_x_at(z) - pipe.outward_sign() * SimTolerances.CONTACT_EPS
		var proj := pipe.project(inward_x, z, state.position.z)
		if not bool(proj.get("ok", false)):
			return false
		if not _pipe_snap_allowed(state, pipe, proj):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = pipe.id
		state.u = float(proj.u)
		state.v = float(proj.v)
		state.position = proj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if model.ramps.has(sid):
		var ramp: RampSurface = model.ramps[sid]
		var rin := ramp.coping_x_at(z) - ramp.outward_sign() * SimTolerances.CONTACT_EPS
		var rproj := ramp.project(rin, z, state.position.z)
		if not bool(rproj.get("ok", false)):
			return false
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = ramp.id
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	return false


## Bounds / space / feature walls — stop into-wall motion; never crash.
func _resolve_bounds_hit(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var axis := str(hit.get("axis", ""))
	var kind := str(hit.get("kind", ""))
	if axis == "x":
		state.velocity.x = 0.0
	elif axis == "z":
		state.velocity.y = 0.0
	else:
		state.velocity.x = 0.0
		state.velocity.y = 0.0
	if kind == "feature_wall":
		# Push back along the motion; do not snap to park AABB faces.
		_depenetrate(state, from)
		var clamped_fw := model.clamp_xz(state.position.x, state.position.y)
		state.position.x = clamped_fw.x
		state.position.y = clamped_fw.y
		state.position.z = maxf(state.position.z, SimTolerances.VOID_FLOOR)
		return
	var clamped := model.clamp_xz(state.position.x, state.position.y)
	state.position.x = clamped.x
	state.position.y = clamped.y
	if axis == "x":
		var inset := 0.05
		state.position.x = (
			inset if float(hit.get("sign", 0.0)) < 0.0
			else maxf(model.width - inset, inset)
		)
	state.position.z = maxf(state.position.z, SimTolerances.VOID_FLOOR)
	_depenetrate(state, from)


## Walk back toward `from` until the capsule is outside solids.
## Never snap to an embedded `from` — that re-buries slope bounces.
func _depenetrate(state: SimState, from: Vector3) -> void:
	if query.blocker_at(state.position).is_empty():
		return
	if query.blocker_at(from).is_empty():
		for _i in range(12):
			if query.blocker_at(state.position).is_empty():
				return
			state.position = state.position.lerp(from, 0.35)
		if query.blocker_at(state.position).is_empty():
			return
		state.position = from
		return
	_push_out_of_solids(state, Vector3(0.0, 0.0, 1.0))


## Free-air must not remain under a pipe/ramp ride surface (chord cuts / stick drill).
func _ensure_air_outside_slopes(state: SimState) -> void:
	if not state.is_airborne():
		return
	var hit := query.blocker_at(state.position)
	if hit.is_empty():
		return
	var kind := str(hit.get("kind", ""))
	if kind != "pipe" and kind != "ramp":
		return
	if _snap_onto_solid(state, hit, state.position.z):
		return
	_bounce_off_solid(state, hit, state.position)


func _step_maneuver(state: SimState, wish: Vector2, delta: float) -> void:
	var plan: ManeuverPlan = state.maneuver
	if plan.kind == ManeuverPlan.Kind.TRANSFER:
		_step_transfer(state, wish, delta, plan)
		return
	if plan.kind != ManeuverPlan.Kind.FLY_OUT:
		state.maneuver = null
		_step_free(state, wish, delta)
		return
	# Unlock into free air with the plan's outward seed; stick may steer after.
	# Fly-out / deck-out stands the skater upright (no carried pipe lean).
	state.velocity = plan.start_velocity
	state.velocity.x = clampf(state.velocity.x, -_max_speed, _max_speed)
	state.maneuver = null
	state.clear_hang()
	state.free_air_upright = true
	state.note_air_height(state.position.z)
	_step_free(state, wish, delta)


## Transfer: time-phased progress 0→1 — never from lateral X.
## Lateral X + lean are outputs of that progress. Completes on lip touch.
func _step_transfer(
	state: SimState, wish: Vector2, delta: float, plan: ManeuverPlan
) -> void:
	state.clear_hang()
	if not plan.hold_facing.is_empty():
		state.facing = plan.hold_facing
		# Keep presentation facing with gameplay for the pull (no apex flip).
		state.visual_facing = plan.hold_facing
		state.facing_yaw = 0.0
	var prev_h := state.position.z
	state.velocity.z += SimTolerances.GRAVITY * delta
	if absf(wish.y) >= 0.15:
		state.velocity.y = wish.y * _max_speed_z
	else:
		state.velocity.y = 0.0
	state.velocity.x = 0.0
	plan.elapsed += delta
	state.position.y += state.velocity.y * delta
	state.position.z += state.velocity.z * delta
	state.position.y = clampf(state.position.y, 0.05, maxf(model.depth - 0.05, 0.05))
	state.note_air_height(state.position.z)
	var touched := (
		prev_h > plan.land_height - SimTolerances.CONTACT_EPS
		and state.position.z <= plan.land_height + SimTolerances.CONTACT_EPS
		and state.velocity.z <= 0.0
	)
	# Clock through apex at constant rate — never stall when vz≈0.
	# Cap below 1 until lip touch so a short land_time cannot finish early.
	var t := plan.transfer_progress_at_elapsed(plan.elapsed)
	if touched:
		state.position.z = plan.land_height
		t = 1.0
	else:
		t = minf(t, 0.999)
	plan.progress = t
	# Dependent outputs — not drivers.
	state.position.x = lerpf(plan.start_position.x, plan.land_x, t)
	if t < 1.0:
		_assert_air_invariants(state)
		return
	state.position.x = plan.land_x
	state.velocity.x = 0.0
	state.maneuver = null
	if _anchor_transfer_dest_hang(state, plan):
		_assert_air_invariants(state)
		return
	_step_free(state, wish, delta)


## Switch air-out ownership onto the transfer destination open edge. Shared-X
## spines (L1 left ↔ L0 wall) need this — X lerp alone does not change lip.
func _anchor_transfer_dest_hang(state: SimState, plan: ManeuverPlan) -> bool:
	var edge := query.open_hang_edge_for_coping(plan.dest_coping_id, state.position.y)
	if edge == null:
		return false
	var launch_id := edge.from_surface_id
	if launch_id.is_empty():
		return false
	state.air_launch_surface_id = launch_id
	state.begin_hang(edge.id)
	if not plan.hold_facing.is_empty():
		state.facing = plan.hold_facing
		state.visual_facing = plan.hold_facing
		state.facing_yaw = 0.0
	var anchor := query.edge_anchor_sample(edge, state.position.y)
	if not anchor.is_empty():
		state.position.x = float(anchor.x)
	# Skip apex spin when held facing already points into the dest bowl.
	var pipe: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
	if pipe != null:
		var into := "l" if pipe.outward_sign() > 0.0 else "r"
		if state.facing == into:
			state.hang_apex_facing_done = true
	state.note_air_height(state.position.z)
	return true


func _try_land(state: SimState, from_height: float = NAN) -> void:
	if state.velocity.z > 0.0:
		return ## still rising
	if state.is_hanging() and _try_return_to_anchor(state, from_height):
		return
	# Search ceiling must be the pre-step height so a tunnel below the pad still
	# sees the surface we crossed this tick (supports_below ignores pads above feet).
	var search_h := state.position.z + SimTolerances.CONTACT_EPS
	if not is_nan(from_height):
		search_h = maxf(search_h, from_height + SimTolerances.CONTACT_EPS)
	var candidates := query.supports_below(state.position.x, state.position.y, search_h)
	var top := _pick_ordinary_land(state, candidates)
	if top.is_empty():
		return
	# Hang return is source pipe/wall only — never sticky-mount a pad under the lock.
	if state.is_hanging() and int(top.kind) == SimKinds.SurfaceKind.DECK:
		return
	var sh := float(top.height)
	# Still above the pad — not a landing this tick.
	if state.position.z > sh + SimTolerances.CONTACT_EPS:
		return
	# Require a descending crossing (or already penetrating) of this pad.
	if not is_nan(from_height) and from_height < sh - SimTolerances.CONTACT_EPS:
		return
	# Decks: must be descending onto the pad, and this air bout must have peaked
	# well above it — lip/apex skims (peak ≈ pad) must not sticky-mount.
	# Same-pad ollie returns only need to have cleared the pad (CONTACT_EPS).
	if int(top.kind) == SimKinds.SurfaceKind.DECK:
		if state.velocity.z >= -SimTolerances.CONTACT_EPS:
			return
		if is_nan(from_height) or from_height <= sh + SimTolerances.CONTACT_EPS:
			return
		if state.air_peak_height <= sh + _deck_land_min_above(state, str(top.surface_id)):
			return
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var vz := state.velocity.y
	var was_hanging := state.is_hanging()
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = str(top.surface_id)
	state.position.z = sh
	if int(top.kind) == SimKinds.SurfaceKind.PIPE:
		var pipe: PipeSurface = model.pipes.get(state.surface_id)
		# Air-out onto same-facing pipe (exit or X-aligned other): snap lip, into bowl.
		if was_hanging and pipe != null:
			var z := state.position.y
			state.u = 1.0
			state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
			state.position = Vector3(
				pipe.x_at_theta(z, PI * 0.5),
				z,
				pipe.height_at_theta(z, PI * 0.5)
			)
			state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
		else:
			var proj: Dictionary = top.proj
			state.u = float(proj.u)
			state.v = float(proj.v)
			state.position = proj.point
			# Drop-in: negative along always rides into the bowl (toward lip).
			state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	elif int(top.kind) == SimKinds.SurfaceKind.RAMP:
		var rproj: Dictionary = top.proj
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
	else:
		# Flat land from hang: drop X-lock / lip lean; coast with world XZ.
		state.u = 0.0
		state.v = 0.0
		state.tangent_velocity = Vector2(state.velocity.x, state.velocity.y)
		state.facing_yaw = 0.0
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	if top.get("lethal", false):
		state.alive = false


## True when free air may ground on this deck hit: not hang, clearly descending
## across the ride top, and this air bout peaked well above the pad.
func _deck_descending_cross_ok(state: SimState, hit: Dictionary, from_height: float) -> bool:
	if state.is_hanging():
		return false
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return false
	var deck: SupportPatch = model.patches.get(str(hit.get("surface_id", "")))
	if deck == null or int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return false
	if is_nan(from_height) or from_height <= deck.height + SimTolerances.CONTACT_EPS:
		return false
	if state.air_peak_height <= deck.height + _deck_land_min_above(state, deck.id):
		return false
	# Floor / bowl ollies that meet the coping column: pipe owns the land —
	# abutting outward decks must not sticky-mount at the lip.
	if _deck_is_pipe_coping_corridor(state, deck.id):
		return false
	return true


## Feet sit on/near a pipe coping (or its bowl side) that this deck abuts.
## Past the coping into the deck (clearly outward) is fly-out land space.
func _deck_is_pipe_coping_corridor(state: SimState, deck_id: String) -> bool:
	if deck_id.is_empty():
		return false
	var z := state.position.y
	var x := state.position.x
	for pipe_id in model.all_pipe_ids():
		var pipe: PipeSurface = model.pipes[pipe_id]
		if pipe == null or z < pipe.z_min - 0.01 or z > pipe.z_max + 0.01:
			continue
		if not _slope_launch_abuts_deck(pipe.id, deck_id, z):
			continue
		var cx := pipe.coping_x_at(z)
		if is_nan(cx):
			continue
		var out := pipe.outward_sign()
		if (x - cx) * out > SimTolerances.CAPSULE_RADIUS:
			continue
		return true
	return false


## Lip skims need a tall peak gate; same-pad ollie returns only need to clear CONTACT_EPS.
func _deck_land_min_above(state: SimState, deck_id: String) -> float:
	if not deck_id.is_empty() and state.air_launch_surface_id == deck_id:
		return SimTolerances.CONTACT_EPS
	return SimTolerances.DECK_LAND_MIN_ABOVE


## Deck lies on the inward (bowl) side of the launch slope's coping — typically the
## rear pad of an opposite stacked pipe. Not a legal outward remount target.
func _hang_rejects_pipe_hit(state: SimState, hit: Dictionary) -> bool:
	var pipe: PipeSurface = model.pipes.get(str(hit.get("surface_id", "")))
	if pipe == null:
		return false
	var source := _hang_launch_pipe(state)
	return source != null and pipe.side != source.side


## True when this contact's owner is the retained hang source (wall and/or its
## pipe). Foreign lips — including opposite-layer coping under the X-lock — are
## not owned and must Corridor.
func _hang_owns_contact(state: SimState, contact: Dictionary) -> bool:
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	if owner.is_empty():
		return false
	var edge := _hang_launch_edge(state)
	if edge != null and owner == edge.from_surface_id:
		return true
	var cur: TopologyEdge = model.edges.get(state.hang_edge_id)
	if cur != null and owner == cur.from_surface_id:
		return true
	var src_pipe := _hang_launch_pipe(state)
	if src_pipe != null and owner == src_pipe.id:
		return true
	if model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		if edge != null and wall.id == edge.from_surface_id:
			return true
		if src_pipe != null and wall.source_pipe_id == src_pipe.id:
			return true
	return false


## Hang may clear onto floor / lava / void when no remountable source is under
## the lock. Decks stay Corridor (never sticky-mount a pad under X-lock).
func _hang_is_flat_land_contact(contact: Dictionary) -> bool:
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	if sid == "__void_floor__" or sid == "__park_floor__":
		return true
	var kind := str(contact.get("kind", ""))
	if kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		return sk == SimKinds.SurfaceKind.FLOOR or sk == SimKinds.SurfaceKind.LAVA
	var patch: SupportPatch = model.patches.get(sid)
	if patch == null:
		return false
	var pk := int(patch.kind)
	return pk == SimKinds.SurfaceKind.FLOOR or pk == SimKinds.SurfaceKind.LAVA


## True when the air bout began on a pipe/ramp whose coping opens onto this deck
## on the outward side. Inward / opposite-pipe rear decks that only share the
## coping X must not count (they steal L0 air-out remounts).
func _slope_launch_abuts_deck(launch_id: String, deck_id: String, z: float) -> bool:
	if launch_id.is_empty() or deck_id.is_empty():
		return false
	var surf = model.pipes.get(launch_id)
	if surf == null:
		surf = model.ramps.get(launch_id)
	if surf == null and model.walls.has(launch_id):
		var wall: WallSurface = model.walls[launch_id]
		surf = model.pipes.get(wall.source_pipe_id)
	if surf == null:
		return false
	var cope: CopingEdge = model.copings.get(str(surf.coping_id))
	if cope == null:
		return false
	var span: CopingSpan = cope.span_at_z(z)
	if span != null and span.outward_deck_id == deck_id:
		return true
	var deck: SupportPatch = model.patches.get(deck_id)
	if deck == null:
		return false
	var cx := float(surf.coping_x_at(z))
	if is_nan(cx):
		return false
	var out := float(surf.outward_sign())
	# Outward deck sits on the +outward side of the coping edge.
	if out > 0.0:
		return absf(cx - deck.x_min) <= SimTolerances.ALIGN_EPS
	return absf(cx - deck.x_max) <= SimTolerances.ALIGN_EPS


## Descending into a deck volume near the ride top after the skim gate rejected a
## land — mount instead of bouncing forever against the underside (pose reset to
## `from`, vz killed → airborne freeze). Only for bouts that left an abutting
## slope / same pad, so generic lip/apex skims stay free.
func _force_near_pad_deck_land(state: SimState, hit: Dictionary) -> bool:
	var deck_id := str(hit.get("surface_id", ""))
	if not model.patches.has(deck_id):
		return false
	var deck: SupportPatch = model.patches[deck_id]
	if int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return false
	var launch := state.air_launch_surface_id
	if launch != deck_id and not _slope_launch_abuts_deck(launch, deck_id, state.position.y):
		return false
	if not deck.contains_xz(state.position.x, state.position.y):
		return false
	# Only the band just under the ride top (not a deep fall through the volume).
	if state.position.z < deck.height - SimTolerances.CAPSULE_RADIUS:
		return false
	if state.position.z > deck.height + SimTolerances.CONTACT_EPS:
		return false
	if state.air_peak_height <= deck.height + SimTolerances.CONTACT_EPS:
		return false
	var vz := state.velocity.y
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = deck.id
	state.u = 0.0
	state.v = 0.0
	state.position = Vector3(state.position.x, state.position.y, deck.height)
	state.tangent_velocity = Vector2(state.velocity.x, vz)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	return true


## Descending through the current hang edge (launch or depth-retargeted) returns
## to its source pipe or wall with fall speed preserved. Wall-top returns seat
## just under the lip so motion carries into the bowl — never perch at u=1 on a
## coplanar deck.
func _try_return_to_anchor(state: SimState, from_height: float) -> bool:
	# May retarget hang_edge_id onto a colinear same-side OPEN edge at this Z.
	var anchor := _hang_anchor(state, state.position.y)
	if anchor.is_empty() or bool(anchor.get("gap", false)):
		return false
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge == null or not edge.contains_z(state.position.y):
		return false
	var height := float(anchor.height)
	if state.position.z > height + SimTolerances.CONTACT_EPS:
		return false
	# Classic remount: descending crossing of the lip this tick.
	var crossed := is_nan(from_height) or from_height >= height - SimTolerances.CONTACT_EPS
	# Depth-transfer recovery: entered a far span already below the lip while
	# still hanging — remount without requiring a fresh above→below crossing.
	var retargeted := (
		not state.hang_launch_edge_id.is_empty()
		and state.hang_edge_id != state.hang_launch_edge_id
	)
	if not crossed and not retargeted:
		return false
	if not crossed and state.velocity.z > 0.0:
		return false
	var impact := maxf(absf(state.velocity.z), absf(state.velocity.x))
	var along := -maxf(impact, 120.0)
	var vz := state.velocity.y
	var z := state.position.y
	state.mode = SimState.Mode.GROUNDED
	state.velocity = Vector3.ZERO
	if model.walls.has(edge.from_surface_id):
		var wall: WallSurface = model.walls[edge.from_surface_id]
		var sample := wall.sample_at_z(z)
		var top := float(sample.top_height)
		var bottom := float(sample.bottom_height)
		# Just under the lip — hang return is "fall back into the ramp", not a
		# deck-height perch that can stick next to an abutting pad.
		var ride_h := clampf(
			top - maxf(SimTolerances.CONTACT_EPS * 4.0, 2.0),
			bottom + SimTolerances.CONTACT_EPS,
			top
		)
		state.surface_id = wall.id
		state.u = wall.u_at_height(z, ride_h)
		state.v = clampf(
			(z - wall.z_min) / maxf(wall.z_max - wall.z_min, 0.001),
			0.0,
			1.0
		)
		state.position = wall.position_at(z, state.u)
		state.tangent_velocity = Vector2(along, vz)
	elif model.pipes.has(edge.from_surface_id):
		var pipe: PipeSurface = model.pipes[edge.from_surface_id]
		# Into the bowl from the lip (negative along).
		var theta := PI * 0.5 * 0.92
		state.surface_id = pipe.id
		state.u = theta / (PI * 0.5)
		state.v = clampf(
			(z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001),
			0.0,
			1.0
		)
		state.position = Vector3(
			pipe.x_at_theta(z, theta),
			z,
			pipe.height_at_theta(z, theta)
		)
		state.tangent_velocity = Vector2(along, vz)
	else:
		state.surface_id = edge.from_surface_id
		state.u = 1.0
		state.position = Vector3(float(anchor.x), z, height)
		state.tangent_velocity = Vector2(along, vz)
	state.clear_hang()
	state.clear_air_peak()
	return true


## Air-out prefers same-facing X-aligned pipes (remount). If none are available
## at this XZ (outside the pipe / gap), land the nearest flat solid and clear hang.
func _pick_ordinary_land(state: SimState, candidates: Array) -> Dictionary:
	var hang_side := -1
	var lock_x := state.position.x
	if state.is_hanging():
		var anchor := _hang_anchor(state, state.position.y)
		var hp: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", "")))
		if hp != null:
			hang_side = hp.side
			lock_x = float(anchor.x)
	if hang_side >= 0:
		for c in candidates:
			if int(c.kind) != SimKinds.SurfaceKind.PIPE:
				continue
			var pipe: PipeSurface = c.get("pipe")
			if pipe == null or pipe.side != hang_side:
				continue
			var cx := pipe.coping_x_at(state.position.y)
			if is_nan(cx) or absf(cx - lock_x) > SimTolerances.ALIGN_EPS:
				continue
			return c
		# No remountable pipe under the lock — accept floor / deck / lava / void.
		# Pipe bodies that failed the facing/X gate stay excluded.
		for c in candidates:
			if int(c.kind) == SimKinds.SurfaceKind.PIPE:
				continue
			return c
		return {}
	# Free air: a pipe under the coping column (bowl side / on lip) beats an
	# abutting outward deck — floor ollies that land on the coping must drop in,
	# not sticky-mount the pad with zero coast.
	var cope_pipe := _free_air_coping_pipe_candidate(state, candidates)
	if not cope_pipe.is_empty():
		return cope_pipe
	for c in candidates:
		if int(c.kind) == SimKinds.SurfaceKind.RAMP:
			return c
		if int(c.kind) != SimKinds.SurfaceKind.PIPE:
			return c
		var pipe2: PipeSurface = c.get("pipe")
		if pipe2 == null:
			continue
		# Free air: drop-in from outward side, or same-facing travel from the bowl.
		# Deck-backed OPEN from clearly outward needs acid — skip ordinary land.
		# On the coping column itself, the pipe still owns the land.
		var cx2 := pipe2.coping_x_at(state.position.y)
		var out2 := pipe2.outward_sign()
		var from_outward := (
			not is_nan(cx2)
			and (state.position.x - cx2) * out2 >= -SimTolerances.CAPSULE_RADIUS
		)
		var clearly_outward := (
			not is_nan(cx2)
			and (state.position.x - cx2) * out2 > SimTolerances.CAPSULE_RADIUS
		)
		if clearly_outward:
			var cope: CopingEdge = model.copings.get(pipe2.coping_id)
			var span: CopingSpan = cope.span_at_z(state.position.y) if cope != null else null
			if span != null and not span.outward_deck_id.is_empty():
				continue
		if not from_outward and state.velocity.z > 0.0:
			var vx := state.velocity.x
			if absf(vx) < 1.0:
				continue ## no clear travel — skip pipes, prefer flats below
			var want := SimKinds.PipeSide.LEFT if vx < 0.0 else SimKinds.PipeSide.RIGHT
			if pipe2.side != want:
				continue
		return c
	return {}


## Pipe candidate when free-air feet are on/near its coping (not past it onto the
## outward deck). Used so abutting `#` pads cannot steal coping landings.
func _free_air_coping_pipe_candidate(state: SimState, candidates: Array) -> Dictionary:
	var z := state.position.y
	var x := state.position.x
	for c in candidates:
		if int(c.kind) != SimKinds.SurfaceKind.PIPE:
			continue
		var pipe: PipeSurface = c.get("pipe")
		if pipe == null:
			continue
		var cx := pipe.coping_x_at(z)
		if is_nan(cx):
			continue
		var out := pipe.outward_sign()
		if (x - cx) * out > SimTolerances.CAPSULE_RADIUS:
			continue
		# Only override when a same-height abutting deck is also competing.
		var deck_competing := false
		for d in candidates:
			if int(d.kind) != SimKinds.SurfaceKind.DECK:
				continue
			if absf(float(d.height) - float(c.height)) > SimTolerances.SEAM_EPS:
				continue
			if _slope_launch_abuts_deck(pipe.id, str(d.surface_id), z):
				deck_competing = true
				break
		if not deck_competing:
			continue
		return c
	return {}
