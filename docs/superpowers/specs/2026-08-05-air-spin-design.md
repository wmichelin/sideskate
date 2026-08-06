# Air spin (yaw rotation)

**Status:** approved design (2026-08-05). Implementation follows
`docs/superpowers/plans/2026-08-05-air-spin.md`.

## Goal

While airborne (including transfer), hold rotate left/right to yaw the rider and
board. Landing must be near a true *N×180°* or the rider falls. Spin never
changes X velocity. A “backwards” landing flips gameplay facing to momentum
without rotating the board.

## Context

Board yaw is presentation-owned (`BoardYawTracker` / `LogicalPose.board_yaw`)
with hang-apex co-rotation. This feature promotes **air spin** into sim
authority (`spin_yaw`) so land classify and facing flips are deterministic.
Aerial vocabulary (air-out / fly-out / transfer) is unchanged; spin is an
additive air control.

## Vocabulary

| Term | Meaning |
|------|---------|
| **`spin_yaw`** | Continuous yaw (rad) from the start of the current air bout |
| **Rotate left / right** | Input actions (Q / E): CCW / CW while held |
| **Land window** | Tunable half-width around nearest *N×π*; outside → fall |
| **Momentum facing fix** | On successful land, if facing opposes horizontal momentum, set facing to momentum without changing board yaw |

## Player-facing behavior

| Rule | Behavior |
|------|----------|
| Input | `rotate_left` (Q, CCW) / `rotate_right` (E, CW). Hold = spin at rate; both held = no spin. |
| Freeze | Release locks yaw mid-air. Landing always freezes at contact angle (even if still held). |
| Facing (live) | `facing` flips each time continuous yaw crosses an odd *N×180* from takeoff. **No change to `velocity.x`.** |
| Good land | Within tunable window of nearest *N×180* → snap yaw to that exact angle; keep facing from snapped yaw. |
| Bad land | Outside window (e.g. ~90° / ~270°) → `begin_fall`. |
| Backwards land | After a good land, if `facing` opposes horizontal momentum → set `facing` to momentum **without** changing board yaw (no spin-back anim; head-only later). |
| Grounded | Q/E ignored. |
| Allowed | Any airborne state, including transfer maneuvers. |

**Angle reference:** `spin_yaw = 0` at the start of the current air bout
(`_enter_air` / new airborne stretch). Do **not** reset mid-transfer.

## Architecture

Sim owns the spin; presentation only displays it.

| Piece | Role |
|-------|------|
| `SimState` | `spin_yaw`, rotate hold flags, bout takeoff facing for live flips |
| `AirSolver` | Integrate yaw while airborne + rotate held; freeze on release; never touch `velocity.x` |
| Land path | On grounded mount / hang remount / transfer dest seat: classify vs *N×π*; bad → `begin_fall`; good → snap, then momentum facing fix without rewriting board yaw |
| `BoardYawTracker` | Advances `board_yaw` with spin deltas (like hang-apex co-rotation); momentum facing fix does **not** call board snap |
| `player.gd` | InputMap → sim; debug exports; pose publishes `facing_yaw + spin_yaw` |
| Debug | Sliders for spin rate and land success half-width (degrees) |

### Yaw composition

- **Discrete** `facing` (`l`/`r`): flips live at odd *N×π* crossings; momentum fix may flip again on successful land without touching board.
- **Continuous** `spin_yaw`: integrate while held; freeze on release or land.
- **Hang apex** keeps using `facing_yaw`; display body yaw = `facing_yaw + spin_yaw` (+ depth-turn).
- **Board:** tracker follows `delta(spin_yaw)` and existing apex `facing_yaw` deltas.

### Defaults

- Spin rate ≈ `π` rad/s (debug tunable).
- Land success half-width ≈ `25°` (debug tunable).

## Land gate

- `nearest = round(spin_yaw / π) * π`
- `err = abs(angle_difference(spin_yaw, nearest))` (or equivalent absolute error to nearest *N×π*)
- If `err ≤ LAND_SPIN_WINDOW` → success: snap `spin_yaw = nearest`; sync facing from half-turns; **rebase** `spin_yaw` to 0 with `spin_handoff` so presentation does **not** rotate back through the spin (the 180 sticks).
- Else → `begin_fall()`; freeze spin; leave mid-angle for fall presentation.

**Momentum facing fix** (success only): if horizontal momentum sign is clearly
nonzero and opposes `facing`, set facing to momentum only (no `snap_to_facing` on
the board).

**Compose with existing systems:** hang apex turn still runs (does not reset
`spin_yaw`); depth-turn unchanged; transfer X-lerp unchanged; fall bout ignores
rotate input.

**Clear / reset:** `spin_yaw = 0` on new air bout, successful grounded settle,
fall enter, death/respawn.

## Out of scope

- Flip tricks (kickflip roll/pitch) beyond the existing ollie clip
- Head-only facing visual (follow-up)
- Grounded spinning / manuals
- Score / combo metering
- Changing `velocity.x` from spin
- Touch bindings for rotate (can come later)

## Acceptance

1. Hold rotate in free air → `spin_yaw` advances; `velocity.x` unchanged
2. Live facing flips at odd *N×180* crossings mid-air
3. Release freezes yaw; land inside window → snap to exact *N×π*, no fall
4. Land near 90°/270° (outside window) → falling
5. Hold through land → freeze at contact; same classify
6. Good 180 with travel opposing facing → facing flips to momentum; board yaw unchanged by that fix
7. Spin during transfer allowed; seat/land still gated
8. Debug sliders move spin rate and land window
