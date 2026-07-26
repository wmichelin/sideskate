class_name RampLevel
extends Node2D
## Level runtime: loads .ssk, samples floor/deck/pipes, projects to screen.

@export var level_path: String = "res://levels/plaza_default.ssk"

@export_group("World scale")
## Logical units per ASCII column. Level width = columns × this.
@export var cell_size_x: float = 47.0
## Logical units per ASCII row. Level depth = rows × this.
@export var cell_size_z: float = 26.0

@export_group("Perspective")
## Screen Y of the near edge (z_min). Larger Y = lower on screen.
@export var near_screen_y: float = 560.0
## Screen Y at `reference_depth` units past z_min (not at z_max). Deep levels
## keep the same px/Z so they extend off-frame instead of compressing.
@export var far_screen_y: float = 300.0
## Logical depth span that maps near_screen_y → far_screen_y.
@export var reference_depth: float = 485.0
## Logical width used only for X convergence math — not the level's real span.
@export var reference_width: float = 1280.0
## X convergence toward the skater. 0 = side-on truck (parallel edges, camera
## slides in Z). Higher values tilt into a looking-down vanishing point.
@export var perspective_inset: float = 70.0
@export var far_geometry_scale: float = 1.0

signal rebuilt

var spec: LevelSpec
var pipes: Array = []  # QuarterPipe nodes

var z_min: float = 0.0
var z_max: float = 100.0
var lip_left: float = 180.0
var lip_right: float = 1100.0
var pipe_radius: float = 150.0
## Far X converges toward the skater so adjacent pipes share lean.
var perspective_origin_x: float = 640.0
## Lean band is centered on the skater so short and deep parks match on-screen.
var perspective_origin_z: float = 0.0
var _loaded_path: String = ""

@onready var _visual: Node2D = $RampVisual


func _ready() -> void:
	var path := level_path
	if GameSession.pending_level_path != "":
		path = GameSession.pending_level_path
	if path != "":
		load_level(path)


func load_level(path: String) -> bool:
	_loaded_path = path
	level_path = path
	LevelLoader.cell_size_x = cell_size_x
	LevelLoader.cell_size_z = cell_size_z
	var loaded: LevelSpec = LevelLoader.load_path(path, cell_size_x, cell_size_z)
	# load_path aborts the process on malformed files; null is only possible if quit is deferred.
	if loaded == null:
		return false
	apply_spec(loaded)
	rebuilt.emit()
	return true


## Re-parse the current .ssk with the active cell sizes (debug tuning).
func reload() -> bool:
	var path := _loaded_path if _loaded_path != "" else level_path
	if path == "":
		return false
	return load_level(path)


func apply_spec(s: LevelSpec) -> void:
	spec = s
	z_min = s.z_min
	z_max = s.z_max

	# Clear previous pipe nodes
	for p in pipes:
		if is_instance_valid(p):
			p.queue_free()
	pipes.clear()

	# Remove legacy LeftPipe/RightPipe if present
	for child_name in ["LeftPipe", "RightPipe"]:
		var legacy := get_node_or_null(child_name)
		if legacy:
			legacy.queue_free()

	for pd in s.pipes:
		var n := QuarterPipe.new()
		n.side = pd.side
		n.lip_x = pd.lip_x
		n.radius = pd.radius
		n.z_min = pd.z_min
		n.z_max = pd.z_max
		add_child(n)
		pipes.append(n)

	# Convenience: first left / first right for debug / simple visuals
	lip_left = s.x_min
	lip_right = s.x_max
	pipe_radius = 150.0
	for pd in s.pipes:
		if pd.side == QuarterPipe.PipeSide.LEFT:
			lip_left = pd.lip_x
			pipe_radius = pd.radius
			break
	for pd in s.pipes:
		if pd.side == QuarterPipe.PipeSide.RIGHT:
			lip_right = pd.lip_x
			break

	if spec:
		perspective_origin_x = spec.spawn_x
		perspective_origin_z = spec.spawn_z
	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


## Keep lean under the skater so the visible band matches across level depths.
## Threshold avoids redrawing the whole park every physics tick while skating.
func set_perspective_origin(logical_x: float, logical_z: float) -> void:
	if (
		absf(logical_x - perspective_origin_x) < 2.0
		and absf(logical_z - perspective_origin_z) < 4.0
	):
		return
	perspective_origin_x = logical_x
	perspective_origin_z = logical_z
	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


func depth_t(logical_z: float) -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


## Lean rate: 0 at skater−ref/2, 1 at skater+ref/2. Unclamped so lip lines keep
## one continuous slope instead of bending into a parallel corridor.
func perspective_t(logical_z: float) -> float:
	return PerspectiveMath.perspective_t(logical_z, perspective_origin_z, reference_depth)


func geometry_scale_at(logical_z: float) -> float:
	return PerspectiveMath.geometry_scale_at(perspective_t(logical_z), far_geometry_scale)


func inset_at(logical_z: float) -> float:
	return PerspectiveMath.inset_at(perspective_t(logical_z), perspective_inset)


## Pixels of screen-Y per logical Z unit (near edge → farther = smaller Y).
func screen_y_per_z() -> float:
	return PerspectiveMath.screen_y_per_z(near_screen_y, far_screen_y, reference_depth)


func ground_screen_y(logical_z: float) -> float:
	# Absolute mapping — deep levels grow taller in screen space and stay off-frame
	# until the camera pans with the player.
	return PerspectiveMath.ground_screen_y(
		logical_z, z_min, near_screen_y, far_screen_y, reference_depth
	)


func x_min() -> float:
	if spec:
		return spec.x_min
	return lip_left - pipe_radius


func x_max() -> float:
	if spec:
		return spec.x_max
	return lip_right + pipe_radius


## Prefer a specific pipe first (side + lip). Stops spine neighbors that share a
## coping X from stealing the sample while still riding.
func sample(
	logical_x: float,
	logical_z: float,
	prefer_side: int = -1,
	prefer_lip_x: float = NAN
) -> Dictionary:
	if prefer_side >= 0 and not is_nan(prefer_lip_x):
		for pipe in pipes:
			if int(pipe.side) != prefer_side:
				continue
			if absf(pipe.lip_x - prefer_lip_x) > 0.05:
				continue
			var preferred: Dictionary = pipe.query_surface(logical_x, logical_z)
			if preferred.get("active", false):
				return preferred

	for pipe in pipes:
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			return hit

	var p := Vector2(logical_x, logical_z)
	if spec:
		for deck in spec.decks:
			if LevelSpec.point_in_poly(p, deck.poly):
				return {
					"active": true,
					"zone": "deck",
					"height": float(deck.height),
					"angle": 0.0,
					"theta": 0.0,
					"normal_x": 0.0,
					"normal_y": 1.0,
					"t_along_pipe": 0.0,
					"deck": deck,
				}
		for floor in spec.floors:
			if LevelSpec.point_in_poly(p, floor.poly):
				return {
					"active": true,
					"zone": "flat",
					"height": 0.0,
					"angle": 0.0,
					"theta": 0.0,
					"normal_x": 0.0,
					"normal_y": 1.0,
					"t_along_pipe": 0.0,
				}

	return {
		"active": false,
		"zone": "oob",
		"height": 0.0,
		"angle": 0.0,
		"theta": 0.0,
		"normal_x": 0.0,
		"normal_y": 1.0,
		"t_along_pipe": 0.0,
	}


## Transfer probe: decks first, then other pipes, then flat. Excludes the source pipe.
func sample_transfer(
	logical_x: float,
	logical_z: float,
	exclude_side: int,
	exclude_lip_x: float
) -> Dictionary:
	var p := Vector2(logical_x, logical_z)
	if spec:
		for deck in spec.decks:
			if LevelSpec.point_in_poly(p, deck.poly):
				return {
					"active": true,
					"zone": "deck",
					"height": float(deck.height),
					"angle": 0.0,
					"theta": 0.0,
					"normal_x": 0.0,
					"normal_y": 1.0,
					"t_along_pipe": 0.0,
					"deck": deck,
				}

	for pipe in pipes:
		if pipe.side == exclude_side and absf(pipe.lip_x - exclude_lip_x) < 0.05:
			continue
		var hit: Dictionary = pipe.query_surface(logical_x, logical_z)
		if hit.get("active", false):
			hit["radius"] = pipe.radius
			return hit

	if spec:
		for floor in spec.floors:
			if LevelSpec.point_in_poly(p, floor.poly):
				return {
					"active": true,
					"zone": "flat",
					"height": 0.0,
					"angle": 0.0,
					"theta": 0.0,
					"normal_x": 0.0,
					"normal_y": 1.0,
					"t_along_pipe": 0.0,
				}

	# Empty / oob still lands as flat at the probe point.
	return {
		"active": true,
		"zone": "flat",
		"height": 0.0,
		"angle": 0.0,
		"theta": 0.0,
		"normal_x": 0.0,
		"normal_y": 1.0,
		"t_along_pipe": 0.0,
	}


## Project a world point for gameplay visuals.
func project_surface(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	return project(logical_x, logical_z, surface_height)


## Decks use the same projector as everything else (logical X → perspective lerp).
func project_deck_point(deck: Dictionary, logical_x: float, logical_z: float) -> Dictionary:
	return project(logical_x, logical_z, float(deck.height))


## Project logical (x,z,height) to screen.
## X scales toward perspective_origin_x with depth (same for floor/pipes/decks)
## so adjacent features share lean instead of fanning from the level midpoint.
## Height uses geometry_scale alone. X lean uses reference_width (not level span)
## so wider maps keep the same vanishing rate as a single bay.
func project(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	return PerspectiveMath.project(
		logical_x,
		logical_z,
		surface_height,
		perspective_origin_x,
		perspective_origin_z,
		z_min,
		near_screen_y,
		far_screen_y,
		reference_depth,
		reference_width,
		perspective_inset,
		far_geometry_scale
	)


func pipe_screen_point_for(pipe: QuarterPipe, logical_z: float, u: float) -> Vector2:
	var theta := clampf(u, 0.0, 1.0) * PI * 0.5
	var x_off := pipe.radius * sin(theta)
	var height := pipe.radius * (1.0 - cos(theta))
	var logical_x: float
	if pipe.side == QuarterPipe.PipeSide.LEFT:
		logical_x = pipe.lip_x - x_off
	else:
		logical_x = pipe.lip_x + x_off
	var p := project(logical_x, logical_z, height)
	return Vector2(p.screen_x, p.ground_y - p.surface_screen_h)


## Back-compat for single-bay helpers.
func pipe_screen_point(is_left: bool, logical_z: float, u: float) -> Vector2:
	for pipe in pipes:
		var pipe_is_left: bool = pipe.side == QuarterPipe.PipeSide.LEFT
		if pipe_is_left == is_left:
			return pipe_screen_point_for(pipe, logical_z, u)
	return Vector2.ZERO
