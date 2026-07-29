extends RefCounted
## Ground ride + deck seam + fly-out / spine / acid matrices.


func run() -> bool:
	return (
		_ride_halfpipe()
		and _fly_out_open_vs_backed()
		and _hang_x_lock_until_fly_out()
		and _hang_land_into_bowl()
		and _spine_plan()
		and _acid_plan()
		and _deterministic_replay()
		and _layered_spawn_respects_story()
		and _supports_sorted_high_to_low()
		and _pipe_along_wish_and_lip_exit()
		and _ollie_faces_direction()
		and _coast_with_zero_friction()
		and _air_no_x_friction()
		and _wall_extension_climbs()
		and _layered_fly_out_at_upper_lip()
		and _void_floor_catches_fall()
		and _world_border_contains()
		and _edge_pipe_coping_not_in_wall()
		and _pipe_body_no_clip()
		and _embedded_pipe_no_phase_through()
		and _embedded_pipe_mounts_not_sticks()
		and _spine_deck_solid_from_floor()
		and _land_snaps_out_of_pipe_solid()
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


func _fly_out_open_vs_backed() -> bool:
	# Open: stick-only outward X-dominant fly-out at coping (no transfer button).
	var open := PlayerSim.new()
	if not open.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("setup open_fly")
		return false
	var left_open := _left_pipe(open.model)
	if left_open == null:
		return false
	_place_at_coping(open, left_open, 80.0)
	open.set_input(Vector2(-1, 0), false, true)
	open.tick()
	if not open.state.is_airborne():
		push_error("open stick fly-out should launch air: reject=%s" % open.state.last_reject)
		return false

	# Ride into OPEN coping with along only (no stick): hang air, X-locked.
	var launch := PlayerSim.new()
	if not launch.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("setup open_fly launch")
		return false
	var left_l := _left_pipe(launch.model)
	_place_at_coping(launch, left_l, 200.0)
	launch.set_input(Vector2.ZERO, false, true)
	launch.tick()
	if not launch.state.is_airborne() or not launch.state.is_hanging():
		push_error("OPEN coping with along must hang-air")
		return false

	# Backed same-height #: OPEN air/fly corridor — outward stick fly-out / deck-out.
	var backed := PlayerSim.new()
	if not backed.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("setup backed")
		return false
	var left_b := _left_pipe(backed.model)
	_place_at_coping(backed, left_b, 80.0)
	backed.set_input(Vector2(-1, 0), false, true)
	backed.tick()
	if not backed.state.is_airborne():
		push_error("deck-backed stick fly-out should launch: reject=%s" % backed.state.last_reject)
		return false
	if backed.state.is_hanging():
		push_error("deck-backed fly-out should unlock X (not remain air-out)")
		return false
	# No stick: rise into coping → air-out hang, not deck seam mount.
	var air := PlayerSim.new()
	if not air.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("setup backed air-out")
		return false
	var left_a := _left_pipe(air.model)
	_place_at_coping(air, left_a, 200.0)
	air.set_input(Vector2.ZERO, false, true)
	air.tick()
	if not air.state.is_airborne() or not air.state.is_hanging():
		push_error("deck-backed along must air-out hang, not mount deck")
		return false
	return true


func _hang_x_lock_until_fly_out() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("setup hang lock")
		return false
	var left := _left_pipe(sim.model)
	_place_at_coping(sim, left, 200.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("expected hang after coping leave")
		return false
	var lock_x := left.coping_x_at(sim.state.position.y)
	# Z-dominant stick: stay hang-locked (not X-dominant fly-out).
	sim.set_input(Vector2(-0.2, 0.9), false, false)
	for _i in range(2):
		sim.tick()
		if not sim.state.is_hanging():
			push_error("hang cleared without fly-out/spine reject=%s" % sim.state.last_reject)
			return false
		if absf(sim.state.position.x - lock_x) > SimTolerances.CONTACT_EPS:
			push_error("hang drifted X: got %.2f want %.2f" % [sim.state.position.x, lock_x])
			return false
		if absf(sim.state.velocity.x) > 0.01:
			push_error("hang must keep vx=0")
			return false
	# Explicit X-dominant outward fly-out unlocks free air (no transfer edge).
	sim.set_input(Vector2(-1, 0), false, false)
	sim.tick()
	if sim.state.is_hanging():
		push_error("fly-out should clear hang: reject=%s h=%.1f vh=%.1f" % [
			sim.state.last_reject, sim.state.position.z, sim.state.velocity.z
		])
		return false
	if not sim.state.is_airborne():
		push_error("fly-out should leave airborne free")
		return false
	if sim.state.velocity.x >= -1.0:
		push_error("fly-out should seed outward (-X) velocity, got %s" % sim.state.velocity)
		return false
	return true


func _hang_land_into_bowl() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("setup hang land")
		return false
	var left := _left_pipe(sim.model)
	_place_at_coping(sim, left, 350.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("expected hang after launch")
		return false
	var exit_vh := sim.state.velocity.z
	if exit_vh < 300.0:
		push_error("hang should keep exit along as vertical (got %.1f)" % exit_vh)
		return false
	# Fall back to coping — must drop into bowl, not bounce forever at u=1.
	var landed := false
	for _i in range(90):
		sim.tick()
		if sim.state.is_grounded() and sim.model.pipes.has(sim.state.surface_id):
			landed = true
			if sim.state.tangent_velocity.x >= -1.0:
				push_error("hang land must seed into-bowl along (-), got %s" % sim.state.tangent_velocity.x)
				return false
			var u0 := sim.state.u
			for _j in range(20):
				sim.tick()
				if not sim.state.is_grounded():
					push_error("hang land re-launched into air (stuck bounce)")
					return false
			if sim.state.u >= u0 - 0.01:
				push_error("hang land should ride down pipe, u %s → %s" % [u0, sim.state.u])
				return false
			break
	if not landed:
		push_error("never landed from hang")
		return false
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


func _ollie_faces_direction() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie")
		return false
	sim.ollie_accel = 650.0
	sim.max_speed = 880.0
	# Facing right, no stick: ollie should build +X velocity.
	sim.state.facing = "r"
	sim.state.tangent_velocity = Vector2.ZERO
	var x0 := sim.state.position.x
	for _i in range(30):
		sim.set_input(Vector2.ZERO, false, false, true)
		sim.tick()
		if not sim.state.is_grounded():
			break
	if sim.state.tangent_velocity.x < 200.0:
		push_error("ollie facing-r should accumulate +X (got %s)" % sim.state.tangent_velocity.x)
		return false
	if sim.state.position.x <= x0 + 5.0:
		push_error("ollie facing-r should move +X noticeably")
		return false
	# Facing left, no stick: accelerate −X.
	sim.state.facing = "l"
	sim.state.tangent_velocity = Vector2.ZERO
	for _i in range(30):
		sim.set_input(Vector2.ZERO, false, false, true)
		sim.tick()
		if not sim.state.is_grounded():
			break
	if sim.state.tangent_velocity.x >= -10.0:
		push_error("ollie facing-l should accelerate -X, tv=%s" % sim.state.tangent_velocity)
		return false
	return true


func _coast_with_zero_friction() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup coast")
		return false
	sim.friction = 0.0
	sim.brake = 1250.0
	sim.accel = 3250.0
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	var vx0 := sim.state.tangent_velocity.x
	var floor_id := sim.state.surface_id
	for _i in range(12):
		sim.set_input(Vector2.ZERO, false, false, false)
		sim.tick()
		if sim.state.surface_id != floor_id:
			break
	if sim.state.surface_id == floor_id and absf(sim.state.tangent_velocity.x - vx0) > 1.0:
		push_error("zero friction must coast, vx %s → %s" % [vx0, sim.state.tangent_velocity.x])
		return false
	# Stick opposite velocity brakes toward zero.
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.set_input(Vector2(-1, 0), false, false, false)
	sim.tick()
	if sim.state.tangent_velocity.x >= 400.0 - 1.0:
		push_error("opposite stick should brake, got %s" % sim.state.tangent_velocity.x)
		return false
	if sim.state.tangent_velocity.x < 0.0:
		push_error("brake must not reverse in one tick, got %s" % sim.state.tangent_velocity.x)
		return false
	# Depth: release snaps Z velocity to 0 (no momentum).
	sim.state.tangent_velocity.y = 300.0
	sim.set_input(Vector2.ZERO, false, false, false)
	sim.tick()
	if absf(sim.state.tangent_velocity.y) > 0.01:
		push_error("depth must stop immediately on release, got %s" % sim.state.tangent_velocity.y)
		return false
	sim.set_input(Vector2(0, 1), false, false, false)
	sim.tick()
	if absf(sim.state.tangent_velocity.y - sim.max_speed_z) > 0.01:
		push_error("depth stick should set vz=max, got %s" % sim.state.tangent_velocity.y)
		return false
	return true


func _air_no_x_friction() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("air friction: setup")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	# High over the flat bowl so we do not clip a pipe body mid-fall.
	sim.state.position = Vector3(sim.model.width * 0.5, sim.model.depth * 0.5, 400.0)
	sim.state.velocity = Vector3(350.0, 0.0, 0.0)
	var vx0 := sim.state.velocity.x
	for _i in range(12):
		sim.set_input(Vector2.ZERO, false, false, false)
		sim.tick()
		if not sim.state.is_airborne():
			push_error("air friction: unexpectedly landed")
			return false
		if absf(sim.state.velocity.x - vx0) > 1.0:
			push_error(
				"air must conserve X with neutral stick (no friction), %s → %s"
				% [vx0, sim.state.velocity.x]
			)
			return false
	return true


func _wall_extension_climbs() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_wall_extension.ssk"):
		push_error("setup wall_extension fixture")
		return false
	# Find a WALL_EXTENSION pipe (taller outward floor).
	var wall_pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		var c: CopingEdge = sim.model.copings.get(p.coping_id)
		if c != null and c.coping_class == SimKinds.CopingClass.WALL_EXTENSION:
			wall_pipe = p
			break
	if wall_pipe == null:
		push_error("no WALL_EXTENSION pipe in sim_wall_extension")
		return false
	var cope: CopingEdge = sim.model.copings[wall_pipe.coping_id]
	var z := (wall_pipe.z_min + wall_pipe.z_max) * 0.5
	var h_geom := wall_pipe.height_at_theta(z, PI * 0.5)
	var h_eff := float(cope.sample_at_z(z).height)
	if h_eff <= h_geom + 10.0:
		push_error("expected tall wall extension")
		return false
	# Start just below geometric coping with strong along.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall_pipe.id
	sim.state.u = 0.92
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.position = Vector3(
		wall_pipe.x_at_theta(z, 0.92 * PI * 0.5),
		z,
		wall_pipe.height_at_theta(z, 0.92 * PI * 0.5)
	)
	var saw_wall := false
	var heights: Array = []
	for _i in range(90):
		sim.set_input(Vector2(wall_pipe.outward_sign(), 0), false, false)
		sim.tick()
		if not sim.state.is_grounded():
			push_error("left ground mid wall-climb")
			return false
		if sim.model.pipes.has(sim.state.surface_id) and sim.state.u > 1.05 and sim.state.u < 1.95:
			saw_wall = true
			heights.append(sim.state.position.z)
			# Must not teleport to pad top in one step from geometric.
			if sim.state.position.z >= h_eff - 1.0 and heights.size() < 3:
				push_error("teleported to pad top instead of climbing wall")
				return false
		if sim.model.patches.has(sim.state.surface_id):
			# Mounted floor after climb.
			if not saw_wall:
				push_error("mounted pad without climbing wall u-range")
				return false
			if absf(sim.state.position.z - h_eff) > SimTolerances.SEAM_EPS * 2.0:
				push_error("pad mount height %.1f want ~%.1f" % [sim.state.position.z, h_eff])
				return false
			# Climbing heights should increase monotonically while on wall.
			for hi in range(heights.size() - 1):
				if float(heights[hi + 1]) + 0.5 < float(heights[hi]):
					push_error("wall height went down while climbing")
					return false
			return true
	push_error("never mounted pad after wall climb (saw_wall=%s u=%s h=%.1f)" % [
		saw_wall, sim.state.u, sim.state.position.z
	])
	return false


func _layered_fly_out_at_upper_lip() -> bool:
	# L0 right under L1 left: fly-out at L0 geometric must fail; after climb, fly at L1 height.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("setup layered fly")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		if str(id).begins_with("pipe_1_L0"):
			pipe = sim.model.pipes[id]
			break
	if pipe == null:
		push_error("no L0 right")
		return false
	var cope: CopingEdge = sim.model.copings[pipe.coping_id]
	if cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
		push_error("expected WALL_EXTENSION, got %s" % cope.class_name_str())
		return false
	# Use Z overlapping an L1 left pipe.
	var z := 1000.0
	z = clampf(z, pipe.z_min, pipe.z_max)
	var h_geom := pipe.height_at_theta(z, PI * 0.5)
	var h_eff := float(cope.sample_at_z(z).height)
	# At geometric lip with outward stick — must not fly through L1.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 0.99
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, PI * 0.5), z, h_geom)
	sim.set_input(Vector2(1, 0), false, false)
	sim.tick()
	if sim.state.is_airborne() and not sim.state.is_hanging() and absf(sim.state.position.z - h_geom) < 30.0:
		push_error("must not free-fly at L0 geometric height")
		return false
	# Climb to effective lip.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 0.95
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, 0.95 * PI * 0.5), z, pipe.height_at_theta(z, 0.95 * PI * 0.5))
	for _i in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging() and sim.state.position.z >= h_eff - SimTolerances.CONTACT_EPS * 2.0:
			break
		if sim.state.is_grounded() and sim.state.u >= 1.98:
			break
	if sim.state.position.z < h_eff - 20.0 and not (sim.state.is_grounded() and sim.state.u >= 1.98):
		push_error("never reached upper lip h=%.1f got %.1f" % [h_eff, sim.state.position.z])
		return false
	# Fly-out at upper lip.
	sim.set_input(Vector2(1, 0), false, false)
	sim.tick()
	if sim.state.is_hanging():
		# Need rising window — seed upward if we landed flat at top.
		sim.state.velocity.z = maxf(sim.state.velocity.z, 80.0)
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
	if sim.state.is_hanging():
		push_error("fly-out at L1 lip should unlock: reject=%s h=%.1f" % [
			sim.state.last_reject, sim.state.position.z
		])
		return false
	if not sim.state.is_airborne():
		push_error("expected free air after upper fly-out")
		return false
	if sim.state.position.z < h_eff - 40.0:
		push_error("fly-out height still near L0 (%.1f)" % sim.state.position.z)
		return false
	return true


func _void_floor_catches_fall() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("void: setup")
		return false
	# Drop in free air above the park with no nearby pad under feet search —
	# punch through a mid-air spawn so only the void floor remains reachable.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.position = Vector3(sim.model.width * 0.5, sim.model.depth * 0.5, 50.0)
	sim.state.velocity = Vector3(0.0, 0.0, -10.0)
	# Clear real floors under this XZ by teleporting over a guaranteed hole:
	# use world center; open_fly is all floor — land on real floor first is OK,
	# then force height below all real pads so void is next.
	var real_top := sim.query.top_support(
		sim.state.position.x, sim.state.position.y, 5000.0
	)
	if real_top.is_empty():
		push_error("void: expected some support")
		return false
	# Start just above void with descending velocity; search ceiling excludes real pads.
	sim.state.position.z = SimTolerances.VOID_FLOOR + 30.0
	sim.state.velocity = Vector3(0.0, 0.0, -200.0)
	var landed := false
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("void: died falling — must stay alive")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == "__void_floor__":
			landed = true
			break
	if not landed:
		push_error(
			"void: expected land on __void_floor__ got mode=%s id=%s h=%.1f"
			% [sim.state.mode, sim.state.surface_id, sim.state.position.z]
		)
		return false
	return true


func _world_border_contains() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("border: setup")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	var mid_z := sim.model.depth * 0.5
	sim.state.position = Vector3(sim.model.width - 20.0, mid_z, 80.0)
	sim.state.velocity = Vector3(800.0, 0.0, 0.0)
	var wall := sim.model.width + SimTolerances.CAPSULE_RADIUS
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("border: died at world edge")
			return false
		if sim.state.position.x > wall + 1.0:
			push_error("border: escaped east wall x=%.1f" % sim.state.position.x)
			return false
		if sim.state.position.x < -SimTolerances.CAPSULE_RADIUS - 1.0:
			push_error("border: escaped west wall")
			return false
	return true


func _edge_pipe_coping_not_in_wall() -> bool:
	# Plaza-style edge >>> must hang at coping without immediately hitting bounds.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("edge: setup plaza")
		return false
	var best: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		if best == null or p.coping_x_at((p.z_min + p.z_max) * 0.5) \
				> best.coping_x_at((best.z_min + best.z_max) * 0.5):
			best = p
	if best == null:
		push_error("edge: no right pipe")
		return false
	var z := (best.z_min + best.z_max) * 0.5
	var cx := best.coping_x_at(z)
	var hit := sim.query.blocker_at(Vector3(cx, z, best.height_at_theta(z, PI * 0.5)))
	if str(hit.get("kind", "")) == "bounds":
		push_error("edge: coping x=%.1f blocked by bounds %s" % [cx, hit])
		return false
	# Ride up into air-out hang; must keep living and not pin against the wall.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = best.id
	sim.state.u = 0.85
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	var th := sim.state.u * PI * 0.5
	sim.state.position = Vector3(
		best.x_at_theta(z, th), z, best.height_at_theta(z, th)
	)
	var hung := false
	for _i in range(60):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("edge: died riding edge pipe")
			return false
		if sim.state.is_hanging():
			hung = true
			# Hang X is coping; must not be a bounds hit.
			var h2 := sim.query.blocker_at(sim.state.position)
			if str(h2.get("kind", "")) == "bounds":
				push_error("edge: hang pinned in bounds at x=%.1f" % sim.state.position.x)
				return false
			break
	if not hung:
		push_error("edge: expected air-out hang at OPEN edge coping")
		return false
	return true


func _pipe_body_no_clip() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("clip: setup")
		return false
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var mid_x := left.x_at_theta(z, PI * 0.35)
	var mid_h := left.height_at_theta(z, PI * 0.35)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	# Start in the bowl, drive into the pipe body below the ride surface.
	var out := left.outward_sign()
	sim.state.position = Vector3(mid_x - out * 60.0, z, mid_h - 25.0)
	# Ensure start is not already solid.
	if not sim.query.blocker_at(sim.state.position).is_empty():
		sim.state.position.x = mid_x - out * 90.0
	sim.state.velocity = Vector3(out * 900.0, 0.0, 0.0)
	var deepest_pen := 0.0
	for _i in range(90):
		sim.set_input(Vector2(signf(out), 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("clip: died against pipe body")
			return false
		if left.contains_xz(sim.state.position.x, sim.state.position.y):
			var proj := left.project(sim.state.position.x, sim.state.position.y, sim.state.position.z)
			if bool(proj.get("ok", false)):
				var pen := float(proj.point.z) - sim.state.position.z
				if pen > deepest_pen:
					deepest_pen = pen
				# Allow tiny numerical overlap; deep tunnel is a fail.
				if pen > SimTolerances.CAPSULE_RADIUS:
					push_error(
						"clip: penetrated pipe body pen=%.1f h=%.1f surface=%.1f"
						% [pen, sim.state.position.z, float(proj.point.z)]
					)
					return false
	if deepest_pen > SimTolerances.CONTACT_EPS * 4.0:
		# Hit response should keep us out; brief skim OK, sustained deep no.
		pass
	return true


func _embedded_pipe_no_phase_through() -> bool:
	# Floor wraps around an embedded >> pipe; floor poly may cover the pipe
	# cells, but grounded motion must not walk through the solid body.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_embedded_pipe.ssk"):
		push_error("embed: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		pipe = sim.model.pipes[id]
		break
	if pipe == null:
		push_error("embed: no pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var lip := float((pipe.samples[0] as Dictionary).lip_x)
	var radius := float((pipe.samples[0] as Dictionary).radius)
	var coping_x := lip + radius # right-facing
	# Start on floor left of the lip; charge right through the obstacle.
	sim.state.mode = SimState.Mode.GROUNDED
	# Prefer any floor patch under spawn.
	var floor_id := ""
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) != SimKinds.SurfaceKind.FLOOR or pid.begins_with("__"):
			continue
		if p.contains_xz(lip - 40.0, z):
			floor_id = pid
			break
	if floor_id.is_empty():
		push_error("embed: no floor left of pipe")
		return false
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(lip - 40.0, z, 0.0)
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.u = 0.0
	sim.state.v = 0.0
	var max_h := 0.0
	var rode_pipe := false
	var phased := false
	for _i in range(240):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("embed: died")
			return false
		max_h = maxf(max_h, sim.state.position.z)
		if sim.state.is_grounded() and sim.model.pipes.has(sim.state.surface_id):
			rode_pipe = true
		# Deep inside pipe body below ride surface = fail.
		if pipe.contains_xz(sim.state.position.x, sim.state.position.y):
			var proj := pipe.project(
				sim.state.position.x, sim.state.position.y, sim.state.position.z
			)
			if bool(proj.get("ok", false)):
				var ph := float(proj.point.z)
				if sim.state.position.z < ph - SimTolerances.CAPSULE_RADIUS:
					push_error(
						"embed: phased into pipe body h=%.1f surface=%.1f x=%.1f"
						% [sim.state.position.z, ph, sim.state.position.x]
					)
					return false
		# Past coping on the far floor without ever climbing = walked through the solid.
		if sim.state.position.x > coping_x + SimTolerances.CAPSULE_RADIUS \
				and sim.state.position.z < 20.0 \
				and sim.state.is_grounded() \
				and not rode_pipe \
				and max_h < radius * 0.35:
			phased = true
			break
	if phased:
		push_error("embed: walked through pipe to far side at floor height")
		return false
	# From the back (outward) side: may mount the pipe and ride, but must not
	# skate the floor under the arc through to the lip.
	sim.respawn()
	var floor_r := ""
	for pid2 in sim.model.patches.keys():
		var p2: SupportPatch = sim.model.patches[pid2]
		if int(p2.kind) != SimKinds.SurfaceKind.FLOOR or pid2.begins_with("__"):
			continue
		if p2.contains_xz(coping_x + 40.0, z):
			floor_r = pid2
			break
	if floor_r.is_empty():
		push_error("embed: no floor right of pipe")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_r
	sim.state.position = Vector3(coping_x + 40.0, z, 0.0)
	sim.state.tangent_velocity = Vector2(-400.0, 0.0)
	sim.state.u = 0.0
	sim.state.v = 0.0
	var rode_from_back := false
	for _j in range(240):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("embed: died from back")
			return false
		if sim.model.pipes.has(sim.state.surface_id):
			rode_from_back = true
		if pipe.contains_xz(sim.state.position.x, sim.state.position.y):
			var proj2 := pipe.project(
				sim.state.position.x, sim.state.position.y, sim.state.position.z
			)
			if bool(proj2.get("ok", false)) \
					and sim.state.position.z < float(proj2.point.z) - SimTolerances.CAPSULE_RADIUS:
				push_error("embed: phased into pipe from back")
				return false
		if sim.state.position.x < lip - SimTolerances.CAPSULE_RADIUS \
				and sim.state.position.z < 20.0 \
				and sim.state.is_grounded() \
				and not sim.model.pipes.has(sim.state.surface_id) \
				and not rode_from_back:
			push_error("embed: walked through pipe from back to lip side")
			return false
	return true


func _embedded_pipe_mounts_not_sticks() -> bool:
	# Approaching >> from the lip must mount the ride surface, not stick under the arc.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_embedded_pipe.ssk"):
		push_error("mount: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		pipe = sim.model.pipes[id]
		break
	if pipe == null:
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var lip := float((pipe.samples[0] as Dictionary).lip_x)
	var floor_id := ""
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) != SimKinds.SurfaceKind.FLOOR or pid.begins_with("__"):
			continue
		if p.contains_xz(lip - 30.0, z):
			floor_id = pid
			break
	if floor_id.is_empty():
		push_error("mount: no floor")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(lip - 30.0, z, 0.0)
	sim.state.tangent_velocity = Vector2(300.0, 0.0)
	var mounted := false
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.model.pipes.has(sim.state.surface_id):
			mounted = true
			# Feet must sit on the analytical surface, not under it.
			var proj := pipe.project(
				sim.state.position.x, sim.state.position.y, sim.state.position.z
			)
			if bool(proj.get("ok", false)):
				var ph := float(proj.point.z)
				if absf(sim.state.position.z - ph) > SimTolerances.CONTACT_EPS * 2.0:
					push_error(
						"mount: on pipe but off surface h=%.1f want %.1f"
						% [sim.state.position.z, ph]
					)
					return false
			if sim.state.position.z > 5.0 or sim.state.u > 0.05:
				break
	if not mounted:
		push_error("mount: never left floor onto embedded pipe (stuck under arc)")
		return false
	return true


func _spine_deck_solid_from_floor() -> bool:
	# ## spine deck is solid below the top — cannot walk through from the floor
	# and fall through the park.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_spine_deck_solid.ssk"):
		push_error("deck solid: setup")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("deck solid: no deck patch")
		return false
	var z := (deck.z_min + deck.z_max) * 0.5
	var mid_x := (deck.x_min + deck.x_max) * 0.5
	# Start on floor left of the spine, charge through the deck footprint at floor height.
	var floor_id := ""
	for pid2 in sim.model.patches.keys():
		var p2: SupportPatch = sim.model.patches[pid2]
		if int(p2.kind) != SimKinds.SurfaceKind.FLOOR or pid2.begins_with("__"):
			continue
		if p2.contains_xz(deck.x_min - 40.0, z):
			floor_id = pid2
			break
	if floor_id.is_empty():
		# Try farther left / mid floor band.
		for pid3 in sim.model.patches.keys():
			var p3: SupportPatch = sim.model.patches[pid3]
			if int(p3.kind) != SimKinds.SurfaceKind.FLOOR or pid3.begins_with("__"):
				continue
			floor_id = pid3
			break
	if floor_id.is_empty():
		push_error("deck solid: no floor")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(deck.x_min - 50.0, z, 0.0)
	if not sim.model.patches[floor_id].contains_xz(sim.state.position.x, z):
		sim.state.position.x = sim.model.patches[floor_id].x_min + 20.0
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	for _i in range(300):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("deck solid: died")
			return false
		# Must never occupy deck XZ below the top (clip through base).
		if deck.contains_xz(sim.state.position.x, sim.state.position.y) \
				and sim.state.position.z < deck.height - SimTolerances.CONTACT_EPS * 2.0:
			push_error(
				"deck solid: under/through deck h=%.1f top=%.1f x=%.1f"
				% [sim.state.position.z, deck.height, sim.state.position.x]
			)
			return false
		# Must never land on the void floor after crossing the spine.
		if sim.state.surface_id == "__void_floor__":
			push_error("deck solid: fell to void floor through deck")
			return false
	# Direct probe: floor-height sample inside deck is a solid blocker.
	var hit := sim.query.blocker_at(Vector3(mid_x, z, 0.0))
	if str(hit.get("kind", "")) != "deck":
		push_error("deck solid: expected deck blocker at floor under ##, got %s" % hit)
		return false
	return true


func _land_snaps_out_of_pipe_solid() -> bool:
	# Falling into a pipe body must snap onto the ride surface — not stick inside.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("land snap: setup")
		return false
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var mid_x := left.x_at_theta(z, PI * 0.35)
	var mid_h := left.height_at_theta(z, PI * 0.35)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	# Start above the pipe and drop into the solid volume.
	sim.state.position = Vector3(mid_x, z, mid_h + 80.0)
	sim.state.velocity = Vector3(0.0, 0.0, -400.0)
	var snapped := false
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("land snap: died")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			snapped = true
			var proj := left.project(
				sim.state.position.x, sim.state.position.y, sim.state.position.z
			)
			if not bool(proj.get("ok", false)):
				push_error("land snap: grounded but not on pipe band")
				return false
			if absf(sim.state.position.z - float(proj.point.z)) > SimTolerances.CONTACT_EPS:
				push_error(
					"land snap: feet not on surface h=%.1f want %.1f"
					% [sim.state.position.z, float(proj.point.z)]
				)
				return false
			if not sim.query.blocker_at(sim.state.position).is_empty():
				push_error("land snap: still inside solid after land")
				return false
			break
	if not snapped:
		push_error("land snap: never grounded on pipe")
		return false
	# Buried start: already inside solid must resolve on the next grounded/air tick.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.position = Vector3(mid_x, z, mid_h - 20.0)
	sim.state.velocity = Vector3(0.0, 0.0, -10.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if sim.query.blocker_at(sim.state.position).is_empty() == false \
			and not (sim.state.is_grounded() and sim.model.pipes.has(sim.state.surface_id)):
		# One more tick for snap path.
		sim.tick()
	if not sim.query.blocker_at(sim.state.position).is_empty():
		push_error(
			"land snap: remained buried kind=%s h=%.1f"
			% [sim.query.blocker_at(sim.state.position), sim.state.position.z]
		)
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
