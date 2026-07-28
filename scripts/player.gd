extends Node
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## Air over any zone. Coping exit locks X (gravity applies); acid drop locks X only.
## Ride-off a higher surface → free air (keep height + gravity). All sim on physics ticks.
## Plain Node: Canvas2D pose lived on Node2D; 3D reads PseudoDepthBody logicals.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")
const _AerialSettle := preload("res://scripts/aerial_settle.gd")
const _AerialTargeting := preload("res://scripts/aerial_targeting.gd")
const _AerialLanding := preload("res://scripts/aerial_landing.gd")
const _AerialContact := preload("res://scripts/aerial_contact.gd")
const _AerialTransfer := preload("res://scripts/aerial_transfer.gd")
const _FacingCastMath := preload("res://scripts/facing_cast_math.gd")
const _MotionVectors := preload("res://scripts/motion_vectors.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")
const _GroundPipeMath := preload("res://scripts/ground_pipe_math.gd")
const _GroundMotion := preload("res://scripts/ground_motion.gd")
const _PlayerPipeHits := preload("res://scripts/player_pipe_hits.gd")
const _PlayerDeath := preload("res://scripts/player_death.gd")
const _PlayerMotionDebug := preload("res://scripts/player_motion_debug.gd")

@export var max_speed_x: float = 880.0

@export var max_speed_z: float = 400.0
@export var acceleration: float = 3250.0
## Coast rate when no input (logical u/s²). Debug slider writes this.
@export var friction: float = 0.0
## Opposite-stick brake rate (logical u/s²). Much stronger than friction. Debug slider writes this.
@export var brake: float = 1250.0
## THPS-style forward accel while holding ollie (logical units/s²). Debug slider writes this.
@export var ollie_accel: float = 650.0
@export var depth_speed_feel: bool = true
@export var level_path: NodePath = NodePath("../RampLevel")
## How far past the coping to probe for transfer targets.
@export var transfer_probe: float = 8.0
## Physics-time duration for transfer horizontal settle.
@export var transfer_x_duration: float = 0.15
## Min free-air |vx| when releasing locked pipe air via transfer.
@export var transfer_release_min: float = 260.0
## Gravity while in unlocked air (m/s²). Debug slider writes this.
@export var gravity_ms2: float = -19.0
## Convert m/s² into logical units/s².
@export var logic_per_meter: float = 100.0
## Feet must drop at least this far below prior support to ride off into air.
@export var ride_off_height_eps: float = 0.5
## Acid/spine: max cells ahead along travel/facing cast to accept a top coping.
## Tuned via TUNING "acid cells" — independent of facing-cast debug draw distance.
@export_range(1, 16, 1) var facing_coping_cells: int = 6
## Acid/spine X settle seconds at coping (height-above = 0).
@export var acid_drop_x_duration: float = 0.18
## Extra settle seconds per logical unit of height above coping.
@export var acid_drop_x_duration_per_height: float = 0.002
## Soft cap on acid/spine settle (0 = uncapped).
@export var acid_drop_x_duration_max: float = 0.9
## God-mode vertical speed (logical units/s) for j/k. Debug only.
@export var god_vert_speed: float = 320.0
## Along-arc speed drain while on a pipe (logical u/s²). Debug slider writes this.
@export var ramp_friction: float = 0.0
## Pipe-exit X-lock fly-out: max height above coping (logical) where unlock is
## still allowed. Higher = can fly out farther up the air; 1 keeps it near the lip.
## INPUT must point toward that pipe's side. Debug slider writes this.
@export var fly_out_above_coping: float = 40.0

@onready var depth: PseudoDepthBody = $PseudoDepthBody
## Optional Canvas2D debug widgets (absent in the 3D-only gameplay scene).
var _head_debug_label: Label = null
var _head_debug_panel: Control = null
var _face_nose: Polygon2D = null

var _velocity: Vector2 = Vector2.ZERO
## Last physics-tick control acceleration (d(_velocity)/dt from integrate).
var _debug_accel: Vector2 = Vector2.ZERO
## Along-arc speed while on a pipe (world-X signed). Stick integrates against this;
## `_velocity.x` is the remaining horizontal component `along * cos(θ)` after projection.
var _ramp_along: float = 0.0
var _on_ramp: bool = false
## Sticky pipe identity while riding — adjacent opposite pipes share coping X.
var _ramp_side: int = QuarterPipe.PipeSide.RIGHT
var _ramp_lip_x: float = 0.0
var _ramp_base_height: float = 0.0
var _ramp_z_min: float = NAN
var _ramp_z_max: float = NAN
var _level: RampLevel
var last_surface: Dictionary = {}

var _airborne: bool = false
## Absolute logical feet height while airborne.
var air_abs_height: float = 0.0
## Vertical velocity while airborne (logic units/s); used for gravity.
var air_vel_y: float = 0.0
## Zone underneath while airborne (left_pipe / right_pipe / deck / flat).
var air_over: String = ""
## Layer index for current air_over surface (-1 unknown).
var _air_over_layer: int = -1
var _air_x_locked: bool = false
var _air_side: int = QuarterPipe.PipeSide.RIGHT
var _air_lip_x: float = 0.0
var _air_coping_x: float = 0.0
var _air_radius: float = 150.0
var _air_base_height: float = 0.0
var _air_z_min: float = NAN
var _air_z_max: float = NAN
## Pipe identity exited this aerial — keep excluding after fly-out / flat air_over.
var _exit_pipe_side: int = -1
var _exit_pipe_lip: float = NAN
var _exit_pipe_coping: float = NAN
var _exit_pipe_z_min: float = NAN
var _exit_pipe_z_max: float = NAN
## Last horizontal travel when leaving a pipe (outward). Acid fallback if vx≈0.
var _exit_travel_x: float = 0.0
## Travel sign locked at acid start — never allow horiz vx to flip against this.
var _acid_travel_x: float = 0.0
## True after pipe fly-out this aerial — land must not yank back into the exit wall.
var _flew_out_this_aerial: bool = false
## Set only after riding through a pipe's coping into pipe-exit air.
## Intent fly-out must not trigger from another locked-air path.
var _crossed_pipe_coping_this_aerial: bool = false
## True after acid button this aerial (hit or miss) — never into-bowl reverse on exit.
var _acid_pressed_this_aerial: bool = false
## Last behind-sign used for transfer probes when unlocked.
var _transfer_behind_sign: float = 1.0

## Transfer-X + body-tilt settle (acid / spine / free transfer).
var _settle := _AerialSettle.new()
## Displayed body tilt (radians); lerps toward target / transfer endpoints.
var _body_tilt: float = 0.0
## One transfer per aerial; replenished on any surface contact.
var _transfer_available: bool = true
## One acid drop per aerial; replenished on any surface contact.
var _acid_drop_available: bool = true
## X-locked via acid drop: pin to coping; gravity continues (same as coping lock).
var _acid_drop_lock: bool = false
## Spine transfer: X-lock to opposite coping; land converts vert → along-arc (drop-in).
var _spine_transfer_lock: bool = false
## Peak |along|/|air_vy|/|vx| this aerial — survives gravity climb for low→high drop-in.
var _air_carry_speed: float = 0.0
## Once per locked aerial: facing flip (or stick override) at vertical apex.
var _apex_facing_done: bool = false
## Measured actual velocity from position deltas (not stick / momentum).
var _actual_vel_x: float = 0.0
var _actual_vel_z: float = 0.0
var _vert_vel: float = 0.0
## Last non-zero measured vertical rate (for apex: vert==0 but still "rising").
var _last_nonzero_vert_vel: float = 0.0
var _prev_logical_x: float = 0.0
var _prev_logical_z: float = 0.0
var _prev_feet_h: float = 0.0
## Last physics-tick stick input (X = horiz, Y = depth Z). Debug input arrow.
var _last_input: Vector2 = Vector2.ZERO
## Horizontal facing: "l" or "r". Spawn default from level (usually r).
var facing_h: String = "r"
## Grounded on lava — freeze sim until death overlay finishes + respawn.
var _dead: bool = false
## Last grounded floor/deck pad (respawn). Seeded from `@` spawn.
var _safe_x: float = 640.0
var _safe_z: float = 40.0
var _safe_h: float = 0.0
var _safe_facing: String = "r"
var _death_overlay: Node = null


func _ready() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	_face_nose = get_node_or_null("Body/FaceNose") as Polygon2D
	_head_debug_label = get_node_or_null("Body/HeadDebug/Label") as Label
	_head_debug_panel = get_node_or_null("Body/HeadDebug") as Control
	var head_dbg := _head_debug_panel
	if head_dbg:
		head_dbg.add_to_group("debug_tools")
		if not DebugTools.is_available():
			head_dbg.queue_free()
			_head_debug_label = null
			_head_debug_panel = null
		else:
			_apply_head_debug_visible(DebugTools.show_head_debug)
			if not DebugTools.show_head_debug_changed.is_connected(_apply_head_debug_visible):
				DebugTools.show_head_debug_changed.connect(_apply_head_debug_visible)
	_ensure_death_overlay()
	call_deferred("_spawn_from_level")


func _ensure_death_overlay() -> void:
	# Prefer scene-baked overlay on the gameplay root (parent), not current_scene
	# (tests may parent Main under root without setting current_scene).
	var host: Node = get_parent()
	if host != null:
		var baked := host.get_node_or_null("DeathOverlay")
		if baked != null:
			_death_overlay = baked
			return
	_death_overlay = get_tree().get_first_node_in_group("death_overlay")
	if _death_overlay != null:
		return
	if host == null:
		host = get_tree().current_scene
	var overlay_script: Script = load("res://scripts/death_overlay.gd") as Script
	if overlay_script == null:
		return
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.set_script(overlay_script)
	overlay.add_to_group("death_overlay")
	if host:
		host.add_child.call_deferred(overlay)
	_death_overlay = overlay


func _spawn_from_level() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level and not _level.rebuilt.is_connected(_on_level_rebuilt):
		_level.rebuilt.connect(_on_level_rebuilt)
	_apply_spawn_from_level()


func _on_level_rebuilt() -> void:
	_apply_spawn_from_level()


func _apply_spawn_from_level() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level and _level.spec:
		depth.logical_x = _level.spec.spawn_x
		depth.logical_z = _level.spec.spawn_z
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
		facing_h = _normalize_facing(_level.spec.spawn_facing)
		# Stand on the `@` story (may be L1+), not always height 0.
		var spawn_h := float(_level.spec.spawn_height)
		depth.surface_height = spawn_h
		depth.support_height = spawn_h
		_remember_safe_pad(depth.logical_x, depth.logical_z, spawn_h, facing_h)
	else:
		depth.logical_x = 640.0
		depth.logical_z = 40.0
		facing_h = "r"
		depth.surface_height = 0.0
		depth.support_height = 0.0
		_remember_safe_pad(640.0, 40.0, 0.0, "r")
	_dead = false
	_reset_all_motion()
	_clear_air()
	_apply_surface()
	_prev_logical_x = depth.logical_x
	_prev_logical_z = depth.logical_z
	_prev_feet_h = _feet_height()
	_refresh_head_debug()
	_update_face_nose()
	_step_body_tilt(0.0)
	depth.apply()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel

	_tick_debug_god_input()
	_tick_transfer_press()
	_tick_integrate_input(delta)
	_tick_apply_world_motion(delta)
	_tick_clamp_playable_bounds()
	_apply_surface()
	_note_safe_pad_from_surface()
	if _try_lava_death():
		_step_body_tilt(0.0)
		depth.apply()
		return
	_update_actual_velocity(delta)
	_tick_transfer_hold()
	_clear_momentum_if_at_rest()
	_step_body_tilt(delta)
	depth.apply()


func _tick_debug_god_input() -> void:
	if DebugTools.is_available() and Input.is_action_just_pressed("god_mode_toggle"):
		DebugTools.toggle_god_mode()
		if DebugTools.god_mode:
			air_vel_y = 0.0


func _tick_transfer_press() -> void:
	if Input.is_action_just_pressed("transfer"):
		_try_air_action()


func _tick_integrate_input(delta: float) -> void:
	var input := _read_move_input()
	_last_input = input
	# Stick must accelerate along-arc speed, not the post-projection horizontal remnant.
	if _on_ramp:
		_velocity.x = _ramp_along
	_update_facing_h(input)
	_update_face_nose()
	_integrate_velocity(input, delta)
	if _on_ramp:
		_ramp_along = _velocity.x
	_clamp_momentum_to_max_speed()


func _tick_apply_world_motion(delta: float) -> void:
	var speed_mul := depth.depth_speed_multiplier() if depth_speed_feel else 1.0
	_apply_motion(delta, speed_mul)
	_clamp_momentum_to_max_speed()
	_step_god_vertical(delta)


func _tick_clamp_playable_bounds() -> void:
	if _level:
		depth.logical_x = clampf(depth.logical_x, _level.x_min(), _level.x_max())
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	else:
		depth.logical_x = clampf(depth.logical_x, 80.0, 1200.0)


func _tick_transfer_hold() -> void:
	# Hold into a ramp / fall: auto-fire spine while rising, acid when cast sees a
	# coping while falling (or after fly-out). Press still goes through _try_air_action.
	if not Input.is_action_pressed("transfer") or not _airborne:
		return
	if _flew_out_this_aerial or not _transfer_vert_ok():
		_try_acid_drop(true)
	elif not _flew_out_this_aerial:
		_try_spine_transfer(true)


func _remember_safe_pad(x: float, z: float, h: float, face: String) -> void:
	_safe_x = x
	_safe_z = z
	_safe_h = h
	_safe_facing = _normalize_facing(face)


func _note_safe_pad_from_surface() -> void:
	if _airborne or last_surface.is_empty():
		return
	if not ContactMath.is_safe_pad(last_surface):
		return
	_remember_safe_pad(
		depth.logical_x,
		depth.logical_z,
		float(last_surface.get("height", depth.surface_height)),
		facing_h,
	)


func _reset_all_motion() -> void:
	_velocity = Vector2.ZERO
	_ramp_along = 0.0
	_debug_accel = Vector2.ZERO
	_actual_vel_x = 0.0
	_actual_vel_z = 0.0
	_vert_vel = 0.0
	_last_nonzero_vert_vel = 0.0
	_air_carry_speed = 0.0
	_last_input = Vector2.ZERO
	air_vel_y = 0.0


## Grounded lava (`aerial=false`, zone lava): red death flash → last safe pad.
func _try_lava_death() -> bool:
	if not _PlayerDeath.should_die_on_lava(_airborne, last_surface):
		return false
	_dead = true
	_reset_all_motion()
	_ensure_death_overlay()
	if _death_overlay != null and _death_overlay.has_method("play"):
		if _death_overlay.has_signal("finished") \
				and not _death_overlay.finished.is_connected(_on_death_overlay_finished):
			_death_overlay.finished.connect(_on_death_overlay_finished, CONNECT_ONE_SHOT)
		_death_overlay.play()
	else:
		_respawn_at_safe_pad()
	return true


func _on_death_overlay_finished() -> void:
	_respawn_at_safe_pad()


func _respawn_at_safe_pad() -> void:
	depth.logical_x = _safe_x
	depth.logical_z = _safe_z
	facing_h = _normalize_facing(_safe_facing)
	depth.surface_height = _safe_h
	depth.support_height = _safe_h
	_on_ramp = false
	_dead = false
	_reset_all_motion()
	_clear_air()
	_apply_surface()
	_prev_logical_x = depth.logical_x
	_prev_logical_z = depth.logical_z
	_prev_feet_h = _feet_height()
	_refresh_head_debug()
	_update_face_nose()
	_step_body_tilt(0.0)
	depth.apply()


func _feet_height() -> float:
	if _airborne:
		return air_abs_height
	return depth.surface_height


func _air_coping_floor() -> float:
	return _air_base_height + _air_radius


## Keep moves inside layer-0 playable footprint (hard boundary). Always commits.
func _commit_xz(next_x: float, next_z: float) -> bool:
	var z := depth.clamp_z(next_z)
	var x := next_x
	if _level and _level.spec:
		var clamped: Vector2 = _level.spec.clamp_to_playable(x, z)
		x = clamped.x
		z = depth.clamp_z(clamped.y)
	depth.logical_x = x
	depth.logical_z = z
	return true


## Snap current pose into playable bounds (coping pin / transfer / pipe move).
func _clamp_pose_playable() -> void:
	if _level == null or _level.spec == null:
		return
	var clamped: Vector2 = _level.spec.clamp_to_playable(depth.logical_x, depth.logical_z)
	depth.logical_x = clamped.x
	depth.logical_z = depth.clamp_z(clamped.y)


func _update_actual_velocity(delta: float) -> void:
	var h := _feet_height()
	if delta > 0.0001:
		_actual_vel_x = (depth.logical_x - _prev_logical_x) / delta
		_actual_vel_z = (depth.logical_z - _prev_logical_z) / delta
		_vert_vel = (h - _prev_feet_h) / delta
	else:
		_actual_vel_x = 0.0
		_actual_vel_z = 0.0
		_vert_vel = 0.0
	if absf(_vert_vel) > 0.5:
		_last_nonzero_vert_vel = _vert_vel
	_prev_logical_x = depth.logical_x
	_prev_logical_z = depth.logical_z
	_prev_feet_h = h


## Drop integrated momentum when ACTUAL speed is ~0 (unless air gravity applies).
func _clear_momentum_if_at_rest() -> void:
	var gravity_applies := _airborne and _air_over_uses_gravity()
	var actual_speed := Vector3(_actual_vel_x, _vert_vel, _actual_vel_z).length()
	if not _MotionMath.should_clear_momentum_at_rest(gravity_applies, actual_speed):
		return
	_velocity = Vector2.ZERO
	_ramp_along = 0.0


func _apply_motion(delta: float, speed_mul: float) -> void:
	if _airborne:
		_clamp_pose_playable()
		_step_transfer_x(delta)
		if _air_x_locked:
			_apply_locked_air_motion(delta, speed_mul)
		else:
			_apply_free_air_motion(delta, speed_mul)
		return

	_apply_grounded_motion(delta, speed_mul)


## X-locked air: pin coping, gravity, optional fly-out, land from shared contact.
func _apply_locked_air_motion(delta: float, speed_mul: float) -> void:
	# Don't pin X while a transfer/acid-drop lerp is carrying us to coping.
	if not _settle.x_active:
		depth.logical_x = _air_coping_x
	_clamp_pose_playable()
	_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)

	# God mode over a coping lock: keep X pin, free height via j/k.
	if DebugTools.god_mode:
		_resolve_and_apply_air_contact(air_abs_height)
		air_vel_y = 0.0
		return

	var prev_air_vy := air_vel_y
	var h_before := air_abs_height
	# Contact after XZ commit — label and collision share this resolve.
	var contact: Dictionary = _resolve_and_apply_air_contact(h_before)
	_integrate_air_gravity(delta)
	_try_apex_facing_flip(prev_air_vy)
	# Fly-out unlocks X but must still run landing this tick.
	if _try_fly_out_from_pipe_lock():
		if not _settle.x_active:
			_commit_xz(
				depth.logical_x + _velocity.x * speed_mul * delta,
				depth.logical_z
			)
		# Re-resolve after X nudge so contact matches new column.
		contact = _resolve_and_apply_air_contact(h_before)
	_try_land_from_air_contact(contact, h_before, delta, speed_mul)


## Unlocked air: free XZ then contact → gravity → land from same contact.
func _apply_free_air_motion(delta: float, speed_mul: float) -> void:
	if not _settle.x_active:
		_commit_xz(
			depth.logical_x + _velocity.x * speed_mul * delta,
			depth.logical_z + _velocity.y * speed_mul * delta
		)
	else:
		_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)
	if _air_over_uses_gravity():
		var h_before_free := air_abs_height
		var contact_free: Dictionary = _resolve_and_apply_air_contact(h_before_free)
		_integrate_air_gravity(delta)
		_try_land_from_air_contact(contact_free, h_before_free, delta, speed_mul)
	else:
		_resolve_and_apply_air_contact(air_abs_height)


func _apply_grounded_motion(delta: float, speed_mul: float) -> void:
	var prev_support_h := depth.surface_height
	_commit_xz(depth.logical_x, depth.logical_z + _velocity.y * speed_mul * delta)

	var hit: Dictionary = _sample_underfoot()
	# A fresh mount belongs to the visible story at the player's feet. Plain
	# height sampling can otherwise choose overlapping L0 lava / coping below an
	# L1 pipe arc before we have a sticky identity.
	if not _on_ramp and _level != null:
		var story_pipe: Dictionary = _level.sample_pipe_on_story(
			depth.logical_x, depth.logical_z, _feet_height()
		)
		if story_pipe.get("active", false):
			hit = story_pipe
	# Sticky ride: never adopt a foreign pipe (stacked L0 at shared L1 coping).
	if _on_ramp:
		var own: Dictionary = _query_own_ramp_surface()
		var current := _ramp_pipe_hit()
		var under: Dictionary = hit
		# Sticky sample refuses fallthrough when inactive — still probe for a
		# competing pipe (plain sample) so we launch instead of remounting it.
		if not own.get("active", false) and not _ContactMath.is_pipe(hit) and _level != null:
			under = _level.sample(
				depth.logical_x, depth.logical_z, -1, NAN, _feet_height()
			)
		var sticky: Dictionary = _GroundMotion.decide_sticky(
			true, own.get("active", false), under, current, _velocity.x, _ramp_side
		)
		var sticky_action := str(sticky.get("action", "leave"))
		if sticky_action == "launch":
			_enter_air_from_pipe(current, float(sticky.get("toward", 0.0)))
			return
		if sticky_action == "leave":
			_leave_ramp_to_flat()
			hit = _sample_underfoot()
		else:
			hit = own
	var solid_pad := _solid_pad_underfoot(prev_support_h)
	var mount: Dictionary = _GroundMotion.decide_mount(
		hit, prev_support_h, _on_ramp, solid_pad, ride_off_height_eps
	)
	if bool(mount.get("allow_pipe", false)):
		if not _on_ramp:
			_ramp_along = _velocity.x
			_on_ramp = true
		_ramp_side = int(hit.get("side", _ramp_side))
		_ramp_lip_x = float(hit.get("lip_x", _ramp_lip_x))
		_ramp_base_height = float(hit.get("base_height", _ramp_base_height))
		_ramp_z_min = float(hit.get("z_min", _ramp_z_min))
		_ramp_z_max = float(hit.get("z_max", _ramp_z_max))
		_apply_ramp_friction(delta)
		_ramp_along = _velocity.x
		var arc_speed := _ramp_along * speed_mul
		_move_along_pipe(hit, arc_speed, delta)
		# Re-sample after move so θ matches feet; project along → horiz remnant.
		if _on_ramp and not _airborne:
			var after_own: Dictionary = _query_own_ramp_surface()
			var after_sample: Dictionary = _sample_underfoot()
			var after_under: Dictionary = after_sample
			if (
				not after_own.get("active", false)
				and not _ContactMath.is_pipe(after_sample)
				and _level != null
			):
				after_under = _level.sample(
					depth.logical_x, depth.logical_z, -1, NAN, _feet_height()
				)
			var after: Dictionary = _GroundMotion.decide_post_move(
				after_own.get("active", false),
				after_own,
				after_under,
				_ramp_pipe_hit(),
				_ramp_along,
				_ramp_side,
			)
			var after_action := str(after.get("action", "leave"))
			if after_action == "ride":
				_project_ramp_velocity(float(after.get("theta", 0.0)))
			elif after_action == "launch":
				_enter_air_from_pipe(_ramp_pipe_hit(), float(after.get("toward", 0.0)))
			else:
				_leave_ramp_to_flat()
		return

	if _on_ramp:
		_leave_ramp_to_flat()
	var flat_arc := _velocity.x * speed_mul
	var next_x: float = depth.logical_x + flat_arc * delta
	var cross := _coping_cross_hit(depth.logical_x, next_x)
	var flat: Dictionary = _GroundMotion.decide_flat_path(
		hit,
		cross,
		solid_pad,
		bool(mount.get("rejected_fresh_coping", false)),
		flat_arc,
	)
	var flat_action := str(flat.get("action", "commit"))
	if flat_action == "ride_off":
		_commit_xz(next_x, depth.logical_z)
		_try_ride_off_air(prev_support_h)
		return
	if flat_action == "coping_launch":
		_enter_air_from_pipe(flat.get("hit", {}), float(flat.get("up_speed", 0.0)))
		return
	_commit_xz(next_x, depth.logical_z)
	_try_ride_off_air(prev_support_h)


func _step_transfer_x(delta: float) -> void:
	if not _settle.x_active:
		return
	var above := maxf(air_abs_height - _air_coping_floor(), 0.0)
	depth.logical_x = _settle.step_x(
		delta,
		depth.logical_x,
		above,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		acid_drop_x_duration_max,
		_acid_drop_lock,
		_acid_travel_x,
	)
	_clamp_pose_playable()


## Start horizontal settle onto `to_x`. Acid/spine: live duration from height
## above coping (`base + rate * h`) + smoothstep. Free transfer: fixed duration,
## linear. Height-scaled also starts a tilt settle (even when X is already on
## the coping).
func _begin_transfer_x_lerp(to_x: float, height_scaled: bool, _coping_radius: float = 0.0) -> void:
	var above := maxf(air_abs_height - _air_coping_floor(), 0.0)
	var active := _settle.begin_x(
		depth.logical_x,
		to_x,
		height_scaled,
		above,
		transfer_x_duration,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		acid_drop_x_duration_max,
	)
	if not active:
		depth.logical_x = to_x
	if height_scaled:
		_begin_tilt_lerp(_body_tilt_target_radians(), true)


## Resolve air contact at current XZ and write air_over / layer / sticky ids from it.
## prefer_h is feet height before this tick's gravity (label = collision source).
## Any X-lock force-stickys to the lock target and never adopts a different
## underfoot pipe (avoids free spine onto a higher coping; press transfer).
func _resolve_and_apply_air_contact(prefer_h: float) -> Dictionary:
	if _level == null:
		return _ContactMath.make_air_contact("oob", -1, 0.0, false, {})
	var sticky: Dictionary = _AerialContact.sticky_query(
		air_over,
		_air_x_locked,
		_air_side,
		_air_lip_x,
		_air_base_height,
		_air_z_min,
		_air_z_max,
	)
	var contact: Dictionary = _level.resolve_air_contact(
		depth.logical_x,
		depth.logical_z,
		prefer_h,
		int(sticky.get("side", -1)),
		float(sticky.get("lip_x", NAN)),
		float(sticky.get("base_height", NAN)),
		_air_x_locked,
		float(sticky.get("z_min", NAN)),
		float(sticky.get("z_max", NAN)),
	)
	var patch: Dictionary = _AerialContact.unlocked_identity_from_contact(
		contact, _air_x_locked
	)
	if not bool(patch.get("apply", false)):
		# Collision/landing uses contact; keep locked coping identity for pin / drop-in.
		return contact

	air_over = str(patch.get("air_over", "flat"))
	_air_over_layer = int(patch.get("air_over_layer", -1))
	var kind := str(patch.get("kind", "plain"))
	if kind == "pipe":
		var chit: Dictionary = patch.get("hit", {})
		_air_side = int(chit.get("side", _air_side))
		_air_lip_x = float(chit.get("lip_x", _air_lip_x))
		_air_radius = _pipe_radius_for_hit(chit)
		_air_base_height = float(chit.get("base_height", _air_base_height))
		_air_z_min = float(chit.get("z_min", _air_z_min))
		_air_z_max = float(chit.get("z_max", _air_z_max))
		_air_coping_x = _coping_x_for(_air_side, _air_lip_x, _air_radius)
		_transfer_behind_sign = _coping_sign(_air_side)
	elif patch.has("air_base_height"):
		_air_base_height = float(patch.get("air_base_height", 0.0))
	return contact


## True when logical X is still on the locked pipe's top coping column.
func _is_aligned_with_air_coping() -> bool:
	var eps := maxf(_air_radius * 0.05, 2.0)
	return absf(depth.logical_x - _air_coping_x) <= eps


## Apply pipe identity from a sample hit. `keep_lock` pins X to that pipe's coping.
func _adopt_air_pipe_from_hit(under: Dictionary, keep_lock: bool) -> void:
	var id: Dictionary = _AerialContact.pipe_identity_from_hit(
		under,
		_air_side,
		_air_lip_x,
		_air_base_height,
		_air_z_min,
		_air_z_max,
		_pipe_radius_for_hit(under),
		_layer_index_for_base(float(under.get("base_height", _air_base_height))),
	)
	air_over = str(id.get("air_over", air_over))
	_air_side = int(id.get("air_side", _air_side))
	_air_lip_x = float(id.get("air_lip_x", _air_lip_x))
	_air_radius = float(id.get("air_radius", _air_radius))
	_air_base_height = float(id.get("air_base_height", _air_base_height))
	_air_z_min = float(id.get("air_z_min", _air_z_min))
	_air_z_max = float(id.get("air_z_max", _air_z_max))
	_air_coping_x = float(id.get("air_coping_x", _air_coping_x))
	_transfer_behind_sign = float(id.get("transfer_behind_sign", _transfer_behind_sign))
	_air_over_layer = int(id.get("air_over_layer", _air_over_layer))
	if keep_lock:
		_air_x_locked = true
		if not _settle.x_active:
			depth.logical_x = _air_coping_x
		_clamp_pose_playable()


func _air_over_uses_gravity() -> bool:
	# All air modes use gravity except god mode (vertical via j/k).
	return not DebugTools.god_mode


func _integrate_air_gravity(delta: float) -> void:
	if DebugTools.god_mode:
		air_vel_y = 0.0
		return
	air_vel_y += gravity_ms2 * logic_per_meter * delta
	air_abs_height += air_vel_y * delta
	_note_air_carry()


## Bump peak aerial carry (never shrinks). Used so low→high spine keeps exit speed.
func _note_air_carry(extra: float = 0.0) -> void:
	_air_carry_speed = max(
		_air_carry_speed,
		absf(extra),
		absf(air_vel_y),
		absf(_velocity.x),
		absf(_ramp_along),
	)


## Debug god mode: j/k change height; take off from ground with k.
func _step_god_vertical(delta: float) -> void:
	if not DebugTools.is_available() or not DebugTools.god_mode:
		return
	var v := Input.get_axis("god_down", "god_up")
	if is_zero_approx(v):
		return
	if not _airborne:
		if v <= 0.0:
			return
		var under: Dictionary = (
			_level.sample(depth.logical_x, depth.logical_z, -1, NAN, depth.surface_height)
			if _level else {}
		)
		var zone := str(under.get("zone", "flat"))
		if zone == "oob":
			zone = "flat"
		var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
		if _ContactMath.is_pipe(under):
			target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
			target["lip_x"] = float(under.get("lip_x", depth.logical_x))
			target["radius"] = _pipe_radius_for_hit(under)
			target["base_height"] = float(under.get("base_height", 0.0))
			target["layer"] = int(under.get("layer", -1))
		_begin_air_over(target, depth.surface_height, false)
		air_vel_y = 0.0
	var h_before_god := air_abs_height
	air_abs_height += v * god_vert_speed * delta
	air_vel_y = 0.0
	if v < 0.0:
		air_vel_y = -0.01
		var contact: Dictionary = _resolve_and_apply_air_contact(h_before_god)
		_try_land_from_air_contact(contact, h_before_god, delta, 1.0)
		air_vel_y = 0.0


func _underlying_surface_height() -> float:
	if _level == null:
		return 0.0
	# Spine lock keeps air_over on the target pipe while X lerps across a deck.
	# Sample underfoot with no sticky so the shadow sits on the pad, not the pipe.
	var use_sticky := (not _spine_transfer_lock) and (
		air_over == "left_pipe" or air_over == "right_pipe"
	)
	var contact: Dictionary = _level.resolve_air_contact(
		depth.logical_x,
		depth.logical_z,
		air_abs_height,
		_air_side if use_sticky else -1,
		_air_lip_x if use_sticky else NAN,
		_air_base_height if use_sticky else NAN,
		false,
		_air_z_min if use_sticky else NAN,
		_air_z_max if use_sticky else NAN,
	)
	if _ContactMath.is_air_contact_solid(contact):
		return float(contact.get("height", 0.0))
	# Hole / oob: shadow on next solid below via sample.
	var resolved: Dictionary = _level.sample_sweep(
		depth.logical_x, depth.logical_z, air_abs_height, air_abs_height
	)
	return float(resolved.get("height", 0.0))


## Land using the same air contact that drives the label. Solid contact is hard —
## never tunnel through. Hole skips this story; may catch a lower solid in the sweep.
func _try_land_from_air_contact(
	contact: Dictionary, h_before: float, delta: float, speed_mul: float
) -> bool:
	if _level == null:
		return false
	var h1 := air_abs_height
	var sweep: Dictionary = {}
	var hole_lower: Dictionary = {}
	var resolved: Dictionary = _AerialLanding.resolve_land_hit(
		contact, h_before, h1, air_vel_y, sweep, hole_lower
	)
	if bool(resolved.get("need_sweep", false)):
		sweep = _level.sample_sweep(depth.logical_x, depth.logical_z, h_before, h1)
		resolved = _AerialLanding.resolve_land_hit(
			contact, h_before, h1, air_vel_y, sweep, hole_lower
		)
	if bool(resolved.get("need_hole_lower", false)):
		var hole_h := float(resolved.get("hole_h", 0.0))
		hole_lower = _level.sample(
			depth.logical_x, depth.logical_z, -1, NAN, hole_h - 2.0
		)
		resolved = _AerialLanding.resolve_land_hit(
			contact, h_before, h1, air_vel_y, sweep, hole_lower
		)
	if not bool(resolved.get("land", false)):
		return false

	var land_hit: Dictionary = resolved.get("land_hit", {})
	var floor_h := float(resolved.get("floor_h", 0.0))
	if land_hit.is_empty():
		return false
	if _AerialLanding.should_reject_land(
		land_hit,
		_acid_drop_lock,
		_is_exit_pipe_hit(land_hit),
		_air_side,
		_air_lip_x,
		_spine_transfer_lock,
		_air_base_height,
	):
		return false

	air_abs_height = floor_h
	var pin_x := _AerialLanding.land_pin_x(
		depth.logical_x, _air_x_locked, _air_coping_x, _air_radius
	)
	var was_locked := _air_x_locked
	var was_acid := _acid_drop_lock
	var acid_travel := _acid_travel_x
	var flew_out := _flew_out_this_aerial
	var acid_pressed := _acid_pressed_this_aerial
	var exit_travel := _exit_travel_x
	var land_vy := air_vel_y
	var approach_x := _velocity.x
	var carry_peak := _air_carry_speed
	var logical_x := depth.logical_x
	_clear_air()

	var apply: Dictionary = _AerialLanding.compute_land_apply(
		land_hit,
		floor_h,
		logical_x,
		pin_x,
		approach_x,
		land_vy,
		was_locked,
		was_acid,
		acid_travel,
		flew_out,
		acid_pressed,
		exit_travel,
		carry_peak,
	)
	var kind := str(apply.get("kind", "other"))
	if kind == "solid":
		depth.surface_height = float(apply.floor_h)
		depth.logical_x = float(apply.logical_x)
		_velocity.x = float(apply.vx)
		_on_ramp = false
		return true
	if kind == "pipe":
		_ramp_along = float(apply.ramp_along)
		_velocity.x = float(apply.vx)
		_on_ramp = true
		_ramp_side = int(apply.ramp_side)
		_ramp_lip_x = float(apply.ramp_lip_x)
		_ramp_base_height = float(apply.ramp_base_height)
		_ramp_z_min = float(apply.ramp_z_min)
		_ramp_z_max = float(apply.ramp_z_max)
		depth.surface_height = float(apply.floor_h)
		if bool(apply.move_along):
			_move_along_pipe(land_hit, float(apply.ramp_along) * speed_mul, delta)
		else:
			depth.logical_x = float(apply.logical_x)
		return true

	depth.surface_height = float(apply.floor_h)
	depth.logical_x = float(apply.logical_x)
	return true


## Leave a higher support surface into free air (keep height, apply gravity).
func _try_ride_off_air(prev_support_h: float) -> void:
	if _airborne or _level == null:
		return
	var under: Dictionary = _level.sample(
		depth.logical_x, depth.logical_z, -1, NAN, prev_support_h
	)
	var zone := str(under.get("zone", "flat"))
	# Hole / empty: no support on this story. Never treat as standing surface.
	var has_support: bool = (
		bool(under.get("active", true))
		and zone != "hole"
		and zone != "oob"
	)
	var new_h := 0.0
	if has_support:
		new_h = float(under.get("height", 0.0))
	if new_h >= prev_support_h - ride_off_height_eps:
		return
	if zone == "oob" or zone == "hole":
		zone = "flat"
	var target := {"zone": zone, "lock_x": false, "anchor_x": depth.logical_x}
	if _ContactMath.is_pipe(under) and has_support:
		target["side"] = int(under.get("side", QuarterPipe.PipeSide.RIGHT))
		target["lip_x"] = float(under.get("lip_x", depth.logical_x))
		target["radius"] = _pipe_radius_for_hit(under)
		target["base_height"] = float(under.get("base_height", 0.0))
		target["layer"] = int(under.get("layer", -1))
	_begin_air_over(target, prev_support_h, false)


## True when feet are on a solid floor/deck pad (not a hole). Blocks fake
## pipe-exit pops when an upper story sits at layer-0 coping height.
func _solid_pad_underfoot(feet_h: float) -> bool:
	if _level == null or _level.spec == null:
		return false
	var eps := ride_off_height_eps + 1.5
	for h in _level.spec.floor_heights_at(depth.logical_x, depth.logical_z):
		if absf(float(h) - feet_h) <= eps:
			return true
	var p := Vector2(depth.logical_x, depth.logical_z)
	for deck in _level.spec.decks:
		if absf(float(deck.get("height", 0.0)) - feet_h) > eps:
			continue
		if LevelSpec.point_in_poly(p, deck.poly):
			return true
	return false


## Only stand on / mount surfaces within ride_off_height_eps of feet.
func _can_mount_surface(hit: Dictionary, feet_h: float) -> bool:
	var h := float(hit.get("height", 0.0))
	return h >= feet_h - ride_off_height_eps


func _sample_underfoot() -> Dictionary:
	if _level == null:
		return {}
	var prefer_h := _feet_height()
	if _on_ramp:
		return _level.sample(
			depth.logical_x, depth.logical_z,
			_ramp_side, _ramp_lip_x, prefer_h, _ramp_base_height,
			_ramp_z_min, _ramp_z_max
		)
	return _level.sample(depth.logical_x, depth.logical_z, -1, NAN, prefer_h)


## Sticky identity as a pipe hit dict (for ContactMath.same_pipe / air enter).
func _ramp_pipe_hit() -> Dictionary:
	return _PlayerPipeHits.ramp_pipe_hit(
		_ramp_side,
		_ramp_lip_x,
		_ramp_base_height,
		_ramp_z_min,
		_ramp_z_max,
		_sticky_pipe_radius(),
	)


## Direct query of the sticky pipe underfoot (ignores competing stories).
func _query_own_ramp_surface() -> Dictionary:
	if _level == null:
		return {"active": false}
	for pipe in _level.pipes:
		if int(pipe.side) != _ramp_side:
			continue
		if absf(float(pipe.lip_x) - _ramp_lip_x) > 0.05:
			continue
		if absf(float(pipe.base_height) - _ramp_base_height) > 0.5:
			continue
		if not is_nan(_ramp_z_min) and absf(float(pipe.z_min) - _ramp_z_min) > 0.05:
			continue
		if not is_nan(_ramp_z_max) and absf(float(pipe.z_max) - _ramp_z_max) > 0.05:
			continue
		return pipe.query_surface(depth.logical_x, depth.logical_z)
	return {"active": false}


## Advance along the quarter-pipe arc. Past θ=PI/2 enters air at coping.
func _apply_ramp_friction(delta: float) -> void:
	if ramp_friction <= 0.0 or delta <= 0.0:
		return
	_ramp_along = move_toward(_ramp_along, 0.0, ramp_friction * delta)
	_velocity.x = _ramp_along


## Split along-arc speed into remaining horizontal (`along * cosθ`). Vertical is
## carried by surface height while grounded; at the lip it becomes `air_vel_y`.
func _project_ramp_velocity(theta: float) -> void:
	_velocity.x = _GroundPipeMath.project_horiz_from_along(_ramp_along, theta)


func _sticky_pipe_radius() -> float:
	return _PlayerPipeHits.pipe_radius_for_hit({
		"side": _ramp_side,
		"lip_x": _ramp_lip_x,
		"base_height": _ramp_base_height,
		"z_min": _ramp_z_min,
		"z_max": _ramp_z_max,
	}, _pipes_array())


func _leave_ramp_to_flat() -> void:
	# Back on flat: full along-speed is horizontal again.
	_velocity.x = _ramp_along
	_on_ramp = false


func _move_along_pipe(hit: Dictionary, arc_speed: float, delta: float) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = _pipe_radius_for_hit(hit)
	var theta: float = float(hit.get("theta", 0.0))
	var step: Dictionary = _GroundPipeMath.step_along_pipe(
		side, lip, radius, theta, arc_speed, delta
	)
	match str(step.get("kind", "noop")):
		"launch":
			_enter_air_from_pipe({
				"side": int(step.get("side", side)),
				"lip_x": float(step.get("lip_x", lip)),
				"radius": float(step.get("radius", radius)),
				"base_height": float(hit.get("base_height", _ramp_base_height)),
			}, float(step.get("up_speed", 0.0)))
		"flat":
			depth.logical_x = float(step.get("logical_x", depth.logical_x))
			_clamp_pose_playable()
			_leave_ramp_to_flat()
		"arc":
			depth.logical_x = float(step.get("logical_x", depth.logical_x))
			_clamp_pose_playable()


func _move_along_pipe_or_flat(arc_speed: float, delta: float) -> void:
	var hit: Dictionary = {
		"active": true,
		"zone": _pipe_zone_name(_air_side),
		"side": _air_side,
		"lip_x": _air_lip_x,
		"theta": PI * 0.5,
		"t_along_pipe": 1.0,
		"radius": _air_radius,
		"base_height": _air_base_height,
	}
	_move_along_pipe(hit, arc_speed, delta)


func _apply_surface() -> void:
	if _level == null:
		last_surface = {"zone": "flat", "height": 0.0, "angle": 0.0}
		depth.surface_height = 0.0
		depth.height_offset = 0.0
		depth.airborne = false
		depth.support_height = 0.0
		_clear_air()
		_refresh_head_debug()
		return

	last_surface = _sample_underfoot()
	var zone := str(last_surface.get("zone", "flat"))
	# Safety: clamping + sample fallback should make this unreachable.
	if zone == "oob":
		_clamp_pose_playable()
		last_surface = _sample_underfoot()
		zone = str(last_surface.get("zone", "flat"))
		if zone == "oob":
			last_surface = last_surface.duplicate()
			last_surface["zone"] = "flat"
			last_surface["active"] = true
			zone = "flat"

	if _airborne:
		last_surface = last_surface.duplicate()
		last_surface["zone"] = "air"
		last_surface["air_over"] = air_over
		last_surface["air_over_layer"] = _air_over_layer
		last_surface["height"] = air_abs_height
		depth.surface_height = air_abs_height
		depth.height_offset = 0.0
		depth.airborne = true
		depth.support_height = _underlying_surface_height()
	else:
		depth.height_offset = 0.0
		depth.airborne = false
		if not last_surface.get("active", true) and (zone == "oob" or zone == "hole"):
			# No standing surface — ride off instead of freezing as grounded oob.
			_try_ride_off_air(depth.surface_height)
			if _airborne:
				last_surface = last_surface.duplicate()
				last_surface["zone"] = "air"
				last_surface["air_over"] = air_over
				last_surface["air_over_layer"] = _air_over_layer
				last_surface["height"] = air_abs_height
				depth.surface_height = air_abs_height
				depth.height_offset = 0.0
				depth.airborne = true
				depth.support_height = _underlying_surface_height()
				_refresh_head_debug()
				return
			depth.support_height = depth.surface_height
		else:
			var sample_h := float(last_surface.get("height", 0.0))
			# Follow continuous support (pipe arc / flats) even when height drops
			# faster than ride_off_eps per tick. Far-below stories are handled by
			# ride-off into air before this runs — don't freeze height on the way down.
			if _on_ramp or sample_h >= depth.surface_height - ride_off_height_eps:
				depth.surface_height = sample_h
			depth.support_height = depth.surface_height

	_refresh_head_debug()


func _coping_cross_hit(from_x: float, to_x: float) -> Dictionary:
	if _level == null:
		return {}
	return _GroundMotion.find_coping_cross(
		_level.pipes, depth.logical_z, from_x, to_x, _feet_height()
	)


## Pipe-only entry path (today). Future entries should call _begin_air_over.
## `up_speed` is along-arc speed fully converted to vertical at the lip (θ = π/2).
func _enter_air_from_pipe(hit: Dictionary, up_speed: float = 0.0) -> void:
	var side: int = int(hit.get("side", QuarterPipe.PipeSide.RIGHT))
	var lip: float = float(hit.get("lip_x", depth.logical_x))
	var radius: float = float(hit.get("radius", _pipe_radius_for_hit(hit)))
	var base_h: float = float(hit.get("base_height", _ramp_base_height))
	var z_min: float = float(hit.get("z_min", _ramp_z_min))
	var z_max: float = float(hit.get("z_max", _ramp_z_max))
	var coping := _coping_x_for(side, lip, radius)
	var coping_floor := base_h + radius
	_begin_air_over({
		"zone": _pipe_zone_name(side),
		"side": side,
		"lip_x": lip,
		"radius": radius,
		"base_height": base_h,
		"z_min": z_min,
		"z_max": z_max,
		"layer": int(hit.get("layer", _layer_index_for_base(base_h))),
		"lock_x": true,
		"anchor_x": coping,
	}, coping_floor, true)
	_exit_pipe_side = side
	_exit_pipe_lip = lip
	_exit_pipe_coping = coping
	_exit_pipe_z_min = z_min
	_exit_pipe_z_max = z_max
	_exit_travel_x = _coping_sign(side)
	_crossed_pipe_coping_this_aerial = true
	# Fully convert remaining along-speed into vertical; horiz is gone at θ = π/2.
	air_vel_y = maxf(up_speed, 0.0)
	_ramp_along = 0.0
	_velocity.x = 0.0
	_on_ramp = false
	_note_air_carry(up_speed)


## Unlock pipe-exit X-lock into free air when rising, above coping, and planar
## INPUT is X-dominant toward that pipe's side (not MOMENTUM, not Z-dominant).
## No room outward (facing cast) → keep X lock (avoids edge clamp bounce).
## Spine transfer stays locked (no fly-out) until drop-in.
func _try_fly_out_from_pipe_lock() -> bool:
	if not _crossed_pipe_coping_this_aerial:
		return false
	if _spine_transfer_lock:
		return false
	if not _fly_out_has_outward_room():
		return false
	if not _AerialMath.should_fly_out_pipe_lock(
		_air_x_locked,
		_acid_drop_lock,
		_air_side,
		air_abs_height,
		_air_coping_floor(),
		fly_out_above_coping,
		_last_input.x,
		air_vel_y,
		0.15,
		_last_input.y,
	):
		return false
	_air_x_locked = false
	_flew_out_this_aerial = true
	# Seed outward horiz so fly-out is a real arc (pipe exit zeros vx at θ=π/2).
	var out := _exit_travel_x
	if absf(out) < 1.0:
		out = _coping_sign(_air_side)
		_exit_travel_x = out
	_velocity.x = out * maxf(_air_carry_speed, transfer_release_min)
	return true


## True when the facing cast finds a playable cell outward from this pipe's
## coping. Use coping X (not inward-nudged cell_under_feet) so edge columns
## correctly report nowhere ahead.
func _fly_out_has_outward_room() -> bool:
	if _level == null or _level.spec == null:
		return false
	var cell: Vector2i = _level.spec.cell_at(_air_coping_x, depth.logical_z)
	var facing := "r" if _air_side == QuarterPipe.PipeSide.RIGHT else "l"
	return _FacingCastMath.has_playable_ahead(_level.spec, cell.x, cell.y, facing, 1)


## Start airborne over a target. snap_x pins to anchor immediately (pipe enter);
## false keeps current X so a transfer lerp can carry us there.
func _begin_air_over(target: Dictionary, abs_height: float, snap_x: bool = true) -> void:
	_airborne = true
	_crossed_pipe_coping_this_aerial = false
	air_vel_y = 0.0
	air_over = str(target.get("zone", "flat"))
	_air_x_locked = bool(target.get("lock_x", false))
	_acid_drop_lock = false
	_spine_transfer_lock = false
	_apex_facing_done = false
	if target.has("side"):
		_air_side = int(target.side)
		_transfer_behind_sign = _coping_sign(_air_side)
	if target.has("lip_x"):
		_air_lip_x = float(target.lip_x)
	if target.has("radius"):
		_air_radius = float(target.radius)
	_air_base_height = float(target.get("base_height", 0.0))
	_air_z_min = float(target.get("z_min", NAN))
	_air_z_max = float(target.get("z_max", NAN))
	if target.has("layer"):
		_air_over_layer = int(target.layer)
	else:
		_air_over_layer = _layer_index_for_base(_air_base_height)
	var coping_floor := _air_coping_floor()
	if _air_x_locked:
		_air_coping_x = float(target.get("anchor_x", _coping_x_for(_air_side, _air_lip_x, _air_radius)))
		if snap_x:
			depth.logical_x = _air_coping_x
		air_abs_height = maxf(abs_height, coping_floor)
	else:
		air_abs_height = abs_height
	depth.height_offset = 0.0


func _clear_air() -> void:
	_airborne = false
	air_abs_height = 0.0
	air_vel_y = 0.0
	air_over = ""
	_air_over_layer = -1
	_air_x_locked = false
	_acid_drop_lock = false
	_spine_transfer_lock = false
	_apex_facing_done = false
	_settle.reset()
	_transfer_available = true
	_acid_drop_available = true
	_last_nonzero_vert_vel = 0.0
	_air_carry_speed = 0.0
	_air_z_min = NAN
	_air_z_max = NAN
	_exit_pipe_side = -1
	_exit_pipe_lip = NAN
	_exit_pipe_coping = NAN
	_exit_pipe_z_min = NAN
	_exit_pipe_z_max = NAN
	_exit_travel_x = 0.0
	_acid_travel_x = 0.0
	_flew_out_this_aerial = false
	_crossed_pipe_coping_this_aerial = false
	_acid_pressed_this_aerial = false
	depth.height_offset = 0.0


## Rising, or at apex after a rise (vert≈0 but last non-zero was up).
func _transfer_vert_ok() -> bool:
	return _MotionMath.transfer_vert_ok(_vert_vel, _last_nonzero_vert_vel)


## Same button: transfer while rising/apex, acid drop while falling.
## After fly-out, always acid — fly-out apex (vert≈0 after rise) used to route to
## transfer/spine and slam into-bowl velocity (felt like acid reverse).
func _try_air_action() -> void:
	if _flew_out_this_aerial:
		_try_acid_drop()
		return
	if _AerialMath.choose_air_action(_vert_vel, _last_nonzero_vert_vel) == _AerialMath.ACTION_TRANSFER:
		if _try_spine_transfer():
			return
		_try_transfer()
	else:
		_try_acid_drop()


func _try_acid_drop(from_hold: bool = false) -> void:
	if not _airborne or _level == null or not _acid_drop_available:
		return
	# Rising/apex → transfer — except after fly-out (apex of the parabola must
	# still acid; transfer_vert_ok would otherwise no-op the press).
	if _transfer_vert_ok() and not _flew_out_this_aerial:
		return
	# ACTUAL → exit outward → MOMENTUM. Stick-MOMENTUM must not beat exit travel
	# (that cast acid back into the bowl after a fly-out).
	var travel_x := _AerialMath.resolve_acid_travel_x(
		_actual_vel_x, _velocity.x, _exit_travel_x
	)
	if absf(travel_x) < 1.0:
		return
	var hit := _find_acid_coping_target(travel_x)
	if hit.is_empty():
		# Hold buffer: wait until a cast cell shows a coping — don't unlock / abort.
		if from_hold:
			return
		# Press with no forward coping: unlock exit pin and keep travel velocity.
		_acid_pressed_this_aerial = true
		_acid_travel_x = travel_x
		_acid_abort_without_reverse(travel_x)
		return

	# Mark press once we commit to a lerp.
	_acid_pressed_this_aerial = true
	_acid_travel_x = travel_x

	var lock: Dictionary = _AerialTransfer.resolve_acid_lock(
		hit, depth.logical_x, travel_x, depth.logical_x
	)
	if not bool(lock.get("ok", false)):
		if from_hold:
			return
		_acid_abort_without_reverse(travel_x)
		return

	var side: int = int(lock.side)
	var lip: float = float(lock.lip_x)
	var radius: float = float(lock.radius)
	var coping: float = float(lock.coping_x)
	_air_x_locked = true
	_acid_drop_lock = true
	_air_side = side
	_air_lip_x = lip
	_air_radius = radius
	_air_base_height = float(lock.base_height)
	_air_z_min = float(lock.z_min)
	_air_z_max = float(lock.z_max)
	_air_coping_x = coping
	air_over = _pipe_zone_name(side)
	if int(lock.layer) >= 0:
		_air_over_layer = int(lock.layer)
	else:
		_air_over_layer = _layer_index_for_base(_air_base_height)
	_transfer_behind_sign = _coping_sign(side)
	# Clear into-bowl stash; never rewrite to into-pipe carry.
	_note_air_carry()
	_preserve_acid_travel_velocity()

	_begin_transfer_x_lerp(coping, true, radius)
	if not _AerialMath.acid_coping_ahead(_settle.x_from, _settle.x_to, travel_x) \
			and absf(_settle.x_to - _settle.x_from) > 0.05:
		_settle.x_active = false
		_acid_drop_lock = false
		if from_hold:
			return
		_acid_abort_without_reverse(travel_x)
		return

	_acid_drop_available = false


## Acid pressed but no valid forward coping: leave exit X-lock with travel velocity
## so the coming land cannot lock_carry / merge into the bowl.
func _acid_abort_without_reverse(travel_x: float) -> void:
	_acid_drop_lock = false
	_acid_travel_x = travel_x
	_acid_pressed_this_aerial = true
	if not _spine_transfer_lock:
		_air_x_locked = false
	_preserve_acid_travel_velocity()
	if absf(_velocity.x) < 1.0:
		var sgn := signf(travel_x)
		_velocity.x = sgn * maxf(_air_carry_speed, transfer_release_min)


## Keep horiz momentum on the acid travel side — never reverse sign.
## Opposing MOMENTUM (stick into bowl while pipe-locked) is zeroed, not flipped
## into a fake outward carry.
func _preserve_acid_travel_velocity() -> void:
	if absf(_acid_travel_x) < 1.0:
		return
	var sgn := signf(_acid_travel_x)
	if _velocity.x * sgn < 0.0:
		_velocity.x = 0.0


## True when hit is the pipe (or coping column) left this aerial.
func _is_exit_pipe_hit(hit: Dictionary) -> bool:
	return _AerialContact.is_exit_pipe_hit(
		hit,
		_exit_pipe_side,
		_exit_pipe_lip,
		_exit_pipe_coping,
		_exit_pipe_z_min,
		_exit_pipe_z_max,
	)


func _is_exit_pipe_coping(coping: float, side: int, lip: float) -> bool:
	return _AerialContact.is_exit_pipe_coping(
		coping, side, lip, _exit_pipe_side, _exit_pipe_lip, _exit_pipe_coping
	)


## First opposite-facing top coping within `facing_coping_cells` along acid travel.
## Cast-cell window only — no logical-X buffer / max-ahead.
## Same-side / exit-pipe copings are rejected (landing drop-in would reverse travel).
func _find_acid_coping_target(travel_x: float) -> Dictionary:
	if _level == null or _level.spec == null:
		return {}
	var cell: Vector2i = cell_under_feet()
	var xz: Vector2 = cell_sample_xz()
	return _AerialTargeting.find_acid_coping_target(
		_level.spec,
		_level.pipes,
		cell,
		xz.y,
		_feet_height(),
		depth.logical_x,
		travel_x,
		facing_coping_cells,
		Callable(self, "_is_exit_pipe_hit"),
	)


## Spine transfer: rising air, or rising on a pipe, when FacingCastMath finds a
## top coping within `facing_coping_cells` ahead of facing_h (excludes current pipe).
## Requires feet at/above the opposite coping so low→high cannot start early and
## clip through the dest back wall. Lock X; land uses drop-in merge.
## Spends both charges. A held transfer button is explicit input, including high→low.
func _try_spine_transfer(_from_hold_buffer: bool = false) -> bool:
	if _flew_out_this_aerial:
		return false
	if _level == null or not _transfer_available:
		return false
	var from_ramp := (not _airborne) and _on_ramp and _ramp_rising_toward_coping()
	if _airborne:
		if not _transfer_vert_ok():
			return false
	elif not from_ramp:
		return false

	var hit: Dictionary = _find_facing_coping_target()
	if hit.is_empty():
		return false
	# Must already clear the opposite lip — no early spine into a taller back wall.
	if not _AerialTransfer.spine_feet_clear_dest(_feet_height(), hit):
		return false
	# Peak aerial carry (exit speed), not live air_vel_y after a gravity climb.
	_note_air_carry()
	var carry: float = _air_carry_speed

	# Leave the wall into air with upward speed, then spine-lock (don't pin to
	# the source coping — lerp to the facing target).
	if not _airborne:
		_launch_air_for_spine_from_ramp()
		_note_air_carry()
		carry = _air_carry_speed

	_apply_spine_lock(hit, carry)
	return true


## Along-arc is carrying us toward the top coping (up the wall).
func _ramp_rising_toward_coping() -> bool:
	if not _on_ramp:
		return false
	return _ramp_along * _coping_sign(_ramp_side) > 8.0


## Enter air from a grounded pipe ride without X-locking to the source coping.
func _launch_air_for_spine_from_ramp() -> void:
	var th := 0.0
	if last_surface.has("theta"):
		th = float(last_surface.theta)
	var up := absf(_ramp_along) * sin(clampf(th, 0.0, PI * 0.5))
	_airborne = true
	_on_ramp = false
	_air_x_locked = false
	_acid_drop_lock = false
	_spine_transfer_lock = false
	_apex_facing_done = false
	_settle.x_active = false
	_settle.tilt_active = false
	air_abs_height = depth.surface_height
	air_vel_y = maxf(up, 0.0)
	_ramp_along = 0.0
	_velocity.x = 0.0
	_air_side = _ramp_side
	_air_lip_x = _ramp_lip_x
	_air_radius = _sticky_pipe_radius()
	_air_base_height = _ramp_base_height
	_air_z_min = _ramp_z_min
	_air_z_max = _ramp_z_max
	_exit_pipe_side = _ramp_side
	_exit_pipe_lip = _ramp_lip_x
	_exit_pipe_coping = _coping_x_for(_ramp_side, _ramp_lip_x, _sticky_pipe_radius())
	_exit_pipe_z_min = _ramp_z_min
	_exit_pipe_z_max = _ramp_z_max
	_exit_travel_x = _coping_sign(_ramp_side)
	air_over = _pipe_zone_name(_ramp_side)
	_air_over_layer = _layer_index_for_base(_ramp_base_height)
	_transfer_behind_sign = _coping_sign(_ramp_side)
	depth.airborne = true
	depth.surface_height = air_abs_height
	_note_air_carry(up)


func _apply_spine_lock(hit: Dictionary, carry_speed: float = -1.0) -> void:
	var carry := carry_speed
	if carry < 0.0:
		_note_air_carry()
		carry = _air_carry_speed
	else:
		_note_air_carry(carry)
		carry = _air_carry_speed
	var lock: Dictionary = _AerialTransfer.resolve_spine_lock(hit, depth.logical_x, carry)
	if not bool(lock.get("ok", false)):
		return
	var side: int = int(lock.side)
	var radius: float = float(lock.radius)
	var coping: float = float(lock.coping_x)

	_air_x_locked = true
	_acid_drop_lock = false
	_spine_transfer_lock = true
	_air_side = side
	_air_lip_x = float(lock.lip_x)
	_air_radius = radius
	_air_base_height = float(lock.base_height)
	_air_z_min = float(lock.z_min)
	_air_z_max = float(lock.z_max)
	_air_coping_x = coping
	air_over = str(lock.air_over)
	if int(lock.layer) >= 0:
		_air_over_layer = int(lock.layer)
	else:
		_air_over_layer = _layer_index_for_base(_air_base_height)
	_transfer_behind_sign = float(lock.transfer_behind_sign)
	_velocity.x = float(lock.vx)

	_begin_transfer_x_lerp(coping, true, radius)

	_transfer_available = false
	_acid_drop_available = false


## Pipe side we're leaving for spine exclude (want = other coping ahead).
func _spine_from_side() -> int:
	if _air_x_locked:
		return _air_side
	if air_over == "left_pipe" or air_over == "right_pipe":
		return _air_side
	if air_over == "hole" and (_air_side == QuarterPipe.PipeSide.LEFT \
			or _air_side == QuarterPipe.PipeSide.RIGHT):
		return _air_side
	if facing_h == "l":
		return QuarterPipe.PipeSide.LEFT
	if facing_h == "r":
		return QuarterPipe.PipeSide.RIGHT
	return -1


## Behind sign (call-site compat / transfer lock seed). Same sources as from-side.
func _spine_behind_sign() -> float:
	var side := _spine_from_side()
	if side >= 0:
		return _coping_sign(side)
	if absf(_transfer_behind_sign) >= 0.001:
		return signf(_transfer_behind_sign)
	return 1.0 if facing_h == "r" else -1.0


## First top coping within facing_coping_cells ahead of facing_h (FacingCastMath).
## Skips the pipe currently locked / underfoot so acid/spine target another coping.
func next_facing_coping() -> Dictionary:
	return _find_facing_coping_target()


## Debug label for next facing coping, e.g. "left_pipe L1" or "—".
func next_facing_coping_debug() -> String:
	var hit: Dictionary = next_facing_coping()
	if hit.is_empty():
		return "—"
	var zone := str(hit.get("zone", "pipe"))
	if zone == "pipe":
		zone = _pipe_zone_name(int(hit.get("side", QuarterPipe.PipeSide.RIGHT)))
	var layer := int(hit.get("layer", -1))
	if layer < 0:
		layer = _layer_index_for_base(float(hit.get("base_height", 0.0)))
	if layer >= 0:
		return "%s L%d" % [zone, layer]
	return zone


## First top coping within facing_coping_cells ahead of facing_h (FacingCastMath).
## Skips the pipe currently locked / underfoot so acid/spine target another coping.
func _find_facing_coping_target(facing_override: String = "") -> Dictionary:
	if _level == null or _level.spec == null:
		return {}
	var cell: Vector2i = cell_under_feet()
	var xz: Vector2 = cell_sample_xz()
	var facing := facing_override
	if facing != "l" and facing != "r":
		facing = facing_h
	if facing != "l" and facing != "r":
		facing = "r"
	var exclude_side := -1
	var exclude_lip := NAN
	var exclude_z_min := NAN
	var exclude_z_max := NAN
	if _exit_pipe_side >= 0 and not is_nan(_exit_pipe_lip):
		# Survive fly-out → flat/hole air_over so we never re-target the exit wall.
		exclude_side = _exit_pipe_side
		exclude_lip = _exit_pipe_lip
		exclude_z_min = _exit_pipe_z_min
		exclude_z_max = _exit_pipe_z_max
	elif _air_x_locked or air_over == "left_pipe" or air_over == "right_pipe" \
			or (air_over == "hole" and (_air_side == QuarterPipe.PipeSide.LEFT \
				or _air_side == QuarterPipe.PipeSide.RIGHT)):
		exclude_side = _air_side
		exclude_lip = _air_lip_x
		exclude_z_min = _air_z_min
		exclude_z_max = _air_z_max
	elif _on_ramp:
		# Grounded pipe ride: skip this wall's coping so cast can see the next one.
		exclude_side = _ramp_side
		exclude_lip = _ramp_lip_x
		exclude_z_min = _ramp_z_min
		exclude_z_max = _ramp_z_max
	return _AerialTargeting.find_facing_coping_target(
		_level.spec,
		_level.pipes,
		cell,
		xz.y,
		_feet_height(),
		facing,
		facing_coping_cells,
		exclude_side,
		exclude_lip,
		exclude_z_min,
		exclude_z_max,
	)


func _try_transfer() -> bool:
	if _flew_out_this_aerial:
		return false
	if not _airborne or _level == null or not _transfer_available:
		return false
	# Rising, or apex after rise (vert≈0 with last non-zero up).
	if not _transfer_vert_ok():
		return false
	var was_locked := _air_x_locked
	var behind: float = _transfer_behind_sign
	if _air_x_locked:
		behind = _coping_sign(_air_side)
	elif behind == 0.0:
		return false
	var probe_from_x: float = _air_coping_x if _air_x_locked else depth.logical_x
	var probe_x: float = probe_from_x + behind * transfer_probe
	var exclude_side := _air_side
	var exclude_lip := _air_lip_x
	var hit: Dictionary = _level.sample_transfer(
		probe_x, depth.logical_z, exclude_side, exclude_lip, air_abs_height
	)
	# Tight spine / gap: probe may land on flat between facing copings — pick the
	# nearest opposite pipe in the behind direction when no deck claimed the spot.
	if not _ContactMath.is_pipe(hit) and str(hit.get("zone", "")) != "deck":
		var pipe_hit := _find_pipe_behind(probe_from_x, behind, exclude_side, exclude_lip)
		if not pipe_hit.is_empty():
			hit = pipe_hit
	# Pipe-exit lock: only commit to a real destination (deck / foreign pipe).
	# Flat/hole/oob probes used to call _begin_air_over and zero air_vel_y — felt
	# like a dead-stop drop when spine/fly-out were both unavailable (level edge).
	if was_locked and not _AerialTransfer.hit_is_meaningful(hit):
		return false
	var pipe_r := 0.0
	if _ContactMath.is_pipe(hit):
		pipe_r = _pipe_radius_for_hit(hit)
	var built: Dictionary = _AerialTransfer.build_begin_air_target(hit, probe_x, pipe_r)
	var target: Dictionary = built.get("target", {})
	var anchor_x: float = float(built.get("anchor_x", probe_x))
	var keep_h := air_abs_height

	_begin_air_over(target, keep_h, false)
	_transfer_available = false

	# Locked pipe air spent stick X on height — release it as free-air horizontal.
	if was_locked:
		_velocity.x = behind * maxf(absf(_velocity.x), transfer_release_min)
		_settle.x_active = false
		return true

	_begin_transfer_x_lerp(anchor_x, false)
	if not _settle.x_active and _air_x_locked:
		depth.logical_x = _air_coping_x
	return true


## Deck or foreign pipe — not flat/hole fillers from sample_transfer.
func _transfer_hit_is_meaningful(hit: Dictionary) -> bool:
	return _AerialTransfer.hit_is_meaningful(hit)


## Nearest other pipe whose coping lies behind us (spine / back-to-back).
func _find_pipe_behind(
	from_x: float, behind: float, exclude_side: int, exclude_lip_x: float
) -> Dictionary:
	if _level == null:
		return {}
	return _AerialMath.find_pipe_behind(
		_level.pipes, from_x, depth.logical_z, behind, exclude_side, exclude_lip_x
	)


func _coping_x_for(side: int, lip_x: float, radius: float) -> float:
	return _PipeMath.coping_x(side, lip_x, radius)


func _pipe_radius_for_hit(hit: Dictionary) -> float:
	return _PlayerPipeHits.pipe_radius_for_hit(hit, _pipes_array())


func _pipes_array() -> Array:
	if _level == null:
		return []
	return _level.pipes


func _coping_sign(side: int) -> float:
	return _PipeMath.coping_sign(side)


func _pipe_zone_name(side: int) -> String:
	return _PipeMath.zone_name(side)


func zone_debug_label() -> String:
	var zone := str(last_surface.get("zone", "flat"))
	if zone == "air":
		var over := air_over
		if over == "" and last_surface.has("air_over"):
			over = str(last_surface.air_over)
		var layer := _air_over_layer
		if layer < 0 and last_surface.has("air_over_layer"):
			layer = int(last_surface.air_over_layer)
		if over != "":
			if layer >= 0:
				zone = "air (over %s L%d)" % [over, layer]
			else:
				zone = "air (over %s)" % over
		else:
			zone = "air"
	else:
		var layer_g := _layer_from_surface(last_surface)
		if layer_g >= 0:
			zone = "%s L%d" % [zone, layer_g]
	return "%s\nhd %s" % [zone, facing_h]


## Layer index for a grounded/air sample hit.
func _layer_from_surface(surf: Dictionary) -> int:
	if surf.has("layer") and int(surf.layer) >= 0:
		return int(surf.layer)
	if surf.has("base_height"):
		return _layer_index_for_base(float(surf.base_height))
	if surf.has("height"):
		return _layer_index_for_base(float(surf.height))
	return -1


## Map a story base_height to .ssk layer index when hits omit `layer`.
func _layer_index_for_base(base_h: float) -> int:
	if _level == null or _level.spec == null:
		return -1
	for L in _level.spec.layers:
		if absf(float(L.get("height", 0.0)) - base_h) <= 0.5:
			return int(L.get("index", -1))
	return -1


## Logical XZ for cell queries (targeting / highlight / HUD). While X-locked on
## a pipe coping, nudges X into the pipe — see LevelSpec.cell_at_for_pose.
func cell_sample_xz() -> Vector2:
	var x := depth.logical_x
	var z := depth.logical_z
	if _airborne and _air_x_locked and (air_over == "left_pipe" or air_over == "right_pipe"):
		x = _PipeMath.pose_x_for_cell_query(x, _air_side)
	return Vector2(x, z)


## Cell under feet for targeting / debug (uses LevelSpec when available).
func cell_under_feet() -> Vector2i:
	if _level == null or _level.spec == null:
		return Vector2i.ZERO
	return _level.spec.cell_at_for_pose(
		depth.logical_x,
		depth.logical_z,
		_airborne and _air_x_locked,
		air_over,
		_air_side,
	)


func _normalize_facing(raw: String) -> String:
	return _MotionMath.normalize_facing(raw)


func _update_facing_h(_input: Vector2) -> void:
	# Facing follows measured ACTUAL X only (X-dominant) — never MOMENTUM.
	# Ollie thrust must not flip facing via leftover `_velocity.x`.
	var from_actual := _MotionMath.facing_from_actual_vel(_actual_vel_x, _actual_vel_z)
	if from_actual != "":
		facing_h = from_actual


## At vertical apex while X-locked over a pipe (pipe-exit lock only): flip
## facing, unless stick holds a horizontal direction (then face that way).
## Once per aerial. Skipped during spine transfer — keep approach facing.
func _try_apex_facing_flip(prev_air_vy: float) -> void:
	if _apex_facing_done or not _air_x_locked or _spine_transfer_lock:
		return
	if prev_air_vy <= 0.0 or air_vel_y > 0.0:
		return
	_apex_facing_done = true
	var ix := Input.get_axis("move_left", "move_right")
	if absf(ix) >= 0.15:
		facing_h = "r" if ix > 0.0 else "l"
	else:
		facing_h = "l" if facing_h == "r" else "r"
	_update_face_nose()


func _update_face_nose() -> void:
	if _face_nose == null:
		return
	# Sit on the facing side of the body silhouette (local; rotates with Body tilt).
	var side := 1.0 if facing_h == "r" else -1.0
	_face_nose.position = Vector2(12.0 * side, -22.0)


## Lean onto the pipe so local-up follows the surface normal (into the bowl).
## Spine/acid run a dedicated tilt settle (same smoothstep timing as X); otherwise ease.
func _step_body_tilt(delta: float) -> void:
	if _settle.tilt_active:
		_advance_tilt_lerp(delta)
		depth.surface_tilt = _body_tilt
		return
	var target := _body_tilt_target_radians()
	if delta <= 0.0:
		_body_tilt = target
	else:
		# ~14/s — tracks riding θ, softens lock/unlock and free-air snaps.
		var k := 1.0 - exp(-14.0 * delta)
		_body_tilt = lerpf(_body_tilt, target, k)
	depth.surface_tilt = _body_tilt


func _begin_tilt_lerp(to_tilt: float, height_scaled: bool) -> void:
	var above := 0.0
	if _air_x_locked and not is_nan(_air_radius):
		above = maxf(air_abs_height - (_air_base_height + _air_radius), 0.0)
	if not _settle.begin_tilt(
		_body_tilt,
		to_tilt,
		height_scaled,
		above,
		transfer_x_duration,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		acid_drop_x_duration_max,
	):
		_body_tilt = to_tilt


func _advance_tilt_lerp(delta: float) -> void:
	var above := 0.0
	if _air_x_locked and not is_nan(_air_radius):
		above = maxf(air_abs_height - (_air_base_height + _air_radius), 0.0)
	_body_tilt = _settle.step_tilt(
		delta,
		_body_tilt,
		above,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		acid_drop_x_duration_max,
	)


func _body_tilt_target_radians() -> float:
	if _air_x_locked:
		# Coping face is θ=π/2; keep that lean for the locked side until unlock.
		return -_coping_sign(_air_side) * (PI * 0.5)
	if _airborne or not _on_ramp:
		return 0.0
	if last_surface.is_empty() or not last_surface.has("theta"):
		return 0.0
	var th := clampf(float(last_surface.theta), 0.0, PI * 0.5)
	var side := int(last_surface.get("side", _ramp_side))
	return -_coping_sign(side) * th


## Screen-local vector for a [MotionVectors.Kind] (+X right, -Y up on screen).
## Prefer this over kind-specific helpers when branching in gameplay/debug code.
func motion_screen(kind: _MotionVectors.Kind) -> Vector2:
	return _PlayerMotionDebug.motion_screen(
		kind,
		_actual_vel_x,
		_actual_vel_z,
		_vert_vel,
		_velocity,
		_ramp_along,
		_on_ramp,
		last_surface,
		_last_input,
		max_speed_x,
		max_speed_z,
	)


## World-space motion for 3D debug arrows (WorldSpace: −logical X, height Y, Z).
func motion_world(kind: _MotionVectors.Kind) -> Vector3:
	return _PlayerMotionDebug.motion_world(
		kind,
		_actual_vel_x,
		_actual_vel_z,
		_vert_vel,
		_velocity,
		_ramp_along,
		_on_ramp,
		last_surface,
		_last_input,
		max_speed_x,
		max_speed_z,
	)


func motion_speed(kind: _MotionVectors.Kind) -> float:
	return _PlayerMotionDebug.motion_speed(
		kind,
		_actual_vel_x,
		_actual_vel_z,
		_vert_vel,
		_velocity,
		_ramp_along,
		_on_ramp,
		_airborne,
		_last_input,
		max_speed_x,
		max_speed_z,
		air_vel_y,
		_air_carry_speed,
	)


## Instantaneous control acceleration from last integrate (u/s²).
func debug_accel_screen() -> Vector2:
	return Vector2(_debug_accel.x, -_debug_accel.y)


func debug_accel_mag() -> float:
	return _debug_accel.length()


func _refresh_head_debug() -> void:
	if _head_debug_label == null or not DebugTools.show_head_debug:
		return
	_head_debug_label.text = zone_debug_label()


func _apply_head_debug_visible(on: bool) -> void:
	if _head_debug_panel == null:
		return
	_head_debug_panel.visible = on
	if on:
		_refresh_head_debug()


func _read_move_input() -> Vector2:
	var x := Input.get_axis("move_left", "move_right")
	var z := Input.get_axis("move_down", "move_up")
	var v := Vector2(x, z)
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _integrate_velocity(input: Vector2, delta: float) -> void:
	var before := _velocity
	# Acid/spine: don't brake X away. Acid also never flips travel sign.
	if _acid_drop_lock or _spine_transfer_lock:
		_velocity.y = input.y * max_speed_z
		if _acid_drop_lock:
			_preserve_acid_travel_velocity()
		_clamp_momentum_to_max_speed()
		if delta > 0.0001:
			_debug_accel = (_velocity - before) / delta
		else:
			_debug_accel = Vector2.ZERO
		return

	# Pipe-exit X-lock: stick still reads for fly-out INPUT, but must not stash
	# into-bowl MOMENTUM (that used to poison acid travel before exit won).
	if _air_x_locked and _airborne:
		_velocity.y = input.y * max_speed_z
		var out := _coping_sign(_air_side)
		if _velocity.x * out < 0.0:
			_velocity.x = 0.0
		_clamp_momentum_to_max_speed()
		if delta > 0.0001:
			_debug_accel = (_velocity - before) / delta
		else:
			_debug_accel = Vector2.ZERO
		return

	var holding_ollie := Input.is_action_pressed("ollie")
	var step := acceleration * delta
	var friction_step := friction * delta
	var brake_step := brake * delta

	# Horizontal X: opposite stick brakes hard to zero (no reverse until stopped).
	_velocity.x = _integrate_axis_no_reverse(
		_velocity.x,
		input.x * max_speed_x,
		step,
		friction_step,
		brake_step,
		holding_ollie and input.x == 0.0,
	)

	# Depth Z: immediate — snap to stick (no accel / friction ramp).
	_velocity.y = input.y * max_speed_z

	# Hold ollie: mild forward thrust in facing direction (THPS charge feel).
	# Skip when stick is already braking opposite to motion.
	if holding_ollie:
		var face := 1.0 if facing_h == "r" else -1.0
		var stick_opposes := absf(input.x) >= 0.15 and input.x * face < 0.0
		if not stick_opposes:
			_velocity.x = move_toward(_velocity.x, face * max_speed_x, ollie_accel * delta)

	_clamp_momentum_to_max_speed()

	if delta > 0.0001:
		_debug_accel = (_velocity - before) / delta
	else:
		_debug_accel = Vector2.ZERO


## Cap MOMENTUM X / along-arc to ±max_speed_x (drops, transfers, tuning changes).
func _clamp_momentum_to_max_speed() -> void:
	var cap := absf(max_speed_x)
	_velocity.x = clampf(_velocity.x, -cap, cap)
	_ramp_along = clampf(_ramp_along, -cap, cap)


## Move `current` toward `want`. Opposite stick uses `brake_step` (no reverse until
## stopped). Coast uses `friction_step`. Acceleration never decelerates.
func _integrate_axis_no_reverse(
	current: float,
	want: float,
	accel_step: float,
	friction_step: float,
	brake_step: float,
	skip_friction: bool,
) -> float:
	return _MotionMath.integrate_axis_no_reverse(
		current, want, accel_step, friction_step, brake_step, skip_friction
	)
