extends RefCounted
## Ground ride + deck seam + fly-out / spine / acid matrices.


func run() -> bool:
	return (
		_ride_halfpipe()
		and _fly_out_open_vs_backed()
		and _hang_x_lock_until_fly_out()
		and _fly_out_seeds_ballistic_outward_x()
		and _hang_land_into_bowl()
		and _hang_apex_faces_into_ramp()
		and _spine_plan()
		and _acid_plan()
		and _deterministic_replay()
		and _layered_spawn_respects_story()
		and _supports_sorted_high_to_low()
		and _pipe_along_wish_and_lip_exit()
		and _ollie_faces_direction()
		and _ollie_jump_charge_scales_impulse()
		and _ollie_jump_caps_at_full_charge()
		and _ollie_jump_airborne_adds_impulse()
		and _ollie_single_charge_replenishes_on_ground()
		and _ollie_on_pipe_pops_world_up_not_along_tangent()
		and _ollie_on_pipe_lip_enters_hang()
		and _ollie_short_deck_return_no_tunnel()
		and _ollie_pipe_low_vx_descending_remounts()
		and _ollie_climbing_ramp_stays_above_solid()
		and _coast_with_zero_friction()
		and _air_no_x_friction()
		and _wall_extension_climbs()
		and _layered_deck_back_air_outs_at_upper_lip()
		and _upper_deck_flyout_hold_right_decks_out()
		and _upper_deck_2_no_stick_air_out()
		and _upper_deck_2_hold_right_keeps_rise()
		and _upper_deck_2_hang_return_past_deck_rear()
		and _upper_deck_2_apex_no_deck_snap()
		and _upper_deck_2_wall_bottom_no_deck_steal()
		and _void_floor_catches_fall()
		and _hang_flat_land_clears_lock()
		and _world_border_contains()
		and _edge_fly_out_wall_slide()
		and _edge_pipe_coping_not_in_wall()
		and _pipe_body_no_clip()
		and _embedded_pipe_no_phase_through()
		and _embedded_pipe_mounts_not_sticks()
		and _spine_deck_solid_from_floor()
		and _land_snaps_out_of_pipe_solid()
		and _no_auto_opposite_pipe_snap()
		and _layered_inbound_right_pipe_lands()
		and _layered_hole_not_invisible_wall()
		and _deck_hash_no_pin_from_floor()
		and _l0_lava_gap_no_phantom_wall_climb()
		and _lava_grounded_contact_kills()
		and _respawn_at_prior_floor_or_deck()
		and _hang_persists_off_edge_z_span()
		and _deck_ride_off_falls_acid_mounts()
		and _layered_deck_back_ride_off_stays_free()
		and _map_edge_deck_no_void_exit()
		and _layered_outer_coping_seam_stays_anchored()
		and _layered_hang_remounts_wall_height()
		and _layered_l1_coping_returns_source()
		and _wall_z_exit_consumes_motion()
		and _cross_story_spine_is_action_only()
		and _ramp_peak_free_air_launch()
		and _ramp_deck_seam_and_launch()
		and _feature_walls_block_endcaps_and_sides()
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


## Fly-out must launch with outward X from climb/air speed, and free-air X must
## stay ballistic after release (not snap to 0 like depth).
func _fly_out_seeds_ballistic_outward_x() -> bool:
	# --- Pipe hang fly-out ---
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("fly-out ballistic: setup open")
		return false
	var left := _left_pipe(sim.model)
	_place_at_coping(sim, left, 400.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("fly-out ballistic: expected hang")
		return false
	var climb_vh := sim.state.velocity.z
	if climb_vh < 100.0:
		push_error("fly-out ballistic: hang missing climb height vel %.1f" % climb_vh)
		return false
	sim.set_input(Vector2(-1, 0), false, false)
	sim.tick()
	if sim.state.is_hanging() or not sim.state.is_airborne():
		push_error("fly-out ballistic: unlock failed reject=%s" % sim.state.last_reject)
		return false
	# Seed is outward and at least climb/air speed (planner floor 120).
	var seeded := sim.state.velocity.x
	if seeded >= -1.0:
		push_error("fly-out ballistic: missing outward -X seed, got %s" % sim.state.velocity)
		return false
	if absf(seeded) + 1.0 < minf(absf(climb_vh), 120.0):
		push_error(
			"fly-out ballistic: seed |vx|=%.1f too small vs climb vh=%.1f"
			% [absf(seeded), climb_vh]
		)
		return false
	# Release stick: X must conserve (ballistic), not snap to 0.
	sim.set_input(Vector2.ZERO, false, false)
	for _i in range(8):
		sim.tick()
		if not sim.state.is_airborne():
			push_error("fly-out ballistic: landed during coast")
			return false
		if absf(sim.state.velocity.x - seeded) > 1.0:
			push_error(
				"fly-out ballistic: release must conserve vx %.1f → %.1f"
				% [seeded, sim.state.velocity.x]
			)
			return false
	# --- Cross-story wall climb → fly-out ---
	var wall_sim := _upper_deck_2_setup()
	if wall_sim == null:
		return false
	var wall := _upper_deck_2_right_wall(wall_sim)
	if wall == null:
		push_error("fly-out ballistic: missing wall")
		return false
	var top_h := float(wall.sample_at_z(wall_sim.state.position.y).top_height)
	var unlocked_vx := 0.0
	var unlocked := false
	for _j in range(160):
		wall_sim.set_input(Vector2(1, 0), false, false)
		wall_sim.tick()
		if wall_sim.state.is_airborne() and not wall_sim.state.is_hanging() \
				and wall_sim.state.velocity.x > 1.0:
			if wall_sim.state.position.z < top_h - SimTolerances.CONTACT_EPS:
				push_error("fly-out ballistic: wall unlock below lip")
				return false
			unlocked = true
			unlocked_vx = wall_sim.state.velocity.x
			break
	if not unlocked:
		push_error("fly-out ballistic: wall climb never unlocked with +X")
		return false
	if unlocked_vx < 100.0:
		push_error("fly-out ballistic: wall fly-out vx too small %.1f" % unlocked_vx)
		return false
	wall_sim.set_input(Vector2.ZERO, false, false)
	for _k in range(8):
		wall_sim.tick()
		if not wall_sim.state.is_airborne():
			# May land the deck while coasting — still must not have killed vx first.
			break
		if absf(wall_sim.state.velocity.x - unlocked_vx) > 1.0:
			push_error(
				"fly-out ballistic: wall release must conserve vx %.1f → %.1f"
				% [unlocked_vx, wall_sim.state.velocity.x]
			)
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


func _hang_apex_faces_into_ramp() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("apex face: setup")
		return false
	var left := _left_pipe(sim.model)
	_place_at_coping(sim, left, 350.0)
	sim.state.set_facing_side("l") ## outward when climbing a left pipe
	SimTolerances.APEX_FACING_DELAY = 0.0
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("apex face: expected hang")
		return false
	var flipped := false
	for _i in range(120):
		sim.tick()
		if sim.state.facing == "r" and absf(absf(sim.state.facing_yaw) - PI) < 0.01:
			flipped = true
			break
		if not sim.state.is_hanging() and not sim.state.is_airborne():
			break
	if not flipped:
		push_error("apex face: left hang never faced into ramp (r)")
		return false
	if sim.state.visual_facing != "l":
		push_error("apex face: presentation facing changed before hang handoff")
		return false
	sim.state.clear_hang()
	if sim.state.visual_facing != "r" or absf(sim.state.facing_yaw) > 0.01:
		push_error("apex face: hang exit did not hand off settled facing")
		return false
	# Non-zero duration: centered local-Y turn must pass through mid-rotation.
	var delayed := PlayerSim.new()
	if not delayed.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("apex face delay: setup")
		return false
	_place_at_coping(delayed, _left_pipe(delayed.model), 500.0)
	delayed.state.set_facing_side("l")
	SimTolerances.APEX_FACING_DELAY = 0.12
	delayed.set_input(Vector2.ZERO, false, false)
	delayed.tick()
	var saw_mid_turn := false
	var saw_apex := false
	for _j in range(180):
		delayed.tick()
		if delayed.state.velocity.z <= 0.0:
			saw_apex = true
		if saw_apex and delayed.state.hang_apex_timer >= 0.0 \
				and not delayed.state.hang_apex_facing_done:
			var yaw: float = delayed.state.facing_yaw
			# Left pipe takes the negative local-Y path; midpoint is away from 0 and ±π.
			if absf(yaw) > 0.4 and absf(absf(yaw) - PI) > 0.4:
				saw_mid_turn = true
			if delayed.state.hang_apex_to_yaw * yaw < 0.0 and absf(yaw) > 0.2:
				push_error("apex face turn: rotating away from bowl (yaw=%.2f to=%.2f)" % [
					yaw, delayed.state.hang_apex_to_yaw
				])
				SimTolerances.APEX_FACING_DELAY = 0.05
				return false
			if delayed.state.facing != "l":
				push_error("apex face turn: discrete facing flipped before turn finished")
				SimTolerances.APEX_FACING_DELAY = 0.05
				return false
		if delayed.state.hang_apex_facing_done and delayed.state.facing == "r":
			if not saw_mid_turn:
				push_error("apex face turn: yaw never passed through mid-turn")
				SimTolerances.APEX_FACING_DELAY = 0.05
				return false
			if delayed.state.visual_facing != "l":
				push_error("apex face turn: visual reflection changed during turn")
				SimTolerances.APEX_FACING_DELAY = 0.05
				return false
			SimTolerances.APEX_FACING_DELAY = 0.05
			return _right_hang_turns_into_ramp()
		if not delayed.state.is_hanging() and delayed.state.is_grounded():
			break
	SimTolerances.APEX_FACING_DELAY = 0.05
	push_error("apex face delay: never completed into-ramp turn")
	return false


func _right_hang_turns_into_ramp() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("right apex face: setup")
		return false
	var right: PipeSurface = null
	for id in sim.model.all_pipe_ids():
		var candidate: PipeSurface = sim.model.pipes[id]
		if candidate.side == SimKinds.PipeSide.RIGHT:
			right = candidate
			break
	if right == null:
		push_error("right apex face: missing pipe")
		return false
	_place_at_coping(sim, right, 500.0)
	sim.state.set_facing_side("r")
	SimTolerances.APEX_FACING_DELAY = 0.12
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	for _i in range(180):
		sim.tick()
		if sim.state.hang_apex_timer >= 0.0:
			if sim.state.hang_apex_to_yaw <= 0.0:
				push_error("right apex face: target must rotate +Y into bowl")
				SimTolerances.APEX_FACING_DELAY = 0.05
				return false
			if absf(sim.state.facing_yaw) > 0.2:
				var ok := sim.state.facing_yaw > 0.0
				if not ok:
					push_error("right apex face: rotating away from bowl")
				SimTolerances.APEX_FACING_DELAY = 0.05
				return ok
		if not sim.state.is_hanging():
			break
	SimTolerances.APEX_FACING_DELAY = 0.05
	push_error("right apex face: turn path was not exercised")
	return false


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


func _ollie_jump_charge_scales_impulse() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie jump scale")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 500.0
	sim.ollie_height = 40.0
	sim.state.tangent_velocity = Vector2.ZERO
	var h0 := sim.state.position.z
	# Hold for half the charge window (15 frames @ 60Hz ≈ 250ms).
	for _i in range(15):
		sim.set_input(Vector2.ZERO, false, false, true, false)
		sim.tick()
	if absf(sim.ollie_charge - 0.5) > 0.05:
		push_error("expected ~50%% charge, got %s" % sim.ollie_charge)
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("partial ollie should leave ground")
		return false
	# 50% of 40u → peak ~20u; after one tick should still be rising above pad.
	if sim.state.velocity.z <= 0.0:
		push_error("partial ollie should still be rising, vh=%s" % sim.state.velocity.z)
		return false
	if sim.state.position.z <= h0 + 0.5:
		push_error(
			"partial ollie should lift off pad (h0=%s h=%s)" % [h0, sim.state.position.z]
		)
		return false
	return true


func _ollie_jump_caps_at_full_charge() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie jump cap")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 200.0
	sim.ollie_height = 40.0
	sim.state.tangent_velocity = Vector2.ZERO
	var h0 := sim.state.position.z
	# Hold well past full charge.
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false, true, false)
		sim.tick()
	if sim.ollie_charge < 0.999:
		push_error("overhold should stay capped at 100%%, got %s" % sim.ollie_charge)
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("full ollie should leave ground")
		return false
	var expected_v := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - expected_v) > 5.0:
		push_error(
			"full ollie vh expected ~%s got %s" % [expected_v, sim.state.velocity.z]
		)
		return false
	# Climb toward peak over a few ticks.
	var peak := h0
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false, false, false)
		sim.tick()
		peak = maxf(peak, sim.state.position.z)
		if sim.state.velocity.z <= 0.0 and sim.state.position.z < peak - 0.1:
			break
	if peak < h0 + 30.0:
		push_error("full ollie peak too low: h0=%s peak=%s" % [h0, peak])
		return false
	return true


func _ollie_jump_airborne_adds_impulse() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie air jump")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height = 40.0
	sim.state.tangent_velocity = Vector2.ZERO
	# Charge must start on ground.
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	if sim.ollie_charge < 0.999:
		push_error("0ms charge should be instantly full while grounded")
		return false
	# Carry the hold meter into free air (still held) without rebuilding there.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.velocity = Vector3(0.0, 0.0, 0.0)
	sim.state.clear_hang()
	sim.state.position.z = 80.0
	sim.ollie_available = true
	var before := sim.state.velocity.z
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var add := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0)
	var expected := before + add + SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - expected) > 5.0:
		push_error(
			"air ollie vh expected ~%s got %s (before=%s)"
			% [expected, sim.state.velocity.z, before]
		)
		return false
	if sim.ollie_available:
		push_error("air ollie should spend the single charge")
		return false
	# Cannot start a new charge meter while airborne.
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	if sim.ollie_charge > 0.001:
		push_error("must not start ollie charge while airborne")
		return false
	return true


func _ollie_single_charge_replenishes_on_ground() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie single charge")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height = 40.0
	sim.state.tangent_velocity = Vector2.ZERO
	var pad_id := sim.state.surface_id
	var pad_h := sim.state.position.z
	var pad_x := sim.state.position.x
	var pad_z := sim.state.position.y
	if not sim.ollie_available:
		push_error("spawn should have an ollie charge")
		return false
	# First ollie from ground.
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("first ollie should leave ground")
		return false
	if sim.ollie_available:
		push_error("first ollie should spend the charge")
		return false
	var vh_after_first := sim.state.velocity.z
	# Second release mid-air must not rebuild or kick again.
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	if sim.ollie_charge > 0.001:
		push_error("spent charge must not rebuild the hold meter")
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var min_second_kick := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) * 0.5
	if sim.state.velocity.z > vh_after_first + min_second_kick:
		push_error(
			"second air ollie should not add height kick (vh0=%s vh=%s)"
			% [vh_after_first, sim.state.velocity.z]
		)
		return false
	# Touch ground again → charge restored.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pad_id
	sim.state.position = Vector3(pad_x, pad_z, pad_h)
	sim.state.velocity = Vector3.ZERO
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.clear_hang()
	sim.state.clear_air_peak()
	sim.set_input(Vector2.ZERO, false, false, false, false)
	sim.tick()
	if not sim.state.is_grounded():
		push_error("forced ground contact should stay grounded")
		return false
	if not sim.ollie_available:
		push_error("ground contact should replenish ollie charge")
		return false
	return true


func _ollie_on_pipe_pops_world_up_not_along_tangent() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie pipe pop")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height = 40.0
	var pipe := _left_pipe(sim.model)
	if pipe == null:
		push_error("missing left pipe")
		return false
	# Mid-transition with strong along-toward-coping — old launch converted this
	# into a free-air slope exit (vh ≈ along*t.z + ollie).
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.45
	var th := u * PI * 0.5
	var along := 500.0
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(along, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.ollie_available = true
	var proj := pipe.project(sim.state.position.x, sim.state.position.y, sim.state.position.z)
	if not bool(proj.get("ok", false)):
		push_error("pipe project failed")
		return false
	var t: Vector3 = proj.tangent_along
	var old_launch_vh := t.z * along + sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0)
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("pipe ollie should leave the surface")
		return false
	var expected_vh := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - expected_vh) > 8.0:
		push_error(
			"pipe ollie should pop world-up (~%s), not along-tangent launch (~%s); got %s"
			% [expected_vh, old_launch_vh + SimTolerances.GRAVITY * SimTolerances.FIXED_DT, sim.state.velocity.z]
		)
		return false
	# Climbing (peak-ward) X is dropped — it drills under the pipe body.
	# Lip-ward carry still keeps t.x*along.
	if absf(sim.state.velocity.x) > 20.0:
		push_error(
			"climbing pipe ollie should drop peak-ward X, got vx=%s (t.x*along=%s)"
			% [sim.state.velocity.x, t.x * along]
		)
		return false
	return true


func _ollie_on_pipe_lip_enters_hang() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie lip hang")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height = 40.0
	sim.ollie_lip_frac = 0.15
	var pipe := _left_pipe(sim.model)
	if pipe == null:
		push_error("missing left pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.ollie_available = true
	# Instant full meter without an extra grounded physics tick (along would decay).
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("lip ollie should leave the pipe")
		return false
	if not sim.state.is_hanging():
		push_error("lip ollie should X-lock into hang air")
		return false
	if absf(sim.state.velocity.x) > 0.01:
		push_error("hang ollie must lock vx, got %s" % sim.state.velocity.x)
		return false
	var expected_vh := 200.0 + sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - expected_vh) > 10.0:
		push_error(
			"lip hang vh expected ~%s (along+ollie) got %s" % [expected_vh, sim.state.velocity.z]
		)
		return false
	var lock_x := pipe.coping_x_at(z)
	if absf(sim.state.position.x - lock_x) > 1.0:
		push_error(
			"lip hang should sit on coping x=%s got %s" % [lock_x, sim.state.position.x]
		)
		return false
	return true


func _ollie_short_deck_return_no_tunnel() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_deck.ssk"):
		push_error("setup short deck ollie")
		return false
	# Stand on the center deck pad.
	var deck_id := ""
	for sid in sim.model.patches.keys():
		var patch: SupportPatch = sim.model.patches[sid]
		if patch.kind == SimKinds.SurfaceKind.DECK:
			deck_id = sid
			sim.state.mode = SimState.Mode.GROUNDED
			sim.state.surface_id = sid
			sim.state.position = Vector3(
				(patch.x_min + patch.x_max) * 0.5,
				(patch.z_min + patch.z_max) * 0.5,
				patch.height
			)
			sim.state.tangent_velocity = Vector2.ZERO
			break
	if deck_id.is_empty():
		push_error("no deck in sim_ramp_deck")
		return false
	var deck_h := sim.state.position.z
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	# Peak ~10u — below DECK_LAND_MIN_ABOVE (20) but a real same-pad return.
	sim.ollie_height = 10.0
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("short deck ollie should leave the pad")
		return false
	if sim.state.air_launch_surface_id != deck_id:
		push_error("air bout should remember launch deck")
		return false
	# Fall back onto the same deck.
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false, false, false)
		sim.tick()
		if sim.state.is_grounded():
			break
	if not sim.state.is_grounded():
		push_error("short deck ollie should remount, still air h=%s" % sim.state.position.z)
		return false
	if sim.state.surface_id != deck_id:
		push_error(
			"short deck ollie tunneled to %s (want %s) h=%s"
			% [sim.state.surface_id, deck_id, sim.state.position.z]
		)
		return false
	if absf(sim.state.position.z - deck_h) > 1.0:
		push_error("remount height drifted: %s vs %s" % [sim.state.position.z, deck_h])
		return false
	return true


func _ollie_pipe_low_vx_descending_remounts() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup low-vx pipe remount")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height = 30.0
	sim.ollie_lip_frac = 0.0 ## force free-air pop, not hang
	var pipe := _left_pipe(sim.model)
	if pipe == null:
		push_error("missing left pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.35
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(20.0, 0.0) ## tiny along → tiny free-air vx
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("pipe ollie should leave")
		return false
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false, false, false)
		sim.tick()
		if sim.state.is_grounded():
			break
	if not sim.state.is_grounded():
		push_error(
			"low-vx descending pipe remount failed; air h=%s vx=%s"
			% [sim.state.position.z, sim.state.velocity.x]
		)
		return false
	if sim.state.surface_id != pipe.id:
		push_error("expected remount on %s got %s" % [pipe.id, sim.state.surface_id])
		return false
	return true


func _ollie_climbing_ramp_stays_above_solid() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("setup climbing ramp ollie")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	# Short pop + max climb — old launch drilled under the rising incline.
	sim.ollie_height = 40.0
	sim.ollie_lip_frac = 0.0
	var ramp: RampSurface = null
	for rid in sim.model.ramps.keys():
		ramp = sim.model.ramps[rid]
		break
	if ramp == null:
		push_error("missing ramp")
		return false
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.45
	var th := u * PI * 0.5
	var along := 880.0
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(along, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	var proj0 := ramp.project(sim.state.position.x, sim.state.position.y, sim.state.position.z)
	if not bool(proj0.get("ok", false)):
		push_error("ramp project failed")
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("climbing ramp ollie should leave")
		return false
	# Peak-ward carry must be dropped; leftover into-normal is rejected.
	if absf(sim.state.velocity.x) > 30.0:
		push_error("climbing ramp ollie should not keep peak-ward X, vx=%s" % sim.state.velocity.x)
		return false
	# Stay free of the ramp body for the whole bout (or remount cleanly).
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false, false, false)
		sim.tick()
		var hit := sim.query.blocker_at(sim.state.position)
		if not hit.is_empty() and str(hit.get("kind", "")) == "ramp":
			push_error(
				"buried in ramp solid at tick %s pos=%s hit=%s"
				% [sim.state.tick, sim.state.position, hit]
			)
			return false
		if sim.state.is_grounded():
			break
	if sim.state.is_grounded() and sim.model.ramps.has(sim.state.surface_id) \
			and sim.state.surface_id != ramp.id:
		push_error("landed wrong ramp %s" % sim.state.surface_id)
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
	# Aligned stick under current speed must not bleed ballistic vx (felt like air friction).
	sim.state.velocity.x = 550.0
	vx0 = sim.state.velocity.x
	for _i in range(12):
		sim.set_input(Vector2(1, 0), false, false, false)
		sim.tick()
		if not sim.state.is_airborne():
			push_error("air friction: landed while holding aligned stick")
			return false
		if sim.state.velocity.x + 1.0 < vx0:
			push_error(
				"aligned stick must not slow ballistic air X, %s → %s"
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
	var span := cope.span_at_z(z)
	if span == null or not sim.model.walls.has(span.wall_id):
		push_error("wall extension has no explicit wall span")
		return false
	var wall: WallSurface = sim.model.walls[span.wall_id]
	var h_eff := float(wall.sample_at_z(z).top_height)
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
		if sim.model.walls.has(sim.state.surface_id):
			saw_wall = true
			heights.append(sim.state.position.z)
			# Must not teleport to pad top in one step from geometric.
			if sim.state.position.z >= h_eff - 1.0 and heights.size() < 3:
				push_error("teleported to pad top instead of climbing wall")
				return false
		if sim.model.patches.has(sim.state.surface_id):
			# Mounted floor after climb.
			if not saw_wall:
				push_error("mounted pad without explicit wall ownership")
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


func _layered_deck_back_air_outs_at_upper_lip() -> bool:
	# L0 right under L1: climb the explicit wall, then retain its open top as
	# an anchored air-out. Proximity to the deck must never auto deck-out.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("setup layered air-out")
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
	var span := cope.span_at_z(z)
	if span == null or not sim.model.walls.has(span.wall_id):
		push_error("layered wall span missing at test Z")
		return false
	var wall: WallSurface = sim.model.walls[span.wall_id]
	var h_eff := float(wall.sample_at_z(z).top_height)
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
	sim.state.surface_id = wall.id
	sim.state.u = 0.9
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = wall.position_at(z, sim.state.u)
	var hung := false
	for _i in range(30):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_airborne():
			if not sim.state.is_hanging():
				push_error("layered wall top auto decked-out instead of air-out")
				return false
			hung = true
			break
	if not hung:
		push_error("layered wall top never entered air-out")
		return false
	if sim.state.position.z < h_eff - 40.0:
		push_error("air-out height still near L0 (%.1f)" % sim.state.position.z)
		return false
	for _i in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id:
				push_error("layered air-out auto-landed on %s" % sim.state.surface_id)
				return false
			return true
	push_error("layered air-out did not return to its source wall")
	return false


func _upper_deck_flyout_hold_right_decks_out() -> bool:
	# Spawn on L0, hold +X: climb the right pipe / wall and deck-out onto the
	# L1 rear deck past the connected upper lip. Must not remain air-out hang.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/upper_deck_flyout_test.ssk"):
		push_error("upper deck flyout: setup")
		return false
	var wall: WallSurface = null
	for id in sim.model.walls.keys():
		wall = sim.model.walls[id]
		break
	if wall == null:
		push_error("upper deck flyout: expected cross-story wall")
		return false
	var top_h := float(wall.sample_at_z(sim.state.position.y).top_height)
	var decked := false
	for _i in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_airborne() and not sim.state.is_hanging() and sim.state.velocity.x > 1.0:
			if sim.state.position.z < top_h - SimTolerances.CONTACT_EPS:
				push_error(
					"upper deck flyout: unlocked below connected upper lip h=%.1f top=%.1f"
					% [sim.state.position.z, top_h]
				)
				return false
			decked = true
			break
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var patch: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(patch.kind) == SimKinds.SurfaceKind.DECK:
				if sim.state.position.z < top_h - SimTolerances.CONTACT_EPS:
					push_error("upper deck flyout: landed deck below upper lip")
					return false
				decked = true
				break
	if not decked:
		push_error(
			"upper deck flyout: hold-right never decked out mode=%s hang=%s surf=%s rej=%s h=%.1f"
			% [
				sim.state.mode,
				sim.state.is_hanging(),
				sim.state.surface_id,
				sim.state.last_reject,
				sim.state.position.z,
			]
		)
		return false
	return true


func _upper_deck_2_setup() -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/upper_deck_flyout_test_2.ssk"):
		push_error("upper_deck_2: setup")
		return null
	return sim


func _upper_deck_2_right_wall(sim: PlayerSim) -> WallSurface:
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT and str(id).contains("L0"):
			pipe = p
			break
	if pipe == null:
		return null
	var cope: CopingEdge = sim.model.copings[pipe.coping_id]
	var span: CopingSpan = cope.span_at_z(sim.state.position.y)
	if span == null or span.wall_id.is_empty():
		return null
	return sim.model.walls.get(span.wall_id)


func _upper_deck_2_is_deck(sim: PlayerSim) -> bool:
	if not sim.state.is_grounded() or not sim.model.patches.has(sim.state.surface_id):
		return false
	var patch: SupportPatch = sim.model.patches[sim.state.surface_id]
	return int(patch.kind) == SimKinds.SurfaceKind.DECK


## No stick at the upper lip: must air-out hang, never auto-ground on the L1 deck.
func _upper_deck_2_no_stick_air_out() -> bool:
	var sim := _upper_deck_2_setup()
	if sim == null:
		return false
	var wall := _upper_deck_2_right_wall(sim)
	if wall == null:
		push_error("upper_deck_2 air-out: missing wall")
		return false
	var top_h := float(wall.sample_at_z(sim.state.position.y).top_height)
	# Climb with +X until on/near the wall, then release stick before the lip.
	var released := false
	var hung := false
	for _i in range(160):
		if not released and sim.state.is_grounded() and sim.model.walls.has(sim.state.surface_id):
			var u := sim.state.u
			if u >= 0.85:
				released = true
		sim.set_input(Vector2.ZERO if released else Vector2(1, 0), false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim):
			push_error("upper_deck_2 air-out: auto-grounded on deck without stick")
			return false
		if sim.state.is_airborne() and not sim.state.is_hanging() and absf(sim.state.velocity.x) > 1.0:
			push_error("upper_deck_2 air-out: unlocked free air without outward stick")
			return false
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("upper_deck_2 air-out: never entered hang")
		return false
	if sim.state.position.z < top_h - SimTolerances.CONTACT_EPS:
		push_error("upper_deck_2 air-out: hang below upper lip")
		return false
	# Descend with zero stick; must remount source wall/pipe, never the deck.
	for _j in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim):
			push_error("upper_deck_2 air-out: landed deck on return")
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id and sim.state.surface_id != wall.source_pipe_id:
				push_error("upper_deck_2 air-out: remounted %s" % sim.state.surface_id)
				return false
			return true
	push_error("upper_deck_2 air-out: never remounted source")
	return false


## Hold +X decks out above the upper lip and keeps rising height (no early vz kill).
func _upper_deck_2_hold_right_keeps_rise() -> bool:
	var sim := _upper_deck_2_setup()
	if sim == null:
		return false
	var wall := _upper_deck_2_right_wall(sim)
	if wall == null:
		push_error("upper_deck_2 rise: missing wall")
		return false
	var top_h := float(wall.sample_at_z(sim.state.position.y).top_height)
	var unlocked := false
	var saw_rising_free := false
	for _i in range(160):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim) and sim.state.position.z <= top_h + 0.5:
			# Early deck snap while still near the lip — rising height was killed.
			if not unlocked:
				push_error("upper_deck_2 rise: grounded deck before free unlock")
				return false
		if sim.state.is_airborne() and not sim.state.is_hanging() and sim.state.velocity.x > 1.0:
			if sim.state.position.z < top_h - SimTolerances.CONTACT_EPS:
				push_error("upper_deck_2 rise: unlocked below upper lip")
				return false
			unlocked = true
			if sim.state.velocity.z > 1.0:
				saw_rising_free = true
			# While still rising in free air, must not snap onto the deck.
			if sim.state.velocity.z > 1.0 and _upper_deck_2_is_deck(sim):
				push_error("upper_deck_2 rise: deck snap while rising")
				return false
			# Keep watching a few ticks of rising free air.
			if saw_rising_free and sim.state.velocity.z <= 0.0:
				break
	if not unlocked:
		push_error("upper_deck_2 rise: never unlocked free air with +X")
		return false
	if not saw_rising_free:
		push_error("upper_deck_2 rise: free air never kept rising height velocity")
		return false
	# Eventually may land the deck only after descending.
	for _j in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.velocity.z > 1.0 and _upper_deck_2_is_deck(sim):
			push_error("upper_deck_2 rise: deck mount while still rising")
			return false
		if _upper_deck_2_is_deck(sim):
			return true
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			# Floor past the deck is also fine after a successful unlock.
			return true
	return true


## Hang above the lip, zero stick: return past the deck rear without stalling.
func _upper_deck_2_hang_return_past_deck_rear() -> bool:
	var sim := _upper_deck_2_setup()
	if sim == null:
		return false
	var wall := _upper_deck_2_right_wall(sim)
	if wall == null:
		push_error("upper_deck_2 return: missing wall")
		return false
	var z := sim.state.position.y
	var top_h := float(wall.sample_at_z(z).top_height)
	var edge := sim.query.edge_at(wall.id, z, "top")
	if edge == null:
		push_error("upper_deck_2 return: missing top edge")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(edge.id)
	sim.state.position = Vector3(float(wall.sample_at_z(z).x), z, top_h + 60.0)
	sim.state.velocity = Vector3(0.0, 0.0, 200.0)
	sim.state.maneuver = null
	var stalled := 0
	for _i in range(200):
		var prev_vz := sim.state.velocity.z
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim):
			push_error("upper_deck_2 return: deck stole hang")
			return false
		if sim.state.is_hanging() and absf(sim.state.position.z - top_h) <= 2.0 \
				and absf(sim.state.velocity.z) < 1.0 and prev_vz < -10.0:
			stalled += 1
			if stalled >= 3:
				push_error("upper_deck_2 return: vz stall at deck height")
				return false
		else:
			stalled = 0
		if sim.state.is_grounded():
			var ok := sim.state.surface_id == wall.id or sim.state.surface_id == wall.source_pipe_id
			if not ok:
				push_error("upper_deck_2 return: remounted %s" % sim.state.surface_id)
				return false
			return true
	push_error("upper_deck_2 return: never remounted source")
	return false


## Apex / lip skim over the L1 rear deck with leftover outward vx must not
## sticky-snap. Peak-near-pad bouts (including the old ~2-unit hover) stay free;
## a high arc that actually peaked well above the pad may still land later.
func _upper_deck_2_apex_no_deck_snap() -> bool:
	var deck: SupportPatch = null
	var mid_x := 0.0
	var mid_z := 0.0
	# Low apex / skim offsets: must never sticky-mount.
	for offset in [0.0, 1.0, 2.0, 3.0, 5.0, 10.0, SimTolerances.DECK_LAND_MIN_ABOVE]:
		var sim := _upper_deck_2_setup()
		if sim == null:
			return false
		if deck == null:
			for id in sim.model.patches.keys():
				var p: SupportPatch = sim.model.patches[id]
				if int(p.kind) == SimKinds.SurfaceKind.DECK:
					deck = p
					break
			if deck == null:
				push_error("upper_deck_2 apex: no deck")
				return false
			mid_x = (deck.x_min + deck.x_max) * 0.5
			mid_z = (deck.z_min + deck.z_max) * 0.5
		sim.state.mode = SimState.Mode.AIRBORNE
		sim.state.surface_id = ""
		sim.state.clear_hang()
		sim.state.maneuver = null
		sim.state.air_peak_height = deck.height + float(offset)
		sim.state.position = Vector3(mid_x, mid_z, deck.height + float(offset))
		sim.state.velocity = Vector3(400.0, 0.0, 0.0)
		for _i in range(20):
			sim.set_input(Vector2.ZERO, false, false)
			sim.tick()
			if _upper_deck_2_is_deck(sim):
				push_error(
					"upper_deck_2 apex: snapped at peak_offset=%.1f with vx=%.1f"
					% [float(offset), sim.state.tangent_velocity.x]
				)
				return false
	# Control: a bout that peaked well above the pad may land while descending.
	var land := _upper_deck_2_setup()
	if land == null:
		return false
	land.state.mode = SimState.Mode.AIRBORNE
	land.state.surface_id = ""
	land.state.clear_hang()
	land.state.maneuver = null
	land.state.air_peak_height = deck.height + SimTolerances.DECK_LAND_MIN_ABOVE + 40.0
	land.state.position = Vector3(mid_x, mid_z, deck.height + 8.0)
	land.state.velocity = Vector3(50.0, 0.0, -200.0)
	var mounted := false
	for _j in range(30):
		land.set_input(Vector2.ZERO, false, false)
		land.tick()
		if _upper_deck_2_is_deck(land):
			mounted = true
			break
	if not mounted:
		push_error("upper_deck_2 apex: high-peak descending bout never landed deck")
		return false
	return true


## Wall entry just above the bottom seam (inside CONTACT_EPS of deck base) must
## keep climbing / air-out — never deck-rescue through the overhanging pad.
func _upper_deck_2_wall_bottom_no_deck_steal() -> bool:
	var sim := _upper_deck_2_setup()
	if sim == null:
		return false
	var wall := _upper_deck_2_right_wall(sim)
	if wall == null:
		push_error("upper_deck_2 bottom: missing wall")
		return false
	var z := sim.state.position.y
	var samp := wall.sample_at_z(z)
	var bottom := float(samp.bottom_height)
	var top := float(samp.top_height)
	# Place in the old dead band: above deck base, within CONTACT_EPS of bottom.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall.id
	sim.state.u = wall.u_at_height(z, bottom + 0.25)
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.position = wall.position_at(z, sim.state.u)
	sim.state.clear_hang()
	sim.state.maneuver = null
	if sim.state.position.z > bottom + SimTolerances.CONTACT_EPS:
		push_error(
			"upper_deck_2 bottom: setup not in seam band h=%.2f bottom=%.2f"
			% [sim.state.position.z, bottom]
		)
		return false
	var hung := false
	for _i in range(90):
		# Hold climb input — same stick that would have triggered the old steal.
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim):
			push_error(
				"upper_deck_2 bottom: deck stole wall climb at h=%.1f"
				% sim.state.position.z
			)
			return false
		if sim.state.is_hanging():
			hung = true
			break
		if sim.state.is_grounded() and sim.state.surface_id != wall.id \
				and sim.state.surface_id != wall.source_pipe_id:
			push_error("upper_deck_2 bottom: left wall onto %s" % sim.state.surface_id)
			return false
	if not hung:
		push_error("upper_deck_2 bottom: never aired out (top=%.1f h=%.1f mode=%s surf=%s)" % [
			top, sim.state.position.z, sim.state.mode, sim.state.surface_id
		])
		return false
	# After hang, release — must not sticky-mount the rear deck on the way down.
	for _j in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if _upper_deck_2_is_deck(sim):
			push_error("upper_deck_2 bottom: deck stole hang return")
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id and sim.state.surface_id != wall.source_pipe_id:
				push_error("upper_deck_2 bottom: remounted %s" % sim.state.surface_id)
				return false
			return true
	push_error("upper_deck_2 bottom: never remounted source after hang")
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


## Hang with no remountable pipe under the lock must land the nearest flat
## (void/floor) and clear X-lock / lip lean — not fall through the park.
func _hang_flat_land_clears_lock() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("hang flat: setup")
		return false
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var edge := sim.query.edge_at(left.id, z, "coping")
	if edge == null:
		push_error("hang flat: missing open coping")
		return false
	# Hang X-locked, but depth parked where this pipe has no loft — only flats below.
	var off_z := left.z_min - 20.0
	if off_z < 1.0:
		off_z = left.z_max + 20.0
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(edge.id)
	sim.state.set_facing_side("l")
	sim.state.facing_yaw = 0.4 ## pretend mid-lean; flat land must clear it
	sim.state.position = Vector3(left.coping_x_at(z), off_z, 80.0)
	sim.state.velocity = Vector3(0.0, 0.0, -100.0)
	sim.state.maneuver = null
	var landed := false
	for _i in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded():
			landed = true
			break
	if not landed:
		push_error(
			"hang flat: never landed (mode=%s h=%.1f hang=%s)"
			% [sim.state.mode, sim.state.position.z, sim.state.hang_edge_id]
		)
		return false
	if sim.model.pipes.has(sim.state.surface_id):
		push_error("hang flat: remounted pipe %s — expected flat" % sim.state.surface_id)
		return false
	if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
		push_error("hang flat: hang/X-lock must clear on flat land")
		return false
	if absf(sim.state.facing_yaw) > 0.01:
		push_error("hang flat: lip lean yaw must reset, got %.3f" % sim.state.facing_yaw)
		return false
	if not sim.state.alive and sim.state.surface_id != "__void_floor__":
		# Lethal flat is fine; void must stay alive.
		pass
	if sim.state.surface_id == "__void_floor__" and not sim.state.alive:
		push_error("hang flat: void land must stay alive")
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
	var wall_x := sim.model.width
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("border: died at world edge")
			return false
		if sim.state.position.x > wall_x + 1.0:
			push_error("border: escaped east wall x=%.1f" % sim.state.position.x)
			return false
		if sim.state.position.x < -1.0:
			push_error("border: escaped west wall")
			return false
	# Depth (Z): walls on the park faces — cannot leave [0, depth].
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.position = Vector3(sim.model.width * 0.5, sim.model.depth - 10.0, 80.0)
	sim.state.velocity = Vector3(0.0, 400.0, 0.0)
	for _j in range(90):
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("border: died at far Z edge")
			return false
		if sim.state.position.y > sim.model.depth + 0.5:
			push_error("border: escaped far Z wall z=%.1f" % sim.state.position.y)
			return false
		if sim.state.position.y < -0.5:
			push_error("border: escaped near Z wall")
			return false
	# Grounded depth stick must also stay inside — never fall off far/near floor edge.
	sim.respawn()
	sim.state.tangent_velocity = Vector2(0.0, 500.0)
	for _k in range(300):
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("border: died grounded Z")
			return false
		if sim.state.position.y >= sim.model.depth - 0.001 \
				or sim.state.position.y <= 0.001:
			push_error("border: grounded on Z face z=%.1f" % sim.state.position.y)
			return false
		if sim.state.surface_id == "__void_floor__":
			push_error("border: walked off map onto void floor z=%.1f" % sim.state.position.y)
			return false
	return true


## A fly-out into the map-edge wall must land on the bordering deck. Pressing
## into that wall must retain depth control and must not truncate vertical fall.
func _edge_fly_out_wall_slide() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("edge wall slide: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get("pipe_3_L0_S1")
	if pipe == null:
		push_error("edge wall slide: missing outer L0 pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 1.0
	sim.state.v = 0.5
	sim.state.position = Vector3(
		pipe.coping_x_at(z), z, pipe.height_at_theta(z, PI * 0.5)
	)
	sim.state.tangent_velocity = Vector2(800.0, 0.0)
	sim.state.clear_hang()
	sim.set_input(Vector2(1, 0), false, false)
	sim.tick()
	var saw_air_wall := false
	for _i in range(600):
		sim.set_input(Vector2(1, 1), false, false)
		sim.tick()
		if not sim.state.alive or sim.state.surface_id == "__void_floor__":
			push_error("edge wall slide: fell outside bordering deck")
			return false
		if not sim.model.in_world_xz(sim.state.position.x, sim.state.position.y):
			push_error("edge wall slide: escaped world bounds at %s" % sim.state.position)
			return false
		if sim.state.is_airborne() and sim.state.position.x >= sim.model.width - 0.1:
			saw_air_wall = true
			if absf(sim.state.velocity.y) < 199.0:
				push_error(
					"edge wall slide: into-wall input dragged depth speed to %.1f"
					% sim.state.velocity.y
				)
				return false
	if not saw_air_wall:
		push_error("edge wall slide: never contacted east wall while airborne")
		return false
	var landed: SupportPatch = sim.model.patches.get(sim.state.surface_id)
	if landed == null or int(landed.kind) != SimKinds.SurfaceKind.DECK:
		push_error("edge wall slide: expected bordering deck, got %s" % sim.state.surface_id)
		return false
	var pressed := PlayerSim.new()
	var free := PlayerSim.new()
	if not pressed.setup_from_path("res://levels/layered_demo.ssk") \
			or not free.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("edge wall slide: fall comparison setup")
		return false
	var fall_start := Vector3(pressed.model.width - 0.05, pressed.model.depth * 0.5, 1000.0)
	pressed.state.mode = SimState.Mode.AIRBORNE
	pressed.state.surface_id = ""
	pressed.state.position = fall_start
	pressed.state.velocity = Vector3.ZERO
	pressed.state.clear_hang()
	free.state.mode = SimState.Mode.AIRBORNE
	free.state.surface_id = ""
	free.state.position = fall_start
	free.state.velocity = Vector3.ZERO
	free.state.clear_hang()
	for _i in range(30):
		pressed.set_input(Vector2(1, 0), false, false)
		free.set_input(Vector2.ZERO, false, false)
		pressed.tick()
		free.tick()
		if absf(pressed.state.position.z - free.state.position.z) > 0.1:
			push_error(
				"edge wall slide: into-wall input dragged fall %.2f vs %.2f"
				% [pressed.state.position.z, free.state.position.z]
			)
			return false
	return true


func _edge_pipe_coping_not_in_wall() -> bool:
	# Plaza-style edge ))) must hang at coping without immediately hitting bounds.
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
		# Must never land on the void floor while inside the deck footprint.
		if sim.state.surface_id == "__void_floor__" \
				and deck.contains_xz(sim.state.position.x, sim.state.position.y):
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
	# Start above the pipe and drop into the solid volume with travel matching side.
	# Same-facing land: left pipe wants −X travel. Hold outward so vx stays
	# present for the mount (ballistic seed alone is fine too).
	sim.state.position = Vector3(mid_x, z, mid_h + 80.0)
	sim.state.velocity = Vector3(left.outward_sign() * 200.0, 0.0, -400.0)
	var land_stick := Vector2(left.outward_sign(), 0.0)
	var snapped := false
	for _i in range(90):
		sim.set_input(land_stick, false, false)
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


func _no_auto_opposite_pipe_snap() -> bool:
	# Hanging on one pipe must not auto-mount the opposite (spine needs transfer).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_spine.ssk"):
		push_error("auto: setup")
		return false
	var left: PipeSurface = null
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.LEFT and left == null:
			left = p
		elif p.side == SimKinds.PipeSide.RIGHT and right == null:
			right = p
	if left == null or right == null:
		push_error("auto: need both pipes")
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var lx := left.x_at_theta(z, PI * 0.4)
	var lh := left.height_at_theta(z, PI * 0.4)
	var hang_edge := sim.query.edge_at(right.id, z, "coping")
	if hang_edge == null:
		push_error("auto: missing right air-out edge")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.hang_edge_id = hang_edge.id
	sim.state.maneuver = null
	sim.state.facing = "r"
	# Still hanging on the right; drift into the left pipe body without transfer.
	sim.state.position = Vector3(lx - 10.0, z, lh + 20.0)
	sim.state.velocity = Vector3(200.0, 0.0, -120.0)
	for _i in range(45):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.has_maneuver():
			push_error("auto: maneuver started without transfer button")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			push_error("auto: snapped onto opposite (left) pipe while hanging on right")
			return false
	return true


func _layered_inbound_right_pipe_lands() -> bool:
	# layered_demo L1 right: approach from outside (−X + descending) must mount,
	# not freeze airborne with zero velocity against the coping / wall-extension.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("inbound: setup")
		return false
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		var mid_z := (p.z_min + p.z_max) * 0.5
		var samp := p.sample_at_z(mid_z)
		if float(samp.get("base_height", 0.0)) < 100.0:
			continue
		right = p
		break
	if right == null:
		push_error("inbound: no L1 right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var cx := right.coping_x_at(z)
	var lip_h := right.height_at_theta(z, PI * 0.5)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.facing = "l"
	sim.state.position = Vector3(cx + 40.0, z, lip_h + 40.0)
	sim.state.velocity = Vector3(-220.0, 0.0, -280.0)
	var grounded := false
	for _i in range(90):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("inbound: died")
			return false
		if sim.state.is_grounded():
			grounded = true
			break
		if (
			sim.state.is_airborne()
			and absf(sim.state.velocity.x) < 1.0
			and absf(sim.state.velocity.z) < 1.0
			and absf(sim.state.position.z - lip_h) < 30.0
		):
			push_error(
				"inbound: stuck airborne vx=%.1f vh=%.1f h=%.1f"
				% [sim.state.velocity.x, sim.state.velocity.z, sim.state.position.z]
			)
			return false
	if not grounded:
		push_error(
			"inbound: never grounded mode=%s sid=%s h=%.1f"
			% [sim.state.mode, sim.state.surface_id, sim.state.position.z]
		)
		return false
	if sim.state.surface_id != right.id:
		push_error(
			"inbound: expected L1 right pipe, got %s"
			% sim.state.surface_id
		)
		return false
	return true


func _layered_hole_not_invisible_wall() -> bool:
	# L1 `.` gap between pipe islands must be fall-through, not a Z wall —
	# including when skating near the pipe (mount then ride off the pipe end).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("hole: setup")
		return false
	var cell_h := sim.model.cell_h
	var H := sim.model.grid_h
	# Last L1 floor row before the hole (ASCII row 8), near the right pipe.
	var edge_z := (float(H - 1 - 8) + 0.5) * cell_h
	var hole_z := (float(H - 1 - 10) + 0.5) * cell_h
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		if edge_z < p.z_min - 1.0 or edge_z > p.z_max + 1.0:
			continue
		var samp := p.sample_at_z(edge_z)
		if float(samp.get("base_height", 0.0)) < 100.0:
			continue
		right = p
		break
	if right == null:
		push_error("hole: no L1 right pipe at edge")
		return false
	# Start on L1 floor beside the right pipe, drive −Z into the hole.
	var floor_id := ""
	var start_x := 0.0
	for pid in sim.model.patches.keys():
		var pad: SupportPatch = sim.model.patches[pid]
		if pad.height < 100.0:
			continue
		if edge_z < pad.z_min - 1.0 or edge_z > pad.z_max + 1.0:
			continue
		# Prefer floor whose right edge meets this pipe.
		if absf(pad.x_max - right.x_at_theta(edge_z, 0.0)) > sim.model.cell_w * 2.0 \
				and not pad.contains_xz((pad.x_min + pad.x_max) * 0.5, edge_z):
			continue
		if pad.contains_xz(pad.x_max - 5.0, edge_z):
			floor_id = pid
			start_x = pad.x_max - 10.0
			break
	if floor_id.is_empty():
		# Fallback: any L1 floor covering the edge row.
		for pid2 in sim.model.patches.keys():
			var pad2: SupportPatch = sim.model.patches[pid2]
			if pad2.height < 100.0:
				continue
			if pad2.contains_xz((pad2.x_min + pad2.x_max) * 0.5, edge_z):
				floor_id = pid2
				start_x = pad2.x_max - 10.0
				break
	if floor_id.is_empty():
		push_error("hole: no L1 floor beside pipe")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(start_x, edge_z, 141.0)
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	var left_pipe := false
	for _i in range(90):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("hole: died")
			return false
		if sim.state.is_airborne():
			left_pipe = true
			break
		# Still grounded past the hole Z ⇒ invisible wall trapped us.
		if sim.state.position.y <= hole_z + 5.0 and sim.state.is_grounded():
			# Landed on L0 under the hole — also OK.
			if sim.model.patches.has(sim.state.surface_id):
				var landed: SupportPatch = sim.model.patches[sim.state.surface_id]
				if landed.height < 50.0:
					return true
			push_error(
				"hole: grounded through hole on %s y=%.1f"
				% [sim.state.surface_id, sim.state.position.y]
			)
			return false
	if not left_pipe and sim.state.is_grounded():
		push_error(
			"hole: stuck mode=%s sid=%s y=%.1f tvz=%.1f"
			% [
				sim.state.mode,
				sim.state.surface_id,
				sim.state.position.y,
				sim.state.tangent_velocity.y,
			]
		)
		return false
	# Phantom wall-extension must not block L1 height inside the hole band.
	var mid_x := right.coping_x_at(hole_z)
	var phantom := sim.query.blocker_at(Vector3(mid_x, hole_z, 141.0))
	if str(phantom.get("kind", "")) == "wall":
		push_error("hole: phantom wall-extension in hole rows: %s" % phantom)
		return false
	return true


func _deck_hash_no_pin_from_floor() -> bool:
	# `#(((===` — contact with the `#` prism remounts onto the deck top,
	# never freezes with zero velocity against the vertical face.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("hash: setup")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) != SimKinds.SurfaceKind.DECK:
			continue
		if p.height < 200.0:
			continue ## prefer L1 deck (base 141, top 282)
		deck = p
		break
	if deck == null:
		push_error("hash: no L1 deck")
		return false
	var z := (deck.z_min + deck.z_max) * 0.5
	var mid_x := (deck.x_min + deck.x_max) * 0.5
	# Floor at deck base height (story floor).
	var floor_id := ""
	for pid in sim.model.patches.keys():
		var pad: SupportPatch = sim.model.patches[pid]
		if int(pad.kind) != SimKinds.SurfaceKind.FLOOR:
			continue
		if absf(pad.height - deck.base_height) > 1.0:
			continue
		floor_id = pid
		break
	if floor_id.is_empty():
		push_error("hash: no story floor")
		return false
	# 1) Already inside the deck volume at mid-height → remount to top.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(mid_x, z, deck.base_height + 20.0)
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	sim.set_input(Vector2(1, 0), false, false)
	sim.tick()
	if not sim.state.is_grounded() or sim.state.surface_id != deck.id:
		push_error(
			"hash: buried remount failed mode=%s sid=%s h=%.1f"
			% [sim.state.mode, sim.state.surface_id, sim.state.position.z]
		)
		return false
	if absf(sim.state.position.z - deck.height) > SimTolerances.CONTACT_EPS * 2.0:
		push_error("hash: not on deck top after remount h=%.1f" % sim.state.position.z)
		return false
	if absf(sim.state.tangent_velocity.x) < 1.0:
		push_error("hash: remount cleared motion tv=%.1f" % sim.state.tangent_velocity.x)
		return false
	# 2) Floor approach into deck XZ at base height → remount via contain, not pin.
	var pad: SupportPatch = sim.model.patches[floor_id]
	var start_x := deck.x_max + 10.0
	if not pad.contains_xz(start_x, z):
		start_x = deck.x_min - 10.0
	if not pad.contains_xz(start_x, z):
		return true ## remount path already proven; no abutting floor cell
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = floor_id
	sim.state.position = Vector3(start_x, z, pad.height)
	sim.state.tangent_velocity = Vector2(signf(mid_x - start_x) * 400.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	for _i in range(45):
		sim.set_input(Vector2(signf(mid_x - sim.state.position.x), 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("hash: died")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == deck.id:
			return true
		if (
			sim.state.is_grounded()
			and absf(sim.state.tangent_velocity.x) < 1.0
			and absf(sim.state.tangent_velocity.y) < 1.0
			and absf(sim.state.position.z - deck.base_height) < 5.0
			and absf(sim.state.position.x - mid_x) < sim.model.cell_w * 1.5
		):
			push_error(
				"hash: pinned at deck face x=%.1f h=%.1f sid=%s"
				% [sim.state.position.x, sim.state.position.z, sim.state.surface_id]
			)
			return false
	return true


func _l0_lava_gap_no_phantom_wall_climb() -> bool:
	# Under L1 hole rows, L0 pipes facing lava must air-out at geometric lip —
	# not climb a phantom WALL_EXTENSION toward missing L1 geometry.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("lava: setup")
		return false
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		var samp := p.sample_at_z((p.z_min + p.z_max) * 0.5)
		if float(samp.get("base_height", 0.0)) > 10.0:
			continue
		if right == null or p.coping_x_at((p.z_min + p.z_max) * 0.5) < right.coping_x_at(
			(right.z_min + right.z_max) * 0.5
		):
			right = p
	if right == null:
		push_error("lava: no L0 right pipe")
		return false
	var cope: CopingEdge = sim.model.copings.get(right.coping_id)
	if cope == null or cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
		push_error("lava: expected WALL_EXTENSION coping")
		return false
	var cell_h := sim.model.cell_h
	var H := sim.model.grid_h
	# L1 hole band (ASCII rows ~9–14).
	var hole_z := (float(H - 1 - 11) + 0.5) * cell_h
	var z := clampf(hole_z, right.z_min + 1.0, right.z_max - 1.0)
	var hole_span := cope.span_at_z(z)
	if hole_span == null or not hole_span.wall_id.is_empty():
		push_error("lava: hole span should compile without a wall")
		return false
	var hole_edge := sim.query.edge_at(right.id, z, "coping")
	if hole_edge == null or hole_edge.kind != SimKinds.EdgeKind.OPEN_COPING:
		push_error("lava: hole span should compile an OPEN edge")
		return false
	var h_geom := right.height_at_theta(z, PI * 0.5)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = right.id
	sim.state.u = 0.95
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(
		right.x_at_theta(z, 0.95 * PI * 0.5),
		z,
		right.height_at_theta(z, 0.95 * PI * 0.5)
	)
	sim.state.clear_hang()
	for _i in range(45):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_airborne():
			if sim.state.position.z > h_geom + 40.0:
				push_error(
					"lava: climbed phantom wall h=%.1f geom=%.1f"
					% [sim.state.position.z, h_geom]
				)
				return false
			return true
		if sim.model.walls.has(sim.state.surface_id):
			push_error("lava: entered explicit wall in hole span h=%.1f" % sim.state.position.z)
			return false
	push_error("lava: never left pipe")
	return false


## Grounded feet on an `x` pad kill; airborne over lava does not.
func _lava_grounded_contact_kills() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/test_lava.ssk"):
		push_error("lava kill: setup")
		return false
	var lava: SupportPatch = null
	for id in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[id]
		if p.lethal:
			lava = p
			break
	if lava == null:
		push_error("lava kill: no lethal patch")
		return false
	var mx := (lava.x_min + lava.x_max) * 0.5
	var mz := (lava.z_min + lava.z_max) * 0.5
	# Airborne over lava: stay alive.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.alive = true
	sim.state.position = Vector3(mx, mz, lava.height + 80.0)
	sim.state.velocity = Vector3(0.0, 0.0, 0.0)
	sim.state.air_peak_height = sim.state.position.z
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.alive:
		push_error("lava kill: airborne over lava must not kill")
		return false
	# Skate from spawn floor into the lava footprint (floor poly may overlap).
	sim.respawn()
	if not sim.state.alive or not sim.state.is_grounded():
		push_error("lava kill: respawn failed")
		return false
	var died := false
	for _i in range(180):
		# Move toward lava in +Z (fixture: @ south of x row).
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if not sim.state.alive:
			died = true
			if not str(sim.state.surface_id).begins_with("lava"):
				push_error("lava kill: died on %s, want lava" % sim.state.surface_id)
				return false
			break
	if not died:
		push_error(
			"lava kill: skating into lava never died surf=%s pos=%s"
			% [sim.state.surface_id, sim.state.position]
		)
		return false
	# Direct mount / land onto lava also kills.
	sim.respawn()
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = lava.id
	sim.state.position = Vector3(mx, mz, lava.height)
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.alive = true
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if sim.state.alive:
		push_error("lava kill: grounded on lethal patch must die")
		return false
	# Descending land onto lava footprint.
	sim.respawn()
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.alive = true
	sim.state.position = Vector3(mx, mz, lava.height + 60.0)
	sim.state.velocity = Vector3(0.0, 0.0, -400.0)
	sim.state.air_peak_height = sim.state.position.z
	var landed_dead := false
	for _j in range(40):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.alive:
			landed_dead = true
			break
	if not landed_dead:
		push_error(
			"lava kill: air land on lava never died mode=%s surf=%s alive=%s"
			% [sim.state.mode, sim.state.surface_id, sim.state.alive]
		)
		return false
	return true


## After lava death, respawn ~CHECKPOINT_HISTORY_SEC back on floor/deck — not
## the lethal edge and not a one-tick nudge.
func _respawn_at_prior_floor_or_deck() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/test_lava.ssk"):
		push_error("respawn cp: setup")
		return false
	var spawn_pos := sim.state.position
	# Build a full history window by skating along the floor (away from lava).
	# Keep going until the oldest sample is no longer the IDL spawn pose.
	var mark := Vector3.ZERO
	var marked := false
	for _i in range(sim._checkpoint_history_limit() * 2 + 10):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("respawn cp: died while filling history")
			return false
		if sim.checkpoint_history.size() >= sim._checkpoint_history_limit() \
				and sim.checkpoint_position.distance_to(spawn_pos) > 20.0:
			mark = sim.checkpoint_position
			marked = true
			break
	if not marked:
		push_error(
			"respawn cp: oldest sample never left spawn (cp=%s hist=%d)"
			% [sim.checkpoint_position, sim.checkpoint_history.size()]
		)
		return false
	# Now skate into lava and die.
	var died := false
	for _j in range(180):
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if not sim.state.alive:
			died = true
			break
	if not died:
		push_error("respawn cp: never died on lava")
		return false
	var want := sim.checkpoint_position
	sim.respawn()
	if not sim.state.alive or not sim.state.is_grounded():
		push_error("respawn cp: bad respawn state")
		return false
	if sim.state.position.distance_to(want) > 5.0:
		push_error(
			"respawn cp: should restore oldest history sample %s got %s"
			% [want, sim.state.position]
		)
		return false
	if sim.state.position.distance_to(spawn_pos) < 10.0:
		push_error("respawn cp: collapsed to IDL spawn")
		return false
	# Pad switch: floor history then deck — oldest should still be floor.
	var deck_sim := PlayerSim.new()
	if not deck_sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("respawn cp: deck setup")
		return false
	var spawn_floor_id := deck_sim.state.surface_id
	var spawn_floor_pos := deck_sim.state.position
	if not deck_sim._is_checkpoint_surface(spawn_floor_id):
		push_error("respawn cp: spawn should be floor")
		return false
	var deck: SupportPatch = null
	for id in deck_sim.model.patches.keys():
		var p: SupportPatch = deck_sim.model.patches[id]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("respawn cp: no deck")
		return false
	var dx := (deck.x_min + deck.x_max) * 0.5
	var dz := (deck.z_min + deck.z_max) * 0.5
	deck_sim.state.mode = SimState.Mode.GROUNDED
	deck_sim.state.surface_id = deck.id
	deck_sim.state.position = Vector3(dx, dz, deck.height)
	deck_sim.state.tangent_velocity = Vector2.ZERO
	deck_sim.set_input(Vector2.ZERO, false, false)
	deck_sim.tick()
	if deck_sim.checkpoint_surface_id != spawn_floor_id:
		push_error(
			"respawn cp: oldest should still be spawn floor %s got %s"
			% [spawn_floor_id, deck_sim.checkpoint_surface_id]
		)
		return false
	deck_sim.state.alive = false
	deck_sim.respawn()
	if deck_sim.state.surface_id != spawn_floor_id:
		push_error(
			"respawn cp: should restore floor %s got %s"
			% [spawn_floor_id, deck_sim.state.surface_id]
		)
		return false
	if deck_sim.state.position.distance_to(spawn_floor_pos) > 5.0:
		push_error(
			"respawn cp: floor pose want ~%s got %s"
			% [spawn_floor_pos, deck_sim.state.position]
		)
		return false
	return true


## Leaving a hang edge's Z span must keep X-lock + hang (no free-air level-out)
## unless the player flys out. Also remounts the far same-facing pipe on air_transfer.
func _hang_persists_off_edge_z_span() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/air_transfer.ssk"):
		push_error("hang off-z: setup")
		return false
	var spawn_z := sim.state.position.y
	var source: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		if spawn_z < p.z_min - 1.0 or spawn_z > p.z_max + 1.0:
			continue
		source = p
		break
	if source == null:
		push_error("hang off-z: no right pipe at spawn depth")
		return false
	_place_at_coping(sim, source, 400.0)
	sim.state.set_facing_side("r")
	SimTolerances.APEX_FACING_DELAY = 0.05
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("hang off-z: expected hang after coping leave")
		return false
	var lock_x := source.coping_x_at(sim.state.position.y)
	var takeoff_facing := sim.state.facing
	var saw_gap_air := false
	var remounted := false
	for _i in range(240):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("hang off-z: died at z=%.1f h=%.1f" % [
				sim.state.position.y, sim.state.position.z
			])
			return false
		if absf(sim.state.position.x - lock_x) > SimTolerances.ALIGN_EPS + 0.5:
			push_error(
				"hang off-z: lost X lock got %.2f want %.2f"
				% [sim.state.position.x, lock_x]
			)
			return false
		# Mid-lava band (well clear of either pipe's ALIGN_EPS soft edge).
		var mid_gap := (
			sim.state.position.y < source.z_min - SimTolerances.ALIGN_EPS - 1.0
			and sim.state.position.y > 94.0 + SimTolerances.ALIGN_EPS + 1.0
		)
		if mid_gap:
			saw_gap_air = true
			if not sim.state.is_hanging():
				push_error(
					"hang off-z: cleared hang over lava without fly-out (reject=%s)"
					% sim.state.last_reject
				)
				return false
			if absf(sim.state.velocity.x) > 0.01:
				push_error("hang off-z: hang over gap must keep vx=0")
				return false
			if absf(sim.state.facing_yaw) > 0.05:
				push_error("hang off-z: yaw changed during depth transfer")
				return false
			if sim.state.facing != takeoff_facing:
				push_error("hang off-z: facing flipped during depth transfer")
				return false
		if sim.state.is_grounded() and sim.model.pipes.has(sim.state.surface_id):
			var landed: PipeSurface = sim.model.pipes[sim.state.surface_id]
			if landed.side != SimKinds.PipeSide.RIGHT:
				push_error("hang off-z: landed wrong-facing pipe")
				return false
			if landed.id == source.id:
				continue
			remounted = true
			break
	if not saw_gap_air:
		push_error("hang off-z: never airborne over lava mid-gap")
		return false
	if not remounted:
		push_error(
			"hang off-z: never remounted far pipe (mode=%s z=%.1f hang=%s)"
			% [sim.state.mode, sim.state.position.y, sim.state.hang_edge_id]
		)
		return false
	# Fly-out still clears hang on the launch span.
	var fly := PlayerSim.new()
	if not fly.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("hang off-z fly: setup")
		return false
	var left := _left_pipe(fly.model)
	_place_at_coping(fly, left, 200.0)
	fly.set_input(Vector2.ZERO, false, false)
	fly.tick()
	if not fly.state.is_hanging():
		push_error("hang off-z fly: expected hang")
		return false
	fly.set_input(Vector2(-1, 0), false, false)
	fly.tick()
	if fly.state.is_hanging():
		push_error("hang off-z fly: fly-out must clear hang")
		return false
	return true


## ####((( : ride deck toward pipe → fall (no auto-stick); acid drop mounts.
func _deck_ride_off_falls_acid_mounts() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("deck drop: setup")
		return false
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	var left_cope: CopingEdge = sim.model.copings[left.coping_id]
	var deck_span := left_cope.span_at_z((left.z_min + left.z_max) * 0.5)
	if deck_span == null or deck_span.outward_deck_id.is_empty():
		push_error("deck drop: left pipe should have outward deck")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("deck drop: no deck")
		return false
	var z := (deck.z_min + deck.z_max) * 0.5
	var cx := left.coping_x_at(z)
	# Near the deck’s pipe-facing edge, skating +X toward the ramp.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.u = 0.0
	sim.state.v = 0.0
	sim.state.position = Vector3(cx - sim.model.cell_w * 0.6, z, deck.height)
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	sim.state.maneuver = null
	var left_id := left.id
	var saw_air := false
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_airborne():
			saw_air = true
			break
		if sim.model.pipes.has(sim.state.surface_id):
			push_error("deck drop: auto-mounted pipe while still grounded on deck ride-off")
			return false
	if not saw_air:
		push_error("deck drop: never left deck into air")
		return false
	# Keep falling without transfer — must not stick to the abutting pipe.
	for _j in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == left_id:
			push_error("deck drop: ordinary land stuck to deck-backed pipe without acid")
			return false
		if sim.state.is_grounded() and not sim.model.pipes.has(sim.state.surface_id):
			break ## floor / void catch in the bowl is fine
		if not sim.state.alive:
			break
	# Fresh ride-off, then acid while descending.
	var acid := PlayerSim.new()
	if not acid.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("deck acid: setup")
		return false
	var left2 := _left_pipe(acid.model)
	var deck2: SupportPatch = null
	for pid2 in acid.model.patches.keys():
		var p2: SupportPatch = acid.model.patches[pid2]
		if int(p2.kind) == SimKinds.SurfaceKind.DECK:
			deck2 = p2
			break
	var z2 := (deck2.z_min + deck2.z_max) * 0.5
	var cx2 := left2.coping_x_at(z2)
	acid.state.mode = SimState.Mode.GROUNDED
	acid.state.surface_id = deck2.id
	acid.state.position = Vector3(cx2 - acid.model.cell_w * 0.6, z2, deck2.height)
	acid.state.tangent_velocity = Vector2(400.0, 0.0)
	acid.state.clear_hang()
	for _k in range(90):
		acid.set_input(Vector2(1, 0), false, false)
		acid.tick()
		if acid.state.is_airborne():
			break
	if not acid.state.is_airborne():
		push_error("deck acid: never airborne")
		return false
	# Wait until descending, then press transfer.
	var pressed := false
	for _m in range(90):
		var edge := false
		if not pressed and acid.state.velocity.z < -1.0:
			edge = true
			pressed = true
		acid.set_input(Vector2(1, 0), false, edge)
		acid.tick()
		if acid.state.has_maneuver() and acid.state.maneuver.kind == ManeuverPlan.Kind.ACID:
			break
		if acid.state.is_grounded() and acid.state.surface_id == left2.id:
			break
	# Resolve plan / land onto left pipe.
	for _n in range(120):
		acid.set_input(Vector2(1, 0), false, false)
		acid.tick()
		if acid.state.is_grounded() and acid.state.surface_id == left2.id:
			return true
	push_error(
		"deck acid: never mounted left pipe mode=%s surf=%s reject=%s"
		% [acid.state.mode, acid.state.surface_id, acid.state.last_reject]
	)
	return false


func _layered_deck_back_ride_off_stays_free() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("deck back fall: setup")
		return false
	var deck: SupportPatch = sim.model.patches.get("deck_2_L1")
	if deck == null:
		push_error("deck back fall: missing L1 deck")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.position = Vector3(deck.x_min + 10.0, 1000.0, deck.height)
	sim.state.tangent_velocity = Vector2(-300.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	var saw_free_fall := false
	for _i in range(30):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if sim.model.walls.has(sim.state.surface_id):
			push_error("deck back fall: ordinary ride-off auto-mounted wall")
			return false
		if sim.state.is_hanging():
			push_error("deck back fall: ordinary ride-off acquired X lock")
			return false
		if sim.state.is_airborne() \
				and sim.state.position.x < deck.x_min - 1.0 \
				and sim.state.velocity.z < -50.0:
			saw_free_fall = true
			break
	if not saw_free_fall:
		push_error(
			"deck back fall: did not clear wall under gravity mode=%s surf=%s pos=%s vel=%s"
			% [
				sim.state.mode,
				sim.state.surface_id,
				sim.state.position,
				sim.state.velocity,
			]
		)
		return false
	return true


## )))#### at the map edge: skating off the deck must not fall into the void.
func _map_edge_deck_no_void_exit() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("edge deck: setup")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) != SimKinds.SurfaceKind.DECK:
			continue
		if deck == null or p.x_max > deck.x_max:
			deck = p
	if deck == null or deck.x_max < sim.model.width - 1.0:
		push_error("edge deck: expected rightmost deck on map edge")
		return false
	var z := (deck.z_min + deck.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.position = Vector3(deck.x_max - 10.0, z, deck.height)
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	sim.state.maneuver = null
	for _i in range(180):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("edge deck: died")
			return false
		if sim.state.surface_id == "__void_floor__":
			push_error("edge deck: fell to void floor x=%.1f" % sim.state.position.x)
			return false
		if sim.state.position.x > sim.model.width + 1.0:
			push_error("edge deck: escaped east x=%.1f" % sim.state.position.x)
			return false
		if sim.state.is_airborne() and sim.state.position.z < deck.height - 40.0:
			push_error(
				"edge deck: fell off map rim in air h=%.1f x=%.1f"
				% [sim.state.position.z, sim.state.position.x]
			)
			return false
	if not sim.state.is_grounded() or sim.state.surface_id != deck.id:
		push_error(
			"edge deck: expected to stay on deck mode=%s surf=%s"
			% [sim.state.mode, sim.state.surface_id]
		)
		return false
	return true


## Upper-story Z boundaries must not cut a continuous L0 quarter-pipe coping.
## Crossing one while hanging used to invalidate the anchor and drop to void.
func _layered_outer_coping_seam_stays_anchored() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("coping seam: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get("pipe_0_L0_S0")
	var z := 681.406351327896
	var edge := sim.query.edge_at(pipe.id, z, "coping") if pipe != null else null
	if pipe == null or edge == null:
		push_error("coping seam: missing outer quarter-pipe anchor")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = Vector3(
		pipe.coping_x_at(z), z, pipe.height_at_theta(z, PI * 0.5)
	)
	sim.state.velocity = Vector3(0.0, -400.0, 1242.08923339844)
	sim.state.begin_hang(edge.id)
	for tick in range(120):
		var wish := Vector2(0, -1)
		if tick >= 49:
			wish = Vector2(0, 1)
		elif tick >= 39:
			wish = Vector2(-1, -1)
		elif tick >= 34:
			wish = Vector2.ZERO
		elif tick >= 8:
			wish = Vector2(-1, 1)
		sim.set_input(wish, false, false)
		sim.tick()
		if sim.state.surface_id == "__void_floor__":
			push_error("coping seam: invalidated anchor dropped through the quarter pipe")
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id != pipe.id:
				push_error("coping seam: returned to %s instead of source pipe" % sim.state.surface_id)
				return false
			return true
	push_error(
		"coping seam: never returned to source pipe mode=%s hang=%s pos=%s"
		% [sim.state.mode, sim.state.hang_edge_id, sim.state.position]
	)
	return false


## L0 WALL_EXTENSION hang must remount the wall at current height — not snap to
## the geometric lip, and not auto-mount the opposite L1 ramp (spine = transfer).
func _layered_hang_remounts_wall_height() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("wall remount: setup")
		return false
	var l0r: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	var l1l: PipeSurface = sim.model.pipes.get("pipe_4_L1_S0")
	if l0r == null or l1l == null:
		push_error("wall remount: missing pipes")
		return false
	var z := clampf(1800.0, l1l.z_min + 5.0, l1l.z_max - 5.0)
	var cope: CopingEdge = sim.model.copings[l0r.coping_id]
	if cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
		push_error("wall remount: expected WALL_EXTENSION")
		return false
	var span := cope.span_at_z(z)
	if span == null or not sim.model.walls.has(span.wall_id):
		push_error("wall remount: explicit wall missing")
		return false
	var wall: WallSurface = sim.model.walls[span.wall_id]
	var h_eff := float(wall.sample_at_z(z).top_height)
	var h_geom := l0r.height_at_theta(z, PI * 0.5)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = l0r.id
	sim.state.u = 0.9
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(
		l0r.x_at_theta(z, 0.9 * PI * 0.5), z, l0r.height_at_theta(z, 0.9 * PI * 0.5)
	)
	sim.state.clear_hang()
	var hung := false
	for _i in range(60):
		if sim.state.is_grounded():
			sim.set_input(Vector2(1, 0), false, false)
		else:
			sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("wall remount: never hung")
		return false
	for _j in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.has_maneuver():
			push_error("wall remount: auto maneuver %s" % sim.state.maneuver.kind)
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id == l1l.id:
				push_error("wall remount: auto-mounted opposite L1 (spine steal)")
				return false
			if sim.state.surface_id != wall.id:
				push_error("wall remount: landed on %s" % sim.state.surface_id)
				return false
			if sim.state.position.z <= h_geom + 5.0:
				push_error(
					"wall remount: snapped to geometric lip h=%.1f u=%.2f"
					% [sim.state.position.z, sim.state.u]
				)
				return false
			if sim.state.position.z < h_eff - 40.0:
				push_error(
					"wall remount: too low on wall h=%.1f u=%.2f"
					% [sim.state.position.z, sim.state.u]
				)
				return false
			if absf(sim.state.tangent_velocity.x) < 200.0:
				push_error(
					"wall remount: fall speed eaten (L1 bounce?) tv=%.1f"
					% sim.state.tangent_velocity.x
				)
				return false
			if sim.state.u < 0.0 or sim.state.u > 1.0:
				push_error("wall remount: invalid explicit wall u=%.2f" % sim.state.u)
				return false
			sim.set_input(Vector2.ZERO, false, false)
			sim.tick()
			if sim.state.surface_id != wall.id or sim.state.u >= 0.999:
				push_error("wall remount: did not descend from anchor u=%.3f" % sim.state.u)
				return false
			return true
	push_error(
		"wall remount: never grounded mode=%s surf=%s h=%.1f vz=%.1f hang=%s block=%s"
		% [
			sim.state.mode,
			sim.state.surface_id,
			sim.state.position.z,
			sim.state.velocity.z,
			sim.state.hang_edge_id,
			sim.query.blocker_at(sim.state.position),
		]
	)
	return false


func _layered_l1_coping_returns_source() -> bool:
	var model := IdlCompiler.compile_path("res://levels/layered_demo.ssk")
	for pipe_id in model.all_pipe_ids():
		var pipe: PipeSurface = model.pipes[pipe_id]
		var sample := pipe.sample_at_z((pipe.z_min + pipe.z_max) * 0.5)
		if float(sample.base_height) < 100.0:
			continue
		var sim := PlayerSim.new()
		if not sim.setup_from_path("res://levels/layered_demo.ssk"):
			return false
		var z := (pipe.z_min + pipe.z_max) * 0.5
		var theta := 0.9 * PI * 0.5
		sim.state.mode = SimState.Mode.GROUNDED
		sim.state.surface_id = pipe.id
		sim.state.u = 0.9
		sim.state.v = 0.5
		sim.state.position = Vector3(
			pipe.x_at_theta(z, theta), z, pipe.height_at_theta(z, theta)
		)
		sim.state.tangent_velocity = Vector2(500.0, 0.0)
		sim.state.velocity = Vector3.ZERO
		sim.state.clear_hang()
		var blocker := sim.query.blocker_at(sim.state.position)
		if not blocker.is_empty() and str(blocker.get("surface_id", "")) != pipe.id:
			push_error("L1 coping starts inside foreign feature: %s" % blocker)
			return false
		var hung := false
		for _tick in range(180):
			var wish := Vector2(pipe.outward_sign(), 0.0) if not hung else Vector2.ZERO
			sim.set_input(wish, false, false)
			sim.tick()
			if not sim.state.alive:
				push_error("L1 coping caused death on %s" % pipe.id)
				return false
			if sim.state.is_hanging():
				hung = true
			elif hung and sim.state.is_grounded():
				if sim.state.surface_id != pipe.id:
					push_error(
						"L1 air-out returned to %s instead of %s"
						% [sim.state.surface_id, pipe.id]
					)
					return false
				break
		if not hung or not sim.state.is_grounded() or sim.state.surface_id != pipe.id:
			push_error("L1 coping cycle incomplete on %s" % pipe.id)
			return false
	return true


func _wall_z_exit_consumes_motion() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		return false
	var wall: WallSurface = null
	for id in sim.model.all_wall_ids():
		var candidate: WallSurface = sim.model.walls[id]
		var source: PipeSurface = sim.model.pipes[candidate.source_pipe_id]
		if source.side == SimKinds.PipeSide.LEFT and candidate.contains_z(1057.5):
			wall = candidate
			break
	if wall == null:
		push_error("wall Z exit: fixture wall missing")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall.id
	sim.state.u = 0.5
	sim.state.v = 1.0
	sim.state.position = wall.position_at(wall.z_max - 1.0, sim.state.u)
	sim.state.tangent_velocity = Vector2(0.0, 400.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	sim.set_input(Vector2(0.0, 1.0), false, false)
	sim.tick()
	if not sim.state.is_airborne() or sim.state.is_hanging():
		push_error("wall Z exit did not enter free air")
		return false
	if sim.state.position.y <= wall.z_max + SimTolerances.ALIGN_EPS:
		push_error(
			"wall Z exit did not consume crossing: z=%.2f edge=%.2f"
			% [sim.state.position.y, wall.z_max]
		)
		return false
	for _tick in range(60):
		sim.set_input(Vector2(0.0, 1.0), false, false)
		sim.tick()
		if sim.state.surface_id == wall.id:
			push_error("wall Z exit remounted the departed wall")
			return false
		if absf(sim.state.velocity.z) > 1500.0:
			push_error("wall Z exit pumped vertical speed: %.1f" % sim.state.velocity.z)
			return false
	return true


func _cross_story_spine_is_action_only() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_cross_story.ssk"):
		push_error("cross-story spine: setup")
		return false
	var wall: WallSurface = null
	for id in sim.model.all_wall_ids():
		wall = sim.model.walls[id]
		break
	if wall == null or wall.upper_partner_pipe_id.is_empty():
		push_error("cross-story spine: missing wall/partner")
		return false
	var source: PipeSurface = sim.model.pipes[wall.source_pipe_id]
	var target: PipeSurface = sim.model.pipes[wall.upper_partner_pipe_id]
	var z := (wall.z_min + wall.z_max) * 0.5
	var edge := sim.query.edge_at(wall.id, z, "top")
	var anchor := sim.query.edge_anchor_sample(edge, z)
	if edge == null or edge.transfer_target_id != target.coping_id or anchor.is_empty():
		push_error("cross-story spine: invalid action edge")
		return false
	# No transfer input: remain anchored/return to the source wall.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.hang_edge_id = edge.id
	sim.state.maneuver = null
	sim.state.position = Vector3(float(anchor.x), z, float(anchor.height) + 5.0)
	sim.state.velocity = Vector3(0.0, 0.0, 80.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if sim.state.has_maneuver() or sim.state.surface_id == target.id:
		push_error("cross-story spine: transferred without action")
		return false
	# Transfer input: the compiled target is reachable only through a spine plan.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.hang_edge_id = edge.id
	sim.state.maneuver = null
	sim.state.position = Vector3(float(anchor.x), z, float(anchor.height) + 5.0)
	sim.state.velocity = Vector3(0.0, 0.0, 80.0)
	sim.set_input(Vector2(source.outward_sign(), 0.0), false, true)
	sim.tick()
	if not sim.state.has_maneuver() \
			or sim.state.maneuver.kind != ManeuverPlan.Kind.SPINE:
		push_error("cross-story spine: action rejected: %s" % sim.state.last_reject)
		return false
	for _i in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded():
			if sim.state.surface_id != target.id:
				push_error("cross-story spine: landed on %s" % sim.state.surface_id)
				return false
			return true
	push_error("cross-story spine: plan never landed")
	return false


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


## Climb a `>` ramp to the peak → free-air launch with upward tangent, no hang/X-lock.
func _ramp_peak_free_air_launch() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("ramp peak: setup failed")
		return false
	if sim.model.ramps.is_empty():
		push_error("ramp peak: no ramps compiled")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	if ramp.side != SimKinds.PipeSide.RIGHT:
		push_error("ramp peak: expected right ramp")
		return false
	var z := (ramp.z_min + ramp.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = 0.2
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(
		ramp.x_at_theta(z, 0.2 * PI * 0.5),
		z,
		ramp.height_at_theta(z, 0.2 * PI * 0.5)
	)
	sim.state.clear_hang()
	var launched := false
	for _i in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
			push_error("ramp peak: hang/X-lock must never engage")
			return false
		if sim.state.is_airborne():
			launched = true
			break
	if not launched:
		push_error("ramp peak: never launched (u=%.2f grounded=%s)" % [
			sim.state.u, sim.state.is_grounded()
		])
		return false
	if sim.state.velocity.z <= 1.0:
		push_error("ramp peak: expected upward height vel, got %s" % sim.state.velocity)
		return false
	if sim.state.velocity.x <= 1.0:
		push_error("ramp peak: expected outward +X, got %s" % sim.state.velocity)
		return false
	# Stay free-air for a few ticks — no sticky remount at peak height.
	for _j in range(6):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_hanging():
			push_error("ramp peak: hang engaged after launch")
			return false
	return true


## Deck height matches ramp peak; riding off the peak launches free air (no deck stick).
func _ramp_deck_seam_and_launch() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_deck.ssk"):
		push_error("ramp deck: setup failed")
		return false
	if sim.model.ramps.size() < 2:
		push_error("ramp deck: expected two ramps, got %d" % sim.model.ramps.size())
		return false
	var right: RampSurface = null
	for id in sim.model.all_ramp_ids():
		var r: RampSurface = sim.model.ramps[id]
		if r.side == SimKinds.PipeSide.RIGHT:
			right = r
			break
	if right == null:
		push_error("ramp deck: missing right ramp")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var peak_h := right.height_at_theta(z, PI * 0.5)
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("ramp deck: missing deck patch")
		return false
	if absf(deck.height - peak_h) > SimTolerances.SEAM_EPS:
		push_error("ramp deck: deck h=%.1f != ramp peak %.1f" % [deck.height, peak_h])
		return false
	# Ride right ramp off the peak — must free-air launch, not sticky-mount the deck.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = right.id
	sim.state.u = 0.85
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.position = Vector3(
		right.x_at_theta(z, 0.85 * PI * 0.5),
		z,
		right.height_at_theta(z, 0.85 * PI * 0.5)
	)
	sim.state.clear_hang()
	var launched := false
	for _i in range(60):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
			push_error("ramp deck: hang/X-lock must never engage")
			return false
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			push_error("ramp deck: sticky deck mount from peak (surf=%s)" % sim.state.surface_id)
			return false
		if sim.state.is_airborne():
			launched = true
			break
	if not launched:
		push_error("ramp deck: never free-air launched (surf=%s u=%.2f)" % [
			sim.state.surface_id, sim.state.u
		])
		return false
	if sim.state.velocity.z <= 1.0:
		push_error("ramp deck: expected upward launch, got %s" % sim.state.velocity)
		return false
	# Stay free over the abutting deck for a few ticks (no sticky remount).
	for _j in range(8):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_hanging():
			push_error("ramp deck: hang after launch")
			return false
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var pad: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(pad.kind) == SimKinds.SurfaceKind.DECK and sim.state.velocity.z > -1.0:
				push_error("ramp deck: remounted deck while still rising")
				return false
	return true


## Endcaps / outer backs / open deck sides stop like world borders — no ride-up remount.
func _feature_walls_block_endcaps_and_sides() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_feature_walls.ssk"):
		push_error("feature walls: setup")
		return false
	var right: RampSurface = null
	for id in sim.model.all_ramp_ids():
		var r: RampSurface = sim.model.ramps[id]
		if r.side == SimKinds.PipeSide.RIGHT:
			right = r
			break
	if right == null:
		push_error("feature walls: missing right ramp")
		return false
	var z_mid := (right.z_min + right.z_max) * 0.5
	var sample := right.sample_at_z(z_mid)
	var lip := float(sample.lip_x)
	var cope := right.coping_x_at(z_mid)
	var peak := float(sample.base_height) + float(sample.radius)
	var thick := SimTolerances.CAPSULE_RADIUS
	# 1) Walk into the far endcap from outside Z — must not remount / ride up.
	var approach_z := right.z_max + maxf(thick * 2.0, sim.model.cell_h * 0.35)
	var floor_x := (lip + cope) * 0.5
	var floor_top := sim.query.top_support(floor_x, approach_z, 5.0)
	if floor_top.is_empty() or float(floor_top.height) < -100.0:
		push_error("feature walls: no floor outside endcap")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = str(floor_top.surface_id)
	sim.state.position = Vector3(floor_x, approach_z, float(floor_top.height))
	sim.state.u = 0.0
	sim.state.v = 0.0
	sim.state.tangent_velocity = Vector2(0.0, -500.0)
	sim.state.clear_hang()
	for _i in range(90):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if sim.model.ramps.has(sim.state.surface_id):
			push_error("feature walls: remounted ramp via endcap")
			return false
		if sim.state.position.y < right.z_max - 1.0:
			push_error("feature walls: tunneled through far endcap z=%.1f" % sim.state.position.y)
			return false
	if sim.state.position.y < right.z_max:
		push_error("feature walls: crossed into ramp Z span via endcap")
		return false
	# 2) Open pipe outer back (no outward deck) — stop, do not remount.
	var open_pipe: PipeSurface = null
	for pid in sim.model.all_pipe_ids():
		var p: PipeSurface = sim.model.pipes[pid]
		var coping: CopingEdge = sim.model.copings[p.coping_id]
		var span := coping.span_at_z((p.z_min + p.z_max) * 0.5)
		if span != null and span.outward_deck_id.is_empty():
			open_pipe = p
			break
	if open_pipe == null:
		push_error("feature walls: missing open pipe")
		return false
	var pz := (open_pipe.z_min + open_pipe.z_max) * 0.5
	var pc := open_pipe.coping_x_at(pz)
	var back_x := pc + open_pipe.outward_sign() * maxf(thick * 3.0, sim.model.cell_w * 0.6)
	var floor2 := sim.query.top_support(back_x, pz, 5.0)
	if floor2.is_empty() or float(floor2.height) < -100.0:
		push_error("feature walls: no floor outside outer back")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = str(floor2.surface_id)
	sim.state.position = Vector3(back_x, pz, float(floor2.height))
	sim.state.tangent_velocity = Vector2(-open_pipe.outward_sign() * 600.0, 0.0)
	sim.state.clear_hang()
	for _j in range(90):
		sim.set_input(Vector2(-open_pipe.outward_sign(), 0), false, false)
		sim.tick()
		if sim.model.pipes.has(sim.state.surface_id):
			push_error("feature walls: remounted pipe via outer back")
			return false
		if open_pipe.outward_sign() > 0.0:
			if sim.state.position.x < pc - 1.0:
				push_error("feature walls: tunneled past outer back x=%.1f" % sim.state.position.x)
				return false
		elif sim.state.position.x > pc + 1.0:
			push_error("feature walls: tunneled past outer back x=%.1f" % sim.state.position.x)
			return false
	# 3) Deck open Z side — stop, no sticky top mount from below.
	var deck: SupportPatch = null
	for patch_id in sim.model.patches.keys():
		var patch: SupportPatch = sim.model.patches[patch_id]
		if int(patch.kind) == SimKinds.SurfaceKind.DECK:
			deck = patch
			break
	if deck == null:
		push_error("feature walls: missing deck")
		return false
	var mid_x := (deck.x_min + deck.x_max) * 0.5
	var deck_approach := deck.z_max + maxf(thick * 2.0, sim.model.cell_h * 0.35)
	var floor3 := sim.query.top_support(mid_x, deck_approach, 5.0)
	if floor3.is_empty() or float(floor3.height) < -100.0:
		push_error("feature walls: no floor outside deck")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = str(floor3.surface_id)
	sim.state.position = Vector3(mid_x, deck_approach, float(floor3.height))
	sim.state.tangent_velocity = Vector2(0.0, -500.0)
	sim.state.clear_hang()
	for _k in range(120):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var landed: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(landed.kind) == SimKinds.SurfaceKind.DECK \
					and absf(sim.state.position.z - deck.height) <= SimTolerances.SEAM_EPS \
					and float(floor3.height) < deck.height - SimTolerances.SEAM_EPS:
				push_error("feature walls: sticky-mounted deck top from open side")
				return false
		if sim.state.position.y < deck.z_max - 1.0 and float(floor3.height) < deck.height - 5.0:
			if sim.state.position.z < deck.height - SimTolerances.CONTACT_EPS:
				push_error("feature walls: entered deck volume through open side")
				return false
	if absf(deck.height - peak) > SimTolerances.SEAM_EPS:
		push_error("feature walls: deck/peak mismatch")
		return false
	return true
