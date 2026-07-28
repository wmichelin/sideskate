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
var brake: float = 1250.0
var friction: float = 0.0
var ramp_friction: float = 0.0
var last_wish: Vector2 = Vector2.ZERO
var action_pressed: bool = false
var action_just: bool = false
var ollie_pressed: bool = false
var debug: SimDebugSnapshot
var trace: SimTrace


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
	debug = SimDebugSnapshot.new()
	trace = SimTrace.new(model.model_hash)
	trace.record(state, Vector2.ZERO, false)
	return true


func set_input(wish: Vector2, action_down: bool, action_edge: bool, ollie_down: bool = false) -> void:
	last_wish = wish
	action_pressed = action_down
	action_just = action_edge
	ollie_pressed = ollie_down


func tick(delta: float = SimTolerances.FIXED_DT) -> void:
	if state == null or not state.alive:
		return
	state.tick += 1
	_try_actions()
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
	_assert_finite()
	debug.capture(state, model, query)
	trace.record(state, last_wish, action_just)
	action_just = false


func _try_actions() -> void:
	# Fly-out: stick-only at OPEN coping while grounded OR hang-airing above it.
	var fly_eligible := not state.has_maneuver() and (
		(state.is_grounded() and model.pipes.has(state.surface_id) and state.u >= 0.98)
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
		state.alive = false


func respawn() -> void:
	if model == null or query == null or ground == null:
		return
	state = ground.spawn_state()
	state.alive = true
	state.maneuver = null
	state.clear_hang()
	state.last_reject = ""
	if debug != null:
		debug.capture(state, model, query)
	if trace != null:
		trace.record(state, Vector2.ZERO, false)


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
