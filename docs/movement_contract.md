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

## High-level states

Exactly one of:

1. **Grounded** — `{ surface_id, u, v, tangent_velocity (Vector2 in surface UV speed), facing }`
2. **Airborne** — `{ position (Vector3: x,z,height), velocity (Vector3), maneuver: ManeuverPlan|null, hang_pipe_id: String }`

`hang_pipe_id` empty ⇒ free air (XZ control). Non-empty ⇒ hang air: X is locked to that pipe’s coping X at the current Z; Z stick still applies. Hang clears on fly-out, spine, acid, or land — not a pile of boolean locks.

Crash / death is a terminal grounded→overlay path after lava contact or out-of-bounds fall; it is not a third motion state.

## Transitions

A transition occurs only via:

- a compiled topology edge (seam / wall extension / open coping), or
- an accepted immutable `ManeuverPlan`, or
- the earliest swept blocker/hazard along a proposed free-air segment.

| From | To | Gate |
|------|----|------|
| Grounded | Grounded | Continuous `SUPPORT_SEAM` or same surface UV advance |
| Grounded | Airborne (hang) | Leave `OPEN` / `SHARED_SPINE` coping with rising along (no fly-out) |
| Grounded | Airborne (free) | Leave unsupported edge / ride-off, or **fly-out** from `OPEN` coping |
| Airborne (hang) | Airborne (free) | **Fly-out** (X-dominant outward stick in window) |
| Airborne (hang) | Airborne+plan | Explicit spine (rising/apex) or acid (descending) |
| Airborne | Grounded | Ordinary descending landing on a support patch |
| Airborne | Airborne+plan | Explicit spine (rising/apex) or acid (descending) |
| Airborne+plan | Grounded | Plan landing time reached on destination coping/pipe |
| Any aerial | Crash | Blocker / lava / invalidated plan corridor |

## Tolerances (`SimTolerances`)

| Name | Default (logical) | Use |
|------|-------------------|-----|
| `CONTACT_EPS` | `1.5` | Support contact / land window |
| `SEAM_EPS` | `0.75` | Height match for support seams; coping classification |
| `ALIGN_EPS` | `2.0` | Target coping alignment / Z overlap slack |
| `MAX_EDGE_CROSSINGS` | `8` | Per-tick seam chain bound |
| `FLY_OUT_ABOVE` | `40` | Max height above coping for fly-out window |
| `FACING_COPING_CELLS` | `3` | Spine cast range in cells |
| `ACID_COPING_CELLS` | `16` | Acid cast range in cells |

No other magic epsilons in solvers.

## Coping classifications

Every compiled `CopingEdge` has exactly one class:

| Class | Behavior |
|-------|----------|
| `OPEN` | Explicit fly-out allowed; otherwise hang at coping (X-locked) until land / fly-out / spine / acid |
| `SUPPORT_SEAM` | Auto-roll onto abutting deck/floor at matching height |
| `WALL_EXTENSION` | Analytical wall continues to deck top; effective coping moves there |
| `SHARED_SPINE` | Opposite-facing pair; spine target relation |

A glyph-aligned outward deck is never both fly-out space and a solid catch wall.

## Velocity rules

- Grounded: integrate control in surface UV; gravity projects onto surface tangent.
- Seam crossing: transport world tangent speed onto the destination surface; no dead-stop.
- Hang leave: seed vertical from along at coping; `vx = 0`; lock X to coping until unlock.
- Fly-out: clear hang and seed free-air velocity from pipe world remnant / outward unlock.
- Ordinary land: require downward surface-normal velocity; convert impact into surface tangent.
- Spine/acid land: convert descending vertical into destination pipe along-arc with travel sign preserved; never reverse travel.
- Maneuver plans once accepted never retarget.

## Input

| Intent | Condition |
|--------|-----------|
| Move | Stick → wish in XZ / along-surface |
| Fly-out | Explicit X-dominant outward stick while rising in fly-out window on `OPEN` |
| Spine | Explicit action while rising or rising-apex |
| Acid | Explicit action while descending |
| Post fly-out | Same action may acid when descending; never spine at apex |

## Tie-breaks

Sort by: directional distance, then absolute height delta, then stable compiled ID (lexicographic string). Never scene-tree order.

## Assertions (must fail loudly)

NaN pose/velocity, penetration beyond `CONTACT_EPS`, unknown `surface_id`, unconsumed motion after `MAX_EDGE_CROSSINGS`, mid-plan retarget, grounded/airborne disagreement with pose, layer-index branches in solvers.
