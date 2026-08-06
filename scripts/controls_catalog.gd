class_name ControlsCatalog
extends RefCounted
## Shared control bindings shown in the Controls screen (main menu + pause).


static func rows() -> Array:
	## Each entry: [input_label, action_label]
	return [
		["WASD / arrows", "Move (W = farther)"],
		["Space", "Hold ollie — accel in facing dir"],
		["P / T", "Spine (rising) / acid drop (falling)"],
		["Q / E", "Air spin left (CCW) / right (CW)"],
		["R", "Grind lock (airborne near rail)"],
		["Y", "Fall"],
		["Esc", "Pause / back"],
	]
