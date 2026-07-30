class_name PlayerSim
extends RefCounted
## Analytical simulation orchestrator — sole gameplay authority.


var model: ParkModel
var query: SurfaceQuery
var ground: GroundSolver
var air: AirSolver
var planner: ManeuverPlanner
var state: SimState
var accel: float = 3250.0
var max_speed: float = 880.0
var max_speed_z: float = 400.0
var ollie_accel: float = 650.0
## Full-charge hold time in milliseconds (0 = instantly full while held).
var ollie_charge_ms: float = 250.0
## Peak ollie height at 100% charge (level units). Converted to up-speed via gravity.
var ollie_height: float = 100.0
var brake: float = 1250.0
var friction: float = 0.0
var ramp_friction: float = 0.0
var last_wish: Vector2 = Vector2.ZERO
var action_just: bool = false
var ollie_pressed: bool = false
var ollie_just_released: bool = false
## Hold meter in [0, 1] while charging an available ollie.
var ollie_charge: float = 0.0
## Single jump charge — spent on release jump, restored on any grounded contact.
var ollie_available: bool = true
var debug: SimDebugSnapshot
var trace: SimTrace
## Safe floor/deck pose history for lava respawn. Oldest sample in the window
## (~CHECKPOINT_HISTORY_SEC of grounded floor/deck time) is the restore point.
var checkpoint_history: Array = []
## Convenience mirror of history[0] for tests / debug.
var checkpoint_surface_id: String = ""
var checkpoint_position: Vector3 = Vector3.ZERO
var checkpoint_facing: String = "r"


func setup_from_path(path: String) -> bool:
	model = IdlCompiler.compile_path(path)
	return _finish_setup()


func setup_from_text(text: String, name_hint: String = "") -> bool:
	model = IdlCompiler.compile_text(text, name_hint)
	return _finish_setup()


func setup_from_spec(spec: LevelSpec) -> bool:
	model = IdlCompiler.compile_spec(spec)
	return _finish_setup()


func _finish_setup() -> bool:
	if model == null or not model.is_valid():
		return false
	query = SurfaceQuery.new(model)
	ground = GroundSolver.new(model, query)
	planner = ManeuverPlanner.new(model, query)
	air = AirSolver.new(model, query, planner, ground)
	state = ground.spawn_state()
	_seed_checkpoint_from_state()
	ollie_available = state != null and state.is_grounded()
	ollie_charge = 0.0
	debug = SimDebugSnapshot.new()
	trace = SimTrace.new(model.model_hash)
	trace.record(state, Vector2.ZERO, false)
	return true


func set_input(
	wish: Vector2,
	_action_down: bool,
	action_edge: bool,
	ollie_down: bool = false,
	ollie_released: bool = false,
) -> void:
	last_wish = wish
	action_just = action_edge
	ollie_pressed = ollie_down
	ollie_just_released = ollie_released


func tick(delta: float = SimTolerances.FIXED_DT) -> void:
	if state == null or not state.alive:
		return
	var previous_surface_id := state.surface_id
	state.tick += 1
	_update_ollie_charge(delta)
	_try_ollie_jump()
	_try_actions()
	var planned_surface_change := state.has_maneuver()
	if state.is_grounded():
		ground.step(
			state,
			last_wish,
			delta,
			accel,
			max_speed,
			max_speed_z,
			brake,
			friction,
			ramp_friction,
			ollie_pressed,
			ollie_accel,
		)
	else:
		air.step(state, last_wish, delta)
	_replenish_ollie_on_ground()
	_apply_lava_kill()
	_note_checkpoint()
	_assert_finite()
	_assert_invariants(previous_surface_id, planned_surface_change)
	debug.capture(state, model, query)
	trace.record(state, last_wish, action_just)
	action_just = false
	ollie_just_released = false


func _update_ollie_charge(delta: float) -> void:
	if ollie_just_released:
		return
	if not ollie_pressed or not ollie_available:
		ollie_charge = 0.0
		return
	# Hold meter only builds while grounded — cannot start charging in air.
	if state == null or not state.is_grounded():
		return
	if ollie_charge_ms <= 0.0:
		ollie_charge = 1.0
		return
	ollie_charge = minf(1.0, ollie_charge + (delta * 1000.0) / ollie_charge_ms)


func _try_ollie_jump() -> void:
	if not ollie_just_released:
		return
	var frac := ollie_charge
	ollie_charge = 0.0
	if not ollie_available:
		return
	var height := frac * ollie_height
	if height <= 0.0:
		return
	ollie_available = false
	_apply_height_impulse(_up_speed_for_height(height))


func _replenish_ollie_on_ground() -> void:
	if state != null and state.alive and state.is_grounded():
		ollie_available = true


## Ballistic peak height → initial up-speed under current gravity: v = √(2|g|h).
func _up_speed_for_height(height: float) -> float:
	var g := absf(SimTolerances.GRAVITY)
	if height <= 0.0 or g < 0.001:
		return 0.0
	return sqrt(2.0 * g * height)


func _apply_height_impulse(up_speed: float) -> void:
	if state == null or not state.alive or up_speed <= 0.0:
		return
	if state.is_grounded():
		ground.launch_height_impulse(state, up_speed)
		return
	# Airborne (free or hang): add upward speed and drop hang/maneuver lock.
	state.maneuver = null
	if state.is_hanging():
		state.clear_hang()
	state.velocity.z += up_speed
	state.note_air_height(state.position.z)


## Grounded contact with any lethal pad kills (floor polys may still cover the
## same XZ as lava — touch is authoritative, not surface_id ownership).
func _apply_lava_kill() -> void:
	if state == null or not state.alive or not state.is_grounded():
		return
	var hit := query.lethal_at(state.position.x, state.position.y, state.position.z)
	if hit.is_empty():
		# Also die if already mounted on a lethal patch (spawn / seam).
		if model.patches.has(state.surface_id):
			var patch: SupportPatch = model.patches[state.surface_id]
			if patch.lethal:
				state.alive = false
		return
	state.surface_id = str(hit.surface_id)
	state.u = 0.0
	state.v = 0.0
	state.position.z = float(hit.height)
	state.tangent_velocity = Vector2.ZERO
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.alive = false


func _is_checkpoint_surface(surface_id: String) -> bool:
	if surface_id.is_empty() or surface_id == "__void_floor__":
		return false
	if not model.patches.has(surface_id):
		return false
	var patch: SupportPatch = model.patches[surface_id]
	if patch.lethal:
		return false
	var kind := int(patch.kind)
	return kind == SimKinds.SurfaceKind.FLOOR or kind == SimKinds.SurfaceKind.DECK


func _seed_checkpoint_from_state() -> void:
	checkpoint_history.clear()
	checkpoint_surface_id = ""
	checkpoint_position = Vector3.ZERO
	checkpoint_facing = model.spawn_facing if model != null else "r"
	if state == null:
		return
	var sid := ""
	var pos := Vector3(model.spawn_x, model.spawn_z, model.spawn_height)
	var facing := model.spawn_facing
	if state.is_grounded() and _is_checkpoint_surface(state.surface_id):
		sid = state.surface_id
		pos = state.position
		facing = state.facing
	else:
		var top := query.top_support(
			model.spawn_x, model.spawn_z, model.spawn_height + SimTolerances.CONTACT_EPS * 4.0
		)
		if not top.is_empty() and _is_checkpoint_surface(str(top.surface_id)):
			sid = str(top.surface_id)
			pos.z = float(top.height)
	_push_checkpoint_sample(sid, pos, facing)


func _checkpoint_history_limit() -> int:
	return maxi(
		int(ceil(SimTolerances.CHECKPOINT_HISTORY_SEC / SimTolerances.FIXED_DT)),
		2
	)


func _push_checkpoint_sample(surface_id: String, pos: Vector3, facing: String) -> void:
	if surface_id.is_empty() or not _is_checkpoint_surface(surface_id):
		return
	var face := facing if facing in ["l", "r"] else "r"
	checkpoint_history.append({
		"surface_id": surface_id,
		"position": pos,
		"facing": face,
	})
	var limit := _checkpoint_history_limit()
	while checkpoint_history.size() > limit:
		checkpoint_history.pop_front()
	_sync_checkpoint_mirror()


func _sync_checkpoint_mirror() -> void:
	if checkpoint_history.is_empty():
		checkpoint_surface_id = ""
		checkpoint_position = Vector3.ZERO
		checkpoint_facing = model.spawn_facing if model != null else "r"
		return
	var oldest: Dictionary = checkpoint_history[0]
	checkpoint_surface_id = str(oldest.get("surface_id", ""))
	checkpoint_position = oldest.get("position", Vector3.ZERO)
	checkpoint_facing = str(oldest.get("facing", "r"))


func _note_checkpoint() -> void:
	if state == null or not state.alive or not state.is_grounded():
		return
	if not _is_checkpoint_surface(state.surface_id):
		return
	_push_checkpoint_sample(state.surface_id, state.position, state.facing)


func _try_actions() -> void:
	# Fly-out: stick-only at OPEN coping while grounded OR hang-airing above it.
	var transfer_edge: TopologyEdge = null
	if state.is_hanging():
		transfer_edge = model.edges.get(state.hang_edge_id)
	elif state.is_grounded() and model.walls.has(state.surface_id):
		transfer_edge = query.edge_at(state.surface_id, state.position.y, "top")
	var action_targets_transfer := (
		action_just
		and transfer_edge != null
		and not transfer_edge.transfer_target_id.is_empty()
	)
	var fly_eligible := not action_targets_transfer and not state.has_maneuver() and (
		(
			state.is_grounded()
			and (model.pipes.has(state.surface_id) or model.walls.has(state.surface_id))
			and state.u >= 0.98
		)
		or state.is_hanging()
	)
	if fly_eligible:
		var fo := planner.try_fly_out(state, last_wish.x, last_wish.y)
		if bool(fo.get("ok", false)):
			var plan: ManeuverPlan = fo.plan
			state.mode = SimState.Mode.AIRBORNE
			state.surface_id = ""
			state.clear_hang()
			state.maneuver = plan
			state.last_reject = ""
			return
		state.last_reject = str(fo.get("reason", ""))
	# Transfer button: spine (rising) / acid (descending) only.
	if not action_just:
		return
	if state.is_airborne() and not state.has_maneuver():
		var rising := state.velocity.z >= -0.5
		if rising:
			var dir := last_wish.x
			if absf(dir) < 0.1:
				dir = 1.0 if state.facing == "r" else -1.0
			var sp := planner.try_spine(state, dir)
			if bool(sp.get("ok", false)):
				state.clear_hang()
				state.maneuver = sp.plan
				state.last_reject = ""
				return
			state.last_reject = str(sp.get("reason", ""))
		else:
			var travel := state.velocity.x
			if absf(travel) < 1.0:
				travel = last_wish.x
			var ac := planner.try_acid(state, travel)
			if bool(ac.get("ok", false)):
				state.clear_hang()
				state.maneuver = ac.plan
				state.last_reject = ""
				return
			state.last_reject = str(ac.get("reason", ""))


func _assert_finite() -> void:
	var p := state.position
	var v := state.velocity
	if is_nan(p.x) or is_nan(p.y) or is_nan(p.z) or is_nan(v.x) or is_nan(v.y) or is_nan(v.z):
		push_error("PlayerSim NaN at tick %d" % state.tick)


func _assert_invariants(previous_surface_id: String, planned_surface_change: bool) -> void:
	if not state.alive:
		return
	if state.is_grounded():
		var owners := int(model.patches.has(state.surface_id)) \
			+ int(model.pipes.has(state.surface_id)) \
			+ int(model.ramps.has(state.surface_id)) \
			+ int(model.walls.has(state.surface_id))
		if owners != 1:
			push_error(
				"PlayerSim grounded owner invariant at tick %d: %s"
				% [state.tick, state.surface_id]
			)
			return
		if (
			model.pipes.has(state.surface_id)
			or model.ramps.has(state.surface_id)
			or model.walls.has(state.surface_id)
		) and (state.u < -0.001 or state.u > 1.001):
			push_error(
				"PlayerSim surface coordinate invariant at tick %d: %s u=%.4f"
				% [state.tick, state.surface_id, state.u]
			)
			return
		var blocker := query.blocker_at(state.position)
		if not blocker.is_empty() \
				and str(blocker.get("surface_id", "")) != state.surface_id:
			push_error(
				"PlayerSim solid penetration at tick %d: owner=%s hit=%s"
				% [state.tick, state.surface_id, blocker]
			)
			return
	if model.pipes.has(previous_surface_id) and model.pipes.has(state.surface_id):
		var before: PipeSurface = model.pipes[previous_surface_id]
		var after: PipeSurface = model.pipes[state.surface_id]
		if before.side != after.side and not planned_surface_change:
			push_error(
				"PlayerSim unplanned opposite surface change at tick %d: %s -> %s"
				% [state.tick, previous_surface_id, state.surface_id]
			)


func respawn() -> void:
	if model == null or query == null or ground == null:
		return
	_sync_checkpoint_mirror()
	var sid := checkpoint_surface_id
	var pos := checkpoint_position
	var face := checkpoint_facing
	if not sid.is_empty() and model.patches.has(sid) and _is_checkpoint_surface(sid):
		var patch: SupportPatch = model.patches[sid]
		state = SimState.new()
		state.alive = true
		state.mode = SimState.Mode.GROUNDED
		state.surface_id = sid
		state.u = 0.0
		state.v = 0.0
		state.tangent_velocity = Vector2.ZERO
		state.velocity = Vector3.ZERO
		state.maneuver = null
		state.clear_hang()
		state.clear_air_peak()
		state.last_reject = ""
		state.set_facing_side(face)
		var px := clampf(pos.x, patch.x_min + 0.05, patch.x_max - 0.05)
		var pz := clampf(pos.y, patch.z_min + 0.05, patch.z_max - 0.05)
		if not patch.contains_xz(px, pz):
			px = clampf((patch.x_min + patch.x_max) * 0.5, 0.05, maxf(model.width - 0.05, 0.05))
			pz = clampf((patch.z_min + patch.z_max) * 0.5, 0.05, maxf(model.depth - 0.05, 0.05))
		state.position = Vector3(px, pz, patch.height)
	else:
		state = ground.spawn_state()
		state.alive = true
		state.maneuver = null
		state.clear_hang()
		state.last_reject = ""
		_seed_checkpoint_from_state()
	if debug != null:
		debug.capture(state, model, query)
	if trace != null:
		trace.record(state, Vector2.ZERO, false)
	ollie_available = state != null and state.is_grounded()
	ollie_charge = 0.0


func pose_dict() -> Dictionary:
	return {
		"x": state.position.x,
		"z": state.position.y,
		"height": state.position.z,
		"facing": state.facing,
		"airborne": state.is_airborne(),
		"alive": state.alive,
		"surface_id": state.surface_id,
		"model_hash": model.model_hash if model else "",
	}
