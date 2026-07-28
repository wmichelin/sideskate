extends CharacterBody3D
## 8-way mover on logical X/Z. Samples RampLevel; spawns from .ssk @ marker.
## Air over any zone. Coping exit locks X (gravity applies); acid drop locks X only.
## Ride-off a higher surface → free air (keep height + gravity). All sim on physics ticks.
## CharacterBody3D transform is motion authority; PseudoDepthBody is a derived snapshot.

const _PipeMath := preload("res://scripts/pipe_math.gd")
const _MotionMath := preload("res://scripts/motion_math.gd")
const _AerialMath := preload("res://scripts/aerial_math.gd")
const _AerialSettle := preload("res://scripts/aerial_settle.gd")
const _AerialTargeting := preload("res://scripts/aerial_targeting.gd")
const _AerialLanding := preload("res://scripts/aerial_landing.gd")
const _AerialContact := preload("res://scripts/aerial_contact.gd")
const _AerialTransfer := preload("res://scripts/aerial_transfer.gd")
const _AerialSpineClearance := preload("res://scripts/aerial_spine_clearance.gd")
const _FacingCastMath := preload("res://scripts/facing_cast_math.gd")
const _MotionVectors := preload("res://scripts/motion_vectors.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")
const _GroundPipeMath := preload("res://scripts/ground_pipe_math.gd")
const _GroundMotion := preload("res://scripts/ground_motion.gd")
const _PlayerPipeHits := preload("res://scripts/player_pipe_hits.gd")
const _PlayerDeath := preload("res://scripts/player_death.gd")
const _PlayerMotionDebug := preload("res://scripts/player_motion_debug.gd")
const _PlayerAirState := preload("res://scripts/player_air_state.gd")
const _PlayerSurface := preload("res://scripts/player_surface.gd")
const _PlayerSteps := preload("res://scripts/player_steps.gd")
const _ContactAdapter := preload("res://scripts/physics/contact_adapter.gd")
const _CollisionLayers := preload("res://scripts/physics/collision_layers.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")

## Capsule in meters (matches LogicalPosePresenter3D body height).
const BODY_RADIUS_M := 0.09
const BODY_CYLINDER_H_M := 0.22
const BODY_FEET_TO_CENTER_M := BODY_RADIUS_M + BODY_CYLINDER_H_M * 0.5

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
## Convert m/s² into logical units/s² (must match WorldSpace.LOGIC_PER_METER).
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
## Spine settle: extra seconds per logical unit of |Δx| (keeps long gaps from snapping).
@export var spine_x_duration_per_x: float = 0.0009
## Spine settle: minimum seconds (clearance-held height_above≈0 must not snap).
@export var spine_x_duration_min: float = 0.45
## Spine settle soft cap (0 = use acid_drop_x_duration_max).
@export var spine_x_duration_max: float = 1.35
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
## Precomputed clearance corridor for the active spine settle (xs/heights/peak).
var _spine_corridor: Dictionary = {}
## Authoritative pose snapshots for render-frame interpolation.
var _pose_prev = null
var _pose_curr = null
var _pose_snap_ready: bool = false
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
## Last Godot contacts from swept motion (debug + face-role filters).
var _last_physics_hits: Array = []
var _excluded_ride_bodies: Array = []


func _ready() -> void:
	_configure_physics_body()
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


func _configure_physics_body() -> void:
	collision_layer = _CollisionLayers.bit(_CollisionLayers.PLAYER)
	collision_mask = _CollisionLayers.player_mask()
	motion_mode = MOTION_MODE_FLOATING
	up_direction = Vector3.UP
	floor_snap_length = _WorldSpace.logic_to_meters(8.0)
	safe_margin = 0.002
	# Never scale the physics body — size is authored in meters.
	scale = Vector3.ONE
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		add_child(cs)
	if cs.shape == null or not (cs.shape is CapsuleShape3D):
		var cap := CapsuleShape3D.new()
		cap.radius = BODY_RADIUS_M
		cap.height = BODY_CYLINDER_H_M
		cs.shape = cap
	cs.position = Vector3(0.0, BODY_FEET_TO_CENTER_M, 0.0)


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
	_teleport_body_to_logical()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _level == null:
		_level = get_node_or_null(level_path) as RampLevel
	# Sync lane bounds before motion — otherwise clamp_z uses stale 0..100 defaults
	# until end-of-frame (spine Z gets crushed to 100 on large maps).
	if _level:
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max

	# Depth may be written by helpers/tests without a body write; start each tick aligned.
	_teleport_body_to_logical()
	_refresh_action_collision_filters()
	_tick_debug_god_input()
	_tick_transfer_press()
	_tick_integrate_input(delta)
	_tick_apply_world_motion(delta)
	_tick_clamp_playable_bounds()
	_apply_surface()
	_teleport_body_to_logical()
	_note_safe_pad_from_surface()
	if _try_lava_death():
		_step_body_tilt(0.0)
		depth.apply()
		_capture_pose_snapshots()
		return
	_update_actual_velocity(delta)
	_tick_transfer_hold()
	_clear_momentum_if_at_rest()
	_step_body_tilt(delta)
	_derive_depth_presentation()
	depth.apply()
	_capture_pose_snapshots()


## Push prev←curr←live after each physics commit for render interpolation.
func _capture_pose_snapshots() -> void:
	var facing := 1.0 if facing_h == "r" else -1.0
	var next := LogicalPose.new()
	next.copy_from_depth(depth, facing, _air_over_layer if _airborne else 0)
	if _pose_curr == null:
		_pose_prev = next
		_pose_curr = next
	else:
		_pose_prev = _pose_curr
		_pose_curr = next
	_pose_snap_ready = true


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
	_sweep_to_logical(depth.logical_x, depth.logical_z, _feet_height())


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
	_teleport_body_to_logical()


func _feet_height() -> float:
	if _airborne:
		return air_abs_height
	return depth.surface_height


func _air_coping_floor() -> float:
	return _air_base_height + _air_radius


## Keep moves inside layer-0 playable footprint (hard boundary). Swept body wins.
func _commit_xz(next_x: float, next_z: float) -> bool:
	var z := depth.clamp_z(next_z)
	var x := next_x
	# Spine corridor flies over non-playable gap cells; playable clamp would yank Z
	# onto a distant pad and abort the transfer. Z stays free for intentional drift.
	if _level and _level.spec and not _spine_transfer_lock:
		var clamped: Vector2 = _level.spec.clamp_to_playable(x, z)
		x = clamped.x
		z = depth.clamp_z(clamped.y)
	_sweep_to_logical(x, z, _feet_height())
	return true


## Snap current pose into playable bounds (coping pin / transfer / pipe move).
func _clamp_pose_playable() -> void:
	if _level == null or _level.spec == null:
		return
	if _spine_transfer_lock:
		return
	var clamped: Vector2 = _level.spec.clamp_to_playable(depth.logical_x, depth.logical_z)
	_sweep_to_logical(clamped.x, depth.clamp_z(clamped.y), _feet_height())


## Teleport body + depth together (spawn / respawn / hard land snaps).
func _teleport_body_to_logical() -> void:
	var h := _feet_height()
	global_position = _WorldSpace.logical_to_world(depth.logical_x, depth.logical_z, h)
	velocity = Vector3.ZERO
	_depenetrate_body()
	_sync_logical_from_body()
	_derive_depth_presentation()


## Push out of overlapping solids after teleports / large corrections.
## Pipe ride/back normals are near-horizontal at the lip — full separation would
## shove logical X off the arc. Keep those contacts vertical-only.
func _depenetrate_body() -> void:
	_refresh_action_collision_filters()
	if collision_mask == 0:
		return
	# Recover with short probes; CharacterBody has no built-in rest depenetration.
	var recover := _WorldSpace.logic_to_meters(12.0)
	for dir in [
		Vector3.UP,
		Vector3.DOWN,
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3.FORWARD,
		Vector3.BACK,
	]:
		for _i in range(4):
			var col := move_and_collide(dir * recover * 0.25)
			if col == null:
				break
			global_position += _depenetrate_push(col)
	# Final zero-length collide to settle contacts if still overlapping.
	for _j in range(3):
		var hit := move_and_collide(Vector3.ZERO)
		if hit == null:
			break
		global_position += _depenetrate_push(hit)


func _depenetrate_push(col: KinematicCollision3D) -> Vector3:
	var push: Vector3 = col.get_normal() * maxf(col.get_depth(), 0.002)
	if _collider_is_pipe_ride_or_back(col.get_collider()):
		push.x = 0.0
		push.z = 0.0
	return push


func _collider_is_pipe_ride_or_back(collider: Object) -> bool:
	if collider == null or not (collider is CollisionObject3D):
		return false
	var body := collider as CollisionObject3D
	var role := str(body.get_meta("face_role", ""))
	if role != "ride" and role != "back":
		return false
	return str(body.get_meta("zone", "")).ends_with("_pipe") or body.has_meta("mesh_part_meta")


## Swept move toward a logical pose; body transform is the authority afterward.
func _sweep_to_logical(next_x: float, next_z: float, next_h: float) -> void:
	_refresh_action_collision_filters()
	var z := depth.clamp_z(next_z)
	var target := _WorldSpace.logical_to_world(next_x, z, next_h)
	var motion := target - global_position
	_last_physics_hits.clear()
	if motion.length_squared() <= 1e-16:
		_sync_logical_from_body()
		return
	var remaining := motion
	for _i in range(4):
		var col := move_and_collide(remaining)
		if col == null:
			break
		_last_physics_hits.append(_ContactAdapter.hit_from_collision(col))
		remaining = remaining.slide(col.get_normal())
		if remaining.length_squared() <= 1e-16:
			break
	_sync_logical_from_body()


func _sync_logical_from_body() -> void:
	var L: Dictionary = _WorldSpace.world_to_logical(global_position)
	depth.logical_x = float(L.x)
	depth.logical_z = depth.clamp_z(float(L.z))
	var h := float(L.height)
	if _airborne:
		air_abs_height = h
		depth.surface_height = h
		depth.airborne = true
	else:
		depth.surface_height = h
		depth.airborne = false


## PseudoDepthBody is presentation / helper scratch; keep tilt + support derived.
func _derive_depth_presentation() -> void:
	depth.airborne = _airborne
	if _airborne:
		depth.surface_height = air_abs_height
		depth.support_height = _underlying_surface_height()
	else:
		depth.support_height = depth.surface_height
	depth.height_offset = 0.0


## Sticky ride clears mask (analytical arc). Airborne hang/settle: suppress the
## exit/origin pipe ride+back so the capsule doesn't embed in the coping wall.
## Free-fall keeps exit ride (high→low needs it); always drop exit *back*.
## Never exclude spine dest (`_air_*`) — landing would fall through.
func _refresh_action_collision_filters() -> void:
	_clear_ride_exceptions()
	if _on_ramp:
		# Concave ride/back will embed a capsule and block coping launch; policy owns the arc.
		collision_mask = 0
		return
	collision_mask = _CollisionLayers.player_mask()
	if not _airborne:
		return
	if _exit_pipe_side < 0:
		return
	# Thin back plane at coping tunnels/sticks during any aerial over the exit pipe.
	_exclude_pipe_faces(_exit_pipe_side, _exit_pipe_lip, ["back"])
	var hang := (
		_air_x_locked
		or _acid_drop_lock
		or _spine_transfer_lock
		or _settle.x_active
		or _flew_out_this_aerial
	)
	if hang:
		_exclude_pipe_faces(_exit_pipe_side, _exit_pipe_lip, ["ride"])


func _exclude_pipe_faces(side: int, lip_x: float, roles: Array) -> void:
	var root := get_tree().get_first_node_in_group("level_collision_3d")
	if root == null:
		var main := get_parent()
		if main != null:
			root = main.get_node_or_null("World3D/LevelCollision3D")
	if root == null:
		return
	var bodies_node := root.get_node_or_null("Bodies")
	if bodies_node == null:
		return
	for child in bodies_node.get_children():
		if not (child is CollisionObject3D):
			continue
		var body := child as CollisionObject3D
		var role := str(body.get_meta("face_role", ""))
		if not roles.has(role):
			continue
		if not _pipe_meta_matches(body, side, lip_x):
			continue
		add_collision_exception_with(body)
		_excluded_ride_bodies.append(body)


func _exclude_pipe_ride(side: int, lip_x: float) -> void:
	_exclude_pipe_faces(side, lip_x, ["ride"])


func _pipe_meta_matches(body: CollisionObject3D, side: int, lip_x: float) -> bool:
	if side < 0 or not body.has_meta("mesh_part_meta"):
		return false
	var meta = body.get_meta("mesh_part_meta")
	if typeof(meta) != TYPE_DICTIONARY:
		return false
	var m: Dictionary = meta
	if int(m.get("side", -2)) != side:
		return false
	if absf(float(m.get("lip_x", NAN)) - lip_x) > 0.5:
		return false
	return true


func _is_exit_pipe_meta(body: CollisionObject3D) -> bool:
	return _pipe_meta_matches(body, _exit_pipe_side, _exit_pipe_lip)


func _clear_ride_exceptions() -> void:
	for body in _excluded_ride_bodies:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_excluded_ride_bodies.clear()


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
	_PlayerSteps.apply_locked_air_motion(self, delta, speed_mul)


## Unlocked air: free XZ then contact → gravity → land from same contact.
func _apply_free_air_motion(delta: float, speed_mul: float) -> void:
	_PlayerSteps.apply_free_air_motion(self, delta, speed_mul)

func _apply_grounded_motion(delta: float, speed_mul: float) -> void:
	_PlayerSteps.apply_grounded_motion(self, delta, speed_mul)


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
		_sweep_to_logical(to_x, depth.logical_z, _feet_height())
	if height_scaled:
		_begin_tilt_lerp(_body_tilt_target_radians(), true)


## Resolve air contact at current XZ and write air_over / layer / sticky ids from it.
## prefer_h is feet height before this tick's gravity (label = collision source).
## Any X-lock force-stickys to the lock target and never adopts a different
## underfoot pipe (avoids free spine onto a higher coping; press transfer).
func _resolve_and_apply_air_contact(prefer_h: float) -> Dictionary:
	return _PlayerSteps.resolve_and_apply_air_contact(self, prefer_h)


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
	var next_h := air_abs_height + air_vel_y * delta
	_sweep_to_logical(depth.logical_x, depth.logical_z, next_h)
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
	_PlayerSteps.step_god_vertical(self, delta)


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
	return _PlayerSteps.try_land_from_air_contact(self, contact, h_before, delta, speed_mul)


func _commit_land_apply(
	apply: Dictionary, land_hit: Dictionary, delta: float, speed_mul: float
) -> bool:
	var kind := str(apply.get("kind", "other"))
	depth.surface_height = float(apply.floor_h)
	if kind == "solid":
		depth.logical_x = float(apply.logical_x)
		_velocity.x = float(apply.vx)
		_on_ramp = false
		_teleport_body_to_logical()
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
		if bool(apply.move_along):
			_move_along_pipe(land_hit, float(apply.ramp_along) * speed_mul, delta)
		else:
			depth.logical_x = float(apply.logical_x)
			_teleport_body_to_logical()
		return true
	depth.logical_x = float(apply.logical_x)
	_teleport_body_to_logical()
	return true


## Leave a higher support surface into free air (keep height, apply gravity).
func _try_ride_off_air(prev_support_h: float) -> void:
	_PlayerSteps.try_ride_off_air(self, prev_support_h)


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
			_sweep_to_logical(
				float(step.get("logical_x", depth.logical_x)),
				depth.logical_z,
				_feet_height()
			)
			_leave_ramp_to_flat()
		"arc":
			# Analytical sticky pose — don't let Godot contacts rewrite X mid-arc.
			depth.logical_x = float(step.get("logical_x", depth.logical_x))
			_teleport_body_to_logical()
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
	_PlayerSteps.apply_surface(self)


func _coping_cross_hit(from_x: float, to_x: float) -> Dictionary:
	if _level == null:
		return {}
	return _GroundMotion.find_coping_cross(
		_level.pipes, depth.logical_z, from_x, to_x, _feet_height()
	)


## Merge air-state patch onto Player fields / depth.
func _apply_air_patch(p: Dictionary) -> void:
	for k in p.keys():
		var key := str(k)
		var v = p[k]
		match key:
			"reset_settle":
				if bool(v):
					_settle.reset()
					_spine_corridor = {}
			"logical_x":
				depth.logical_x = float(v)
			"vx":
				_velocity.x = float(v)
			"depth_height_offset":
				depth.height_offset = float(v)
			"depth_airborne":
				depth.airborne = bool(v)
			"depth_surface_height":
				depth.surface_height = float(v)
			"settle_x_active":
				_settle.x_active = bool(v)
			"settle_tilt_active":
				_settle.tilt_active = bool(v)
			"note_air_carry":
				_note_air_carry(float(v))
			"ramp_along":
				_ramp_along = float(v)
			"on_ramp":
				_on_ramp = bool(v)
			"air_abs_height", "air_vel_y", "air_over":
				set(key, v)
			_:
				set("_" + key, v)


## Pipe-only entry path (today). Future entries should call _begin_air_over.
func _enter_air_from_pipe(hit: Dictionary, up_speed: float = 0.0) -> void:
	var patch: Dictionary = _PlayerAirState.enter_from_pipe_bundle(
		hit,
		depth.logical_x,
		_ramp_base_height,
		_ramp_z_min,
		_ramp_z_max,
		_pipe_radius_for_hit(hit),
		_layer_index_for_base(float(hit.get("base_height", _ramp_base_height))),
		up_speed,
	)
	_apply_air_patch(patch)


func _try_fly_out_from_pipe_lock() -> bool:
	if not _crossed_pipe_coping_this_aerial or _spine_transfer_lock:
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
	_apply_air_patch(
		_PlayerAirState.fly_out_unlock_patch(
			_exit_travel_x, _air_side, _air_carry_speed, transfer_release_min
		)
	)
	return true


func _fly_out_has_outward_room() -> bool:
	if _level == null or _level.spec == null:
		return false
	var cell: Vector2i = _level.spec.cell_at(_air_coping_x, depth.logical_z)
	var facing := "r" if _air_side == QuarterPipe.PipeSide.RIGHT else "l"
	return _FacingCastMath.has_playable_ahead(_level.spec, cell.x, cell.y, facing, 1)


func _begin_air_over(target: Dictionary, abs_height: float, snap_x: bool = true) -> void:
	var layer_fb := _layer_index_for_base(float(target.get("base_height", 0.0)))
	_apply_air_patch(
		_PlayerAirState.begin_air_over_patch(target, abs_height, snap_x, layer_fb)
	)


func _clear_air() -> void:
	_apply_air_patch(_PlayerAirState.clear_patch())


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
	_PlayerSteps.try_acid_drop(self, from_hold)


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
	return _PlayerSteps.try_spine_transfer(self, _from_hold_buffer)


## Along-arc is carrying us toward the top coping (up the wall).
func _ramp_rising_toward_coping() -> bool:
	if not _on_ramp:
		return false
	return _ramp_along * _coping_sign(_ramp_side) > 8.0


## Enter air from a grounded pipe ride without X-locking to the source coping.
func _launch_air_for_spine_from_ramp() -> void:
	var th := float(last_surface.get("theta", 0.0))
	var radius := _sticky_pipe_radius()
	_apply_air_patch(
		_PlayerAirState.spine_launch_from_ramp_patch(
			depth.surface_height,
			_ramp_along,
			th,
			_ramp_side,
			_ramp_lip_x,
			radius,
			_ramp_base_height,
			_ramp_z_min,
			_ramp_z_max,
			_layer_index_for_base(_ramp_base_height),
		)
	)


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
	_apply_air_patch(
		_PlayerAirState.coping_lock_patch(
			lock, false, true, _layer_index_for_base(float(lock.base_height))
		)
	)
	_spine_corridor = _build_spine_corridor(
		depth.logical_x,
		float(lock.coping_x),
		int(lock.side),
		float(lock.lip_x),
		float(lock.base_height),
		float(lock.radius),
	)
	_begin_spine_x_lerp(float(lock.coping_x))


## Sample solids along [from_x→to_x] for spine clearance (no sticky).
func _build_spine_corridor(
	from_x: float,
	to_x: float,
	side: int,
	lip_x: float,
	base_height: float,
	radius: float,
) -> Dictionary:
	if _level == null:
		return {}
	return _AerialSpineClearance.build_corridor(
		from_x,
		to_x,
		side,
		lip_x,
		base_height,
		radius,
		Callable(self, "_spine_corridor_sample_at"),
	)


func _spine_corridor_sample_at(x: float) -> Dictionary:
	if _level == null:
		return {}
	return _level.resolve_air_contact(
		x, depth.logical_z, _feet_height(), -1, NAN, NAN, false, NAN, NAN
	)


## Spine X/tilt settle: distance-scaled duration, locked (no live shorten), smootherstep.
func _begin_spine_x_lerp(to_x: float) -> void:
	var above := maxf(air_abs_height - _air_coping_floor(), 0.0)
	var gap := absf(to_x - depth.logical_x)
	var cap := spine_x_duration_max
	if cap <= 0.0:
		cap = acid_drop_x_duration_max
	var dur := _AerialMath.spine_lock_x_duration(
		gap,
		above,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		spine_x_duration_per_x,
		spine_x_duration_min,
		cap,
	)
	var active := _settle.begin_x(
		depth.logical_x,
		to_x,
		true,
		above,
		transfer_x_duration,
		acid_drop_x_duration,
		acid_drop_x_duration_per_height,
		acid_drop_x_duration_max,
		dur,
		true,
		true,
	)
	if not active:
		depth.logical_x = to_x
	_begin_tilt_lerp(_body_tilt_target_radians(), true, dur, true, true)


## Pipe side we're leaving for spine exclude (want = other coping ahead).
func _spine_from_side() -> int:
	return _PlayerAirState.spine_from_side(_air_x_locked, air_over, _air_side, facing_h)


func _spine_behind_sign() -> float:
	return _PlayerAirState.spine_behind_sign(
		_spine_from_side(), _transfer_behind_sign, facing_h
	)

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
	return _PlayerSteps.find_facing_coping_target(self, facing_override)


func _try_transfer() -> bool:
	return _PlayerSteps.try_transfer(self)


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
	var zone := _PlayerSurface.zone_label(
		last_surface, air_over, _air_over_layer, Callable(self, "_layer_from_surface")
	)
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


func _begin_tilt_lerp(
	to_tilt: float,
	height_scaled: bool,
	duration_override: float = -1.0,
	lock_duration: bool = false,
	use_smootherstep: bool = false,
) -> void:
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
		duration_override,
		lock_duration,
		use_smootherstep,
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
	return _PlayerAirState.body_tilt_target_radians(
		_air_x_locked, _air_side, _airborne, _on_ramp, last_surface, _ramp_side
	)


func _motion_debug_args() -> Dictionary:
	return {
		"ax": _actual_vel_x,
		"az": _actual_vel_z,
		"vert": _vert_vel,
		"vel": _velocity,
		"along": _ramp_along,
		"on_ramp": _on_ramp,
		"surf": last_surface,
		"input": _last_input,
		"max_x": max_speed_x,
		"max_z": max_speed_z,
		"air": _airborne,
		"air_vy": air_vel_y,
		"carry": _air_carry_speed,
	}


func motion_screen(kind: _MotionVectors.Kind) -> Vector2:
	var a := _motion_debug_args()
	return _PlayerMotionDebug.motion_screen(
		kind, a.ax, a.az, a.vert, a.vel, a.along, a.on_ramp, a.surf, a.input, a.max_x, a.max_z
	)


func motion_world(kind: _MotionVectors.Kind) -> Vector3:
	var a := _motion_debug_args()
	return _PlayerMotionDebug.motion_world(
		kind, a.ax, a.az, a.vert, a.vel, a.along, a.on_ramp, a.surf, a.input, a.max_x, a.max_z
	)


func motion_speed(kind: _MotionVectors.Kind) -> float:
	var a := _motion_debug_args()
	return _PlayerMotionDebug.motion_speed(
		kind, a.ax, a.az, a.vert, a.vel, a.along, a.on_ramp, a.air, a.input,
		a.max_x, a.max_z, a.air_vy, a.carry
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
	var mode := "free"
	if _acid_drop_lock:
		mode = "acid"
	elif _spine_transfer_lock:
		mode = "spine"
	elif _air_x_locked and _airborne:
		mode = "pipe_lock"
	var out: Dictionary = _MotionMath.integrate_control_velocity(
		_velocity,
		input,
		delta,
		mode,
		max_speed_x,
		max_speed_z,
		acceleration,
		friction,
		brake,
		ollie_accel,
		Input.is_action_pressed("ollie"),
		facing_h,
		_coping_sign(_air_side),
		_acid_travel_x,
	)
	_velocity = out.velocity
	_debug_accel = out.debug_accel
	_clamp_momentum_to_max_speed()


## Cap MOMENTUM X / along-arc to ±max_speed_x (drops, transfers, tuning changes).
func _clamp_momentum_to_max_speed() -> void:
	var cap := absf(max_speed_x)
	_velocity.x = clampf(_velocity.x, -cap, cap)
	_ramp_along = clampf(_ramp_along, -cap, cap)
