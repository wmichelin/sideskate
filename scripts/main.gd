extends Control

@onready var status_label: Label = %Status
@onready var counter_label: Label = %Counter

var _presses: int = 0


func _ready() -> void:
	status_label.text = "Press SPACE to playtest"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_presses += 1
			counter_label.text = str(_presses)
			status_label.text = "Agent playtest OK — space pressed %d×" % _presses
			get_viewport().set_input_as_handled()
