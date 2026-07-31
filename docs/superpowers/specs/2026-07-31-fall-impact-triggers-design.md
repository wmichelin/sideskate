# Fall impact triggers + checkpoint recovery

## Goal

Wire **business logic** into `PlayerSim.begin_fall()`: hard contact with park containment solids (and hang flat land) starts a fall bout. When any fall bout finishes, soft-restore to the last floor/deck checkpoint — same history window as lava respawn, without the death overlay.

Extends [fall mechanic](2026-07-31-fall-mechanic-design.md); does not replace lava kill.

## Non-goals

- No speed-threshold tunable for this pass (any qualifying Reject / contain / hang-flat mounts falls).
- No death overlay / `alive = false` for fall recovery.
- No change to hang remount onto pipe / ramp / source wall.
- No new motion mode.

## Triggers → `begin_fall()`

| Contact | When | Result |
|---------|------|--------|
| Level walls (`bounds` / `ContactRole.BOUNDS`) | Free air **or** grounded | fall |
| Deck walls / volumes (`feature_wall` on deck, deck solid underside/sides) | Free air **or** grounded | fall |
| Ramp launch / outer-back (`feature_wall` reason `"slope outer back"`, and equivalent ground contain) | Free air **or** grounded, and **not** hanging | fall |
| Hang land onto **floor or deck** (not pipe/ramp) | Hang air, descending flat contact | fall |

Hang remount of owned pipe / ramp / wall stays Mount as today.

`begin_fall()` remains a no-op if already falling or dead. Lava kill still clears fall and runs the death path.

## Non-triggers (must stay playable)

- **Own-ramp peak leave** — contacts that currently corridor via `_slope_outer_back_is_launch_exit` must not fall (riding off `>>` stays free air).
- **Intentional deck-back ride-off** — crossing the one-sided backing wall from a ridden deck top into free air does not fall.
- Soft Corridor contacts that are not Reject / contain / hang-flat mounts.

## Recovery (all falls, including Y)

Fall bout timers / planar stop / presentation box unchanged until recovery conditions:

1. `fall_elapsed >= fall_duration`
2. Skater is **grounded**

Then, instead of in-place upright recovery:

- Soft restore using the existing floor/deck checkpoint history (`CHECKPOINT_HISTORY_SEC`, same selection as `PlayerSim.respawn()`).
- Clear fall bout, zero velocity, grounded on that floor/deck, facing from checkpoint.
- **No** death overlay, **no** `alive = false`.

Applies to every fall enter path: impact, hang-flat, and debug Y.

## Architecture

| Piece | Ownership |
|-------|-----------|
| Classify bail contact | Shared helper (e.g. on `AirSolver` / small util used by air + ground) |
| Air Reject → fall | `air_solver._reject_air_contact` (after classify; still depenetrate / kill into-normal speed so the bout starts outside the solid) |
| Hang flat → fall | Hang flat Mount path: `begin_fall()` instead of clean skate-away; prefer seating on the flat so recovery can complete, then checkpoint teleport |
| Ground contain → fall | `ground_solver` contain against bail `bounds` / `feature_wall` / deck solid |
| Checkpoint restore on recovery | `PlayerSim._tick_fall` → soft restore (factor shared with `respawn()` body, without death UI) |
| Y invoke | unchanged → `begin_fall()`; recovery now teleports |

`PlayerSim` should expose a single restore helper used by lava `respawn()` and fall recovery so history selection stays one path.

## Docs to update (implementation)

- `docs/movement_contract.md` — containment can start fall; hang flat → fall; fall recovery → checkpoint.
- `docs/gameplay.md` — fall triggers + restore note; Y still debug invoke.
- Fall mechanic spec recovery section — in-place → checkpoint soft restore.

## Tests

1. Free-air into park bounds → `falling`.
2. Free-air / grounded into deck feature wall → `falling`.
3. Free-air into foreign ramp outer-back → `falling`; own-ramp peak leave → not falling.
4. Hang descending onto floor (and deck) → `falling`; hang remount same-facing pipe → not falling from that mount alone.
5. After bout (`fall_duration` + grounded), surface is a checkpoint floor/deck (history), not the impact pad if history differs; Y path same.
6. Lava grounded kill still deaths + overlay path (regression).

## Self-review

- **Peak leave vs launch smash:** Explicit non-trigger via existing launch-exit corridor classification — do not fall on that path.
- **Hang + deck:** Today hang corridors decks; this design **adds** hang→deck as a fall trigger (user: ground instead of pipe/ramp). Floor already mounts as hang-flat; both floor and deck fall.
- **Recovery grounded gate:** Unchanged — if duration ends in air, wait for land, then teleport. Impact in air still needs a land before restore.
- **Scope:** One feature (triggers + restore); suitable for a single implementation plan.
