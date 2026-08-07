class_name ControlsCatalog
extends RefCounted
## Shared control bindings shown in the Controls screen (main menu + pause).


static func rows() -> Array:
	## Each entry: [input_label, action_label]
	return [
		["WASD / arrows / stick", "Move (W = farther)"],
		["Space / Cross (×)", "Hold ollie — accel in facing dir"],
		["P / T / R2", "Spine (rising) / acid drop (falling)"],
		["Q / L1 · E / R1", "Air spin left (CCW) / right (CW)"],
		["R / Triangle (△)", "Grind lock (airborne near rail)"],
		["Y", "Fall"],
		["Esc / Options", "Pause / back"],
		["Cross (×)", "Confirm / select in menus"],
		["Circle (○)", "Cancel / close menus"],
	]
