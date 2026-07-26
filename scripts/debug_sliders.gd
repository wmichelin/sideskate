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

	_gravity_slider.min_value = gravity_min
	_gravity_slider.max_value = gravity_max
	_gravity_slider.step = 0.1
	var g := -9.8
	if _player != null and _player.get("gravity_ms2") != null:
		g = float(_player.get("gravity_ms2"))
	_gravity_slider.value = g
	_gravity_slider.value_changed.connect(_on_gravity_changed)
	_refresh_gravity_label(g)

	_acid_slider.min_value = acid_buffer_min
	_acid_slider.max_value = acid_buffer_max
	_acid_slider.step = 1.0
	var buf := 44.0
	if _player != null and _player.get("acid_drop_buffer") != null:
		buf = float(_player.get("acid_drop_buffer"))
	_acid_slider.value = buf
	_acid_slider.value_changed.connect(_on_acid_buffer_changed)
	_refresh_acid_label(buf)

	_ollie_slider.min_value = ollie_accel_min
	_ollie_slider.max_value = ollie_accel_max
	_ollie_slider.step = 10.0
	var oa := 830.0
	if _player != null and _player.get("ollie_accel") != null:
		oa = float(_player.get("ollie_accel"))
	_ollie_slider.value = oa
	_ollie_slider.value_changed.connect(_on_ollie_accel_changed)
	_refresh_ollie_label(oa)

	_max_speed_x_slider.min_value = max_speed_x_min
	_max_speed_x_slider.max_value = max_speed_x_max
	_max_speed_x_slider.step = 10.0
	var msx := 900.0
	if _player != null and _player.get("max_speed_x") != null:
		msx = float(_player.get("max_speed_x"))
	_max_speed_x_slider.value = msx
	_max_speed_x_slider.value_changed.connect(_on_max_speed_x_changed)
	_refresh_max_speed_x_label(msx)

	_ramp_friction_slider.min_value = ramp_friction_min
	_ramp_friction_slider.max_value = ramp_friction_max
	_ramp_friction_slider.step = 10.0
	var rf := 160.0
	if _player != null and _player.get("ramp_friction") != null:
		rf = float(_player.get("ramp_friction"))
	_ramp_friction_slider.value = rf
	_ramp_friction_slider.value_changed.connect(_on_ramp_friction_changed)
	_refresh_ramp_friction_label(rf)

	_friction_slider.min_value = friction_min
	_friction_slider.max_value = friction_max
	_friction_slider.step = 10.0
	var fr := 0.0
	if _player != null and _player.get("friction") != null:
		fr = float(_player.get("friction"))
	_friction_slider.value = fr
	_friction_slider.value_changed.connect(_on_friction_changed)
	_refresh_friction_label(fr)

	var cell_on := true
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
		_ramp_friction_slider, _friction_slider,
	]:
		if row != null:
			row.focus_mode = Control.FOCUS_NONE


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
