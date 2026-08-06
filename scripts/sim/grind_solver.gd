class_name GrindSolver
extends RefCounted
## Along-X rail grind: mount, coast, balance, ollie/end leave.


var model: ParkModel
var query: SurfaceQuery


func _init(m: ParkModel = null, q: SurfaceQuery = null) -> void:
	model = m
	query = q


## Airborne + grind held + near a rail → lock on. Returns true if mounted.
func try_mount(state: SimState, grind_held: bool) -> bool:
	if state == null or model == null or not grind_held:
		return false
	if not state.is_airborne() or state.falling or not state.alive:
		return false
	if state.has_maneuver() or state.is_hanging():
		return false
	if state.grind_remount_cooldown > 0.0:
		return false
	var best_id := ""
	var best_d := INF
	for id in model.all_rail_ids():
		var rail: RailSurface = model.rails[id]
		# Past either end: do not remount (end-eject + R held used to snap back).
		if not rail.contains_x(state.position.x, SimTolerances.CONTACT_EPS):
			continue
		var d := rail.distance_to_pose(state.position)
		if d < best_d:
			best_d = d
			best_id = id
	if best_id.is_empty() or best_d > SimTolerances.RAIL_SNAP_RADIUS:
		return false
	_enter_grind(state, best_id)
	return true


func _enter_grind(state: SimState, rail_id: String) -> void:
	var rail: RailSurface = model.rails[rail_id]
	state.clear_hang()
	state.maneuver = null
	state.mode = SimState.Mode.GRINDING
	state.surface_id = rail_id
	state.grind_rail_id = rail_id
	state.grind_along = state.velocity.x
	state.grind_balance = 0.0
	state.grind_remount_cooldown = 0.0
	# Drop any air-spin residue so grind / leave start upright and aligned.
	state.spin_yaw = 0.0
	state.spin_takeoff_facing = state.facing
	state.spin_handoff = false
	state.board_align_to_facing = true
	state.cancel_spin_land_settle()
	state.velocity = Vector3.ZERO
	state.tangent_velocity = Vector2.ZERO
	state.position.x = clampf(state.position.x, rail.x_min, rail.x_max)
	state.position.y = rail.z
	state.position.z = rail.top_height
	state.clear_air_peak()
	state.free_air_upright = false


## Physics tick while grinding.
func step(state: SimState, wish: Vector2, delta: float) -> void:
	if state == null or model == null or not state.is_grinding():
		return
	if not model.rails.has(state.grind_rail_id):
		_exit_to_air(state, state.grind_along, 0.0)
		return
	var rail: RailSurface = model.rails[state.grind_rail_id]
	# Stick tips the meter over time; neutral stick recovers toward center.
	# Instant wish→lean mapped |stick|==1 to fail and made every approach fall.
	var tip := clampf(wish.x + wish.y, -1.0, 1.0)
	var dt := maxf(delta, 0.0)
	if absf(tip) > 0.05:
		state.grind_balance += tip * SimTolerances.GRIND_BALANCE_RATE * dt
	elif absf(state.grind_balance) > 0.0001:
		var recover := SimTolerances.GRIND_BALANCE_RECOVER * dt
		if absf(state.grind_balance) <= recover:
			state.grind_balance = 0.0
		else:
			state.grind_balance -= signf(state.grind_balance) * recover
	state.grind_balance = clampf(state.grind_balance, -1.25, 1.25)
	if absf(state.grind_balance) >= SimTolerances.GRIND_BALANCE_FAIL - 0.0001:
		state.clear_grind()
		state.mode = SimState.Mode.AIRBORNE
		state.surface_id = ""
		state.velocity = Vector3(state.grind_along, 0.0, 0.0)
		state.position.z = rail.top_height + 1.0
		state.request_fall = true
		return
	var along := state.grind_along
	state.position.x += along * delta
	state.position.y = rail.z
	state.position.z = rail.top_height
	if state.position.x < rail.x_min - 0.01 or state.position.x > rail.x_max + 0.01:
		state.position.x = clampf(state.position.x, rail.x_min, rail.x_max)
		_exit_to_air(state, along, 0.0)
		# Nudge past the end so we do not remount instantly (even with R held).
		state.position.x += signf(along) * maxf(SimTolerances.CONTACT_EPS * 2.0, 4.0)
		state.position.z = rail.top_height + 2.0
		state.grind_remount_cooldown = 0.25
		return


## Ollie release while grinding → free air with pop.
func ollie_out(state: SimState, pop_height_speed: float) -> void:
	if state == null or not state.is_grinding():
		return
	var along := state.grind_along
	var top := state.position.z
	if model != null and model.rails.has(state.grind_rail_id):
		top = (model.rails[state.grind_rail_id] as RailSurface).top_height
	_exit_to_air(state, along, maxf(pop_height_speed, 0.0))
	# Clear the rail solid volume so same-tick air contact does not Reject.
	state.position.z = top + SimTolerances.CONTACT_EPS + 2.0
	state.grind_remount_cooldown = 0.2


func _exit_to_air(state: SimState, vx: float, vz: float) -> void:
	var rail_id := state.grind_rail_id
	var top := state.position.z
	if model != null and model.rails.has(rail_id):
		top = (model.rails[rail_id] as RailSurface).top_height
	state.clear_grind()
	state.mode = SimState.Mode.AIRBORNE
	state.surface_id = ""
	state.air_launch_surface_id = rail_id
	state.velocity = Vector3(vx, 0.0, vz)
	state.tangent_velocity = Vector2.ZERO
	state.reset_air_spin()
	state.position.z = maxf(state.position.z, top + SimTolerances.CONTACT_EPS + 1.0)
	state.note_air_height(state.position.z)
	state.free_air_upright = true
