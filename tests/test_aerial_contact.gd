extends RefCounted
## AerialContact: sticky query + unlocked identity patches.

const _AerialContact := preload("res://scripts/aerial_contact.gd")
const _ContactMath := preload("res://scripts/contact_math.gd")


func run() -> bool:
	return (
		_sticky_when_over_pipe()
		and _sticky_when_locked()
		and _sticky_cleared_on_flat_free()
		and _locked_skips_identity()
		and _unlocked_pipe_identity()
		and _unlocked_pad_and_hole()
		and _pipe_identity_from_hit()
	)


func _sticky_when_over_pipe() -> bool:
	var s = _AerialContact.sticky_query("left_pipe", false, 0, 300.0, 141.0, 10.0, 90.0)
	if int(s.side) != 0 or absf(float(s.lip_x) - 300.0) > 0.01:
		push_error("over-pipe free air must sticky: %s" % s)
		return false
	return true


func _sticky_when_locked() -> bool:
	var s = _AerialContact.sticky_query("flat", true, 1, 400.0, 0.0, 0.0, 100.0)
	if int(s.side) != 1 or absf(float(s.base_height) - 0.0) > 0.01:
		push_error("X-lock must sticky even over flat zone: %s" % s)
		return false
	return true


func _sticky_cleared_on_flat_free() -> bool:
	var s = _AerialContact.sticky_query("flat", false, 0, 300.0, 0.0, 0.0, 100.0)
	if int(s.side) != -1 or not is_nan(float(s.lip_x)):
		push_error("unlocked flat must clear sticky: %s" % s)
		return false
	return true


func _locked_skips_identity() -> bool:
	var contact = _ContactMath.make_air_contact(
		"deck", 1, 141.0, true, {"zone": "deck", "height": 141.0}
	)
	var p = _AerialContact.unlocked_identity_from_contact(contact, true)
	if bool(p.get("apply", true)):
		push_error("locked must not adopt underfoot identity")
		return false
	return true


func _unlocked_pipe_identity() -> bool:
	var hit := {
		"zone": "right_pipe",
		"side": 1,
		"lip_x": 400.0,
		"base_height": 0.0,
		"height": 150.0,
	}
	var contact = _ContactMath.make_air_contact("right_pipe", 0, 150.0, true, hit)
	var p = _AerialContact.unlocked_identity_from_contact(contact, false)
	if not bool(p.apply) or str(p.kind) != "pipe":
		push_error("unlocked pipe identity failed: %s" % p)
		return false
	if int(p.hit.side) != 1:
		push_error("pipe hit side missing")
		return false
	return true


func _unlocked_pad_and_hole() -> bool:
	var pad_c = _ContactMath.make_air_contact(
		"deck", 1, 141.0, true, {"zone": "deck", "height": 141.0}
	)
	var pad = _AerialContact.unlocked_identity_from_contact(pad_c, false)
	if str(pad.kind) != "pad" or absf(float(pad.air_base_height) - 141.0) > 0.01:
		push_error("deck pad identity failed: %s" % pad)
		return false
	var hole_c = _ContactMath.make_air_contact("hole", 1, 188.0, false, {})
	var hole = _AerialContact.unlocked_identity_from_contact(hole_c, false)
	if str(hole.kind) != "hole" or absf(float(hole.air_base_height) - 188.0) > 0.01:
		push_error("hole identity failed: %s" % hole)
		return false
	return true


func _pipe_identity_from_hit() -> bool:
	var under := {
		"side": 0,
		"lip_x": 300.0,
		"base_height": 141.0,
		"radius": 100.0,
		"z_min": 5.0,
		"z_max": 95.0,
		"layer": 1,
	}
	var id = _AerialContact.pipe_identity_from_hit(
		under, 1, 0.0, 0.0, NAN, NAN, 100.0, -1
	)
	if str(id.air_over) != "left_pipe" or int(id.air_side) != 0:
		push_error("pipe identity zone/side: %s" % id)
		return false
	if int(id.air_over_layer) != 1:
		push_error("hit layer must win: %s" % id.air_over_layer)
		return false
	var want_cope = PipeMath.coping_x(0, 300.0, 100.0)
	if absf(float(id.air_coping_x) - want_cope) > 0.01:
		push_error("coping mismatch")
		return false
	return true
