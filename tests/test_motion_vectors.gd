extends RefCounted
## MotionVectors: named INPUT / MOMENTUM / ACTUAL triad.


func run() -> bool:
	if MotionVectors.kind_name(MotionVectors.Kind.ACTUAL) != "actual":
		push_error("ACTUAL name")
		return false
	if MotionVectors.kind_name(MotionVectors.Kind.MOMENTUM) != "momentum":
		push_error("MOMENTUM name")
		return false
	if MotionVectors.kind_name(MotionVectors.Kind.INPUT) != "input":
		push_error("INPUT name")
		return false
	if not MotionVectors.is_planar(MotionVectors.Kind.INPUT):
		push_error("INPUT must be planar (X/Z only)")
		return false
	if MotionVectors.is_planar(MotionVectors.Kind.ACTUAL):
		push_error("ACTUAL may include height — not planar")
		return false
	if MotionVectors.is_planar(MotionVectors.Kind.MOMENTUM):
		push_error("MOMENTUM may include ramp vertical — not planar")
		return false
	# Stable enum ordinals — scene exports and save data depend on these.
	if int(MotionVectors.Kind.ACTUAL) != 0:
		push_error("ACTUAL ordinal must stay 0")
		return false
	if int(MotionVectors.Kind.MOMENTUM) != 1:
		push_error("MOMENTUM ordinal must stay 1")
		return false
	if int(MotionVectors.Kind.INPUT) != 2:
		push_error("INPUT ordinal must stay 2")
		return false
	return true
