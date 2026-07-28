class_name PlayerSteps
extends RefCounted
## Step bodies: per-tick sim procedures that mutate a live Player (`p`).
## Prefer pure helpers for policy; keep player.gd as thin orchestrator.

static func apply_grounded_motion(p, delta: float, speed_mul: float) -> void:
	var prev_support_h: float = p.depth.surface_height
	p._commit_xz(p.depth.logical_x, p.depth.logical_z + p._velocity.y * speed_mul * delta)

	var hit: Dictionary = p._sample_underfoot()
	# A fresh mount belongs to the visible story at the player's feet. Plain
	# height sampling can otherwise choose overlapping L0 lava / coping below an
	# L1 pipe arc before we have a sticky identity.
	if not p._on_ramp and p._level != null:
		var story_pipe: Dictionary = p._level.sample_pipe_on_story(
			p.depth.logical_x, p.depth.logical_z, p._feet_height()
		)
		if story_pipe.get("active", false):
			hit = story_pipe
	# Sticky ride: never adopt a foreign pipe (stacked L0 at shared L1 coping).
	if p._on_ramp:
		var own: Dictionary = p._query_own_ramp_surface()
		var current: Dictionary = p._ramp_pipe_hit()
		var under: Dictionary = hit
		# Sticky sample refuses fallthrough when inactive — still probe for a
		# competing pipe (plain sample) so we launch instead of remounting it.
		if not own.get("active", false) and not p._ContactMath.is_pipe(hit) and p._level != null:
			under = p._level.sample(
				p.depth.logical_x, p.depth.logical_z, -1, NAN, p._feet_height()
			)
		var sticky: Dictionary = p._GroundMotion.decide_sticky(
			true, own.get("active", false), under, current, p._velocity.x, p._ramp_side
		)
		var sticky_action := str(sticky.get("action", "leave"))
		if sticky_action == "launch":
			p._enter_air_from_pipe(current, float(sticky.get("toward", 0.0)))
			return
		if sticky_action == "leave":
			p._leave_ramp_to_flat()
			hit = p._sample_underfoot()
		else:
			hit = own
	var solid_pad: bool = p._solid_pad_underfoot(prev_support_h)
	var mount: Dictionary = p._GroundMotion.decide_mount(
		hit, prev_support_h, p._on_ramp, solid_pad, p.ride_off_height_eps
	)
	if bool(mount.get("allow_pipe", false)):
		if not p._on_ramp:
			p._ramp_along = p._velocity.x
			p._on_ramp = true
		p._ramp_side = int(hit.get("side", p._ramp_side))
		p._ramp_lip_x = float(hit.get("lip_x", p._ramp_lip_x))
		p._ramp_base_height = float(hit.get("base_height", p._ramp_base_height))
		p._ramp_z_min = float(hit.get("z_min", p._ramp_z_min))
		p._ramp_z_max = float(hit.get("z_max", p._ramp_z_max))
		p._apply_ramp_friction(delta)
		p._ramp_along = p._velocity.x
		var arc_speed: float = p._ramp_along * speed_mul
		p._move_along_pipe(hit, arc_speed, delta)
		# Re-sample after move so θ matches feet; project along → horiz remnant.
		if p._on_ramp and not p._airborne:
			var after_own: Dictionary = p._query_own_ramp_surface()
			var after_sample: Dictionary = p._sample_underfoot()
			var after_under: Dictionary = after_sample
			if (
				not after_own.get("active", false)
				and not p._ContactMath.is_pipe(after_sample)
				and p._level != null
			):
				after_under = p._level.sample(
					p.depth.logical_x, p.depth.logical_z, -1, NAN, p._feet_height()
				)
			var after: Dictionary = p._GroundMotion.decide_post_move(
				after_own.get("active", false),
				after_own,
				after_under,
				p._ramp_pipe_hit(),
				p._ramp_along,
				p._ramp_side,
			)
			var after_action := str(after.get("action", "leave"))
			if after_action == "ride":
				p._project_ramp_velocity(float(after.get("theta", 0.0)))
			elif after_action == "launch":
				p._enter_air_from_pipe(p._ramp_pipe_hit(), float(after.get("toward", 0.0)))
			else:
				p._leave_ramp_to_flat()
		return

	if p._on_ramp:
		p._leave_ramp_to_flat()
	var flat_arc: float = p._velocity.x * speed_mul
	var next_x: float = p.depth.logical_x + flat_arc * delta
	var cross: Dictionary = p._coping_cross_hit(p.depth.logical_x, next_x)
	var flat: Dictionary = p._GroundMotion.decide_flat_path(
		hit,
		cross,
		solid_pad,
		bool(mount.get("rejected_fresh_coping", false)),
		flat_arc,
	)
	var flat_action := str(flat.get("action", "commit"))
	if flat_action == "ride_off":
		p._commit_xz(next_x, p.depth.logical_z)
		p._try_ride_off_air(prev_support_h)
		return
	if flat_action == "coping_launch":
		p._enter_air_from_pipe(flat.get("hit", {}), float(flat.get("up_speed", 0.0)))
		return
	p._commit_xz(next_x, p.depth.logical_z)
	p._try_ride_off_air(prev_support_h)

static func resolve_and_apply_air_contact(p, prefer_h: float) -> Dictionary:
	if p._level == null:
		return p._ContactMath.make_air_contact("oob", -1, 0.0, false, {})
	var sticky: Dictionary = p._AerialContact.sticky_query(
		p.air_over,
		p._air_x_locked,
		p._air_side,
		p._air_lip_x,
		p._air_base_height,
		p._air_z_min,
		p._air_z_max,
	)
	var contact: Dictionary = p._level.resolve_air_contact(
		p.depth.logical_x,
		p.depth.logical_z,
		prefer_h,
		int(sticky.get("side", -1)),
		float(sticky.get("lip_x", NAN)),
		float(sticky.get("base_height", NAN)),
		p._air_x_locked,
		float(sticky.get("z_min", NAN)),
		float(sticky.get("z_max", NAN)),
	)
	var patch: Dictionary = p._AerialContact.unlocked_identity_from_contact(
		contact, p._air_x_locked
	)
	if not bool(patch.get("apply", false)):
		# Collision/landing uses contact; keep locked coping identity for pin / drop-in.
		return contact

	p.air_over = str(patch.get("air_over", "flat"))
	p._air_over_layer = int(patch.get("air_over_layer", -1))
	var kind := str(patch.get("kind", "plain"))
	if kind == "pipe":
		var chit: Dictionary = patch.get("hit", {})
		p._air_side = int(chit.get("side", p._air_side))
		p._air_lip_x = float(chit.get("lip_x", p._air_lip_x))
		p._air_radius = p._pipe_radius_for_hit(chit)
		p._air_base_height = float(chit.get("base_height", p._air_base_height))
		p._air_z_min = float(chit.get("z_min", p._air_z_min))
		p._air_z_max = float(chit.get("z_max", p._air_z_max))
		p._air_coping_x = p._coping_x_for(p._air_side, p._air_lip_x, p._air_radius)
		p._transfer_behind_sign = p._coping_sign(p._air_side)
	elif patch.has("air_base_height"):
		p._air_base_height = float(patch.get("air_base_height", 0.0))
	return contact

static func step_god_vertical(p, delta: float) -> void:
	if not DebugTools.is_available() or not DebugTools.god_mode:
		return
	var v := Input.get_axis("god_down", "god_up")
	if is_zero_approx(v):
		return
	if not p._airborne:
		if v <= 0.0:
			return
		var under: Dictionary = (
			p._level.sample(p.depth.logical_x, p.depth.logical_z, -1, NAN, p.depth.surface_height)
			if p._level else {}
		)
		var zone := str(under.get("zone", "flat"))
		if zone == "oob":
			zone = "flat"
		var target := {"zone": zone, "lock_x": false, "anchor_x": p.depth.logical_x}
		if p._ContactMath.is_pipe(under):
			target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
			target["lip_x"] = float(under.get("lip_x", p.depth.logical_x))
			target["radius"] = p._pipe_radius_for_hit(under)
			target["base_height"] = float(under.get("base_height", 0.0))
			target["layer"] = int(under.get("layer", -1))
		p._begin_air_over(target, p.depth.surface_height, false)
		p.air_vel_y = 0.0
	var h_before_god: float = p.air_abs_height
	p.air_abs_height += v * p.god_vert_speed * delta
	p.air_vel_y = 0.0
	if v < 0.0:
		p.air_vel_y = -0.01
		var contact: Dictionary = p._resolve_and_apply_air_contact(h_before_god)
		p._try_land_from_air_contact(contact, h_before_god, delta, 1.0)
		p.air_vel_y = 0.0

static func try_land_from_air_contact(p, contact: Dictionary, h_before: float, delta: float, speed_mul: float) -> bool:
	if p._level == null:
		return false
	var h1: float = p.air_abs_height
	var sweep: Dictionary = {}
	var hole_lower: Dictionary = {}
	var resolved: Dictionary = p._AerialLanding.resolve_land_hit(
		contact, h_before, h1, p.air_vel_y, sweep, hole_lower
	)
	if bool(resolved.get("need_sweep", false)):
		sweep = p._level.sample_sweep(p.depth.logical_x, p.depth.logical_z, h_before, h1)
		resolved = p._AerialLanding.resolve_land_hit(
			contact, h_before, h1, p.air_vel_y, sweep, hole_lower
		)
	if bool(resolved.get("need_hole_lower", false)):
		var hole_h := float(resolved.get("hole_h", 0.0))
		hole_lower = p._level.sample(
			p.depth.logical_x, p.depth.logical_z, -1, NAN, hole_h - 2.0
		)
		resolved = p._AerialLanding.resolve_land_hit(
			contact, h_before, h1, p.air_vel_y, sweep, hole_lower
		)
	if not bool(resolved.get("land", false)):
		return false

	var land_hit: Dictionary = resolved.get("land_hit", {})
	var floor_h := float(resolved.get("floor_h", 0.0))
	if land_hit.is_empty():
		return false
	if p._AerialLanding.should_reject_land(
		land_hit,
		p._acid_drop_lock,
		p._is_exit_pipe_hit(land_hit),
		p._air_side,
		p._air_lip_x,
		p._spine_transfer_lock,
		p._air_base_height,
	):
		return false

	p.air_abs_height = floor_h
	var pin_x: float = p._AerialLanding.land_pin_x(
		p.depth.logical_x, p._air_x_locked, p._air_coping_x, p._air_radius
	)
	var apply: Dictionary = p._AerialLanding.compute_land_apply(
		land_hit,
		floor_h,
		p.depth.logical_x,
		pin_x,
		p._velocity.x,
		p.air_vel_y,
		p._air_x_locked,
		p._acid_drop_lock,
		p._acid_travel_x,
		p._flew_out_this_aerial,
		p._acid_pressed_this_aerial,
		p._exit_travel_x,
		p._air_carry_speed,
	)
	p._clear_air()
	return p._commit_land_apply(apply, land_hit, delta, speed_mul)

static func apply_surface(p) -> void:
	if p._level == null:
		p.last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		p.depth.surface_height = 0.0
		p.depth.height_offset = 0.0
		p.depth.airborne = false
		p.depth.support_height = 0.0
		p._clear_air()
		p._refresh_head_debug()
		return

	p.last_surface = p._sample_underfoot()
	var zone := str(p.last_surface.get("zone", "flat"))
	if zone == "oob":
		p._clamp_pose_playable()
		p.last_surface = p._sample_underfoot()
		zone = str(p.last_surface.get("zone", "flat"))
		if zone == "oob":
			p.last_surface = p.last_surface.duplicate()
			p.last_surface["zone"] = "flat"
			p.last_surface["active"] = true
			zone = "flat"

	if p._airborne:
		p.last_surface = p._PlayerSurface.decorate_air_surface(
			p.last_surface, p.air_over, p._air_over_layer, p.air_abs_height
		)
		p.depth.surface_height = p.air_abs_height
		p.depth.height_offset = 0.0
		p.depth.airborne = true
		p.depth.support_height = p._underlying_surface_height()
	else:
		p.depth.height_offset = 0.0
		p.depth.airborne = false
		if not p.last_surface.get("active", true) and (zone == "oob" or zone == "hole"):
			p._try_ride_off_air(p.depth.surface_height)
			if p._airborne:
				p.last_surface = p._PlayerSurface.decorate_air_surface(
					p.last_surface, p.air_over, p._air_over_layer, p.air_abs_height
				)
				p.depth.surface_height = p.air_abs_height
				p.depth.height_offset = 0.0
				p.depth.airborne = true
				p.depth.support_height = p._underlying_surface_height()
				p._refresh_head_debug()
				return
			p.depth.support_height = p.depth.surface_height
		else:
			var sample_h := float(p.last_surface.get("height", 0.0))
			if p._PlayerSurface.should_follow_sample_height(
				p._on_ramp, sample_h, p.depth.surface_height, p.ride_off_height_eps
			):
				p.depth.surface_height = sample_h
			p.depth.support_height = p.depth.surface_height

	p._refresh_head_debug()

static func try_acid_drop(p, from_hold: bool = false) -> void:
	if not p._airborne or p._level == null or not p._acid_drop_available:
		return
	# Rising/apex → transfer — except after fly-out (apex of the parabola must
	# still acid; transfer_vert_ok would otherwise no-op the press).
	if p._transfer_vert_ok() and not p._flew_out_this_aerial:
		return
	# ACTUAL → exit outward → MOMENTUM. Stick-MOMENTUM must not beat exit travel
	# (that cast acid back into the bowl after a fly-out).
	var travel_x: float = p._AerialMath.resolve_acid_travel_x(
		p._actual_vel_x, p._velocity.x, p._exit_travel_x
	)
	if absf(travel_x) < 1.0:
		return
	var hit: Dictionary = p._find_acid_coping_target(travel_x)
	if hit.is_empty():
		# Hold buffer: wait until a cast cell shows a coping — don't unlock / abort.
		if from_hold:
			return
		# Press with no forward coping: unlock exit pin and keep travel velocity.
		p._acid_pressed_this_aerial = true
		p._acid_travel_x = travel_x
		p._acid_abort_without_reverse(travel_x)
		return

	# Mark press once we commit to a lerp.
	p._acid_pressed_this_aerial = true
	p._acid_travel_x = travel_x

	var lock: Dictionary = p._AerialTransfer.resolve_acid_lock(
		hit, p.depth.logical_x, travel_x, p.depth.logical_x
	)
	if not bool(lock.get("ok", false)):
		if from_hold:
			return
		p._acid_abort_without_reverse(travel_x)
		return

	var side: int = int(lock.side)
	var radius: float = float(lock.radius)
	var coping: float = float(lock.coping_x)
	p._apply_air_patch(
		p._PlayerAirState.coping_lock_patch(
			lock, true, false, p._layer_index_for_base(float(lock.base_height))
		)
	)
	p._note_air_carry()
	p._preserve_acid_travel_velocity()

	p._begin_transfer_x_lerp(coping, true, radius)
	if not p._AerialMath.acid_coping_ahead(p._settle.x_from, p._settle.x_to, travel_x) \
			and absf(p._settle.x_to - p._settle.x_from) > 0.05:
		p._settle.x_active = false
		p._acid_drop_lock = false
		if from_hold:
			return
		p._acid_abort_without_reverse(travel_x)
		return

	p._acid_drop_available = false

static func find_facing_coping_target(p, facing_override: String = "") -> Dictionary:
	if p._level == null or p._level.spec == null:
		return {}
	var cell: Vector2i = p.cell_under_feet()
	var xz: Vector2 = p.cell_sample_xz()
	var facing := facing_override
	if facing != "l" and facing != "r":
		facing = p.facing_h
	if facing != "l" and facing != "r":
		facing = "r"
	var ex: Dictionary = p._PlayerAirState.facing_exclude(
		p._exit_pipe_side,
		p._exit_pipe_lip,
		p._exit_pipe_z_min,
		p._exit_pipe_z_max,
		p._air_x_locked,
		p.air_over,
		p._air_side,
		p._air_lip_x,
		p._air_z_min,
		p._air_z_max,
		p._on_ramp,
		p._ramp_side,
		p._ramp_lip_x,
		p._ramp_z_min,
		p._ramp_z_max,
	)
	return p._AerialTargeting.find_facing_coping_target(
		p._level.spec,
		p._level.pipes,
		cell,
		xz.y,
		p._feet_height(),
		facing,
		p.facing_coping_cells,
		int(ex.side),
		float(ex.lip_x),
		float(ex.z_min),
		float(ex.z_max),
	)

static func try_transfer(p) -> bool:
	if p._flew_out_this_aerial:
		return false
	if not p._airborne or p._level == null or not p._transfer_available:
		return false
	# Rising, or apex after rise (vert≈0 with last non-zero up).
	if not p._transfer_vert_ok():
		return false
	var was_locked: bool = p._air_x_locked
	var behind: float = p._transfer_behind_sign
	if p._air_x_locked:
		behind = p._coping_sign(p._air_side)
	elif behind == 0.0:
		return false
	var probe_from_x: float = p._air_coping_x if p._air_x_locked else p.depth.logical_x
	var probe_x: float = probe_from_x + behind * p.transfer_probe
	var exclude_side: int = p._air_side
	var exclude_lip: float = p._air_lip_x
	var hit: Dictionary = p._level.sample_transfer(
		probe_x, p.depth.logical_z, exclude_side, exclude_lip, p.air_abs_height
	)
	# Tight spine / gap: probe may land on flat between facing copings — pick the
	# nearest opposite pipe in the behind direction when no deck claimed the spot.
	if not p._ContactMath.is_pipe(hit) and str(hit.get("zone", "")) != "deck":
		var pipe_hit: Dictionary = p._find_pipe_behind(probe_from_x, behind, exclude_side, exclude_lip)
		if not pipe_hit.is_empty():
			hit = pipe_hit
	# Pipe-exit lock: only commit to a real destination (deck / foreign pipe).
	# Flat/hole/oob probes used to call _begin_air_over and zero p.air_vel_y — felt
	# like a dead-stop drop when spine/fly-out were both unavailable (level edge).
	if was_locked and not p._AerialTransfer.hit_is_meaningful(hit):
		return false
	var pipe_r := 0.0
	if p._ContactMath.is_pipe(hit):
		pipe_r = p._pipe_radius_for_hit(hit)
	var built: Dictionary = p._AerialTransfer.build_begin_air_target(hit, probe_x, pipe_r)
	var target: Dictionary = built.get("target", {})
	var anchor_x: float = float(built.get("anchor_x", probe_x))
	var keep_h: float = p.air_abs_height

	p._begin_air_over(target, keep_h, false)
	p._transfer_available = false

	# Locked pipe air spent stick X on height — release it as free-air horizontal.
	if was_locked:
		p._velocity.x = behind * maxf(absf(p._velocity.x), p.transfer_release_min)
		p._settle.x_active = false
		return true

	p._begin_transfer_x_lerp(anchor_x, false)
	if not p._settle.x_active and p._air_x_locked:
		p.depth.logical_x = p._air_coping_x
	return true



static func apply_locked_air_motion(p, delta: float, speed_mul: float) -> void:
	if not p._settle.x_active:
		p.depth.logical_x = p._air_coping_x
	p._clamp_pose_playable()
	p._commit_xz(p.depth.logical_x, p.depth.logical_z + p._velocity.y * speed_mul * delta)
	if DebugTools.god_mode:
		p._resolve_and_apply_air_contact(p.air_abs_height)
		p.air_vel_y = 0.0
		return
	var prev_air_vy: float = p.air_vel_y
	var h_before: float = p.air_abs_height
	var contact: Dictionary = p._resolve_and_apply_air_contact(h_before)
	p._integrate_air_gravity(delta)
	p._try_apex_facing_flip(prev_air_vy)
	if p._try_fly_out_from_pipe_lock():
		if not p._settle.x_active:
			p._commit_xz(
				p.depth.logical_x + p._velocity.x * speed_mul * delta,
				p.depth.logical_z
			)
		contact = p._resolve_and_apply_air_contact(h_before)
	p._try_land_from_air_contact(contact, h_before, delta, speed_mul)


static func apply_free_air_motion(p, delta: float, speed_mul: float) -> void:
	if not p._settle.x_active:
		p._commit_xz(
			p.depth.logical_x + p._velocity.x * speed_mul * delta,
			p.depth.logical_z + p._velocity.y * speed_mul * delta
		)
	else:
		p._commit_xz(p.depth.logical_x, p.depth.logical_z + p._velocity.y * speed_mul * delta)
	if p._air_over_uses_gravity():
		var h_before_free: float = p.air_abs_height
		var contact_free: Dictionary = p._resolve_and_apply_air_contact(h_before_free)
		p._integrate_air_gravity(delta)
		p._try_land_from_air_contact(contact_free, h_before_free, delta, speed_mul)
	else:
		p._resolve_and_apply_air_contact(p.air_abs_height)


static func try_ride_off_air(p, prev_support_h: float) -> void:
	if p._airborne or p._level == null:
		return
	var under: Dictionary = p._level.sample(
		p.depth.logical_x, p.depth.logical_z, -1, NAN, prev_support_h
	)
	var zone := str(under.get("zone", "flat"))
	var has_support: bool = (
		bool(under.get("active", true))
		and zone != "hole"
		and zone != "oob"
	)
	var new_h := 0.0
	if has_support:
		new_h = float(under.get("height", 0.0))
	if new_h >= prev_support_h - p.ride_off_height_eps:
		return
	if zone == "oob" or zone == "hole":
		zone = "flat"
	var target := {"zone": zone, "lock_x": false, "anchor_x": p.depth.logical_x}
	if p._ContactMath.is_pipe(under) and has_support:
		target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
		target["lip_x"] = float(under.get("lip_x", p.depth.logical_x))
		target["radius"] = p._pipe_radius_for_hit(under)
		target["base_height"] = float(under.get("base_height", 0.0))
		target["layer"] = int(under.get("layer", -1))
	p._begin_air_over(target, prev_support_h, false)


static func try_spine_transfer(p, _from_hold_buffer: bool = false) -> bool:
	if p._flew_out_this_aerial:
		return false
	if p._level == null or not p._transfer_available:
		return false
	var from_ramp: bool = (not p._airborne) and p._on_ramp and p._ramp_rising_toward_coping()
	if p._airborne:
		if not p._transfer_vert_ok():
			return false
	elif not from_ramp:
		return false
	var hit: Dictionary = p._find_facing_coping_target()
	if hit.is_empty():
		return false
	if not p._AerialTransfer.spine_feet_clear_dest(p._feet_height(), hit):
		return false
	p._note_air_carry()
	var carry: float = p._air_carry_speed
	if not p._airborne:
		p._launch_air_for_spine_from_ramp()
		p._note_air_carry()
		carry = p._air_carry_speed
	p._apply_spine_lock(hit, carry)
	return true
