# SideSkate movement contract

Executable specification for the analytical park simulation (`scripts/sim/`).
This document is authoritative over implementation comments. If code disagrees, the code is wrong.

## Units and frame

| Quantity | Unit | Notes |
|----------|------|-------|
| Position X / Z / height | logical | Same as `.ssk` / `LevelSpec` |
| Velocity | logical / second | Fixed physics timestep only |
| Gravity | logical / s² | Default `-1900` (= −19.0 m/s² × `LOGIC_PER_METER`) |
| Timestep | seconds | `1/60` fixed; never render/idle |
| Capsule radius | logical | `9` (= 0.09 m × 100) |
| Capsule cylinder height | logical | `22` |
| Feet → capsule center | logical | `radius + cylinder/2` |

Coordinate signs match [`docs/level_format.md`](level_format.md): X left→right, Z near→far (row 0 = far), height up.

Godot 3D transforms are presentation / blocker reporting only. Gameplay pose is always logical.

## Aerial vocabulary

Logical axes in this document: **X** left/right, **Z** near/far, **height** up. (Presentation may map height→Y.)

| Term | Alias | Meaning |
|------|-------|---------|
| **Air-out** | hang | Leave a compiled open edge with **X locked** to its anchor. Motion is height (+ optionally Z) only. Stick does **not** unlock X. Keeps surface lean. |
| **Fly-out** | **deck-out** (same action) | Exit X-lock and travel **away** from the pipe: left on a left pipe, right on a right pipe (world outward). Free-air XZ control after unlock. Resets presentation lean upright. |
| **Transfer** | spine / acid pull | Transfer button while a next-spine candidate exists (facing half-plane, opposite side, above target lip). Normal gravity; time-phased progress 0→1 from accept (upright at ballistic apex / mid-pull if falling); lateral X + lean follow (finishes on touch); facing held; `vx` cleared on arrival; re-anchors air-out hang. Logical Z (depth) stays free-air. Deck→pipe remount still TBD. |

### Fly-out / deck-out activation

While air-out (hang) or perched on an `OPEN` / `SHARED_SPINE` coping, and height above coping is within `FLY_OUT_ABOVE`:

- Stick must be **X-dominant** and **outward** (into the lip / toward leaving the pipe): −X on left pipes, +X on right pipes.
- Accepting fly-out clears hang, seeds outward free-air velocity from climb/air speed, ends X-lock, and stands the skater upright (`free_air_upright` — no carried pipe/wall lean).

Same-height outward `#` decks are fly/air corridor — they do **not** auto-mount from the pipe.
Free-air landings on the coping column (or its bowl side) prefer that pipe over an abutting
outward `#` pad — floor ollies that meet the lip drop into the bowl, they do not sticky-mount
the deck with zero coast. Past the coping into the deck remains ordinary deck land / fly-out.

### Air-out landing

While air-out (X-locked):

- The state retains the launch edge and may **retarget** `hang_edge_id` onto a
  colinear same-side `OPEN` coping whose lock X matches when depth leaves the
  launch span.
- Between those spans, hang keeps a synthetic X-lock (does **not** become free air).
  Leaving Z alone never clears hang — that requires fly-out / land / remount.
- Descending through the current (possibly retargeted) edge returns to its source
  pipe or explicit wall with fall speed preserved.
- Depth travel off the launch span (or holding depth stick) skips/freezes the
  into-bowl apex facing turn so takeoff lean is kept.
- Ordinary contact must **never** accept an opposite-facing pipe (transfers TBD).
- Hang remount prefers same-facing X-aligned pipe/wall via the retained/retargeted
  edge anchor. Cross-story rear decks under the lock must not steal remount while a
  remountable pipe/wall is available.
- If no remountable pipe is under the lock (outside the pipe / gap), land the nearest
  floor, deck, lava, or void. Floor/deck flat land clears hang and starts a **fall bout**;
  lava still kills.
- If hang clears mid-air while still on the launch coping X, descending free-air contact
  with that pipe’s wall remounts the wall face (into the bowl) — never bounce-freeze
  beside a coplanar abutting deck.

## High-level states

Exactly one of:

1. **Grounded** — `{ surface_id, u, v, tangent_velocity (Vector2 in surface UV speed), facing }`
2. **Airborne** — `{ position (Vector3: x,z,height), velocity (Vector3), maneuver: ManeuverPlan|null, hang_edge_id: String }`

`hang_edge_id` empty ⇒ free air (XZ control). Non-empty ⇒ **air-out**: X is locked to that edge’s anchor at current Z (depth stick still applies; height ballistic). Hang clears on fly-out, land, or remount. Leaving the launch edge’s Z span **retargets** onto a colinear same-side OPEN edge when available, otherwise keeps a synthetic X-lock across the gap (does not clear).

Crash / death is a terminal grounded→overlay path after **lava** contact only; it is not a third motion state. World borders, unplayable space, deck walls/volumes, and ramp outer-back solids are **containment** that can start a **fall bout** (`begin_fall`) when contacted in free air or while grounded (hang remount of pipe/ramp/wall excluded; own-ramp peak leave and intentional deck-back ride-off excluded). Hang land onto floor/deck also starts a fall. After the fall bout, soft-restore uses the same floor/deck `CHECKPOINT_HISTORY_SEC` window as lava respawn (no death overlay). Invisible `__void_floor__` still catches fall-through. Lava / pipe / wall / void never count as checkpoints.

## Transitions

A transition occurs only via:

- a compiled topology edge (seam / explicit wall / open anchor), or
- an accepted immutable `ManeuverPlan`, or
- the earliest swept blocker/hazard along a proposed free-air segment.

| From | To | Gate |
|------|----|------|
| Grounded | Grounded | Continuous support seam, pipe→wall/wall→pipe seam, or same surface UV advance |
| Grounded | Airborne (air-out) | Leave `OPEN` / `SHARED_SPINE` coping with rising along (no fly-out) |
| Grounded | Airborne (free) | Leave unsupported edge / ride-off, or **fly-out** from `OPEN` / `SHARED_SPINE` |
| Airborne (air-out) | Grounded | Descend through the retained anchor to its source pipe/wall only |
| Airborne (air-out) | Airborne (free) | **Fly-out** (X-dominant outward stick in `FLY_OUT_ABOVE` window) |
| Airborne (free) | Grounded | Ordinary descending land; pipes only if same-facing as travel (never opposite); decks only on a descending crossing of the pad top |
| Airborne / grounded | Airborne+plan | **Fly-out** unlock (`FLY_OUT`) or **transfer** X-lerp (`TRANSFER`) on button + candidate |
| Any | Crash | Grounded lava only |

Invisible world-border walls sit on the park AABB faces (X and Z) so you cannot leave the support footprint and fall out. Edge pipe copings on `x=0` / `x=width` remain rideable. Unplayable `space`, one-sided pipe interiors, **deck volumes** (below the ride top), and compiled wall/backing volumes are solid containment. An invisible `__void_floor__` patch at `VOID_FLOOR` catches fall-through when no other support remains. `#` decks are ride-on-top only. Map-edge decks/floors are walls.

**Contact ownership (single stream):** each airborne physics tick builds one
ordered contact stream — solid-face sweep, support-top crossings, and hang-anchor
crossing — sorted by time `t`. The earliest non-Corridor hit decides the tick.

Compiled span owners (non-overlapping) on each coping span:

| Role | Owns | Typical disposition |
|------|------|---------------------|
| `LIP_COLUMN` | Coping column / bowl-side lip (pipe or wall) | **Mount** when descending |
| `OUTWARD_DECK` | Abutting `#` pad clearly outward of coping | **Mount** if deck land gates pass; else **Reject** (exterior, no `vz=0` freeze) |
| `OPEN_CORRIDOR` | Deck-backed `OPEN` / `SHARED_SPINE` from clearly outward | **Corridor** (acid only; no ordinary mount) |
| `WALL_CLIMB` | Explicit wall face | **Mount** hang source / inbound upper partner; else **Reject** or outward-exit **Corridor** |
| `HANG_ANCHOR` | Retained air-out edge | **Mount** source pipe/wall |

Three dispositions only: **Mount** (ground on that owner), **Reject** (stay
exterior with normal-consistent velocity — never kill vertical while still
intersecting), **Corridor** (continue to the next event). Hang remounts only the
retained source; foreign lips under the X-lock are Corridor. `supports_below`
fills UV/height for a chosen Mount — it is not a competing lander.

Outward `#` remains `OPEN`; riding its deck off onto an abutting pipe does **not**
auto-mount — fall like a ledge (deck→pipe remount TBD). The exact pipe coping is
not inside either pipe solid; contact still returns a stable feature / owner id,
surface, projection, normal, and time.

## Tolerances (`SimTolerances`)

| Name | Default (logical) | Use |
|------|-------------------|-----|
| `CONTACT_EPS` | `1.5` | Support contact / land window |
| `SEAM_EPS` | `0.75` | Height match for support seams; coping classification |
| `ALIGN_EPS` | `2.0` | Target coping alignment / Z overlap slack |
| `MAX_EDGE_CROSSINGS` | `8` | Per-tick seam chain bound |
| `FLY_OUT_ABOVE` | `40` | Max height above coping for fly-out window |
| `DECK_LAND_MIN_ABOVE` | `20` | Air-bout peak must exceed pad by this before free-air deck land |
| `CHECKPOINT_HISTORY_SEC` | `1.5` | Lava respawn restores this many seconds back on floor/deck |
| `APEX_FACING_DELAY` | `0.05` s | Centered local-Y hang turn duration into the source pipe |
| `FACING_COPING_CELLS` | `3` | Spine cast range in cells |
| `ACID_COPING_CELLS` | `16` | Acid cast range in cells |
| `VOID_FLOOR` | `-200` | Invisible safety floor under the park AABB |

No other magic epsilons in solvers.

## Coping spans and wall surfaces

Every geometric `CopingEdge` is partitioned into non-overlapping Z spans. Global
story breakpoints are classification inputs only: adjacent spans with identical
behavior are merged so they cannot become artificial hang seams. Each remaining
span has one behavior and one topology edge:

| Class | Behavior |
|-------|----------|
| `OPEN` | Air-out on rise; fly-out when stick-outward in window |
| `SUPPORT_SEAM` | Auto-roll onto abutting **floor** at matching height only |
| `WALL_EXTENSION` | Seam from pipe `u=1` to an explicit `WallSurface`; wall `u` independently remains in `[0,1]` |
| `SHARED_SPINE` | Opposite-facing pair at matching height within gap | Spine target; air-out / fly-out like `OPEN` |

Outward `#` decks (any height) ⇒ `OPEN` (air/fly corridor). Matching-height `=` floor ⇒ `SUPPORT_SEAM`. A taller outward floor or cross-story opposite pipe compiles an explicit wall only for the occupied Z spans. The upper opposite coping is stored as an action-only transfer target, never an ordinary seam.

Wall faces are one-sided. Riding off a deck through its backing wall enters ordinary free air and preserves gravity; ordinary air contact never acquires wall ownership. Walls are mounted only from their source pipe seam or by returning through the retained air-out anchor.

## Velocity rules

- Grounded X / along: integrate control. Neutral stick coasts (`friction` / `ramp_friction`); stick opposite velocity brakes (`brake`); aligned stick accelerates (`accel`). **`max_speed` is an absolute `|vx|` / along ceiling** (gravity on pipes/walls included).
- Grounded / air **depth (Z)**: zero momentum — velocity is stick × `max_speed_z`; release snaps to 0.
- Free-air **X**: ballistic — no friction/coast decay; stick steers toward `wish × max_speed` (or brakes when opposite). Aligned stick must **not** slow existing `|vx|` toward a lower wish fraction, but `|vx|` is hard-clamped to `max_speed`. Release conserves vx within that cap. Height integrates gravity only.
- Seam crossing: transport world tangent speed onto the destination surface; no dead-stop.
- Pipe→wall and wall→pipe seams preserve tangent speed and consume the crossing once.
- Air-out leave: seed vertical from wall/pipe tangent; `vx = 0`; retain and lock to the launch edge anchor until fly-out / return (depth may retarget onto a colinear same-side OPEN edge or hold a synthetic X-lock across a gap). Once per hang, after vertical apex **while still on the launch Z span** with no depth stick, facing turns around the character's centered local Y axis into the source pipe over `APEX_FACING_DELAY` (0 = instant). Leaving the launch span or holding depth keeps takeoff orientation.
- Fly-out / deck-out: clear hang, keep rising height, and seed outward free-air X from climb/air speed. Deck grounding from free air requires a descending pad crossing **and** that this air bout peaked at least `DECK_LAND_MIN_ABOVE` above the pad. A wall face sharing a rear `#` X owns the full climb band (including the bottom `CONTACT_EPS` seam) — never deck-rescue mid-climb.
- Ordinary land: require descending support crossing; pipes only same-facing (air-out: also coping-X aligned, any height); never opposite-facing. Free-air land onto pipe/ramp maps along from world velocity projected onto the slope tangent (not a forced downhill seed; not vx-only). Hang remount into the bowl still seeds downhill along. Air-out prefers remountable pipes; if none are under the lock, ordinary-land the nearest flat (floor/deck/lava/void) and clear hang.
- Pipe/ramp lip leave with **no abutting support** (park-edge void): clamp on the lip and kill downhill along — do not free-air eject. Void eject + same-slope remount punch (≥80 downhill) trapped stick-out reverse at border lips (`>>>` against the left wall).
- Maneuver plans: fly-out unlock only (spine/acid removed).

## Input

| Intent | Condition |
|--------|-----------|
| Move | Stick → wish in XZ / along-surface |
| Ollie | Hold `ollie`: mild accel toward `max_speed` in **facing** direction; skipped while stick brakes opposite. Hold meter builds only while **grounded** (cannot start charging in air). Release pops to peak height `charge_frac × ollie_height_flat` on floor/deck or `charge_frac × ollie_height_pipe` on pipe/ramp/wall (level units; charge over `ollie_charge_ms`, capped at 100%) via `v = √(2|g|h)` if an ollie charge is available. One charge: spent on a successful release jump, restored on any grounded contact. On pipes **below** the lip / air-out band the pop is world-up and carries **full** along → world X (peak-ward included). In the upper `ollie_lip_frac` of a **pipe** (default top 50%), ollie enters X-locked hang air like a normal air-out (along does not stack onto vertical). **Ramps never hang / X-lock / fly-out** — lip-band ollie and peak leave are free air; Z-adjacent pipes must not auto-mount from a ramp. Free-air leave from a ramp's upper `ollie_lip_frac` (including peak leave) sets `free_air_upright`; presentation lerps tilt upright; mid-ramp free air keeps pre-takeoff lean. |
| Fly-out / deck-out | Same action. X-dominant outward stick (−X left pipe / +X right pipe) while rising in `FLY_OUT_ABOVE` on `OPEN` / `SHARED_SPINE` or while air-out. Cross-story wall tops gate height on the connected upper lip, but outward stick stays with the source pipe that climbed the wall. Clears hang, seeds outward free-air X, and resets presentation lean upright. |
| Spine / Acid | **Removed** — reimplement on the single-owner air contact stream |

## Tie-breaks

Sort by: directional distance, then absolute height delta, then stable compiled ID (lexicographic string). Never scene-tree order.

## Assertions (must fail loudly)

NaN pose/velocity, multiple or unknown grounded owners, surface `u` outside `[0,1]`, foreign solid penetration, unplanned opposite-facing surface change, mid-plan retarget, grounded/airborne disagreement with pose, layer-index branches in solvers, or deterministic replay/hash mismatch.
