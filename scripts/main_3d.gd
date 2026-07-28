extends Node
## 3D gameplay root: shared Escape handler + hide 2D canvas park draw.


func _ready() -> void:
	_setup_environment()
	# Hide 2D park draw + camera; keep RampLevel + Player sim alive.
	var visual := get_node_or_null("RampLevel/RampVisual")
	if visual is CanvasItem:
		(visual as CanvasItem).visible = false
		visual.set_process(false)
	var cam2d := get_node_or_null("FollowCamera")
	if cam2d:
		cam2d.set_physics_process(false)
		if cam2d is Camera2D:
			(cam2d as Camera2D).enabled = false
	var backdrop := get_node_or_null("WorldBackdrop")
	if backdrop:
		backdrop.visible = false
	var body := get_node_or_null("Player/Body")
	if body is CanvasItem:
		(body as CanvasItem).visible = false
	var shadow := get_node_or_null("Player/Shadow")
	if shadow is CanvasItem:
		(shadow as CanvasItem).visible = false
	var vis3d := get_node_or_null("World3D/LevelVisual3D")
	if vis3d != null and vis3d.has_method("rebuild"):
		vis3d.call_deferred("rebuild")


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
		GameSession.return_to_menu()
		get_viewport().set_input_as_handled()
