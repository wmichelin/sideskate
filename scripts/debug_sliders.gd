extends CanvasLayer
## Top-right debug sliders. UI-only; simulation reads values on physics ticks.
## Stripped in production via DebugTools / group `debug_tools`.

@export var player_path: NodePath = NodePath("../Player")
@export var ramp_visual_path: NodePath = NodePath("../RampLevel/RampVisual")
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

@onready var _gravity_slider: HSlider = $Panel/VBox/GravityRow/Slider
@onready var _gravity_value: Label = $Panel/VBox/GravityRow/Value
@onready var _acid_slider: HSlider = $Panel/VBox/AcidDropRow/Slider
@onready var _acid_value: Label = $Panel/VBox/AcidDropRow/Value
@onready var _ollie_slider: HSlider = $Panel/VBox/OllieAccelRow/Slider
@onready var _ollie_value: Label = $Panel/VBox/OllieAccelRow/Value
@onready var _max_speed_x_slider: HSlider = $Panel/VBox/MaxSpeedXRow/Slider
@onready var _max_speed_x_value: Label = $Panel/VBox/MaxSpeedXRow/Value
@onready var _max_speed_z_slider: HSlider = $Panel/VBox/MaxSpeedZRow/Slider
@onready var _max_speed_z_value: Label = $Panel/VBox/MaxSpeedZRow/Value
@onready var _accel_slider: HSlider = $Panel/VBox/AccelRow/Slider
@onready var _accel_value: Label = $Panel/VBox/AccelRow/Value
@onready var _brake_slider: HSlider = $Panel/VBox/BrakeRow/Slider
@onready var _brake_value: Label = $Panel/VBox/BrakeRow/Value
@onready var _ramp_friction_slider: HSlider = $Panel/VBox/RampFrictionRow/Slider
@onready var _ramp_friction_value: Label = $Panel/VBox/RampFrictionRow/Value
@onready var _friction_slider: HSlider = $Panel/VBox/FrictionRow/Slider
@onready var _friction_value: Label = $Panel/VBox/FrictionRow/Value
@onready var _cell_check: CheckButton = $Panel/VBox/CellHighlightRow/Check
@onready var _god_check: CheckButton = $Panel/VBox/GodModeRow/Check

var _player: Node2D
var _visual: Node2D
var _syncing_god := false


func _ready() -> void:
	add_to_group("debug_tools")
	if not DebugTools.is_available():
		queue_free()
		return

	_player = get_node_or_null(player_path) as Node2D
	_visual = get_node_or_null(ramp_visual_path) as Node2D

	_bind_float_slider(_gravity_slider, gravity_min, gravity_max, 0.1, "gravity_ms2", -9.8, _on_gravity_changed, _refresh_gravity_label)
	_bind_float_slider(_acid_slider, acid_buffer_min, acid_buffer_max, 1.0, "acid_drop_buffer", 44.0, _on_acid_buffer_changed, _refresh_acid_label)
	_bind_float_slider(_ollie_slider, ollie_accel_min, ollie_accel_max, 10.0, "ollie_accel", 830.0, _on_ollie_accel_changed, _refresh_ollie_label)
	_bind_float_slider(_max_speed_x_slider, max_speed_x_min, max_speed_x_max, 10.0, "max_speed_x", 900.0, _on_max_speed_x_changed, _refresh_max_speed_x_label)
	_bind_float_slider(_max_speed_z_slider, max_speed_z_min, max_speed_z_max, 5.0, "max_speed_z", 60.0, _on_max_speed_z_changed, _refresh_max_speed_z_label)
	_bind_float_slider(_accel_slider, acceleration_min, acceleration_max, 50.0, "acceleration", 2200.0, _on_accel_changed, _refresh_accel_label)
	_bind_float_slider(_brake_slider, brake_min, brake_max, 50.0, "brake", 5500.0, _on_brake_changed, _refresh_brake_label)
	_bind_float_slider(_ramp_friction_slider, ramp_friction_min, ramp_friction_max, 10.0, "ramp_friction", 160.0, _on_ramp_friction_changed, _refresh_ramp_friction_label)
	_bind_float_slider(_friction_slider, friction_min, friction_max, 10.0, "friction", 0.0, _on_friction_changed, _refresh_friction_label)

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
	]:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE


func _bind_float_slider(
	slider: HSlider,
	min_v: float,
	max_v: float,
	step: float,
	prop: String,
	fallback: float,
	on_changed: Callable,
	refresh: Callable,
) -> void:
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	var v := fallback
	if _player != null and _player.get(prop) != null:
		v = float(_player.get(prop))
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
