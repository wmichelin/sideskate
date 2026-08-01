class_name AirSolver
extends RefCounted
## Ballistic free air + maneuver execution.


var model: ParkModel
var query: SurfaceQuery
var planner: ManeuverPlanner
var ground: GroundSolver
var crash: CrashClassifier
## Live caps from PlayerSim (absolute |vx| / depth stick scale).
var _max_speed: float = 880.0
var _max_speed_z: float = 400.0
## `air_launch_surface_id` at the start of this air tick (reentry along seeding).
var _bout_launch_id: String = ""


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
	crash = CrashClassifier.new(m)


func _slope_along_from_world_vx(surf, world_vx: float) -> float:
	return world_vx * float(surf.outward_sign())


## Project free-air world velocity onto the slope tangent (X + height).
## Same-slope reentry (ollie / air-out drop-back) always seeds downhill like hang
## remount — clamping to 0 let stick-out climb into a weak coping hang / X-lock.
func _slope_along_from_world_vel(
	surf, world_vel: Vector3, at: Vector3, launch_id: String = ""
) -> float:
	var proj: Dictionary = surf.project(at.x, at.y, at.z)
	if not bool(proj.get("ok", false)):
		return _slope_along_from_world_vx(surf, world_vel.x)
	var t: Vector3 = proj.tangent_along
	var along := world_vel.x * t.x + world_vel.z * t.z
	if not _slope_land_is_reentry(surf, launch_id, at.y):
		return along
	# Hang remount parity: always punch downhill on same-slope return.
	var impact := maxf(absf(world_vel.z), absf(world_vel.x) * 0.5)
	return -maxf(impact, 80.0)


func _launch_id_for_along(state: SimState) -> String:
	if not _bout_launch_id.is_empty():
		return _bout_launch_id
	if state != null:
		return state.air_launch_surface_id
	return ""


func _slope_land_is_reentry(surf, launch_id: String, z: float) -> bool:
	if launch_id.is_empty() or surf == null:
		return false
	var sid := str(surf.id)
	if launch_id == sid:
		return true
	# Z-adjacent ramp ↔ pipe at the same footprint.
	if model.ramps.has(launch_id) and model.pipes.has(sid):
		return _ramp_launch_abuts_pipe(launch_id, model.pipes[sid], z)
	if model.pipes.has(launch_id) and model.ramps.has(sid):
		return _ramp_launch_abuts_pipe(sid, model.pipes[launch_id], z)
	return false


## Ollie / free-air stick into the launch lip while still rising must not remount
## (seeds along≈0 → stick climbs → weak coping hang). Stay airborne until fall.
func _rising_same_slope_reentry(state: SimState, surf) -> bool:
	if state == null or surf == null or state.is_hanging():
		return false
	if state.velocity.z <= SimTolerances.CONTACT_EPS:
		return false
	return _slope_land_is_reentry(surf, _launch_id_for_along(state), state.position.y)


func _contact_slope_surf(contact: Dictionary):
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	if owner.is_empty():
		return null
	if model.pipes.has(owner):
		return model.pipes[owner]
	if model.ramps.has(owner):
		return model.ramps[owner]
	if model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		return model.pipes.get(wall.source_pipe_id)
	return null


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
	# Freeze launch id for this tick so mid-tick clears cannot lose reentry context.
	_bout_launch_id = state.air_launch_surface_id
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
	var raw_to := from + Vector3(state.velocity.x, state.velocity.y, state.velocity.z) * delta
	var to := raw_to
	to.x = clampf(to.x, 0.05, maxf(model.width - 0.05, 0.05))
	to.y = clampf(to.y, 0.05, maxf(model.depth - 0.05, 0.05))
	# Soft AABB clamp keeps feet inside — never samples x>width bounds Reject.
	# Treat rim clamp as a level-wall hit for free-air bail.
	var rim_clamp := (
		absf(raw_to.x - to.x) > 0.0001 or absf(raw_to.y - to.y) > 0.0001
	)
	if state.is_hanging():
		var to_anchor := _hang_anchor(state, to.y)
		if not to_anchor.is_empty():
			to.x = float(to_anchor.x)
		rim_clamp = false
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
		# Crash shells (foreign lip, slope outer back, …) stay Reject — never
		# Corridor past them onto a later support-top Mount (warp to u≈1).
		if disp == SimKinds.ContactDisposition.REJECT \
				and not _reject_blocks_later_mount(state, contact) \
				and _stream_has_later_mount(state, contacts, ci, from.z):
			disp = SimKinds.ContactDisposition.CORRIDOR
		if disp == SimKinds.ContactDisposition.CORRIDOR:
			state.position = at
			# Hang X-lock clipping floor/deck solid → fall (even before a clean land).
			if state.is_hanging() and crash != null and crash.is_crash(
				state, contact, {"mode": "hang_clip", "launch_id": _bout_launch_id}
			):
				state.request_fall = true
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
	# Free-air AABB rim: bail unless bordering deck (edge fly-out) or leaving an
	# edge pipe/ramp whose coping sits on that rim (ollie / peak leave).
	if rim_clamp and not state.falling and state.alive \
			and not _air_rim_has_border_deck(state, to) \
			and not _air_rim_is_launch_slope_edge(state, to):
		state.request_fall = true
		if absf(raw_to.x - to.x) > 0.0001:
			state.velocity.x = 0.0
		if absf(raw_to.y - to.y) > 0.0001:
			state.velocity.y = 0.0
	_assert_air_invariants(state)


## Map-edge clamp over an abutting deck — not a level-wall wipeout.
func _air_rim_has_border_deck(state: SimState, at: Vector3) -> bool:
	var top := query.top_support(
		at.x, at.y, state.position.z + SimTolerances.CAPSULE_RADIUS * 4.0
	)
	if top.is_empty():
		return false
	var sid := str(top.get("surface_id", ""))
	if not model.patches.has(sid):
		return false
	return int((model.patches[sid] as SupportPatch).kind) == SimKinds.SurfaceKind.DECK


## Edge ))) / ((( / >> at the park AABB — free-air leave must not wipe out.
func _air_rim_is_launch_slope_edge(state: SimState, at: Vector3) -> bool:
	var launch := state.air_launch_surface_id
	if launch.is_empty():
		return false
	var surf = model.pipes.get(launch)
	if surf == null:
		surf = model.ramps.get(launch)
	if surf == null:
		return false
	var cx := float(surf.coping_x_at(at.y))
	if is_nan(cx):
		return false
	var band := maxf(model.cell_w * 2.0, SimTolerances.CAPSULE_RADIUS * 4.0)
	if at.x >= model.width - 1.0 and absf(cx - model.width) <= band:
		return true
	if at.x <= 1.0 and absf(cx) <= band:
		return true
	return false


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
	# Hang: remount retained source, or clear onto flat floor/deck/lava/void.
	# Foreign lips/walls Corridor so opposite-layer coping never steals.
	if state.is_hanging():
		if role == SimKinds.ContactRole.OPEN_CORRIDOR:
			return SimKinds.ContactDisposition.CORRIDOR
		# Deck under X-lock stays Corridor while a remountable pipe/wall exists
		# (layered rear decks must not steal). Floor / void / lava Mount→fall.
		# Deck Mount→fall only when no remountable source remains under the lock.
		if _hang_is_flat_land_contact(contact):
			var flat_is_deck := _hang_flat_contact_is_deck(contact)
			if flat_is_deck and _hang_has_remountable_source(state):
				return SimKinds.ContactDisposition.CORRIDOR
			return (
				SimKinds.ContactDisposition.MOUNT
				if state.velocity.z <= SimTolerances.CONTACT_EPS
				else SimKinds.ContactDisposition.CORRIDOR
			)
		if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
			return SimKinds.ContactDisposition.CORRIDOR
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
		# Slope outer back is a crash shell (classifier). Never Mount through it —
		# that warped free-air into the lip (u≈1) as if skating the front.
		# Peak leave / free-air exit: Corridor so we do not Reject-freeze X on the
		# launch slope's own outer back (or a Z-adjacent same-footprint hang pipe).
		if reason == "slope outer back" and _slope_outer_back_is_launch_exit(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
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
		if _rising_same_slope_reentry(state, _contact_slope_surf(contact)):
			return SimKinds.ContactDisposition.CORRIDOR
		if _foreign_pipe_lip_is_crash_wall(state, contact):
			# Already wiping out: seat on the lip instead of Reject-bounce forever.
			if state.falling and state.velocity.z <= SimTolerances.CONTACT_EPS:
				return SimKinds.ContactDisposition.MOUNT
			return SimKinds.ContactDisposition.REJECT
		return SimKinds.ContactDisposition.MOUNT
	# Wall climb face.
	if kind == "wall" or role == SimKinds.ContactRole.WALL_CLIMB:
		if _wall_contact_is_outward_exit(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
		if state.is_hanging() and state.velocity.z <= SimTolerances.CONTACT_EPS:
			return SimKinds.ContactDisposition.MOUNT
		# Free-air must not Mount via upper_partner_pipe_id — that id is transfer-
		# only. Partner lip seats warped outer-back smashes onto the L1 ride face.
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
		# Peak / lip leave into the launch slope's own air-out `#` — corridor,
		# not a crash wall (classifier matches via launch_outward_deck).
		var deck_sid := str(contact.get("owner_id", contact.get("surface_id", "")))
		if _launch_owns_outward_deck(state, deck_sid):
			return SimKinds.ContactDisposition.CORRIDOR
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
		if sk == SimKinds.SurfaceKind.PIPE and _foreign_pipe_lip_is_crash_wall(state, contact):
			if state.falling and state.velocity.z <= SimTolerances.CONTACT_EPS:
				return SimKinds.ContactDisposition.MOUNT
			return SimKinds.ContactDisposition.REJECT
		return SimKinds.ContactDisposition.MOUNT
	# Pipe / ramp body solids.
	if kind == "pipe" or kind == "ramp":
		if state.velocity.z > 80.0:
			return SimKinds.ContactDisposition.CORRIDOR
		if _rising_same_slope_reentry(state, _contact_slope_surf(contact)):
			return SimKinds.ContactDisposition.CORRIDOR
		if state.is_hanging() and kind == "pipe" and _hang_rejects_pipe_hit(state, contact):
			return SimKinds.ContactDisposition.CORRIDOR
		if kind == "pipe" and _foreign_pipe_lip_is_crash_wall(state, contact):
			if state.falling and state.velocity.z <= SimTolerances.CONTACT_EPS:
				return SimKinds.ContactDisposition.MOUNT
			return SimKinds.ContactDisposition.REJECT
		return SimKinds.ContactDisposition.MOUNT
	return SimKinds.ContactDisposition.REJECT


## Foreign pipe upper ollie-lip band is a crash wall — Reject, never Mount.
func _foreign_pipe_lip_is_crash_wall(state: SimState, contact: Dictionary) -> bool:
	if crash == null:
		return false
	return crash.is_foreign_pipe_lip_crash(
		state, contact, {"launch_id": _launch_id_for_along(state)}
	)


## Rejects that must not be softened into Corridor for a later Mount.
func _reject_blocks_later_mount(state: SimState, contact: Dictionary) -> bool:
	if _foreign_pipe_lip_is_crash_wall(state, contact):
		return true
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", -1))
	# Open union fence (no outward `#`) — never Corridor past into a pipe Mount.
	if kind == "wall" or role == SimKinds.ContactRole.WALL_CLIMB:
		var wid := str(contact.get("surface_id", contact.get("owner_id", "")))
		if crash != null and crash._wall_is_open_fence(wid, state.position.y):
			return true
		return false
	var reason := str(contact.get("reason", ""))
	# Outer-back shell: crash unless this bout's own peak/leave exit.
	if reason == "slope outer back":
		return not _slope_outer_back_is_launch_exit(state, contact)
	return false


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
	var deck_owned := _slope_span_has_outward_deck(coping_id, launch, z)
	# Wall-extension lip `#` may omit span.outward_deck_id while still abutting.
	if not deck_owned and model.walls.has(owner) and int(pad.kind) == SimKinds.SurfaceKind.DECK:
		var wall: WallSurface = model.walls[owner]
		var ws: Dictionary = wall.sample_at_z(z)
		if not ws.is_empty():
			var wx := float(ws.x)
			deck_owned = (
				absf(pad.x_min - wx) <= SimTolerances.ALIGN_EPS
				or absf(pad.x_max - wx) <= SimTolerances.ALIGN_EPS
			)
	if coping_id.is_empty() or not deck_owned:
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


## True when this outer-back hit belongs to the slope we just left (or its
## Z-adjacent same-footprint pipe). Corridor so peak leave keeps outward X.
func _slope_outer_back_is_launch_exit(state: SimState, contact: Dictionary) -> bool:
	var launch := state.air_launch_surface_id
	if launch.is_empty() or state.is_hanging():
		return false
	var sid := str(contact.get("surface_id", ""))
	if sid.is_empty():
		return false
	if launch == sid:
		return true
	# >> peak leave near )): shared coping X, pipe outer back must not X-freeze.
	if model.ramps.has(launch) and model.pipes.has(sid):
		return _ramp_launch_abuts_pipe(launch, model.pipes[sid], state.position.y)
	return false


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
	var was_hanging := state.is_hanging()
	var mounted := false
	# Hang anchor remount.
	if role == SimKinds.ContactRole.HANG_ANCHOR or kind == "hang_anchor":
		mounted = _try_return_to_anchor(state, from_height)
	# Lip column → mount pipe or wall owner.
	elif role == SimKinds.ContactRole.LIP_COLUMN:
		if model.walls.has(owner_id):
			var whit := {
				"kind": "wall",
				"surface_id": owner_id,
				"projection": contact.get("projection", state.position),
			}
			if ground != null and ground._mount_wall_from_hit(
				state, whit, state.position
			):
				mounted = true
			else:
				# Fall through to source pipe.
				var wall: WallSurface = model.walls[owner_id]
				owner_id = wall.source_pipe_id
		if not mounted and model.pipes.has(owner_id):
			mounted = _mount_pipe_owner(state, owner_id, contact)
		if not mounted and model.ramps.has(owner_id):
			mounted = _mount_ramp_owner(state, owner_id, contact)
	# Slope outer-back land.
	elif kind == "feature_wall" and str(contact.get("reason", "")) == "slope outer back":
		mounted = _try_land_through_slope_back(state, contact, from_height)
	# Support top / solid mount via existing snap + land helpers.
	elif kind == "support_top":
		mounted = _mount_support_top(state, contact, from_height)
	else:
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
			mounted = true
		elif hit.get("kind", "") == "deck" and _force_near_pad_deck_land(state, hit):
			mounted = true
	if mounted:
		_maybe_request_fall_after_hang_flat(state, was_hanging)
	return mounted


## Hang land onto floor/deck (not lava) → fall bout instead of skating away.
func _maybe_request_fall_after_hang_flat(state: SimState, was_hanging: bool) -> void:
	if not was_hanging or state == null or not state.is_grounded():
		return
	if crash == null:
		return
	var contact := {
		"kind": "support_top",
		"surface_id": state.surface_id,
		"owner_id": state.surface_id,
	}
	if model.patches.has(state.surface_id):
		var patch: SupportPatch = model.patches[state.surface_id]
		contact["support_kind"] = int(patch.kind)
	if crash.is_crash(
		state,
		contact,
		{"mode": "hang_flat_mount", "was_hanging": true, "launch_id": _bout_launch_id},
	):
		state.request_fall = true


func _mount_pipe_owner(state: SimState, pipe_id: String, contact: Dictionary) -> bool:
	var pipe: PipeSurface = model.pipes.get(pipe_id)
	if pipe == null:
		return false
	# Ramp Z-leave / seam skim must not force-lip onto the abutting hang pipe.
	if not state.is_hanging() \
			and _ramp_launch_abuts_pipe(state.air_launch_surface_id, pipe, state.position.y):
		return false
	if _rising_same_slope_reentry(state, pipe):
		return false
	# Mid-wipeout may seat on the lip we already crashed into; free-air still
	# refuses foreign lip / outward lip approaches (crash Reject handles those).
	if not state.falling:
		if _foreign_pipe_lip_is_crash_wall(state, contact):
			return false
		if _foreign_outward_lip_approach(state, pipe):
			return false
	var vz := state.velocity.y
	var world_vel := state.velocity
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
		state.tangent_velocity = Vector2(
			_slope_along_from_world_vel(pipe, world_vel, state.position, _launch_id_for_along(state)), vz
		)
		state.velocity = Vector3.ZERO
		state.clear_hang()
		state.clear_air_peak()
		return true
	if not force_lip and not bool(proj.get("ok", false)):
		return false
	# Force-lip seat needs a projectable bowl-side hit — not an outer-back miss.
	if not bool(proj.get("ok", false)) and _clearly_outward_of_pipe(state, pipe):
		return false
	# Lip-column / coping seat: drop into the bowl just under the lip.
	var theta := PI * 0.5 * 0.92
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = pipe.id
	state.u = theta / (PI * 0.5)
	state.v = clampf((z - pipe.z_min) / maxf(pipe.z_max - pipe.z_min, 0.001), 0.0, 1.0)
	state.position = Vector3(pipe.x_at_theta(z, theta), z, pipe.height_at_theta(z, theta))
	state.tangent_velocity = Vector2(
		_slope_along_from_world_vel(pipe, world_vel, state.position, _launch_id_for_along(state)), vz
	)
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_air_peak()
	return true


## Free-air clearly past the coping on the outward side of a foreign pipe, in the
## lip height band — the outer-back crash shell, not a legal drop-in.
func _foreign_outward_lip_approach(state: SimState, pipe: PipeSurface) -> bool:
	if state == null or pipe == null or state.is_hanging():
		return false
	if crash != null and crash.is_same_slope_reentry(
		state, pipe, {"launch_id": _launch_id_for_along(state)}
	):
		return false
	if not _clearly_outward_of_pipe(state, pipe):
		return false
	var u := NAN
	if crash != null:
		u = crash.estimate_pipe_u(pipe, state.position)
	if is_nan(u):
		return false
	var lip := 0.50
	if crash != null:
		lip = crash.ollie_lip_frac
	return u >= 1.0 - clampf(lip, 0.0, 1.0)


func _clearly_outward_of_pipe(state: SimState, pipe: PipeSurface) -> bool:
	if state == null or pipe == null:
		return false
	var z := state.position.y
	var cx := pipe.coping_x_at(z)
	if is_nan(cx):
		return false
	var out := pipe.outward_sign()
	return (state.position.x - cx) * out > SimTolerances.CAPSULE_RADIUS


func _mount_ramp_owner(state: SimState, ramp_id: String, contact: Dictionary) -> bool:
	var ramp: RampSurface = model.ramps.get(ramp_id)
	if ramp == null:
		return false
	if _rising_same_slope_reentry(state, ramp):
		return false
	var rproj := ramp.project(state.position.x, state.position.y, state.position.z)
	if not bool(rproj.get("ok", false)):
		return false
	state.mode = SimState.Mode.GROUNDED
	state.surface_id = ramp.id
	state.u = float(rproj.u)
	state.v = float(rproj.v)
	state.position = rproj.point
	state.tangent_velocity = Vector2(
		_slope_along_from_world_vel(ramp, state.velocity, state.position, _launch_id_for_along(state)), state.velocity.y
	)
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
	if _contact_requests_fall(state, contact):
		state.request_fall = true
	if kind == "bounds" or kind == "feature_wall":
		_resolve_bounds_hit(state, contact, from)
		_ensure_air_outside_slopes(state)
		return
	# Prefer projecting out along the contact normal.
	if kind == "wall":
		# Always reject to the approach side — stacked L0/L1 walls can carry a
		# source/partner outward that points through the face.
		var pt_w: Vector3 = contact.get("projection", contact.get("point", state.position))
		var side := signf(from.x - pt_w.x)
		if absf(side) < 0.001:
			side = signf(normal.x)
		if absf(side) < 0.001:
			side = -1.0
		var wall_n := Vector3(side, 0.0, 0.0)
		state.velocity = _reject_into_normal(state.velocity, wall_n)
		if state.velocity.x * side < 0.0:
			state.velocity.x = 0.0
		if state.request_fall:
			state.stamp_fall_lean(side)
		state.position = Vector3(
			pt_w.x + side * SimTolerances.WALL_REJECT_CLEAR,
			state.position.y,
			state.position.z
		)
		# Stay on the approach face only. Do not walk the bowl footprint to the
		# opposite lip — that teleported joint crashes through the pipe column.
		_clamp_to_wall_approach_side(state, pt_w.x, side)
		_push_out_of_solids(state, wall_n)
	elif normal.length_squared() > 0.0001:
		state.velocity = _reject_into_normal(state.velocity, normal)
		var pt: Vector3 = contact.get("projection", contact.get("point", state.position))
		state.position = pt + normal.normalized() * SimTolerances.CONTACT_EPS
		_push_out_of_solids(state, normal)
	else:
		_bounce_off_solid_no_vz_kill(state, contact, from)
	_ensure_air_outside_slopes(state)


## Free-air bail solids via CrashClassifier. Hang uses hang_flat / hang_clip modes.
func _contact_requests_fall(state: SimState, contact: Dictionary) -> bool:
	if crash == null:
		return false
	var sid := str(contact.get("surface_id", contact.get("owner_id", "")))
	var reason := str(contact.get("reason", ""))
	var launch := _bout_launch_id if not _bout_launch_id.is_empty() else state.air_launch_surface_id
	# Hang must not use the free-air reject table (owned remounts stay playable),
	# but floor/deck solids still wipe out via hang_clip.
	if state.is_hanging():
		return crash.is_crash(
			state, contact, {"mode": "hang_clip", "launch_id": launch}
		)
	return crash.is_crash(
		state,
		contact,
		{
			"mode": "reject",
			"launch_id": launch,
			"launch_exit": (
				reason == "slope outer back" and _slope_outer_back_is_launch_exit(state, contact)
			),
			"deck_ride_off": (
				reason == "deck open side" and state.air_launch_surface_id == sid
			),
			"launch_outward_deck": _launch_owns_outward_deck(state, sid),
		},
	)


## Launch pipe/ramp's abutting outward `#` at this depth (air-out pad).
func _launch_owns_outward_deck(state: SimState, deck_id: String) -> bool:
	if crash != null:
		return crash.is_launch_outward_deck(
			state, deck_id, {"launch_id": _launch_id_for_along(state)}
		)
	if deck_id.is_empty() or state == null:
		return false
	var launch := _launch_id_for_along(state)
	if launch.is_empty():
		return false
	var coping_id := ""
	if model.pipes.has(launch):
		coping_id = (model.pipes[launch] as PipeSurface).coping_id
	elif model.ramps.has(launch):
		coping_id = (model.ramps[launch] as RampSurface).coping_id
	else:
		return false
	return _slope_span_has_outward_deck(coping_id, deck_id, state.position.y)


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
		if _rising_same_slope_reentry(state, pipe):
			return false
		if crash != null and crash.is_foreign_pipe_lip_crash(
			state, hit, {"launch_id": _launch_id_for_along(state)}
		):
			return false
		if _foreign_outward_lip_approach(state, pipe):
			return false
		var proj := _pipe_proj_for_air_hit(state, pipe, hit)
		# Lower-story pipe bodies can wrap under upper lips — prefer a same-side
		# pipe whose surface matches the contact height.
		if not proj.is_empty():
			var dh0 := absf(float(proj.point.z) - state.position.z)
			var max_dh0 := maxf(float(proj.get("rise", proj.get("radius", 40.0))), 40.0)
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
		state.tangent_velocity = Vector2(
			_slope_along_from_world_vel(pipe, state.velocity, state.position, _launch_id_for_along(state)), vz
		)
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
		if _rising_same_slope_reentry(state, ramp):
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
		state.tangent_velocity = Vector2(
			_slope_along_from_world_vel(ramp, state.velocity, state.position, _launch_id_for_along(state)), vz
		)
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
		# Ordinary free air never acquires wall ownership — except recovering the
		# launch pipe's wall when hang cleared mid-air at the lock X. Bounce there
		# freezes beside a coplanar abutting deck (leaned, X stuck).
		# upper_partner_pipe_id is transfer-only — never free-air lip-seat.
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
		# Z-adjacent same-footprint ramp leave must stay free-air — remounting
		# the hang pipe reintroduces X-lock / fly-out beside >> / )).
		if _ramp_launch_abuts_pipe(state.air_launch_surface_id, pipe, state.position.y):
			return false
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


## True when free-air began on a ramp that Z-abuts this same-side / same-footprint
## pipe (shared loft seam). Used to block hang-pipe steal after ramp Z-leave.
func _ramp_launch_abuts_pipe(launch_id: String, pipe: PipeSurface, z: float) -> bool:
	if launch_id.is_empty() or pipe == null:
		return false
	if not model.ramps.has(launch_id):
		return false
	var ramp: RampSurface = model.ramps[launch_id]
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
		var pt_w: Vector3 = hit.get("projection", hit.get("point", state.position))
		var side := signf(from.x - pt_w.x)
		if absf(side) < 0.001:
			var n0: Vector3 = hit.get("normal", Vector3.ZERO)
			side = signf(n0.x)
		if absf(side) < 0.001:
			side = -1.0
		if state.velocity.x * side < 0.0:
			state.velocity.x = 0.0
		state.position.x = pt_w.x + side * SimTolerances.CONTACT_EPS * 2.0
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
	# Bowl-side motion along −outward may Corridor. Free-air smashes from the
	# outward/back side must Reject (L0/L1 union wall). Prefer upper-partner
	# outward on stacked faces; never trust contact.normal alone.
	var wall: WallSurface = model.walls.get(str(hit.get("surface_id", "")))
	if wall == null:
		return false
	var out := 0.0
	if not wall.upper_partner_pipe_id.is_empty():
		var partner: PipeSurface = model.pipes.get(wall.upper_partner_pipe_id)
		if partner != null:
			out = partner.outward_sign()
	if is_zero_approx(out):
		var cope: CopingEdge = model.copings.get(wall.source_coping_id)
		if cope == null:
			return false
		out = float(cope.outward_sign)
	var pt: Vector3 = hit.get("projection", hit.get("point", state.position))
	# Include the thin on_face band as outward so pre-Reject lerps still count.
	var from_outward := (state.position.x - pt.x) * out >= -SimTolerances.CONTACT_EPS
	# Outside → inward is a back smash, not a bowl exit.
	if from_outward and state.velocity.x * out < 0.0:
		return false
	return state.velocity.x * (-out) > 0.0


## Former outer-back → ride-surface warp. Crash shell only — always refuse.
func _try_land_through_slope_back(_state: SimState, _hit: Dictionary, _from_height: float) -> bool:
	return false


## Bounds / space / feature walls — stop into-wall motion; never crash.
func _resolve_bounds_hit(state: SimState, hit: Dictionary, from: Vector3) -> void:
	var axis := str(hit.get("axis", ""))
	var kind := str(hit.get("kind", ""))
	# Bail on level / feature walls (Reject path also stamps; this covers all entries).
	if _contact_requests_fall(state, hit):
		state.request_fall = true
	if axis == "x":
		state.velocity.x = 0.0
	elif axis == "z":
		state.velocity.y = 0.0
	else:
		state.velocity.x = 0.0
		state.velocity.y = 0.0
	if kind == "feature_wall":
		# Push back to the approach side of this face — never walk across a pipe.
		var side_fw := signf(from.x - state.position.x)
		if absf(side_fw) < 0.001:
			var nrm: Vector3 = hit.get("normal", Vector3.ZERO)
			side_fw = signf(nrm.x)
		if absf(side_fw) < 0.001:
			side_fw = -signf(float(hit.get("sign", 0.0)))
		if absf(side_fw) < 0.001:
			side_fw = -1.0
		var face_x := state.position.x
		if state.request_fall:
			state.stamp_fall_lean(side_fw)
		state.position.x += side_fw * SimTolerances.WALL_REJECT_CLEAR
		_clamp_to_wall_approach_side(state, face_x, side_fw)
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
		var side_b := signf(from.x - state.position.x)
		if absf(side_b) < 0.001:
			side_b = -signf(float(hit.get("sign", 0.0)))
		if state.request_fall:
			state.stamp_fall_lean(side_b)
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
	# Local reject/mount only — never walk X across a pipe footprint (that
	# teleported joint/rear crashes to the opposite lip / through L1).
	if _snap_onto_solid(state, hit, state.position.z):
		return
	_bounce_off_solid(state, hit, state.position)


## Keep X on the approach side of a vertical face (joint / rear crash).
func _clamp_to_wall_approach_side(state: SimState, face_x: float, side_x: float) -> void:
	var side := signf(side_x)
	if absf(side) < 0.001:
		side = -1.0
	var min_clear := face_x + side * SimTolerances.WALL_REJECT_CLEAR
	if side < 0.0:
		state.position.x = minf(state.position.x, min_clear)
	else:
		state.position.x = maxf(state.position.x, min_clear)


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
	# Unreachable / expired transfer (below hang lip with no touch) — drop into
	# free air so solids / void floor can remount. Capsule contact is skipped
	# while the maneuver owns the tick.
	if (
		not touched
		and plan.elapsed > maxf(plan.land_time, SimTolerances.FIXED_DT) + 0.25
		and state.position.z < plan.land_height - SimTolerances.CONTACT_EPS
	):
		state.maneuver = null
		_step_free(state, wish, delta)
		return
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
	var world_vel := state.velocity
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
			state.tangent_velocity = Vector2(
				_slope_along_from_world_vel(pipe, world_vel, state.position, _launch_id_for_along(state)) if pipe != null else world_vel.x,
				vz
			)
	elif int(top.kind) == SimKinds.SurfaceKind.RAMP:
		var ramp: RampSurface = model.ramps.get(state.surface_id)
		var rproj: Dictionary = top.proj
		state.u = float(rproj.u)
		state.v = float(rproj.v)
		state.position = rproj.point
		state.tangent_velocity = Vector2(
			_slope_along_from_world_vel(ramp, world_vel, state.position, _launch_id_for_along(state)) if ramp != null else world_vel.x,
			vz
		)
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


func _hang_flat_contact_is_deck(contact: Dictionary) -> bool:
	var kind := str(contact.get("kind", ""))
	if kind == "deck" or int(contact.get("role", -1)) == SimKinds.ContactRole.OUTWARD_DECK:
		return true
	if kind == "support_top":
		return int(contact.get("support_kind", -1)) == SimKinds.SurfaceKind.DECK
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	var patch: SupportPatch = model.patches.get(sid)
	return patch != null and int(patch.kind) == SimKinds.SurfaceKind.DECK


## True when hang can still remount same-facing X-aligned pipe/wall under the lock.
func _hang_has_remountable_source(state: SimState) -> bool:
	var anchor := _hang_anchor(state, state.position.y)
	if anchor.is_empty():
		return false
	var lock_x := float(anchor.x)
	var src: PipeSurface = model.pipes.get(str(anchor.get("source_pipe_id", ""))) as PipeSurface
	if src == null:
		return false
	var z := state.position.y
	if z >= src.z_min - 0.001 and z <= src.z_max + 0.001:
		var cx := src.coping_x_at(z)
		if not is_nan(cx) and absf(cx - lock_x) <= SimTolerances.ALIGN_EPS:
			return true
	# Wall extension above the pipe still counts as remountable source.
	var edge: TopologyEdge = model.edges.get(state.hang_edge_id)
	if edge != null and model.walls.has(edge.from_surface_id):
		return true
	for wid in model.walls.keys():
		var wall: WallSurface = model.walls[wid]
		if wall.source_pipe_id != src.id:
			continue
		if wall.contains_z(z):
			return true
	return false


## Hang may clear onto floor / deck / lava / void when no remountable source is
## under the lock. Floor/deck mounts request a fall bout (lava still kills).
func _hang_is_flat_land_contact(contact: Dictionary) -> bool:
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	if sid == "__void_floor__" or sid == "__park_floor__":
		return true
	var kind := str(contact.get("kind", ""))
	if kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		return (
			sk == SimKinds.SurfaceKind.FLOOR
			or sk == SimKinds.SurfaceKind.DECK
			or sk == SimKinds.SurfaceKind.LAVA
		)
	if kind == "deck" or int(contact.get("role", -1)) == SimKinds.ContactRole.OUTWARD_DECK:
		return true
	var patch: SupportPatch = model.patches.get(sid)
	if patch == null:
		return false
	var pk := int(patch.kind)
	return (
		pk == SimKinds.SurfaceKind.FLOOR
		or pk == SimKinds.SurfaceKind.DECK
		or pk == SimKinds.SurfaceKind.LAVA
	)


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
		if _ramp_launch_abuts_pipe(state.air_launch_surface_id, pipe2, state.position.y):
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
		if _ramp_launch_abuts_pipe(state.air_launch_surface_id, pipe, z):
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
