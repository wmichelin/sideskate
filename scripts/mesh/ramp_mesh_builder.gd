class_name RampMeshBuilder
extends RefCounted
## Solid triangular prism: incline ride face, vertical back, Z endcaps, bottom.


const _MeshPart := preload("res://scripts/mesh/mesh_part.gd")
const _WorldSpace := preload("res://scripts/world_space.gd")
const _FloorMeshBuilder := preload("res://scripts/mesh/floor_mesh_builder.gd")
const _PipeMath := preload("res://scripts/pipe_math.gd")


static func build_from_pipes(pipes: Array) -> Array:
	return _FloorMeshBuilder._parts_to_legacy(build_parts_from_pipes(pipes))


static func build_parts_from_pipes(pipes: Array) -> Array:
	var out: Array = []
	for pipe in pipes:
		if pipe is QuarterPipe:
			if not (pipe as QuarterPipe).is_ramp():
				continue
			out.append_array(build_one_parts(pipe as QuarterPipe))
		elif pipe is Dictionary:
			if str(pipe.get("kind", "pipe")) != "ramp":
				continue
			var qp := QuarterPipe.new()
			qp.side = int(pipe.side)
			qp.lip_x = float(pipe.lip_x)
			qp.radius = float(pipe.radius)
			qp.base_height = float(pipe.get("base_height", 0.0))
			qp.layer = int(pipe.get("layer", 0))
			qp.z_min = float(pipe.z_min)
			qp.z_max = float(pipe.z_max)
			qp.kind = "ramp"
			out.append_array(build_one_parts(qp))
	return out


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
	var bottom = _build_bottom_part(pipe)
	if bottom != null and not bottom.is_empty():
		out.append(bottom)
	return out


static func _ramp_meta(pipe: QuarterPipe, face_role: String) -> Dictionary:
	return {
		"zone": _PipeMath.ramp_zone_name(pipe.side),
		"layer": pipe.layer,
		"face_role": face_role,
		"side": pipe.side,
		"lip_x": pipe.lip_x,
		"radius": pipe.radius,
		"base_height": pipe.base_height,
		"z_min": pipe.z_min,
		"z_max": pipe.z_max,
		"top_coping": _PipeMath.coping_x(pipe.side, pipe.lip_x, pipe.radius),
		"kind": "ramp",
	}


static func _profile_point(pipe: QuarterPipe, u: float) -> Vector2:
	var uu := clampf(u, 0.0, 1.0)
	var h := pipe.base_height + pipe.radius * uu
	var off := pipe.radius * uu
	var x := pipe.lip_x - off if pipe.side == QuarterPipe.PipeSide.LEFT else pipe.lip_x + off
	return Vector2(x, h)


static func _build_ride_part(pipe: QuarterPipe):
	var part = _MeshPart.make("ramp_ride", pipe.layer, _ramp_meta(pipe, "ride"))
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	var p0 := _profile_point(pipe, 0.0)
	var p1 := _profile_point(pipe, 1.0)
	var a: Vector3 = _WorldSpace.logical_to_world(p0.x, z0, p0.y)
	var b: Vector3 = _WorldSpace.logical_to_world(p1.x, z0, p1.y)
	var c: Vector3 = _WorldSpace.logical_to_world(p1.x, z1, p1.y)
	var d: Vector3 = _WorldSpace.logical_to_world(p0.x, z1, p0.y)
	if is_left:
		part.append_tri(a, c, d)
		part.append_tri(a, b, c)
	else:
		part.append_tri(a, c, b)
		part.append_tri(a, d, c)
	return part


static func _build_outer_wall_part(pipe: QuarterPipe):
	var part = _MeshPart.make("ramp_wall", pipe.layer, _ramp_meta(pipe, "back"))
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
	var part = _MeshPart.make("ramp_wall", pipe.layer, _ramp_meta(pipe, "endcap"))
	_endcap_at(part, pipe, pipe.z_min, true)
	_endcap_at(part, pipe, pipe.z_max, false)
	return part


static func _endcap_at(part, pipe: QuarterPipe, logical_z: float, near_face: bool) -> void:
	var lip := _profile_point(pipe, 0.0)
	var peak := _profile_point(pipe, 1.0)
	var bot_lip: Vector3 = _WorldSpace.logical_to_world(lip.x, logical_z, pipe.base_height)
	var bot_peak: Vector3 = _WorldSpace.logical_to_world(peak.x, logical_z, pipe.base_height)
	var top_lip: Vector3 = _WorldSpace.logical_to_world(lip.x, logical_z, lip.y)
	var top_peak: Vector3 = _WorldSpace.logical_to_world(peak.x, logical_z, peak.y)
	# Triangular prism end: lip→peak incline + vertical back + bottom.
	if near_face:
		part.append_tri(bot_lip, top_lip, top_peak)
		part.append_tri(bot_lip, top_peak, bot_peak)
	else:
		part.append_tri(bot_lip, top_peak, top_lip)
		part.append_tri(bot_lip, bot_peak, top_peak)


static func _build_bottom_part(pipe: QuarterPipe):
	var part = _MeshPart.make("ramp_wall", pipe.layer, _ramp_meta(pipe, "bottom"))
	var lip_x := pipe.lip_x
	var cope_x := _PipeMath.coping_x(pipe.side, pipe.lip_x, pipe.radius)
	var bot := pipe.base_height
	var z0 := pipe.z_min
	var z1 := pipe.z_max
	var a: Vector3 = _WorldSpace.logical_to_world(lip_x, z0, bot)
	var b: Vector3 = _WorldSpace.logical_to_world(cope_x, z0, bot)
	var c: Vector3 = _WorldSpace.logical_to_world(cope_x, z1, bot)
	var d: Vector3 = _WorldSpace.logical_to_world(lip_x, z1, bot)
	var is_left := pipe.side == QuarterPipe.PipeSide.LEFT
	# Downward-facing (into ground) — flip winding vs ride.
	if is_left:
		part.append_tri(a, b, c)
		part.append_tri(a, c, d)
	else:
		part.append_tri(a, c, b)
		part.append_tri(a, d, c)
	return part
