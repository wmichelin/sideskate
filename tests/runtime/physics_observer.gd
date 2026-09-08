extends Node
## Runs after Player so each awaited tick observes the completed gameplay step.
signal stepped


func _physics_process(_delta: float) -> void:
	get_parent().observe_completed_tick()
	stepped.emit()
	get_parent().flush_pending_input()
