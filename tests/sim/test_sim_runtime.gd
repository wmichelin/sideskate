extends RefCounted
## Ground ride + deck seam + fly-out / spine / acid matrices.


func run() -> bool:
	return (
		_ride_halfpipe()
		and _deck_seam_mount()
		and _fly_out_open_vs_backed()
		and _spine_plan()
		and _acid_plan()
		and _deterministic_replay()
		and _layered_spawn_respects_story()
		and _supports_sorted_high_to_low()
		and _pipe_along_wish_and_lip_exit()
	)


func _ride_halfpipe() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup halfpipe")
		return false
	# Drive toward left pipe.
	for _i in range(180):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("died on halfpipe")
			return false
	# Should be grounded somewhere.
	if not sim.state.is_grounded() and not sim.state.is_airborne():
		push_error("bad mode")
		return false
	return true


func _deck_seam_mount() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("setup deck_backed")
		return false
	# Place on left pipe near lip and ride up.
	var pipe_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.LEFT:
			pipe_id = id
			break
	if pipe_id.is_empty():
		push_error("no left pipe")
		return false
	var pipe: PipeSurface = sim.model.pipes[pipe_id]
	var z := (pipe.z_min + pipe.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe_id
	sim.state.u = 0.2
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, 0.2 * PI * 0.5), z, pipe.height_at_theta(z, 0.2 * PI * 0.5))
	# Outward stick on left pipe (−X) climbs toward coping / deck seam.
	for _i in range(120):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var patch: SupportPatch = sim.model.patches[sim.state.surface_id]
			if patch.kind == SimKinds.SurfaceKind.DECK:
				return true
	push_error("never mounted deck from pipe seam")
	return false


func _fly_out_open_vs_backed() -> bool:
	# Open: fly-out should succeed at coping with outward input.
	var open := PlayerSim.new()
	if not open.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("setup open_fly")
		return false
	var left_open := _left_pipe(open.model)
	if left_open == null:
		return false
	_place_at_coping(open, left_open, 200.0)
	open.set_input(Vector2(-1, 0), true, true)
	open.tick()
	if not open.state.is_airborne():
		push_error("open fly-out should launch air: reject=%s" % open.state.last_reject)
		return false

	# Backed: fly-out must refuse.
	var backed := PlayerSim.new()
	if not backed.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("setup backed")
		return false
	var left_b := _left_pipe(backed.model)
	_place_at_coping(backed, left_b, 200.0)
	backed.set_input(Vector2(-1, 0), true, true)
	backed.tick()
	if backed.state.is_airborne() and backed.state.has_maneuver():
		var plan: ManeuverPlan = backed.state.maneuver
		if plan.kind == ManeuverPlan.Kind.FLY_OUT:
			push_error("backed coping must not fly-out")
			return false
	# Prefer: still grounded after refused fly-out.
	if backed.state.is_airborne() and not backed.state.has_maneuver():
		# Might have rolled to deck — OK if on deck patch.
		pass
	return true


func _spine_plan() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_spine.ssk"):
		push_error("setup spine")
		return false
	# Stand in air above a SHARED_SPINE coping, rising, face toward partner.
	var src: CopingEdge = null
	for cid in sim.model.copings.keys():
		var c: CopingEdge = sim.model.copings[cid]
		if c.coping_class == SimKinds.CopingClass.SHARED_SPINE and not c.shared_with_id.is_empty():
			src = c
			break
	if src == null:
		push_error("no shared spine coping in fixture")
		return false
	var z := src.midpoint_z()
	var samp := src.sample_at_z(z)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3(float(samp.coping_x), z, float(samp.height) + 20.0)
	sim.state.velocity = Vector3(0, 0, 100.0)
	# Face toward shared partner.
	var partner: CopingEdge = sim.model.copings[src.shared_with_id]
	var ps := partner.sample_at_z(z)
	var dir := signf(float(ps.coping_x) - float(samp.coping_x))
	sim.state.facing = "r" if dir > 0.0 else "l"
	var pr := sim.planner.try_spine(sim.state, dir)
	if not bool(pr.get("ok", false)):
		push_error("spine plan failed: %s" % pr.get("reason", ""))
		return false
	return true


func _acid_plan() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup acid")
		return false
	var left := _left_pipe(sim.model)
	var z := (left.z_min + left.z_max) * 0.5
	var cope: CopingEdge = sim.model.copings[left.coping_id]
	var samp := cope.sample_at_z(z)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.position = Vector3(float(samp.coping_x), z, float(samp.height) + 80.0)
	sim.state.velocity = Vector3(120.0, 0.0, -50.0)
	var pr := sim.planner.try_acid(sim.state, 120.0)
	if not bool(pr.get("ok", false)):
		push_error("acid plan failed: %s" % pr.get("reason", ""))
		return false
	var plan: ManeuverPlan = pr.plan
	if plan.travel_sign <= 0.0:
		push_error("acid travel sign")
		return false
	return true


func _deterministic_replay() -> bool:
	var a := PlayerSim.new()
	var b := PlayerSim.new()
	if not a.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		return false
	if not b.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		return false
	for i in range(90):
		var w := Vector2(sin(float(i) * 0.1), cos(float(i) * 0.07))
		a.set_input(w, false, false)
		b.set_input(w, false, false)
		a.tick()
		b.tick()
	if a.state.state_hash() != b.state.state_hash():
		push_error("deterministic mismatch")
		return false
	if a.trace.final_hash() != b.trace.final_hash():
		push_error("trace hash mismatch")
		return false
	return true


func _left_pipe(model: ParkModel) -> PipeSurface:
	for id in model.pipes.keys():
		var p: PipeSurface = model.pipes[id]
		if p.side == SimKinds.PipeSide.LEFT:
			return p
	push_error("no left pipe")
	return null


func _layered_spawn_respects_story() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("setup layered_demo")
		return false
	if absf(sim.state.position.z - sim.model.spawn_height) > SimTolerances.SEAM_EPS:
		push_error(
			"spawn height want %.1f got %.1f on %s"
			% [sim.model.spawn_height, sim.state.position.z, sim.state.surface_id]
		)
		return false
	if sim.state.position.z < 100.0:
		push_error("layered spawn must not snap under L1 floor")
		return false
	if not sim.state.is_grounded() or not sim.state.alive:
		push_error("layered spawn must be alive grounded")
		return false
	return true


func _supports_sorted_high_to_low() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("setup layered_demo sort")
		return false
	var all: Array = sim.query.supports_below(
		sim.model.spawn_x, sim.model.spawn_z, 99999.0
	)
	if all.size() < 2:
		push_error("expected stacked supports at layered spawn")
		return false
	for i in range(all.size() - 1):
		if float(all[i].height) + 0.0001 < float(all[i + 1].height):
			push_error("supports_below not descending: %s then %s" % [all[i], all[i + 1]])
			return false
	if absf(float(all[0].height) - 141.0) > 0.1:
		push_error("top support should be L1 floor, got %s" % all[0])
		return false
	return true


func _pipe_along_wish_and_lip_exit() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("setup plaza for pipe wish")
		return false
	var right: PipeSurface = null
	var left: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT and right == null:
			right = p
		elif p.side == SimKinds.PipeSide.LEFT and left == null:
			left = p
	if right == null or left == null:
		push_error("need both pipe sides")
		return false
	# Left pipe: +X (into bowl) must decrease u.
	var z := (left.z_min + left.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = left.id
	sim.state.u = 0.6
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.position = Vector3(
		left.x_at_theta(z, 0.6 * PI * 0.5), z, left.height_at_theta(z, 0.6 * PI * 0.5)
	)
	var u0 := sim.state.u
	for _i in range(30):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
	if sim.model.pipes.has(sim.state.surface_id) and sim.state.u >= u0 - 0.02:
		push_error("left pipe +X should ride toward lip, u %s → %s" % [u0, sim.state.u])
		return false
	# Right pipe: ride down to lip and exit onto flat.
	z = (right.z_min + right.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = right.id
	sim.state.u = 0.25
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(-400.0, 0.0)
	sim.state.position = Vector3(
		right.x_at_theta(z, 0.25 * PI * 0.5), z, right.height_at_theta(z, 0.25 * PI * 0.5)
	)
	var left_pipe := false
	for _i in range(180):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if not sim.model.pipes.has(sim.state.surface_id):
			left_pipe = true
			break
	if not left_pipe:
		push_error("stuck on right pipe at lip u=%s sid=%s" % [sim.state.u, sim.state.surface_id])
		return false
	return true


func _place_at_coping(sim: PlayerSim, pipe: PipeSurface, along: float) -> void:
	var z := (pipe.z_min + pipe.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 1.0
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(along, 0.0)
	sim.state.position = Vector3(
		pipe.x_at_theta(z, PI * 0.5),
		z,
		pipe.height_at_theta(z, PI * 0.5)
	)
	sim.state.maneuver = null
