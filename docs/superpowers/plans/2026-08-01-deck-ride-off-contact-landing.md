# Deck Ride-off Contact Landing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An outward `#` deck leaves into free air, Corridors its nonphysical seam support/lip event, Mounts only at a real descending ride-surface crossing, and falls only on an actual solid-face hit.

**Architecture:** `GroundSolver` stamps the deck as `air_launch` and enters ordinary free air. `AirSolver` has the swept segment and chooses the deck-abutting slope contact disposition: crossing → Mount, unprojectable `support_top`/lip ownership seam → Corridor, other actual slope solid → Reject + fall. Accepted Acid and Spine plans already bypass free-air contact processing through `_step_maneuver`.

**Tech Stack:** Godot 4 GDScript, analytical `PlayerSim`, headless test runner.

## Global Constraints

- Simulation advances only on physics ticks; Godot presentation/collision never decides gameplay state.
- Never stage `levels/offset_demo.ssk`.
- Acid and Spine remain the shared `ManeuverPlan.Kind.TRANSFER` path.
- Preserve same-slope reentry, foreign-pipe lip, fly-out, hang, and existing fall behavior outside launch-deck contacts.

---

### Task 1: Correct the regression contract

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Test: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `PlayerSim`, `PipeSurface.project`, the `deck_to_left_pipe.ssk` fixture
- Produces: exact seam-Corridor, surface-crossing Mount, and solid-face fall tests

- [ ] **Step 1: Replace the pre-surface fall assertion**

Rename `_deck_ride_off_rejects_pre_surface_pipe_contact()` to
`_deck_ride_off_corridors_seam_support_contact()` and replace its tick loop:

```gdscript
for _tick in range(3):
	sim.set_input(Vector2.ZERO, false, false)
	sim.tick()
	if sim.state.is_grounded() and sim.state.surface_id == pipe.id:
		push_error("deck seam: proximity-mounted pipe")
		return false
	if sim.state.falling:
		push_error("deck seam: crashed before a ride-surface crossing")
		return false
if not sim.state.is_airborne():
	push_error("deck seam: expected free air, mode=%s" % sim.state.mode)
	return false
return true
```

- [ ] **Step 2: Keep the existing sampled surface-crossing test**

Keep `_deck_ride_off_mounts_only_on_descending_surface_crossing()` in `run()`.
It must still set `air_launch_surface_id = deck.id`, start above
`pipe.height_at_theta`, descend, and assert `surface_id == pipe.id`.

- [ ] **Step 3: Add an actual-solid-face fall regression**

Create `_deck_ride_off_rejects_actual_pipe_solid()` using the same fixture.
Start in free air from the deck launch with X inside the pipe footprint, height
below the sampled ride height, and lateral velocity into the pipe. Assert a
fall occurs and `surface_id` never becomes the pipe:

```gdscript
sim.state.mode = SimState.Mode.AIRBORNE
sim.state.surface_id = ""
sim.state.air_launch_surface_id = deck.id
sim.state.position = Vector3(
	pipe.x_at_theta(z, 0.45 * PI * 0.5), z,
	pipe.height_at_theta(z, 0.45 * PI * 0.5) - 12.0
)
sim.state.velocity = Vector3(180.0, 0.0, 0.0)
```

- [ ] **Step 4: Run RED**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `FAIL test_sim_runtime.gd` with `deck seam: crashed before a ride-surface crossing`.

- [ ] **Step 5: Commit the corrected regressions**

```bash
git add tests/sim/test_sim_runtime.gd
git commit -m "Correct deck seam ride-off regression"
```

---

### Task 2: Make the deck gate seam-aware

**Files:**
- Modify: `scripts/sim/air_solver.gd`
- Modify: `scripts/sim/crash_classifier.gd`
- Test: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Consumes: `CrashClassifier.deck_abuts_slope(deck_id, slope_id, z)`
- Produces: `AirSolver._deck_launch_slope_disposition(state, contact, from, at) -> int`

- [ ] **Step 1: Keep sweep endpoints in contact disposition**

Retain the endpoint-aware calls:

```gdscript
var at := from.lerp(to, t)
var disp := _disposition_for_contact(state, contact, from, at)
```

`_stream_has_later_mount` must calculate `later_at` from the same `from` and
`to`. `_resolve_air_contact` must call disposition with `(from, from)`.

- [ ] **Step 2: Replace the deck-launch helper outcome table**

In `_deck_launch_slope_disposition`, use this order after establishing that the
contact belongs to the launch deck’s abutting slope:

```gdscript
var from_proj: Dictionary = surf.project(from.x, from.y, from.z)
var at_proj: Dictionary = surf.project(at.x, at.y, at.z)
var crossed := (
	state.velocity.z < -SimTolerances.CONTACT_EPS
	and bool(from_proj.get("ok", false))
	and bool(at_proj.get("ok", false))
	and float(from_proj.separation) > SimTolerances.CONTACT_EPS
	and float(at_proj.separation) <= SimTolerances.CONTACT_EPS
)
if crossed:
	return SimKinds.ContactDisposition.MOUNT

var role := int(contact.get("role", SimKinds.ContactRole.SOLID))
if str(contact.get("kind", "")) == "support_top" \
		or role == SimKinds.ContactRole.LIP_COLUMN:
	return SimKinds.ContactDisposition.CORRIDOR
return SimKinds.ContactDisposition.REJECT
```

This explicitly recognizes the `t=0` deck seam ownership event as a corridor
while keeping a true pipe/ramp body, wall, outer-back, or underside hit
rejecting.

- [ ] **Step 3: Request a fall only for a real Reject**

In `_reject_air_contact`, continue to set `state.request_fall = true` only when
the helper returns `REJECT`. Do not call `_reject_air_contact` for a Corridor.

- [ ] **Step 4: Preserve transfer and foreign-lip behavior**

Keep `AirSolver.step()`’s existing early maneuver dispatch:

```gdscript
if state.has_maneuver():
	_step_maneuver(state, wish, delta)
	return
```

Keep `CrashClassifier.is_same_slope_reentry()` unchanged. Do not restore the
old velocity-based `is_with_slope()` exemption.

- [ ] **Step 5: Run GREEN and commit**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
git add scripts/sim/air_solver.gd scripts/sim/crash_classifier.gd tests/sim/test_sim_runtime.gd
git commit -m "Corridor deck seam before slope landing"
```

Expected: `=== 15 passed, 0 failed ===`.

---

### Task 3: Update the contract and verify the renderer

**Files:**
- Modify: `docs/movement_contract.md`
- Modify: `docs/gameplay.md`
- Modify: `docs/superpowers/specs/2026-07-31-crash-classifier-design.md`

- [ ] **Step 1: State the seam-aware deck policy**

Document: deck seam support/lip ownership is Corridor; only a descending sampled
ride-surface crossing Mounts; actual outer/back, underside, and lateral solid
faces Reject + fall; Acid and Spine use accepted transfer-plan seats.

- [ ] **Step 2: Run final gates**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
./tools/render_iteration.sh plaza_default spawn 3d-only
./tools/render_iteration.sh spine_demo spawn 3d-only
./tools/render_iteration.sh layered_demo spawn 3d-only
./tools/render_iteration.sh variable_height_ramps spawn 3d-only
./tools/render_iteration.sh plaza_default_deep spawn pair
```

Expected: `=== 15 passed, 0 failed ===` and every render report has
`"errors": []`.

- [ ] **Step 3: Commit and push**

```bash
git add docs/movement_contract.md docs/gameplay.md \
  docs/superpowers/specs/2026-07-31-crash-classifier-design.md \
  docs/superpowers/specs/2026-08-01-deck-ride-off-contact-landing-design.md \
  docs/superpowers/plans/2026-08-01-deck-ride-off-contact-landing.md
git commit -m "Document seam-aware deck ride-off landing"
git push origin HEAD
```
