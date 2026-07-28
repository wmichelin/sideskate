extends RefCounted
## GroundPipeMath arc step kinds.

const _GroundPipeMath := preload("res://scripts/ground_pipe_math.gd")


func run() -> bool:
	# LEFT sign=-1; negative along climbs toward coping.
	var launch = _GroundPipeMath.step_along_pipe(0, 141.0, 141.0, 1.55, -300.0, 0.05)
	if str(launch.get("kind")) != "launch":
		push_error("near π/2 with toward-coping speed must launch, got %s" % launch)
		return false
	# RIGHT sign=+1; negative speed lowers theta → flat.
	var flat = _GroundPipeMath.step_along_pipe(1, 100.0, 150.0, 0.01, -200.0, 0.05)
	if str(flat.get("kind")) != "flat":
		push_error("theta→0 must return flat, got %s" % flat)
		return false
	var arc = _GroundPipeMath.step_along_pipe(1, 100.0, 150.0, 0.4, 200.0, 1.0 / 60.0)
	if str(arc.get("kind")) != "arc":
		push_error("mid-arc must stay on arc, got %s" % arc)
		return false
	var horiz = _GroundPipeMath.project_horiz_from_along(100.0, 0.0)
	if absf(horiz - 100.0) > 0.01:
		push_error("θ=0 horiz = along")
		return false
	return true
