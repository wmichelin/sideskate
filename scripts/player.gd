extends CharacterBody3D
## Thin CharacterBody3D shell: PlayerSim is the sole gameplay authority.
## PseudoDepthBody + pose snapshots feed 3D presenters only.

const _WorldSpace := preload("res://scripts/world_space.gd")
const _CollisionLayers := preload("res://scripts/physics/collision_layers.gd")
const _LogicalPose := preload("res://scripts/logical_pose.gd")

const BODY_RADIUS_M := 0.09
const BODY_CYLINDER_H_M := 0.22

@export var level_path: NodePath = NodePath("../RampLevel")
@export var accel: float = 3250.0
@export var max_speed_x: float = 880.0
@export var max_speed_z: float = 400.0
@export var ollie_accel: float = 650.0
@export_range(0.0, 5000.0, 1.0) var ollie_charge_ms: float = 250.0
@export_range(0.0, 200.0, 0.1) var ollie_height: float = 100.0
## Upper pipe/ramp fraction from the lip that X-locks ollie into hang air (0.50 = top 50%).
@export_range(0.0, 1.0, 0.01) var ollie_lip_frac: float = 0.50
@export var brake: float = 1250.0
@export var friction: float = 0.0
@export var ramp_friction: float = 0.0
@export var gravity_ms2: float = -19.0
@export var fly_out_above_coping: float = 40.0
@export var apex_facing_delay: float = 0.05
@export_range(0.0, 45.0, 0.5) var depth_turn_degrees: float = 18.0
@export var facing_coping_cells: int = 3
@export var acid_coping_cells: int = 16

var depth: PseudoDepthBody
var facing_h: String = "r"
var visual_facing_h: String = "r"
var facing_yaw: float = 0.0
var _airborne: bool = false
var air_abs_height: float = 0.0
var last_surface: Dictionary = {}
var _level: RampLevel
var _sim: PlayerSim
var _pose_prev
var _pose_curr
var _pose_snap_ready: bool = false
var _model_hash: String = ""
var _death_busy: bool = false
var _last_wish: Vector2 = Vector2.ZERO
## Last grounded pipe/wall lean — kept while airborne so ollie doesn't snap upright.
var _carry_tilt: float = 0.0
## Transfer lean lerp (presentation): start locked on accept, end from plan.tilt_end.
var _transfer_tilt_active: bool = false
var _transfer_tilt_start: float = 0.0
var _transfer_tilt_end: float = 0.0


func _ready() -> void:
	_configure_body()
	depth = get_node_or_null("PseudoDepthBody") as PseudoDepthBody
	_level = get_node_or_null(level_path) as RampLevel
	if _level != null and not _level.rebuilt.is_connected(_on_level_rebuilt):
		_level.rebuilt.connect(_on_level_rebuilt)
	call_deferred("_boot_sim")


func _configure_body() -> void:
	collision_layer = _CollisionLayers.bit(_CollisionLayers.PLAYER)
	## Analytical authority — Godot colliders never rewrite gameplay state.
	collision_mask = 0
	motion_mode = MOTION_MODE_FLOATING
	up_direction = Vector3.UP
	safe_margin = 0.002
	scale = Vector3.ONE
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs and (cs.shape == null or not (cs.shape is CapsuleShape3D)):
		var cap := CapsuleShape3D.new()
		cap.radius = BODY_RADIUS_M
		cap.height = BODY_CYLINDER_H_M
		cs.shape = cap


func _boot_sim() -> void:
	_level = get_node_or_null(level_path) as RampLevel
	if _level == null or _level.spec == null:
		return
	if depth != null:
		depth.z_min = _level.z_min
		depth.z_max = _level.z_max
	_sim = PlayerSim.new()
	_sync_tuning_to_sim()
	if not _sim.setup_from_spec(_level.spec):
		push_error("PlayerSim failed to compile level")
		_sim = null
		return
	_model_hash = _sim.model.model_hash
	_assert_presentation_hash()
	_sync_from_sim()
	_capture_pose_snapshots()


func _on_level_rebuilt() -> void:
	_boot_sim()


func _assert_presentation_hash() -> void:
	## Presentation/collision must consume the same compiled IDL as the sim.
	## Mesh builders still derive from LevelSpec; stamp the sim hash for gate checks.
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		root = get_parent()
	if root == null:
		return
	var col := root.get_node_or_null("World3D/LevelCollision3D")
	if col != null:
		col.set_meta("sim_model_hash", _model_hash)
	var vis := root.get_node_or_null("World3D/LevelVisual3D")
	if vis != null:
		vis.set_meta("sim_model_hash", _model_hash)


func _physics_process(delta: float) -> void:
	if _sim == null or _sim.state == null or _death_busy:
		return
	var wish := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_down", "move_up")
	)
	_last_wish = wish
	var action_down := Input.is_action_pressed("transfer")
	var action_edge := Input.is_action_just_pressed("transfer")
	var ollie_down := Input.is_action_pressed("ollie")
	var ollie_released := Input.is_action_just_released("ollie")
	_sync_tuning_to_sim()
	_sim.set_input(wish, action_down, action_edge, ollie_down, ollie_released)
	_sim.tick(delta)
	_sync_from_sim()
	_capture_pose_snapshots()
	if not _sim.state.alive:
		_begin_death()


func _sync_tuning_to_sim() -> void:
	if _sim == null:
		return
	_sim.accel = accel
	_sim.max_speed = max_speed_x
	_sim.max_speed_z = max_speed_z
	_sim.ollie_accel = ollie_accel
	_sim.ollie_charge_ms = ollie_charge_ms
	_sim.ollie_height = ollie_height
	_sim.ollie_lip_frac = ollie_lip_frac
	_sim.brake = brake
	_sim.friction = friction
	_sim.ramp_friction = ramp_friction
	SimTolerances.GRAVITY = gravity_ms2 * SimTolerances.LOGIC_PER_METER
	SimTolerances.FLY_OUT_ABOVE = fly_out_above_coping
	SimTolerances.APEX_FACING_DELAY = apex_facing_delay
	SimTolerances.FACING_COPING_CELLS = facing_coping_cells
	SimTolerances.ACID_COPING_CELLS = acid_coping_cells


func _sync_from_sim() -> void:
	var st: SimState = _sim.state
	var p := st.position
	facing_h = st.facing
	visual_facing_h = st.visual_facing
	facing_yaw = st.facing_yaw
	_airborne = st.is_airborne()
	air_abs_height = p.z
	last_surface = {
		"zone": _zone_from_state(st),
		"surface_id": st.surface_id,
	}
	var tilt := 0.0
	if st.is_hanging():
		# Prefer live anchor; off-span hang still leans from the launch pipe.
		var hang_pipe: PipeSurface = null
		var edge: TopologyEdge = _sim.model.edges.get(st.hang_edge_id)
		var anchor := _sim.query.edge_anchor_sample(edge, p.y) if edge != null else {}
		if not anchor.is_empty():
			hang_pipe = _sim.model.pipes.get(str(anchor.get("source_pipe_id", ""))) as PipeSurface
		if hang_pipe == null:
			var launch_id := st.hang_launch_edge_id if not st.hang_launch_edge_id.is_empty() \
					else st.hang_edge_id
			var launch: TopologyEdge = _sim.model.edges.get(launch_id)
			if launch != null:
				if _sim.model.pipes.has(launch.from_surface_id):
					hang_pipe = _sim.model.pipes[launch.from_surface_id] as PipeSurface
				elif _sim.model.walls.has(launch.from_surface_id):
					var hang_wall: WallSurface = _sim.model.walls[launch.from_surface_id]
					hang_pipe = _sim.model.pipes.get(hang_wall.source_pipe_id) as PipeSurface
		if hang_pipe != null:
			tilt = -hang_pipe.outward_sign() * (PI * 0.5)
			_carry_tilt = tilt
	elif st.is_grounded() and _sim.model.walls.has(st.surface_id):
		var wall: WallSurface = _sim.model.walls[st.surface_id]
		var wall_pipe: PipeSurface = _sim.model.pipes[wall.source_pipe_id]
		tilt = -wall_pipe.outward_sign() * (PI * 0.5)
		_carry_tilt = tilt
	elif st.is_grounded() and _sim.model.pipes.has(st.surface_id):
		var pipe: PipeSurface = _sim.model.pipes[st.surface_id]
		var th := st.u * (PI * 0.5)
		tilt = -pipe.outward_sign() * th
		_carry_tilt = tilt
	elif st.is_grounded() and _sim.model.ramps.has(st.surface_id):
		var ramp: RampSurface = _sim.model.ramps[st.surface_id]
		# Match pipe lean along incline (u∈[0,1] → 0…45° at full rise).
		tilt = -ramp.outward_sign() * (st.u * PI * 0.25)
		_carry_tilt = tilt
	elif st.is_airborne():
		# Transfer: lerp carry lean toward the destination lip/peak.
		if st.has_maneuver() and st.maneuver is ManeuverPlan \
				and (st.maneuver as ManeuverPlan).kind == ManeuverPlan.Kind.TRANSFER:
			var tplan: ManeuverPlan = st.maneuver
			if not _transfer_tilt_active:
				_transfer_tilt_start = _carry_tilt
				_transfer_tilt_end = tplan.tilt_end
				_transfer_tilt_active = true
			# Start lean → upright at apex_frac → dest. Always from progress 0.
			var tt := tplan.progress
			var apex := clampf(tplan.apex_frac, 0.001, 0.999)
			if tt < apex:
				tilt = lerp_angle(_transfer_tilt_start, 0.0, tt / apex)
			else:
				tilt = lerp_angle(0.0, _transfer_tilt_end, (tt - apex) / (1.0 - apex))
			_carry_tilt = tilt
		elif st.free_air_upright:
			# Air-out hang / ollie keep surface lean. Fly-out / deck-out stands upright.
			_transfer_tilt_active = false
			tilt = 0.0
			_carry_tilt = 0.0
		else:
			_transfer_tilt_active = false
			tilt = _carry_tilt
	else:
		_transfer_tilt_active = false
		_carry_tilt = 0.0
	var support_h := p.z
	if st.is_hanging():
		var support_edge: TopologyEdge = _sim.model.edges.get(st.hang_edge_id)
		var support_anchor := _sim.query.edge_anchor_sample(support_edge, p.y) \
				if support_edge != null else {}
		if support_anchor.is_empty() and not st.hang_launch_edge_id.is_empty():
			var launch_edge: TopologyEdge = _sim.model.edges.get(st.hang_launch_edge_id)
			if launch_edge != null:
				var z_ref := clampf(p.y, launch_edge.z_min, launch_edge.z_max - 0.001)
				support_anchor = _sim.query.edge_anchor_sample(launch_edge, z_ref)
		if not support_anchor.is_empty():
			support_h = float(support_anchor.height)
	if depth:
		depth.logical_x = p.x
		depth.logical_z = p.y
		depth.surface_height = p.z
		depth.airborne = _airborne
		depth.support_height = support_h
		depth.surface_tilt = tilt
		depth.apply()
	global_position = _WorldSpace.logical_to_world(p.x, p.y, p.z)
	collision_mask = 0


func _zone_from_state(st: SimState) -> String:
	if not st.alive:
		return "dead"
	if st.is_airborne():
		return "air"
	if _sim.model.pipes.has(st.surface_id):
		var pipe: PipeSurface = _sim.model.pipes[st.surface_id]
		return "left_pipe" if pipe.side == SimKinds.PipeSide.LEFT else "right_pipe"
	if _sim.model.walls.has(st.surface_id):
		var wall: WallSurface = _sim.model.walls[st.surface_id]
		var source: PipeSurface = _sim.model.pipes[wall.source_pipe_id]
		return "left_pipe" if source.side == SimKinds.PipeSide.LEFT else "right_pipe"
	if _sim.model.patches.has(st.surface_id):
		var patch: SupportPatch = _sim.model.patches[st.surface_id]
		if patch.lethal:
			return "lava"
		if patch.kind == SimKinds.SurfaceKind.DECK:
			return "deck"
		return "flat"
	return "unknown"


func _capture_pose_snapshots() -> void:
	if depth == null:
		return
	var facing := 1.0 if visual_facing_h == "r" else -1.0
	var next = _LogicalPose.new()
	next.copy_from_depth(depth, facing, 0)
	next.facing_yaw = facing_yaw
	# Mirror by facing: +Z turns either nose toward +Z, not the same screen side.
	next.depth_turn_yaw = deg_to_rad(depth_turn_degrees) * _last_wish.y * facing
	if _pose_curr == null:
		_pose_prev = next
		_pose_curr = next
	else:
		_pose_prev = _pose_curr
		_pose_curr = next
	_pose_snap_ready = true


func _begin_death() -> void:
	if _death_busy:
		return
	_death_busy = true
	var overlay := get_tree().get_first_node_in_group("death_overlay")
	if overlay != null and overlay.has_method("play"):
		if not overlay.finished.is_connected(_on_death_finished):
			overlay.finished.connect(_on_death_finished, CONNECT_ONE_SHOT)
		overlay.play()
	else:
		_on_death_finished()


func _on_death_finished() -> void:
	if _sim != null:
		_sim.respawn()
	_death_busy = false
	_carry_tilt = 0.0
	_transfer_tilt_active = false
	_transfer_tilt_end = 0.0
	_sync_from_sim()
	_capture_pose_snapshots()


func cell_sample_xz() -> Vector2:
	if depth:
		return Vector2(depth.logical_x, depth.logical_z)
	return Vector2.ZERO


func cell_under_feet() -> Vector2i:
	if _level == null or _level.spec == null or depth == null:
		return Vector2i.ZERO
	return _level.spec.cell_at(depth.logical_x, depth.logical_z)


func zone_debug_label() -> String:
	if _sim == null or _sim.state == null:
		return "sim?"
	var st: SimState = _sim.state
	if not st.alive:
		return "dead"
	if st.is_airborne():
		if st.has_maneuver() and st.maneuver is ManeuverPlan:
			return "air %s" % (st.maneuver as ManeuverPlan).kind_name()
		return "air"
	var side := _surface_side_label(st.surface_id)
	if side.is_empty():
		return "gnd %s" % st.surface_id
	return "gnd %s %s" % [side, st.surface_id]


## Pipe/ramp open side: "left" / "right". Walls use their source surface.
func _surface_side_label(surface_id: String) -> String:
	if _sim == null or _sim.model == null or surface_id.is_empty():
		return ""
	var model: ParkModel = _sim.model
	if model.pipes.has(surface_id):
		var pipe: PipeSurface = model.pipes[surface_id]
		return "left" if pipe.side == SimKinds.PipeSide.LEFT else "right"
	if model.ramps.has(surface_id):
		var ramp: RampSurface = model.ramps[surface_id]
		return "left" if ramp.side == SimKinds.PipeSide.LEFT else "right"
	if model.walls.has(surface_id):
		var wall: WallSurface = model.walls[surface_id]
		return _surface_side_label(wall.source_pipe_id)
	return ""


func ollie_charge_frac() -> float:
	if _sim == null:
		return 0.0
	if not _sim.ollie_available:
		return 0.0
	return clampf(_sim.ollie_charge, 0.0, 1.0)


func next_facing_coping_debug() -> String:
	if _sim == null or _sim.state == null or _sim.query == null:
		return "—"
	var cands: Array = _sim.query.transfer_candidates(_sim.state)
	if cands.is_empty():
		return "no coping"
	var c: Dictionary = cands[0]
	return "%s %s d=%.0f" % [
		str(c.get("side", "?")),
		str(c.get("coping_id", c.get("id", "?"))),
		float(c.get("distance", c.get("dist", 0.0))),
	]


func motion_world(kind: int) -> Vector3:
	if _sim == null or _sim.state == null:
		return Vector3.ZERO
	var st: SimState = _sim.state
	match kind:
		MotionVectors.Kind.INPUT:
			return _WorldSpace.logical_velocity_to_world(
				_last_wish.x * max_speed_x, _last_wish.y * max_speed_x, 0.0
			)
		MotionVectors.Kind.MOMENTUM:
			if st.is_airborne():
				return _WorldSpace.logical_velocity_to_world(st.velocity.x, st.velocity.y, st.velocity.z)
			return _WorldSpace.logical_velocity_to_world(
				st.tangent_velocity.x, st.tangent_velocity.y, 0.0
			)
		_:
			if st.is_airborne():
				return _WorldSpace.logical_velocity_to_world(st.velocity.x, st.velocity.y, st.velocity.z)
			return _WorldSpace.logical_velocity_to_world(
				st.tangent_velocity.x, st.tangent_velocity.y, 0.0
			)


func motion_speed(kind: int) -> float:
	return motion_world(kind).length() * _WorldSpace.LOGIC_PER_METER


func sim_model_hash() -> String:
	return _model_hash


func get_sim() -> PlayerSim:
	return _sim
