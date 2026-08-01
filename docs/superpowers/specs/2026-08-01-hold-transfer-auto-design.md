# Hold-to-auto-transfer (spine / acid)

**Status:** approved design (2026-08-01).

## Goal

Holding the transfer button auto-accepts a transfer plan (spine or acid drop —
same `ManeuverPlan.Kind.TRANSFER` path) once a candidate exists, after a short
delay. Tap still fires immediately when a candidate exists. Delay is tunable
from the debug menu.

## Context

- `player.gd` already passes `action_down` and `action_edge` into
  `PlayerSim.set_input`; only `action_edge` → `action_just` is used today.
- Transfer accept lives in `PlayerSim._try_actions` via
  `ManeuverPlanner.try_transfer` + candidate gates in
  `SurfaceQuery.transfer_candidates` (above dest hang lip, facing half-plane,
  opposite side).
- Gameplay must arm/fire on the **fixed physics timestep** only.

## Behavior

| Input | When candidate exists | Result |
|-------|----------------------|--------|
| Tap (`action_just`) | Same physics tick | Try transfer immediately (unchanged) |
| Hold (`action_down`) | Continuously eligible | After `transfer_hold_delay` of **eligible** time, try transfer once |
| Hold | No candidate / busy / falling | Do not arm; timer stays 0 |
| Release | Any | Reset eligible timer |

Eligible means: transfer pressed, alive, not falling, no active maneuver, and
`transfer_candidates(state)` non-empty. Timer accumulates only while eligible
(fixed `dt`); it does **not** start on button-down before a candidate appears.

Spine and acid share one path — no separate acid timer or button.

## Architecture

**Sim-owned hold arm (sole approach).**

1. `PlayerSim` stores `action_held` from `set_input` (wire the existing
   `_action_down` parameter).
2. Each physics tick before/with `_try_actions`:
   - If not eligible → `transfer_hold_eligible = 0`.
   - Else → `transfer_hold_eligible += dt`.
   - Fire when `action_just` **or**
     `transfer_hold_eligible >= transfer_hold_delay` (treat delay ≤ 0 as
     immediate on first eligible hold tick).
3. On successful accept (same as today’s clear_hang + assign plan), reset
   `transfer_hold_eligible`. Rejects while still held keep accumulating so a
   later-valid window can still fire after the delay has already elapsed
   (clamp: once eligible time ≥ delay, each tick may retry until accept or
   ineligibility).

Tuning:

- `PlayerSim.transfer_hold_delay: float` (seconds).
- `@export` on `player.gd`, synced in `_sync_tuning_to_sim` like other knobs.
- Debug slider in `debug_sliders.gd` (range ~0–0.5 s, default **0.08**).

Presentation / Godot input must not invent candidates or fire transfers;
they only forward pressed/edge.

## Tests

Headless in `tests/sim/test_sim_runtime.gd` (spine fixture already exists):

1. **Hold delay 0:** hold without edge → accept once a candidate appears.
2. **Hold delay > 0:** hold while rising into the window → no accept until
   enough eligible ticks; then accept.
3. **Tap:** with large delay, `action_just` still accepts on the edge tick.

## Out of scope

- Separate acid vs spine input or delays.
- Auto-transfer without the button held.
- Changing transfer candidate geometry / land_along carry.

## Docs

Update `docs/gameplay.md` Transfer blurb: tap immediate; hold after tunable
delay once eligible. Mention debug slider.
