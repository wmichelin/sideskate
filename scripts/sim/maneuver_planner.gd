class_name ManeuverPlanner
extends RefCounted
## Build immutable spine / acid / fly-out plans.


var model: ParkModel
var query: SurfaceQuery


func _init(m: ParkModel = null, q: SurfaceQuery = null) -> void:
	model = m
	query = q if q != null else SurfaceQuery.new(m)


func try_fly_out(state: SimState, input_x: float, input_z: float) -> Dictionary:
	if not state.is_grounded() and not state.is_airborne():
		return _reject("bad state")
	# Fly-out from grounded pipe near open coping OR hang air over that pipe.
	var pipe: PipeSurface = null
	var cope: CopingEdge = null
	var pos := state.position
	var vel_h := 0.0
	if state.is_grounded() and model.pipes.has(state.surface_id):
		pipe = model.pipes[state.surface_id]
		cope = model.copings.get(pipe.coping_id)
		if state.u < 0.98:
			return _reject("not at coping")
		vel_h = state.tangent_velocity.x ## along-arc
	elif state.is_hanging() and model.pipes.has(state.hang_pipe_id):
		pipe = model.pipes[state.hang_pipe_id]
		cope = model.copings.get(pipe.coping_id)
		vel_h = state.velocity.z
	elif state.is_airborne() and not state.has_maneuver():
		# Find nearest pipe coping under feet (non-hang free air — rare).
		var top := query.top_support(pos.x, pos.y, pos.z + SimTolerances.CONTACT_EPS)
		if top.is_empty() or int(top.kind) != SimKinds.SurfaceKind.PIPE:
			return _reject("no pipe under air")
		pipe = top.pipe as PipeSurface
		cope = model.copings.get(pipe.coping_id)
		vel_h = state.velocity.z
	else:
		return _reject("fly-out unavailable")
	if cope == null:
		return _reject("no coping")
	if cope.coping_class != SimKinds.CopingClass.OPEN \
			and cope.coping_class != SimKinds.CopingClass.SHARED_SPINE:
		return _reject("coping not OPEN (%s)" % cope.class_name_str())
	if vel_h <= 0.0 and state.velocity.z <= 0.0:
		# Need rising — for grounded use along toward coping (positive u speed).
		if state.is_grounded() and state.tangent_velocity.x <= 0.0:
			return _reject("not rising")
		if state.is_airborne() and state.velocity.z <= 0.0:
			return _reject("not rising")
	var out := pipe.outward_sign()
	if absf(input_x) <= 0.15:
		return _reject("no outward input")
	if absf(input_x) <= absf(input_z):
		return _reject("input not X-dominant")
	if input_x * out <= 0.15:
		return _reject("input not outward")
	var samp := cope.sample_at_z(pos.y)
	var cope_h := float(samp.height)
	var above := pos.z - cope_h
	if above < -SimTolerances.CONTACT_EPS:
		return _reject("below coping")
	if above > SimTolerances.FLY_OUT_ABOVE + 0.001:
		return _reject("above fly-out window")
	# Outward corridor: one cell playable ahead.
	var cell := model.cell_at(float(samp.coping_x), pos.y)
	var ahead_col := cell.x + (1 if out > 0.0 else -1)
	if not model.is_playable_cell(ahead_col, cell.y):
		return _reject("no outward playable cell")
	var plan := ManeuverPlan.new()
	plan.kind = ManeuverPlan.Kind.FLY_OUT
	plan.source_coping_id = cope.id
	plan.start_position = pos
	var speed := maxf(absf(state.tangent_velocity.x), absf(state.velocity.length()))
	plan.start_velocity = Vector3(out * maxf(speed, 120.0), state.velocity.y if state.is_airborne() else state.tangent_velocity.y, maxf(vel_h, state.velocity.z))
	plan.land_time = 0.0 ## immediate free-air unlock
	plan.travel_sign = out
	return {"ok": true, "plan": plan}


func try_spine(state: SimState, facing_dir: float) -> Dictionary:
	if not state.is_airborne() or state.has_maneuver():
		if not (state.is_grounded() and model.pipes.has(state.surface_id)):
			return _reject("spine needs air or pipe")
	var pos := state.position
	var vh := state.velocity.z if state.is_airborne() else state.tangent_velocity.x
	if vh < -0.5:
		return _reject("spine needs rising/apex")
	var dir := signf(facing_dir)
	if absf(dir) < 0.001:
		dir = 1.0 if state.facing == "r" else -1.0
	var cands := query.copings_in_direction(pos.x, pos.y, pos.z, dir)
	var source_id := ""
	if state.is_grounded() and model.pipes.has(state.surface_id):
		var pipe: PipeSurface = model.pipes[state.surface_id]
		source_id = pipe.coping_id
	for c in cands:
		var cope: CopingEdge = c.coping
		if cope.id == source_id:
			continue
		var ok_target := cope.coping_class == SimKinds.CopingClass.SHARED_SPINE
		# Facing cast direction: +X seeks right-side destinations (and shared partners).
		var want_side := SimKinds.PipeSide.RIGHT if dir > 0.0 else SimKinds.PipeSide.LEFT
		if int(c.side) == want_side:
			ok_target = true
		if not ok_target:
			continue
		var plan := _build_transfer_plan(
			ManeuverPlan.Kind.SPINE, state, cope, dir, source_id
		)
		if bool(plan.get("ok", false)):
			return plan
	return _reject("no spine target")


func try_acid(state: SimState, travel_x: float) -> Dictionary:
	if not state.is_airborne():
		return _reject("acid needs air")
	if state.has_maneuver():
		return _reject("already maneuvering")
	if state.velocity.z > 0.5:
		return _reject("acid needs descending")
	var dir := signf(travel_x)
	if absf(dir) < 0.001:
		return _reject("no travel")
	var pos := state.position
	var cands := query.copings_in_direction(
		pos.x, pos.y, pos.z, dir, SimTolerances.ACID_COPING_CELLS
	)
	for c in cands:
		var cope: CopingEdge = c.coping
		# Opposite wall of a halfpipe: travel +X → right pipe; travel −X → left pipe.
		var want := SimKinds.PipeSide.RIGHT if dir > 0.0 else SimKinds.PipeSide.LEFT
		if int(c.side) != want:
			continue
		var plan := _build_transfer_plan(
			ManeuverPlan.Kind.ACID, state, cope, dir, ""
		)
		if bool(plan.get("ok", false)):
			return plan
	return _reject("no acid target")


func _build_transfer_plan(
	kind: int, state: SimState, dest: CopingEdge, travel_sign: float, source_id: String
) -> Dictionary:
	var pos := state.position
	var vel := state.velocity if state.is_airborne() else Vector3(
		state.tangent_velocity.x * travel_sign, state.tangent_velocity.y, absf(state.tangent_velocity.x)
	)
	var samp := dest.sample_at_z(pos.y)
	var land_x := float(samp.coping_x)
	var land_h := float(samp.height)
	var dx := land_x - pos.x
	if dx * travel_sign <= 0.0:
		return _reject("target behind travel")
	# Landing time on descending ballistic branch: land_h = h0 + v0 t + 0.5 g t^2
	var h0 := pos.z
	var v0 := vel.z if state.is_airborne() else maxf(absf(state.tangent_velocity.x), 40.0)
	if not state.is_airborne():
		v0 = absf(v0) ## rising launch
	var g := SimTolerances.GRAVITY
	var land_t := _solve_descend_time(h0, v0, land_h, g)
	if land_t < 0.05:
		return _reject("unreachable land time")
	# Clearance corridor sample.
	var steps := 12
	for i in range(1, steps):
		var t := land_t * float(i) / float(steps)
		var xi := lerpf(pos.x, land_x, float(i) / float(steps))
		var zi := pos.y
		var hi := h0 + v0 * t + 0.5 * g * t * t
		# Soft floor: must clear supports below by CONTACT_EPS unless destination.
		var supports := query.supports_below(xi, zi, hi + 50.0)
		for s in supports:
			if float(s.height) > hi + SimTolerances.CONTACT_EPS:
				# Would clip a taller solid.
				if str(s.surface_id) != dest.support_patch_id:
					var hit := query.sweep_capsule(
						Vector3(pos.x, pos.y, h0), Vector3(xi, zi, hi)
					)
					if not hit.is_empty() and str(hit.get("kind", "")) == "wall":
						return _reject("clearance blocked")
	var plan := ManeuverPlan.new()
	plan.kind = kind
	plan.source_coping_id = source_id
	plan.dest_coping_id = dest.id
	plan.dest_pipe_id = dest.pipe_id
	plan.start_position = pos
	plan.start_velocity = Vector3(vel.x if state.is_airborne() else travel_sign * absf(v0), vel.y, v0)
	plan.land_time = land_t
	plan.z_start = pos.y
	plan.z_end = pos.y
	plan.land_height = land_h
	plan.land_x = land_x
	plan.travel_sign = travel_sign
	plan.land_along = -travel_sign * maxf(absf(v0), 80.0) ## into bowl
	plan.x_coeffs = _quintic_x(pos.x, plan.start_velocity.x, land_x, land_t)
	# Validate monotonic X in travel direction.
	var prev := pos.x
	for i in range(1, 17):
		var t := land_t * float(i) / 16.0
		var xi := plan.sample_x(t)
		if (xi - prev) * travel_sign < -0.01:
			return _reject("non-monotonic X")
		prev = xi
	var corridor := query.sweep_capsule(
		pos, Vector3(land_x, pos.y, land_h + SimTolerances.CONTACT_EPS)
	)
	if not corridor.is_empty() and str(corridor.get("kind", "")) == "wall":
		return _reject("corridor wall")
	return {"ok": true, "plan": plan}


func _solve_descend_time(h0: float, v0: float, land_h: float, g: float) -> float:
	# 0.5 g t^2 + v0 t + (h0 - land_h) = 0
	var a := 0.5 * g
	var b := v0
	var c := h0 - land_h
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		# Force a climb then descend: use apex then fall.
		if v0 <= 0.0:
			return -1.0
		var t_apex := -v0 / g
		var h_apex := h0 + v0 * t_apex + 0.5 * g * t_apex * t_apex
		if land_h > h_apex + 0.001:
			return -1.0
		# Fall from apex: land_h = h_apex + 0.5 g t_fall^2
		var fall := sqrt(maxf((land_h - h_apex) / (0.5 * g), 0.0)) if g < 0.0 else -1.0
		# Wait g is negative; (land_h - h_apex) negative; / (0.5*g) positive.
		fall = sqrt(maxf(2.0 * (h_apex - land_h) / absf(g), 0.0))
		return t_apex + fall
	var sqrt_d := sqrt(disc)
	var t1 := (-b + sqrt_d) / (2.0 * a)
	var t2 := (-b - sqrt_d) / (2.0 * a)
	# Prefer positive root on descending branch (velocity at land ≤ 0).
	var best := -1.0
	for t in [t1, t2]:
		if t < 0.05:
			continue
		var v_land: float = v0 + g * t
		if v_land > 0.5:
			continue
		if best < 0.0 or t < best:
			best = t
	return best


func _quintic_x(x0: float, v0: float, x1: float, T: float) -> PackedFloat32Array:
	# Boundary: x(0)=x0, x'(0)=v0, x''(0)=0, x(T)=x1, x'(T)=0, x''(T)=0
	# Standard minimum-jerk / rest-to-rest with initial velocity.
	var T2 := T * T
	var T3 := T2 * T
	var T4 := T3 * T
	var T5 := T4 * T
	# Solve for a3,a4,a5 with a0=x0, a1=v0, a2=0.
	# x1 = x0 + v0 T + a3 T3 + a4 T4 + a5 T5
	# 0 = v0 + 3 a3 T2 + 4 a4 T3 + 5 a5 T4
	# 0 = 6 a3 T + 12 a4 T2 + 20 a5 T3
	var A := PackedFloat32Array([
		T3, T4, T5,
		3.0 * T2, 4.0 * T3, 5.0 * T4,
		6.0 * T, 12.0 * T2, 20.0 * T3,
	])
	var rhs := PackedFloat32Array([
		x1 - x0 - v0 * T,
		-v0,
		0.0,
	])
	var sol := _solve3(A, rhs)
	return PackedFloat32Array([x0, v0, 0.0, sol[0], sol[1], sol[2]])


func _solve3(A: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	# Row-major 3x3.
	var m := [
		[A[0], A[1], A[2], b[0]],
		[A[3], A[4], A[5], b[1]],
		[A[6], A[7], A[8], b[2]],
	]
	for col in range(3):
		var pivot := col
		for r in range(col + 1, 3):
			if absf(m[r][col]) > absf(m[pivot][col]):
				pivot = r
		var tmp = m[col]
		m[col] = m[pivot]
		m[pivot] = tmp
		var div: float = m[col][col]
		if absf(div) < 1e-9:
			return PackedFloat32Array([0.0, 0.0, 0.0])
		for c in range(col, 4):
			m[col][c] /= div
		for r in range(3):
			if r == col:
				continue
			var f: float = m[r][col]
			for c in range(col, 4):
				m[r][c] -= f * m[col][c]
	return PackedFloat32Array([m[0][3], m[1][3], m[2][3]])


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
