extends RefCounted
## Swept landings must acquire support at their actual contact XZ, including holes.

const EDGE := "ssk 2\nname crossing_edge\n---\nlayer 0\nheight 0\n..@===\n..====\n..====\n"
const HOLE := "ssk 2\nname crossing_hole\n---\nlayer 0\nheight 0\n======\n=@..==\n==..==\n======\n"


func cases() -> Array:
	return ["outside_edge_cannot_own_feet", "hole_cannot_own_feet", "contacts_stay_in_footprints", "legitimate_landings"]


func run() -> bool:
	return outside_edge_cannot_own_feet() and hole_cannot_own_feet() \
		and contacts_stay_in_footprints() and legitimate_landings()


func _airborne(text: String, position: Vector3, velocity: Vector3) -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_text(text):
		return null
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.position = position
	sim.state.velocity = velocity
	sim.state.air_peak_height = 100.0
	sim.set_input(Vector2.ZERO, false, false)
	return sim


func outside_edge_cannot_own_feet() -> bool:
	var sim := _airborne(EDGE, Vector3(91, 70, 0.1), Vector3(360, 0, -34.333333))
	if sim == null:
		return false
	sim.tick()
	return _valid_ground_owner(sim)


func hole_cannot_own_feet() -> bool:
	# Travel out of the interior hole into its right or left boundary.
	for direction in [-1.0, 1.0]:
		var x := 97.0 if direction < 0.0 else 185.0
		var sim := _airborne(HOLE, Vector3(x, 70, 0.1), Vector3(direction * 360, 0, -34.333333))
		if sim == null:
			return false
		sim.tick()
		if not _valid_ground_owner(sim):
			return false
	return true


func contacts_stay_in_footprints() -> bool:
	var sim := _airborne(HOLE, Vector3.ZERO, Vector3.ZERO)
	if sim == null:
		return false
	for pair in [
		[Vector3(97, 70, 0.1), Vector3(91, 70, -1)],
		[Vector3(185, 70, 0.1), Vector3(191, 70, -1)],
		[Vector3(70, 94, 1), Vector3(200, 94, -1)],
	]:
		for contact in sim.query.collect_air_contacts(pair[0], pair[1]):
			if str(contact.kind) != "support_top":
				continue
			var point: Vector3 = contact.point
			var owner := str(contact.surface_id)
			var projection := sim.query.project_to_surface(owner, point.x, point.y, point.z)
			if not bool(projection.ok):
				return _fail("crossing %s lies outside %s" % [point, owner])
	return true


func legitimate_landings() -> bool:
	for speed in [-880.0, 0.0, 880.0]:
		var sim := _airborne(EDGE, Vector3(160, 70, 3), Vector3(speed, 0, -300))
		if sim == null:
			return false
		sim.tick()
		if not sim.state.is_grounded() or not _valid_ground_owner(sim):
			return _fail("valid descending floor contact did not land")
	# Landing into a slope's lower ride band must still retain that surface.
	for glyph in [")", "(", ">", "<"]:
		var text := "ssk 2\nname crossing_slope\n---\nlayer 0\nheight 0\n===%s===\n=@=%s===\n===%s===\n" % [glyph.repeat(3), glyph.repeat(3), glyph.repeat(3)]
		var sim := _airborne(text, Vector3.ZERO, Vector3.ZERO)
		if sim == null:
			return false
		var ids := sim.model.all_pipe_ids() if glyph in [")", "("] else sim.model.all_ramp_ids()
		var sid := str(ids[0])
		var surf = sim.model.pipes.get(sid, sim.model.ramps.get(sid))
		var x: float = surf.x_at_theta(70.0, 0.2)
		var h: float = surf.height_at_theta(70.0, 0.2)
		sim.state.position = Vector3(x, 70, h + 3.0)
		sim.state.velocity = Vector3(0, 0, -300)
		sim.state.air_launch_surface_id = sid
		sim.tick()
		if not sim.state.is_grounded() or sim.state.surface_id != sid:
			return _fail("valid %s descending contact did not land" % glyph)
	return true


func _valid_ground_owner(sim: PlayerSim) -> bool:
	if not sim.state.is_grounded():
		return true
	var p := sim.state.position
	var projection := sim.query.project_to_surface(sim.state.surface_id, p.x, p.y, p.z)
	return bool(projection.ok) or _fail("grounded feet %s are outside owner %s" % [p, sim.state.surface_id])


func _fail(message: String) -> bool:
	push_error("support crossing: " + message)
	return false
