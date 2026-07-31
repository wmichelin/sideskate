class_name PlayerDebug3D
extends Node3D
## 3D motion-vector arrows + head zone label (Body CanvasItem debug is hidden in 3D).
## Ollie charge is a screen-space bar projected from the interpolated skater visual
## (same follow target as the camera) so it stays crisp while skating.

@export var player_path: NodePath = NodePath("../Player")
@export var visual_path: NodePath = NodePath("../PlayerVisual")
@export var min_speed: float = 8.0
@export var units_per_speed: float = 0.0008
@export var min_length: float = 0.18
@export var max_length: float = 0.90
@export var head_offset: Vector3 = Vector3(0.0, 0.52, 0.0)
@export var charge_bar_offset: Vector3 = Vector3(0.0, 0.72, 0.0)
@export var charge_bar_px: Vector2 = Vector2(72.0, 8.0)

var _player: Node
var _visual: Node3D
var _head: Label3D
var _charge_layer: CanvasLayer
var _charge_root: Control
var _charge_fill: ColorRect
var _charge_label: Label
var _arrows: Dictionary = {}
var _last_charge_frac: float = -1.0


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return
	# After PlayerVisual + CameraRig so unproject uses this frame's pose/camera.
	process_priority = 100
	_player = get_node_or_null(player_path)
	_visual = get_node_or_null(visual_path) as Node3D
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

	_setup_charge_bar()
	tree_exiting.connect(_free_charge_hud)

	_spawn_arrow(MotionVectors.Kind.ACTUAL, Vector3(-12, 48, 0), MotionVectors.debug_color(MotionVectors.Kind.ACTUAL))
	_spawn_arrow(MotionVectors.Kind.MOMENTUM, Vector3(12, 48, 0), MotionVectors.debug_color(MotionVectors.Kind.MOMENTUM))
	_spawn_arrow(MotionVectors.Kind.INPUT, Vector3(0, 58, 0), MotionVectors.debug_color(MotionVectors.Kind.INPUT))


func _free_charge_hud() -> void:
	if _charge_layer != null and is_instance_valid(_charge_layer):
		_charge_layer.queue_free()
		_charge_layer = null
		_charge_root = null
		_charge_fill = null
		_charge_label = null


func _setup_charge_bar() -> void:
	_free_charge_hud()
	# Drop any leftover world-space bar from older builds.
	var legacy := get_node_or_null("OllieChargeBar")
	if legacy != null:
		remove_child(legacy)
		legacy.free()
	# Clear a HUD left on Main from a previous deferred attach attempt.
	var scene := get_tree().current_scene
	if scene != null:
		var stale := scene.get_node_or_null("OllieChargeHud")
		if stale != null:
			stale.free()

	# CanvasLayer ignores parent 3D transform — safe to own it here (adding to
	# Main during _ready fails while the scene is still setting up children).
	_charge_layer = CanvasLayer.new()
	_charge_layer.name = "OllieChargeHud"
	_charge_layer.layer = 20
	add_child(_charge_layer)

	_charge_root = Control.new()
	_charge_root.name = "Root"
	_charge_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_root.visible = false
	_charge_layer.add_child(_charge_root)

	_charge_label = Label.new()
	_charge_label.name = "ChargeLabel"
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_charge_label.add_theme_font_size_override("font_size", 13)
	_charge_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85, 1))
	_charge_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_charge_label.add_theme_constant_override("outline_size", 2)
	_charge_label.position = Vector2(0.0, -18.0)
	_charge_label.size = Vector2(charge_bar_px.x, 16.0)
	_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_root.add_child(_charge_label)

	var bg := ColorRect.new()
	bg.name = "ChargeBg"
	bg.color = Color(0.08, 0.1, 0.14, 0.92)
	bg.position = Vector2.ZERO
	bg.size = charge_bar_px
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_root.add_child(bg)

	_charge_fill = ColorRect.new()
	_charge_fill.name = "ChargeFill"
	_charge_fill.color = Color(0.95, 0.72, 0.18, 1.0)
	_charge_fill.position = Vector2.ZERO
	_charge_fill.size = Vector2(0.0, charge_bar_px.y)
	_charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_charge_root.add_child(_charge_fill)


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
	if _visual == null:
		_visual = get_node_or_null(visual_path) as Node3D
	if _player == null:
		return
	# Keep 3D debug gizmos on the interpolated skater (camera follow target).
	if _visual != null:
		global_position = _visual.global_position
	else:
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
	_update_charge_bar()
	_update_arrows()


func _update_head() -> void:
	var on := DebugTools.show_head_debug
	_head.visible = on
	if on and _player.has_method("zone_debug_label"):
		_head.text = str(_player.call("zone_debug_label"))


func _update_charge_bar() -> void:
	if _charge_root == null:
		return
	# Fall countdown takes the head bar while falling; otherwise ollie charge.
	if DebugTools.show_fall_cooldown and _player.has_method("is_falling") \
			and bool(_player.call("is_falling")) and _player.has_method("fall_cooldown_frac"):
		var falling_frac := clampf(float(_player.call("fall_cooldown_frac")), 0.0, 1.0)
		_draw_head_bar(
			falling_frac,
			true,
			Color(0.45, 0.72, 0.95, 1.0),
			"%d%%" % int(round(falling_frac * 100.0))
		)
		return

	var on := DebugTools.show_ollie_charge
	if not on or not _player.has_method("ollie_charge_frac"):
		_charge_root.visible = false
		_last_charge_frac = -1.0
		return
	var frac := clampf(float(_player.call("ollie_charge_frac")), 0.0, 1.0)
	if frac <= 0.001:
		_charge_root.visible = false
		_last_charge_frac = frac
		return
	_draw_head_bar(
		frac,
		false,
		Color(0.95, 0.72, 0.18, 1.0),
		"%d%%" % int(round(frac * 100.0))
	)


func _draw_head_bar(frac: float, force_show: bool, fill_color: Color, label_text: String) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _visual == null:
		_charge_root.visible = false
		return
	var head_world := _visual.global_position + charge_bar_offset
	if cam.is_position_behind(head_world):
		_charge_root.visible = false
		return

	var screen: Vector2 = cam.unproject_position(head_world)
	_charge_root.position = Vector2(
		roundf(screen.x - charge_bar_px.x * 0.5),
		roundf(screen.y - charge_bar_px.y * 0.5)
	)
	_charge_root.visible = true
	_charge_fill.color = fill_color
	_charge_label.text = label_text
	var draw_key := frac + (10.0 if force_show else 0.0)
	if is_equal_approx(draw_key, _last_charge_frac) and _charge_fill.size.x >= 0.0:
		_charge_fill.size = Vector2(charge_bar_px.x * frac, charge_bar_px.y)
		return
	_last_charge_frac = draw_key
	_charge_fill.size = Vector2(charge_bar_px.x * frac, charge_bar_px.y)


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
