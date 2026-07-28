class_name PipeMeshBuilder
extends RefCounted
## Quarter-cylinder ride surface + outer wall + Z endcaps from QuarterPipe math.


const ARC_STEPS := 12


static func build_from_pipes(pipes: Array) -> Array:
	var out: Array = []
	for pipe in pipes:
		if pipe is QuarterPipe:
			out.append_array(build_one(pipe as QuarterPipe))
		elif pipe is Dictionary:
			var qp := QuarterPipe.new()
			qp.side = int(pipe.side)
			qp.lip_x = float(pipe.lip_x)
			qp.radius = float(pipe.radius)
			qp.base_height = float(pipe.get("base_height", 0.0))
			qp.layer = int(pipe.get("layer", 0))
			qp.z_min = float(pipe.z_min)
			qp.z_max = float(pipe.z_max)
			out.append_array(build_one(qp))
	return out


static func build_one(pipe: QuarterPipe) -> Array:
	var out: Array = []
	var ride := _build_ride(pipe)
	if ride != null:
		out.append({"mesh": ride, "material_key": "pipe_ride", "layer": pipe.layer})
	var wall := _build_outer_wall(pipe)
	if wall != null:
		out.append({"mesh": wall, "material_key": "pipe_wall", "layer": pipe.layer})
	var caps := _build_endcaps(pipe)
	if caps != null:
		out.append({"mesh": caps, "material_key": "pipe_wall", "layer": pipe.layer})
	return out


static func _build_ride(pipe: QuarterPipe) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	for i in range(ARC_STEPS):
		var t0 := float(i) / float(ARC_STEPS)
		var t1 := float(i + 1) / float(ARC_STEPS)
		var theta0 := t0 * PI * 0.5
		var theta1 := t1 * PI * 0.5
		var p0 := _profile_point(pipe, theta0, is_left)
		var p1 := _profile_point(pipe, theta1, is_left)
		var a := WorldSpace.logical_to_world(p0.x, z0, p0.y)
		var b := WorldSpace.logical_to_world(p1.x, z0, p1.y)
		var c := WorldSpace.logical_to_world(p1.x, z1, p1.y)
		var d := WorldSpace.logical_to_world(p0.x, z1, p0.y)
		# Outward-facing; WorldSpace X-mirror reverses winding vs logical layout.
		if is_left:
			_tri(st, a, c, d)
			_tri(st, a, b, c)
		else:
			_tri(st, a, c, b)
			_tri(st, a, d, c)
	st.generate_normals()
	return st.commit()


static func _build_outer_wall(pipe: QuarterPipe) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cope_x := PipeMath.coping_x(pipe.side, pipe.lip_x, pipe.radius)
	var top_h := pipe.base_height + pipe.radius
	var bot := pipe.base_height
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var a := WorldSpace.logical_to_world(cope_x, z0, top_h)
	var b := WorldSpace.logical_to_world(cope_x, z1, top_h)
	var c := WorldSpace.logical_to_world(cope_x, z1, bot)
	var d := WorldSpace.logical_to_world(cope_x, z0, bot)
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	if is_left:
		_tri(st, a, c, b)
		_tri(st, a, d, c)
	else:
		_tri(st, a, c, d)
		_tri(st, a, b, c)
	st.generate_normals()
	return st.commit()


static func _build_endcaps(pipe: QuarterPipe) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_endcap_at(st, pipe, pipe.z_min, true)
	_endcap_at(st, pipe, pipe.z_max, false)
	st.generate_normals()
	return st.commit()


static func _endcap_at(st: SurfaceTool, pipe: QuarterPipe, logical_z: float, near_face: bool) -> void:
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	# Solid under the ride arc: fan from the outer base corner (cope_x, base)
	# through arc samples — same silhouette as RampVisual._draw_pipe_endcap
	# (arc → outer drop → base), not a hard chord triangle.
	var cope_profile := _profile_point(pipe, PI * 0.5, is_left)
	var cope_bot := WorldSpace.logical_to_world(cope_profile.x, logical_z, pipe.base_height)
	for i in range(ARC_STEPS):
		var t0 := float(i) / float(ARC_STEPS)
		var t1 := float(i + 1) / float(ARC_STEPS)
		var p0 := _profile_point(pipe, t0 * PI * 0.5, is_left)
		var p1 := _profile_point(pipe, t1 * PI * 0.5, is_left)
		var a := WorldSpace.logical_to_world(p0.x, logical_z, p0.y)
		var b := WorldSpace.logical_to_world(p1.x, logical_z, p1.y)
		# WorldSpace X-mirror reverses near/far winding.
		if near_face:
			_tri(st, cope_bot, a, b)
		else:
			_tri(st, cope_bot, b, a)


## Profile point: Vector2(x, height) at angle theta from lip (0) to coping (π/2).
static func _profile_point(pipe: QuarterPipe, theta: float, is_left: bool) -> Vector2:
	var h := pipe.base_height + pipe.radius * (1.0 - cos(theta))
	var x: float
	if is_left:
		x = pipe.lip_x - pipe.radius * sin(theta)
	else:
		x = pipe.lip_x + pipe.radius * sin(theta)
	return Vector2(x, h)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
