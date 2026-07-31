# Ramp lip-band exit upright

## Goal

When leaving a **ramp** from the upper lip band (same `ollie_lip_frac` as pipe ollie), free air should stand the skater upright so ollies and peak ride-offs do not carry ramp lean through the air.

## Non-goals

- No change to **pipe** hang / air-out / fly-out lean rules.
- No new tunable (reuse `ollie_lip_frac`).
- Mid-ramp leaves (below the band) keep pre-takeoff lean.
- Presentation lerps carry lean → upright over `Player.free_air_upright_duration` (default 0.1s; 0 = snap). Same path as fly-out upright.

## Band

Same threshold as pipe lip ollie:

```
u >= 1.0 - ollie_lip_frac
```

Default `ollie_lip_frac = 0.50` → top 50% of the ramp (`u` toward the peak / coping end). Peak leave is always at `u = 1`, so it is always in-band.

## Behavior

| Exit | Surface | In lip band? | `free_air_upright` |
|------|---------|--------------|--------------------|
| Free-air ollie | Ramp | Yes | `true` |
| Peak leave (`_launch_from_ramp_peak`) | Ramp | Always (`u = 1`) | `true` |
| Other free-air leave (e.g. Z-end eject) | Ramp | Yes | `true` |
| Free-air ollie / fall / Z leave | Ramp | No | `false` (keep lean) |
| Any free-air / hang / fly-out | Pipe | — | Unchanged |

## Architecture

Reuse `SimState.free_air_upright`. Presentation already zeros tilt when the flag is set (`player.gd`).

`_enter_air` today clears hang and sets `free_air_upright = false` for free-air entries. Ramp lip-band leave sites set the flag to `true` **after** that enter (or equivalent: set upright in the leave helper once airborne).

Preferred touch points:

1. `launch_height_impulse` — after free-air `_enter_air` from a ramp with `u` in lip band (capture band membership before clearing grounded surface).
2. `_launch_from_ramp_peak` — after `_enter_air`, set upright.
3. Any other ramp → free-air path that can fire while `u` is in-band (e.g. `_leave_slope_at_z_end` eject) — same rule: if launch surface was a ramp and takeoff `u` was in-band, set upright.

Do **not** overload `_enter_air` with a general upright parameter unless a second call site needs it; keep the rule at ramp leave sites.

## Docs to update (implementation)

- `docs/movement_contract.md` — Ollie row: ramp lip-band free air uprights presentation lean.
- `docs/gameplay.md` — same note (air keeps lean except ramp lip-band exit + fly-out).
- `AGENTS.md` lean one-liner — include ramp lip-band exit.

## Tests

Headless sim coverage in `tests/sim/`:

1. Ramp free-air ollie with `u` in lip band → `free_air_upright == true`.
2. Ramp peak leave → `free_air_upright == true`.
3. Ramp free-air ollie below lip band → `free_air_upright == false`.
4. Pipe paths unchanged (existing hang / fly-out upright assertions remain).

## Self-review

- **Gap:** Z-end leave while in lip band is rare but covered by the “any free-air leave from band” rule so behavior stays consistent.
- **Ambiguity:** “Top” means peak-ward `u` (`u → 1`), not deck lip at `u = 0`. Deck-side lip leave stays grounded when supported and is out of scope for upright air.
- **Existing lean contract:** Fly-out already sets upright; this extends the same flag to ramp lip-band free-air exits only.
