extends RefCounted
## PlayerDeath: grounded-lava predicate only.

const _PlayerDeath := preload("res://scripts/player_death.gd")


func run() -> bool:
	return (
		_grounded_lava_dies()
		and _airborne_lava_safe()
		and _empty_surface_safe()
		and _flat_ground_safe()
	)


func _grounded_lava_dies() -> bool:
	if not _PlayerDeath.should_die_on_lava(false, {"zone": "lava"}):
		push_error("grounded lava must kill")
		return false
	return true


func _airborne_lava_safe() -> bool:
	if _PlayerDeath.should_die_on_lava(true, {"zone": "lava"}):
		push_error("airborne over lava must not kill")
		return false
	return true


func _empty_surface_safe() -> bool:
	if _PlayerDeath.should_die_on_lava(false, {}):
		push_error("empty last_surface must not kill")
		return false
	return true


func _flat_ground_safe() -> bool:
	if _PlayerDeath.should_die_on_lava(false, {"zone": "flat"}):
		push_error("flat ground must not kill")
		return false
	return true
