extends RefCounted
## AerialSettle: height-retuned X/tilt progress, acid travel clamp.

const _AerialSettle := preload("res://scripts/aerial_settle.gd")


func run() -> bool:
	return (
		_x_reaches_endpoint()
		and _duration_shrinks_on_fall()
		and _acid_travel_never_reverses()
		and _tilt_completes()
	)


func _x_reaches_endpoint() -> bool:
	var s = _AerialSettle.new()
	var active = s.begin_x(100.0, 200.0, true, 0.0, 0.15, 0.18, 0.002, 0.9)
	if not active:
		push_error("settle should be active across 100u")
		return false
	var x = 100.0
	for _i in range(120):
		x = s.step_x(1.0 / 60.0, x, 0.0, 0.18, 0.002, 0.9, false, 0.0)
		if not s.x_active:
			break
	if s.x_active or absf(x - 200.0) > 0.05:
		push_error("settle must finish at endpoint, x=%s active=%s" % [x, s.x_active])
		return false
	return true


func _duration_shrinks_on_fall() -> bool:
	var s = _AerialSettle.new()
	s.begin_x(0.0, 300.0, true, 200.0, 0.15, 0.18, 0.002, 0.9)
	var dur0 = s.x_dur
	s.step_x(1.0 / 60.0, 0.0, 200.0, 0.18, 0.002, 0.9, false, 0.0)
	var mid = s.x_u
	# Fall to coping — duration must snap shorter and progress accelerate.
	s.step_x(1.0 / 60.0, 0.0, 0.0, 0.18, 0.002, 0.9, false, 0.0)
	if s.x_dur > dur0 + 0.001:
		push_error("duration must not grow on fall, %s → %s" % [dur0, s.x_dur])
		return false
	if s.x_dur > 0.19:
		push_error("at coping duration should near base, got %s" % s.x_dur)
		return false
	if s.x_u <= mid:
		push_error("progress must advance, mid=%s after=%s" % [mid, s.x_u])
		return false
	return true


func _acid_travel_never_reverses() -> bool:
	var s = _AerialSettle.new()
	s.begin_x(0.0, 200.0, true, 50.0, 0.15, 0.18, 0.002, 0.9)
	var x = 0.0
	var travel = 1.0
	for _i in range(30):
		var next = s.step_x(1.0 / 60.0, x, 40.0, 0.18, 0.002, 0.9, true, travel)
		if next + 0.001 < x:
			push_error("acid settle reversed travel: %s → %s" % [x, next])
			return false
		x = next
	return true


func _tilt_completes() -> bool:
	var s = _AerialSettle.new()
	if not s.begin_tilt(0.0, -PI * 0.5, true, 0.0, 0.15, 0.18, 0.002, 0.9):
		push_error("tilt settle should start")
		return false
	var t = 0.0
	for _i in range(120):
		t = s.step_tilt(1.0 / 60.0, t, 0.0, 0.18, 0.002, 0.9)
		if not s.tilt_active:
			break
	if s.tilt_active or absf(t + PI * 0.5) > 0.02:
		push_error("tilt must finish at target, t=%s" % t)
		return false
	return true
