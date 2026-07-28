extends CanvasLayer
## Top-right debug sliders. UI-only; simulation reads values on physics ticks.
## Collapsible body starts collapsed. Stripped in production via DebugTools.

@export var player_path: NodePath = NodePath("../Player")
@export var ramp_level_path: NodePath = NodePath("../RampLevel")
@export var ramp_visual_path: NodePath = NodePath("../RampLevel/RampVisual")
@export var start_collapsed: bool = true
## Max height of the expanded slider list before vertical scroll (viewport-clamped).
@export var body_max_height: float = 640.0
@export var body_bottom_margin: float = 24.0
@export var gravity_min: float = -30.0
@export var gravity_max: float = 0.0
@export var acid_buffer_min: float = 0.0
@export var acid_buffer_max: float = 80.0
@export var fly_out_above_min: float = 0.0
@export var fly_out_above_max: float = 300.0
@export var ollie_accel_min: float = 0.0
@export var ollie_accel_max: float = 3000.0
@export var max_speed_x_min: float = 50.0
@export var max_speed_x_max: float = 2000.0
@export var max_speed_z_min: float = 10.0
@export var max_speed_z_max: float = 800.0
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
@export var far_geom_max: float = 3.0
@export var ref_depth_min: float = 20.0
@export var ref_depth_max: float = 500.0
@export var draw_band_pad_min: float = 0.0
@export var draw_band_pad_max: float = 4.0
@export var arc_steps_min: float = 4.0
@export var arc_steps_max: float = 32.0
@export var cast_cells_min: float = 1.0
@export var cast_cells_max: float = 16.0
@export var coping_cells_min: float = 1.0
@export var coping_cells_max: float = 16.0
@export var cell_x_min: float = 10.0
@export var cell_x_max: float = 120.0
@export var cell_z_min: float = 10.0
@export var cell_z_max: float = 200.0

@onready var _panel: PanelContainer = $Panel
@onready var _header: Control = $Panel/VBox/Header
@onready var _title: Label = $Panel/VBox/Header/Title
@onready var _body: VBoxContainer = $Panel/VBox/Body
@onready var _toggle: Button = $Panel/VBox/Header/Toggle
@onready var _gravity_slider: HSlider = $Panel/VBox/Body/GravityRow/Slider
@onready var _gravity_value: Label = $Panel/VBox/Body/GravityRow/Value
@onready var _acid_slider: HSlider = $Panel/VBox/Body/AcidDropRow/Slider
@onready var _acid_value: Label = $Panel/VBox/Body/AcidDropRow/Value
@onready var _fly_out_slider: HSlider = $Panel/VBox/Body/FlyOutRow/Slider
@onready var _fly_out_value: Label = $Panel/VBox/Body/FlyOutRow/Value
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
@onready var _draw_band_pad_slider: HSlider = $Panel/VBox/Body/DrawBandPadRow/Slider
@onready var _draw_band_pad_value: Label = $Panel/VBox/Body/DrawBandPadRow/Value
@onready var _arc_steps_slider: HSlider = $Panel/VBox/Body/ArcStepsRow/Slider
@onready var _arc_steps_value: Label = $Panel/VBox/Body/ArcStepsRow/Value
@onready var _cell_x_slider: HSlider = $Panel/VBox/Body/CellXRow/Slider
@onready var _cell_x_value: Label = $Panel/VBox/Body/CellXRow/Value
@onready var _cell_z_slider: HSlider = $Panel/VBox/Body/CellZRow/Slider
@onready var _cell_z_value: Label = $Panel/VBox/Body/CellZRow/Value
@onready var _depth_grid_check: CheckButton = $Panel/VBox/Body/DepthGridRow/Check
@onready var _cell_check: CheckButton = $Panel/VBox/Body/CellHighlightRow/Check
@onready var _facing_cast_check: CheckButton = $Panel/VBox/Body/FacingCastRow/Check
@onready var _motion_vectors_check: CheckButton = $Panel/VBox/Body/MotionVectorsRow/Check
@onready var _head_debug_check: CheckButton = $Panel/VBox/Body/HeadDebugRow/Check
@onready var _fps_check: CheckButton = $Panel/VBox/Body/FpsRow/Check
@onready var _vsync_check: CheckButton = $Panel/VBox/Body/VsyncRow/Check
@onready var _cast_cells_slider: HSlider = $Panel/VBox/Body/CastCellsRow/Slider
@onready var _cast_cells_value: Label = $Panel/VBox/Body/CastCellsRow/Value
@onready var _coping_cells_slider: HSlider = $Panel/VBox/Body/CopingCellsRow/Slider
@onready var _coping_cells_value: Label = $Panel/VBox/Body/CopingCellsRow/Value
@onready var _god_check: CheckButton = $Panel/VBox/Body/GodModeRow/Check

var _player: Node2D
var _level: Node2D
var _visual: Node2D
var _syncing_god := false
var _collapsed: bool = true
var _scroll: ScrollContainer


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return

	_player = get_node_or_null(player_path) as Node2D
	_level = get_node_or_null(ramp_level_path) as Node2D
	_visual = get_node_or_null(ramp_visual_path) as Node2D

	_wrap_body_in_scroll()
	get_viewport().size_changed.connect(_refit_panel_layout)
	_wire_header_toggle()

	_bind_float_slider(_gravity_slider, gravity_min, gravity_max, 0.1, _player, "gravity_ms2", -19.0, _on_gravity_changed, _refresh_gravity_label)
	_bind_float_slider(_acid_slider, acid_buffer_min, acid_buffer_max, 1.0, _player, "acid_drop_buffer", 44.0, _on_acid_buffer_changed, _refresh_acid_label)
	_bind_float_slider(
		_fly_out_slider,
		fly_out_above_min,
		fly_out_above_max,
		1.0,
		_player,
		"fly_out_above_coping",
		40.0,
		_on_fly_out_changed,
		_refresh_fly_out_label
	)
	_bind_float_slider(_ollie_slider, ollie_accel_min, ollie_accel_max, 10.0, _player, "ollie_accel", 650.0, _on_ollie_accel_changed, _refresh_ollie_label)
	_bind_float_slider(_max_speed_x_slider, max_speed_x_min, max_speed_x_max, 10.0, _player, "max_speed_x", 880.0, _on_max_speed_x_changed, _refresh_max_speed_x_label)
	_bind_float_slider(_max_speed_z_slider, max_speed_z_min, max_speed_z_max, 5.0, _player, "max_speed_z", 400.0, _on_max_speed_z_changed, _refresh_max_speed_z_label)
	_bind_float_slider(_accel_slider, acceleration_min, acceleration_max, 50.0, _player, "acceleration", 3250.0, _on_accel_changed, _refresh_accel_label)
	_bind_float_slider(_brake_slider, brake_min, brake_max, 50.0, _player, "brake", 1250.0, _on_brake_changed, _refresh_brake_label)
	_bind_float_slider(_ramp_friction_slider, ramp_friction_min, ramp_friction_max, 10.0, _player, "ramp_friction", 0.0, _on_ramp_friction_changed, _refresh_ramp_friction_label)
	_bind_float_slider(_friction_slider, friction_min, friction_max, 10.0, _player, "friction", 0.0, _on_friction_changed, _refresh_friction_label)

	_bind_float_slider(_persp_inset_slider, persp_inset_min, persp_inset_max, 1.0, _level, "perspective_inset", 155.0, _on_persp_inset_changed, _refresh_persp_inset_label)
	_bind_float_slider(_far_geom_slider, far_geom_min, far_geom_max, 0.01, _level, "far_geometry_scale", 1.0, _on_far_geom_changed, _refresh_far_geom_label)
	_bind_float_slider(_ref_depth_slider, ref_depth_min, ref_depth_max, 5.0, _level, "reference_depth", 500.0, _on_ref_depth_changed, _refresh_ref_depth_label)
	_bind_float_slider(
		_draw_band_pad_slider,
		draw_band_pad_min,
		draw_band_pad_max,
		0.05,
		_visual,
		"draw_band_pad",
		2.0,
		_on_draw_band_pad_changed,
		_refresh_draw_band_pad_label
	)
	_bind_float_slider(
		_arc_steps_slider,
		arc_steps_min,
		arc_steps_max,
		1.0,
		_visual,
		"arc_steps",
		8.0,
		_on_arc_steps_changed,
		_refresh_arc_steps_label
	)
	_bind_float_slider(_cell_x_slider, cell_x_min, cell_x_max, 1.0, _level, "cell_size_x", 47.0, _on_cell_x_changed, _refresh_cell_x_label)
	_bind_float_slider(_cell_z_slider, cell_z_min, cell_z_max, 1.0, _level, "cell_size_z", 47.0, _on_cell_z_changed, _refresh_cell_z_label)

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

	var facing_on := false
	if _visual != null and _visual.get("debug_facing_cast") != null:
		facing_on = bool(_visual.get("debug_facing_cast"))
	_facing_cast_check.button_pressed = facing_on
	_facing_cast_check.focus_mode = Control.FOCUS_NONE
	_facing_cast_check.toggled.connect(_on_facing_cast_toggled)

	_motion_vectors_check.button_pressed = DebugTools.show_motion_vectors
	_motion_vectors_check.focus_mode = Control.FOCUS_NONE
	_motion_vectors_check.toggled.connect(_on_motion_vectors_toggled)

	_head_debug_check.button_pressed = DebugTools.show_head_debug
	_head_debug_check.focus_mode = Control.FOCUS_NONE
	_head_debug_check.toggled.connect(_on_head_debug_toggled)

	_fps_check.button_pressed = DebugTools.show_fps
	_fps_check.focus_mode = Control.FOCUS_NONE
	_fps_check.toggled.connect(_on_fps_toggled)

	_vsync_check.button_pressed = DebugTools.vsync_enabled
	_vsync_check.focus_mode = Control.FOCUS_NONE
	_vsync_check.toggled.connect(_on_vsync_toggled)

	_bind_float_slider(
		_cast_cells_slider,
		cast_cells_min,
		cast_cells_max,
		1.0,
		_visual,
		"facing_cast_distance",
		3.0,
		_on_cast_cells_changed,
		_refresh_cast_cells_label
	)

	_bind_float_slider(
		_coping_cells_slider,
		coping_cells_min,
		coping_cells_max,
		1.0,
		_player,
		"facing_coping_cells",
		3.0,
		_on_coping_cells_changed,
		_refresh_coping_cells_label
	)

	_god_check.button_pressed = DebugTools.god_mode
	_god_check.focus_mode = Control.FOCUS_NONE
	_god_check.toggled.connect(_on_god_mode_toggled)
	DebugTools.god_mode_changed.connect(_on_god_mode_changed)

	# Sliders: mouse only — Space is ollie and must not steal focus.
	for row in [
		_gravity_slider, _acid_slider, _fly_out_slider, _ollie_slider, _max_speed_x_slider,
		_max_speed_z_slider, _accel_slider, _brake_slider,
		_ramp_friction_slider, _friction_slider,
		_persp_inset_slider, _far_geom_slider, _ref_depth_slider,
		_draw_band_pad_slider, _arc_steps_slider, _cast_cells_slider,
		_coping_cells_slider, _cell_x_slider, _cell_z_slider,
	]:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE

	_set_collapsed(start_collapsed)


func _wire_header_toggle() -> void:
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header.gui_input.connect(_on_header_gui_input)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_toggle.pressed.connect(_on_toggle_pressed)


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_toggle_pressed()
		_header.accept_event()


func _on_toggle_pressed() -> void:
	_set_collapsed(not _collapsed)


func _set_collapsed(on: bool) -> void:
	_collapsed = on
	if _scroll:
		_scroll.visible = not on
		_body.visible = true
		if on:
			# Expand sets an explicit scroll min-height + panel.size; clear both on collapse.
			_scroll.custom_minimum_size = Vector2.ZERO
			_scroll.size = Vector2.ZERO
	else:
		_body.visible = not on
	_toggle.text = "▶" if on else "▼"
	# Panel.size is set explicitly while open and does not auto-shrink when body hides.
	call_deferred("_refit_panel_layout")


func _refit_panel_layout() -> void:
	_fit_scroll_height()
	# Wait a frame so container min-sizes reflect scroll visibility / height.
	call_deferred("_fit_panel")


func _wrap_body_in_scroll() -> void:
	if _body == null or _body.get_parent() is ScrollContainer:
		return
	var parent := _body.get_parent()
	var idx := _body.get_index()
	var was_visible := _body.visible
	parent.remove_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.visible = was_visible
	parent.add_child(_scroll)
	parent.move_child(_scroll, idx)
	_body.visible = true
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)


func _fit_scroll_height() -> void:
	if _scroll == null:
		return
	if _collapsed:
		_scroll.custom_minimum_size = Vector2.ZERO
		_scroll.size = Vector2.ZERO
		return
	var vp_h := get_viewport().get_visible_rect().size.y
	var panel_top := _panel.offset_top if _panel else 16.0
	var header_h := _header.get_combined_minimum_size().y if _header else 28.0
	var sep := 8.0
	var max_h := minf(
		body_max_height,
		maxf(120.0, vp_h - panel_top - header_h - sep - body_bottom_margin)
	)
	var content_h := _body.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(0.0, minf(content_h, max_h))


func _fit_panel() -> void:
	if _panel == null:
		return
	var min_sz := _panel.get_combined_minimum_size()
	if _collapsed and _header != null and min_sz.y > _header.get_combined_minimum_size().y + 32.0:
		# Fallback if a hidden scroll still contributes to min size.
		min_sz.y = _header.get_combined_minimum_size().y + 16.0
	_panel.custom_minimum_size = Vector2(maxf(min_sz.x, 280.0), 0.0)
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


func _on_fly_out_changed(v: float) -> void:
	if _player != null:
		_player.set("fly_out_above_coping", v)
	_refresh_fly_out_label(v)


func _refresh_fly_out_label(v: float) -> void:
	_fly_out_value.text = "≤%.0f u" % v


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
		if _level.has_method("sync_lean_origin_z"):
			_level.call("sync_lean_origin_z")
	_refresh_ref_depth_label(v)
	_refresh_level_visual()


func _refresh_ref_depth_label(v: float) -> void:
	_ref_depth_value.text = "%.0f" % v


func _on_draw_band_pad_changed(v: float) -> void:
	if _visual != null:
		_visual.set("draw_band_pad", v)
	_refresh_draw_band_pad_label(v)
	_refresh_level_visual()


func _refresh_draw_band_pad_label(v: float) -> void:
	_draw_band_pad_value.text = "%.2f" % v


func _on_arc_steps_changed(v: float) -> void:
	if _visual != null:
		_visual.set("arc_steps", int(round(v)))
	_refresh_arc_steps_label(v)
	_refresh_level_visual()


func _refresh_arc_steps_label(v: float) -> void:
	_arc_steps_value.text = "%d" % int(round(v))


func _on_cell_x_changed(v: float) -> void:
	if _level != null:
		_level.set("cell_size_x", v)
		LevelLoader.cell_size_x = v
		if _level.has_method("sync_reference_depth_to_glyphs"):
			_level.call("sync_reference_depth_to_glyphs")
			if _ref_depth_slider != null:
				_ref_depth_slider.value = float(_level.get("reference_depth"))
		if _level.has_method("reload"):
			_level.call("reload")
	_refresh_cell_x_label(v)


func _refresh_cell_x_label(v: float) -> void:
	_cell_x_value.text = "%.0f" % v


func _on_cell_z_changed(v: float) -> void:
	if _level != null:
		_level.set("cell_size_z", v)
		LevelLoader.cell_size_z = v
		if _level.has_method("sync_reference_depth_to_glyphs"):
			_level.call("sync_reference_depth_to_glyphs")
			if _ref_depth_slider != null:
				_ref_depth_slider.value = float(_level.get("reference_depth"))
		if _level.has_method("reload"):
			_level.call("reload")
	_refresh_cell_z_label(v)


func _refresh_cell_z_label(v: float) -> void:
	_cell_z_value.text = "%.0f" % v


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


func _on_facing_cast_toggled(on: bool) -> void:
	if _visual != null:
		_visual.set("debug_facing_cast", on)
		if _visual.has_method("refresh"):
			_visual.call("refresh")
		else:
			_visual.queue_redraw()


func _on_motion_vectors_toggled(on: bool) -> void:
	DebugTools.set_show_motion_vectors(on)


func _on_head_debug_toggled(on: bool) -> void:
	DebugTools.set_show_head_debug(on)


func _on_fps_toggled(on: bool) -> void:
	DebugTools.set_show_fps(on)


func _on_vsync_toggled(on: bool) -> void:
	DebugTools.set_vsync_enabled(on)


func _on_cast_cells_changed(v: float) -> void:
	if _visual != null:
		_visual.set("facing_cast_distance", int(round(v)))
		if _visual.has_method("refresh"):
			_visual.call("refresh")
		else:
			_visual.queue_redraw()
	_refresh_cast_cells_label(v)


func _refresh_cast_cells_label(v: float) -> void:
	_cast_cells_value.text = "%d" % int(round(v))


func _on_coping_cells_changed(v: float) -> void:
	if _player != null:
		_player.set("facing_coping_cells", int(round(v)))
	_refresh_coping_cells_label(v)


func _refresh_coping_cells_label(v: float) -> void:
	_coping_cells_value.text = "%d" % int(round(v))


func _on_god_mode_toggled(on: bool) -> void:
	if _syncing_god:
		return
	DebugTools.set_god_mode(on)


func _on_god_mode_changed(on: bool) -> void:
	_syncing_god = true
	_god_check.button_pressed = on
	_syncing_god = false
