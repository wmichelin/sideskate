class_name PlayerDebug3D
extends Node3D
## 3D motion-vector arrows + head zone label (Body CanvasItem debug is hidden in 3D).

@export var player_path: NodePath = NodePath("../../Player")
@export var min_speed: float = 8.0
@export var units_per_speed: float = 0.08
@export var min_length: float = 18.0
@export var max_length: float = 90.0
@export var head_offset: Vector3 = Vector3(0.0, 52.0, 0.0)

var _player: Node
var _head: Label3D
var _arrows: Dictionary = {}


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return
	_player = get_node_or_null(player_path)
	_head = Label3D.new()
	_head.name = "HeadDebug"
	_head.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_head.font_size = 48
	_head.modulate = Color(0.9, 0.93, 0.98, 1)
	_head.outline_size = 8
	_head.outline_modulate = Color(0, 0, 0, 0.75)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_head.position = head_offset
	_head.visible = false
	add_child(_head)

	_spawn_arrow(MotionVectors.Kind.ACTUAL, Vector3(-12, 48, 0), MotionVectors.debug_color(MotionVectors.Kind.ACTUAL))
	_spawn_arrow(MotionVectors.Kind.MOMENTUM, Vector3(12, 48, 0), MotionVectors.debug_color(MotionVectors.Kind.MOMENTUM))
	_spawn_arrow(MotionVectors.Kind.INPUT, Vector3(0, 58, 0), MotionVectors.debug_color(MotionVectors.Kind.INPUT))


func _spawn_arrow(kind: MotionVectors.Kind, offset: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Arrow_%s" % MotionVectors.kind_name(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = offset
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	var speed := Label3D.new()
	speed.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speed.font_size = 28
	speed.modulate = Color(0.95, 0.95, 0.92, 1)
	speed.outline_size = 4
	speed.outline_modulate = Color(0, 0, 0, 0.7)
	speed.visible = false
	mi.add_child(speed)
	_arrows[kind] = {"mesh": mi, "mat": mat, "speed": speed, "color": color}


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path)
	if _player == null:
		return
	var depth: PseudoDepthBody = _player.get_node_or_null("PseudoDepthBody") as PseudoDepthBody
	if depth == null:
		return
	var feet_h := depth.surface_height
	if bool(_player.get("_airborne")):
		feet_h = float(_player.get("air_abs_height"))
	global_position = WorldSpace.logical_to_world(depth.logical_x, depth.logical_z, feet_h)
	global_rotation = Vector3.ZERO
	scale = Vector3.ONE

	_update_head()
	_update_arrows()


func _update_head() -> void:
	var on := DebugTools.show_head_debug
	_head.visible = on
	if on and _player.has_method("zone_debug_label"):
		_head.text = str(_player.call("zone_debug_label"))


func _update_arrows() -> void:
	var show := DebugTools.show_motion_vectors
	for kind in _arrows.keys():
		var entry: Dictionary = _arrows[kind]
		var mi: MeshInstance3D = entry.mesh
		var speed_lbl: Label3D = entry.speed
		if not show:
			mi.visible = false
			speed_lbl.visible = false
			continue
		if not _player.has_method("motion_world") or not _player.has_method("motion_speed"):
			mi.visible = false
			speed_lbl.visible = false
			continue
		var world_v: Vector3 = _player.call("motion_world", kind)
		var speed: float = float(_player.call("motion_speed", kind))
		if speed < min_speed or world_v.length_squared() < 0.0001:
			mi.visible = false
			speed_lbl.visible = false
			continue
		var dir := world_v.normalized()
		var length := clampf(speed * units_per_speed, min_length, max_length)
		mi.mesh = _arrow_mesh(dir * length, entry.color)
		mi.visible = true
		speed_lbl.visible = true
		speed_lbl.text = "%.0f" % speed
		speed_lbl.position = dir * length + Vector3(0, 6, 0)


func _arrow_mesh(tip: Vector3, color: Color) -> ImmediateMesh:
	var im := ImmediateMesh.new()
	var dir := tip.normalized() if tip.length_squared() > 0.0001 else Vector3.FORWARD
	var length := tip.length()
	var head_len := mini(12.0, length * 0.35)
	var head_w := head_len * 0.65
	var base := tip - dir * head_len
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized() * head_w

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(base)
	im.surface_end()

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	im.surface_set_color(color)
	im.surface_add_vertex(tip)
	im.surface_add_vertex(base + side)
	im.surface_add_vertex(base - side)
	im.surface_end()
	return im
