extends CanvasLayer
## Top-right debug sliders. UI-only; simulation reads values on physics ticks.

@export var player_path: NodePath = NodePath("../Player")
@export var gravity_min: float = -30.0
@export var gravity_max: float = 0.0
@export var acid_buffer_min: float = 0.0
@export var acid_buffer_max: float = 80.0

@onready var _gravity_slider: HSlider = $Panel/VBox/GravityRow/Slider
@onready var _gravity_value: Label = $Panel/VBox/GravityRow/Value
@onready var _acid_slider: HSlider = $Panel/VBox/AcidDropRow/Slider
@onready var _acid_value: Label = $Panel/VBox/AcidDropRow/Value

var _player: Node2D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D

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
	var buf := 10.0
	if _player != null and _player.get("acid_drop_buffer") != null:
		buf = float(_player.get("acid_drop_buffer"))
	_acid_slider.value = buf
	_acid_slider.value_changed.connect(_on_acid_buffer_changed)
	_refresh_acid_label(buf)


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
