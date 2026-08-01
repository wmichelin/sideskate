# Wipeout presentation and approach park

> **Status:** The deck→abutting-slope auto-Mount policy formerly specified here
> is superseded by
> [deck-ride-off-contact-landing-design.md](2026-08-01-deck-ride-off-contact-landing-design.md).
> That document is authoritative for deck launch, ordinary landing, Acid, and
> Spine behavior. This document retains only the wipeout presentation design.

## Goal

Keep an into-face wipeout on the approach side of its wall and drive its visible
tip directly from analytical simulation, never from an independently simulated
RigidBody.

Extends [crash classifier](2026-07-31-crash-classifier-design.md) and
[fall mechanic](2026-07-31-fall-mechanic-design.md).

## Joint / wall wipeout

Into-face Reject on a compiled wall / union face / bounds:

- Feet park on the **approach** side at `WALL_REJECT_CLEAR` from the face.
- Into-face planar speed and `fall_start_*` are zeroed / absorbed so later ticks cannot reinject through the face.
- Fall lean stamps **away** from the face (approach sign).
- Presentation tip stays on that clearance — never inside the impact solid.

Tip-of-pipe skims may still clear outside the bowl lip; mid-joint hits must not
teleport across the pipe column.

## Wipeout architecture

| Piece | Ownership |
|-------|-----------|
| `CrashClassifier` | Selects true crash contacts |
| `AirSolver` | Parks into-face Rejects on the approach side |
| `PlayerSim` / `SimState` | Approach lean + planar absorb; tip-skim eject only when tip-band and safe |
| `logical_pose_presenter_3d` | **Kinematic** fall tip from sim feet + lean; remove RigidBody fall box tunneling |
| Docs | Fall behavior and presentation contract |

Godot park colliders remain presentation-only (non-authoritative).

## Fall presentation detail

- On fall enter: hide skater body; show tip mesh parented/posed from interpolated sim feet.
- Tip rotation uses `fall_lean_sign` (approach) over `fall_anim_duration`; no independent world impulses into the impact face.
- Optional: collide fall mesh with floor/ride only if it cannot push the visual past the sim approach plane; default is no RigidBody.
- On fall end / restore: hide tip, show body at sim pose.

## Verification

| Case | Expect |
|------|--------|
| Layered joint/wall into-face crash | `x` never past face; lean away; after N fall ticks still approach-side |
| Presentation smoke / unit: fall start at wall | Tip origin stays on approach half-space of face (logical → world) |
| Existing union open-lip fly-out + mid-face no-tunnel | Stay green |

Prefer `tests/levels/` fixtures + `LevelLoader.parse_text` over playable `res://levels/`.
