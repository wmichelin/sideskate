extends RefCounted

const MODEL := preload("res://assets/characters/ssk_skater.glb")
const DT := 1.0 / 60.0


func cases() -> Array:
	return ["charge_holds_and_cancels", "successful_ollie_and_landing", "ride_off_and_fall_recovery", "planted_feet_and_board"]


func run() -> bool:
	return charge_holds_and_cancels() and successful_ollie_and_landing() and ride_off_and_fall_recovery() and planted_feet_and_board()


func _fixture() -> Dictionary:
	var node := MODEL.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	var player := node.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skeleton := node.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var controller := SkaterAnimationController.new()
	controller.configure(player)
	return {"node": node, "player": player, "skeleton": skeleton, "controller": controller}


func _check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error(reason)
	return ok


func charge_holds_and_cancels() -> bool:
	var f := _fixture()
	var controller: SkaterAnimationController = f.controller
	var skeleton: Skeleton3D = f.skeleton
	var pelvis := skeleton.find_bone("pelvis")
	var ride_height := skeleton.get_bone_pose_position(pelvis).y
	for i in 90:
		controller.tick(DT, false, false, 1.0, false, false, 0.0)
	var crouch_height := skeleton.get_bone_pose_position(pelvis).y
	var ok := _check(controller.pose_name == controller.CHARGE and ride_height - crouch_height > 0.12,
		"Holding charge must hold a visibly lower pelvis without replaying the crouch")
	for i in 15:
		controller.tick(DT, false, false, 0.0, false, false, 0.0)
	ok = _check(controller.pose_name == controller.RIDE and absf(skeleton.get_bone_pose_position(pelvis).y - ride_height) < 0.015,
		"Cancelled charge must return to the ride pose") and ok
	f.node.free()
	return ok


func successful_ollie_and_landing() -> bool:
	var f := _fixture()
	var c: SkaterAnimationController = f.controller
	c.tick(DT, false, false, 1.0, false, false, 0)
	c.tick(DT, true, false, 0, true, false, 450)
	var ok := _check(c.pose_name == c.OLLIE, "Successful pop must start the ollie clip")
	for i in 30:
		c.tick(DT, true, false, 0, false, false, -100)
	ok = _check(c.pose_name == c.AIR, "Descending ollie must hold the airborne pose") and ok
	c.tick(DT, false, false, 0, false, false, 0)
	ok = _check(c.pose_name == c.LAND, "Real airborne-to-ground contact must trigger landing") and ok
	for i in 30:
		c.tick(DT, false, false, 0, false, false, 0)
	ok = _check(c.pose_name == c.RIDE, "Landing must settle back into riding") and ok
	f.node.free()
	return ok


func ride_off_and_fall_recovery() -> bool:
	var f := _fixture()
	var c: SkaterAnimationController = f.controller
	c.tick(DT, true, false, 0, false, false, 300)
	var ok := _check(c.pose_name == c.AIR, "Ride-off without a successful pop must use free-air pose")
	c.tick(DT, true, true, 0, false, false, -100)
	ok = _check(c.pose_name == c.FALL, "Wipeout must interrupt airborne animation") and ok
	c.reset()
	c.tick(DT, false, false, 0, false, false, 0)
	ok = _check(c.pose_name == c.RIDE, "Recovery must clear the old airborne bout") and ok
	c.tick(DT, false, false, 0, false, true, 0)
	ok = _check(c.pose_name == c.GRIND, "Rail contact must use the balance pose") and ok
	c.tick(DT, true, false, 0, true, false, 350)
	ok = _check(c.pose_name == c.OLLIE, "A rail ollie must interrupt grinding") and ok
	f.node.free()
	return ok


func planted_feet_and_board() -> bool:
	var f := _fixture()
	var player: AnimationPlayer = f.player
	var skeleton: Skeleton3D = f.skeleton
	var ok := true
	for clip in SkaterAnimationController.REQUIRED:
		player.play(clip, 0.0)
		for sample in 5:
			player.seek(player.get_animation(clip).length * sample / 4.0, true)
			player.advance(0.0)
			for side in ["L", "R"]:
				var index := skeleton.find_bone("foot_" + side)
				if index == -1:
					index = skeleton.find_bone("foot." + side)
				var foot := skeleton.get_bone_global_pose(index).origin
				ok = _check(absf(foot.y - 0.13) < 0.01 and absf(absf(foot.x) - 0.32) < 0.01,
					"Gameplay clips must keep both feet planted across the board: %s %s %s" % [clip, side, foot]) and ok
	f.node.free()
	var presenter := LogicalPosePresenter3D.new()
	presenter._build_meshes()
	var pose := LogicalPose.new()
	pose.airborne = true
	pose.feet_height = 250
	presenter.apply_pose(pose)
	var board := presenter.get_node("Board") as Node3D
	ok = _check(is_equal_approx(board.position.y, presenter.board_clearance + presenter.board_size.y * 0.5),
		"Bone animation must never add a second jump offset to the board") and ok
	presenter.free()
	return ok
