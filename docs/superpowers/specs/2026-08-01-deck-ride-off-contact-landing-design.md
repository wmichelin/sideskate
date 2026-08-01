# Deck ride-off contact landing

## Goal

Correct the deck-to-abutting-slope behavior:

- Riding off an outward `#` deck is an ordinary **free-air** leave.
- The adjacent pipe or ramp must not Mount merely because the deck ends at its
  coping, nor because the free-air capsule overlaps its body near that edge.
- An ordinary Mount is legal only when the falling trajectory physically crosses
  the slope's sampled ride surface from above.
- A deck-seam support/lip ownership contact before such a crossing is a
  **Corridor**, not a collision.
- An actual outer/back wall, underside, or lateral solid-face hit before such a
  crossing is an into-face **Reject + fall**.
- **Acid** and **Spine** remain explicit transfer paths and may seat their
  accepted targets independently of the ordinary deck-launch landing gate.

This supersedes the with-slope auto-Mount claim in
[2026-08-01-with-slope-leave-land-wipeout-design.md](2026-08-01-with-slope-leave-land-wipeout-design.md).

## Problem

The current implementation treats a deck-launched abutting slope as
“with-slope.” That only suppresses the foreign-lip crash rule; it leaves the
ordinary body-contact Mount path enabled. A free-air sweep can therefore Mount
the adjacent pipe/ramp before the rider's trajectory reaches its ride surface.

The previous regression also hid the issue: it moved the rider to five logical
units before the coping and used neutral input, instead of reproducing the
held-direction deck leave that caused the report.

## Ordinary deck-launch contact policy

For an air bout whose `air_launch_surface_id` is an outward `#` deck:

| Contact with the deck's abutting pipe/ramp | Required disposition |
|---|---|
| The ride surface is crossed from above while falling | **Mount** |
| Deck seam support-top or lip ownership contact before that crossing | **Corridor** |
| Outer/back wall, underside, or lateral solid face before that crossing | **Reject + fall** |
| No slope contact | Continue free air; ordinary flat/lava landing rules apply |

“Crossed from above while falling” is a sweep condition, not a proximity test:
the segment begins above the sampled slope height at the contact X/Z and ends
at or below it, with negative vertical velocity. A body overlap with no such
crossing is not a landing.

The first `support_top` / lip-owner event at an abutting deck seam is only
compiled ownership metadata. It may occur at `t=0` while the rider remains
above or outside the projectable ride surface, so it must Corridor into the
next free-air segment rather than Reject or Mount.

## Explicit transfers

Acid and Spine construct accepted maneuver plans. Their target seats continue
to follow maneuver-plan rules; the ordinary deck-launch contact gate must not
intercept or reinterpret those accepted transfers.

## Architecture

`GroundSolver` remains responsible only for leaving the deck into free air and
stamping the deck as `air_launch_surface_id`. It does not Mount the adjacent
slope.

`AirSolver` owns the ordinary-air decision:

1. Identify contact with the slope abutting the launch deck at the current
   depth span.
2. For that pair, test the free-air segment against the sampled ride height.
3. Select Mount only for the real descending surface crossing.
4. Corridor seam support/lip ownership events that do not cross the ride
   surface.
5. Reject and request a fall for every other solid-face contact with that slope.

`CrashClassifier` may expose the deck-abut ownership lookup, but it does not
label an entire deck air bout “with-slope.” Collision timing and the
surface-crossing predicate belong in `AirSolver`.

## Tests

Add real-sim regressions using `####(((=====`:

1. Deck edge starts free air and Corridors through its first adjacent-slope seam
   support/lip ownership contact.
2. Held-direction leave reproduces the formerly problematic trajectory and
   does not Mount by proximity.
3. A trajectory that descends through the sampled pipe/ramp surface Mounts.
4. A true lateral solid face hit before a valid surface crossing Rejects and
   starts a fall.
5. Acid and Spine transfers still seat accepted targets.

Keep existing fly-out, hang, and foreign-pipe lip regressions green.
