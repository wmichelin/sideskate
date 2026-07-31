# Ollie height: flat vs pipe

## Goal

Separate peak ollie height when popping off flat supports from when popping off transition/wall surfaces, and expose both values on the debug TUNING sliders.

## Behavior

On grounded ollie release, peak height is `charge_frac ×` one of two tunables:

| Grounded surface | Height used | Default |
|------------------|-------------|---------|
| Floor, deck | `ollie_height_flat` | 150 |
| Pipe, ramp, wall | `ollie_height_pipe` | 100 |

- Charge time (`ollie_charge_ms`) stays shared.
- Lip-band hang path (`ollie_lip_frac`) and free-air vs hang launch path are unchanged; only the height scalar fed into `v = √(2|g|h)` changes.
- Surface class is taken from the grounded `surface_id` at release (same ownership as the ride).
- Airborne ollie release remains out of scope (charge still only builds while grounded).

## Wiring

1. **`Player` / `PlayerSim`** — Replace `ollie_height` with `ollie_height_flat` (default 150) and `ollie_height_pipe` (default 100). Sync from `Player` into `PlayerSim` wherever `ollie_height` is copied today.
2. **`PlayerSim._try_ollie_jump`** — Select height from grounded surface kind before converting to up-speed:
   - `model.patches[surface_id]` with floor kind → flat
   - `model.patches[surface_id]` with deck kind → flat
   - `model.pipes` / `model.ramps` / `model.walls` → pipe
   - Unknown / missing → flat (safe fallback)
3. **`DebugTools` TUNING panel** — Replace the single “ollie height” row with:
   - “ollie height flat” → `ollie_height_flat` (0–200, step 0.1)
   - “ollie height pipe” → `ollie_height_pipe` (0–200, step 0.1)
4. **Docs** — Update `docs/gameplay.md` and the ollie row in `docs/movement_contract.md` to name both heights.
5. **Tests** — Migrate call sites that set `ollie_height` to the appropriate field. Add one regression: with unequal flat/pipe heights, floor release uses flat and pipe release uses pipe (peak or initial `velocity.z` check).

## Non-goals

- Separate charge times per surface class
- Separate lip-frac or launch-path tunables beyond what already exists
- Changing presentation lean / hang / transfer behavior

## Success criteria

- Two TUNING sliders independently change flat vs pipe/ramp/wall ollie peak.
- Defaults: flat 150, pipe 100.
- Headless suite green, including the new pick regression.
