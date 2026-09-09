extends RefCounted

const MODEL := preload("res://assets/characters/ssk_skater.glb")
const DT := 1.0 / 60.0


func cases() -> Array:
	return ["charge_holds_and_cancels", "successful_ollie_and_landing", "ride_off_and_fall_recovery", "planted_feet_and_board", "knees_and_pop_sequence", "board_follows_baked_pose", "descent_prepares_and_landing_compresses"]


func run() -> bool:
	var ok := true
	for test in cases():
		ok = bool(call(test)) and ok
	return ok


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
	var marker := skeleton.find_bone("board_pose")
	if not _check(marker >= 0, "Export must retain the authored board pose"):
		f.node.free()
		return false
	for clip in SkaterAnimationController.REQUIRED:
		player.play(clip, 0.0)
		for sample in 5:
			player.seek(player.get_animation(clip).length * sample / 4.0, true)
			player.advance(0.0)
			for side in ["L", "R"]:
				var index := skeleton.find_bone("foot_" + side)
				if index == -1:
					index = skeleton.find_bone("foot." + side)
				var board_pose := skeleton.get_bone_global_pose(marker) * skeleton.get_bone_global_rest(marker).affine_inverse()
				var foot := board_pose.affine_inverse() * skeleton.get_bone_global_pose(index).origin
				ok = _check(absf(foot.y - 0.13) < 0.01 and absf(absf(foot.x) - 0.32) < 0.01,
					"Gameplay soles must follow the animated board plane: %s %s %s" % [clip, side, foot]) and ok
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


func _bone(skeleton: Skeleton3D, name: String) -> int:
	var index := skeleton.find_bone(name)
	return index if index >= 0 else skeleton.find_bone(name.replace(".", "_"))


func knees_and_pop_sequence() -> bool:
	var f := _fixture()
	var skeleton: Skeleton3D = f.skeleton
	var player: AnimationPlayer = f.player
	var ok := true
	# Inspect the exported knees, not just the authoring control locations.
	for clip in ["ollie_charge", "airborne", "landing"]:
		player.play(clip, 0.0)
		for sample in 11:
			player.seek(player.get_animation(clip).length * sample / 10.0, true)
			player.advance(0.0)
			var pelvis := skeleton.get_bone_global_pose(_bone(skeleton, "pelvis")).origin
			if pelvis.y > 0.7:
				continue
			for side in ["L", "R"]:
				var sign_x := 1.0 if side == "L" else -1.0
				var knee := skeleton.get_bone_global_pose(_bone(skeleton, "shin." + side)).origin
				var foot := skeleton.get_bone_global_pose(_bone(skeleton, "foot." + side)).origin
				ok = _check(sign_x * (knee.x - foot.x) > -0.025,
					"Deep crouch knees must track over the feet, not collapse inward: %s %s %s" % [clip, side, knee]) and ok
	player.play("ollie_pop", 0.0)
	player.seek(2.0 / 30.0, true)
	player.advance(0.0)
	var front := skeleton.get_bone_global_pose(_bone(skeleton, "shin.L")).origin
	var rear := skeleton.get_bone_global_pose(_bone(skeleton, "shin.R")).origin
	ok = _check(front.y > rear.y + 0.07, "The front knee must lead the ollie pop") and ok
	f.node.free()
	return ok


func board_follows_baked_pose() -> bool:
	var presenter := LogicalPosePresenter3D.new()
	presenter.skater_mesh = MODEL
	presenter.skater_yaw_offset = PI
	(Engine.get_main_loop() as SceneTree).root.add_child(presenter)
	var player := presenter._skater_anim
	player.play("ollie_pop", 0.0)
	player.seek(2.0 / 30.0, true)
	player.advance(0.0)
	var ok := true
	for facing in [-1.0, 1.0]:
		for yaw in [0.0, 0.7]:
			var pose := LogicalPose.new()
			pose.airborne = true
			pose.feet_height = 250
			pose.facing_h = facing
			pose.facing_yaw = yaw
			pose.board_yaw = yaw
			presenter.apply_pose(pose)
			var board := presenter._board
			var top := board.position + board.basis.y * presenter.board_size.y * 0.5
			ok = _check(top.distance_to(presenter._skater.position) < 0.001,
				"Ollie board must pivot beneath the soles without an extra jump offset") and ok
			ok = _check(board.basis.y.dot(Vector3.UP) < 0.99,
				"Board must display the authored pop tilt in either facing: bone=%s basis=%s" % [presenter._board_pose_bone, board.basis]) and ok
	presenter.free()
	return ok


func descent_prepares_and_landing_compresses() -> bool:
	var f := _fixture()
	var c: SkaterAnimationController = f.controller
	var skeleton: Skeleton3D = f.skeleton
	var pelvis := _bone(skeleton, "pelvis")
	for tick in 12:
		c.tick(DT, true, false, 0, false, false, 0)
	var tucked := skeleton.get_bone_global_pose(pelvis).origin.y
	for tick in 20:
		c.tick(DT, true, false, 0, false, false, -float(tick + 1) * 32.5)
	var prepared := skeleton.get_bone_global_pose(pelvis).origin.y
	var ok := _check(prepared - tucked > 0.12,
		"Descent must extend the tucked legs in preparation for contact")
	for tick in 6:
		c.tick(DT, false, false, 0, false, false, 0)
	var compressed := skeleton.get_bone_global_pose(pelvis).origin.y
	ok = _check(c.pose_name == c.LAND and prepared - compressed > 0.12,
		"Landing must absorb impact before standing back up") and ok
	for tick in 24:
		c.tick(DT, false, false, 0, false, false, 0)
	ok = _check(c.pose_name == c.RIDE and skeleton.get_bone_global_pose(pelvis).origin.y - compressed > 0.2,
		"Impact compression must recover smoothly into riding") and ok
	f.node.free()
	return ok
