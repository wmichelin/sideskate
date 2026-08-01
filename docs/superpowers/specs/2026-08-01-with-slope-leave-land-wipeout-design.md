# With-slope leave/land + wipeout presentation

## Goal

Stop inconsistent deck→pipe “ledge falls” and wipeouts that tip into wall meshes by splitting authority cleanly:

1. **Sim leave/land policy:** motion *with* the slope Corridors/Mounts; motion *into* a face Rejects and may start a fall bout.
2. **Fall presentation:** kinematic tip driven from sim clearance — never an independent RigidBody that can tunnel into park trimeshes.

Extends [crash classifier](2026-07-31-crash-classifier-design.md) and [fall mechanic](2026-07-31-fall-mechanic-design.md). Supersedes the movement-contract line that riding an outward `#` onto an abutting pipe is “fall like a ledge (deck→pipe remount TBD).”

## Non-goals

- Redesigning transfer / acid pull.
- Removing fall bouts for true into-wall / outer-back smashes.
- Changing lava death or checkpoint soft-restore timing.
- A general lean-vs-normal orientation engine beyond planar with-slope / into-face half-planes.
- Full rewrite of every disposition branch unrelated to leave/land or wipeout park.

## Player-facing behavior

### Deck → abutting pipe/ramp (`####(((=====` and mirrors)

Skating off `#` toward the abutting `(((` / `)))` / ramp:

1. Grounded leave crosses the deck open side into **free air** with `air_launch_surface_id` = that deck.
2. **No** `request_fall` / wipeout on that leave.
3. Free air over the abutting slope is **Corridor** (not foreign-lip Reject) while this bout’s launch is that deck (or with-slope vs that slope).
4. Descending contact with that slope’s **ride face** → **Mount** (traveling with the slope).
5. Later into-face contact (wall, outer-back, bounds) may still wipe out.

Inconsistency today (“sometimes rides off, sometimes falls”) is a defect; the above is the only legal outcome for ordinary skate-off.

### Joint / wall wipeout

Into-face Reject on a compiled wall / union face / bounds:

- Feet park on the **approach** side at `WALL_REJECT_CLEAR` from the face.
- Into-face planar speed and `fall_start_*` are zeroed / absorbed so later ticks cannot reinject through the face.
- Fall lean stamps **away** from the face (approach sign).
- Presentation tip stays on that clearance — never inside the impact solid.

Tip-of-pipe skims that are not with-slope leaves may still clear outside the bowl lip; mid-joint hits must not teleport across the pipe column.

## With-slope vs into-face

Central helper (on `CrashClassifier` or a tiny `SlopeTravel` util used by it):

| Kind | Meaning | Disposition |
|------|---------|-------------|
| **With-slope** | Planar motion in the slope’s downhill / into-bowl half-plane, or intentional deck open-side leave whose launch pad abuts that slope | Corridor or Mount — **never** foreign-lip Reject for that leave |
| **Into-face** | Planar motion into a wall/bounds/feature face, outer-back, or against a foreign slope face | Reject; classifier may `request_fall` |

Covers in one rule:

- Intentional `#` open-side leave onto abutting pipe/ramp
- Same-slope remount (including upper band when with-slope)
- Peak / lip leave onto the owned ride face

Foreign-lip Reject remains only when contact is **into-face** (not when traveling with that slope after a legal leave).

## Architecture

| Piece | Ownership |
|-------|-----------|
| `CrashClassifier` / `SlopeTravel` | `is_with_slope`, `is_into_face`; deck-abut ownership; tighten foreign-lip to into-face |
| `AirSolver` | Disposition uses helper; deck leave → free air no fall; wipeout park approach-only |
| `GroundSolver` | Rolling off `#` open side does not wipe out; with-slope seam onto abutting slope |
| `PlayerSim` / `SimState` | Approach lean + planar absorb; tip-skim eject only when tip-band and safe |
| `logical_pose_presenter_3d` | **Kinematic** fall tip from sim feet + lean; remove RigidBody fall box tunneling |
| Docs | `movement_contract.md`, `gameplay.md` fall / deck leave notes |

Godot park colliders remain presentation-only (non-authoritative).

## Fall presentation detail

- On fall enter: hide skater body; show tip mesh parented/posed from interpolated sim feet.
- Tip rotation uses `fall_lean_sign` (approach) over `fall_anim_duration`; no independent world impulses into the impact face.
- Optional: collide fall mesh with floor/ride only if it cannot push the visual past the sim approach plane; default is no RigidBody.
- On fall end / restore: hide tip, show body at sim pose.

## Docs to update (implementation)

- `docs/movement_contract.md` — replace deck→pipe ledge-fall TBD with with-slope leave/land; wipeout approach park.
- `docs/gameplay.md` — deck skate-off; fall presentation note.
- Cross-link from crash-classifier spec: foreign-lip narrowed by into-face.

## Tests

| Case | Expect |
|------|--------|
| Fixture `####(((=====` (and depth repeats): grounded on `#`, stick +X | Never `falling` on leave; enters free air; Mounts abutting left pipe when descending onto ride face |
| Mirror `=====)))####` skate −X off deck | Same |
| Layered joint/wall into-face crash | `x` never past face; lean away; after N fall ticks still approach-side |
| Presentation smoke / unit: fall start at wall | Tip origin stays on approach half-space of face (logical → world) |
| Existing union open-lip fly-out + mid-face no-tunnel | Stay green |

Prefer `tests/levels/` fixtures + `LevelLoader.parse_text` over playable `res://levels/`.

## Rollout

1. Failing tests for ride-off + wipeout-into-wall.
2. Classifier / with-slope helper + air/ground disposition.
3. Kinematic fall presentation.
4. Contract / gameplay docs.
5. Full headless suite.

## Success criteria

- Deck skate-off onto abutting pipe is consistent every time (free air, then with-slope Mount).
- Joint/wall wipeout never places sim or fall visual inside the impact wall.
- Fly-out and mid-face union regressions remain green.
