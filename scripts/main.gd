extends Node2D
## Gameplay root helpers (return to menu).


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameSession.return_to_menu()
		get_viewport().set_input_as_handled()
