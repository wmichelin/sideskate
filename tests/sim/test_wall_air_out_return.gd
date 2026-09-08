extends RefCounted

const FIXTURE := "res://tests/levels/sim/wall_deck_return.ssk"


func cases() -> Array:
	return ["wall_return", "deck_collision_guards"]


func run() -> bool:
	return wall_return() and deck_collision_guards()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
	return ok


func _approach(direction: float, speed: float, z: float) -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(FileAccess.get_file_as_string(FIXTURE)):
		return null
	var x := 600.0 if direction > 0 else sim.model.width - 600.0
	for patch in sim.model.patches.values():
		if patch.height == 0.0 and patch.contains_xz(x, z) and not patch.lethal:
			sim.state.surface_id = patch.id
			sim.state.position = Vector3(x, z, 0)
			break
	sim.state.set_facing_side("r" if direction > 0 else "l")
	sim.max_speed = speed
	for tick in 180:
		sim.set_input(Vector2(direction, 0), false, false)
		sim.tick()
		if sim.state.falling or not sim.state.alive:
			return null
		if sim.state.is_hanging():
			return sim
	return null


func wall_return() -> bool:
	for direction in [-1.0, 1.0]:
		for speed in [450.0, 650.0, 880.0]:
			for z in [47.0, 117.5, 188.0]:
				var sim := _approach(direction, speed, z)
				if not _check(sim != null, "Wall return must reach air-out through movement input"):
					return false
				var wall_id: String = sim.model.edges[sim.state.hang_edge_id].from_surface_id
				if not _check(sim.model.walls.has(wall_id), "Fixture must launch from the deck-backed wall"):
					return false
				var anchor_x := sim.state.position.x
				var remounted := false
				var rolled_away := false
				for tick in 180:
					sim.set_input(Vector2.ZERO, false, false)
					sim.tick()
					var s := sim.state
					if not _check(s.alive and not s.falling and not s.request_fall,
							"No-trick wall return must not wipe out: direction=%s speed=%s z=%s tick=%s surface=%s" % [direction, speed, z, tick, s.surface_id]):
						return false
					if s.is_hanging() and not _check(absf(s.position.x - anchor_x) < 0.001,
							"Wall air-out must retain its anchor"):
						return false
					if s.is_grounded() and not remounted:
						if not _check(s.surface_id == wall_id and s.tangent_velocity.x < -100.0,
								"Return must seat the source wall downhill, never the abutting deck"):
							return false
						remounted = true
					if remounted and s.position.z < 0.01 and s.is_grounded():
						rolled_away = true
						break
				if not _check(remounted and rolled_away, "Wall return must continue down the pipe onto the floor"):
					return false
	return true


func deck_collision_guards() -> bool:
	var sim := _approach(1.0, 880.0, 117.5)
	if sim == null:
		return _check(false, "Deck collision guard fixture must reach air-out")
	var s := sim.state
	var wall: WallSurface = sim.model.walls[sim.model.edges[s.hang_edge_id].from_surface_id]
	var top: Dictionary = wall.sample_at_z(s.position.y)
	var pad: SupportPatch = null
	for patch in sim.model.patches.values():
		if int(patch.kind) == SimKinds.SurfaceKind.DECK and absf(patch.x_min - s.position.x) < 0.01 and absf(patch.height - float(top.top_height)) < 0.01:
			pad = patch
			break
	if not _check(pad != null, "Deck must abut the upper wall lip"):
		return false
	var classifier := CrashClassifier.new(sim.model)
	var contact := {"kind": "support_top", "surface_id": pad.id, "owner_id": pad.id, "support_kind": SimKinds.SurfaceKind.DECK}
	if not _check(not classifier.is_crash(s, contact, {"mode": "hang_clip"}),
			"Touching the owned wall's deck seam must remain a remount corridor"):
		return false
	s.position.x += SimTolerances.CAPSULE_RADIUS * 3.0
	if not _check(classifier.is_crash(s, contact, {"mode": "hang_clip"}), "A deep deck clip must still cause a fall"):
		return false
	s.position.x = float(top.x)
	s.clear_hang()
	var solid := contact.duplicate()
	solid["kind"] = "deck"
	return _check(classifier.is_crash(s, solid, {"mode": "reject"})
		and classifier.is_crash(s, contact, {"mode": "hang_flat_mount", "was_hanging": true}),
		"Free-air deck collision and an actual flat hang landing must still cause falls")
