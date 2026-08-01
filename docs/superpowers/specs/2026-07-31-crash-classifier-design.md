# Crash classifier — sudden-stop fall triggers

## Goal

Centralize crash / wipeout classification in a small `CrashClassifier` used by air and ground solvers. Qualifying contacts set `SimState.request_fall` and enter the existing fall bout + checkpoint recovery path (`PlayerSim.begin_fall()`).

Extends [fall impact triggers](2026-07-31-fall-impact-triggers-design.md) and [fall mechanic](2026-07-31-fall-mechanic-design.md). Does not replace lava kill.

Guiding intuition (not implemented as a general orientation engine this pass): if something would suddenly stop the skater like hitting a wall — upright into a vertical face, or leaned into flat — they crash.

## Non-goals

- No general body-parallel / lean-vs-normal classifier this pass (enumerated rules only).
- No speed-threshold tunable (any qualifying contact falls).
- No death overlay / `alive = false` for these crashes (checkpoint soft-restore, same as other falls).
- No change to lava death.
- No new motion mode.
- Opposite-facing pipe upper-lip as a designed case (geometry → ramp outer-back or no contact).
- Treating ramp **ride face** as a crash wall (only ramp / pipe **outer-back**).

## Approach

**CrashClassifier util** (`scripts/sim/crash_classifier.gd`, `RefCounted`):

- Holds `ParkModel` and current `ollie_lip_frac` (synced from `PlayerSim`).
- Pure policy: `is_crash(state, contact, ctx) -> bool` (+ optional reason for tests/debug).
- Does not mutate sim state or run physics.

`AirSolver` / `GroundSolver` call it at disposition, reject, hang-clip, and ground-contain sites; on true they Reject (where Mount would wrongly seat) and set `request_fall`.

## Triggers → crash / `begin_fall()`

| Contact | When | Result |
|---------|------|--------|
| Level walls (`bounds` / `ContactRole.BOUNDS`) | Free air or grounded | fall (existing carve-outs below) |
| Deck walls / volumes (`feature_wall`, deck solid) | Free air or grounded | fall |
| Ramp **or pipe** outer-back (`feature_wall` reason `"slope outer back"`, ground contain equivalent) | Free air or grounded; not hang remount | fall unless launch-exit / intentional deck-back carve-out |
| Foreign **pipe** in upper ollie-lip band (`u ≥ 1 - ollie_lip_frac`) | Free air; lip column / body / support_top owning that pipe | **Reject + fall — never Mount** |
| Deck-launch abutting slope before a descending ride-surface crossing (see [deck ride-off contact landing](2026-08-01-deck-ride-off-contact-landing-design.md)) | Free air; actual outer/back wall, underside, or lateral solid contact owning that slope | **Reject + fall — never Mount** |
| Hang + floor/deck **solid or clip** | Hang / X-lock; capsule intersects floor or deck solid (not only clean descending flat Mount) | fall |
| Hang descending land onto floor or deck | Hang air | fall (already shipped; classifier owns the rule) |

## Non-triggers (must stay playable)

| Case | Why |
|------|-----|
| Same-slope remount (launch pipe/ramp, or Z-adjacent same-footprint ramp↔pipe), including upper lip band | Normal air-out drop-in |
| Foreign pipe below lip band (`u < 1 - ollie_lip_frac`) | Ordinary land / ride |
| Ordinary descending ride-surface crossing (including deck launch) | AirSolver proves the sampled surface was crossed from above; outer-back still crashes |
| Deck-seam support-top / lip ownership before that crossing | Ownership metadata only; Corridor into the next free-air segment |
| Hang remount of owned pipe / ramp / source wall | Keep skating the transition |
| Hang X-lock on coping lip-column overlapping own outward `#` | Lip-band ollie / air-out; deep pad clip and hang→deck land still fall |
| Free-air into launch pipe/ramp's own outward `#` | Peak / lip leave air-out pad; foreign decks still crash |
| Own-ramp / own-pipe peak leave corridor | Riding off lip stays free air |
| Intentional deck-back ride-off | Ledge fall / acid, not wipeout |
| Free-air map-edge over bordering `#` | Edge fly corridor |
| Grounded on map-edge deck pressing rim | Stay playable; grounded **floor** into rim still falls |

**Foreign pipe:** contact owner is a pipe and is **not** same-slope reentry vs `air_launch_surface_id` / hang source (reuse existing reentry / abut helpers).

**Lip band:** shared `ollie_lip_frac` (default `0.50`) — same threshold as lip-band ollie hang on pipes.

## Architecture

| Piece | Ownership |
|-------|-----------|
| `CrashClassifier` | Enumerated crash policy |
| `PlayerSim` | Owns classifier instance; syncs `ollie_lip_frac`; `request_fall` → `begin_fall()` |
| `AirSolver` | Contact disposition; owns deck-launch sweep crossing versus face Reject; reject/hang-clip → ask classifier → `request_fall` |
| `GroundSolver` | Contain against bail solids → ask classifier → `request_fall` |
| Fall recovery | Unchanged checkpoint soft-restore |

Migrate existing `_contact_requests_fall` logic into the classifier so air/ground share one table. Solvers stay thin.

## Docs to update (implementation)

- `docs/movement_contract.md` — foreign pipe lip band Reject+fall; pipe outer-back fall; hang clip flat.
- `docs/gameplay.md` — crash trigger summary; point at classifier.
- Cross-link from fall-impact-triggers spec as superseded for the trigger table (recovery unchanged).

## Tests

1. Free-air floor/deck ollie into foreign pipe at `u ≥ 1 - ollie_lip_frac` → `falling`, never grounded on that pipe.
2. Same bout into foreign pipe below lip band → may Mount; not forced fall from this rule.
3. Same-slope air-out remount into upper band → not fall from this rule; remount/drop-in stays legal.
4. Hang X-lock capsule clipping deck/floor solid → `falling` even without a clean descending flat Mount.
5. Free-air / grounded into pipe or ramp outer-back → `falling`; own-slope peak-leave carve-out → not falling.
6. Regression: bounds / deck wall / hang→floor land / checkpoint restore / lava death still pass.

## Self-review

- **Mount vs fall:** Foreign high pipe is explicitly Reject — no seat, no downhill punch, no “drop in.”
- **Lip frac source:** One knob (`ollie_lip_frac`) shared with lip-band ollie; classifier reads the synced value.
- **Hang clip vs hang remount:** Flat solid/clip crashes; owned pipe/wall remount does not.
- **Ramp asymmetry:** Intentional — ride face landable; outer-back crashes (pipe outer-back too).
- **Scope:** One feature (classifier + new/migrated rules); suitable for a single implementation plan.
