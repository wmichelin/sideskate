class_name GroundPipeMath
extends RefCounted
## Pure quarter-pipe arc step: theta advance, lip exit, flat return.


## Result of one arc step.
## kind: "arc" | "launch" | "flat" | "noop"
static func step_along_pipe(
	side: int,
	lip_x: float,
	radius: float,
	theta: float,
	arc_speed: float,
	delta: float,
) -> Dictionary:
	if radius <= 0.0001:
		return {"kind": "noop"}
	var sign := PipeMath.coping_sign(side)
	var toward_arc := (arc_speed * delta) * sign
	var new_theta := theta + toward_arc / radius
	if new_theta >= PI * 0.5:
		return {
			"kind": "launch",
			"up_speed": maxf(arc_speed * sign, 0.0),
			"side": side,
			"lip_x": lip_x,
			"radius": radius,
		}
	if new_theta <= 0.0:
		var overshoot_x := lip_x - sign * absf(new_theta) * radius
		return {
			"kind": "flat",
			"logical_x": overshoot_x,
			"restore_horiz": true,
		}
	var x_off := radius * sin(new_theta)
	var next_x := lip_x - x_off if side == 0 else lip_x + x_off
	return {
		"kind": "arc",
		"logical_x": next_x,
		"theta": new_theta,
	}


static func project_horiz_from_along(along: float, theta: float) -> float:
	return along * cos(clampf(theta, 0.0, PI * 0.5))
