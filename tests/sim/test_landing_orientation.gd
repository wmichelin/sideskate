extends RefCounted

const PLAYER := preload("res://scripts/player.gd")


func cases() -> Array:
	return ["backwards_coast", "ground_roll_reversal", "spun_landing_continuity"]


func run() -> bool:
	return backwards_coast() and ground_roll_reversal() and spun_landing_continuity()


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error(reason)
	return ok


func _fixture(side: String):
	var player = PLAYER.new()
	player.depth = PseudoDepthBody.new()
	player._sim = PlayerSim.new()
	player._sim.setup_from_text(FileAccess.get_file_as_string("res://tests/levels/runtime/flat.ssk"))
	var state: SimState = player._sim.state
	state.set_facing_side(side)
	state.mode = SimState.Mode.AIRBORNE
	state.air_launch_surface_id = state.surface_id
	state.surface_id = ""
	state.position.z = 4000.0
	state.reset_air_spin()
	_capture(player)
	return player


func _capture(player) -> Vector2:
	var state: SimState = player._sim.state
	player.visual_facing_h = state.visual_facing
	player.facing_yaw = state.facing_yaw + state.spin_yaw
	player._capture_pose_snapshots()
	var pose: LogicalPose = player._pose_curr
	return Vector2(pose.facing_yaw + (PI if pose.facing_h < 0 else 0.0), pose.board_yaw)


func _dispose(player) -> void:
	player.depth.free()
	player.free()


func backwards_coast() -> bool:
	for side in ["l", "r"]:
		var player = _fixture(side)
		var sim: PlayerSim = player._sim
		var speed := 300.0 if side == "l" else -300.0
		sim.state.position.z = 2.0
		sim.state.velocity = Vector3(speed, 0, -150)
		var before := _capture(player)
		for tick in 45:
			sim.set_input(Vector2.ZERO, false, false)
			sim.tick()
			var after := _capture(player)
			if not _check(sim.state.is_grounded() and not sim.state.falling
					and sim.state.facing == side and absf(sim.state.tangent_velocity.x - speed) < 0.01
					and absf(angle_difference(before.x, after.x)) < 0.01
					and absf(angle_difference(before.y, after.y)) < 0.01,
					"Backwards landing must keep rider, board and momentum through coasting: %s tick %s" % [side, tick]):
				_dispose(player)
				return false
		_dispose(player)
	return true


func ground_roll_reversal() -> bool:
	for side in ["l", "r"]:
		var player = _fixture(side)
		var sim: PlayerSim = player._sim
		var direction := 1.0 if side == "r" else -1.0
		sim.state.position.z = 2.0
		sim.state.velocity = Vector3(direction * 300.0, 0, -150)
		sim.tick()
		for tick in 40:
			sim.set_input(Vector2(-direction, 0), false, false)
			sim.tick()
		if not _check(sim.state.is_grounded() and not sim.state.falling
				and sim.state.tangent_velocity.x * direction < -50.0
				and sim.state.facing != side,
				"Ground steering must still turn the rider when reversing a roll"):
			_dispose(player)
			return false
		_dispose(player)
	return true


func spun_landing_continuity() -> bool:
	for side in ["l", "r"]:
		for turns in [-2, -1, 1, 2]:
			for residual in [-0.15, 0.15]:
				var player = _fixture(side)
				var sim: PlayerSim = player._sim
				var speed := 300.0 if side == "r" else -300.0
				sim.state.velocity = Vector3(speed, 0, 0)
				var target: float = turns * PI + residual
				var previous := _capture(player)
				# Drive real spin input in fixed ticks, including both half-turn crossings.
				while absf(sim.state.spin_yaw) < absf(target):
					sim.set_input(Vector2.ZERO, false, false, false, false, target > 0, target < 0)
					sim.tick()
					var current := _capture(player)
					if not _check(absf(angle_difference(previous.x, current.x)) < 0.15,
							"Continuous spin must not double-flip the rider at a half-turn"):
						_dispose(player)
						return false
					previous = current
				var contact_residual: float = sim.state.spin_yaw - turns * PI
				var snapped: Vector2 = previous - Vector2.ONE * contact_residual
				sim.state.position.z = 2.0
				sim.state.velocity.z = -150.0
				for tick in 45:
					sim.set_input(Vector2.ZERO, false, false)
					sim.tick()
					var current := _capture(player)
					if not _check(sim.state.is_grounded() and not sim.state.falling
							and absf(angle_difference(previous.x, current.x)) < 0.15
							and absf(angle_difference(previous.y, current.y)) < 0.15,
							"Landing/settle/rebase must not reverse rider or board: %s turns %s tick %s" % [side, turns, tick]):
						_dispose(player)
						return false
					previous = current
				if not _check(absf(angle_difference(snapped.x, previous.x)) < 0.01
						and absf(angle_difference(snapped.y, previous.y)) < 0.01,
						"Settled landing must keep the completed trick's orientation"):
					_dispose(player)
					return false
				_dispose(player)
	return true
