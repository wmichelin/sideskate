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
| **Air spin** | — | Hold rotate left/right while airborne (incl. transfer). Continuous yaw from bout zero; live facing flips at odd *N×180°*; never changes `vx`. Land near *N×180°* or fall; success snaps; backwards land may fix facing to momentum without board re-yaw. |
| **Spine** | — | Explicit transfer to an opposite-facing pipe. Requires the transfer input and an eligible target; ordinary contact never performs a spine. |
| **Acid** | — | Explicit descending transfer onto a pipe, using the same transfer input and `TRANSFER` plan. |

Spine and acid select a candidate in the facing half-plane, on the opposite side,
above the target's effective hang lip. A tap accepts immediately; holding transfer
accepts after `transfer_hold_delay` (default 0.08 seconds) of continuous eligibility.
Both use normal gravity and a time-phased `TRANSFER` plan: X and lean advance from
0→1, facing stays fixed, and arrival clears `vx` and re-anchors air-out. Depth stays
free-air. A descending acid can originate from deck ollie/ride-off free air.
Ordinary deck-to-pipe contact follows the contact rules below.

### Fly-out / deck-out activation

While air-out (hang) or perched on an `OPEN` / `SHARED_SPINE` coping, and height above coping is within `FLY_OUT_ABOVE`:

- Stick must be **X-dominant** and **outward** (into the lip / toward leaving the pipe): −X on left pipes, +X on right pipes.
- Accepting fly-out clears hang, seeds outward free-air velocity from climb/air speed, ends X-lock, and stands the skater upright (`free_air_upright` — no carried pipe/wall lean).

Same-height outward `#` decks are fly/air corridor — they do **not** auto-mount from the pipe.
Free-air landings on the coping column prefer that pipe over an abutting outward `#` pad for
ownership — but a **foreign** pipe upper ollie-lip band is a crash wall (Reject + fall), not a
drop-in. Same-slope remount may still seat. Past the coping into the deck remains ordinary
deck land / fly-out.

### Air-out landing

While air-out (X-locked):

- The state retains the launch edge and may **retarget** `hang_edge_id` onto a
  colinear same-side `OPEN` coping whose lock X matches when depth leaves the
  launch span.
- Between those spans, hang keeps a synthetic X-lock (does **not** become free air).
  Leaving Z alone never clears hang — that requires fly-out / land / remount.
- Descending through the current (possibly retargeted) edge returns to its source
  pipe or explicit wall with fall speed preserved.
- Hang apex into-bowl facing turn still fires after vertical apex when holding
  depth stick or leaving the launch Z span; presentation depth-turn yaw layers
  on top of `facing_yaw` and is unchanged.
- Ordinary contact must **never** accept an opposite-facing pipe; that requires an explicit spine or acid plan.
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
3. **Grinding** — `{ grind_rail_id, grind_along, grind_balance, position }`, with depth and height locked to the rail and signed speed along world X.

`hang_edge_id` empty ⇒ free air (XZ control). Non-empty ⇒ **air-out**: X is locked to that edge’s anchor at current Z (depth stick still applies; height ballistic). Hang clears on fly-out, land, or remount. Leaving the launch edge’s Z span **retargets** onto a colinear same-side OPEN edge when available, otherwise keeps a synthetic X-lock across the gap (does not clear).

Death is a grounded→overlay path after **lava** contact only. Death and fall bouts are independent of the three motion modes. Sudden-stop contacts classified by `CrashClassifier` start a **fall bout** (`begin_fall`): world borders, deck walls/volumes, ramp **or pipe** outer-back, an actual deck-launch outer/back wall, underside, or lateral solid hit before a valid ride-surface crossing, free-air into a **foreign pipe** upper ollie-lip band (`u ≥ 1 - ollie_lip_frac` — Reject, never Mount), and hang / X-lock clipping or landing floor/deck. Excluded: deck-seam support/lip ownership contact, same-slope remount (including upper band), foreign pipe below the lip band, ordinary descending ride-surface crossing, hang remount of owned pipe/wall, hang on the coping lip-column of an abutting `#`, free-air into the launch slope’s own outward `#` (lip/peak leave), own-slope peak leave / outer-back, intentional deck-back ride-off. After the fall bout, soft-restore uses the same floor/deck `CHECKPOINT_HISTORY_SEC` window as lava respawn (no death overlay). Invisible `__void_floor__` still catches fall-through. Lava / pipe / wall / void never count as checkpoints.

## Transitions

A transition occurs only via:

- a compiled topology edge (seam / explicit wall / open anchor), or
- an accepted immutable `ManeuverPlan`, or
- the earliest swept blocker/hazard along a proposed free-air segment, or
- a grind mount/exit accepted by `GrindSolver`.

| From | To | Gate |
|------|----|------|
| Grounded | Grounded | Continuous support seam, pipe→wall/wall→pipe seam, or same surface UV advance |
| Grounded | Airborne (air-out) | Leave `OPEN` / `SHARED_SPINE` coping with rising along (no fly-out) |
| Grounded | Airborne (free) | Leave unsupported edge / ride-off, or **fly-out** from `OPEN` / `SHARED_SPINE` |
| Airborne (air-out) | Grounded | Descend through the retained anchor to its source pipe/wall only |
| Airborne (air-out) | Airborne (free) | **Fly-out** (X-dominant outward stick in `FLY_OUT_ABOVE` window) |
| Airborne (free) | Grounded | Ordinary descending land; pipes only if same-facing as travel (never opposite); decks only on a descending crossing of the pad top |
| Airborne / grounded | Airborne+plan | **Fly-out** unlock (`FLY_OUT`) or **transfer** X-lerp (`TRANSFER`) on button + candidate |
| Airborne (free) | Grinding | Hold grind within `RAIL_SNAP_RADIUS`; alive, no fall/plan/hang, and remount cooldown expired |
| Grinding | Airborne (free) | Charged ollie release or ride past either rail end; preserve signed `grind_along` as world `vx` |
| Grinding | Airborne + fall bout | Balance reaches `GRIND_BALANCE_FAIL`; preserve signed grind speed into fall deceleration |
| Any | Death overlay | Grounded lava only |

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
| `WALL_CLIMB` | Explicit wall face | **Mount** hang source / free-air remount of launch wall; else **Reject** or outward-exit **Corridor**. `upper_partner_pipe_id` is transfer-only — never free-air Mount (outer-back smash must not lip-seat the upper pipe) |
| `HANG_ANCHOR` | Retained air-out edge | **Mount** source pipe/wall |

Three dispositions only: **Mount** (ground on that owner), **Reject** (stay
exterior with normal-consistent velocity — never kill vertical while still
intersecting), **Corridor** (continue to the next event). Hang remounts only the
retained source; foreign lips under the X-lock are Corridor. `supports_below`
fills UV/height for a chosen Mount — it is not a competing lander.

Outward `#` remains `OPEN`. Riding off that deck is ordinary free air with
`air_launch` = the deck. The initial deck-seam support/lip ownership event is a
**Corridor** only while **not** falling: it neither Mounts nor crashes, so
gravity carries the rider toward the transition. The adjoining pipe/ramp Mounts
only when the descending free-air sweep crosses its sampled ride surface from
above. An actual outer/back wall, underside, or lateral solid face hit before
that crossing Rejects and starts a fall. Once a fall bout is active, every
deck-launch contact with that abutting pipe/ramp **Rejects** (never Corridor or
Mount) and clearance stays on the approach / outward side. Accepted **Acid** and
**Spine** transfer plans use their own target-seat rules. Into-face wall/bounds
Rejects park on the approach side at `WALL_REJECT_CLEAR` with lean away from the
face. The exact pipe coping is not inside either pipe solid; contact still
returns a stable feature / owner id, surface, projection, normal, and time.

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
| `RAIL_OFFSET` | `56` | Rail top above its layer base |
| `RAIL_SNAP_RADIUS` | `36` | Maximum distance for an eligible airborne grind mount |
| `GRIND_BALANCE_FAIL` | `1` | Absolute balance threshold that starts a fall bout |

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

Wall faces are one-sided. Riding off a deck through its backing wall enters ordinary
free air and preserves gravity. A wall can be mounted from its source pipe seam,
through the retained air-out anchor, or by the documented free-air remount of the
launch wall. Foreign walls follow the Reject/corridor rules above; an upper partner
pipe remains an explicit transfer target.

## Velocity rules

- Grounded X / along: integrate control. Neutral stick coasts (`friction` / `ramp_friction`); stick opposite velocity brakes (`brake`); aligned stick accelerates (`accel`). **`max_speed` is an absolute `|vx|` / along ceiling** (gravity on pipes/walls included).
- Grounded / air **depth (Z)**: zero momentum — velocity is stick × `max_speed_z`; release snaps to 0.
- Free-air **X**: ballistic — no friction/coast decay; stick steers toward `wish × max_speed` (or brakes when opposite). Aligned stick must **not** slow existing `|vx|` toward a lower wish fraction, but `|vx|` is hard-clamped to `max_speed`. Release conserves vx within that cap. Height integrates gravity only.
- Seam crossing: transport world tangent speed onto the destination surface; no dead-stop.
- Pipe→wall and wall→pipe seams preserve tangent speed and consume the crossing once.
- Air-out leave: seed vertical from wall/pipe tangent; `vx = 0`; retain and lock to the launch edge anchor until fly-out / return (depth may retarget onto a colinear same-side OPEN edge or hold a synthetic X-lock across a gap). Once per hang, after vertical apex, facing turns around the character's centered local Y axis into the source pipe over `APEX_FACING_DELAY` (0 = instant) — still runs with depth stick held or after leaving the launch Z span. Presentation depth-turn yaw remains a separate additive layer.
- Fly-out / deck-out: clear hang, keep rising height, and seed outward free-air X from climb/air speed. Deck grounding from free air requires a descending pad crossing **and** that this air bout peaked at least `DECK_LAND_MIN_ABOVE` above the pad. A wall face sharing a rear `#` X owns the full climb band (including the bottom `CONTACT_EPS` seam) — never deck-rescue mid-climb.
- Ordinary land: require descending support crossing; pipes only same-facing (air-out: also coping-X aligned, any height); never opposite-facing. Free-air land onto pipe/ramp maps along from world velocity projected onto the slope tangent (not a forced downhill seed; not vx-only). Hang remount into the bowl **always** seeds downhill along from stored air-out takeoff `|along|` (`hang_launch_along`) via one helper — every path (HANG_ANCHOR, LIP_COLUMN, support-top, snap, ordinary land), never hang world-vel projection (`vx` is locked to 0). **Transfer** stamps that takeoff into `ManeuverPlan.land_along` before `clear_hang` (which zeros `hang_launch_along`) and restores it on dest hang re-anchor — otherwise dest remount collapses to the 120 floor (spine drag). Free-air acid (deck ollie / skate-off with hang stamp cleared) stamps `|vx|` the same way. Air-out prefers remountable pipes; if none are under the lock, ordinary-land the nearest flat (floor/deck/lava/void) and clear hang.
- Pipe/ramp lip leave with **no abutting support** (park-edge void): clamp on the lip and kill downhill along — do not free-air eject. Void eject + same-slope remount punch (≥80 downhill) trapped stick-out reverse at border lips (`>>>` against the left wall).
- Maneuver plans: `FLY_OUT` exits X-lock and seeds outward free air; `TRANSFER` carries accepted spine/acid motion to its fixed target. No mid-plan retargeting.
- Grinding: retain signed entry `vx` as `grind_along`; stick X+Z adjusts balance, not speed or depth. Neutral input returns balance toward center. Releasing grind does not end an existing lock. End leave and ollie preserve signed speed and start a short remount cooldown. Balance failure preserves that speed into the existing timed fall envelope.

## Input

| Input | Condition |
|--------|-----------|
| Move | Stick → wish in XZ / along-surface |
| Ollie | Hold `ollie`: mild accel toward `max_speed` in **facing** direction; skipped while stick brakes opposite. Hold meter builds while **grounded or grinding** (cannot start charging in air). Release pops to peak height `charge_frac × ollie_height_flat` on floor/deck or `charge_frac × ollie_height_pipe` on pipe/ramp/wall (level units; charge over `ollie_charge_ms`, capped at 100%) via `v = √(2|g|h)` if an ollie charge is available. One charge: spent on a successful release jump, restored on grounded contact or a grind mount. On pipes **below** the lip / air-out band the pop is world-up and carries **full** along → world X (peak-ward included). In the upper `ollie_lip_frac` of a **pipe** (default top 50%), ollie enters X-locked hang air like a normal air-out (along does not stack onto vertical). **Ramps never hang / X-lock / fly-out** — lip-band ollie and peak leave are free air; Z-adjacent pipes must not auto-mount from a ramp. Free-air leave from a ramp's upper `ollie_lip_frac` (including peak leave) sets `free_air_upright`; presentation lerps tilt upright; mid-ramp free air keeps pre-takeoff lean. |
| Fly-out / deck-out | Same action. X-dominant outward stick (−X left pipe / +X right pipe) while rising in `FLY_OUT_ABOVE` on `OPEN` / `SHARED_SPINE` or while air-out. Cross-story wall tops gate height on the connected upper lip, but outward stick stays with the source pipe that climbed the wall. Clears hang, seeds outward free-air X, and resets presentation lean upright. |
| Spine / Acid | Tap transfer with a candidate, or hold through `transfer_hold_delay` of continuous eligibility. Target must be in the facing half-plane, opposite-facing, and below the skater at its effective hang lip. Both use `ManeuverPlan.Kind.TRANSFER`; descending transfer is acid. |
| Grind | Hold grind while airborne near an eligible rail to mount. Stick controls balance. Hold/release ollie to leave; riding past an end also enters free air. |
| Fall | `fall` input starts the same soft fall bout as a classified crash; gameplay input stays ignored until checkpoint recovery. |

## Tie-breaks

Sort by: directional distance, then absolute height delta, then stable compiled ID (lexicographic string). Never scene-tree order.

## Assertions (must fail loudly)

Non-finite pose, velocity or surface coordinates; multiple/unknown grounded owners;
unknown grind owner; surface `u` outside `[0,1]`; foreign solid penetration outside
an allowed corridor; unplanned opposite-facing surface change; mid-plan retarget;
motion mode disagreement with pose; layer-index branches in solvers; or replay
checkpoint mismatch.

## Recording contract

`PlayerSim.gameplay_snapshot()` includes `SimState`, accepted maneuver details,
input holds/edges, ollie charge/availability, transfer eligibility, checkpoint
history and effective tuning. `gameplay_hash()` identifies this complete state;
`SimState.state_hash()` identifies only the state object. Consumed presentation
latches (`spin_handoff`, `board_align_to_facing`, `ollie_just_popped`) and diagnostic
`last_reject` do not affect gameplay identity.

Recordings store the initial snapshot/model identity and ordered input/tuning
for every physics tick and external fall/respawn command. Recording indices stay
monotonic when checkpoint restoration resets `SimState.tick`. The model hash
includes spawn, dimensions, playable footprint, geometric samples and topology.
Stopping also records input/tuning changed after the last tick, without advancing
physics. Always check the recording's error field and replay result.

`SimSnapshot.VERSION` versions the format. Canonical dictionaries sort their keys;
Godot 4 Variant encoding preserves scalar floating-point precision, engine vector
precision and infinite sentinels. The JSON transport uses base64 with a checksum
to reject corrupted data before decoding those bytes.
There is no decimal quantization or guarantee of identical physics across engine
versions/architectures. Replay checks model/engine compatibility and every event's
complete gameplay hash. See `tests/sim/test_sim_replay.gd` for executable examples.
