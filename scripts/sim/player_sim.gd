class_name PlayerSim
extends RefCounted
## Analytical simulation orchestrator — sole gameplay authority.


var model: ParkModel
var query: SurfaceQuery
var ground: GroundSolver
var air: AirSolver
var planner: ManeuverPlanner
var crash: CrashClassifier
var state: SimState
var accel: float = 3250.0
var max_speed: float = 880.0
var max_speed_z: float = 400.0
var ollie_accel: float = 650.0
## Full-charge hold time in milliseconds (0 = instantly full while held).
var ollie_charge_ms: float = 250.0
## Peak ollie height at 100% charge on floor/deck (level units).
var ollie_height_flat: float = 150.0
## Peak ollie height at 100% charge on pipe/ramp/wall (level units).
var ollie_height_pipe: float = 200.0
## Upper pipe/ramp band (fraction of u from the lip) where ollie enters X-locked hang air.
## Ramps ignore this — peak/ollie leave is always free air.
## 0.50 = top 50% of the transition (u ≥ 0.50).
var ollie_lip_frac: float = 0.50
var brake: float = 1250.0
var friction: float = 0.0
var ramp_friction: float = 0.0
var last_wish: Vector2 = Vector2.ZERO
var action_just: bool = false
## Transfer button held (spine / acid). Used for hold-to-auto-transfer.
var action_held: bool = false
## Seconds of continuous transfer eligibility before hold auto-fires.
var transfer_hold_delay: float = 0.08
## Accumulated eligible time while held with a live transfer candidate.
var transfer_hold_eligible: float = 0.0
var ollie_pressed: bool = false
var ollie_just_released: bool = false
## Air spin hold (Q/E). Ignored while falling; grounded no-ops in AirSolver.
var rotate_left: bool = false
var rotate_right: bool = false
## Presentation latch: set when an ollie impulse actually fires; consume via player.
var ollie_just_popped: bool = false
## Hold meter in [0, 1] while charging an available ollie.
var ollie_charge: float = 0.0
## Peak height snapshotted while grounded charging — kept through airborne release.
var ollie_charge_peak_height: float = 0.0
## Single jump charge — spent on release jump, restored on any grounded contact.
var ollie_available: bool = true
## Fall bout tunables (seconds). Synced from Player debug exports.
var fall_anim_duration: float = 0.15
var fall_stop_duration: float = 1.0
var fall_duration: float = 2.0
var debug: SimDebugSnapshot
var trace: SimTrace
## Safe floor/deck pose history for lava respawn. Oldest sample in the window
## (~CHECKPOINT_HISTORY_SEC of grounded floor/deck time) is the restore point.
var checkpoint_history: Array = []
## Convenience mirror of history[0] for tests / debug.
var checkpoint_surface_id: String = ""
var checkpoint_position: Vector3 = Vector3.ZERO
var checkpoint_facing: String = "r"
## Throttle solid-penetration push_error — spam on dense spine farms tanks FPS.
var _last_penetration_log_tick: int = -999999
const _PENETRATION_LOG_EVERY_TICKS := 60


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
	crash = CrashClassifier.new(model, ollie_lip_frac)
	ground = GroundSolver.new(model, query)
	ground.crash = crash
	planner = ManeuverPlanner.new(model, query)
	air = AirSolver.new(model, query, planner, ground)
	air.crash = crash
	state = ground.spawn_state()
	_seed_checkpoint_from_state()
	ollie_available = state != null and state.is_grounded()
	ollie_charge = 0.0
	ollie_charge_peak_height = 0.0
	ollie_just_popped = false
	debug = SimDebugSnapshot.new()
	trace = SimTrace.new(model.model_hash)
	trace.record(state, Vector2.ZERO, false)
	return true


func set_input(
	wish: Vector2,
	action_down: bool,
	action_edge: bool,
	ollie_down: bool = false,
	ollie_released: bool = false,
	rotate_left_down: bool = false,
	rotate_right_down: bool = false,
) -> void:
	last_wish = wish
	action_held = action_down
	action_just = action_edge
	ollie_pressed = ollie_down
	ollie_just_released = ollie_released
	rotate_left = rotate_left_down
	rotate_right = rotate_right_down
	if not action_held:
		transfer_hold_eligible = 0.0


## Start a fall bout (Y key / business logic). No-op if already falling or dead.
func begin_fall() -> void:
	if state == null or not state.alive or state.falling:
		return
	state.clear_hang()
	state.maneuver = null
	ollie_charge = 0.0
	ollie_charge_peak_height = 0.0
	ollie_pressed = false
	ollie_just_released = false
	ollie_just_popped = false
	action_just = false
	action_held = false
	rotate_left = false
	rotate_right = false
	transfer_hold_eligible = 0.0
	last_wish = Vector2.ZERO
	state.falling = true
	state.fall_elapsed = 0.0
	# Support plane is the surface under the feet — never mid-air feet height
	# (that pinned the presentation FallBox and cancelled gravity).
	refresh_fall_support_plane()
	# Wall/feature crashes stamp approach-side lean so the fall box flops away
	# from the impact face (facing-into-wall used to tip the RigidBody into mesh).
	if not state.fall_lean_locked:
		state.fall_lean_sign = 1.0 if state.facing == "r" else -1.0
	state.fall_lean_locked = false
	if state.is_airborne():
		state.fall_start_vx = state.velocity.x
		state.fall_start_vy = state.velocity.y
	else:
		state.fall_start_vx = state.tangent_velocity.x
		state.fall_start_vy = state.tangent_velocity.y


## Keep FallBox support on the analytical surface under the sim feet.
## Preserves any stamped impact (wall approach) half-space.
func refresh_fall_support_plane() -> void:
	if state == null or query == null:
		return
	var impact_pt := (
		state.fall_impact_point if state.fall_has_impact_plane else Vector3.ZERO
	)
	var impact_n := (
		state.fall_impact_normal if state.fall_has_impact_plane else Vector3.ZERO
	)
	AirSolver.stamp_fall_planes_underfoot(state, query, impact_pt, impact_n)


## Remaining lockout fraction 1→0 over fall_duration.
func fall_cooldown_frac() -> float:
	if state == null or not state.falling:
		return 0.0
	if fall_duration <= 0.0:
		return 0.0
	return clampf(1.0 - state.fall_elapsed / fall_duration, 0.0, 1.0)


## Side-lean progress 0→1 over fall_anim_duration.
func fall_anim_frac() -> float:
	if state == null or not state.falling:
		return 0.0
	if fall_anim_duration <= 0.0:
		return 1.0
	return clampf(state.fall_elapsed / fall_anim_duration, 0.0, 1.0)


func tick(delta: float = SimTolerances.FIXED_DT) -> void:
	if state == null or not state.alive:
		return
	var previous_surface_id := state.surface_id
	state.tick += 1
	var falling := state.falling
	var wish := Vector2.ZERO if falling else last_wish
	if falling:
		ollie_just_released = false
		action_just = false
		action_held = false
		rotate_left = false
		rotate_right = false
		transfer_hold_eligible = 0.0
		ollie_pressed = false
		# Planar schedule before solvers so Reject/depenetrate can cut into-wall
		# speed. _tick_fall must not reinject fall_start afterward (that tunneled
		# through L0/L1 union walls after a crash).
		_apply_fall_planar()
	else:
		_update_ollie_charge(delta)
		_try_ollie_jump()
		_update_transfer_hold(delta)
		_try_actions()
	var planned_surface_change := state.has_maneuver()
	if crash != null:
		crash.set_ollie_lip_frac(ollie_lip_frac)
	if state.is_grounded():
		ground.ollie_lip_frac = ollie_lip_frac
		ground.step(
			state,
			wish,
			delta,
			accel,
			max_speed,
			max_speed_z,
			brake,
			friction,
			ramp_friction,
			false if falling else ollie_pressed,
			ollie_accel,
		)
	else:
		air.rotate_left = rotate_left
		air.rotate_right = rotate_right
		air.step(state, wish, delta, max_speed, max_speed_z)
	if state.request_fall:
		state.request_fall = false
		begin_fall()
		falling = state.falling
		_apply_fall_planar()
	if falling or state.falling:
		_tick_fall(delta)
	_replenish_ollie_on_ground()
	# Refresh charge peak after surface changes this tick (floor→pipe mount).
	_refresh_ollie_charge_peak()
	_apply_lava_kill()
	_note_checkpoint()
	_assert_finite()
	_assert_invariants(previous_surface_id, planned_surface_change)
	debug.capture(state, model, query)
	trace.record(state, wish, action_just)
	action_just = false
	ollie_just_released = false


## Time-based planar stop envelope (does not advance fall_elapsed).
func _apply_fall_planar() -> void:
	if state == null or not state.falling:
		return
	var stop_t := 1.0
	if fall_stop_duration > 0.0:
		stop_t = clampf(state.fall_elapsed / fall_stop_duration, 0.0, 1.0)
	var vx := lerpf(state.fall_start_vx, 0.0, stop_t)
	var vy := lerpf(state.fall_start_vy, 0.0, stop_t)
	if state.is_airborne():
		state.velocity.x = vx
		state.velocity.y = vy
	else:
		state.tangent_velocity.x = vx
		state.tangent_velocity.y = vy
		state.velocity = Vector3.ZERO


## After solvers: keep collision-cut planar speed and shrink the fall envelope so
## later ticks cannot reinject into-wall motion.
func _absorb_fall_planar_after_collision() -> void:
	if state == null or not state.falling:
		return
	var stop_t := 1.0
	if fall_stop_duration > 0.0:
		stop_t = clampf(state.fall_elapsed / fall_stop_duration, 0.0, 1.0)
	var remain := maxf(1.0 - stop_t, 0.001)
	if state.is_airborne():
		var cur_x := state.velocity.x
		var cur_y := state.velocity.y
		var tgt_x := lerpf(state.fall_start_vx, 0.0, stop_t)
		var tgt_y := lerpf(state.fall_start_vy, 0.0, stop_t)
		state.velocity.x = _fall_planar_keep_collision(cur_x, tgt_x)
		state.velocity.y = _fall_planar_keep_collision(cur_y, tgt_y)
		state.fall_start_vx = state.velocity.x / remain
		state.fall_start_vy = state.velocity.y / remain
	else:
		var cur_tx := state.tangent_velocity.x
		var cur_ty := state.tangent_velocity.y
		var tgt_tx := lerpf(state.fall_start_vx, 0.0, stop_t)
		var tgt_ty := lerpf(state.fall_start_vy, 0.0, stop_t)
		state.tangent_velocity.x = _fall_planar_keep_collision(cur_tx, tgt_tx)
		state.tangent_velocity.y = _fall_planar_keep_collision(cur_ty, tgt_ty)
		state.fall_start_vx = state.tangent_velocity.x / remain
		state.fall_start_vy = state.tangent_velocity.y / remain
		state.velocity = Vector3.ZERO


## Prefer post-collision planar when it is closer to zero than the schedule
## (same sign). Opposite/zero collision results clear the axis.
func _fall_planar_keep_collision(current: float, target: float) -> float:
	if absf(target) <= 0.0001:
		return 0.0
	if current * target <= 0.0:
		return 0.0
	if absf(current) < absf(target):
		return current
	return target


func _tick_fall(delta: float) -> void:
	if state == null or not state.falling:
		return
	_absorb_fall_planar_after_collision()
	refresh_fall_support_plane()
	state.fall_elapsed += delta
	# Checkpoint teleport — do not wait for a land. Crash walls (foreign lip,
	# bounds, deck solids) can Reject forever with planar stop, leaving the
	# skater airborne and never grounded.
	if state.fall_elapsed >= fall_duration:
		_restore_to_checkpoint()


func _update_ollie_charge(delta: float) -> void:
	if ollie_just_released:
		return
	if not ollie_pressed or not ollie_available:
		ollie_charge = 0.0
		ollie_charge_peak_height = 0.0
		return
	# Hold meter only builds while grounded — cannot start charging in air.
	# Peak height is snapshotted on the grounded surface and kept through air-out.
	if state == null or not state.is_grounded():
		return
	ollie_charge_peak_height = _ollie_peak_height_for_surface()
	if ollie_charge_ms <= 0.0:
		ollie_charge = 1.0
		return
	ollie_charge = minf(1.0, ollie_charge + (delta * 1000.0) / ollie_charge_ms)


func _try_ollie_jump() -> void:
	if not ollie_just_released:
		return
	var frac := ollie_charge
	var peak := ollie_charge_peak_height
	ollie_charge = 0.0
	ollie_charge_peak_height = 0.0
	if not ollie_available:
		return
	# Airborne release: launch surface wins over a stale flat snapshot from
	# earlier floor charging (hold through floor→pipe→air-out).
	if state != null and state.is_airborne() and model != null:
		var sid := state.air_launch_surface_id
		if model.pipes.has(sid) or model.ramps.has(sid) or model.walls.has(sid):
			peak = ollie_height_pipe
		elif model.patches.has(sid):
			peak = ollie_height_flat
		elif peak <= 0.0:
			peak = _ollie_peak_height_for_surface()
	elif peak <= 0.0:
		peak = _ollie_peak_height_for_surface()
	var height := frac * peak
	if height <= 0.0:
		return
	ollie_available = false
	_apply_height_impulse(height)
	ollie_just_popped = true


## Floor/deck → flat height; pipe/ramp/wall → pipe height. Unknown → flat.
## Airborne release (charged on ground, then air-out) uses the launch surface.
func _ollie_peak_height_for_surface() -> float:
	if state == null or model == null:
		return ollie_height_flat
	var sid := state.surface_id
	if sid.is_empty() and state.is_airborne():
		sid = state.air_launch_surface_id
	if model.pipes.has(sid) or model.ramps.has(sid) or model.walls.has(sid):
		return ollie_height_pipe
	if model.patches.has(sid):
		var patch: SupportPatch = model.patches[sid]
		if int(patch.kind) == SimKinds.SurfaceKind.DECK \
				or int(patch.kind) == SimKinds.SurfaceKind.FLOOR:
			return ollie_height_flat
	return ollie_height_flat


func _refresh_ollie_charge_peak() -> void:
	if not ollie_pressed or not ollie_available:
		return
	if state == null or not state.is_grounded():
		return
	ollie_charge_peak_height = _ollie_peak_height_for_surface()


func _replenish_ollie_on_ground() -> void:
	if state != null and state.alive and state.is_grounded():
		ollie_available = true


## Ballistic peak height → initial up-speed under current gravity: v = √(2|g|h).
func _up_speed_for_height(height: float) -> float:
	var g := absf(SimTolerances.GRAVITY)
	if height <= 0.0 or g < 0.001:
		return 0.0
	return sqrt(2.0 * g * height)


## `height` is peak rise (charge × ollie_height_*). Grounded: enter-air impulse.
## Airborne: boost vz enough to reach launch-lip + height, keeping any faster
## residual leave speed (stack OK) without adding a second full pop on top.
func _apply_height_impulse(height: float) -> void:
	if state == null or not state.alive or height <= 0.0:
		return
	var up_speed := _up_speed_for_height(height)
	if state.is_grounded():
		ground.launch_height_impulse(state, up_speed, ollie_lip_frac)
		return
	state.maneuver = null
	if not state.is_hanging():
		state.clear_hang()
	var ref_z := _ollie_launch_lip_height()
	if is_nan(ref_z):
		ref_z = state.position.z
	var gap := (ref_z + height) - state.position.z
	var need := _up_speed_for_height(maxf(gap, 0.0))
	state.velocity.z = maxf(state.velocity.z, need)
	state.note_air_height(state.position.z)


## Coping / peak height of the air-launch pipe or ramp; NAN if unknown.
func _ollie_launch_lip_height() -> float:
	if state == null or model == null:
		return NAN
	var sid := state.air_launch_surface_id
	var z := state.position.y
	if model.pipes.has(sid):
		var pipe: PipeSurface = model.pipes[sid]
		var z_ref := clampf(z, pipe.z_min, pipe.z_max - 0.001)
		return pipe.height_at_theta(z_ref, PI * 0.5)
	if model.ramps.has(sid):
		var ramp: RampSurface = model.ramps[sid]
		var z_ref := clampf(z, ramp.z_min, ramp.z_max - 0.001)
		return ramp.height_at_theta(z_ref, PI * 0.5)
	if model.walls.has(sid):
		var wall: WallSurface = model.walls[sid]
		var sample := wall.sample_at_z(clampf(z, wall.z_min, wall.z_max - 0.001))
		if sample.is_empty():
			return NAN
		return float(sample.top_height)
	return NAN


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
				state.clear_fall()
				state.alive = false
		return
	state.surface_id = str(hit.surface_id)
	state.u = 0.0
	state.v = 0.0
	state.position.z = float(hit.height)
	state.tangent_velocity = Vector2.ZERO
	state.velocity = Vector3.ZERO
	state.clear_hang()
	state.clear_fall()
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
	if state == null or not state.alive or not state.is_grounded() or state.falling:
		return
	if not _is_checkpoint_surface(state.surface_id):
		return
	_push_checkpoint_sample(state.surface_id, state.position, state.facing)


## Arm hold-to-auto-transfer only while pressed with a live candidate.
func _update_transfer_hold(delta: float) -> void:
	if state == null or not state.alive or state.falling or state.has_maneuver():
		transfer_hold_eligible = 0.0
		return
	if not action_held:
		transfer_hold_eligible = 0.0
		return
	if query.transfer_candidates(state).is_empty():
		transfer_hold_eligible = 0.0
		return
	transfer_hold_eligible += maxf(delta, 0.0)


func _try_actions() -> void:
	if state.has_maneuver():
		return
	# Transfer: tap immediate, or hold after eligible time ≥ delay.
	var hold_ready := (
		action_held
		and transfer_hold_eligible + 0.0001 >= maxf(transfer_hold_delay, 0.0)
	)
	if action_just or hold_ready:
		var tr := planner.try_transfer(state)
		if bool(tr.get("ok", false)):
			var tplan: ManeuverPlan = tr.plan
			if state.is_grounded():
				_stamp_air_launch_from_current()
				state.mode = SimState.Mode.AIRBORNE
				state.surface_id = ""
				state.velocity = tplan.start_velocity
				state.tangent_velocity = Vector2.ZERO
				state.reset_air_spin()
			state.clear_hang()
			state.maneuver = tplan
			state.last_reject = ""
			transfer_hold_eligible = 0.0
			if not tplan.hold_facing.is_empty():
				state.facing = tplan.hold_facing
				state.visual_facing = tplan.hold_facing
				state.facing_yaw = 0.0
				# Keep bout spin reference aligned with held transfer facing.
				if absf(state.spin_yaw) < 0.0001:
					state.spin_takeoff_facing = tplan.hold_facing
			return
		state.last_reject = str(tr.get("reason", ""))
	# Fly-out: stick-only at OPEN coping while grounded OR hang-airing above it.
	var fly_eligible := (
		(
			state.is_grounded()
			and (model.pipes.has(state.surface_id) or model.walls.has(state.surface_id))
			and state.u >= 0.98
		)
		or state.is_hanging()
	)
	if not fly_eligible:
		return
	var fo := planner.try_fly_out(state, last_wish.x, last_wish.y)
	if bool(fo.get("ok", false)):
		var plan: ManeuverPlan = fo.plan
		# Same as GroundSolver._enter_air — keep launch ownership for same-slope
		# remount / crash carve-outs. Grounded stick fly-out used to clear
		# surface_id without stamping, so air-ollie return hit foreign-lip fall.
		var was_grounded := state.is_grounded()
		_stamp_air_launch_from_current()
		state.mode = SimState.Mode.AIRBORNE
		state.surface_id = ""
		state.clear_hang()
		state.maneuver = plan
		state.last_reject = ""
		if was_grounded:
			state.reset_air_spin()
		return
	state.last_reject = str(fo.get("reason", ""))


## Stamp `air_launch_surface_id` before clearing grounded / hang ownership.
func _stamp_air_launch_from_current() -> void:
	if state == null or model == null:
		return
	if state.is_grounded() and not state.surface_id.is_empty():
		state.air_launch_surface_id = state.surface_id
		return
	if not state.air_launch_surface_id.is_empty():
		return
	# Hang fly-out with a wiped launch id — recover from the hang edge source.
	var eid := state.hang_launch_edge_id
	if eid.is_empty():
		eid = state.hang_edge_id
	var edge: TopologyEdge = model.edges.get(eid)
	if edge == null:
		return
	var sid := edge.from_surface_id
	if model.walls.has(sid):
		var wall: WallSurface = model.walls[sid]
		if not wall.source_pipe_id.is_empty():
			sid = wall.source_pipe_id
	if not sid.is_empty():
		state.air_launch_surface_id = sid


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
		# Full blocker_at every grounded tick is expensive on dense spine farms.
		# Sample sparsely — contract still fails loudly when a real leak shows up.
		if (state.tick % 30) == 0:
			var blocker := query.blocker_at(state.position)
			if not blocker.is_empty() \
					and str(blocker.get("surface_id", "")) != state.surface_id:
				if state.tick - _last_penetration_log_tick >= _PENETRATION_LOG_EVERY_TICKS:
					_last_penetration_log_tick = state.tick
					push_error(
						"PlayerSim solid penetration at tick %d: owner=%s hit=%s"
						% [state.tick, state.surface_id, str(blocker.get("reason", blocker.get("kind", "?")))]
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


## Soft restore to oldest floor/deck checkpoint (lava respawn + fall recovery).
## Does not touch `alive` or death UI — callers own that.
func _restore_to_checkpoint() -> void:
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
		state.clear_fall()
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
		state.clear_fall()
		state.last_reject = ""
		_seed_checkpoint_from_state()
	ollie_available = state != null and state.is_grounded()
	ollie_charge = 0.0
	ollie_charge_peak_height = 0.0
	if debug != null:
		debug.capture(state, model, query)
	if trace != null:
		trace.record(state, Vector2.ZERO, false)


func respawn() -> void:
	_restore_to_checkpoint()


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
