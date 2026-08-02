extends Node
## Gameplay root: environment setup + Escape → pause menu.


@onready var _pause_menu: CanvasLayer = $PauseMenu


func _ready() -> void:
	_setup_environment()
	var vis3d := get_node_or_null("World3D/LevelVisual3D")
	if vis3d != null and vis3d.has_method("rebuild"):
		vis3d.call_deferred("rebuild")
	var col3d := get_node_or_null("World3D/LevelCollision3D")
	if col3d != null and col3d.has_method("rebuild"):
		col3d.call_deferred("rebuild")
	if _pause_menu != null:
		_pause_menu.quit_to_menu.connect(_on_quit_to_menu)


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
	# Keep soft key shadows — deck wood vs floor blue-grey needs the contrast.
	# Cap distance so spine_demo's 100m farm does not cascade the whole park.
	var key := get_node_or_null("World3D/KeyLight") as DirectionalLight3D
	if key != null:
		key.shadow_enabled = true
		key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		key.directional_shadow_max_distance = 28.0
		key.shadow_blur = 0.8


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		if _pause_menu != null and _pause_menu.has_method("toggle_pause"):
			_pause_menu.toggle_pause()
			get_viewport().set_input_as_handled()


func _on_quit_to_menu() -> void:
	GameSession.return_to_menu()
