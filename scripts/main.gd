extends Node
## Shared Escape → menu handler for 2D and 3D gameplay roots.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		GameSession.return_to_menu()
		get_viewport().set_input_as_handled()
