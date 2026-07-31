# Fall mechanic

## Goal

Add an invokable **fall bout**: hard-interrupt current ride control, lean the skater onto their side, decay planar velocity to zero while gravity continues, lock out input for a duration, then soft-recover upright in place (or on the next land if still airborne).

Y key is the initial invoke for playtesting. The same entry point is for business logic later (not a permanent “press Y to fall” game rule).

## Non-goals

- Not a third motion mode (Grounded / Airborne stay sole modes).
- Not lava death / checkpoint respawn.
- Not a full animation system — presentation lean + debug HUD only.

## Architecture

Fall is a **bout flag** on `SimState`, owned by `PlayerSim`.

| Piece | Ownership |
|-------|-----------|
| Enter / timers / input lock / planar velocity decay / recovery | `PlayerSim` + `SimState` (physics tick) |
| Side lean visual | Presentation (`LogicalPose` / shell sync / 3D presenter) |
| Head cooldown bar | Debug presentation (`player_debug_3d.gd` + `DebugTools`) |
| Y invoke | `player.gd` → `PlayerSim.begin_fall()` |

Public API: `PlayerSim.begin_fall() -> void`.

- No-op if already falling or `not state.alive`.
- On enter: clear hang, maneuver, and ollie charge state; stamp fall elapsed = 0; capture facing for lean sign; capture world X and depth velocity for the stop lerp.

## Timers

All three start at fall enter. Tunable via Player `@export` + debug TUNING sliders; synced to `PlayerSim` each physics tick (same pattern as `apex_facing_delay` / ollie charge).

| Tunable | Default | Role |
|---------|---------|------|
| `fall_anim_duration` | 0.15 s | Lerp presentation onto side |
| `fall_stop_duration` | 0.35 s | Lerp world X and depth (Y) → 0 |
| `fall_duration` | 1.0 s | Input lockout length before recovery is allowed |

Suggested defaults are starting points only.

## Behavior

### While falling

- Ignore stick, transfer, and ollie (control wish treated as zero; no new hang / transfer / ollie).
- Gravity still applies to height (Z).
- Air and ground contact / mounts still run so the skater can land mid-bout.
- Retrigger via `begin_fall()`: no-op.
- Lava kill (`alive = false`) wins: clear fall; existing death overlay path runs.

### Planar velocity stop

- Over `fall_stop_duration`, lerp **world X and depth (Y)** from enter-captured values toward 0.
- Height Z is **not** part of that lerp.
- When grounded, keep tangent velocity consistent with the decaying planar world velocity (do not let ground wish re-accelerate).
- After stop duration, hold X / depth at 0 until recovery.

### Side lean (presentation)

- Over `fall_anim_duration`, lerp fall roll to **±90° toward current facing** at enter (`l` one way, `r` the other).
- While falling, fall roll **owns** visual lean (replaces normal surface-tilt presentation lean).
- On recovery: return to normal surface tilt / upright presentation.
- Anim finishing early does not unlock input.

### Recovery

Recovery runs when **both** are true:

1. `fall_elapsed >= fall_duration`
2. Skater is **grounded**

If duration elapses while airborne, remain locked until the next grounded mount, then recover on that tick.

On recovery:

- Standing upright presentation
- Zero world velocity and tangent velocity
- Clear fall bout
- Input returns

## Input

- New InputMap action `fall` bound to keyboard **Y**.
- `player.gd`: on `just_pressed`, call `_sim.begin_fall()`.
- Future systems call `begin_fall()` directly; Y remains a debug/dev invoke unless gameplay later adopts it.

## Debug HUD — fall cooldown bar

Mirror the ollie charge bar in `scripts/rendering_3d/player_debug_3d.gd`.

- `DebugTools.show_fall_cooldown` (bool) + TUNING checkbox (same pattern as ollie charge bar).
- Visible only while falling and the bool is on.
- Fill = **remaining** lockout fraction: full at enter, drains to empty over `fall_duration` (`1 - elapsed / duration`). Opposite of ollie (which fills up).
- After duration reaches 0 but still waiting to land: stay visible at **0%** until recovery, then hide.
- Same placement/size family as ollie bar; distinct color; label shows remaining `%`.

## Key scripts

| Area | Touch |
|------|--------|
| `SimState` | Fall bout fields (`falling`, elapsed, captured planar vel, facing for lean) |
| `PlayerSim` | `begin_fall()`, tick fall timers / stop lerp / recovery / input gate |
| `player.gd` | Y → `begin_fall()`; export durations; sync tuning; expose fall frac for HUD/lean |
| `LogicalPose` / pose sync / 3D presenter | Fall roll channel |
| `debug_tools.gd` / `debug_sliders.gd` | Durations + show_fall_cooldown |
| `player_debug_3d.gd` | Countdown bar |
| `project.godot` | `fall` action → Y |
| Tests | Headless sim cases below |

## Tests

1. `begin_fall` clears hang and ignores wish (no along climb from stick-out).
2. World X / depth decay to ~0 by `fall_stop_duration`; airborne height still changes under gravity.
3. Duration elapsed in air → still locked; after land → upright, zero vel, wish works again.
4. Facing at enter drives lean sign (sim exposes fall progress / facing for presenters).

## Success criteria

- Y (or `begin_fall()`) starts a fall bout that hard-interrupts hang / maneuver / ollie.
- Skater leans onto facing side quickly; planar speed dies out; gravity continues.
- Input stays locked for `fall_duration`, extended until land if needed; recovery is in-place upright with zero velocity.
- Debug cooldown bar counts down over the head when enabled.
- Headless tests cover lockout, stop lerp, and air-then-land recovery.
