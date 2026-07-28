class_name PlayerSurface
extends RefCounted
## Pure last_surface / height-follow helpers for Player._apply_surface.


## Decorate underfoot sample as airborne debug/collision label.
static func decorate_air_surface(
	underfoot: Dictionary,
	air_over: String,
	air_over_layer: int,
	air_abs_height: float,
) -> Dictionary:
	var s := underfoot.duplicate()
	s["zone"] = "air"
	s["air_over"] = air_over
	s["air_over_layer"] = air_over_layer
	s["height"] = air_abs_height
	return s


## Whether grounded feet should adopt sampled support height this tick.
static func should_follow_sample_height(
	on_ramp: bool,
	sample_h: float,
	prev_surface_h: float,
	ride_off_eps: float,
) -> bool:
	return on_ramp or sample_h >= prev_surface_h - ride_off_eps


## Head-debug zone line (without facing suffix).
static func zone_label(
	last_surface: Dictionary,
	air_over: String,
	air_over_layer: int,
	layer_from_surface: Callable,
) -> String:
	var zone := str(last_surface.get("zone", "flat"))
	if zone == "air":
		var over := air_over
		if over == "" and last_surface.has("air_over"):
			over = str(last_surface.air_over)
		var layer := air_over_layer
		if layer < 0 and last_surface.has("air_over_layer"):
			layer = int(last_surface.air_over_layer)
		if over != "":
			if layer >= 0:
				return "air (over %s L%d)" % [over, layer]
			return "air (over %s)" % over
		return "air"
	var layer_g := -1
	if layer_from_surface.is_valid():
		layer_g = int(layer_from_surface.call(last_surface))
	if layer_g >= 0:
		return "%s L%d" % [zone, layer_g]
	return zone
