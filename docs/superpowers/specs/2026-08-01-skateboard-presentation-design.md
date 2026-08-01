# Skateboard presentation (placeholder board + dual fall)

**Status:** implemented on main (2026-08-01).

## Goal

Give the player a visible skateboard under the orange rider with an independent
yaw that can rotate with hang apex (and later tricks), and split fall into two
presentation RigidBodies so the rider falls off the board.

## Context

`LogicalPosePresenter3D` now draws an orange rider on a red-nose / blue-tail
placeholder board. `LogicalPose` snapshots carry presentation-owned
`board_yaw`, and the board applies that yaw plus the ephemeral depth-turn yaw
without changing gameplay facing (`SimState.facing` / `visual_facing`).

Fall now hides the riding meshes and unfreezes two presentation RigidBodies:
`RiderFall` for the orange rider and facing mark, and `BoardFall` for the
nose/tail board. `PlayerSim` remains sole gameplay authority, with a clear seam
to promote board yaw into `SimState` later if tricks affect gameplay.

## Vocabulary

| Term | Meaning |
|------|---------|
| **Nose** | Red half of the board; the end that points toward facing at spawn/restore |
| **Tail** | Blue half; opposite the nose |
| **`board_yaw`** | Persistent presentation yaw of the board (local Y in the lean frame) |
| **Depth-turn yaw** | Existing ephemeral pose `depth_turn_yaw`; displayed on rider and board; never baked into `board_yaw` |

Fly-out / deck-out remain the same aerial action (prefer **fly-out** in code).
This feature does not change aerial vocabulary or sim transfer rules.

## Visual placeholder

- **Rider:** orange box (replace current pink); yellow facing mark on the rider
  only.
- **Board:** thin flat rectangle under the feet; thickness ~0.05; length ≈ body
  height (~0.40); cross-width ≈ body depth.
- **Halves:** 50/50 split at center under the rider — red nose, blue tail.
- **Local ground:** board shares the pose root lean (`surface_tilt` /
  free-air upright lerp). On flats this is world-horizontal; on pipe/ramp it
  stays under the feet (perpendicular to the rider), not world-locked flat.
- Later asset swap replaces meshes/materials only; the transform contract stays.

## Orientation contract

| Event | Board yaw |
|-------|-----------|
| Spawn / checkpoint restore | Snap once so nose matches current facing |
| Hang apex turn | Rotate with the rider: advance `board_yaw` with the same lerped apex yaw the body uses |
| Depth stick turn | Temporary display offset only (`depth_turn_yaw`); release restores stored `board_yaw` |
| Gameplay / visual facing flips | **Do not** change `board_yaw` |
| Future tricks / air spins | Will write `board_yaw` (out of scope) |

Lean is shared. Independence is **yaw-only**.

## Architecture (approach 1)

**Riding / air (not fallen)**

- One pose root (`LogicalPosePresenter3D`): lean on root Z.
- Children: **Rider** mesh and **Board** mesh (nose/tail materials).
- Pose snapshots / `LogicalPose` carry `board_yaw`.
- `apply_pose`: rider uses facing mark + body yaw as today; board uses
  `board_yaw + depth_turn_yaw` in the lean frame.

**Who writes `board_yaw`**

- `player.gd` pose capture / restore hooks (spawn, checkpoint).
- Hang apex: while sim advances hang apex `facing_yaw`, presentation applies the
  **same delta** to `board_yaw` (co-rotation through the lerped turn without
  snapping board yaw to facing at apex start).
- No sim solver ownership in this slice.

**Fall**

- Hide rider + board pose meshes.
- Unfreeze two `FallBoxConstraint`-style RigidBodies under `World3D`
  (presentation only; never write sim):
  - **RiderFall** — orange box + facing mark; impulse / angular from existing
    fall lean sign.
  - **BoardFall** — red/blue board at the board’s riding transform; lighter
    mass; separate impulse so the board skitters away.
- Both use RAGDOLL vs park geometry; both refresh support/impact planes like
  today’s FallBox.
- Camera tracks **RiderFall X** only (Y/Z lock unchanged). Debug cooldown bar
  anchors to the rider fall body.
- On bout end / restore: freeze+hide both; show pose meshes; re-snap
  `board_yaw` to facing with checkpoint restore.
- Sim fall bout timing (`fall_stop_duration` / `fall_duration`) unchanged — one
  logical bout.

## Ownership

| Piece | Responsibility |
|-------|----------------|
| `LogicalPose` / pose snapshots | Store and lerp `board_yaw` |
| `player.gd` | Capture snapshots; spawn/restore snap; apex delta into `board_yaw` |
| `LogicalPosePresenter3D` | Build orange rider + board meshes; apply lean/yaw; dual fall bodies |
| `CameraRig3D` / debug HUD | Resolve active fall body → rider |
| `docs/gameplay.md` | Short presentation note (nose/tail, independent yaw, dual fall) |
| `PlayerSim` / movement contract | Unchanged for this slice |

## Out of scope

- Trick rotations and free-air board spins that permanently change orientation
  beyond hang apex
- GLTF / final board asset
- Sim-owned `SimState.board_yaw`
- Camera tracking the board or a midpoint
- Changing fall bout duration defaults

## Tests

Headless (`tests/test_logical_pose.gd` and small helpers as needed):

1. `board_yaw` lerps in `LogicalPose.lerp_poses`.
2. Facing flip does not change `board_yaw`.
3. Spawn/checkpoint restore snaps `board_yaw` to facing.
4. Depth-turn display does not persist into the next snapshot’s `board_yaw`.
5. Dual fall bodies: extend existing FallBox plane clearance tests to rider and
   board constraints (above support / impact approach side).

Manual / render gate (not required for green headless): orange rider, readable
nose/tail, apex board turns with body, fall separates both bodies.

## Success criteria

- Riding: orange rider stands on a visible red/blue board on local ground.
- Facing can flip while the board stays put (except spawn/restore snap and hang
  apex co-rotation).
- Depth turn yaws both briefly without changing stored board orientation.
- Hang apex: board rotates with the rider through the lerped turn.
- Fall: two physics bodies; camera follows the rider; restore snaps board nose
  to facing.
