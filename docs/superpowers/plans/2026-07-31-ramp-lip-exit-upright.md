# Ramp lip-band exit upright — implementation plan

Spec: `docs/superpowers/specs/2026-07-31-ramp-lip-exit-upright-design.md`

## Steps

1. In `ground_solver.gd`, after free-air enter from a ramp in the lip band (`u >= 1 - lip_frac`), set `state.free_air_upright = true`.
   - `launch_height_impulse` (capture ramp + u before enter; use passed `lip_frac`)
   - `_launch_from_ramp_peak` (always upright)
   - `_leave_slope_at_z_end` free-air eject (need lip frac on solver or default 0.50 matching PlayerSim)
2. Extend / add sim tests for lip ollie upright, peak leave upright, mid-ramp ollie not upright.
3. Update lean notes in `movement_contract.md`, `gameplay.md`, `AGENTS.md`.
4. Run `godot4 --headless --path . --script res://tests/test_runner.gd`.
