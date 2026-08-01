# Bounded fall presentation and containment

**Status:** implemented on `main` (2026-08-01).

## Goal

Restore a physics-like crash tumble without letting a presentation body enter
park meshes, and prevent any fall bout from passing through an abutting L1 pipe
via the deck-seam Corridor.

## Problem

The current `FallTip` is a mesh reposed every render frame at a capped 55° roll.
It has no gravity, settle, collision response, support-plane offset, or facing
marker; its rotated box can visibly sink through the support surface.

Separately, a deck-launched fall still carries `air_launch_surface_id`. The
deck-launch contact gate therefore returns `CORRIDOR` for a seam/lip event even
after `state.falling` is true. That bypasses the normal falling slope Reject and
can let the skater cross an L1 pipe.

## Presentation contract

`PlayerSim` remains the sole gameplay authority. The fall RigidBody is visual
only: its position, rotation, collision, and impulses never write simulation
state.

On a wall/pipe Reject that begins a fall, the sim records:

- a support plane: point + normal used to keep the visual body above the
  current analytical support;
- an optional impact plane: point + approach-side normal used to keep the
  visual body on the same side as the sim feet.

The presenter restores `FallBox` as a `RigidBody3D` with continuous collision,
gravity, damping, angular velocity, and a facing marker. At fall enter it:

1. starts from the interpolated analytical feet pose;
2. uses the desired tipped orientation;
3. offsets the oriented box center by its projected half-extents along the
   support normal, so no corner starts below the support plane;
4. offsets/clamps the body to the impact approach half-space.

Each presentation physics tick, the body is projected back above the stored
support plane and onto the stored approach half-space if collision/integration
would cross either. The clamp changes only the visual RigidBody. At fall end it
freezes/hides the box and shows the normal skater body.

## Fall containment contract

The deck seam remains a `CORRIDOR` only while the rider is in ordinary free air.
Once `state.falling` is true, the deck-launch gate never returns `CORRIDOR` or
`MOUNT` for its abutting pipe/ramp:

- every seam, lip, support-top, and body contact returns `REJECT`;
- existing fall clearance/depenetration resolves the skater outside the pipe;
- no fall tick may ground on that pipe or cross to its far side through its
  solid volume.

Acid and Spine remain accepted transfer plans before a fall starts. A fall bout
clears the maneuver, so neither is a fall containment exception.

## Ownership

| Piece | Responsibility |
|---|---|
| `SimState` | Stores fall support/impact planes with simulation-owned clearance |
| `AirSolver` | Stamps planes when beginning a Reject fall; falling deck contacts Reject |
| `PlayerSim` | Clears plane state when a fall begins and when checkpoint recovery completes |
| `LogicalPosePresenter3D` | Runs the bounded, visual-only FallBox |
| Tests | Assert sim containment and visual oriented-box plane clearance |

## Tests

1. A slow `####(((=====` coast Corridors the seam, then gravity Mounts the ride
   surface; this remains unchanged.
2. The same deck launch after `begin_fall()` rejects a seam/lip/body contact on
   an abutting layered L1 pipe and remains outside it for the whole fall bout.
3. Flat and tilted support-plane tests transform all eight FallBox corners and
   prove none is below the recorded support plane.
4. Impact-plane test proves the FallBox remains on the sim approach side of a
   wall Reject throughout the tumble.
5. Existing fall recovery, Acid/Spine transfer, fly-out, and renderer gates
   remain green.
