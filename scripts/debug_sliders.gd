extends CanvasLayer
## Top-right debug sliders. UI-only; simulation reads values on physics ticks.
## Collapsible body starts collapsed. Stripped in production via DebugTools.

@export var player_path: NodePath = NodePath("../Player")
@export var ramp_level_path: NodePath = NodePath("../RampLevel")
@export var ramp_visual_path: NodePath = NodePath("../RampLevel/RampVisual")
@export var start_collapsed: bool = true
@export var gravity_min: float = -30.0
@export var gravity_max: float = 0.0
@export var acid_buffer_min: float = 0.0
@export var acid_buffer_max: float = 80.0
@export var ollie_accel_min: float = 0.0
@export var ollie_accel_max: float = 3000.0
@export var max_speed_x_min: float = 50.0
@export var max_speed_x_max: float = 2000.0
@export var max_speed_z_min: float = 10.0
@export var max_speed_z_max: float = 400.0
@export var acceleration_min: float = 100.0
@export var acceleration_max: float = 6000.0
@export var brake_min: float = 0.0
@export var brake_max: float = 12000.0
@export var ramp_friction_min: float = 0.0
@export var ramp_friction_max: float = 2000.0
@export var friction_min: float = 0.0
@export var friction_max: float = 2000.0
@export var persp_inset_min: float = 0.0
@export var persp_inset_max: float = 200.0
@export var far_geom_min: float = 0.4
@export var far_geom_max: float = 1.0
@export var ref_depth_min: float = 20.0
@export var ref_depth_max: float = 500.0

@onready var _panel: PanelContainer = $Panel
@onready var _body: VBoxContainer = $Panel/VBox/Body
@onready var _toggle: Button = $Panel/VBox/Header/Toggle
@onready var _gravity_slider: HSlider = $Panel/VBox/Body/GravityRow/Slider
@onready var _gravity_value: Label = $Panel/VBox/Body/GravityRow/Value
@onready var _acid_slider: HSlider = $Panel/VBox/Body/AcidDropRow/Slider
@onready var _acid_value: Label = $Panel/VBox/Body/AcidDropRow/Value
@onready var _ollie_slider: HSlider = $Panel/VBox/Body/OllieAccelRow/Slider
@onready var _ollie_value: Label = $Panel/VBox/Body/OllieAccelRow/Value
@onready var _max_speed_x_slider: HSlider = $Panel/VBox/Body/MaxSpeedXRow/Slider
@onready var _max_speed_x_value: Label = $Panel/VBox/Body/MaxSpeedXRow/Value
@onready var _max_speed_z_slider: HSlider = $Panel/VBox/Body/MaxSpeedZRow/Slider
@onready var _max_speed_z_value: Label = $Panel/VBox/Body/MaxSpeedZRow/Value
@onready var _accel_slider: HSlider = $Panel/VBox/Body/AccelRow/Slider
@onready var _accel_value: Label = $Panel/VBox/Body/AccelRow/Value
@onready var _brake_slider: HSlider = $Panel/VBox/Body/BrakeRow/Slider
@onready var _brake_value: Label = $Panel/VBox/Body/BrakeRow/Value
@onready var _ramp_friction_slider: HSlider = $Panel/VBox/Body/RampFrictionRow/Slider
@onready var _ramp_friction_value: Label = $Panel/VBox/Body/RampFrictionRow/Value
@onready var _friction_slider: HSlider = $Panel/VBox/Body/FrictionRow/Slider
@onready var _friction_value: Label = $Panel/VBox/Body/FrictionRow/Value
@onready var _persp_inset_slider: HSlider = $Panel/VBox/Body/PerspInsetRow/Slider
@onready var _persp_inset_value: Label = $Panel/VBox/Body/PerspInsetRow/Value
@onready var _far_geom_slider: HSlider = $Panel/VBox/Body/FarGeomScaleRow/Slider
@onready var _far_geom_value: Label = $Panel/VBox/Body/FarGeomScaleRow/Value
@onready var _ref_depth_slider: HSlider = $Panel/VBox/Body/RefDepthRow/Slider
@onready var _ref_depth_value: Label = $Panel/VBox/Body/RefDepthRow/Value
@onready var _depth_grid_check: CheckButton = $Panel/VBox/Body/DepthGridRow/Check
@onready var _cell_check: CheckButton = $Panel/VBox/Body/CellHighlightRow/Check
@onready var _god_check: CheckButton = $Panel/VBox/Body/GodModeRow/Check

var _player: Node2D
var _level: Node2D
var _visual: Node2D
var _syncing_god := false
var _collapsed: bool = true


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return

	_player = get_node_or_null(player_path) as Node2D
	_level = get_node_or_null(ramp_level_path) as Node2D
	_visual = get_node_or_null(ramp_visual_path) as Node2D

	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(_on_toggle_pressed)

	_bind_float_slider(_gravity_slider, gravity_min, gravity_max, 0.1, _player, "gravity_ms2", -12.8, _on_gravity_changed, _refresh_gravity_label)
	_bind_float_slider(_acid_slider, acid_buffer_min, acid_buffer_max, 1.0, _player, "acid_drop_buffer", 44.0, _on_acid_buffer_changed, _refresh_acid_label)
	_bind_float_slider(_ollie_slider, ollie_accel_min, ollie_accel_max, 10.0, _player, "ollie_accel", 650.0, _on_ollie_accel_changed, _refresh_ollie_label)
	_bind_float_slider(_max_speed_x_slider, max_speed_x_min, max_speed_x_max, 10.0, _player, "max_speed_x", 880.0, _on_max_speed_x_changed, _refresh_max_speed_x_label)
	_bind_float_slider(_max_speed_z_slider, max_speed_z_min, max_speed_z_max, 5.0, _player, "max_speed_z", 335.0, _on_max_speed_z_changed, _refresh_max_speed_z_label)
	_bind_float_slider(_accel_slider, acceleration_min, acceleration_max, 50.0, _player, "acceleration", 3250.0, _on_accel_changed, _refresh_accel_label)
	_bind_float_slider(_brake_slider, brake_min, brake_max, 50.0, _player, "brake", 1250.0, _on_brake_changed, _refresh_brake_label)
	_bind_float_slider(_ramp_friction_slider, ramp_friction_min, ramp_friction_max, 10.0, _player, "ramp_friction", 0.0, _on_ramp_friction_changed, _refresh_ramp_friction_label)
	_bind_float_slider(_friction_slider, friction_min, friction_max, 10.0, _player, "friction", 0.0, _on_friction_changed, _refresh_friction_label)

	_bind_float_slider(_persp_inset_slider, persp_inset_min, persp_inset_max, 1.0, _level, "perspective_inset", 200.0, _on_persp_inset_changed, _refresh_persp_inset_label)
	_bind_float_slider(_far_geom_slider, far_geom_min, far_geom_max, 0.01, _level, "far_geometry_scale", 1.0, _on_far_geom_changed, _refresh_far_geom_label)
	_bind_float_slider(_ref_depth_slider, ref_depth_min, ref_depth_max, 5.0, _level, "reference_depth", 500.0, _on_ref_depth_changed, _refresh_ref_depth_label)

	var depth_on := false
	if _visual != null and _visual.get("show_depth_grid") != null:
		depth_on = bool(_visual.get("show_depth_grid"))
	_depth_grid_check.button_pressed = depth_on
	_depth_grid_check.focus_mode = Control.FOCUS_NONE
	_depth_grid_check.toggled.connect(_on_depth_grid_toggled)

	var cell_on := false
	if _visual != null and _visual.get("debug_cell_highlight") != null:
		cell_on = bool(_visual.get("debug_cell_highlight"))
	_cell_check.button_pressed = cell_on
	_cell_check.focus_mode = Control.FOCUS_NONE
	_cell_check.toggled.connect(_on_cell_highlight_toggled)

	_god_check.button_pressed = DebugTools.god_mode
	_god_check.focus_mode = Control.FOCUS_NONE
	_god_check.toggled.connect(_on_god_mode_toggled)
	DebugTools.god_mode_changed.connect(_on_god_mode_changed)

	# Sliders: mouse only — Space is ollie and must not steal focus.
	for row in [
		_gravity_slider, _acid_slider, _ollie_slider, _max_speed_x_slider,
		_max_speed_z_slider, _accel_slider, _brake_slider,
		_ramp_friction_slider, _friction_slider,
		_persp_inset_slider, _far_geom_slider, _ref_depth_slider,
	]:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE

	_set_collapsed(start_collapsed)


func _on_toggle_pressed() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(on: bool) -> void:
	_collapsed = on
	_body.visible = not on
	_toggle.text = "▶" if on else "▼"
	call_deferred("_fit_panel")


func _fit_panel() -> void:
	if _panel == null:
		return
	var min_sz := _panel.get_combined_minimum_size()
	_panel.size = Vector2(maxf(min_sz.x, 280.0), min_sz.y)


func _bind_float_slider(
	slider: HSlider,
	min_v: float,
	max_v: float,
	step: float,
	target: Object,
	prop: String,
	fallback: float,
	on_changed: Callable,
	refresh: Callable,
) -> void:
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	var v := fallback
	if target != null and target.get(prop) != null:
		v = float(target.get(prop))
	slider.value = v
	slider.value_changed.connect(on_changed)
	refresh.call(v)


func _on_gravity_changed(v: float) -> void:
	if _player != null:
		_player.set("gravity_ms2", v)
	_refresh_gravity_label(v)


func _refresh_gravity_label(v: float) -> void:
	_gravity_value.text = "%.1f m/s²" % v


func _on_acid_buffer_changed(v: float) -> void:
	if _player != null:
		_player.set("acid_drop_buffer", v)
	_refresh_acid_label(v)


func _refresh_acid_label(v: float) -> void:
	_acid_value.text = "%.0f u" % v


func _on_ollie_accel_changed(v: float) -> void:
	if _player != null:
		_player.set("ollie_accel", v)
	_refresh_ollie_label(v)


func _refresh_ollie_label(v: float) -> void:
	_ollie_value.text = "%.0f" % v


func _on_max_speed_x_changed(v: float) -> void:
	if _player != null:
		_player.set("max_speed_x", v)
	_refresh_max_speed_x_label(v)


func _refresh_max_speed_x_label(v: float) -> void:
	_max_speed_x_value.text = "%.0f" % v


func _on_max_speed_z_changed(v: float) -> void:
	if _player != null:
		_player.set("max_speed_z", v)
	_refresh_max_speed_z_label(v)


func _refresh_max_speed_z_label(v: float) -> void:
	_max_speed_z_value.text = "%.0f" % v


func _on_accel_changed(v: float) -> void:
	if _player != null:
		_player.set("acceleration", v)
	_refresh_accel_label(v)


func _refresh_accel_label(v: float) -> void:
	_accel_value.text = "%.0f" % v


func _on_brake_changed(v: float) -> void:
	if _player != null:
		_player.set("brake", v)
	_refresh_brake_label(v)


func _refresh_brake_label(v: float) -> void:
	_brake_value.text = "%.0f" % v


func _on_ramp_friction_changed(v: float) -> void:
	if _player != null:
		_player.set("ramp_friction", v)
	_refresh_ramp_friction_label(v)


func _refresh_ramp_friction_label(v: float) -> void:
	_ramp_friction_value.text = "%.0f" % v


func _on_friction_changed(v: float) -> void:
	if _player != null:
		_player.set("friction", v)
	_refresh_friction_label(v)


func _refresh_friction_label(v: float) -> void:
	_friction_value.text = "%.0f" % v


func _refresh_level_visual() -> void:
	if _visual != null:
		if _visual.has_method("refresh"):
			_visual.call("refresh")
		else:
			_visual.queue_redraw()
	if _player != null and _player.has_node("PseudoDepthBody"):
		var depth: Node = _player.get_node("PseudoDepthBody")
		if depth.has_method("apply"):
			depth.call("apply")


func _on_persp_inset_changed(v: float) -> void:
	if _level != null:
		_level.set("perspective_inset", v)
	_refresh_persp_inset_label(v)
	_refresh_level_visual()


func _refresh_persp_inset_label(v: float) -> void:
	_persp_inset_value.text = "%.0f" % v


func _on_far_geom_changed(v: float) -> void:
	if _level != null:
		_level.set("far_geometry_scale", v)
	_refresh_far_geom_label(v)
	_refresh_level_visual()


func _refresh_far_geom_label(v: float) -> void:
	_far_geom_value.text = "%.2f" % v


func _on_ref_depth_changed(v: float) -> void:
	if _level != null:
		_level.set("reference_depth", v)
	_refresh_ref_depth_label(v)
	_refresh_level_visual()


func _refresh_ref_depth_label(v: float) -> void:
	_ref_depth_value.text = "%.0f" % v


func _on_depth_grid_toggled(on: bool) -> void:
	if _visual != null:
		_visual.set("show_depth_grid", on)
		if _visual.has_method("refresh"):
			_visual.call("refresh")
		else:
			_visual.queue_redraw()


func _on_cell_highlight_toggled(on: bool) -> void:
	if _visual != null:
		_visual.set("debug_cell_highlight", on)
		if _visual.has_method("refresh"):
			_visual.call("refresh")
		else:
			_visual.queue_redraw()


func _on_god_mode_toggled(on: bool) -> void:
	if _syncing_god:
		return
	DebugTools.set_god_mode(on)


func _on_god_mode_changed(on: bool) -> void:
	_syncing_god = true
	_god_check.button_pressed = on
	_syncing_god = false
