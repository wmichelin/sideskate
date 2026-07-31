extends Node
## Gameplay root: environment setup + Escape → menu.


func _ready() -> void:
	_setup_environment()
	var vis3d := get_node_or_null("World3D/LevelVisual3D")
	if vis3d != null and vis3d.has_method("rebuild"):
		vis3d.call_deferred("rebuild")
	var col3d := get_node_or_null("World3D/LevelCollision3D")
	if col3d != null and col3d.has_method("rebuild"):
		col3d.call_deferred("rebuild")


func _setup_environment() -> void:
	var we := get_node_or_null("World3D/WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	if we.environment == null:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.08, 0.1, 0.14, 1)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.35, 0.38, 0.42)
		env.ambient_light_energy = 0.55
		we.environment = env
	# Shadows over a 100m park farm the GPU; fill lights stay on.
	var key := get_node_or_null("World3D/KeyLight") as DirectionalLight3D
	if key != null:
		key.shadow_enabled = false
		key.directional_shadow_max_distance = 28.0
		key.shadow_blur = 0.8


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		GameSession.return_to_menu()
		get_viewport().set_input_as_handled()
