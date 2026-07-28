class_name PlayerDeath
extends RefCounted
## Safe-pad / lava death predicates (no overlay / respawn mutation).


## Grounded lava only — airborne over lava must not kill.
static func should_die_on_lava(airborne: bool, last_surface: Dictionary) -> bool:
	if airborne or last_surface.is_empty():
		return false
	return ContactMath.is_lava(last_surface)
