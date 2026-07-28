extends RefCounted
## Lava death freezes sim and respawns at last safe pad.

const _Fixture := preload("res://tests/player_runtime_fixture.gd")


func run() -> bool:
	var fx = _Fixture.new()
	if not fx.setup("res://tests/levels/test_lava.ssk"):
		return false
	var ok = _grounded_lava_kills(fx) and _airborne_lava_safe(fx)
	fx.teardown()
	return ok


func _grounded_lava_kills(fx) -> bool:
	fx.player.call("_clear_air")
	fx.player._on_ramp = false
	fx.player._airborne = false
	fx.player.depth.airborne = false
	fx.player._dead = false
	fx.player._safe_x = 400.0
	fx.player._safe_z = 100.0
	fx.player._safe_h = 0.0
	fx.player._safe_facing = "r"
	# Stand on a lava glyph cell (row with xxxx around mid).
	fx.player.depth.logical_x = 470.0
	fx.player.depth.logical_z = 70.0
	fx.player.depth.surface_height = 0.0
	fx.player._velocity = Vector2.ZERO
	fx.tick(3)
	if not bool(fx.player._dead):
		# Sample may not land exactly on lava — force last_surface then death check.
		fx.player.last_surface = {"zone": "lava", "active": true, "height": 0.0}
		fx.player._airborne = false
		fx.player.call("_try_lava_death")
	if not bool(fx.player._dead):
		push_error("grounded lava must set _dead")
		return false
	return true


func _airborne_lava_safe(fx) -> bool:
	fx.player._dead = false
	fx.clear_to_air()
	fx.player.last_surface = {"zone": "lava", "active": true, "height": 0.0}
	fx.player.air_abs_height = 80.0
	fx.player.depth.surface_height = 80.0
	fx.player.call("_try_lava_death")
	if bool(fx.player._dead):
		push_error("airborne over lava must not kill")
		return false
	return true
