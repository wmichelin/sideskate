class_name PipeMeshBuilder
extends RefCounted
## Quarter-cylinder ride surface + outer wall + Z endcaps from QuarterPipe math.

const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")
const _FloorMeshBuilder := preload("res://scripts/mesh/floor_mesh_builder.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")

const ARC_STEPS := 12


static func build_from_pipes(pipes: Array) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_parts_from_pipes(pipes))


static func build_parts_from_pipes(pipes: Array) -> Array:
	var out: Array = []
	for pipe in pipes:
		if pipe is QuarterPipe:
			out.append_array(build_one_parts(pipe as QuarterPipe))
		elif pipe is Dictionary:
			var qp := QuarterPipe.new()
			qp.side = int(pipe.side)
			qp.lip_x = float(pipe.lip_x)
			qp.radius = float(pipe.radius)
			qp.base_height = float(pipe.get("base_height", 0.0))
			qp.layer = int(pipe.get("layer", 0))
			qp.z_min = float(pipe.z_min)
			qp.z_max = float(pipe.z_max)
			out.append_array(build_one_parts(qp))
	return out


static func build_one(pipe: QuarterPipe) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_one_parts(pipe))


static func build_one_parts(pipe: QuarterPipe) -> Array:
	var out: Array = []
	var ride = _build_ride_part(pipe)
	if ride != null and not ride.is_empty():
		out.append(ride)
	var wall = _build_outer_wall_part(pipe)
	if wall != null and not wall.is_empty():
		out.append(wall)
	var caps = _build_endcaps_part(pipe)
	if caps != null and not caps.is_empty():
		out.append(caps)
	return out


static func _pipe_meta(pipe: QuarterPipe, face_role: String) -> Dictionary:
	return {
		"zone": _PipeMath.zone_name(pipe.side),
		"layer": pipe.layer,
		"face_role": face_role,
		"side": pipe.side,
		"lip_x": pipe.lip_x,
		"radius": pipe.radius,
		"base_height": pipe.base_height,
		"z_min": pipe.z_min,
		"z_max": pipe.z_max,
		"top_coping": _PipeMath.coping_x(pipe.side, pipe.lip_x, pipe.radius),
	}


static func _build_ride_part(pipe: QuarterPipe):
	var part = _MeshPart.make("pipe_ride", pipe.layer, _pipe_meta(pipe, "ride"))
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	for i in range(ARC_STEPS):
		var t0 := float(i) / float(ARC_STEPS)
		var t1 := float(i + 1) / float(ARC_STEPS)
		var theta0 := t0 * PI * 0.5
		var theta1 := t1 * PI * 0.5
		var p0 := profile_point(pipe, theta0, is_left)
		var p1 := profile_point(pipe, theta1, is_left)
		var a: Vector3 = _WorldSpace.logical_to_world(p0.x, z0, p0.y)
		var b: Vector3 = _WorldSpace.logical_to_world(p1.x, z0, p1.y)
		var c: Vector3 = _WorldSpace.logical_to_world(p1.x, z1, p1.y)
		var d: Vector3 = _WorldSpace.logical_to_world(p0.x, z1, p0.y)
		# Outward-facing; WorldSpace X-mirror reverses winding vs logical layout.
		if is_left:
			part.append_tri(a, c, d)
			part.append_tri(a, b, c)
		else:
			part.append_tri(a, c, b)
			part.append_tri(a, d, c)
	return part


static func _build_outer_wall_part(pipe: QuarterPipe):
	var part = _MeshPart.make("pipe_wall", pipe.layer, _pipe_meta(pipe, "back"))
	var cope_x := _PipeMath.coping_x(pipe.side, pipe.lip_x, pipe.radius)
	var top_h := pipe.base_height + pipe.radius
	var bot := pipe.base_height
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var a: Vector3 = _WorldSpace.logical_to_world(cope_x, z0, top_h)
	var b: Vector3 = _WorldSpace.logical_to_world(cope_x, z1, top_h)
	var c: Vector3 = _WorldSpace.logical_to_world(cope_x, z1, bot)
	var d: Vector3 = _WorldSpace.logical_to_world(cope_x, z0, bot)
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	if is_left:
		part.append_tri(a, c, b)
		part.append_tri(a, d, c)
	else:
		part.append_tri(a, c, d)
		part.append_tri(a, b, c)
	return part


static func _build_endcaps_part(pipe: QuarterPipe):
	var part = _MeshPart.make("pipe_wall", pipe.layer, _pipe_meta(pipe, "endcap"))
	_endcap_at(part, pipe, pipe.z_min, true)
	_endcap_at(part, pipe, pipe.z_max, false)
	return part


static func _endcap_at(part, pipe: QuarterPipe, logical_z: float, near_face: bool) -> void:
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var cope_profile := profile_point(pipe, PI * 0.5, is_left)
	var cope_bot: Vector3 = _WorldSpace.logical_to_world(cope_profile.x, logical_z, pipe.base_height)
	for i in range(ARC_STEPS):
		var t0 := float(i) / float(ARC_STEPS)
		var t1 := float(i + 1) / float(ARC_STEPS)
		var p0 := profile_point(pipe, t0 * PI * 0.5, is_left)
		var p1 := profile_point(pipe, t1 * PI * 0.5, is_left)
		var a: Vector3 = _WorldSpace.logical_to_world(p0.x, logical_z, p0.y)
		var b: Vector3 = _WorldSpace.logical_to_world(p1.x, logical_z, p1.y)
		if near_face:
			part.append_tri(cope_bot, a, b)
		else:
			part.append_tri(cope_bot, b, a)


## Profile point: Vector2(x, height) at angle theta from lip (0) to coping (π/2).
static func profile_point(pipe: QuarterPipe, theta: float, is_left: bool) -> Vector2:
	var h := pipe.base_height + pipe.radius * (1.0 - cos(theta))
	var x: float
	if is_left:
		x = pipe.lip_x - pipe.radius * sin(theta)
	else:
		x = pipe.lip_x + pipe.radius * sin(theta)
	return Vector2(x, h)


## Backward-compatible alias used by tests.
static func _profile_point(pipe: QuarterPipe, theta: float, is_left: bool) -> Vector2:
	return profile_point(pipe, theta, is_left)
