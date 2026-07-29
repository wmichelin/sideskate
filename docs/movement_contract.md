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
| **Air-out** | hang | Leave a compiled open edge with **X locked** to its anchor. Motion is height (+ optionally Z) only. Stick does **not** unlock X. |
| **Fly-out** | deck-out | Exit X-lock and travel **away** from the pipe: left on a left pipe, right on a right pipe (world outward). Free-air XZ control after unlock. |
| **Spine** | — | Explicit transfer onto an **opposite-facing** pipe. Never an automatic ordinary land. |

### Fly-out / deck-out activation

While air-out (hang) or perched on an `OPEN` / `SHARED_SPINE` coping, and height above coping is within `FLY_OUT_ABOVE`:

- Stick must be **X-dominant** and **outward** (into the lip / toward leaving the pipe): −X on left pipes, +X on right pipes.
- Accepting fly-out clears hang, seeds outward free-air velocity, and ends X-lock.

Same-height outward `#` decks are fly/air corridor — they do **not** auto-mount from the pipe.

### Air-out landing

While air-out (X-locked):

- The state retains the exact source edge and surface.
- Descending through that edge returns to its source pipe or explicit wall with fall speed preserved.
- Z travel leaving the edge’s compiled span clears the anchor and becomes free air.
- Ordinary contact must **never** accept the edge’s opposite-facing transfer target (that requires spine).
- Floors / decks under the locked X remain valid ordinary lands.

### Spine landing

Spine is an accepted `ManeuverPlan` only (transfer button while rising/apex). Destination is the opposite-facing pipe approached from its **outward** side: travel +X onto a left pipe (from left of it), or travel −X onto a right pipe (from right of it).

## High-level states

Exactly one of:

1. **Grounded** — `{ surface_id, u, v, tangent_velocity (Vector2 in surface UV speed), facing }`
2. **Airborne** — `{ position (Vector3: x,z,height), velocity (Vector3), maneuver: ManeuverPlan|null, hang_edge_id: String }`

`hang_edge_id` empty ⇒ free air (XZ control). Non-empty ⇒ **air-out**: X is locked to that edge’s anchor at current Z (depth stick still applies; height ballistic). Hang clears on fly-out, spine, acid, land, or leaving the edge’s Z span.

Crash / death is a terminal grounded→overlay path after **lava** contact only; it is not a third motion state. World borders, unplayable space, and solid geometry are **containment** (invisible walls / void floor) — never crash.

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
| Airborne (air-out) | Grounded | Descend through the retained anchor to its source pipe/wall; floor/deck contact under lock may land first |
| Airborne (air-out) | Airborne (free) | **Fly-out** (X-dominant outward stick in `FLY_OUT_ABOVE` window) |
| Airborne (air-out) | Airborne+plan | Explicit spine (rising/apex) or acid (descending) |
| Airborne (free) | Grounded | Ordinary descending land; pipes only if same-facing as travel (never opposite) |
| Airborne | Airborne+plan | Explicit spine (rising/apex) or acid (descending) |
| Airborne+plan | Grounded | Plan landing time reached on destination coping/pipe |
| Any | Crash | Grounded lava only |

Invisible world-border walls sit on the park AABB faces (X and Z) so you cannot leave the support footprint and fall out. Edge pipe copings on `x=0` / `x=width` remain rideable. Unplayable `space`, one-sided pipe interiors, **deck volumes** (below the ride top), and compiled wall/backing volumes are solid containment. An invisible `__void_floor__` patch at `VOID_FLOOR` catches fall-through when no other support remains. `#` decks are ride-on-top only. Map-edge decks/floors are walls.

**Contact ownership:** support projection, edge lookup, and swept solid contact are separate queries. A shared coping boundary has one compiled owner; the exact pipe coping is not inside either pipe solid. Contact returns a stable feature ID, surface, projection, normal, and time. Outward `#` remains `OPEN`; riding its deck off onto an abutting pipe does **not** auto-mount — fall, and mount only via **acid** while descending.

## Tolerances (`SimTolerances`)

| Name | Default (logical) | Use |
|------|-------------------|-----|
| `CONTACT_EPS` | `1.5` | Support contact / land window |
| `SEAM_EPS` | `0.75` | Height match for support seams; coping classification |
| `ALIGN_EPS` | `2.0` | Target coping alignment / Z overlap slack |
| `MAX_EDGE_CROSSINGS` | `8` | Per-tick seam chain bound |
| `FLY_OUT_ABOVE` | `40` | Max height above coping for fly-out window |
| `APEX_FACING_DELAY` | `0.05` s | Centered local-Y hang turn duration into the source pipe |
| `FACING_COPING_CELLS` | `3` | Spine cast range in cells |
| `ACID_COPING_CELLS` | `16` | Acid cast range in cells |
| `VOID_FLOOR` | `-200` | Invisible safety floor under the park AABB |

No other magic epsilons in solvers.

## Coping spans and wall surfaces

Every geometric `CopingEdge` is partitioned into non-overlapping Z spans. Each span has one behavior and one topology edge:

| Class | Behavior |
|-------|----------|
| `OPEN` | Air-out on rise; fly-out when stick-outward in window |
| `SUPPORT_SEAM` | Auto-roll onto abutting **floor** at matching height only |
| `WALL_EXTENSION` | Seam from pipe `u=1` to an explicit `WallSurface`; wall `u` independently remains in `[0,1]` |
| `SHARED_SPINE` | Opposite-facing pair at matching height within gap | Spine target; air-out / fly-out like `OPEN` |

Outward `#` decks (any height) ⇒ `OPEN` (air/fly corridor). Matching-height `=` floor ⇒ `SUPPORT_SEAM`. A taller outward floor or cross-story opposite pipe compiles an explicit wall only for the occupied Z spans. The upper opposite coping is stored as an action-only transfer target, never an ordinary seam.

## Velocity rules

- Grounded X / along: integrate control. Neutral stick coasts (`friction` / `ramp_friction`); stick opposite velocity brakes (`brake`); aligned stick accelerates (`accel`). Cap at max speeds.
- Grounded / air **depth (Z)**: zero momentum — velocity is stick × max speed; release snaps to 0.
- Free-air **X**: ballistic — no friction/coast decay; stick steers only while held (accelerate toward wish or brake when opposite). Aligned stick must **not** slow existing `|vx|` toward a lower wish cap. Release conserves vx. Height integrates gravity only.
- Seam crossing: transport world tangent speed onto the destination surface; no dead-stop.
- Pipe→wall and wall→pipe seams preserve tangent speed and consume the crossing once.
- Air-out leave: seed vertical from wall/pipe tangent; `vx = 0`; retain and lock to the exact edge anchor until fly-out / spine / acid / return. Once per hang, after vertical apex, facing turns around the character's centered local Y axis into the source pipe over `APEX_FACING_DELAY` (0 = instant).
- Fly-out / deck-out: clear hang; seed free-air velocity with outward X.
- Ordinary land: require descending support crossing; pipes only same-facing (air-out: also coping-X aligned, any height); never opposite-facing.
- Spine/acid land: convert descending vertical into destination pipe along-arc with travel sign preserved; never reverse travel.
- Maneuver plans once accepted never retarget.

## Input

| Intent | Condition |
|--------|-----------|
| Move | Stick → wish in XZ / along-surface |
| Ollie | Hold `ollie`: mild accel toward `max_speed` in **facing** direction; skipped while stick brakes opposite |
| Fly-out / deck-out | X-dominant outward stick (−X left pipe / +X right pipe) while rising in `FLY_OUT_ABOVE` on `OPEN` / `SHARED_SPINE` or while air-out |
| Spine | Explicit action while rising/apex; dest opposite-facing; traveler outward of dest coping |
| Acid | Explicit action while descending; classic opposite wall, or deck drop-in onto abutting pipe from its outward side |
| Post fly-out | Same action may acid when descending; never spine at apex |

## Tie-breaks

Sort by: directional distance, then absolute height delta, then stable compiled ID (lexicographic string). Never scene-tree order.

## Assertions (must fail loudly)

NaN pose/velocity, multiple or unknown grounded owners, surface `u` outside `[0,1]`, foreign solid penetration, unplanned opposite-facing surface change, mid-plan retarget, grounded/airborne disagreement with pose, layer-index branches in solvers, or deterministic replay/hash mismatch.
