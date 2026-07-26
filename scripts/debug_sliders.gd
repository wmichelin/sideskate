extends CanvasLayer
## Top-right debug sliders. UI-only; simulation reads values on physics ticks.

@export var player_path: NodePath = NodePath("../Player")
@export var gravity_min: float = -30.0
@export var gravity_max: float = 0.0

@onready var _gravity_slider: HSlider = $Panel/VBox/GravityRow/Slider
@onready var _gravity_value: Label = $Panel/VBox/GravityRow/Value

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


func _on_gravity_changed(v: float) -> void:
	if _player != null:
		_player.set("gravity_ms2", v)
	_refresh_gravity_label(v)


func _refresh_gravity_label(v: float) -> void:
	_gravity_value.text = "%.1f m/s²" % v
