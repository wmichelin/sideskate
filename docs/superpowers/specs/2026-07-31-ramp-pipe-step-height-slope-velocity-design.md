# Ramp/pipe step height + slope velocity retention

## Goal

1. Pipe and ramp **rise** scale with glyph run length via a shared `step_height`, not `cell_w`.
2. Landing on a pipe/ramp from free air **retains** world X (mapped to along), instead of forcing downhill speed.
3. Ollieing on a pipe/ramp below the lip band **carries full along → world X** (including peak-ward), instead of zeroing uphill X.

## Geometry — `step_height`

### Header

- Optional IDL field: `step_height H` (same header block as `deck_height`).
- If omitted: `H = cell_w` (sane default; preserves today’s single-glyph rise at the default cell size).

### Compile rule (pipes and ramps)

| Glyph run | Footprint width (X) | Rise / radius (height) |
|-----------|---------------------|-------------------------|
| `)` / `>` | `1 × cell_w` | `1 × step_height` |
| `))` / `>>` | `2 × cell_w` | `2 × step_height` |
| `)))` / `>>>` | `3 × cell_w` | `3 × step_height` |

- Footprint stays grid-aligned (`run_cells × cell_w`).
- Height uses `run_cells × step_height` so taller runs are proportionally taller even if `cell_w` changes.
- Deck `#` rise from neighboring pipe/ramp continues to use max neighbor rise (now driven by step_height).
- Pipes and ramps **always share** the same `step_height` (one header).

### Out of scope

- Changing the meaning of `cell_w` / `cell_z`.
- Separate per-type step heights.

## Landing velocity (air → pipe/ramp)

### Bug

Air mounts (`_mount_pipe_owner`, `_mount_ramp_owner`, and hang-remount paths that use the same seed) set:

`tangent_velocity.x = -max(impact, 80)`

That always seeds downhill along-speed and discards incoming world X.

### Rule

On free-air land onto pipe or ramp:

- `along = state.velocity.x * outward_sign()`
- `depth = state.velocity.y` (unchanged)
- No minimum downhill seed; no forced lip-ward sign.

Grounded `_mount_slope_at` already uses `world_vx * outward_sign()` — keep it; make air mounts match.

### Player-facing example

Facing/moving right, land mid `>` (lip left / downhill left): keep positive along (uphill). Gravity still slows and can reverse you; you do not instantly stop and accelerate left.

## Slope ollie velocity (below lip / free-air)

### Bug

Free-air slope ollie builds `wx = t.x * along`, then zeros peak-ward X when `wx * n.x < 0`. Riding up a pipe and ollieing before hang kills world X.

### Rule

- `world = (t.x * along, depth, height_impulse)`, then `_reject_into_normal` only.
- Do **not** zero peak-ward world X.
- Vertical pop remains charge × `ollie_height_flat` / `ollie_height_pipe` as today.
- Lip-band hang path unchanged in policy: X-locked hang; along does **not** stack onto vertical; clearance-to-hang-lip + height impulse as already implemented.

## Key scripts

| Area | Touch |
|------|--------|
| IDL parse / `LevelSpec` | `step_height` field + default |
| `idl_compiler` / loft refine | rise = `run_cells × step_height`; footprint unchanged |
| `air_solver` mount helpers | land along = `vx * outward_sign()` |
| `ground_solver.launch_height_impulse` | drop peak-ward X kill on free-air slope ollie |
| Docs | `level_format.md`, `movement_contract.md`, `gameplay.md` |

## Tests

1. Compiler: `step_height H` → `>` rise H, `>>` rise 2H; same for `)` / `))`; omit header → H defaults to `cell_w`.
2. Land: air `+vx` onto mid `>` → `tangent_velocity.x > 0` (not forced negative).
3. Land: air `+vx` onto mid `)` → along = `vx * outward_sign()`, not `-max(impact, 80)`.
4. Ollie: grounded on pipe with peak-ward along, release below lip → airborne `velocity.x` keeps peak-ward sign (not ~0).

## Success criteria

- Glyph run magnitude controls pipe/ramp height independently of cell width (via `step_height`).
- Landing on a slope no longer feels like an instant stop into downhill.
- Mid-face pipe/ramp ollie preserves ride X through takeoff.
