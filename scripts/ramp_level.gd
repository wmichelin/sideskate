class_name RampLevel
extends Node2D
## Level runtime: loads .ssk, samples floor/deck/pipes, projects to screen.

@export var level_path: String = "res://levels/plaza_default.ssk"

@export_group("Perspective")
@export var near_screen_y: float = 560.0
@export var far_screen_y: float = 300.0
@export var perspective_inset: float = 80.0
@export var far_geometry_scale: float = 0.72

var spec: LevelSpec
var pipes: Array = []  # QuarterPipe nodes

var z_min: float = 0.0
var z_max: float = 100.0
var lip_left: float = 180.0
var lip_right: float = 1100.0
var pipe_radius: float = 150.0

@onready var _visual: Node2D = $RampVisual


func _ready() -> void:
	var path := level_path
	if GameSession.pending_level_path != "":
		path = GameSession.pending_level_path
	if path != "":
		load_level(path)


func load_level(path: String) -> bool:
	var loaded: LevelSpec = LevelLoader.load_path(path)
	# load_path aborts the process on malformed files; null is only possible if quit is deferred.
	if loaded == null:
		return false
	apply_spec(loaded)
	return true


func apply_spec(s: LevelSpec) -> void:
	spec = s
	perspective_inset = s.perspective_inset
	far_geometry_scale = s.far_geometry_scale
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

	if _visual and _visual.has_method("refresh"):
		_visual.refresh()
	elif _visual:
		_visual.queue_redraw()


func depth_t(logical_z: float) -> float:
	var span := z_max - z_min
	if span <= 0.0001:
		return 0.0
	return clampf((logical_z - z_min) / span, 0.0, 1.0)


func geometry_scale_at(logical_z: float) -> float:
	return lerpf(1.0, far_geometry_scale, depth_t(logical_z))


func inset_at(logical_z: float) -> float:
	return lerpf(0.0, perspective_inset, depth_t(logical_z))


func ground_screen_y(logical_z: float) -> float:
	return lerpf(near_screen_y, far_screen_y, depth_t(logical_z))


func x_min() -> float:
	if spec:
		return spec.x_min
	return lip_left - pipe_radius


func x_max() -> float:
	if spec:
		return spec.x_max
	return lip_right + pipe_radius


func sample(logical_x: float, logical_z: float) -> Dictionary:
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


## Project a world point for gameplay visuals — decks use lip-anchored framing.
func project_surface(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	if spec:
		var p := Vector2(logical_x, logical_z)
		for deck in spec.decks:
			if LevelSpec.point_in_poly(p, deck.poly):
				return project_deck_point(deck, logical_x, logical_z)
	return project(logical_x, logical_z, surface_height)


## Project a deck surface point using neighboring pipe lip frames so edge/spine
## decks stay continuous with pipe coping under perspective.
func project_deck_point(deck: Dictionary, logical_x: float, logical_z: float) -> Dictionary:
	var h := float(deck.height)
	var anchors: Array = deck.get("anchors", [])
	if anchors.is_empty():
		return project(logical_x, logical_z, h)

	var t := depth_t(logical_z)
	var inset := inset_at(logical_z)
	var gscale := geometry_scale_at(logical_z)
	var ground_y := ground_screen_y(logical_z)
	var xmin := x_min()
	var xmax := x_max()
	var span := xmax - xmin

	var screen_x: float
	if anchors.size() == 1:
		screen_x = _screen_x_from_lip_anchor(anchors[0], logical_x, t, inset, gscale, xmin, span)
	else:
		# Spine: lerp between coping screen positions so both pipe tops stay flush.
		var sorted: Array = anchors.duplicate()
		sorted.sort_custom(func(a, b): return float(a.coping_x) < float(b.coping_x))
		var a0: Dictionary = sorted[0]
		var a1: Dictionary = sorted[sorted.size() - 1]
		var x0 := float(a0.coping_x)
		var x1 := float(a1.coping_x)
		var sx0 := _screen_x_from_lip_anchor(a0, x0, t, inset, gscale, xmin, span)
		var sx1 := _screen_x_from_lip_anchor(a1, x1, t, inset, gscale, xmin, span)
		var u := 0.0 if absf(x1 - x0) <= 0.0001 else clampf((logical_x - x0) / (x1 - x0), 0.0, 1.0)
		screen_x = lerpf(sx0, sx1, u)

	return {
		"t": t,
		"screen_x": screen_x,
		"ground_y": ground_y,
		"surface_screen_h": h * gscale,
		"geometry_scale": gscale,
		"inset": inset,
	}


func _screen_x_from_lip_anchor(
	anchor: Dictionary,
	logical_x: float,
	t: float,
	inset: float,
	gscale: float,
	xmin: float,
	span: float
) -> float:
	var lip_x := float(anchor.lip_x)
	var lip_u := 0.0 if span <= 0.0001 else clampf((lip_x - xmin) / span, 0.0, 1.0)
	var lip_screen := lerpf(xmin + inset * t, x_max() - inset * t, lip_u)
	if anchor.side == QuarterPipe.PipeSide.LEFT:
		return lip_screen - (lip_x - logical_x) * gscale
	return lip_screen + (logical_x - lip_x) * gscale


## Project logical (x,z,height) to screen. Global X remap + height scale.
func project(logical_x: float, logical_z: float, surface_height: float = 0.0) -> Dictionary:
	var t := depth_t(logical_z)
	var inset := inset_at(logical_z)
	var gscale := geometry_scale_at(logical_z)
	var ground_y := ground_screen_y(logical_z)

	var xmin := x_min()
	var xmax := x_max()
	var span := xmax - xmin
	var u := 0.0 if span <= 0.0001 else clampf((logical_x - xmin) / span, 0.0, 1.0)
	var screen_x := lerpf(xmin + inset * t, xmax - inset * t, u)

	# Prefer per-pipe projection when on a pipe band (matches arc drawing).
	# Lip uses the same perspective lerp as the floor so seams stay closed when
	# the follow camera pans; arc offset is then scaled by geometry_scale.
	for pipe in pipes:
		if logical_z < pipe.z_min - 0.001 or logical_z > pipe.z_max + 0.001:
			continue
		if logical_x < pipe.x_min() - 0.001 or logical_x > pipe.x_max() + 0.001:
			continue
		var lip_u := 0.0 if span <= 0.0001 else clampf((pipe.lip_x - xmin) / span, 0.0, 1.0)
		var lip_screen := lerpf(xmin + inset * t, xmax - inset * t, lip_u)
		var x_off: float
		if pipe.side == QuarterPipe.PipeSide.LEFT:
			x_off = pipe.lip_x - logical_x
			screen_x = lip_screen - x_off * gscale
		else:
			x_off = logical_x - pipe.lip_x
			screen_x = lip_screen + x_off * gscale
		break

	return {
		"t": t,
		"screen_x": screen_x,
		"ground_y": ground_y,
		"surface_screen_h": surface_height * gscale,
		"geometry_scale": gscale,
		"inset": inset,
	}


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
