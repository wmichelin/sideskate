class_name ControlsCatalog
extends RefCounted
## Shared control bindings shown in the Controls screen (main menu + pause).


static func rows() -> Array:
	## Each entry: [input_label, action_label]
	return [
		["WASD / arrows / stick", "Move (W = farther)"],
		["Space / Cross (×)", "Hold ollie — accel in facing dir"],
		["P / T / Square (□)", "Spine (rising) / acid drop (falling)"],
		["Q / L1", "Air spin left (CCW)"],
		["E / Triangle (△)", "Air spin right (CW)"],
		["R / R1", "Grind lock (airborne near rail)"],
		["Y", "Fall"],
		["Esc / Options", "Pause / back"],
		["Circle (○)", "Cancel / close menus"],
	]
