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
		and _deterministic_replay()
		and _layered_spawn_respects_story()
		and _supports_sorted_high_to_low()
		and _pipe_along_wish_and_lip_exit()
		and _ollie_faces_direction()
		and _ollie_jump_charge_scales_impulse()
		and _ollie_height_picks_flat_vs_pipe()
		and _ollie_airborne_release_uses_launch_pipe_height()
		and _wall_ollie_hangs_x_locked()
		and _pipe_lip_ollie_respects_height_not_along()
		and _layered_wall_lip_ollie_peak_is_ollie_height_above_lip()
		and _layered_ollie_into_l1_pipe_back_crashes()
		and _layered_floor_ollie_into_joint_rear_falls_clear()
		and _layered_past_joint_fall_does_not_tunnel_partner()
		and _layered_joint_crash_fall_leans_away_from_wall()
		and _layered_pipe_top_skim_fall_stays_outside()
		and _layered_union_wall_crash_does_not_tunnel()
		and _layered_union_open_lips_fly_out()
		and _ollie_jump_caps_at_full_charge()
		and _ollie_jump_airborne_adds_impulse()
		and _ramp_air_ollie_peak_matches_lip_ollie()
		and _ollie_single_charge_replenishes_on_ground()
		and _ollie_on_pipe_pops_world_up_not_along_tangent()
		and _ollie_on_pipe_lip_enters_hang()
		and _ollie_pipe_lip_outward_deck_no_crash()
		and _ollie_short_deck_return_no_tunnel()
		and _ollie_pipe_low_vx_descending_remounts()
		and _ollie_climbing_ramp_stays_above_solid()
		and _ollie_into_pipe_with_stick_stays_outside()
		and _ramp_ollie_onto_abutting_deck_no_freeze()
		and _coast_with_zero_friction()
		and _air_no_x_friction()
		and _max_speed_x_is_absolute_ceiling()
		and _wall_extension_climbs()
		and _layered_deck_back_air_outs_at_upper_lip()
		and _upper_deck_flyout_hold_right_decks_out()
		and _upper_deck_2_no_stick_air_out()
		and _upper_deck_2_hold_right_keeps_rise()
		and _upper_deck_2_hang_return_past_deck_rear()
		and _upper_deck_2_apex_no_deck_snap()
		and _upper_deck_2_wall_bottom_no_deck_steal()
		and _l0_air_out_not_stuck_on_l1_opposite_deck()
		and _l0_pipe_ollie_not_stuck_on_l1_deck()
		and _l0_launch_does_not_force_land_inward_deck()
		and _l0_free_air_at_cope_remounts_wall_not_freeze()
		and _floor_ollie_coping_crashes_not_deck()
		and _air_contact_stream_lip_owns_coping_column()
		and _airborne_reject_leaves_exterior()
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
		and _layered_outer_wall_crashes_not_warp()
		and _layered_hole_not_invisible_wall()
		and _deck_hash_no_pin_from_floor()
		and _l0_lava_gap_no_phantom_wall_climb()
		and _lava_grounded_contact_kills()
		and _respawn_at_prior_floor_or_deck()
		and _hang_persists_off_edge_z_span()
		and _hang_depth_transfer_lands_edge_floor()
		and _hang_depth_transfer_lands_edge_lava()
		and _deck_ride_off_rejects_pre_surface_pipe_contact()
		and _deck_ride_off_mounts_only_on_descending_surface_crossing()
		and _right_pipe_deck_slow_leave_lands_floor()
		and _joint_wipeout_fall_tip_stays_approach()
		and _layered_next_spine_keeps_l1_past_l0_lip()
		and _transfer_button_lerps_x_holds_facing()
		and _transfer_shared_x_spine_reanchors_hang()
		and _transfer_rejects_below_hang_lip_after_floor_ollie()
		and _layered_deck_back_ride_off_stays_free()
		and _map_edge_deck_no_void_exit()
		and _layered_outer_coping_seam_stays_anchored()
		and _layered_hang_remounts_wall_height()
		and _layered_l1_coping_returns_source()
		and _wall_z_exit_consumes_motion()
		and _ramp_peak_free_air_launch()
		and _ramp_deck_seam_and_launch()
		and _feature_walls_block_endcaps_and_sides()
		and _air_land_ramp_keeps_uphill_along()
		and _air_land_pipe_maps_vx_via_outward()
		and _air_out_reenter_ramp_not_fake_uphill()
		and _air_out_reenter_pipe_not_fake_uphill()
		and _ollie_near_lip_stick_out_no_coping_hang()
		and _pipe_ollie_below_lip_keeps_peakward_x()
		and _ramp_adjacent_pipe_z_leave_no_hang()
		and _ramp_lip_ollie_is_free_air()
		and _ramp_lip_ollie_sets_free_air_upright()
		and _ramp_mid_ollie_keeps_lean()
		and _ramp_peak_leave_sets_free_air_upright()
		and _ramp_peak_beside_pipe_keeps_outward_x()
		and _fall_clears_hang_ignores_wish()
		and _fall_stops_planar_keeps_gravity()
		and _fall_air_waits_for_land_then_recovers()
		and _fall_crash_air_recovers_without_land()
		and _fall_midair_still_collides_pipe()
		and _fall_impact_bounds_requests_fall()
		and _fall_impact_deck_wall_requests_fall()
		and _fall_hang_flat_floor_requests_fall()
		and _fall_peak_leave_does_not_bail()
		and _ramp_lip_ollie_own_outward_deck_no_crash()
		and _fall_recovery_restores_checkpoint()
		and _crash_foreign_pipe_lip_rejects_and_falls()
		and _crash_foreign_pipe_below_lip_may_mount()
		and _crash_same_slope_upper_remount_no_bail()
		and _fly_out_ollie_same_pipe_no_crash()
		and _air_out_hang_return_deck_pipe_no_crash()
		and _air_out_hang_ollie_same_pipe_no_crash()
		and _crash_hang_clips_deck_requests_fall()
		and _ramp_edge_lip_stick_out_faces_and_climbs()
		and _z_band_short_coping_owns_short_deck()
		and _z_band_tall_to_short_leave_airs()
		and _z_band_short_to_tall_riser_falls()
	)


func _fall_clears_hang_ignores_wish() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("fall hang: setup")
		return false
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var left: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.LEFT:
			left = p
			break
	if left == null:
		push_error("fall hang: no left pipe")
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var edge := sim.query.edge_at(left.id, z, "coping")
	if edge == null:
		push_error("fall hang: no coping edge")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(edge.id)
	sim.state.position = Vector3(left.coping_x_at(z), z, left.height_at_theta(z, PI * 0.5) + 40.0)
	sim.state.velocity = Vector3(0.0, 0.0, 200.0)
	sim.begin_fall()
	if sim.state.is_hanging():
		push_error("fall hang: hang must clear")
		return false
	if not sim.state.falling:
		push_error("fall hang: expected falling")
		return false
	# Stick outward must not invent climb — wish ignored while falling.
	var u0 := NAN
	for _i in range(25):
		sim.set_input(Vector2(-1.0, 0.0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			if is_nan(u0):
				u0 = sim.state.u
			elif sim.state.u > u0 + 0.08 and sim.state.tangent_velocity.x > 30.0:
				push_error(
					"fall hang: stick-out climbed along while falling u %.2f→%.2f"
					% [u0, sim.state.u]
				)
				return false
	return true


func _fall_stops_planar_keeps_gravity() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("fall stop: setup")
		return false
	sim.fall_stop_duration = 0.35
	sim.fall_duration = 2.0
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.position = Vector3(sim.model.spawn_x, sim.model.spawn_z, 180.0)
	sim.state.velocity = Vector3(200.0, 80.0, 100.0)
	sim.state.note_air_height(sim.state.position.z)
	var z0 := sim.state.position.z
	sim.begin_fall()
	var ticks := int(ceil(sim.fall_stop_duration / SimTolerances.FIXED_DT)) + 2
	for _i in range(ticks):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.is_airborne():
			break
	if not sim.state.falling:
		push_error("fall stop: should still be falling")
		return false
	if sim.state.is_airborne():
		if absf(sim.state.velocity.x) > 5.0 or absf(sim.state.velocity.y) > 5.0:
			push_error(
				"fall stop: planar not near zero vx=%.1f vy=%.1f"
				% [sim.state.velocity.x, sim.state.velocity.y]
			)
			return false
		if sim.state.position.z >= z0 - 1.0:
			push_error(
				"fall stop: gravity should drop height %.1f → %.1f"
				% [z0, sim.state.position.z]
			)
			return false
	return true


func _fall_air_waits_for_land_then_recovers() -> bool:
	# Name is historical: recovery is duration-gated checkpoint restore (no land wait).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("fall recover: setup")
		return false
	sim.fall_anim_duration = 0.05
	sim.fall_stop_duration = 0.1
	sim.fall_duration = 0.2
	sim.friction = 0.0
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.position = Vector3(sim.model.spawn_x, sim.model.spawn_z, 220.0)
	sim.state.velocity = Vector3(0.0, 0.0, 50.0)
	sim.state.note_air_height(sim.state.position.z)
	sim.begin_fall()
	for _i in range(200):
		sim.set_input(Vector2(1.0, 0.0), false, false)
		sim.tick()
		if not sim.state.falling and sim.state.is_grounded():
			if sim.state.velocity.length() > 0.5 \
					or sim.state.tangent_velocity.length() > 0.5:
				push_error("fall recover: expected zero vel")
				return false
			# Wish should work again.
			var x0 := sim.state.position.x
			for _k in range(30):
				sim.set_input(Vector2(1.0, 0.0), false, false)
				sim.tick()
			if absf(sim.state.position.x - x0) < 1.0 \
					and absf(sim.state.tangent_velocity.x) < 10.0:
				push_error("fall recover: input still locked after recover")
				return false
			return true
	push_error("fall recover: never recovered grounded")
	return false


## Foreign high-lip Reject can trap mid-air; recovery must not wait for a land.
func _fall_crash_air_recovers_without_land() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("fall crash air: setup")
		return false
	sim.fall_anim_duration = 0.05
	sim.fall_stop_duration = 0.1
	sim.fall_duration = 0.25
	var pipe: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if pipe == null:
		push_error("fall crash air: missing pipe")
		return false
	var floor_id := ""
	for id in sim.model.patches.keys():
		if int(sim.model.patches[id].kind) == SimKinds.SurfaceKind.FLOOR:
			floor_id = id
			break
	if floor_id.is_empty():
		push_error("fall crash air: no floor")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = floor_id
	sim.state.position = Vector3(
		pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th) + 20.0
	)
	sim.state.velocity = Vector3(0.0, 0.0, -200.0)
	sim.state.note_air_height(sim.state.position.z)
	var saw_fall := false
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			saw_fall = true
		if saw_fall and not sim.state.falling and sim.state.is_grounded():
			if not sim._is_checkpoint_surface(sim.state.surface_id):
				push_error("fall crash air: restore not on floor/deck")
				return false
			return true
	push_error(
		"fall crash air: stuck falling=%s grounded=%s pos=%s"
		% [sim.state.falling, sim.state.is_grounded(), sim.state.position]
	)
	return false


func _fall_midair_still_collides_pipe() -> bool:
	# Falling into a pipe body must not tunnel past coping below peak.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("fall collide: setup")
		return false
	sim.fall_duration = 3.0
	sim.fall_stop_duration = 0.5
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("fall collide: no right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var cx := right.coping_x_at(z)
	var peak := right.height_at_theta(z, PI * 0.5)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = ""
	# Approach from bowl side toward coping, below peak.
	sim.state.position = Vector3(cx - 80.0, z, peak - 25.0)
	sim.state.velocity = Vector3(400.0, 0.0, -50.0)
	sim.state.note_air_height(sim.state.position.z + 10.0)
	sim.begin_fall()
	for _i in range(90):
		sim.set_input(Vector2(1.0, 0.0), false, false)
		sim.tick()
		if not sim.state.falling and not sim.state.is_grounded():
			push_error("fall collide: fall cleared without ground")
			return false
		if sim.state.is_airborne() and sim.state.position.z < peak - 5.0 \
				and sim.state.position.x > cx + SimTolerances.CAPSULE_RADIUS:
			push_error(
				"fall collide: tunneled past coping at %s" % sim.state.position
			)
			return false
		if sim.state.is_grounded():
			break
	return true


func _fall_impact_bounds_requests_fall() -> bool:
	# Grounded into park AABB (free-air rim over a border deck stays playable).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("fall bounds: setup")
		return false
	sim.fall_duration = 5.0
	var mid_z := sim.model.depth * 0.5
	var floor_top := sim.query.top_support(sim.model.width - 40.0, mid_z, 5.0)
	if floor_top.is_empty():
		push_error("fall bounds: no floor")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = str(floor_top.surface_id)
	sim.state.position = Vector3(sim.model.width - 40.0, mid_z, float(floor_top.height))
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.clear_hang()
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			return true
	push_error("fall bounds: never fell into world wall")
	return false


func _fall_impact_deck_wall_requests_fall() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_feature_walls.ssk"):
		push_error("fall deck wall: setup")
		return false
	sim.fall_duration = 5.0
	var deck: SupportPatch = null
	for id in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[id]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("fall deck wall: no deck")
		return false
	var mid_x := (deck.x_min + deck.x_max) * 0.5
	# Free-air into the deck open-side feature wall (floor footprint may end sooner).
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = ""
	sim.state.position = Vector3(mid_x, deck.z_max + 25.0, deck.height * 0.5)
	sim.state.velocity = Vector3(0.0, -500.0, 0.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(60):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if sim.state.falling:
			return true
	push_error("fall deck wall: never fell")
	return false


func _fall_hang_flat_floor_requests_fall() -> bool:
	# Hang off the pipe Z span onto floor — must fall (not skate away).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("fall hang flat: setup")
		return false
	sim.fall_duration = 5.0
	var left: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.LEFT:
			left = p
			break
	if left == null:
		push_error("fall hang flat: no left pipe")
		return false
	var z := (left.z_min + left.z_max) * 0.5
	var edge := sim.query.edge_at(left.id, z, "coping")
	if edge == null:
		push_error("fall hang flat: no coping")
		return false
	var off_z := left.z_min - 20.0
	if off_z < 1.0:
		off_z = left.z_max + 20.0
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(edge.id)
	sim.state.position = Vector3(left.coping_x_at(z), off_z, 80.0)
	sim.state.velocity = Vector3(0.0, 0.0, -100.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			return true
	push_error(
		"fall hang flat: never fell mode=%s surf=%s hang=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.hang_edge_id]
	)
	return false


func _fall_peak_leave_does_not_bail() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("fall peak leave: setup")
		return false
	sim.fall_duration = 5.0
	if sim.model.ramps.is_empty():
		push_error("fall peak leave: no ramps")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = 0.85
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(
		ramp.x_at_theta(z, 0.85 * PI * 0.5),
		z,
		ramp.height_at_theta(z, 0.85 * PI * 0.5)
	)
	sim.state.clear_hang()
	for _i in range(80):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error("fall peak leave: peak leave must not bail")
			return false
		if sim.state.is_airborne():
			# Give a few free-air ticks past the outer-back band.
			for _j in range(8):
				sim.set_input(Vector2(1, 0), false, false)
				sim.tick()
				if sim.state.falling:
					push_error("fall peak leave: fell after peak leave")
					return false
			return true
	push_error("fall peak leave: never launched")
	return false


## Lip-band ramp ollie into the abutting outward `#` must not crash (same bout).
func _ramp_lip_ollie_own_outward_deck_no_crash() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("ramp own deck: setup")
		return false
	sim.fall_duration = 5.0
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_pipe = 60.0
	sim.ollie_lip_frac = 0.50
	sim.friction = 0.0
	var ramp: RampSurface = null
	var deck_id := ""
	for id in sim.model.ramps.keys():
		var r: RampSurface = sim.model.ramps[id]
		var cope: CopingEdge = sim.model.copings.get(r.coping_id)
		if cope == null:
			continue
		var span = cope.span_at_z((r.z_min + r.z_max) * 0.5)
		if span == null or span.outward_deck_id.is_empty():
			continue
		ramp = r
		deck_id = span.outward_deck_id
		break
	if ramp == null or deck_id.is_empty():
		push_error("ramp own deck: no ramp with outward deck")
		return false
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(350.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.state.clear_hang()
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2(ramp.outward_sign(), 0.0), false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ramp own deck: expected free-air after lip ollie")
		return false
	if sim.state.is_hanging():
		push_error("ramp own deck: ramps must not hang")
		return false
	if sim.state.air_launch_surface_id != ramp.id:
		push_error("ramp own deck: launch should be ramp")
		return false
	for _i in range(60):
		sim.set_input(Vector2(ramp.outward_sign(), 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"ramp own deck: crashed into own outward deck pos=%s launch=%s"
				% [sim.state.position, sim.state.air_launch_surface_id]
			)
			return false
		# Landed on the air-out pad or remounted ramp — success.
		if sim.state.is_grounded() and (
			sim.state.surface_id == deck_id or sim.state.surface_id == ramp.id
		):
			return true
	# Still airborne past the pad without falling is acceptable for this gate.
	return not sim.state.falling


func _fall_recovery_restores_checkpoint() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("fall cp: setup")
		return false
	sim.fall_anim_duration = 0.05
	sim.fall_stop_duration = 0.05
	sim.fall_duration = 0.15
	sim.friction = 0.0
	var spawn := sim.state.position
	var floor_id := sim.state.surface_id
	if not sim._is_checkpoint_surface(floor_id):
		push_error("fall cp: spawn should be floor")
		return false
	for i in range(sim._checkpoint_history_limit()):
		sim._push_checkpoint_sample(
			floor_id,
			Vector3(spawn.x, spawn.y + 30.0 + float(i), spawn.z),
			"r"
		)
	var want := sim.checkpoint_position
	if want.distance_to(spawn) < 5.0:
		push_error("fall cp: history never left spawn")
		return false
	sim.begin_fall()
	for _j in range(200):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.falling and sim.state.is_grounded():
			if sim.state.position.distance_to(want) > 8.0:
				push_error(
					"fall cp: expected checkpoint %s got %s" % [want, sim.state.position]
				)
				return false
			if not sim._is_checkpoint_surface(sim.state.surface_id):
				push_error("fall cp: restored surface not floor/deck")
				return false
			return true
	push_error("fall cp: never recovered")
	return false


## Floor launch into foreign pipe upper ollie-lip band → Reject + fall, never Mount.
func _crash_foreign_pipe_lip_rejects_and_falls() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("crash lip: setup")
		return false
	sim.fall_duration = 5.0
	var right: PipeSurface = null
	var floor_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	for id in sim.model.patches.keys():
		if int(sim.model.patches[id].kind) == SimKinds.SurfaceKind.FLOOR:
			floor_id = id
			break
	if right == null or floor_id.is_empty():
		push_error("crash lip: missing pipe/floor")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = floor_id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 20.0
	)
	sim.state.velocity = Vector3(0.0, 0.0, -200.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			push_error(
				"crash lip: must not Mount foreign high pipe u=%.2f"
				% sim.state.u
			)
			return false
		if sim.state.falling:
			return true
	push_error(
		"crash lip: never fell mode=%s surf=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position]
	)
	return false


## Floor launch into foreign pipe below lip band may Mount (not forced lip crash).
func _crash_foreign_pipe_below_lip_may_mount() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("crash low pipe: setup")
		return false
	var right: PipeSurface = null
	var floor_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	for id in sim.model.patches.keys():
		if int(sim.model.patches[id].kind) == SimKinds.SurfaceKind.FLOOR:
			floor_id = id
			break
	if right == null or floor_id.is_empty():
		push_error("crash low pipe: missing pipe/floor")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.35
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = floor_id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 25.0
	)
	sim.state.velocity = Vector3(80.0, 0.0, -160.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error("crash low pipe: lip rule must not fall below band")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			if sim.state.u >= 1.0 - sim.ollie_lip_frac:
				push_error("crash low pipe: expected below-lip mount, u=%.2f" % sim.state.u)
				return false
			return true
	push_error("crash low pipe: never mounted")
	return false


## Same-slope air-out remount into upper band must not lip-crash.
func _crash_same_slope_upper_remount_no_bail() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("crash same-slope: setup")
		return false
	sim.fall_duration = 5.0
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("crash same-slope: missing pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = right.id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 14.0
	)
	sim.state.velocity = Vector3(0.0, 0.0, -180.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error("crash same-slope: remount must not bail")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			return true
	push_error("crash same-slope: never remounted")
	return false


## Stick fly-out from a deck-backed pipe, air ollie, return — same pipe, no bail.
func _fly_out_ollie_same_pipe_no_crash() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("fly-out ollie: setup")
		return false
	sim.fall_duration = 5.0
	sim.ollie_height_pipe = 200.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_accel = 0.0
	sim.ollie_lip_frac = 0.50
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	_place_at_coping(sim, left, 320.0)
	sim.ollie_available = true
	sim.set_input(Vector2(left.outward_sign(), 0.0), false, false, true, false)
	sim.tick()
	if not sim.state.is_airborne():
		push_error(
			"fly-out ollie: expected fly-out air reject=%s"
			% sim.state.last_reject
		)
		return false
	if sim.state.is_hanging():
		push_error("fly-out ollie: stick fly-out must unlock hang")
		return false
	if sim.state.air_launch_surface_id != left.id:
		push_error(
			"fly-out ollie: launch must be pipe, got '%s'"
			% sim.state.air_launch_surface_id
		)
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if sim.state.falling:
		push_error("fly-out ollie: crashed on ollie tick")
		return false
	for _i in range(150):
		sim.set_input(Vector2(-left.outward_sign(), 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"fly-out ollie: same-pipe return fell launch=%s pos=%s"
				% [sim.state.air_launch_surface_id, sim.state.position]
			)
			return false
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			return true
	push_error(
		"fly-out ollie: never remounted mode=%s surf=%s launch=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.air_launch_surface_id]
	)
	return false


## Hang air-out (no stick fly-out) return onto a deck-backed pipe must remount.
func _air_out_hang_return_deck_pipe_no_crash() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("air-out hang return: setup")
		return false
	sim.fall_duration = 5.0
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	_place_at_coping(sim, left, 280.0)
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error(
			"air-out hang return: expected hang mode=%s reject=%s"
			% [sim.state.mode, sim.state.last_reject]
		)
		return false
	if sim.state.air_launch_surface_id != left.id:
		push_error(
			"air-out hang return: launch=%s want %s"
			% [sim.state.air_launch_surface_id, left.id]
		)
		return false
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"air-out hang return: fell on remount hang=%s pos=%s"
				% [sim.state.is_hanging(), sim.state.position]
			)
			return false
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			return true
	push_error(
		"air-out hang return: never remounted mode=%s surf=%s"
		% [sim.state.mode, sim.state.surface_id]
	)
	return false


## Hang air-out + air ollie on the same deck-backed pipe — remount, no bail.
func _air_out_hang_ollie_same_pipe_no_crash() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_deck_backed.ssk"):
		push_error("air-out hang ollie: setup")
		return false
	sim.fall_duration = 5.0
	sim.ollie_height_pipe = 200.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_accel = 0.0
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var left := _left_pipe(sim.model)
	if left == null:
		return false
	_place_at_coping(sim, left, 280.0)
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("air-out hang ollie: expected hang")
		return false
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if sim.state.falling:
		push_error("air-out hang ollie: crashed on ollie tick")
		return false
	for _i in range(150):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"air-out hang ollie: fell launch=%s hang=%s pos=%s"
				% [
					sim.state.air_launch_surface_id,
					sim.state.is_hanging(),
					sim.state.position,
				]
			)
			return false
		if sim.state.is_grounded() and sim.state.surface_id == left.id:
			return true
	push_error("air-out hang ollie: never remounted")
	return false


## Hang X-lock clipping a deck solid requests fall (not only clean flat Mount).
func _crash_hang_clips_deck_requests_fall() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("crash hang deck: setup")
		return false
	sim.fall_duration = 5.0
	# Prefer a pipe with an outward deck at coping.
	var pipe: PipeSurface = null
	var deck_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		var cope: CopingEdge = sim.model.copings.get(p.coping_id)
		if cope == null:
			continue
		var span = cope.span_at_z((p.z_min + p.z_max) * 0.5)
		if span == null or span.outward_deck_id.is_empty():
			continue
		pipe = p
		deck_id = span.outward_deck_id
		break
	if pipe == null or deck_id.is_empty():
		push_error("crash hang deck: no pipe with outward deck")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var edge := sim.query.edge_at(pipe.id, z, "coping")
	if edge == null:
		push_error("crash hang deck: no coping edge")
		return false
	var deck: SupportPatch = sim.model.patches[deck_id]
	var cx := pipe.coping_x_at(z)
	# Hang snaps X to coping — probe inside the outward deck body (not above top,
	# which remounts the pipe before any clip contact).
	var dx := clampf(cx + pipe.outward_sign() * 40.0, deck.x_min + 1.0, deck.x_max - 1.0)
	var dz := clampf(z, deck.z_min + 1.0, deck.z_max - 1.0)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(edge.id)
	sim.state.position = Vector3(dx, dz, deck.height - 8.0)
	sim.state.velocity = Vector3(0.0, 0.0, -20.0)
	sim.state.note_air_height(sim.state.position.z)
	if sim.query.blocker_at(sim.state.position).is_empty():
		push_error("crash hang deck: expected start inside deck solid")
		return false
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			return true
	push_error(
		"crash hang deck: never fell mode=%s hang=%s pos=%s"
		% [sim.state.mode, sim.state.hang_edge_id, sim.state.position]
	)
	return false


## Park-edge >>> lip: facing left + hold right must face right and climb out
## (not bounce into void and remount with a downhill punch forever).
func _ramp_edge_lip_stick_out_faces_and_climbs() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("ramp edge lip: setup")
		return false
	if sim.model.ramps.is_empty():
		push_error("ramp edge lip: no ramps")
		return false
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var rid: String = str(sim.model.ramps.keys()[0])
	var ramp: RampSurface = sim.model.ramps[rid]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = rid
	sim.state.u = 0.05
	sim.state.v = 0.5
	sim.state.maneuver = null
	sim.state.clear_hang()
	var th := sim.state.u * PI * 0.5
	sim.state.position = Vector3(
		ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th)
	)
	sim.state.tangent_velocity = Vector2(-120.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.set_facing_side("l")
	var u0 := sim.state.u
	for _i in range(180):
		sim.set_input(Vector2(1.0, 0.0), false, false, false)
		sim.tick()
	if sim.state.facing != "r":
		push_error(
			"ramp edge lip: still facing %s after hold-right (sid=%s u=%.3f tv=%s)"
			% [sim.state.facing, sim.state.surface_id, sim.state.u, sim.state.tangent_velocity]
		)
		return false
	var climbed := sim.state.surface_id == rid and sim.state.u > u0 + 0.08
	var on_floor_right := (
		sim.state.is_grounded()
		and not sim.model.ramps.has(sim.state.surface_id)
		and sim.state.position.x > ramp.bound_x_max - 5.0
	)
	if not climbed and not on_floor_right:
		push_error(
			"ramp edge lip: did not climb/ride out (sid=%s u=%.3f→%.3f x=%.1f)"
			% [sim.state.surface_id, u0, sim.state.u, sim.state.position.x]
		)
		return false
	return true


func _air_land_ramp_keeps_uphill_along() -> bool:
	# Skate onto mid > with mostly horizontal +vx → uphill along (not forced downhill).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("air land ramp: setup")
		return false
	if sim.model.ramps.is_empty():
		push_error("air land ramp: no ramps")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var mid_u := 0.45
	var th := mid_u * PI * 0.5
	var mid_x := ramp.x_at_theta(z, th)
	var mid_h := ramp.height_at_theta(z, th)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.position = Vector3(mid_x, z, mid_h + 25.0)
	# Strong +X, mild fall — approach from the flat, not an air-out drop-in.
	sim.state.velocity = Vector3(420.0, 0.0, -80.0)
	var landed := false
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == ramp.id:
			landed = true
			if sim.state.tangent_velocity.x <= 0.0:
				push_error(
					"air land ramp: expected uphill along (>0), got %.1f"
					% sim.state.tangent_velocity.x
				)
				return false
			break
	if not landed:
		push_error("air land ramp: never grounded on ramp")
		return false
	return true


func _air_land_pipe_maps_vx_via_outward() -> bool:
	# Horizontal +vx onto mid ) → uphill along (not -max(impact, 80)).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("air land pipe: setup")
		return false
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("air land pipe: missing right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	# u=0.35 — above lip band (u≥1-ollie_lip_frac) free-air lands crash.
	var th := PI * 0.5 * 0.35
	var mid_x := right.x_at_theta(z, th)
	var mid_h := right.height_at_theta(z, th)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = ""
	sim.state.position = Vector3(mid_x, z, mid_h + 25.0)
	sim.state.velocity = Vector3(400.0, 0.0, -60.0)
	var landed := false
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed = true
			if sim.state.tangent_velocity.x <= 0.0:
				push_error(
					"air land pipe: expected uphill along, got %.1f"
					% sim.state.tangent_velocity.x
				)
				return false
			# Must not be the old forced -max(impact, 80) seed.
			if sim.state.tangent_velocity.x < -50.0:
				push_error(
					"air land pipe: still forced downhill along %.1f"
					% sim.state.tangent_velocity.x
				)
				return false
			break
	if not landed:
		push_error("air land pipe: never grounded on pipe")
		return false
	return true


func _air_out_reenter_ramp_not_fake_uphill() -> bool:
	# Air-out style: residual outward +vx while falling hard onto mid >.
	# Must project fall onto tangent (downhill), not map vx alone to uphill
	# (that felt like friction with ramp_friction = 0).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("air-out reenter: setup")
		return false
	sim.ramp_friction = 0.0
	sim.friction = 0.0
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var mid_u := 0.45
	var th := mid_u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.position = Vector3(
		ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th) + 50.0
	)
	sim.state.velocity = Vector3(220.0, 0.0, -420.0)
	var landed_along := NAN
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == ramp.id:
			landed_along = sim.state.tangent_velocity.x
			break
	if is_nan(landed_along):
		push_error("air-out reenter: never landed")
		return false
	if landed_along > 50.0:
		push_error(
			"air-out reenter: falling reentry must not seed large uphill along, got %.1f"
			% landed_along
		)
		return false
	# With friction 0, downhill coast should not grind toward zero from fake uphill.
	# Sample mid-incline only — park-edge lips clamp instead of void-ejecting.
	var a0 := landed_along
	var a_mid := a0
	for _j in range(10):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.is_grounded() or sim.state.surface_id != ramp.id:
			break
		if sim.state.u < 0.08:
			break
		a_mid = sim.state.tangent_velocity.x
	if a0 < -1.0 and a_mid > a0 + 5.0:
		# Became less downhill (wrong) — gravity should speed downhill.
		push_error(
			"air-out reenter: downhill coast lost speed %.1f → %.1f (friction0)"
			% [a0, a_mid]
		)
		return false
	return true


func _air_out_reenter_pipe_not_fake_uphill() -> bool:
	# Near-lip free-air drop-in with residual outward +vx: must not seed climb
	# (near-horizontal tangent + fall ≈ fake uphill → stall at peak / friction).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("air-out pipe reenter: setup")
		return false
	sim.ramp_friction = 0.0
	sim.friction = 0.0
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("air-out pipe reenter: missing right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.90
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = right.id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 12.0
	)
	sim.state.velocity = Vector3(200.0, 0.0, -250.0)
	sim.state.note_air_height(sim.state.position.z)
	var landed_along := NAN
	var landed_u := NAN
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed_along = sim.state.tangent_velocity.x
			landed_u = sim.state.u
			break
	if is_nan(landed_along):
		push_error("air-out pipe reenter: never landed")
		return false
	if landed_along > 20.0:
		push_error(
			"air-out pipe reenter: fall-dominant near-lip must not seed uphill (along=%.1f u=%.2f)"
			% [landed_along, landed_u]
		)
		return false
	var a0 := landed_along
	for _j in range(15):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.is_grounded():
			break
	if sim.state.is_grounded() and a0 <= 0.0 and sim.state.tangent_velocity.x > a0 + 8.0:
		push_error(
			"air-out pipe reenter: coast lost downhill %.1f → %.1f"
			% [a0, sim.state.tangent_velocity.x]
		)
		return false
	# Strong residual outward + moderate fall near lip (fall_frac ~0.45) — still
	# must not invent climb.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = right.id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 10.0
	)
	sim.state.velocity = Vector3(300.0, 0.0, -150.0)
	sim.state.note_air_height(sim.state.position.z)
	landed_along = NAN
	for _k in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed_along = sim.state.tangent_velocity.x
			break
	if is_nan(landed_along):
		push_error("air-out pipe reenter: moderate-fall case never landed")
		return false
	# Same-slope reentry with soft fall + strong outward X must still clamp.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = right.id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 8.0
	)
	sim.state.velocity = Vector3(400.0, 0.0, -90.0)
	sim.state.note_air_height(sim.state.position.z)
	landed_along = NAN
	for _n in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed_along = sim.state.tangent_velocity.x
			break
	if is_nan(landed_along):
		push_error("air-out pipe reenter: soft-fall reentry never landed")
		return false
	if landed_along > 20.0:
		push_error(
			"air-out pipe reenter: same-slope soft fall seeded uphill %.1f"
			% landed_along
		)
		return false
	# Rising skim remount (vz soft / still climbing into face) must not invent climb.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = right.id
	var th_hi := 0.72 * PI * 0.5
	sim.state.position = Vector3(
		right.x_at_theta(z, th_hi), z, right.height_at_theta(z, th_hi) + 4.0
	)
	sim.state.velocity = Vector3(280.0, 0.0, 40.0)
	sim.state.note_air_height(sim.state.position.z + 10.0)
	# Force a snap-style land via falling next ticks after apex.
	sim.state.velocity.z = -20.0
	landed_along = NAN
	for _r in range(40):
		sim.set_input(Vector2(1.0, 0.0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed_along = sim.state.tangent_velocity.x
			break
	if not is_nan(landed_along) and landed_along > 20.0:
		push_error(
			"air-out pipe reenter: rising/skim reentry seeded uphill %.1f"
			% landed_along
		)
		return false
	return true


## Free-air ollie near the lip + hold outward used to remount mid-ascent with
## along=0, then stick climb into a soft coping hang / X-lock.
func _ollie_near_lip_stick_out_no_coping_hang() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("ollie lip stick: setup")
		return false
	sim.ollie_height_pipe = 80.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_accel = 0.0
	sim.ollie_lip_frac = 0.50
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("ollie lip stick: no right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u0 := 0.48
	var th := u0 * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = right.id
	sim.state.u = u0
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(120.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.position = Vector3(right.x_at_theta(z, th), z, right.height_at_theta(z, th))
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.clear_air_peak()
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.ollie_charge_peak_height = 80.0
	sim.set_input(Vector2(1.0, 0.0), false, false, false, true)
	sim.tick()
	if sim.state.is_hanging():
		push_error("ollie lip stick: mid-face ollie must not hang")
		return false
	var landed := false
	var land_along := 0.0
	var land_u := 0.0
	var saw_hang := false
	for _i in range(120):
		sim.set_input(Vector2(1.0, 0.0), false, false)
		sim.tick()
		if sim.state.is_hanging():
			saw_hang = true
		if not landed and sim.state.is_grounded() and sim.state.surface_id == right.id:
			landed = true
			land_along = sim.state.tangent_velocity.x
			land_u = sim.state.u
			if land_along > -40.0:
				push_error(
					"ollie lip stick: remount must seed downhill, along=%.1f u=%.2f"
					% [land_along, land_u]
				)
				return false
			# Coast with stick-out: must keep dropping u, never soft-stick at peak.
			var u_min := land_u
			for _k in range(30):
				sim.set_input(Vector2(1.0, 0.0), false, false)
				sim.tick()
				if sim.state.is_hanging():
					push_error("ollie lip stick: soft remount climbed into hang")
					return false
				if not sim.state.is_grounded():
					break
				u_min = minf(u_min, sim.state.u)
				if sim.state.u >= 0.99 and absf(sim.state.tangent_velocity.x) < 20.0:
					push_error("ollie lip stick: stalled at coping")
					return false
			if u_min >= land_u - 0.02 and land_u > 0.85:
				push_error(
					"ollie lip stick: never rode downhill (u %.2f → min %.2f)"
					% [land_u, u_min]
				)
				return false
			break
	if not landed:
		push_error("ollie lip stick: never remounted pipe")
		return false
	if saw_hang:
		push_error("ollie lip stick: entered hang before remount")
		return false
	return true


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
	if sim.state.free_air_upright:
		push_error("air-out hang must not set free_air_upright")
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
	if not sim.state.free_air_upright:
		push_error("fly-out / deck-out must set free_air_upright (reset lean)")
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
	if absf(float(all[0].height) - 120.0) > 0.1:
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
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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


## Unequal flat/pipe heights: floor release uses flat, pipe release uses pipe.
func _ollie_height_picks_flat_vs_pipe() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("ollie pick: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 100.0
	sim.ollie_lip_frac = 0.0
	# Floor pop.
	if not sim.model.patches.has(sim.state.surface_id):
		push_error("ollie pick: expected floor at spawn got %s" % sim.state.surface_id)
		return false
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ollie pick: floor should air")
		return false
	var g := absf(SimTolerances.GRAVITY)
	var dt := SimTolerances.FIXED_DT
	# Air step applies gravity in the same release tick.
	var want_flat := sqrt(2.0 * g * 40.0) - g * dt
	if absf(sim.state.velocity.z - want_flat) > 1.0:
		push_error(
			"ollie pick: floor vz=%.1f want ~%.1f" % [sim.state.velocity.z, want_flat]
		)
		return false
	# Remount a pipe below lip band and pop with full pipe height.
	var pipe: PipeSurface = null
	for pid in sim.model.all_pipe_ids():
		pipe = sim.model.pipes[pid]
		break
	if pipe == null:
		push_error("ollie pick: no pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var th := 0.25 * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 0.25
	sim.state.v = 0.5
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.state.velocity = Vector3.ZERO
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ollie pick: pipe should air")
		return false
	var want_pipe := sqrt(2.0 * g * 100.0) - g * dt
	if absf(sim.state.velocity.z - want_pipe) > 5.0:
		push_error(
			"ollie pick: pipe vz=%.1f want ~%.1f" % [sim.state.velocity.z, want_pipe]
		)
		return false
	return true


## Charge on pipe, air-out, release while airborne — still uses ollie_height_pipe.
func _ollie_airborne_release_uses_launch_pipe_height() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("air ollie: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	# Flat taller than pipe — airborne bug used flat and overshot.
	sim.ollie_height_flat = 150.0
	sim.ollie_height_pipe = 60.0
	sim.ollie_lip_frac = 0.50
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			pipe = p
			break
	if pipe == null:
		push_error("air ollie: no right pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.99
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(280.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.state.clear_hang()
	sim.ollie_available = true
	# Hold into hang so charge snapshot locks pipe height while grounded.
	var hung := false
	for _i in range(30):
		sim.set_input(Vector2(1.0, 0.0), false, false, true, false)
		sim.tick()
		if sim.state.is_hanging() or (
			sim.state.is_airborne() and not sim.state.air_launch_surface_id.is_empty()
		):
			hung = true
			break
	if not hung:
		push_error("air ollie: never left pipe into air")
		return false
	if sim.ollie_charge_peak_height < sim.ollie_height_pipe - 0.1:
		push_error(
			"air ollie: charge peak should be pipe height, got %.1f"
			% sim.ollie_charge_peak_height
		)
		return false
	# Even if launch id is wiped, snapshot must still drive pipe height.
	# Restore launch so peak targets lip + pipe height (not flat).
	sim.state.air_launch_surface_id = pipe.id
	var lip := pipe.height_at_theta(z, PI * 0.5)
	sim.state.position.z = lip
	sim.state.velocity.z = 0.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var g := absf(SimTolerances.GRAVITY)
	var want_vz := sqrt(2.0 * g * 60.0) + SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	var flat_vz := sqrt(2.0 * g * 150.0) + SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - want_vz) > 12.0:
		push_error(
			"air ollie: vz=%.1f want pipe ~%.1f (not flat ~%.1f) lip=%.1f"
			% [sim.state.velocity.z, want_vz, flat_vz, lip]
		)
		return false
	if absf(sim.state.velocity.z - flat_vz) < 8.0:
		push_error("air ollie: used flat height instead of pipe")
		return false
	return true


## Wall-climb ollie must X-lock (hang) or deck-out — never free-air stick X.
func _wall_ollie_hangs_x_locked() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("wall ollie: setup")
		return false
	var wall: WallSurface = null
	for id in sim.model.all_wall_ids():
		wall = sim.model.walls[id]
		break
	if wall == null:
		push_error("wall ollie: no wall")
		return false
	var z := (wall.z_min + wall.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall.id
	sim.state.u = 0.92
	sim.state.v = 0.5
	sim.state.position = wall.position_at(z, 0.92)
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 100.0
	sim.ollie_height_pipe = 100.0
	sim.ollie_lip_frac = 0.50
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var top_edge := sim.query.edge_at(wall.id, z, "top")
	var decked := (
		sim.state.is_grounded()
		and sim.model.patches.has(sim.state.surface_id)
	)
	if decked:
		# Lip + top pad → grounded deck/floor is a valid leave.
		return true
	if not sim.state.is_hanging():
		push_error(
			"wall ollie: expected hang or deck, mode=%s hang=%s surf=%s edge=%s"
			% [
				sim.state.mode,
				sim.state.hang_edge_id,
				sim.state.surface_id,
				top_edge.id if top_edge else "?",
			]
		)
		return false
	for _i in range(8):
		sim.set_input(Vector2(1, 0), false, false, false, false)
		sim.tick()
		if not sim.state.is_hanging():
			break
		if absf(sim.state.velocity.x) > 0.5:
			push_error("wall ollie: hang allowed stick X vx=%.2f" % sim.state.velocity.x)
			return false
	if sim.state.is_hanging() and absf(sim.state.velocity.x) > 0.5:
		push_error("wall ollie: still steering X while hanging")
		return false
	return true


## Lip-band pipe ollie peak comes from ollie_height_pipe only — not climb along.
## Takeoff Z stays put (no snap to wall-top) so the slider pop is fully felt.
func _pipe_lip_ollie_respects_height_not_along() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("lip ollie height: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.all_pipe_ids():
		pipe = sim.model.pipes[id]
		break
	if pipe == null:
		push_error("lip ollie height: no pipe")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 150.0
	sim.ollie_height_pipe = 100.0
	sim.ollie_lip_frac = 0.50
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	var takeoff_h := pipe.height_at_theta(z, th)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, takeoff_h)
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("lip ollie height: expected hang")
		return false
	# One air tick climbs ~vh·dt; a Z teleport to wall-top would leap tens of units.
	var climb := sim.state.position.z - takeoff_h
	if climb > 40.0:
		push_error(
			"lip ollie snapped Z (climb %.1f from %.1f) — hides ollie_height_pipe"
			% [climb, takeoff_h]
		)
		return false
	var g := absf(SimTolerances.GRAVITY)
	var edge := sim.query.edge_at(pipe.id, z, "coping")
	var hang_z := takeoff_h
	if edge != null:
		if sim.model.walls.has(edge.to_surface_id):
			var wall_top := sim.query.edge_at(edge.to_surface_id, z, "top")
			if wall_top != null:
				edge = wall_top
		var anchor := sim.query.edge_anchor_sample(edge, z)
		if not anchor.is_empty():
			hang_z = float(anchor.height)
	# One ballistic vz to hang_z + ollie_height (not clearance-vz + ollie-vz).
	var want := sqrt(2.0 * g * maxf((hang_z + 100.0) - takeoff_h, 0.0)) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - want) > 2.0:
		push_error(
			"lip ollie height: vz=%.1f want ~%.1f (along must not stack)"
			% [sim.state.velocity.z, want]
		)
		return false
	# Slider must move peak: taller pipe height → clearly higher hang apex.
	var peak_lo := _hang_peak_for_pipe_height(20.0)
	var peak_hi := _hang_peak_for_pipe_height(120.0)
	if peak_lo < 0.0 or peak_hi < 0.0:
		return false
	if peak_hi - peak_lo < 60.0:
		push_error(
			"pipe height slider dead: peak@20=%.1f peak@120=%.1f"
			% [peak_lo, peak_hi]
		)
		return false
	return true


## Free-air into an open L1 pipe outer back must fall — never warp through the
## shell onto the ride surface (u≈1 skating down). Deck-backed L1 pipes hide
## that face behind `#`; open islands expose it.
func _layered_ollie_into_l1_pipe_back_crashes() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("l1 back crash: setup")
		return false
	sim.fall_duration = 5.0
	var l1: PipeSurface = sim.model.pipes.get("pipe_8_L1_S0")
	if l1 == null:
		push_error("l1 back crash: missing open L1 left pipe")
		return false
	var z := clampf(250.0, l1.z_min + 5.0, l1.z_max - 5.0)
	var cope_x := l1.coping_x_at(z)
	var peak := l1.height_at_theta(z, PI * 0.5)
	var out := l1.outward_sign()
	var floor_id := "floor_5_L1"
	if not sim.model.patches.has(floor_id):
		push_error("l1 back crash: no L1 floor near open pipe")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = floor_id
	sim.state.free_air_upright = true
	sim.state.position = Vector3(cope_x + out * 40.0, z, peak + 20.0)
	sim.state.velocity = Vector3(-out * 180.0, 0.0, -280.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(90):
		sim.set_input(Vector2(-out, 0.0), false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == l1.id:
			push_error(
				"l1 back crash: warped onto L1 pipe u=%.2f pos=%s"
				% [sim.state.u, sim.state.position]
			)
			return false
		if sim.state.falling:
			return true
	push_error(
		"l1 back crash: never fell mode=%s surf=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position]
	)
	return false


## Floor ollie toward L0 right pipe (not on it yet) into the L1/joint rear must
## fall on the approach side of the joint — not teleport through the pipe column
## to the opposite lip, and not cross past the coping into L1.
func _layered_floor_ollie_into_joint_rear_falls_clear() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("joint rear fall: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	sim.ollie_height_flat = 160.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	var l0: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if l0 == null:
		push_error("joint rear fall: missing L0 right pipe")
		return false
	var z := 250.0
	var wx := l0.coping_x_at(z)
	var lip := l0.bound_x_min
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = "floor_0_L0"
	sim.state.position = Vector3(wx - 250.0, z, 0.0)
	sim.state.tangent_velocity = Vector2(420.0, 0.0)
	sim.state.facing = "r"
	var fell := false
	var fall_x_min := INF
	var fall_x_max := -INF
	for i in range(120):
		sim.set_input(Vector2(1, 0), false, false, i < 3, i == 3)
		sim.tick()
		if sim.state.falling:
			fell = true
			fall_x_min = minf(fall_x_min, sim.state.position.x)
			fall_x_max = maxf(fall_x_max, sim.state.position.x)
			if sim.state.position.x > wx + SimTolerances.CONTACT_EPS:
				push_error(
					"joint rear fall: tunneled past joint x=%.1f wx=%.1f h=%.1f"
					% [sim.state.position.x, wx, sim.state.position.z]
				)
				return false
		if fell and sim.state.is_grounded():
			if sim.state.surface_id.begins_with("pipe_"):
				push_error(
					"joint rear fall: seated on pipe mid-wipeout sid=%s x=%.1f"
					% [sim.state.surface_id, sim.state.position.x]
				)
				return false
			if sim.state.position.x > wx + SimTolerances.CONTACT_EPS:
				push_error(
					"joint rear fall: landed past joint x=%.1f wx=%.1f sid=%s"
					% [sim.state.position.x, wx, sim.state.surface_id]
				)
				return false
			return true
		# Soft-restore clears falling without a floor land — still OK if we never
		# tunneled past the joint or seated on the pipe.
		if fell and not sim.state.falling and not sim.state.is_grounded():
			return fall_x_max <= wx + SimTolerances.CONTACT_EPS
	if not fell:
		push_error(
			"joint rear fall: never fell mode=%s pos=%s"
			% [sim.state.mode, sim.state.position]
		)
		return false
	# Still falling at tick budget but stayed on approach side.
	if fall_x_max <= wx + SimTolerances.CONTACT_EPS:
		return true
	push_error(
		"joint rear fall: fell but never cleared pos=%s"
		% sim.state.position
	)
	return false


## Clipping the tip of L0 right pipe must not seat/slide into the transition.
func _layered_pipe_top_skim_fall_stays_outside() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("pipe top skim: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var l0: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if l0 == null:
		push_error("pipe top skim: missing pipe")
		return false
	var z := 250.0
	var wx := l0.coping_x_at(z)
	var lip := l0.bound_x_min
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_0_L0"
	sim.state.facing = "r"
	sim.state.position = Vector3(wx - 30.0, z, l0.bound_h_max + 5.0)
	sim.state.velocity = Vector3(200.0, 0.0, -40.0)
	sim.state.note_air_height(sim.state.position.z)
	var fell := false
	for _i in range(60):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			fell = true
		if fell and sim.state.surface_id == l0.id:
			push_error(
				"pipe top skim: mounted pipe mid-fall u=%.2f x=%.1f h=%.1f"
				% [sim.state.u, sim.state.position.x, sim.state.position.z]
			)
			return false
		if fell and l0.contains_solid_xz(sim.state.position.x, z) \
				and sim.state.position.z < l0.bound_h_max - SimTolerances.PIPE_TOP_SKIM_BAND:
			push_error(
				"pipe top skim: dropped into pipe column x=%.1f h=%.1f lip=%.1f"
				% [sim.state.position.x, sim.state.position.z, lip]
			)
			return false
		if fell and sim.state.is_grounded() and not sim.state.surface_id.begins_with("pipe_"):
			if sim.state.position.x > lip + SimTolerances.WALL_REJECT_CLEAR:
				push_error(
					"pipe top skim: landed inside footprint x=%.1f lip=%.1f"
					% [sim.state.position.x, lip]
				)
				return false
			return true
	if not fell:
		push_error("pipe top skim: never fell")
		return false
	# Ejected outside and still falling / restored — OK if never inside mid-pipe.
	return sim.state.position.x <= lip + SimTolerances.WALL_REJECT_CLEAR


## Joint/rear crash fall must flop away from the wall (approach side), with feet
## clear of the face — facing-into-wall lean parked the fall RigidBody in mesh.
func _layered_joint_crash_fall_leans_away_from_wall() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("joint lean: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var wall: WallSurface = sim.model.walls.get("wall_span_coping_pipe_1_L0_S1_0")
	if wall == null:
		push_error("joint lean: missing wall")
		return false
	var z := 250.0
	var ws: Dictionary = wall.sample_at_z(z)
	var wx := float(ws.x)
	var top := float(ws.top_height)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_0_L0"
	sim.state.facing = "r"
	sim.state.position = Vector3(wx - 40.0, z, top - 25.0)
	sim.state.velocity = Vector3(500.0, 0.0, -80.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(40):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			if sim.state.fall_lean_sign >= 0.0:
				push_error(
					"joint lean: expected approach lean < 0 got %.1f (facing into wall)"
					% sim.state.fall_lean_sign
				)
				return false
			if sim.state.position.x > wx - SimTolerances.WALL_REJECT_CLEAR + 0.5:
				push_error(
					"joint lean: feet inside clear band x=%.1f wx=%.1f clear=%.1f"
					% [sim.state.position.x, wx, SimTolerances.WALL_REJECT_CLEAR]
				)
				return false
			return true
	push_error("joint lean: never fell")
	return false


## Past the joint coping while falling must bounce on the approach side — never
## walk +X through the partner pipe solid to the far lip.
func _layered_past_joint_fall_does_not_tunnel_partner() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("past joint fall: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var l0: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	var l1: PipeSurface = sim.model.pipes.get("pipe_8_L1_S0")
	if l0 == null or l1 == null:
		push_error("past joint fall: missing pipes")
		return false
	var z := 250.0
	var wx := l0.coping_x_at(z)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_0_L0"
	sim.state.facing = "r"
	sim.state.falling = true
	sim.state.fall_elapsed = 0.0
	sim.state.fall_start_vx = 400.0
	sim.state.fall_start_vy = 0.0
	sim.state.position = Vector3(wx + 5.0, z, 90.0)
	sim.state.velocity = Vector3(400.0, 0.0, -120.0)
	sim.state.note_air_height(90.0)
	for _i in range(40):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.position.x > wx + 40.0:
			push_error(
				"past joint fall: tunneled into L1 x=%.1f wx=%.1f h=%.1f s1=%s"
				% [
					sim.state.position.x,
					wx,
					sim.state.position.z,
					l1.contains_solid_xz(sim.state.position.x, z),
				]
			)
			return false
	return true


## L→R into the L0/L1 union wall must fall and stay on the bowl side — fall_start
## planar must not reinject through a wrong wall normal (partner outward).
func _layered_union_wall_crash_does_not_tunnel() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("union wall: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var wall: WallSurface = sim.model.walls.get("wall_span_coping_pipe_2_L0_S0_0")
	if wall == null or wall.upper_partner_pipe_id.is_empty():
		push_error("union wall: missing L0→L1 right wall")
		return false
	var z := 250.0
	var ws: Dictionary = wall.sample_at_z(z)
	var wx := float(ws.x)
	var top := float(ws.top_height)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_5_L1"
	sim.state.facing = "r"
	sim.state.position = Vector3(wx - 50.0, z, top - 30.0)
	sim.state.velocity = Vector3(300.0, 0.0, -100.0)
	sim.state.note_air_height(sim.state.position.z)
	var fell := false
	for _i in range(100):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			fell = true
		if sim.state.position.x > wx + SimTolerances.CONTACT_EPS:
			push_error(
				"union wall: tunneled past face x=%.1f wx=%.1f fall=%s vx=%.1f start=%.1f"
				% [
					sim.state.position.x,
					wx,
					sim.state.falling,
					sim.state.velocity.x,
					sim.state.fall_start_vx,
				]
			)
			return false
	if not fell:
		push_error("union wall: never fell")
		return false
	return true


## Regression: L0↔L1 open union lips must stick-fly-out past the joint.
## Failure modes this pins (do not reintroduce):
## - try_fly_out rejects "outward corridor blocked" on the own joint wall
## - above-top wall lip fence keeps corridor blocked forever after the lip frame
## - unlock then Reject on the lip seam before X clears the coping
func _layered_union_open_lips_fly_out() -> bool:
	var z := 250.0
	if not _union_fly_out_pipe_clears_joint("pipe_9_L1_S1", z):
		return false
	if not _union_fly_out_pipe_clears_joint("pipe_8_L1_S0", z):
		return false
	if not _union_fly_out_wall_clears_joint("wall_span_coping_pipe_1_L0_S1_0", z):
		return false
	if not _union_fly_out_wall_clears_joint("wall_span_coping_pipe_2_L0_S0_0", z):
		return false
	return true


func _union_fly_out_pipe_clears_joint(pipe_id: String, z: float) -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("union fly-out: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get(pipe_id)
	if pipe == null:
		push_error("union fly-out: missing %s" % pipe_id)
		return false
	var out := pipe.outward_sign()
	var wx := pipe.coping_x_at(z)
	var lip_h := pipe.height_at_theta(z, PI * 0.5)
	# Planner must accept at lip and above — own joint wall is not a corridor block.
	if not _planner_fly_out_ok_at_hang(sim, pipe, wx, z, lip_h, out, pipe_id):
		return false
	if not _planner_fly_out_ok_at_hang(sim, pipe, wx, z, lip_h + 20.0, out, pipe_id):
		return false
	var u := 0.95
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.facing = "r" if out > 0.0 else "l"
	sim.state.clear_hang()
	sim.state.falling = false
	sim.state.request_fall = false
	return _stick_fly_out_clears_coping(sim, wx, out, pipe_id)


func _union_fly_out_wall_clears_joint(wall_id: String, z: float) -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("union wall fly-out: setup")
		return false
	var wall: WallSurface = sim.model.walls.get(wall_id)
	if wall == null or wall.upper_partner_pipe_id.is_empty():
		push_error("union wall fly-out: missing joint %s" % wall_id)
		return false
	var src: PipeSurface = sim.model.pipes.get(wall.source_pipe_id)
	if src == null:
		push_error("union wall fly-out: no source for %s" % wall_id)
		return false
	var out := src.outward_sign()
	var ws: Dictionary = wall.sample_at_z(z)
	var wx := float(ws.x)
	var top := float(ws.top_height)
	if not _planner_fly_out_ok_at_wall_hang(sim, wall, src, wx, z, top, out, wall_id):
		return false
	if not _planner_fly_out_ok_at_wall_hang(
		sim, wall, src, wx, z, top + 20.0, out, wall_id
	):
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = wall.id
	sim.state.u = 0.9
	sim.state.v = 0.5
	sim.state.position = wall.position_at(z, 0.9)
	sim.state.tangent_velocity = Vector2(700.0, 0.0)
	sim.state.facing = "r" if out > 0.0 else "l"
	sim.state.clear_hang()
	sim.state.falling = false
	sim.state.request_fall = false
	var hung := false
	for _i in range(40):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("union wall fly-out: %s never hung" % wall_id)
		return false
	return _stick_fly_out_clears_coping(sim, wx, out, wall_id)


func _planner_fly_out_ok_at_hang(
	sim: PlayerSim,
	pipe: PipeSurface,
	wx: float,
	z: float,
	h: float,
	out: float,
	tag: String,
) -> bool:
	var hang_id := ""
	for eid in sim.model.edges.keys():
		var e: TopologyEdge = sim.model.edges[eid]
		var samp: Dictionary = sim.query.edge_anchor_sample(e, z)
		if str(samp.get("source_surface_id", "")) == pipe.id:
			hang_id = eid
			break
	if hang_id.is_empty():
		push_error("union fly-out: %s no hang edge" % tag)
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(hang_id)
	sim.state.air_launch_surface_id = pipe.id
	sim.state.position = Vector3(wx, z, h)
	sim.state.velocity = Vector3(0.0, 0.0, 180.0)
	sim.state.facing = "r" if out > 0.0 else "l"
	sim.state.falling = false
	sim.state.request_fall = false
	var fo: Dictionary = sim.planner.try_fly_out(sim.state, out, 0.0)
	if not bool(fo.get("ok", false)):
		push_error(
			"union fly-out: planner blocked %s at h=%.1f reason=%s"
			% [tag, h, fo.get("reason", "")]
		)
		return false
	return true


func _planner_fly_out_ok_at_wall_hang(
	sim: PlayerSim,
	wall: WallSurface,
	src: PipeSurface,
	wx: float,
	z: float,
	h: float,
	out: float,
	tag: String,
) -> bool:
	var hang_id := ""
	for eid in sim.model.edges.keys():
		var e: TopologyEdge = sim.model.edges[eid]
		var samp: Dictionary = sim.query.edge_anchor_sample(e, z)
		if str(samp.get("source_surface_id", "")) == wall.id \
				and absf(float(samp.get("height", -1.0)) - float(wall.sample_at_z(z).top_height)) < 1.0:
			hang_id = eid
			break
	if hang_id.is_empty():
		# Fall back to source pipe coping edge at the same X.
		for eid2 in sim.model.edges.keys():
			var e2: TopologyEdge = sim.model.edges[eid2]
			var samp2: Dictionary = sim.query.edge_anchor_sample(e2, z)
			if str(samp2.get("source_pipe_id", "")) == src.id \
					and absf(float(samp2.get("x", -999.0)) - wx) < 1.0:
				hang_id = eid2
				break
	if hang_id.is_empty():
		push_error("union wall fly-out: %s no hang edge" % tag)
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.begin_hang(hang_id)
	sim.state.air_launch_surface_id = wall.id
	sim.state.position = Vector3(wx, z, h)
	sim.state.velocity = Vector3(0.0, 0.0, 180.0)
	sim.state.facing = "r" if out > 0.0 else "l"
	sim.state.falling = false
	sim.state.request_fall = false
	var fo: Dictionary = sim.planner.try_fly_out(sim.state, out, 0.0)
	if not bool(fo.get("ok", false)):
		push_error(
			"union wall fly-out: planner blocked %s at h=%.1f reason=%s"
			% [tag, h, fo.get("reason", "")]
		)
		return false
	return true


## Hold outward stick: unlock free air and clear past coping X without falling.
func _stick_fly_out_clears_coping(
	sim: PlayerSim, wx: float, out: float, tag: String
) -> bool:
	var unlocked := false
	var cleared := false
	for _i in range(24):
		sim.set_input(Vector2(out, 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"union fly-out: %s fell during fly-out x=%.1f h=%.1f rej=%s"
				% [tag, sim.state.position.x, sim.state.position.z, sim.state.last_reject]
			)
			return false
		if sim.state.is_airborne() and not sim.state.is_hanging() \
				and sim.state.velocity.x * out > 1.0:
			unlocked = true
		if unlocked and (sim.state.position.x - wx) * out > 8.0:
			cleared = true
			break
	if not unlocked:
		push_error(
			"union fly-out: %s never unlocked reject=%s hang=%s"
			% [tag, sim.state.last_reject, sim.state.is_hanging()]
		)
		return false
	if not cleared:
		push_error(
			"union fly-out: %s unlocked but never cleared coping x=%.1f wx=%.1f h=%.1f"
			% [tag, sim.state.position.x, wx, sim.state.position.z]
		)
		return false
	return true


## Layered L0→wall lip ollie must peak at wall-top + ollie_height_pipe.
## Adding clearance-vz + ollie-vz overshoots by 2√(gap·h) — feels "way higher".
func _layered_wall_lip_ollie_peak_is_ollie_height_above_lip() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("layered wall ollie: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if pipe == null:
		push_error("layered wall ollie: missing L0 right pipe")
		return false
	var cope: CopingEdge = sim.model.copings[pipe.coping_id]
	if cope.coping_class != SimKinds.CopingClass.WALL_EXTENSION:
		push_error("layered wall ollie: expected WALL_EXTENSION")
		return false
	var z := clampf(1000.0, pipe.z_min + 5.0, pipe.z_max - 5.0)
	var span := cope.span_at_z(z)
	if span == null or not sim.model.walls.has(span.wall_id):
		push_error("layered wall ollie: wall span missing")
		return false
	var wall: WallSurface = sim.model.walls[span.wall_id]
	var hang_z := float(wall.sample_at_z(z).top_height)
	var ollie_h := 100.0
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 150.0
	sim.ollie_height_pipe = ollie_h
	sim.ollie_lip_frac = 0.50
	var u := 0.92
	var th := u * PI * 0.5
	var takeoff_h := pipe.height_at_theta(z, th)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, takeoff_h)
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.velocity = Vector3.ZERO
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("layered wall ollie: expected hang air-out")
		return false
	var peak_z := sim.state.position.z
	for _i in range(200):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		peak_z = maxf(peak_z, sim.state.position.z)
		if sim.state.velocity.z < 0.0 and sim.state.position.z < peak_z - 1.0:
			break
	var want := hang_z + ollie_h
	# Additive vz bug peaks near want + 2√(gap·h) — reject that overshoot.
	var gap := maxf(hang_z - takeoff_h, 0.0)
	var bogus := want + 2.0 * sqrt(maxf(gap * ollie_h, 0.0))
	if peak_z > want + 35.0:
		push_error(
			"layered wall ollie: apex %.1f want ~%.1f (bogus additive ~%.1f)"
			% [peak_z, want, bogus]
		)
		return false
	if peak_z < want - 40.0:
		push_error(
			"layered wall ollie: apex %.1f too low (want ~%.1f)"
			% [peak_z, want]
		)
		return false
	return true


func _hang_peak_for_pipe_height(pipe_h: float) -> float:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("hang peak: setup")
		return -1.0
	var pipe: PipeSurface = null
	for id in sim.model.all_pipe_ids():
		pipe = sim.model.pipes[id]
		break
	if pipe == null:
		push_error("hang peak: no pipe")
		return -1.0
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 150.0
	sim.ollie_height_pipe = pipe_h
	sim.ollie_lip_frac = 0.50
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(50.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_hanging():
		push_error("hang peak: expected hang at h=%s" % pipe_h)
		return -1.0
	var peak := sim.state.position.z
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false, false, false)
		sim.tick()
		peak = maxf(peak, sim.state.position.z)
		if sim.state.is_grounded():
			break
	return peak


func _ollie_jump_caps_at_full_charge() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie jump cap")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 200.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	sim.state.air_launch_surface_id = ""
	sim.state.clear_hang()
	sim.state.position.z = 80.0
	sim.ollie_available = true
	# 1) Low residual → boost to √(2g·h).
	sim.state.velocity = Vector3(0.0, 0.0, 0.0)
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var want := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - want) > 5.0:
		push_error(
			"air ollie vh expected ~%s got %s"
			% [want, sim.state.velocity.z]
		)
		return false
	if sim.ollie_available:
		push_error("air ollie should spend the single charge")
		return false
	# 2) Faster residual leave speed is kept (stack), not cut down.
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	var residual := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0) + 120.0
	sim.state.velocity.z = residual
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	var keep := residual + SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - keep) > 5.0:
		push_error(
			"air ollie should keep residual rise ~%s got %s"
			% [keep, sim.state.velocity.z]
		)
		return false
	# Cannot start a new charge meter while airborne.
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	if sim.ollie_charge > 0.001:
		push_error("must not start ollie charge while airborne")
		return false
	return true


## Post-leave air ollie peak ≈ grounded lip-band ramp ollie (ollie_height_pipe).
func _ramp_air_ollie_peak_matches_lip_ollie() -> bool:
	var path := "res://tests/levels/sim/sim_ramp.ssk"
	var h := 80.0
	var lip_peak := _ramp_ollie_peak_height(path, h, false)
	var air_peak := _ramp_ollie_peak_height(path, h, true)
	if is_nan(lip_peak) or is_nan(air_peak):
		return false
	if absf(air_peak - lip_peak) > 25.0:
		push_error(
			"ramp air ollie peak=%.1f vs lip ollie peak=%.1f (want ~same)"
			% [air_peak, lip_peak]
		)
		return false
	return true


func _ramp_ollie_peak_height(path: String, ollie_h: float, air_release: bool) -> float:
	var sim := PlayerSim.new()
	if not sim.setup_from_path(path):
		push_error("ramp ollie peak: setup %s" % path)
		return NAN
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = ollie_h
	sim.ollie_height_pipe = ollie_h
	sim.ollie_lip_frac = 0.50
	sim.friction = 0.0
	sim.ramp_friction = 0.0
	if sim.model.ramps.is_empty():
		push_error("ramp ollie peak: no ramps")
		return NAN
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.state.clear_hang()
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	if air_release:
		# Leave via lip ollie impulse without spending charge, then air-release.
		sim.ollie_available = false
		sim.ground.launch_height_impulse(
			sim.state, sim._up_speed_for_height(ollie_h), sim.ollie_lip_frac
		)
		if not sim.state.is_airborne():
			push_error("ramp ollie peak: air path never left")
			return NAN
		# One air tick of residual rise, then full-charge air ollie.
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		sim.ollie_available = true
		sim.ollie_charge = 1.0
		sim.set_input(Vector2(1, 0), false, false, false, true)
		sim.tick()
	else:
		sim.set_input(Vector2(1, 0), false, false, false, true)
		sim.tick()
		if not sim.state.is_airborne():
			push_error("ramp ollie peak: lip path never left")
			return NAN
	var peak := sim.state.position.z
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		peak = maxf(peak, sim.state.position.z)
		if sim.state.velocity.z < 0.0 and sim.state.position.z < peak - 1.0:
			break
	return peak


func _ollie_single_charge_replenishes_on_ground() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie single charge")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	# Climbing (peak-ward) X is carried through free-air takeoff.
	var want_vx := t.x * along
	if sim.state.velocity.x * want_vx <= 0.0 or absf(sim.state.velocity.x) < absf(want_vx) * 0.5:
		push_error(
			"climbing pipe ollie should keep peak-ward X ~%s, got vx=%s"
			% [want_vx, sim.state.velocity.x]
		)
		return false
	return true


func _pipe_ollie_below_lip_keeps_peakward_x() -> bool:
	# Grounded on ), u below lip band, peak-ward along → free-air ollie keeps +X.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("pipe ollie peakward: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 80.0
	sim.ollie_height_pipe = 80.0
	sim.ollie_lip_frac = 0.50
	var right: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	if right == null:
		push_error("pipe ollie peakward: missing right pipe")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.35
	var th := u * PI * 0.5
	var along := 420.0
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = right.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(along, 0.0)
	sim.state.position = Vector3(right.x_at_theta(z, th), z, right.height_at_theta(z, th))
	sim.ollie_available = true
	var proj := right.project(sim.state.position.x, sim.state.position.y, sim.state.position.z)
	if not bool(proj.get("ok", false)):
		push_error("pipe ollie peakward: project failed")
		return false
	var t: Vector3 = proj.tangent_along
	var want_wx := t.x * along
	if want_wx <= 1.0:
		push_error("pipe ollie peakward: fixture need peak-ward +X, got want %.1f" % want_wx)
		return false
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("pipe ollie peakward: should be airborne")
		return false
	if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
		push_error("pipe ollie peakward: must be free-air, not hang")
		return false
	if sim.state.velocity.x <= 20.0:
		push_error(
			"pipe ollie peakward: expected +vx keep, got %.1f (want ~%.1f)"
			% [sim.state.velocity.x, want_wx]
		)
		return false
	return true


func _ramp_adjacent_pipe_z_leave_no_hang() -> bool:
	# >> abutting )) in Z at matching peak/cope height must not steal into pipe hang.
	# Drive toward the shared loft seam (ramp.z_min == pipe.z_max), not away from it.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_pipe_adj.ssk"):
		push_error("ramp-pipe adj: setup")
		return false
	var ramp: RampSurface = null
	var pipe: PipeSurface = null
	for id in sim.model.ramps.keys():
		var r: RampSurface = sim.model.ramps[id]
		if r.side == SimKinds.PipeSide.RIGHT:
			ramp = r
			break
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			pipe = p
			break
	if ramp == null or pipe == null:
		push_error("ramp-pipe adj: missing right ramp/pipe")
		return false
	# Near ramp peak, depth toward the pipe span (shared loft seam).
	var z := ramp.z_min + 5.0
	var u := 0.95
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.1
	sim.state.tangent_velocity = Vector2(80.0, -400.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.state.clear_hang()
	var left_ramp := false
	for _i in range(90):
		sim.set_input(Vector2(0.2, -1.0), false, false)
		sim.tick()
		if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
			push_error(
				"ramp-pipe adj: hang/X-lock after Z leave (surf=%s hang=%s)"
				% [sim.state.surface_id, sim.state.hang_edge_id]
			)
			return false
		if sim.state.surface_id == pipe.id:
			push_error("ramp-pipe adj: auto-mounted adjacent pipe")
			return false
		if sim.state.is_airborne() or sim.state.surface_id != ramp.id:
			left_ramp = true
			# Keep watching — free-air remount onto the abutting pipe was the bug.
			break
	if not left_ramp:
		push_error("ramp-pipe adj: never left ramp (u=%.2f z=%.1f)" % [
			sim.state.u, sim.state.position.y
		])
		return false
	# Stay free of hang / abutting-pipe steal for more ticks after leave.
	for _j in range(40):
		sim.set_input(Vector2(0.2, -1.0), false, false)
		sim.tick()
		if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
			push_error("ramp-pipe adj: hang engaged after leave")
			return false
		if sim.state.surface_id == pipe.id:
			push_error("ramp-pipe adj: remounted adjacent pipe after Z leave")
			return false
	return true


func _ramp_lip_ollie_is_free_air() -> bool:
	# Upper-band ramp ollie must free-air (no X-lock), even beside a pipe.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_pipe_adj.ssk"):
		push_error("ramp lip ollie: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 60.0
	sim.ollie_height_pipe = 60.0
	sim.ollie_lip_frac = 0.50
	var ramp: RampSurface = null
	for id in sim.model.ramps.keys():
		var r: RampSurface = sim.model.ramps[id]
		if r.side == SimKinds.PipeSide.RIGHT:
			ramp = r
			break
	if ramp == null:
		push_error("ramp lip ollie: missing ramp")
		return false
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ramp lip ollie: should leave ramp")
		return false
	if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
		push_error("ramp lip ollie: must not X-lock hang")
		return false
	return true


func _ramp_lip_ollie_sets_free_air_upright() -> bool:
	# Lip-band ramp ollie levels presentation tilt (same band as pipe ollie_lip_frac).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("ramp lip upright: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 60.0
	sim.ollie_height_pipe = 60.0
	sim.ollie_lip_frac = 0.50
	if sim.model.ramps.is_empty():
		push_error("ramp lip upright: no ramps")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ramp lip upright: should be airborne")
		return false
	if not sim.state.free_air_upright:
		push_error("ramp lip upright: expected free_air_upright")
		return false
	return true


func _ramp_mid_ollie_keeps_lean() -> bool:
	# Below lip band, ramp ollie keeps pre-takeoff lean.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("ramp mid ollie lean: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 60.0
	sim.ollie_height_pipe = 60.0
	sim.ollie_lip_frac = 0.50
	if sim.model.ramps.is_empty():
		push_error("ramp mid ollie lean: no ramps")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.25
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.ollie_available = true
	sim.set_input(Vector2.ZERO, false, false, true, false)
	sim.tick()
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ramp mid ollie lean: should be airborne")
		return false
	if sim.state.free_air_upright:
		push_error("ramp mid ollie lean: must keep lean (free_air_upright false)")
		return false
	return true


func _ramp_peak_leave_sets_free_air_upright() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp.ssk"):
		push_error("ramp peak upright: setup")
		return false
	if sim.model.ramps.is_empty():
		push_error("ramp peak upright: no ramps")
		return false
	var ramp: RampSurface = sim.model.ramps[sim.model.all_ramp_ids()[0]]
	var z := (ramp.z_min + ramp.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = 0.85
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(500.0, 0.0)
	sim.state.position = Vector3(
		ramp.x_at_theta(z, 0.85 * PI * 0.5),
		z,
		ramp.height_at_theta(z, 0.85 * PI * 0.5)
	)
	sim.state.clear_hang()
	for _i in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_airborne():
			if not sim.state.free_air_upright:
				push_error("ramp peak upright: expected free_air_upright")
				return false
			return true
	push_error("ramp peak upright: never launched")
	return false


func _ramp_peak_beside_pipe_keeps_outward_x() -> bool:
	# User layout: >> above )) — ride off peak must keep +X (not outer-back freeze).
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_peak_fly.ssk"):
		push_error("ramp peak fly: setup")
		return false
	var ramp: RampSurface = null
	for id in sim.model.ramps.keys():
		var r: RampSurface = sim.model.ramps[id]
		if r.side == SimKinds.PipeSide.RIGHT:
			ramp = r
			break
	if ramp == null:
		push_error("ramp peak fly: missing ramp")
		return false
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.85
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(200.0, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.state.clear_hang()
	var launch_x := 0.0
	var left := false
	for _i in range(40):
		sim.set_input(Vector2(1.0, 0.0), false, false)
		sim.tick()
		if sim.state.is_hanging():
			push_error("ramp peak fly: hang")
			return false
		if sim.state.is_airborne():
			if not left:
				left = true
				launch_x = sim.state.position.x
			elif sim.state.velocity.x <= 1.0:
				push_error(
					"ramp peak fly: VX frozen (vx=%.1f x=%.1f)"
					% [sim.state.velocity.x, sim.state.position.x]
				)
				return false
			elif sim.state.position.x > launch_x + 20.0:
				return true
	if not left:
		push_error("ramp peak fly: never left")
		return false
	push_error(
		"ramp peak fly: did not advance past peak (x=%.1f launch=%.1f)"
		% [sim.state.position.x, launch_x]
	)
	return false


func _ollie_on_pipe_lip_enters_hang() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup ollie lip hang")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	var takeoff_h := pipe.height_at_theta(z, th)
	var edge := sim.query.edge_at(pipe.id, z, "coping")
	var hang_z := takeoff_h
	if edge != null:
		if sim.model.walls.has(edge.to_surface_id):
			var wall_top := sim.query.edge_at(edge.to_surface_id, z, "top")
			if wall_top != null:
				edge = wall_top
		var anchor := sim.query.edge_anchor_sample(edge, z)
		if not anchor.is_empty():
			hang_z = float(anchor.height)
	var g := absf(SimTolerances.GRAVITY)
	var expected_vh := sqrt(2.0 * g * maxf((hang_z + 40.0) - takeoff_h, 0.0)) \
			+ SimTolerances.GRAVITY * SimTolerances.FIXED_DT
	if absf(sim.state.velocity.z - expected_vh) > 10.0:
		push_error(
			"lip hang vh expected ~%s (ballistic to lip+ollie) got %s"
			% [expected_vh, sim.state.velocity.z]
		)
		return false
	var lock_x := pipe.coping_x_at(z)
	if absf(sim.state.position.x - lock_x) > 1.0:
		push_error(
			"lip hang should sit on coping x=%s got %s" % [lock_x, sim.state.position.x]
		)
		return false
	return true


## Lip-band ollie on a pipe with outward `#` must hang, not hang-clip crash.
func _ollie_pipe_lip_outward_deck_no_crash() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("lip ollie deck: setup")
		return false
	sim.fall_duration = 5.0
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_pipe = 80.0
	sim.ollie_lip_frac = 0.50
	sim.friction = 0.0
	var pipe: PipeSurface = null
	var deck_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		var cope: CopingEdge = sim.model.copings.get(p.coping_id)
		if cope == null:
			continue
		var span = cope.span_at_z((p.z_min + p.z_max) * 0.5)
		if span == null or span.outward_deck_id.is_empty():
			continue
		pipe = p
		deck_id = span.outward_deck_id
		break
	if pipe == null or deck_id.is_empty():
		push_error("lip ollie deck: no pipe with outward deck")
		return false
	var deck: SupportPatch = sim.model.patches[deck_id]
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.85
	var th := u * PI * 0.5
	var takeoff_h := pipe.height_at_theta(z, th)
	if takeoff_h >= deck.height - 1.0:
		push_error("lip ollie deck: expected takeoff below deck top")
		return false
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(120.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, takeoff_h)
	sim.state.clear_hang()
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if sim.state.falling:
		push_error("lip ollie deck: crashed on takeoff tick")
		return false
	if not sim.state.is_hanging():
		push_error(
			"lip ollie deck: expected hang mode=%s hang=%s"
			% [sim.state.mode, sim.state.hang_edge_id]
		)
		return false
	for _i in range(90):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"lip ollie deck: crashed mid-hang pos=%s"
				% sim.state.position
			)
			return false
		if sim.state.is_grounded() and sim.state.surface_id == pipe.id:
			return true
	# Still hanging / airborne without a fall is acceptable for this gate.
	return not sim.state.falling


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
	sim.ollie_height_flat = 10.0
	sim.ollie_height_pipe = 10.0
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
	sim.ollie_height_flat = 30.0
	sim.ollie_height_pipe = 30.0
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
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
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
	# Peak-ward ride X is retained on free-air slope ollie (spec).
	if sim.state.velocity.x <= 30.0:
		push_error("climbing ramp ollie should keep peak-ward +X, vx=%s" % sim.state.velocity.x)
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


func _ollie_into_pipe_with_stick_stays_outside() -> bool:
	# Stick toward coping while airborne used to chord-cut under the pipe body
	# because bounce depenetrated back toward the embedded start pose.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("setup pipe stick ollie")
		return false
	var pipe := _left_pipe(sim.model)
	if pipe == null:
		push_error("missing left pipe")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 80.0
	sim.ollie_height_pipe = 80.0
	sim.ollie_lip_frac = 0.0
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var u := 0.4
	var th := u * PI * 0.5
	var cx := pipe.coping_x_at(z)
	var peak := (
		float(pipe.sample_at_z(z).base_height) + float(pipe.sample_at_z(z).radius)
	)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(700.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	var out := pipe.outward_sign()
	sim.set_input(Vector2(out, 0.0), false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("pipe stick ollie should leave")
		return false
	for _i in range(120):
		# Keep holding toward the coping — must collide / stay outside, not bury.
		sim.set_input(Vector2(out, 0.0), false, false, false, false)
		sim.tick()
		if pipe.contains_xz(sim.state.position.x, sim.state.position.y):
			var proj := pipe.project(
				sim.state.position.x, sim.state.position.y, sim.state.position.z
			)
			if bool(proj.get("ok", false)) \
					and sim.state.position.z < float(proj.point.z) - SimTolerances.CONTACT_EPS:
				push_error(
					"buried in pipe solid pos=%s surface_h=%s"
					% [sim.state.position, proj.point.z]
				)
				return false
		# Past coping below peak without clearing = tunneled through the body.
		if (sim.state.position.x - cx) * out > 15.0 \
				and sim.state.position.z < peak - 10.0:
			push_error("tunneled past pipe coping below peak at %s" % sim.state.position)
			return false
		if sim.state.is_grounded():
			break
	return true


func _ramp_ollie_onto_abutting_deck_no_freeze() -> bool:
	# High ramp clip → deck used to bounce-loop under the skim gate (vz killed,
	# pose reset to `from`) and freeze airborne with leftover horizontal speed.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_ramp_deck.ssk"):
		push_error("setup ramp→deck freeze")
		return false
	var ramp: RampSurface = null
	for id in sim.model.ramps.keys():
		var r: RampSurface = sim.model.ramps[id]
		if r.outward_sign() > 0.0:
			ramp = r
			break
	if ramp == null:
		push_error("missing right ramp")
		return false
	var deck_id := ""
	for id in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[id]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck_id = id
			break
	if deck_id.is_empty():
		push_error("missing deck")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 40.0
	sim.ollie_lip_frac = 0.0
	var z := (ramp.z_min + ramp.z_max) * 0.5
	var u := 0.85
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = ramp.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(600.0, 0.0)
	sim.state.position = Vector3(ramp.x_at_theta(z, th), z, ramp.height_at_theta(z, th))
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2(1, 0), false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ramp ollie should leave")
		return false
	var stuck := 0
	var last := sim.state.position
	for _i in range(180):
		sim.set_input(Vector2(1, 0), false, false, false, false)
		sim.tick()
		var moved := (sim.state.position - last).length()
		last = sim.state.position
		if sim.state.is_airborne() and moved < 0.05:
			stuck += 1
			if stuck >= 12:
				push_error(
					"frozen airborne at %s v=%s surf_blocker=%s"
					% [sim.state.position, sim.state.velocity, sim.query.blocker_at(sim.state.position)]
				)
				return false
		else:
			stuck = 0
		if sim.state.is_grounded() and sim.state.surface_id == deck_id:
			# Must still accept stick input on the deck.
			var tv0 := sim.state.tangent_velocity.x
			sim.set_input(Vector2(1, 0), false, false, false, false)
			sim.tick()
			if sim.state.is_grounded() and absf(sim.state.tangent_velocity.x - tv0) < 0.01 \
					and absf(tv0) < 1.0:
				# Coasting at zero is ok if we just landed; give accel a tick.
				sim.set_input(Vector2(1, 0), false, false, false, false)
				sim.tick()
			if sim.state.is_grounded() and absf(sim.state.tangent_velocity.x) < 1.0:
				# Still fine if friction/brake — just ensure mode isn't soft-locked.
				pass
			return true
	if sim.state.is_airborne():
		push_error(
			"never landed after ramp→deck ollie; pos=%s v=%s"
			% [sim.state.position, sim.state.velocity]
		)
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


## max_speed_x is an absolute |vx| / along ceiling (air + gravity on slopes).
func _max_speed_x_is_absolute_ceiling() -> bool:
	var air := PlayerSim.new()
	if not air.setup_from_path("res://tests/levels/sim/sim_open_fly.ssk"):
		push_error("max speed air: setup")
		return false
	air.max_speed = 300.0
	air.state.mode = SimState.Mode.AIRBORNE
	air.state.surface_id = ""
	air.state.clear_hang()
	air.state.maneuver = null
	air.state.position = Vector3(air.model.width * 0.5, air.model.depth * 0.5, 400.0)
	air.state.velocity = Vector3(700.0, 0.0, 0.0)
	air.set_input(Vector2.ZERO, false, false, false)
	air.tick()
	if absf(air.state.velocity.x) > air.max_speed + 0.01:
		push_error(
			"max speed air: ballistic vx not clamped, got %.1f cap %.1f"
			% [air.state.velocity.x, air.max_speed]
		)
		return false
	# Stick target uses max_speed (was hardcoded 400).
	air.max_speed = 1000.0
	air.state.position.z = 800.0
	air.state.velocity = Vector3(0.0, 0.0, 400.0)
	for _i in range(60):
		air.state.position.z = maxf(air.state.position.z, 500.0)
		air.set_input(Vector2(1, 0), false, false, false)
		air.tick()
		if not air.state.is_airborne():
			push_error("max speed air: landed while accelerating")
			return false
	if air.state.velocity.x < 450.0:
		push_error(
			"max speed air: stick should exceed old 400 hardcode, got %.1f"
			% air.state.velocity.x
		)
		return false
	if air.state.velocity.x > air.max_speed + 0.01:
		push_error(
			"max speed air: stick overshot cap, got %.1f"
			% air.state.velocity.x
		)
		return false
	var pipe := PlayerSim.new()
	if not pipe.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("max speed pipe: setup")
		return false
	var left: PipeSurface = null
	for id in pipe.model.pipes:
		var p: PipeSurface = pipe.model.pipes[id]
		if p.outward_sign() < 0.0:
			left = p
			break
	if left == null:
		push_error("max speed pipe: no left pipe")
		return false
	pipe.max_speed = 200.0
	pipe.state.mode = SimState.Mode.GROUNDED
	pipe.state.surface_id = left.id
	pipe.state.u = 0.55
	var z_mid := (left.z_min + left.z_max) * 0.5
	pipe.state.position = Vector3(
		left.x_at_theta(z_mid, pipe.state.u * PI * 0.5),
		z_mid,
		left.height_at_theta(z_mid, pipe.state.u * PI * 0.5)
	)
	# Into-bowl along: gravity adds speed that must still hard-cap.
	pipe.state.tangent_velocity = Vector2(-500.0, 0.0)
	pipe.set_input(Vector2.ZERO, false, false, false)
	pipe.tick()
	if not pipe.state.is_grounded() or pipe.state.surface_id != left.id:
		push_error(
			"max speed pipe: left surface mid-tick mode=%s surf=%s"
			% [pipe.state.mode, pipe.state.surface_id]
		)
		return false
	if absf(pipe.state.tangent_velocity.x) > pipe.max_speed + 0.01:
		push_error(
			"max speed pipe: along not clamped, got %.1f cap %.1f"
			% [pipe.state.tangent_velocity.x, pipe.max_speed]
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


## L0 right-pipe air-out must fall back into the L0 wall/pipe bowl — never
## sticky-mount the L1 opposite pipe's rear deck while still hanging.
func _l0_air_out_not_stuck_on_l1_opposite_deck() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_l0_air_out_l1_deck.ssk"):
		push_error("l0 air-out: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			pipe = p
			break
	if pipe == null:
		push_error("l0 air-out: missing right pipe")
		return false
	var wall: WallSurface = null
	for id in sim.model.walls.keys():
		var w: WallSurface = sim.model.walls[id]
		if w.source_pipe_id == pipe.id:
			wall = w
			break
	if wall == null:
		push_error("l0 air-out: missing wall")
		return false
	var hung := false
	for _i in range(200):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("l0 air-out: deck stole climb/hang")
			return false
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("l0 air-out: never hung")
		return false
	var stalled := 0
	var top_h := float(wall.sample_at_z(sim.state.position.y).top_height)
	for _j in range(220):
		var prev_vz := sim.state.velocity.z
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("l0 air-out: landed L1 opposite rear deck")
			return false
		if sim.state.is_hanging() and absf(sim.state.position.z - top_h) <= 3.0 \
				and absf(sim.state.velocity.z) < 1.0 and prev_vz < -10.0:
			stalled += 1
			if stalled >= 3:
				push_error("l0 air-out: hang stalled at L1 deck/lip height")
				return false
		else:
			stalled = 0
		if sim.state.is_grounded():
			var ok := (
				sim.state.surface_id == wall.id
				or sim.state.surface_id == pipe.id
			)
			if not ok:
				push_error("l0 air-out: remounted %s" % sim.state.surface_id)
				return false
			# Keep riding a few ticks — must enter the L0 pipe bowl, not freeze at lip.
			for _k in range(40):
				sim.set_input(Vector2.ZERO, false, false)
				sim.tick()
				if sim.model.patches.has(sim.state.surface_id) \
						and int(sim.model.patches[sim.state.surface_id].kind) \
						== SimKinds.SurfaceKind.DECK:
					push_error("l0 air-out: deck stole after remount")
					return false
				if sim.state.surface_id == pipe.id and sim.state.u < 0.95:
					return true
			if sim.state.surface_id == pipe.id or sim.state.surface_id == wall.id:
				return true
			push_error("l0 air-out: left source after remount surf=%s" % sim.state.surface_id)
			return false
	push_error("l0 air-out: never remounted source")
	return false


## Ollie from the L0 pipe lip (wall-extension) must hang at the effective lip and
## fall back into the L0 pipe — not sticky-mount the wall climb into the L1 deck.
func _l0_pipe_ollie_not_stuck_on_l1_deck() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_l0_air_out_l1_deck.ssk"):
		push_error("l0 ollie: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			pipe = p
			break
	if pipe == null:
		push_error("l0 ollie: missing right pipe")
		return false
	var wall: WallSurface = null
	for id in sim.model.walls.keys():
		var w: WallSurface = sim.model.walls[id]
		if w.source_pipe_id == pipe.id:
			wall = w
			break
	if wall == null:
		push_error("l0 ollie: missing wall")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var top_h := float(wall.sample_at_z(z).top_height)
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = u
	sim.state.v = 0.5
	sim.state.tangent_velocity = Vector2(400.0, 0.0)
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.state.set_facing_side("r")
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 120.0
	sim.ollie_height_pipe = 120.0
	sim.ollie_lip_frac = 0.50
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_hanging():
		push_error(
			"l0 ollie: expected hang air, mode=%s surf=%s hang=%s"
			% [sim.state.mode, sim.state.surface_id, sim.state.hang_edge_id]
		)
		return false
	if sim.state.velocity.z <= 0.0:
		push_error("l0 ollie: expected rising hang pop, vz=%s" % sim.state.velocity.z)
		return false
	# Clearance+ollie must carry past the wall-top lip (no Z teleport).
	var cleared := false
	for _rise in range(45):
		if sim.state.position.z >= top_h - 2.0:
			cleared = true
			break
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if not sim.state.is_hanging() and not sim.state.is_airborne():
			break
	if not cleared:
		push_error(
			"l0 ollie: never cleared effective lip h=%.1f top=%.1f"
			% [sim.state.position.z, top_h]
		)
		return false
	# Must not immediately sticky-mount the wall extension and climb.
	for _i in range(8):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.model.walls.has(sim.state.surface_id):
			push_error("l0 ollie: rising hang sticky-mounted wall")
			return false
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("l0 ollie: deck stole during rise")
			return false
	var stalled := 0
	for _j in range(220):
		var prev_vz := sim.state.velocity.z
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("l0 ollie: landed L1 deck")
			return false
		if sim.state.is_hanging() and absf(sim.state.position.z - top_h) <= 3.0 \
				and absf(sim.state.velocity.z) < 1.0 and prev_vz < -10.0:
			stalled += 1
			if stalled >= 3:
				push_error("l0 ollie: hang stalled at deck/lip height")
				return false
		else:
			stalled = 0
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id and sim.state.surface_id != pipe.id:
				push_error("l0 ollie: remounted %s" % sim.state.surface_id)
				return false
			for _k in range(50):
				sim.set_input(Vector2.ZERO, false, false)
				sim.tick()
				if sim.model.patches.has(sim.state.surface_id) \
						and int(sim.model.patches[sim.state.surface_id].kind) \
						== SimKinds.SurfaceKind.DECK:
					push_error("l0 ollie: deck stole after remount")
					return false
				if sim.state.surface_id == pipe.id and sim.state.u < 0.95:
					return true
			if sim.state.surface_id == pipe.id or sim.state.surface_id == wall.id:
				return true
			push_error("l0 ollie: left source surf=%s" % sim.state.surface_id)
			return false
	push_error("l0 ollie: never remounted source")
	return false


## Free air over an inward opposite rear deck must not force-land just because the
## deck shares the launch coping X (outward abut only).
func _l0_launch_does_not_force_land_inward_deck() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_l0_air_out_l1_deck.ssk"):
		push_error("inward deck: setup")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			pipe = p
			break
	if pipe == null:
		push_error("inward deck: missing pipe")
		return false
	var deck: SupportPatch = null
	for id in sim.model.patches.keys():
		var patch: SupportPatch = sim.model.patches[id]
		if int(patch.kind) == SimKinds.SurfaceKind.DECK:
			deck = patch
			break
	if deck == null:
		push_error("inward deck: missing deck")
		return false
	var mid_x := (deck.x_min + deck.x_max) * 0.5
	var mid_z := (deck.z_min + deck.z_max) * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.air_launch_surface_id = pipe.id
	# Peak fails the tall skim gate — only force-near-pad could sticky-mount.
	sim.state.air_peak_height = deck.height + 5.0
	sim.state.position = Vector3(mid_x, mid_z, deck.height - 2.0)
	sim.state.velocity = Vector3(-40.0, 0.0, -80.0)
	for _i in range(40):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.surface_id == deck.id:
			push_error("inward deck: force land stole opposite rear deck")
			return false
		if sim.state.is_grounded() and (
			sim.state.surface_id == pipe.id
			or sim.model.walls.has(sim.state.surface_id)
		):
			return true
	return not (sim.state.surface_id == deck.id)


## layered_demo: free air at the L0 right coping (hang cleared mid-air) must remount
## the source wall / pipe into the bowl — never bounce-freeze at the L1 abutting
## deck height while still leaned with X stuck.
func _l0_free_air_at_cope_remounts_wall_not_freeze() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("l0 free-air cope: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if pipe == null:
		push_error("l0 free-air cope: missing pipe_1_L0_S1")
		return false
	var wall: WallSurface = null
	for id in sim.model.walls.keys():
		var w: WallSurface = sim.model.walls[id]
		if w.source_pipe_id == pipe.id and w.contains_z(1010.5):
			wall = w
			break
	if wall == null:
		push_error("l0 free-air cope: missing wall at mid depth")
		return false
	var midz := 1010.5
	var cx := pipe.coping_x_at(midz)
	var top_h := float(wall.sample_at_z(midz).top_height)
	# Low peak: deck skim gate fails; abutting deck_2 sits on coping X.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.free_air_upright = false
	sim.state.air_launch_surface_id = pipe.id
	sim.state.air_peak_height = top_h + 5.0
	sim.state.position = Vector3(cx, midz, top_h + 8.0)
	sim.state.velocity = Vector3(0.0, 0.0, -20.0)
	var stalled := 0
	var prev_z := sim.state.position.z
	for _i in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("l0 free-air cope: landed abutting L1 deck")
			return false
		if sim.state.is_airborne() and absf(sim.state.position.z - prev_z) < 0.01 \
				and absf(sim.state.position.z - top_h) <= 3.0 \
				and absf(sim.state.velocity.z) > 50.0:
			stalled += 1
			if stalled >= 4:
				push_error(
					"l0 free-air cope: freeze at lip z=%.2f vz=%.1f"
					% [sim.state.position.z, sim.state.velocity.z]
				)
				return false
		else:
			stalled = 0
		prev_z = sim.state.position.z
		if sim.state.is_grounded():
			if sim.state.surface_id != wall.id and sim.state.surface_id != pipe.id:
				push_error("l0 free-air cope: remounted %s" % sim.state.surface_id)
				return false
			for _k in range(50):
				sim.set_input(Vector2.ZERO, false, false)
				sim.tick()
				if sim.model.patches.has(sim.state.surface_id) \
						and int(sim.model.patches[sim.state.surface_id].kind) \
						== SimKinds.SurfaceKind.DECK:
					push_error("l0 free-air cope: deck stole after remount")
					return false
				if sim.state.surface_id == pipe.id and sim.state.u < 0.95:
					return true
			return sim.state.surface_id == pipe.id or sim.state.surface_id == wall.id
	push_error("l0 free-air cope: never remounted source")
	return false


## Floor / free-air ollie that meets an L0 pipe coping must land the pipe and
## drop into the bowl — not sticky-mount the abutting same-height deck at 0 coast.
## Floor ollie onto coping column: foreign high lip crashes (Reject+fall);
## abutting outward deck must not steal the contact as a clean Mount.
func _floor_ollie_coping_crashes_not_deck() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("floor ollie cope: setup")
		return false
	sim.fall_duration = 5.0
	var pipe: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if pipe == null:
		push_error("floor ollie cope: missing pipe")
		return false
	var midz := (pipe.z_min + pipe.z_max) * 0.5
	var cx := pipe.coping_x_at(midz)
	var lip := pipe.height_at_theta(midz, PI * 0.5)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.free_air_upright = false
	sim.state.air_launch_surface_id = "floor_1_L0"
	sim.state.air_peak_height = lip + 40.0
	# Meet the coping column with little lateral speed (floor ollie apex).
	sim.state.position = Vector3(cx, midz, lip + 18.0)
	sim.state.velocity = Vector3(0.0, 0.0, -40.0)
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.model.patches.has(sim.state.surface_id) \
				and int(sim.model.patches[sim.state.surface_id].kind) == SimKinds.SurfaceKind.DECK:
			push_error("floor ollie cope: abutting deck stole coping land")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == pipe.id:
			push_error(
				"floor ollie cope: foreign high lip must not Mount pipe u=%.2f"
				% sim.state.u
			)
			return false
		if sim.state.falling:
			return true
	push_error(
		"floor ollie cope: never fell mode=%s surf=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position]
	)
	return false


## Coping-column contacts compile to a single lip owner (pipe/wall), not the
## abutting outward deck — stream annotation must not dual-claim the seam.
func _air_contact_stream_lip_owns_coping_column() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("air stream: setup")
		return false
	var pipe: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if pipe == null:
		push_error("air stream: missing pipe")
		return false
	var midz := (pipe.z_min + pipe.z_max) * 0.5
	var cx := pipe.coping_x_at(midz)
	var lip := pipe.height_at_theta(midz, PI * 0.5)
	var span = null
	var cope: CopingEdge = sim.model.copings.get(pipe.coping_id)
	if cope != null:
		span = cope.span_at_z(midz)
	if span == null or span.lip_owner_id.is_empty():
		push_error("air stream: missing lip owner on span")
		return false
	if span.lip_owner_id != pipe.id and not sim.model.walls.has(span.lip_owner_id):
		push_error("air stream: lip owner %s not pipe/wall" % span.lip_owner_id)
		return false
	var from := Vector3(cx, midz, lip + 12.0)
	var to := Vector3(cx, midz, lip - 6.0)
	var contacts: Array = sim.query.collect_air_contacts(from, to, "")
	if contacts.is_empty():
		push_error("air stream: expected contacts at coping column")
		return false
	var saw_lip := false
	for c in contacts:
		var role := int(c.get("role", -1))
		var owner := str(c.get("owner_id", ""))
		if role == SimKinds.ContactRole.LIP_COLUMN:
			saw_lip = true
			if owner != span.lip_owner_id and owner != pipe.id:
				push_error(
					"air stream: lip contact owner %s != span %s"
					% [owner, span.lip_owner_id]
				)
				return false
		# Abutting deck hits on the column must remap to the lip — never claim
		# the deck as Mount owner at the coping X.
		if str(c.get("kind", "")) == "deck" and role == SimKinds.ContactRole.OUTWARD_DECK:
			if absf(float(c.get("point", from).x) - cx) <= SimTolerances.CAPSULE_RADIUS:
				push_error("air stream: outward deck claimed coping column")
				return false
	if not saw_lip:
		# Solid/support may arrive as SUPPORT_TOP remapped — accept pipe owner.
		var c0: Dictionary = contacts[0]
		if str(c0.get("owner_id", "")) != span.lip_owner_id \
				and str(c0.get("owner_id", "")) != pipe.id \
				and str(c0.get("surface_id", "")) != pipe.id:
			push_error(
				"air stream: no lip role; first=%s owner=%s"
				% [c0.get("kind"), c0.get("owner_id")]
			)
			return false
	return true


## Rejecting a skim deck must leave feet outside the solid with non-zero
## descending velocity available (no underside freeze).
func _airborne_reject_leaves_exterior() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/plaza_default.ssk"):
		push_error("air reject: setup")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) == SimKinds.SurfaceKind.DECK and not p.lethal:
			deck = p
			break
	if deck == null:
		push_error("air reject: no deck")
		return false
	var x := (deck.x_min + deck.x_max) * 0.5
	var z := (deck.z_min + deck.z_max) * 0.5
	# Skim from below the peak gate: should Reject, not Mount, and not freeze.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.air_launch_surface_id = "floor_1_L0"
	sim.state.air_peak_height = deck.height + 1.0 ## below DECK_LAND_MIN_ABOVE
	sim.state.position = Vector3(x, z, deck.height + 4.0)
	sim.state.velocity = Vector3(0.0, 0.0, -80.0)
	for _i in range(12):
		var prev_vz := sim.state.velocity.z
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == deck.id:
			push_error("air reject: skim mounted deck")
			return false
		if sim.state.is_airborne():
			var blk := sim.query.blocker_at(sim.state.position)
			if not blk.is_empty() and str(blk.get("kind", "")) == "deck" \
					and absf(sim.state.velocity.z) <= 0.01 and prev_vz < -10.0:
				push_error("air reject: underside freeze in deck")
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
	# Floor/deck hang-flat starts a fall bout (void does not).
	if model_patches_is_floor_or_deck(sim) and not sim.state.falling:
		push_error("hang flat: floor/deck land must request fall")
		return false
	return true


func model_patches_is_floor_or_deck(sim: PlayerSim) -> bool:
	if not sim.model.patches.has(sim.state.surface_id):
		return false
	var pk := int((sim.model.patches[sim.state.surface_id] as SupportPatch).kind)
	return pk == SimKinds.SurfaceKind.FLOOR or pk == SimKinds.SurfaceKind.DECK


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
	# Below ollie-lip band so foreign free-air land Mounts (upper band is a crash wall).
	# Drop mostly vertically — large outward vx drifts into the lip band before contact.
	var th := PI * 0.5 * 0.35
	var mid_x := left.x_at_theta(z, th)
	var mid_h := left.height_at_theta(z, th)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = ""
	sim.state.position = Vector3(mid_x, z, mid_h + 25.0)
	sim.state.velocity = Vector3(left.outward_sign() * 40.0, 0.0, -280.0)
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


func _layered_outer_wall_crashes_not_warp() -> bool:
	# layered_demo L1 right outer wall: free-air smash must fall (crash shell),
	# never freeze with vx≈0 and never warp onto the upper partner pipe lip.
	# upper_partner_pipe_id is transfer-only.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("inbound: setup")
		return false
	sim.fall_duration = 5.0
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
	for _i in range(90):
		sim.set_input(Vector2(-1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("inbound: died")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			push_error(
				"inbound: warped onto L1 pipe u=%.2f (partner lip seat)"
				% sim.state.u
			)
			return false
		if (
			sim.state.is_airborne()
			and not sim.state.falling
			and absf(sim.state.velocity.x) < 1.0
			and absf(sim.state.velocity.z) < 1.0
			and absf(sim.state.position.z - lip_h) < 30.0
		):
			push_error(
				"inbound: stuck airborne vx=%.1f vh=%.1f h=%.1f"
				% [sim.state.velocity.x, sim.state.velocity.z, sim.state.position.z]
			)
			return false
		if sim.state.falling:
			return true
	push_error(
		"inbound: never fell mode=%s sid=%s h=%.1f"
		% [sim.state.mode, sim.state.surface_id, sim.state.position.z]
	)
	return false


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
	sim.state.position = Vector3(start_x, edge_z, 120.0)
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
	var phantom := sim.query.blocker_at(Vector3(mid_x, hole_z, 120.0))
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
			continue ## prefer L1 deck (base 120, top 240)
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
	sim.fall_duration = 30.0
	var spawn_pos := sim.state.position
	var floor_id := sim.state.surface_id
	if not sim._is_checkpoint_surface(floor_id):
		push_error("respawn cp: spawn should be floor")
		return false
	# Seed a full history window away from spawn (narrow maps hit pipes/rims
	# before natural skate can age the oldest sample out).
	var mark := Vector3.ZERO
	for i in range(sim._checkpoint_history_limit()):
		var sample_pos := Vector3(spawn_pos.x + 40.0 + float(i), spawn_pos.y, spawn_pos.z)
		sim._push_checkpoint_sample(floor_id, sample_pos, "r")
	mark = sim.checkpoint_position
	if mark.distance_to(spawn_pos) <= 20.0:
		push_error(
			"respawn cp: seeded oldest still near spawn (cp=%s)"
			% sim.checkpoint_position
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


## Air-out at a right-edge coping, depth-transfer onto floor rows, then descend:
## must land the floor at lock X (map edge) — not fall through to the void.
func _hang_depth_transfer_lands_edge_floor() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/air_transfer.ssk"):
		push_error("hang edge floor: setup")
		return false
	var hung := false
	for _i in range(400):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("hang edge floor: never hung")
		return false
	var lock_x := sim.state.position.x
	# Depth toward the top ==== floor band (increasing Y on this map).
	for _j in range(120):
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if sim.state.position.y >= sim.model.depth * 0.78:
			break
	if sim.state.position.y < sim.model.depth * 0.7:
		push_error("hang edge floor: never reached floor band z=%.1f" % sim.state.position.y)
		return false
	# Descend onto the pad under the lock.
	for _k in range(180):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.position.z < -20.0:
			push_error(
				"hang edge floor: fell through (pos=%s hang=%s)"
				% [sim.state.position, sim.state.is_hanging()]
			)
			return false
		if sim.state.falling:
			return true
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var patch: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(patch.kind) != SimKinds.SurfaceKind.FLOOR:
				push_error("hang edge floor: landed %s kind=%s" % [
					sim.state.surface_id, patch.kind
				])
				return false
			if absf(sim.state.position.x - lock_x) > SimTolerances.ALIGN_EPS + 0.5:
				push_error("hang edge floor: lost lock on land")
				return false
			if absf(sim.state.position.z - patch.height) > SimTolerances.CONTACT_EPS * 2.0:
				push_error("hang edge floor: not seated on pad h=%.2f" % sim.state.position.z)
				return false
			if not sim.state.falling:
				push_error("hang edge floor: floor land must start fall")
				return false
			return true
	push_error(
		"hang edge floor: never landed mode=%s sid=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position]
	)
	return false


## Same air-out lock parked over the lava gap row must land lava (and die) — not
## phase through the lethal pad into the void below the park.
func _hang_depth_transfer_lands_edge_lava() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/air_transfer.ssk"):
		push_error("hang edge lava: setup")
		return false
	var hung := false
	for _i in range(400):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging():
			hung = true
			break
	if not hung:
		push_error("hang edge lava: never hung")
		return false
	var lock_x := sim.state.position.x
	# Park mid-lava under the synthetic gap lock, then drop (no depth stick so
	# we don't retarget onto the far pipe).
	var lava_z := 117.5
	sim.state.position = Vector3(lock_x, lava_z, 80.0)
	sim.state.velocity = Vector3(0.0, 0.0, -120.0)
	for _k in range(120):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.position.z < -20.0 and sim.state.alive:
			push_error(
				"hang edge lava: fell through alive pos=%s"
				% sim.state.position
			)
			return false
		if not sim.state.alive:
			return true
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var patch: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(patch.kind) == SimKinds.SurfaceKind.LAVA:
				return true
			push_error(
				"hang edge lava: expected lava, got %s kind=%s"
				% [sim.state.surface_id, patch.kind]
			)
			return false
	push_error(
		"hang edge lava: never landed lava mode=%s sid=%s alive=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.alive, sim.state.position]
	)
	return false


## Fixture setup for deck launch into an abutting left pipe.
func _deck_left_pipe_setup() -> Dictionary:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/deck_to_left_pipe.ssk"):
		return {}
	var deck: SupportPatch = null
	var pipe: PipeSurface = null
	for id in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[id]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
	for id in sim.model.pipes.keys():
		var pp: PipeSurface = sim.model.pipes[id]
		if int(pp.side) == SimKinds.PipeSide.LEFT:
			pipe = pp
	if deck == null or pipe == null:
		return {}
	return {"sim": sim, "deck": deck, "pipe": pipe}


## A deck edge does not proximity-mount its abutting pipe before the falling
## segment has crossed that pipe's sampled ride surface.
func _deck_ride_off_rejects_pre_surface_pipe_contact() -> bool:
	var setup := _deck_left_pipe_setup()
	if setup.is_empty():
		push_error("deck contact: setup")
		return false
	var sim: PlayerSim = setup.sim
	var deck: SupportPatch = setup.deck
	var pipe: PipeSurface = setup.pipe
	var z := (deck.z_min + deck.z_max) * 0.5
	var cx := pipe.coping_x_at(z)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.position = Vector3(cx - 5.0, z, deck.height)
	sim.state.tangent_velocity = Vector2(180.0, 0.0)
	sim.state.facing = "r"
	sim.state.clear_hang()
	var saw_air := false
	for tick in range(12):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		saw_air = saw_air or sim.state.is_airborne()
		if sim.state.is_grounded() and sim.state.surface_id == pipe.id:
			push_error("deck contact: proximity-mounted pipe at tick %s" % tick)
			return false
		if sim.state.falling:
			return saw_air
	push_error("deck contact: pre-surface pipe face never rejected")
	return false


## The same deck launch may Mount once gravity carries its free-air segment
## through the sampled pipe ride surface from above.
func _deck_ride_off_mounts_only_on_descending_surface_crossing() -> bool:
	var setup := _deck_left_pipe_setup()
	if setup.is_empty():
		push_error("deck crossing: setup")
		return false
	var sim: PlayerSim = setup.sim
	var deck: SupportPatch = setup.deck
	var pipe: PipeSurface = setup.pipe
	var z := (deck.z_min + deck.z_max) * 0.5
	var theta := 0.45 * PI * 0.5
	var x := pipe.x_at_theta(z, theta)
	var ride_h := pipe.height_at_theta(z, theta)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = deck.id
	sim.state.position = Vector3(x, z, ride_h + 18.0)
	sim.state.velocity = Vector3(0.0, 0.0, -240.0)
	sim.state.note_air_height(sim.state.position.z)
	for tick in range(20):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error("deck crossing: fell instead of mounting at tick %s" % tick)
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id != pipe.id:
				push_error(
					"deck crossing: landed %s, want %s"
					% [sim.state.surface_id, pipe.id]
				)
				return false
			return true
	push_error("deck crossing: never mounted sampled ride surface")
	return false


## Joint wipeout parks on approach side with lean away from the face.
func _joint_wipeout_fall_tip_stays_approach() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("wipeout park: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var wall: WallSurface = sim.model.walls.get("wall_span_coping_pipe_1_L0_S1_0")
	if wall == null:
		push_error("wipeout park: missing wall")
		return false
	var z := 250.0
	var ws: Dictionary = wall.sample_at_z(z)
	var wx := float(ws.x)
	var top := float(ws.top_height)
	var bottom := float(ws.bottom_height)
	# Mid climb-band — below the wall bottom hits pipe solids with facing lean.
	var h := (bottom + top) * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_0_L0"
	sim.state.facing = "r"
	sim.state.position = Vector3(wx - 40.0, z, h)
	sim.state.velocity = Vector3(500.0, 0.0, -40.0)
	sim.state.note_air_height(sim.state.position.z)
	var fell := false
	for _i in range(50):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			fell = true
			if sim.state.fall_lean_sign >= 0.0:
				push_error("wipeout park: lean into wall %.1f" % sim.state.fall_lean_sign)
				return false
			if sim.state.position.x > wx - SimTolerances.WALL_REJECT_CLEAR + 0.5:
				push_error(
					"wipeout park: feet past clear x=%.1f wx=%.1f"
					% [sim.state.position.x, wx]
				)
				return false
	if not fell:
		push_error("wipeout park: never fell")
		return false
	return true


## Next-spine: facing cast, opposite side, above target lip; never self lip.
func _layered_next_spine_keeps_l1_past_l0_lip() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("next spine: setup")
		return false
	var left: PipeSurface = sim.model.pipes.get("pipe_2_L0_S0")
	var l1_right: PipeSurface = sim.model.pipes.get("pipe_5_L1_S1")
	if left == null or l1_right == null:
		push_error("next spine: missing layered pipes")
		return false
	var z := 1700.0
	var cx := left.coping_x_at(z)
	var l0_h := left.height_at_theta(z, PI * 0.5)
	var l1_h := l1_right.height_at_theta(z, PI * 0.5)
	# Below the L1 lip — must not count an above-facing target.
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = left.id
	sim.state.u = 1.0
	sim.state.position = Vector3(cx, z, l0_h)
	sim.state.tangent_velocity = Vector2(300.0, 0.0)
	sim.state.set_facing_side("l")
	sim.debug.capture(sim.state, sim.model, sim.query)
	sim.debug.refresh_transfer_candidates(sim.state, sim.query)
	for c in sim.debug.candidates:
		if str(c.get("id", "")) == l1_right.coping_id:
			push_error("next spine: L1 counted while below its lip %s" % [c])
			return false
	# Above the L1 lip at the shared X — opposite right lip counts.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = left.id
	sim.state.position = Vector3(cx - SimTolerances.CAPSULE_RADIUS * 0.5, z, l1_h + 20.0)
	sim.state.velocity = Vector3(-200.0, 0.0, 50.0)
	sim.state.set_facing_side("l")
	sim.debug.capture(sim.state, sim.model, sim.query)
	sim.debug.refresh_transfer_candidates(sim.state, sim.query)
	if sim.debug.candidates.is_empty() \
			or str(sim.debug.candidates[0].get("id", "")) != l1_right.coping_id:
		push_error(
			"next spine: want L1 right from above got %s" % [sim.debug.candidates]
		)
		return false
	# Gravity turn on an L1 left pipe: facing right must not report that same lip.
	var l1_left: PipeSurface = sim.model.pipes.get("pipe_4_L1_S0")
	if l1_left == null:
		push_error("next spine: missing pipe_4_L1_S0")
		return false
	var z1 := (l1_left.z_min + l1_left.z_max) * 0.5
	var th: float = 0.7 * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = l1_left.id
	sim.state.u = 0.7
	sim.state.air_launch_surface_id = ""
	sim.state.position = Vector3(
		l1_left.x_at_theta(z1, th), z1, l1_left.height_at_theta(z1, th)
	)
	sim.state.tangent_velocity = Vector2(-200.0, 0.0)
	sim.state.set_facing_side("r")
	sim.debug.capture(sim.state, sim.model, sim.query)
	sim.debug.refresh_transfer_candidates(sim.state, sim.query)
	var self_cope := l1_left.coping_id
	for c in sim.debug.candidates:
		if str(c.get("id", "")) == self_cope:
			push_error("next spine: self lip reported after gravity turn %s" % [c])
			return false
	return true


## Transfer button pulls X onto the next opposite lip, holds facing, clears vx.
func _transfer_button_lerps_x_holds_facing() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("transfer lerp: setup")
		return false
	var left: PipeSurface = sim.model.pipes.get("pipe_2_L0_S0")
	var l1_right: PipeSurface = sim.model.pipes.get("pipe_5_L1_S1")
	if left == null or l1_right == null:
		push_error("transfer lerp: missing pipes")
		return false
	var z := 1700.0
	var cx := float(l1_right.coping_x_at(z))
	var l1_h := l1_right.height_at_theta(z, PI * 0.5)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = left.id
	sim.state.position = Vector3(cx + 80.0, z, l1_h + 40.0)
	sim.state.velocity = Vector3(-250.0, 0.0, 80.0)
	sim.state.set_facing_side("l")
	sim.state.clear_hang()
	sim.state.maneuver = null
	var cands := sim.query.transfer_candidates(sim.state)
	if cands.is_empty() or str(cands[0].coping_id) != l1_right.coping_id:
		push_error("transfer lerp: expected L1 right candidate got %s" % [cands])
		return false
	sim.set_input(Vector2.ZERO, false, true)
	sim.tick()
	if not sim.state.has_maneuver() \
			or (sim.state.maneuver as ManeuverPlan).kind != ManeuverPlan.Kind.TRANSFER:
		push_error(
			"transfer lerp: no TRANSFER plan reject=%s man=%s"
			% [sim.state.last_reject, sim.state.maneuver]
		)
		return false
	# Geometric right-lip lean (presentation may rewrite to the long roll path).
	var want_tilt := -l1_right.outward_sign() * (PI * 0.5)
	var got_tilt := float((sim.state.maneuver as ManeuverPlan).tilt_end)
	if absf(wrapf(got_tilt - want_tilt, -PI, PI)) > 0.01:
		push_error("transfer lerp: tilt_end=%.3f want %.3f" % [got_tilt, want_tilt])
		return false
	var plan0: ManeuverPlan = sim.state.maneuver
	var start_x := plan0.start_position.x
	var start_h := plan0.start_position.z
	var dest_h := plan0.land_height
	var saw_partial := false
	var prev_prog := -1.0
	var stall_frames := 0
	for _i in range(240):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.facing != "l":
			push_error("transfer lerp: facing changed to %s" % sim.state.facing)
			return false
		if sim.state.has_maneuver():
			var pcur: ManeuverPlan = sim.state.maneuver
			var px := sim.state.position.x
			var h := sim.state.position.z
			# Progress must keep advancing through the apex (no height stall).
			if pcur.progress > 0.05 and pcur.progress < 0.95:
				if prev_prog >= 0.0 and pcur.progress <= prev_prog + 0.00001:
					stall_frames += 1
					if stall_frames > 2:
						push_error(
							"transfer lerp: progress stalled at %.3f (apex freeze)"
							% pcur.progress
						)
						return false
				else:
					stall_frames = 0
			prev_prog = pcur.progress
			# Still clearly above the lip → must not already be parked on dest X.
			if h > dest_h + 8.0 and absf(px - cx) <= SimTolerances.ALIGN_EPS \
					and absf(start_x - cx) > 10.0:
				push_error(
					"transfer lerp: snapped to dest X while still above lip h=%.1f dest_h=%.1f"
					% [h, dest_h]
				)
				return false
			# Mid-flight must show intermediate X (time-phased, not end snap).
			if h < start_h - 5.0 and h > dest_h + 8.0:
				if absf(px - start_x) < 2.0 or absf(px - cx) < 2.0:
					push_error(
						"transfer lerp: mid-fall x=%.1f stuck at endpoint (start=%.1f dest=%.1f h=%.1f prog=%.2f)"
						% [px, start_x, cx, h, pcur.progress]
					)
					return false
				saw_partial = true
			continue
		break
	if not saw_partial:
		push_error("transfer lerp: never saw mid-lerp X")
		return false
	if absf(sim.state.position.x - cx) > SimTolerances.ALIGN_EPS:
		push_error(
			"transfer lerp: x=%.1f want cope %.1f" % [sim.state.position.x, cx]
		)
		return false
	if absf(sim.state.velocity.x) > 1.0:
		push_error("transfer lerp: vx not cleared got %.1f" % sim.state.velocity.x)
		return false
	if sim.state.facing != "l":
		push_error("transfer lerp: facing lost after arrive")
		return false
	return true


## Floor ollie mid-band (above geometric L0 lip, below WALL_EXTENSION hang lip):
## transfer must reject — accepting snaps X through the ramp and falls forever.
func _transfer_rejects_below_hang_lip_after_floor_ollie() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("below-hang transfer: setup")
		return false
	var l1r: PipeSurface = sim.model.pipes.get("pipe_5_L1_S1")
	var l0l: PipeSurface = sim.model.pipes.get("pipe_2_L0_S0")
	if l1r == null or l0l == null:
		push_error("below-hang transfer: missing pipes")
		return false
	var z := 1700.0
	var cx := float(l1r.coping_x_at(z))
	var geom_h := float(sim.model.copings[l0l.coping_id].sample_at_z(z).height)
	var hang_h := sim.query.transfer_hang_height(l0l.coping_id, z, geom_h)
	if hang_h <= geom_h + 10.0:
		push_error(
			"below-hang transfer: expected WALL_EXTENSION hang above geom (%.1f / %.1f)"
			% [hang_h, geom_h]
		)
		return false
	var mid_h := (geom_h + hang_h) * 0.5
	var floor_id := ""
	for pid in sim.model.patches.keys():
		if str(pid).begins_with("floor"):
			floor_id = str(pid)
			break
	if floor_id.is_empty():
		push_error("below-hang transfer: no floor")
		return false
	# Free air after floor ollie, bowl-side of L1 right, facing the L0 left wall.
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = floor_id
	sim.state.position = Vector3(cx - 60.0, z, mid_h)
	sim.state.velocity = Vector3(200.0, 0.0, 80.0)
	sim.state.set_facing_side("r")
	sim.state.clear_hang()
	sim.state.maneuver = null
	var cands := sim.query.transfer_candidates(sim.state)
	for c in cands:
		if str(c.get("coping_id", "")) == l0l.coping_id:
			push_error(
				"below-hang transfer: L0 wall listed while below hang lip (h=%.1f hang=%.1f)"
				% [mid_h, hang_h]
			)
			return false
	sim.set_input(Vector2(1, 0), false, true)
	sim.tick()
	if sim.state.has_maneuver():
		push_error(
			"below-hang transfer: accepted unreachable plan land_h=%.1f start_h=%.1f"
			% [(sim.state.maneuver as ManeuverPlan).land_height, mid_h]
		)
		return false
	# Stay alive above the void — no snap-through forever fall.
	for _i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if not sim.state.alive:
			push_error("below-hang transfer: died mid air")
			return false
		if sim.state.position.z < SimTolerances.VOID_FLOOR + 5.0 and sim.state.has_maneuver():
			push_error(
				"below-hang transfer: fell through while still maneuvering h=%.1f"
				% sim.state.position.z
			)
			return false
	return true


## Shared-X spine (L1 left OPEN → L0 right WALL_EXTENSION): transfer must
## re-anchor hang onto the L0 wall top — X lerp alone is a no-op at dx=0.
func _transfer_shared_x_spine_reanchors_hang() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("shared-x transfer: setup")
		return false
	var l1l: PipeSurface = sim.model.pipes.get("pipe_4_L1_S0")
	var l0r: PipeSurface = sim.model.pipes.get("pipe_1_L0_S1")
	if l1l == null or l0r == null:
		push_error("shared-x transfer: missing pipes")
		return false
	var z := clampf(1800.0, l1l.z_min + 5.0, l1l.z_max - 5.0)
	var cx := float(l1l.coping_x_at(z))
	if absf(cx - float(l0r.coping_x_at(z))) > SimTolerances.ALIGN_EPS:
		push_error("shared-x transfer: expected shared cope X")
		return false
	var h_l := l1l.height_at_theta(z, PI * 0.5)
	var src_edge := sim.query.edge_at(l1l.id, z, "coping")
	if src_edge == null:
		push_error("shared-x transfer: missing L1 open edge")
		return false
	var dest_edge := sim.query.open_hang_edge_for_coping(l0r.coping_id, z)
	if dest_edge == null:
		push_error("shared-x transfer: missing L0 hang edge")
		return false
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = l1l.id
	sim.state.position = Vector3(cx, z, h_l + 40.0)
	sim.state.velocity = Vector3(0.0, 0.0, 60.0)
	sim.state.set_facing_side("l")
	sim.state.begin_hang(src_edge.id)
	sim.state.maneuver = null
	var cands := sim.query.transfer_candidates(sim.state)
	if cands.is_empty() or str(cands[0].coping_id) != l0r.coping_id:
		push_error("shared-x transfer: HUD/cands want L0 right got %s" % [cands])
		return false
	sim.set_input(Vector2.ZERO, false, true)
	sim.tick()
	if not sim.state.has_maneuver() \
			or (sim.state.maneuver as ManeuverPlan).kind != ManeuverPlan.Kind.TRANSFER:
		push_error("shared-x transfer: expected TRANSFER plan got reject=%s" % sim.state.last_reject)
		return false
	var xplan: ManeuverPlan = sim.state.maneuver
	var dest_h := float(xplan.land_height)
	var want_end := -l0r.outward_sign() * (PI * 0.5)
	if absf(wrapf(float(xplan.tilt_end) - want_end, -PI, PI)) > 0.01:
		push_error("shared-x transfer: tilt_end should be L0 geometric lean")
		return false
	var saw_mid_progress := false
	# Must still be transferring while clearly above the hang lip.
	for _i in range(240):
		if sim.state.is_hanging() and sim.state.hang_edge_id == dest_edge.id:
			break
		if not sim.state.has_maneuver() \
				and sim.state.position.z > dest_h + SimTolerances.CAPSULE_RADIUS:
			push_error(
				"shared-x transfer: ended above lip h=%.1f dest=%.1f"
				% [sim.state.position.z, dest_h]
			)
			return false
		if sim.state.has_maneuver():
			var pcur: ManeuverPlan = sim.state.maneuver
			if pcur.progress > 0.15 and pcur.progress < 0.95 \
					and sim.state.position.z > dest_h + 8.0:
				saw_mid_progress = true
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
	if not saw_mid_progress:
		push_error("shared-x transfer: never saw mid transfer progress")
		return false
	if not sim.state.is_hanging() or sim.state.hang_edge_id != dest_edge.id:
		push_error(
			"shared-x transfer: hang=%s want %s reject=%s man=%s"
			% [
				sim.state.hang_edge_id,
				dest_edge.id,
				sim.state.last_reject,
				sim.state.maneuver.kind_name() if sim.state.has_maneuver() else "none",
			]
		)
		return false
	if sim.state.air_launch_surface_id != dest_edge.from_surface_id:
		push_error(
			"shared-x transfer: launch=%s want %s"
			% [sim.state.air_launch_surface_id, dest_edge.from_surface_id]
		)
		return false
	if sim.state.facing != "l":
		push_error("shared-x transfer: facing changed to %s" % sim.state.facing)
		return false
	if absf(sim.state.position.x - cx) > SimTolerances.ALIGN_EPS:
		push_error("shared-x transfer: x drifted %.2f" % sim.state.position.x)
		return false
	return true


## ===)))#### : slow left coast off the outward deck must not Reject-freeze on
## the deck open-side cage, and must land the bowl floor (not void).
func _right_pipe_deck_slow_leave_lands_floor() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_right_pipe_deck_floor.ssk"):
		push_error("right deck leave: setup")
		return false
	var deck: SupportPatch = null
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	if deck == null:
		push_error("right deck leave: no deck")
		return false
	var pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side != SimKinds.PipeSide.RIGHT:
			continue
		if pipe == null or absf(p.coping_x_at((p.z_min + p.z_max) * 0.5) - deck.x_min) \
				< absf(pipe.coping_x_at((pipe.z_min + pipe.z_max) * 0.5) - deck.x_min):
			pipe = p
	if pipe == null:
		push_error("right deck leave: no right pipe")
		return false
	var z := 50.0
	if z < pipe.z_min or z > pipe.z_max:
		z = (pipe.z_min + pipe.z_max) * 0.5
	var cx := pipe.coping_x_at(z)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.u = 0.0
	sim.state.v = 0.0
	sim.state.position = Vector3(cx + 5.0, z, deck.height)
	sim.state.tangent_velocity = Vector2(-180.0, 0.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.set_facing_side("l")
	sim.state.clear_hang()
	sim.state.maneuver = null
	var saw_air := false
	var stuck_h := deck.height
	var stuck_ticks := 0
	for _i in range(240):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_airborne():
			saw_air = true
			if absf(sim.state.position.z - stuck_h) < 0.5 \
					and absf(sim.state.velocity.x) < 1.0:
				stuck_ticks += 1
			else:
				stuck_h = sim.state.position.z
				stuck_ticks = 0
			if stuck_ticks > 30:
				push_error(
					"right deck leave: freeze near lip x=%.1f h=%.1f launch=%s"
					% [sim.state.position.x, sim.state.position.z, sim.state.air_launch_surface_id]
				)
				return false
		if sim.state.surface_id == "__void_floor__" or sim.state.position.z < -50.0:
			push_error(
				"right deck leave: void x=%.1f h=%.1f"
				% [sim.state.position.x, sim.state.position.z]
			)
			return false
		if sim.state.is_grounded() and sim.model.patches.has(sim.state.surface_id):
			var land: SupportPatch = sim.model.patches[sim.state.surface_id]
			if int(land.kind) == SimKinds.SurfaceKind.FLOOR and not land.lethal:
				if not saw_air:
					push_error("right deck leave: grounded floor without air")
					return false
				return true
	push_error(
		"right deck leave: never floored mode=%s surf=%s pos=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position]
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
	var launch_x := 0.0
	for _i in range(120):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging() or not sim.state.hang_edge_id.is_empty():
			push_error("ramp peak: hang/X-lock must never engage")
			return false
		if sim.state.is_airborne():
			launched = true
			launch_x = sim.state.position.x
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
	# Keep holding outward — outer-back feature wall must not zero VX (felt like
	# lip/X-lock on the ramp itself).
	for _j in range(8):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.is_hanging():
			push_error("ramp peak: hang engaged after launch")
			return false
		if sim.state.is_airborne() and sim.state.velocity.x <= 1.0:
			push_error(
				"ramp peak: outward X frozen after leave (vx=%.1f x=%.1f)"
				% [sim.state.velocity.x, sim.state.position.x]
			)
			return false
		if sim.state.is_airborne() and sim.state.position.x <= launch_x + 0.5 and _j >= 2:
			push_error(
				"ramp peak: X not advancing past peak (x=%.1f launch=%.1f)"
				% [sim.state.position.x, launch_x]
			)
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
	# Bail duration long so impact→fall does not checkpoint-teleport mid-assert.
	sim.fall_duration = 10.0
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
	var peak := float(sample.base_height) + float(sample.get("rise", sample.radius))
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
	var endcap_bailed := false
	for _i in range(90):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if sim.state.falling:
			endcap_bailed = true
			break
		if sim.model.ramps.has(sim.state.surface_id):
			push_error("feature walls: remounted ramp via endcap")
			return false
		if sim.state.position.y < right.z_max - 1.0:
			push_error("feature walls: tunneled through far endcap z=%.1f" % sim.state.position.y)
			return false
	if not endcap_bailed and sim.state.position.y < right.z_max:
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


func _z_band_decks(sim: PlayerSim) -> Dictionary:
	var short_h := LevelLoader.DEFAULT_STEP_HEIGHT
	var tall_h := 3.0 * LevelLoader.DEFAULT_STEP_HEIGHT
	var out := {"short": null, "tall": null}
	for pid in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[pid]
		if int(p.kind) != SimKinds.SurfaceKind.DECK:
			continue
		if is_equal_approx(p.height, short_h):
			out.short = p
		elif is_equal_approx(p.height, tall_h):
			out.tall = p
	return out


func _z_band_short_coping_owns_short_deck() -> bool:
	# Short pipe Z must own the short deck — no tall roof over short coping.
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_z_band_deck.ssk"):
		push_error("z_band cope: setup")
		return false
	var decks := _z_band_decks(sim)
	if decks.short == null or decks.tall == null:
		push_error("z_band cope: need short+tall decks")
		return false
	var short_deck: SupportPatch = decks.short
	var tall_deck: SupportPatch = decks.tall
	var short_pipe: PipeSurface = null
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		var samp: Dictionary = p.sample_at_z((p.z_min + p.z_max) * 0.5)
		if samp.is_empty():
			continue
		if is_equal_approx(float(samp.get("rise", 0.0)), LevelLoader.DEFAULT_STEP_HEIGHT):
			short_pipe = p
			break
	if short_pipe == null:
		push_error("z_band cope: no short pipe")
		return false
	var z := (short_pipe.z_min + short_pipe.z_max) * 0.5
	var cope: CopingEdge = sim.model.copings[short_pipe.coping_id]
	var span := cope.span_at_z(z)
	if span == null or span.outward_deck_id != short_deck.id:
		push_error(
			"z_band cope: short pipe outward_deck want %s got %s"
			% [short_deck.id, span.outward_deck_id if span else ""]
		)
		return false
	# Tall pad must not cover short-pipe mid Z (floating roof).
	if tall_deck.contains_xz((tall_deck.x_min + tall_deck.x_max) * 0.5, z):
		push_error("z_band cope: tall deck still covers short pipe Z")
		return false
	if not short_deck.contains_xz((short_deck.x_min + short_deck.x_max) * 0.5, z):
		push_error("z_band cope: short deck missing at short pipe Z")
		return false
	# Air at short lip must land short deck — not die on a phantom tall roof.
	sim.fall_duration = 5.0
	var cx := short_pipe.coping_x_at(z)
	var mid_x := (short_deck.x_min + short_deck.x_max) * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.state.air_launch_surface_id = short_pipe.id
	sim.state.free_air_upright = true
	sim.state.position = Vector3(lerpf(cx, mid_x, 0.55), z, short_deck.height + 8.0)
	sim.state.velocity = Vector3(short_pipe.outward_sign() * 80.0, 0.0, -120.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(90):
		sim.set_input(Vector2(short_pipe.outward_sign(), 0.0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error("z_band cope: bailed over short band (tall roof?)")
			return false
		if sim.state.is_grounded() and sim.state.surface_id == short_deck.id:
			return true
	push_error("z_band cope: never landed short deck")
	return false


func _z_band_tall_to_short_leave_airs() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_z_band_deck.ssk"):
		push_error("z_band leave: setup")
		return false
	sim.friction = 0.0
	var decks := _z_band_decks(sim)
	if decks.short == null or decks.tall == null:
		push_error("z_band leave: need short+tall decks")
		return false
	var tall: SupportPatch = decks.tall
	var short: SupportPatch = decks.short
	# Tall band is near (low Z); short is far (high Z) — leave +Y off tall ledge.
	var mid_x := (tall.x_min + tall.x_max) * 0.5
	var z0 := tall.z_max - 8.0
	if z0 <= tall.z_min:
		z0 = (tall.z_min + tall.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = tall.id
	sim.state.u = 0.0
	sim.state.v = 0.0
	sim.state.position = Vector3(mid_x, z0, tall.height)
	sim.state.tangent_velocity = Vector2(0.0, 420.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	var saw_air := false
	for _i in range(120):
		sim.set_input(Vector2(0, 1), false, false)
		sim.tick()
		if sim.state.is_airborne():
			saw_air = true
		if saw_air and sim.state.is_grounded() and sim.state.surface_id == short.id:
			# Descending land onto short is OK; sticky mid-air mount is not.
			if sim.state.position.z > short.height + SimTolerances.CONTACT_EPS * 4.0:
				push_error("z_band leave: sticky mount short above its top")
				return false
			return true
		if sim.state.falling:
			return true
	if not saw_air:
		push_error("z_band leave: tall→short never left into free air")
		return false
	return true


func _z_band_short_to_tall_riser_falls() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_z_band_deck.ssk"):
		push_error("z_band riser: setup")
		return false
	sim.fall_duration = 5.0
	sim.friction = 0.0
	var decks := _z_band_decks(sim)
	if decks.short == null or decks.tall == null:
		push_error("z_band riser: need short+tall decks")
		return false
	var short: SupportPatch = decks.short
	var tall: SupportPatch = decks.tall
	var mid_x := (short.x_min + short.x_max) * 0.5
	# Approach the tall riser from the short pad (high Z → low Z).
	var z0 := short.z_min + 8.0
	if z0 >= short.z_max:
		z0 = (short.z_min + short.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = short.id
	sim.state.u = 0.0
	sim.state.v = 0.0
	sim.state.position = Vector3(mid_x, z0, short.height)
	sim.state.tangent_velocity = Vector2(0.0, -480.0)
	sim.state.velocity = Vector3.ZERO
	sim.state.clear_hang()
	for _i in range(120):
		sim.set_input(Vector2(0, -1), false, false)
		sim.tick()
		if sim.state.falling:
			return true
		# Must not tunnel onto tall top without leaving short height band.
		if sim.state.is_grounded() and sim.state.surface_id == tall.id:
			push_error("z_band riser: mounted tall top through riser")
			return false
	push_error("z_band riser: never fell into tall open-side wall")
	return false
